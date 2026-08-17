import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/repositories/cloud_communication_repository.dart';
import '../../providers/cloud_communication_provider.dart';

/// Sınıfın ders öğretmeni kadrosunu yöneten modal (Faz 3).
///
/// ## Neden bu ekran var
/// Kullanıcı kararı: **duyuruyu yalnızca sınıf öğretmeni yapar**, ancak
/// veli çocuğunun dersine giren **branş öğretmenleriyle de yazışabilmeli**.
/// Bu iki farklı yetki eksenidir. Duyuru sahiplikle çalışır; mesajlaşma ise
/// bu ekrandan yönetilen kadro üyeliğiyle.
///
/// Kadroya eklenmeyen bir öğretmen veliyle mesajlaşamaz — `firestore.rules`
/// içindeki `isClassStaff()` bunu zorunlu kılar.
///
/// ## Öğretmen kimliği nasıl belirleniyor
/// Mesajlaşma yetkisi Firebase UID'ye bağlıdır, isme değil. Branş
/// öğretmeninin UID'sini sınıf öğretmeni bilemeyeceği için akış şöyledir:
///
/// 1. Sınıf öğretmeni kadroya bir satır ekler (ad + branş + görüşme saati).
/// 2. Sistem o satır için bir **katılım kodu** üretir.
/// 3. Branş öğretmeni kendi hesabından bu kodu girer; UID'si kadroya yazılır.
///
/// Kod girilene kadar satır "beklemede" görünür: veli o öğretmeni listede
/// görür (kimin dersine girdiğini bilir) ama mesajlaşma açılmaz.
class ClassStaffManagerModal extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const ClassStaffManagerModal({super.key, required this.classModel});

  static Future<void> show(BuildContext context, {required ClassModel classModel}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassStaffManagerModal(classModel: classModel),
    );
  }

  @override
  ConsumerState<ClassStaffManagerModal> createState() =>
      _ClassStaffManagerModalState();
}

class _ClassStaffManagerModalState
    extends ConsumerState<ClassStaffManagerModal> {
  bool _busy = false;

  String get _classCloudId {
    final teacher = ref.read(teacherProfileProvider);
    return CloudIds.classId(
      teacherUid: teacher.id,
      localClassId: widget.classModel.id ?? 0,
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(classStaffProvider(_classCloudId));
  }

  Future<void> _addStaffMember() async {
    final nameCtrl = TextEditingController();
    final branchCtrl = TextEditingController();
    final dayCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ders Öğretmeni Ekle',
          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu sınıfa derse giren öğretmeni ekleyin. Eklenen öğretmen, '
                'katılım kodunu girdikten sonra velilerle yazışabilir.',
                style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  hintText: 'Örn: Selin Demir',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: branchCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Branş',
                  hintText: 'Örn: Fizik',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dayCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Görüşme Günü',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final teacher = ref.read(teacherProfileProvider);
      final repo = ref.read(cloudCommunicationRepositoryProvider);

      // Sınıf odası yoksa kadro alt koleksiyonu da yazılamaz.
      await repo.ensureClassRoom(
        classCloudId: _classCloudId,
        className: widget.classModel.name,
        teacherUid: teacher.id,
        teacherName: teacher.fullName,
        schoolId: teacher.schoolId ?? '',
        schoolName: teacher.schoolName,
      );

      final ok = await repo.addPendingStaff(
        classCloudId: _classCloudId,
        teacherName: nameCtrl.text.trim(),
        branch: branchCtrl.text.trim(),
        meetingDay: dayCtrl.text.trim(),
        meetingTime: timeCtrl.text.trim(),
      );

      await _refresh();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Öğretmen kadroya eklendi. Katılım kodunu kendisine iletin.'
                : 'Öğretmen eklenemedi. İnternet bağlantınızı kontrol edin.',
          ),
          backgroundColor: ok ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Kadro ekleme hatası: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Öğretmen eklenirken bir sorun oluştu.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeStaff(CloudStaffMember member) async {
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
      if (mounted) await _refresh();
    } catch (e, stackTrace) {
      debugPrint('Kadrodan çıkarma hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareJoinCode(CloudStaffMember member) {
    Clipboard.setData(ClipboardData(text: member.joinCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Katılım kodu kopyalandı: ${member.joinCode}'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffAsync = ref.watch(classStaffProvider(_classCloudId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFF3B82F6), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.classModel.name} Ders Öğretmenleri',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _addStaffMember,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                tooltip: 'Öğretmen Ekle',
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kadrodaki öğretmenler bu sınıfın velileriyle yazışabilir. '
            'Duyuru yayınlama yetkisi yalnızca sizde kalır.',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: staffAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Kadro yüklenemedi. İnternet bağlantınızı kontrol edin.',
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              data: (staff) {
                if (staff.isEmpty) return _buildEmptyState(isDark);

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: staff.length,
                  itemBuilder: (context, idx) =>
                      _buildStaffCard(staff[idx], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Henüz Ders Öğretmeni Eklenmedi',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Bu sınıfa derse giren branş öğretmenlerini ekleyin; '
              'veliler onları görebilsin ve yazışabilsin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : _addStaffMember,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Öğretmen Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(CloudStaffMember member, bool isDark) {
    final isPending = member.isPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPending ? Colors.orange : const Color(0xFF3B82F6))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  member.isHomeroom
                      ? Icons.star_rounded
                      : Icons.person_rounded,
                  color: isPending ? Colors.orange : const Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.teacherName,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.branch.isNotEmpty)
                      Text(
                        member.branch,
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (member.meetingDay.isNotEmpty ||
                        member.meetingTime.isNotEmpty)
                      Text(
                        'Görüşme: ${member.meetingDay} ${member.meetingTime}'.trim(),
                        style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _busy ? null : () => _removeStaff(member),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.redAccent,
                tooltip: 'Kadrodan Çıkar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _shareJoinCode(member),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Katılım kodu: ${member.joinCode}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.copy_rounded, size: 14, color: Colors.orange),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Öğretmen bu kodu girene kadar velilerle yazışamaz.',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
