import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../../shared/widgets/gruplu_liste.dart';
import '../../../auth_profile/data/repositories/school_directory_repository.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/repositories/cloud_communication_repository.dart';
import '../../providers/cloud_communication_provider.dart';

/// Veliler sayfasındaki "Derse giren öğretmenler" bölümü (sınıf kadrosu).
///
/// ## Neden sayfanın içinde
/// Kadro eskiden iki katman derindeydi: Sınıfım → Veli Paneli → Kadro
/// sekmesi → "Kadroyu Yönet" penceresi. Kullanıcı: "kadroya öğretmen katma
/// işi daha görünür olmalı" (18 Ekim 2026). Liste ve "Okuldan öğretmen
/// ekle" düğmesi artık doğrudan Veliler sayfasında.
///
/// ## Kim eklenebilir
/// Okula kayıtlı (okul dizininde) her öğretmen, kod alışverişi olmadan
/// doğrudan eklenir (kullanıcı kararı, 18 Ekim 2026). Kadrodaki öğretmen bu
/// sınıfın velileriyle yazışabilir; `firestore.rules` içindeki
/// `isClassStaff()` bunu zorunlu kılar. Duyuru yetkisi sınıf öğretmeninde
/// kalır.
class SinifKadrosuBolumu extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const SinifKadrosuBolumu({super.key, required this.classModel});

  @override
  ConsumerState<SinifKadrosuBolumu> createState() => _SinifKadrosuBolumuState();
}

class _SinifKadrosuBolumuState extends ConsumerState<SinifKadrosuBolumu> {
  bool _busy = false;

  String get _uid => TeacherIdentity.resolve(ref.read(teacherProfileProvider));

  /// Kod üretimiyle AYNI kimlik kullanılmalı; aksi hâlde kadro satırı
  /// velinin baktığından başka bir sınıf odasına yazılır.
  String get _classCloudId => CloudIds.classId(
        teacherUid: _uid,
        localClassId: widget.classModel.id ?? 0,
      );

  @override
  void initState() {
    super.initState();
    _ensureHomeroomInStaff();
  }

  /// Sınıf öğretmeninin kadro satırını garanti eder.
  ///
  /// Kadro satırı eskiden yalnızca duyuru yayımlanınca ya da branş
  /// öğretmeni eklenince oluşuyordu; yalnızca referans kodu üretilmiş
  /// sınıflarda sınıf öğretmeni kadroda hiç görünmüyor, veli ona mesaj
  /// atamıyordu. Bu bölüm açıldığında eksik satır tamamlanır.
  Future<void> _ensureHomeroomInStaff() async {
    final teacher = ref.read(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);
    if (!CloudIds.isValidUid(uid)) return;

    try {
      await ref.read(cloudCommunicationRepositoryProvider).ensureClassRoom(
            classCloudId: _classCloudId,
            className: widget.classModel.name,
            teacherUid: uid,
            teacherName: teacher.fullName,
            schoolId: teacher.schoolId ?? '',
            schoolName: teacher.schoolName,
          );
      if (mounted) ref.invalidate(classStaffProvider(_classCloudId));
    } catch (e, stackTrace) {
      debugPrint('Kadro onarımı hatası: $e\n$stackTrace');
    }
  }

  /// Okul dizininden meslektaş seçtirip kadroya ekler.
  Future<void> _ekle() async {
    final teacher = ref.read(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);

    setState(() => _busy = true);
    final colleagues =
        await SchoolDirectoryRepository().teachersOfSchool(teacher.schoolId ?? '');
    if (!mounted) return;

    // Kendisi ve zaten kadroda olanlar listede çıkmaz.
    final existing = ref.read(classStaffProvider(_classCloudId)).valueOrNull ?? [];
    final existingUids = existing.map((m) => m.teacherUid).toSet();
    final available = colleagues
        .where((c) => c.uid != uid && !existingUids.contains(c.uid))
        .toList();
    setState(() => _busy = false);

    final picked = await showModalBottomSheet<SchoolTeacher>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MeslektasSecimi(
        colleagues: available,
        schoolName: teacher.schoolName,
      ),
    );
    if (!mounted || picked == null) return;

    final meeting = await _gorusmeSaatiSor(picked.fullName);
    if (!mounted || meeting == null) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(cloudCommunicationRepositoryProvider);
      await repo.ensureClassRoom(
        classCloudId: _classCloudId,
        className: widget.classModel.name,
        teacherUid: uid,
        teacherName: teacher.fullName,
        schoolId: teacher.schoolId ?? '',
        schoolName: teacher.schoolName,
      );
      final ok = await repo.addStaffDirectly(
        classCloudId: _classCloudId,
        teacherUid: picked.uid,
        teacherName: picked.fullName,
        branch: picked.branch,
        meetingDay: meeting.$1,
        meetingTime: meeting.$2,
      );
      ref.invalidate(classStaffProvider(_classCloudId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '${picked.fullName} kadroya eklendi. Velilerle yazışabilir.'
                : 'Öğretmen eklenemedi. İnternet bağlantınızı kontrol edin.',
          ),
          backgroundColor: ok ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Kadro ekleme hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Görüşme günü ve saatini sorar (isteğe bağlı).
  Future<(String, String)?> _gorusmeSaatiSor(String teacherName) async {
    final dayCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Veli Görüşme Saati',
          style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$teacherName için (isteğe bağlı)',
              style: AppFonts.outfit(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dayCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gün',
                      hintText: 'Salı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Saat',
                      hintText: '13:30',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kadroya Ekle'),
          ),
        ],
      ),
    );

    if (ok != true) return null;
    return (dayCtrl.text.trim(), timeCtrl.text.trim());
  }

  Future<void> _cikar(CloudStaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kadrodan Çıkar'),
        content: Text(
          '${member.teacherName} kadrodan çıkarılsın mı? '
          'Bu öğretmen artık velilerle yazışamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(cloudCommunicationRepositoryProvider).removeStaff(
            classCloudId: _classCloudId,
            teacherUid: member.teacherUid,
          );
      ref.invalidate(classStaffProvider(_classCloudId));
    } catch (e, stackTrace) {
      debugPrint('Kadrodan çıkarma hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffAsync = ref.watch(classStaffProvider(_classCloudId));

    final soluk = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final List<Widget> uyeler = staffAsync.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ],
      error: (e, _) => const [
        GrupSatiri(
          ikon: Icons.cloud_off_rounded,
          ad: 'Kadro yüklenemedi',
          alt: 'İnternet bağlantınızı kontrol edin',
          uyari: true,
        ),
      ],
      // Sınıf öğretmeninin kendi satırı listede kalabalık etmez.
      data: (staff) => [for (final m in staff.where((m) => !m.isHomeroom)) _uyeSatiri(m, isDark)],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kadrodakiler bu sınıfın velileriyle yazışabilir; duyuru yalnız sizde.',
          style: AppFonts.outfit(fontSize: 11.5, color: soluk, height: 1.35),
        ),
        const SizedBox(height: 8),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        GrupKutusu(satirlar: [
          ...uyeler,
          GrupSatiri(
            key: const ValueKey('kadroya_ogretmen_ekle'),
            ikon: Icons.person_add_alt_1_rounded,
            ad: 'Okuldan öğretmen ekle',
            alt: uyeler.isEmpty && staffAsync.hasValue
                ? 'Henüz ders öğretmeni eklenmedi'
                : 'Okulunuzda kayıtlı öğretmenler',
            onTap: _busy ? null : _ekle,
          ),
        ]),
      ],
    );
  }

  Widget _uyeSatiri(CloudStaffMember m, bool isDark) {
    final gorusme = '${m.meetingDay} ${m.meetingTime}'.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.branch.isEmpty ? m.teacherName : '${m.teacherName} · ${m.branch}',
                  style: AppFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  gorusme.isEmpty ? 'Görüşme saati yazılmadı' : 'Görüşme: $gorusme',
                  style: AppFonts.outfit(
                    fontSize: 11.2,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _busy ? null : () => _cikar(m),
            icon: const Icon(Icons.person_remove_outlined, size: 20),
            color: AppColors.danger,
            tooltip: 'Kadrodan çıkar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Aynı okuldaki meslektaşları listeleyen seçim sayfası.
///
/// Öğretmen okulunu seçtiğinde `school_teachers` dizinine kaydolduğu için
/// bu liste kendiliğinden dolar — kimse ek bir işlem yapmaz.
class _MeslektasSecimi extends StatelessWidget {
  final List<SchoolTeacher> colleagues;
  final String schoolName;

  const _MeslektasSecimi({required this.colleagues, required this.schoolName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ders öğretmeni seç',
            style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            schoolName.isEmpty ? 'Okulunuzdaki öğretmenler' : '$schoolName öğretmenleri',
            style: AppFonts.outfit(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: colleagues.isEmpty
                ? Center(
                    child: Text(
                      'Okulunuzda eklenebilecek başka öğretmen bulunamadı.',
                      textAlign: TextAlign.center,
                      style: AppFonts.outfit(fontSize: 13, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: colleagues.length,
                    itemBuilder: (context, idx) {
                      final c = colleagues[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => Navigator.of(context).pop(c),
                          leading: const Icon(Icons.person_rounded, color: Color(0xFF3B82F6)),
                          title: Text(
                            c.fullName,
                            style: AppFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: c.branch.isEmpty
                              ? null
                              : Text(
                                  c.branch,
                                  style: AppFonts.outfit(fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: const Icon(Icons.add_circle_outline_rounded,
                              size: 20, color: AppColors.primary),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Listede olmayan öğretmen henüz uygulamaya kaydolmamıştır. '
            'Kaydolup okulunu seçtiğinde burada görünür.',
            style: AppFonts.outfit(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }
}
