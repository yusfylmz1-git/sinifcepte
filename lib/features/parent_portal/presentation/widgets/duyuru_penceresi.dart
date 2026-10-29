import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/class_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/gruplu_liste.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/class_announcement_model.dart';
import '../../data/services/communication_ids.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_portal_provider.dart';

/// Sınıf duyurusu yazma (Veliler sayfasındaki "Duyuru yap").
///
/// ## Neden tam sayfa (DEG-9, 30 Ekim 2026)
/// Kullanıcı: "duyuru yap düğmesine basınca açılan duyuru penceresi
/// görünümü çok kötü." Küçük pencerede metin kutusu üç satırdı, tür
/// emojili bir açılır listede saklıydı, gönder düğmesi klavyenin altında
/// kalıyordu. Zümre/ŞÖK'te onaylanan tam sayfa kısa form düzenine geçti:
/// tür üstte dokunmalık seçenek, metin geniş, Gönder hep altta.
///
/// Yazar ve sınıf odası kimliği [TeacherIdentity.resolve] ile çözülür.
/// Eskiden `teacher.id` kullanılıyordu; profildeki kimlik yer tutucu
/// olduğunda sunucu kuralı (`authorUid == request.auth.uid`) yazmayı
/// reddediyordu.
Future<void> sinifDuyurusuYaz(
  BuildContext context,
  WidgetRef ref,
  ClassModel classModel,
) async {
  final taslak = await Navigator.of(context).push<DuyuruTaslagi>(
    MaterialPageRoute(builder: (_) => DuyuruYazEkrani(sinifAdi: classModel.name)),
  );
  if (taslak == null || !context.mounted) return;
  await _yayinla(
    context,
    ref,
    classModel,
    title: taslak.baslik,
    content: taslak.metin,
    priority: taslak.tur,
    eventAt: taslak.tarih,
  );
}

typedef DuyuruTaslagi = ({String baslik, String metin, String tur, DateTime? tarih});

/// Duyuru türleri: değer bulutta `priority` alanına yazılır.
const _turler = <(String, String, IconData)>[
  ('normal', 'Duyuru', Icons.campaign_outlined),
  ('urgent', 'Acil', Icons.priority_high_rounded),
  ('exam', 'Sınav', Icons.edit_note_rounded),
  ('event', 'Etkinlik', Icons.event_outlined),
];

class DuyuruYazEkrani extends StatefulWidget {
  const DuyuruYazEkrani({super.key, required this.sinifAdi});

  final String sinifAdi;

  @override
  State<DuyuruYazEkrani> createState() => _DuyuruYazEkraniState();
}

class _DuyuruYazEkraniState extends State<DuyuruYazEkrani> {
  final _baslik = TextEditingController();
  final _metin = TextEditingController();
  String _tur = 'normal';

  // Sınav ve etkinlik duyurularında tarih sorulur; veli takviminde bu
  // tarihte görünür. Ayrı bir "sınav" koleksiyonu açılmadı — duyuru
  // altyapısı kullanıldığı için ek maliyet doğmaz.
  DateTime? _tarih;

  bool get _tarihli => _tur == 'exam' || _tur == 'event';
  bool get _hazir => _baslik.text.trim().isNotEmpty && _metin.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _baslik.addListener(() => setState(() {}));
    _metin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _baslik.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final now = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: _tarih ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );
    if (secilen != null) setState(() => _tarih = secilen);
  }

  void _gonder() => Navigator.of(context).pop<DuyuruTaslagi>((
        baslik: _baslik.text.trim(),
        metin: _metin.text.trim(),
        tur: _tur,
        tarih: _tarihli ? _tarih : null,
      ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soluk = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'Duyuru yaz',
        subtitle: '${widget.sinifAdi} velilerine',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  const GrupBasligi('TÜR'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final t in _turler) _turSecenegi(isDark, t)],
                  ),
                  if (_tarihli) ...[
                    const SizedBox(height: 18),
                    GrupBasligi(_tur == 'exam' ? 'SINAV TARİHİ' : 'ETKİNLİK TARİHİ'),
                    const SizedBox(height: 7),
                    GrupKutusu(satirlar: [
                      GrupSatiri(
                        key: const ValueKey('duyuru_tarih'),
                        ikon: Icons.event_outlined,
                        ad: _tarih == null ? 'Tarih seçin' : AppDateFormatter.formatTurkishDate(_tarih!),
                        alt: _tarih == null ? 'İsteğe bağlı; veli takviminde bu günde görünür' : 'Değiştirmek için dokunun',
                        onTap: _tarihSec,
                      ),
                    ]),
                  ],
                  const SizedBox(height: 18),
                  const GrupBasligi('BAŞLIK'),
                  const SizedBox(height: 7),
                  TextField(
                    key: const ValueKey('duyuru_baslik'),
                    controller: _baslik,
                    // Uzunluk sınırı: sınırsız metin Firestore doküman
                    // sınırını (1 MiB) zorluyor ve arayüzü taşırıyordu.
                    maxLength: 100,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _alan(isDark, 'Örn: Veli toplantısı'),
                  ),
                  const SizedBox(height: 6),
                  const GrupBasligi('METİN'),
                  const SizedBox(height: 7),
                  TextField(
                    key: const ValueKey('duyuru_metin'),
                    controller: _metin,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _alan(isDark, 'Velilere iletmek istediğiniz ayrıntılar'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bu sınıfa bağlı veliler uygulamayı açınca görür.',
                    style: AppFonts.outfit(fontSize: 11.5, color: soluk),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: FilledButton.icon(
                key: const ValueKey('duyuru_gonder'),
                onPressed: _hazir ? _gonder : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Gönder'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _turSecenegi(bool isDark, (String, String, IconData) t) {
    final (deger, ad, ikon) = t;
    final secili = _tur == deger;
    final renk = secili
        ? (isDark ? AppColors.primaryLight : AppColors.primary)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569));
    return Material(
      color: secili
          ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.10)
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: secili
              ? AppColors.primary.withValues(alpha: 0.7)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: InkWell(
        key: ValueKey('duyuru_tur_$deger'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() {
          _tur = deger;
          // Tarih yalnızca sınav ve etkinlikte anlamlı.
          if (!_tarihli) _tarih = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 17, color: renk),
              const SizedBox(width: 6),
              Text(ad,
                  style: AppFonts.outfit(
                      fontSize: 12.5, fontWeight: secili ? FontWeight.w700 : FontWeight.w500, color: renk)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _alan(bool isDark, String ipucu) {
    final cizgi = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    OutlineInputBorder kenar(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: ipucu,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: kenar(cizgi),
      focusedBorder: kenar(AppColors.primary, 1.5),
      border: kenar(cizgi),
    );
  }
}

Future<void> _yayinla(
  BuildContext context,
  WidgetRef ref,
  ClassModel classModel, {
  required String title,
  required String content,
  required String priority,
  required DateTime? eventAt,
}) async {
  final teacher = ref.read(teacherProfileProvider);
  final uid = TeacherIdentity.resolve(teacher);
  final newAnn = ClassAnnouncementModel(
    id: CommunicationIds.announcement(authorUid: uid),
    classId: classModel.id!,
    className: classModel.name,
    authorTeacherId: uid,
    authorTeacherName: teacher.fullName,
    title: title,
    content: content,
    priority: priority,
    createdAt: DateTime.now(),
  );

  // Öğretmenin cihazındaki kayıt yalnızca kendi arşividir.
  final repo = ref.read(parentPortalRepositoryProvider);
  await repo.createAnnouncement(newAnn);
  ref.invalidate(classAnnouncementsProvider(classModel.id!));

  // Buluta da yayımla: veliler duyuruyu ancak buradan görür.
  var published = false;
  if (CloudIds.isValidUid(uid)) {
    final cloudRepo = ref.read(cloudCommunicationRepositoryProvider);
    final classCloudId = CloudIds.classId(
      teacherUid: uid,
      localClassId: classModel.id!,
    );

    // Sınıf odası yoksa duyuru yazılamaz (kurallar bu dokümanın
    // varlığına dayanır).
    await cloudRepo.ensureClassRoom(
      classCloudId: classCloudId,
      className: classModel.name,
      teacherUid: uid,
      teacherName: teacher.fullName,
      schoolId: teacher.schoolId ?? '',
      schoolName: teacher.schoolName,
    );

    published = await cloudRepo.publishAnnouncement(
      classCloudId: classCloudId,
      announcementId: newAnn.id,
      title: title,
      content: content,
      authorName: teacher.fullName,
      authorUid: uid,
      priority: priority,
      eventAt: eventAt,
    );
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        published
            ? 'Duyuru velilere gönderildi.'
            : 'Duyuru cihazınıza kaydedildi ancak velilere gönderilemedi. '
                'İnternet bağlantısı gelince tekrar yayınlayın.',
      ),
      backgroundColor: published ? const Color(0xFF10B981) : Colors.orange,
      duration: Duration(seconds: published ? 3 : 6),
    ),
  );
}
