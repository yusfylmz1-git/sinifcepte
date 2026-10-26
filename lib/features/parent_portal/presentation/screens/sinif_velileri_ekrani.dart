import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/liste_arama_kutusu.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../../classes/screens/parent_contacts_screen.dart';
import '../../data/models/parent_link_model.dart';
import '../../data/repositories/cloud_communication_repository.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/gelen_kutusu_provider.dart';
import '../../providers/parent_portal_provider.dart';
import '../../providers/parent_token_provider.dart';
import '../widgets/class_reference_codes_modal.dart';
import '../widgets/duyuru_penceresi.dart';
import '../widgets/parent_teacher_chat_modal.dart';
import '../widgets/sinif_kadrosu_bolumu.dart';
import 'gelen_kutusu_ekrani.dart';

/// Rehberlik sınıfının Veliler sayfası: tek sayfa, sekmesiz.
///
/// ## Neden baştan yazıldı (18 Ekim 2026)
/// Veli Paneli uygulamanın içinde ikinci bir uygulamaydı: kendi alt
/// çubuğunda beş sekme (Özet, Mesajlar, Duyurular, Veliler, Kadro), üçünün
/// içinde ikinci bir beş sekme. Kadro en dipteydi. Kullanıcı: "veliler
/// bölümünü baştan dizayn etmeliyiz, çok karışık; kadroya öğretmen katma
/// işi daha görünür olmalı". Kullanıcının seçtiği yerleşim: tek sayfa,
/// yukarıdan aşağı yanıt bekleyenler, yazışmalar, derse giren
/// öğretmenler, veli bağlantıları.
///
/// ## "Yanıt bekleyen" ne demek
/// Durumu sunucuda tutulan işler: onay bekleyen randevu ve "görüldü"
/// denmemiş veli bildirimi. Mesajlar gelen kutusunda (üst çubukta da):
/// okunmamış sayısı cihazda tutulur, sohbet açılınca sıfırlanır (18 Ekim
/// 2026).
class SinifVelileriEkrani extends ConsumerWidget {
  final ClassModel classModel;

  const SinifVelileriEkrani({super.key, required this.classModel});

  static Future<void> ac(BuildContext context, ClassModel classModel) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SinifVelileriEkrani(classModel: classModel)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = TeacherIdentity.resolve(ref.watch(teacherProfileProvider));
    final bulutVar = CloudIds.isValidUid(uid);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: '${classModel.name} Velileri',
        subtitle: 'Duyuru, mesaj, kadro ve veli kodları',
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (!bulutVar) return;
            final cls = CloudIds.classId(teacherUid: uid, localClassId: classModel.id ?? 0);
            ref.invalidate(classLinkedParentsProvider(classModel));
            ref.invalidate(classAppointmentsCloudProvider(cls));
            ref.invalidate(classStatusReportsCloudProvider(cls));
            ref.invalidate(classStaffProvider(cls));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (bulutVar) ...[
                _BaglantiOzeti(classModel: classModel),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('veliler_duyuru_yap'),
                        onPressed: () => sinifDuyurusuYaz(context, ref, classModel),
                        icon: const Icon(Icons.campaign_rounded, size: 19),
                        label: const Text('Duyuru yap'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _git(context, SinifDuyurulariEkrani(classModel: classModel)),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Gönderilenler'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                _baslik(isDark, 'Yanıt bekleyenler'),
                _Bekleyenler(classModel: classModel, uid: uid),
                _baslik(isDark, 'Yazışmalar'),
                _GelenKutusuSatiri(
                  classCloudId: CloudIds.classId(teacherUid: uid, localClassId: classModel.id ?? 0),
                ),
                _satir(
                  isDark,
                  ikon: Icons.edit_note_rounded,
                  baslik: 'Bir veliye yaz',
                  altBaslik: 'Bağlı velilerin listesi; dokununca sohbet açılır',
                  onTap: () => _git(context, VeliYazismalariEkrani(classModel: classModel)),
                ),
                _baslik(isDark, 'Derse giren öğretmenler'),
                SinifKadrosuBolumu(classModel: classModel),
              ] else
                _bilgi(
                  isDark,
                  'Duyuru, mesaj ve kadro velilerle paylaşılan buluta bağlıdır; '
                  'Google ile giriş yaptığınızda açılır. Veli rehberi girişsiz de çalışır.',
                ),
              _baslik(isDark, 'Veli bağlantıları'),
              if (bulutVar)
                _satir(
                  isDark,
                  ikon: Icons.vpn_key_rounded,
                  baslik: 'Veli kodları',
                  altBaslik: 'Velinin uygulamaya bağlanma kodu; yazdır ya da paylaş',
                  onTap: () => ClassReferenceCodesModal.show(context, classModel: classModel),
                ),
              _satir(
                isDark,
                ikon: Icons.contact_phone_rounded,
                baslik: 'Veli rehberi',
                altBaslik: 'Telefonlar; arama ve WhatsApp',
                onTap: () => _git(context, ParentContactsScreen(classModel: classModel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _git(BuildContext context, Widget hedef) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => hedef));

/// Bölüm başlığı. toUpperCase() YOK: Dart 'i'yi 'I' yapar.
Widget _baslik(bool isDark, String metin) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        metin,
        style: AppFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );

Widget _satir(
  bool isDark, {
  required IconData ikon,
  required String baslik,
  required String altBaslik,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(ikon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: AppFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      altBaslik,
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white38 : Colors.grey),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _bilgi(bool isDark, String metin) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        metin,
        style: AppFonts.outfit(
          fontSize: 12.5,
          height: 1.45,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );

/// "Gelen kutusu · 3 okunmamış" satırı (bu sınıfın mesajları).
class _GelenKutusuSatiri extends ConsumerWidget {
  final String classCloudId;

  const _GelenKutusuSatiri({required this.classCloudId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = ref.watch(gelenKutusuProvider).valueOrNull;
    final okunmamis = d == null
        ? 0
        : d.sohbetler
            .where((o) => o.classCloudId == classCloudId)
            .fold<int>(0, (t, o) => t + o.okunmamis);
    return _satir(
      isDark,
      ikon: Icons.inbox_rounded,
      baslik: okunmamis == 0 ? 'Gelen kutusu' : 'Gelen kutusu · $okunmamis okunmamış',
      altBaslik: 'Velilerin size yazdıkları; okunmamışlar önde',
      onTap: () => GelenKutusuEkrani.ac(context, sinif: classCloudId),
    );
  }
}

/// "18/28 öğrencinin velisi bağlı".
class _BaglantiOzeti extends ConsumerWidget {
  final ClassModel classModel;

  const _BaglantiOzeti({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ogrenci = ref.watch(studentListProvider(classModel.id!)).valueOrNull?.length;
    final baglar = ref.watch(classLinkedParentsProvider(classModel)).valueOrNull;
    final bagliOgrenci = baglar?.map((l) => l.studentId).toSet().length;

    final metin = (ogrenci == null || bagliOgrenci == null)
        ? 'Veli bağlantıları yükleniyor…'
        : '$bagliOgrenci/$ogrenci öğrencinin velisi bağlı';

    return Text(
      metin,
      key: const ValueKey('veli_baglanti_ozeti'),
      style: AppFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
    );
  }
}

/// Onay bekleyen randevular ve "görüldü" denmemiş veli bildirimleri.
class _Bekleyenler extends ConsumerWidget {
  final ClassModel classModel;
  final String uid;

  const _Bekleyenler({required this.classModel, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cls = CloudIds.classId(teacherUid: uid, localClassId: classModel.id ?? 0);
    final randevular = ref.watch(classAppointmentsCloudProvider(cls));
    final bildirimler = ref.watch(classStatusReportsCloudProvider(cls));

    if (randevular.isLoading || bildirimler.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (randevular.hasError || bildirimler.hasError) {
      return _bilgi(isDark, 'Randevu ve bildirimler yüklenemedi. İnternet bağlantınızı kontrol edin.');
    }

    final bekleyenRandevu = (randevular.valueOrNull ?? const <CloudAppointment>[])
        .where((a) => a.isPending)
        .toList();
    final bekleyenBildirim = (bildirimler.valueOrNull ?? const <CloudStatusReport>[])
        .where((r) => !r.isAcknowledged)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bekleyenRandevu.isEmpty && bekleyenBildirim.isEmpty)
          _bilgi(isDark, 'Yanıt bekleyen randevu talebi ya da veli bildirimi yok.')
        else ...[
          for (final r in bekleyenBildirim) BildirimKarti(rapor: r, classCloudId: cls),
          for (final a in bekleyenRandevu) RandevuKarti(randevu: a, classCloudId: cls),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _git(context, VeliGecmisiEkrani(classModel: classModel)),
            child: const Text('Geçmiş randevu ve bildirimler'),
          ),
        ),
      ],
    );
  }
}

/// Veli durum bildirimi (geç gelme, erken çıkış, not) kartı.
class BildirimKarti extends ConsumerWidget {
  final CloudStatusReport rapor;
  final String classCloudId;

  const BildirimKarti({super.key, required this.rapor, required this.classCloudId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = rapor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(r.typeIcon, size: 18, color: r.typeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${r.studentName} · ${r.relation}: ${r.parentName}',
                  style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!r.isAcknowledged)
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(cloudCommunicationRepositoryProvider).acknowledgeStatusReport(
                          classCloudId: classCloudId,
                          reportId: r.id,
                        );
                    ref.invalidate(classStatusReportsCloudProvider(classCloudId));
                    ref.invalidate(gelenKutusuProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Görüldü', style: TextStyle(fontSize: 11.5)),
                )
              else
                const Text('Görüldü ✅',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${r.title}: ${r.details}',
            style: AppFonts.outfit(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt),
              style: AppFonts.outfit(fontSize: 10.5, color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Veli görüşme randevusu kartı; bekleyen talepte Onayla / Reddet.
class RandevuKarti extends ConsumerWidget {
  final CloudAppointment randevu;
  final String classCloudId;

  const RandevuKarti({super.key, required this.randevu, required this.classCloudId});

  Future<void> _yanitla(WidgetRef ref, String durum) async {
    await ref.read(cloudCommunicationRepositoryProvider).updateAppointmentStatus(
          classCloudId: classCloudId,
          appointmentId: randevu.id,
          status: durum,
        );
    ref.invalidate(classAppointmentsCloudProvider(classCloudId));
    ref.invalidate(gelenKutusuProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final a = randevu;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Randevu · ${a.studentName} · ${a.parentName} (${a.relation})',
                  style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(a.statusTitleTr,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: a.statusColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${a.teacherName} · ${DateFormat('dd.MM.yyyy').format(a.appointmentDate)} ${a.timeSlot}',
            style: AppFonts.outfit(fontSize: 11.5, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text('Konu: ${a.topic}',
              style: AppFonts.outfit(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87)),
          if (a.isPending) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _yanitla(ref, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reddet', style: TextStyle(fontSize: 11.5)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _yanitla(ref, 'confirmed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Onayla', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bağlı velilerin listesi; dokununca sohbet açılır.
class VeliYazismalariEkrani extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const VeliYazismalariEkrani({super.key, required this.classModel});

  @override
  ConsumerState<VeliYazismalariEkrani> createState() => _VeliYazismalariEkraniState();
}

class _VeliYazismalariEkraniState extends ConsumerState<VeliYazismalariEkrani> {
  /// Öğrenci ya da veli adıyla arama.
  String _arama = '';

  ClassModel get classModel => widget.classModel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = ref.watch(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);
    final async = ref.watch(classLinkedParentsProvider(classModel));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(title: 'Velilerle yazışmalar', subtitle: classModel.name),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Veli listesi yüklenemedi.', style: AppFonts.outfit(color: Colors.grey))),
          data: (baglar) {
            if (baglar.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: _bilgi(
                  isDark,
                  'Henüz bağlı veli yok. Veli kodlarını dağıttıktan sonra veliler burada görünür.',
                ),
              );
            }
            final gorunen = [
              for (final b in baglar)
                if (aramayaUyar(_arama, [b.studentName, b.parentName])) b,
            ];
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(classLinkedParentsProvider(classModel)),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  ListeAramaKutusu(
                    ipucu: 'Öğrenci veya veli adı ara',
                    onChanged: (v) => setState(() => _arama = v),
                  ),
                  const SizedBox(height: 10),
                  if (gorunen.isEmpty) const AramaSonucuYok(metin: 'Aramaya uyan veli yok.'),
                  for (final b in gorunen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _veliSatiri(context, isDark, b, uid, teacher.fullName),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _veliSatiri(BuildContext context, bool isDark, ParentLinkModel link, String uid, String ad) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => ParentTeacherChatModal.show(
          context,
          classCloudId: link.classCloudId.isNotEmpty
              ? link.classCloudId
              : CloudIds.classId(teacherUid: uid, localClassId: classModel.id ?? 0),
          studentCloudId: link.studentCloudId.isNotEmpty
              ? link.studentCloudId
              : CloudIds.studentId(teacherUid: uid, localStudentId: link.studentId),
          studentName: link.studentName,
          parentUserId: link.parentUserId,
          selfName: ad,
          selfUid: uid,
          asTeacher: true,
          counterpartName: '${link.relation}: ${link.parentName}',
          // Öğretmen kendi sohbetini açar.
          teacherUid: uid,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  link.studentName.isNotEmpty ? link.studentName.characters.first : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.studentName,
                      style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${link.relation}: ${link.parentName}',
                      style: AppFonts.outfit(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tüm randevular ve veli bildirimleri (yanıtlanmışlar dahil).
class VeliGecmisiEkrani extends ConsumerWidget {
  final ClassModel classModel;

  const VeliGecmisiEkrani({super.key, required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = TeacherIdentity.resolve(ref.watch(teacherProfileProvider));
    final cls = CloudIds.classId(teacherUid: uid, localClassId: classModel.id ?? 0);
    final randevular = ref.watch(classAppointmentsCloudProvider(cls)).valueOrNull ?? const [];
    final bildirimler = ref.watch(classStatusReportsCloudProvider(cls)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(title: 'Randevu ve bildirimler', subtitle: classModel.name),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _baslik(isDark, 'Veli bildirimleri'),
            if (bildirimler.isEmpty) _bilgi(isDark, 'Veli bildirimi yok.'),
            for (final r in bildirimler) BildirimKarti(rapor: r, classCloudId: cls),
            _baslik(isDark, 'Randevu talepleri'),
            if (randevular.isEmpty) _bilgi(isDark, 'Randevu talebi yok.'),
            for (final a in randevular) RandevuKarti(randevu: a, classCloudId: cls),
          ],
        ),
      ),
    );
  }
}

/// Gönderilen sınıf duyuruları; okunma sayısı ve silme.
class SinifDuyurulariEkrani extends ConsumerWidget {
  final ClassModel classModel;

  const SinifDuyurulariEkrani({super.key, required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = TeacherIdentity.resolve(ref.watch(teacherProfileProvider));
    final cls = CloudIds.classId(teacherUid: uid, localClassId: classModel.id ?? 0);
    final async = ref.watch(classAnnouncementsProvider(classModel.id!));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(title: 'Gönderilen duyurular', subtitle: classModel.name),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Duyurular yüklenemedi.', style: AppFonts.outfit(color: Colors.grey))),
          data: (duyurular) {
            if (duyurular.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: _bilgi(isDark, 'Henüz duyuru gönderilmedi.'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: duyurular.length,
              itemBuilder: (context, i) {
                final a = duyurular[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a.priorityIcon, size: 16, color: a.priorityColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              a.title,
                              style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('👁️ ${a.readCount}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.content,
                        style: AppFonts.outfit(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd.MM.yyyy HH:mm').format(a.createdAt),
                              style: AppFonts.outfit(fontSize: 10.5, color: Colors.grey)),
                          IconButton(
                            tooltip: 'Duyuruyu sil',
                            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              await ref.read(parentPortalRepositoryProvider).deleteAnnouncement(a.id);
                              // Buluttan da sil: aksi hâlde duyuru öğretmende
                              // kaybolur ama velilerde görünmeye devam ederdi.
                              if (CloudIds.isValidUid(uid)) {
                                await ref.read(cloudCommunicationRepositoryProvider).deleteAnnouncement(
                                      classCloudId: cls,
                                      announcementId: a.id,
                                    );
                              }
                              ref.invalidate(classAnnouncementsProvider(classModel.id!));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
