import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/gruplu_liste.dart';
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
///
/// ## Gruplu liste (DEG-9, 30 Ekim 2026)
/// Kullanıcı: "Sınıfım/Veliler bölümü çok karışık, bir düzen yok." Sayfada
/// iki büyük düğme, ayrı ayrı kartlar, düz yazı ve tam genişlikte bir
/// "ekle" düğmesi yan yana duruyordu. Bölüm sırası korundu; hepsi Rehberlik
/// Dosyası ile Sınav İşlemleri'nin gruplu listesine geçti. Veli kodları
/// üstteki bağlantı kartına, veli rehberi İletişim grubuna taşındı.
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
    final cls = CloudIds.classId(teacherUid: uid, localClassId: classModel.id ?? 0);
    final rehber = GrupSatiri(
      ikon: Icons.contact_phone_outlined,
      ad: 'Veli rehberi',
      alt: 'Telefonlar; arama ve WhatsApp',
      onTap: () => _git(context, ParentContactsScreen(classModel: classModel)),
    );

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
            ref.invalidate(classLinkedParentsProvider(classModel));
            ref.invalidate(classAppointmentsCloudProvider(cls));
            ref.invalidate(classStatusReportsCloudProvider(cls));
            ref.invalidate(classStaffProvider(cls));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            children: [
              if (bulutVar) ...[
                _BaglantiKarti(classModel: classModel),
                const SizedBox(height: 18),
                const GrupBasligi('DUYURULAR'),
                const SizedBox(height: 7),
                GrupKutusu(satirlar: [
                  GrupSatiri(
                    key: const ValueKey('veliler_duyuru_yap'),
                    ikon: Icons.campaign_outlined,
                    ad: 'Duyuru yap',
                    alt: 'Genel, acil, sınav ya da etkinlik duyurusu',
                    onTap: () => sinifDuyurusuYaz(context, ref, classModel),
                  ),
                  _GonderilenlerSatiri(classModel: classModel),
                ]),
                const SizedBox(height: 18),
                _Bekleyenler(classModel: classModel, classCloudId: cls),
                const SizedBox(height: 18),
                const GrupBasligi('İLETİŞİM'),
                const SizedBox(height: 7),
                GrupKutusu(satirlar: [
                  _GelenKutusuSatiri(classCloudId: cls),
                  GrupSatiri(
                    ikon: Icons.edit_note_rounded,
                    ad: 'Bir veliye yaz',
                    alt: 'Bağlı veliler; dokununca sohbet açılır',
                    onTap: () => _git(context, VeliYazismalariEkrani(classModel: classModel)),
                  ),
                  rehber,
                ]),
                const SizedBox(height: 18),
                const GrupBasligi('DERSE GİREN ÖĞRETMENLER'),
                const SizedBox(height: 7),
                SinifKadrosuBolumu(classModel: classModel),
              ] else ...[
                _bilgi(
                  isDark,
                  'Duyuru, mesaj ve kadro velilerle paylaşılan buluta bağlıdır; '
                  'Google ile giriş yaptığınızda açılır. Veli rehberi girişsiz de çalışır.',
                ),
                const SizedBox(height: 18),
                const GrupBasligi('İLETİŞİM'),
                const SizedBox(height: 7),
                GrupKutusu(satirlar: [rehber]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _git(BuildContext context, Widget hedef) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => hedef));

Color _yazi(bool isDark) => isDark ? Colors.white : const Color(0xFF0F172A);
Color _soluk(bool isDark) => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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

/// Gruplu listedeki satırların simge kutusu; renk satırın türünü söyler.
Widget _simge(IconData ikon, Color renk, bool isDark) => Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: renk.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(ikon, size: 18, color: renk),
    );

/// Satır içi düğme yazısı: temanın düğme yazı tipinden türetilir.
/// `AppFonts.outfit` aile vermediği için düğmenin kendi yazı stilinde
/// kullanılınca tema yazı tipi düşüyordu.
TextStyle? _dugmeYazisi(BuildContext context) =>
    Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12, fontWeight: FontWeight.w700);

/// "Gelen kutusu · 3 okunmamış" satırı (bu sınıfın mesajları).
class _GelenKutusuSatiri extends ConsumerWidget {
  final String classCloudId;

  const _GelenKutusuSatiri({required this.classCloudId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(gelenKutusuProvider).valueOrNull;
    final okunmamis = d == null
        ? 0
        : d.sohbetler
            .where((o) => o.classCloudId == classCloudId)
            .fold<int>(0, (t, o) => t + o.okunmamis);
    return GrupSatiri(
      ikon: Icons.inbox_outlined,
      ad: okunmamis == 0 ? 'Gelen kutusu' : 'Gelen kutusu · $okunmamis okunmamış',
      alt: 'Velilerin size yazdıkları; okunmamışlar önde',
      uyari: okunmamis > 0,
      onTap: () => GelenKutusuEkrani.ac(context, sinif: classCloudId),
    );
  }
}

/// Veli bağlantısı: "18/28 öğrencinin velisi bağlı", ilerleme çubuğu;
/// dokununca veli kodları açılır.
class _BaglantiKarti extends ConsumerWidget {
  final ClassModel classModel;

  const _BaglantiKarti({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ogrenci = ref.watch(studentListProvider(classModel.id!)).valueOrNull?.length;
    final baglar = ref.watch(classLinkedParentsProvider(classModel)).valueOrNull;
    final bagliOgrenci = baglar?.map((l) => l.studentId).toSet().length;
    final yuklendi = ogrenci != null && bagliOgrenci != null;

    final metin = yuklendi ? '$bagliOgrenci/$ogrenci öğrencinin velisi bağlı' : 'Veli bağlantıları yükleniyor…';
    final eksik = yuklendi ? (ogrenci - bagliOgrenci).clamp(0, ogrenci) : 0;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('veli_kodlari'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => ClassReferenceCodesModal.show(context, classModel: classModel),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('VELİ BAĞLANTISI',
                        style: AppFonts.outfit(
                            fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.6)),
                  ),
                  Text('Veli kodları',
                      style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                metin,
                key: const ValueKey('veli_baglanti_ozeti'),
                style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: _yazi(isDark)),
              ),
              if (yuklendi && ogrenci > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (bagliOgrenci / ogrenci).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: AppColors.success,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  eksik == 0
                      ? 'Bütün öğrencilerin velisi bağlı'
                      : '$eksik öğrencinin velisi bağlanmadı · kodunu verin',
                  style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: _soluk(isDark)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Gönderilen duyurular · 3 duyuru".
class _GonderilenlerSatiri extends ConsumerWidget {
  final ClassModel classModel;

  const _GonderilenlerSatiri({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(classAnnouncementsProvider(classModel.id!)).valueOrNull?.length;
    return GrupSatiri(
      key: const ValueKey('veliler_gonderilenler'),
      ikon: Icons.history_rounded,
      ad: 'Gönderilen duyurular',
      alt: n == null || n == 0 ? 'Okunma sayıları ve silme' : '$n duyuru · okunma sayıları ve silme',
      onTap: () => _git(context, SinifDuyurulariEkrani(classModel: classModel)),
    );
  }
}

/// Onay bekleyen randevular ve "görüldü" denmemiş veli bildirimleri.
class _Bekleyenler extends ConsumerWidget {
  final ClassModel classModel;
  final String classCloudId;

  const _Bekleyenler({required this.classModel, required this.classCloudId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cls = classCloudId;
    final randevular = ref.watch(classAppointmentsCloudProvider(cls));
    final bildirimler = ref.watch(classStatusReportsCloudProvider(cls));
    final yukleniyor = randevular.isLoading || bildirimler.isLoading;
    final hata = randevular.hasError || bildirimler.hasError;

    final bekleyenRandevu = (randevular.valueOrNull ?? const <CloudAppointment>[])
        .where((a) => a.isPending)
        .toList();
    final bekleyenBildirim = (bildirimler.valueOrNull ?? const <CloudStatusReport>[])
        .where((r) => !r.isAcknowledged)
        .toList();
    final sayi = bekleyenRandevu.length + bekleyenBildirim.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrupBasligi('YANIT BEKLEYENLER', etiket: yukleniyor || hata || sayi == 0 ? null : '$sayi yeni'),
        const SizedBox(height: 7),
        if (hata)
          _bilgi(isDark, 'Randevu ve bildirimler yüklenemedi. İnternet bağlantınızı kontrol edin.')
        else
          GrupKutusu(satirlar: [
            if (yukleniyor)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (sayi == 0)
              const GrupSatiri(
                ikon: Icons.check_circle_outline_rounded,
                ad: 'Bekleyen yok',
                alt: 'Randevu talebi ya da veli bildirimi gelince burada görünür',
              )
            else ...[
              for (final r in bekleyenBildirim) BildirimKarti(rapor: r, classCloudId: cls),
              for (final a in bekleyenRandevu) RandevuKarti(randevu: a, classCloudId: cls),
            ],
            GrupSatiri(
              ikon: Icons.history_rounded,
              ad: 'Geçmiş randevu ve bildirimler',
              alt: 'Yanıtlananlar dahil',
              onTap: () => _git(context, VeliGecmisiEkrani(classModel: classModel)),
            ),
          ]),
      ],
    );
  }
}

/// Veli durum bildirimi (geç gelme, erken çıkış, not) satırı.
class BildirimKarti extends ConsumerWidget {
  final CloudStatusReport rapor;
  final String classCloudId;

  const BildirimKarti({super.key, required this.rapor, required this.classCloudId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = rapor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _simge(r.typeIcon, r.typeColor, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r.studentName} · ${r.title}',
                        style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _yazi(isDark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (r.isAcknowledged) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('Görüldü',
                          style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(r.details, style: AppFonts.outfit(fontSize: 12, color: _yazi(isDark).withValues(alpha: 0.8))),
                const SizedBox(height: 3),
                Text(
                  '${r.relation}: ${r.parentName} · ${DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt)}',
                  style: AppFonts.outfit(fontSize: 10.5, color: _soluk(isDark)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!r.isAcknowledged) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () async {
                        await ref.read(cloudCommunicationRepositoryProvider).acknowledgeStatusReport(
                              classCloudId: classCloudId,
                              reportId: r.id,
                            );
                        ref.invalidate(classStatusReportsCloudProvider(classCloudId));
                        ref.invalidate(gelenKutusuProvider);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        textStyle: _dugmeYazisi(context),
                      ),
                      child: const Text('Görüldü'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Veli görüşme randevusu satırı; bekleyen talepte Onayla / Reddet.
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _simge(Icons.event_note_rounded, const Color(0xFF3B82F6), isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Randevu · ${a.studentName}',
                        style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _yazi(isDark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(a.statusTitleTr,
                        style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: a.statusColor)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd.MM.yyyy').format(a.appointmentDate)} ${a.timeSlot} · ${a.teacherName}',
                  style: AppFonts.outfit(fontSize: 12, color: _yazi(isDark).withValues(alpha: 0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('Konu: ${a.topic}', style: AppFonts.outfit(fontSize: 12, color: _yazi(isDark).withValues(alpha: 0.8))),
                const SizedBox(height: 3),
                Text(
                  '${a.relation}: ${a.parentName}',
                  style: AppFonts.outfit(fontSize: 10.5, color: _soluk(isDark)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (a.isPending) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _yanitla(ref, 'rejected'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
                          visualDensity: VisualDensity.compact,
                          textStyle: _dugmeYazisi(context),
                        ),
                        child: const Text('Reddet'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _yanitla(ref, 'confirmed'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          textStyle: _dugmeYazisi(context),
                        ),
                        child: const Text('Onayla'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            const GrupBasligi('VELİ BİLDİRİMLERİ'),
            const SizedBox(height: 7),
            if (bildirimler.isEmpty)
              _bilgi(isDark, 'Veli bildirimi yok.')
            else
              GrupKutusu(satirlar: [for (final r in bildirimler) BildirimKarti(rapor: r, classCloudId: cls)]),
            const SizedBox(height: 18),
            const GrupBasligi('RANDEVU TALEPLERİ'),
            const SizedBox(height: 7),
            if (randevular.isEmpty)
              _bilgi(isDark, 'Randevu talebi yok.')
            else
              GrupKutusu(satirlar: [for (final a in randevular) RandevuKarti(randevu: a, classCloudId: cls)]),
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
