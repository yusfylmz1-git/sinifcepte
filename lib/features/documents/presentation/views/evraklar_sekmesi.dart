import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/gruplu_liste.dart';
import '../../../analytics/presentation/views/exam_analysis_list_view.dart';
import '../../../analytics/presentation/widgets/class_report_card_comments_modal.dart';
import '../../../classes/screens/class_list_screen.dart';
import '../../../clubs/presentation/screens/clubs_hub_screen.dart';
import '../../../exam_operations/presentation/views/project_tracking_view.dart';
import '../../../exam_operations/presentation/views/quiz_list_view.dart';
import '../../../guidance/presentation/screens/guidance_hub_screen.dart';
import '../../../student_photos/presentation/eokul_foto_merkezi_ekrani.dart';
import '../../data/council_minutes.dart';
import '../../data/special_days_repository.dart';
import 'annual_plans_view.dart';
import 'council_minutes_view.dart';
import 'daily_plans_view.dart';
import 'special_days_view.dart';
import 'teacher_file_view.dart';

/// Evraklar: sınıfa bağlı olmayan bütün evrakların TEK kataloğu.
///
/// ## Neden tek katalog (17 Ekim 2026)
/// Evraklara beş ayrı kapıdan giriliyordu: ana sayfadaki "Diğer Evraklar",
/// "Sınav İşlemleri" ve "Rehberlik" kartları, üç çizgili menüdeki
/// "Raporlar" ve "e-Okul foto". Öğretmen bir belgeyi ararken önce hangi
/// kapıdan gireceğini bulmak zorundaydı. Artık hepsi burada; Özet ve
/// Cepte araması yalnız kısayol verir.
///
/// 17 Ekim'de alt çubukta sekmeydi; 26 Ekim 2026'dan beri Özet'teki
/// "Evraklar" düğmesinden sayfa olarak açılır (kullanıcı kararı).
///
/// ## Her belge tek dokunuşta (DEG-1, 30 Ekim 2026)
/// Kullanıcı başka bir uygulamanın evrak düzenini gösterdi: "adam düzenini
/// çok güzel kurmuş, bizde çok karışık." Bizde kartların çoğu bir ara
/// merkez açıyordu (Kurul Tutanakları → iki tutanak, Sınav İşlemleri →
/// beş iş); belgeye iki-üç dokunuşta varılıyordu. Akış alındı, görünüş
/// alınmadı: belgeler Rehberlik Dosyası'ndaki gruplu listede, her satır
/// doğrudan belgeyi açar. Rehberlik tek satır kaldı: belgeleri sınıf
/// seçilerek üretilir, seçici kendi sayfasında.
///
/// Sınıfa BAĞLI evraklar (oturma planı, nöbetçi listesi, öğrenci listesi,
/// veli rehberi) buraya taşınmaz: önce "hangi sınıf?" sorusunu gerektirir,
/// evleri sınıf sayfası. Son satır öğretmeni sınıf listesine götürür; aynı
/// ekranı ikinci bir kapıdan açmaz.
class EvraklarSekmesi extends ConsumerWidget {
  const EvraklarSekmesi({super.key});

  static Future<void> ac(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const EvraklarSekmesi()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void ac(Widget hedef) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => hedef),
        );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Evraklarım',
        subtitle: 'Dosya, plan, kurul, sınav ve rehberlik evrakları',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            const GrupBasligi('DOSYA VE PLANLAR'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              // Teftişte ilk istenen dosya bu; listenin başında durur.
              GrupSatiri(
                key: const ValueKey('evrak_ogretmen_dosyasi'),
                ikon: Icons.badge_outlined,
                ad: 'Öğretmen Dosyası',
                alt: '13 resmî evrak · kapak, künye, İstiklâl Marşı',
                onTap: () => ac(const TeacherFileView()),
              ),
              GrupSatiri(
                key: const ValueKey('evrak_yillik_plan'),
                ikon: Icons.calendar_month_outlined,
                ad: 'Yıllık Planlar',
                alt: 'Ünitelendirilmiş plan taslağı · A4 yatay PDF',
                onTap: () => ac(const AnnualPlansView()),
              ),
              GrupSatiri(
                key: const ValueKey('evrak_gunluk_plan'),
                ikon: Icons.menu_book_outlined,
                ad: 'Günlük Planlar',
                alt: 'Ders işleniş planı · sınıf ve hafta bazlı PDF',
                onTap: () => ac(const DailyPlansView()),
              ),
            ]),
            const SizedBox(height: 18),
            const GrupBasligi('KURULLAR'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              GrupSatiri(
                key: const ValueKey('evrak_zumre'),
                ikon: Icons.groups_outlined,
                ad: 'Zümre Öğretmenler Kurulu',
                alt: 'Sene başı, 2. dönem ve yıl sonu gündemi hazır',
                onTap: () => CouncilMinutesView.open(context, CouncilKind.zumre),
              ),
              GrupSatiri(
                key: const ValueKey('evrak_sok'),
                ikon: Icons.account_tree_outlined,
                ad: 'Şube Öğretmenler Kurulu',
                alt: 'Şube kadrosu, imza sirküsü, öğrenci ızgarası',
                onTap: () => CouncilMinutesView.open(context, CouncilKind.sok),
              ),
            ]),
            const SizedBox(height: 18),
            const GrupBasligi('SINAV VE DEĞERLENDİRME'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              GrupSatiri(
                key: const ValueKey('evrak_sinav_analizi'),
                ikon: Icons.insights_outlined,
                ad: 'Sınav Analizleri',
                alt: 'Soru bazlı başarı ve MEB analiz raporu',
                onTap: () => ac(const ExamAnalysisListView()),
              ),
              GrupSatiri(
                key: const ValueKey('evrak_karne_gorusu'),
                ikon: Icons.rate_review_outlined,
                ad: 'e-Okul Karne Görüşü',
                alt: 'Ders içi katılımdan görüş ve katılım puanı',
                onTap: () => ClassReportCardCommentsModal.show(context),
              ),
              GrupSatiri(
                key: const ValueKey('evrak_quiz'),
                ikon: Icons.table_chart_outlined,
                ad: 'Quiz ve Sözlü Notlar',
                alt: 'Her quiz bir sütun, ortalama kendiliğinden',
                onTap: () => ac(const QuizListView()),
              ),
              GrupSatiri(
                key: const ValueKey('evrak_proje'),
                ikon: Icons.assignment_turned_in_outlined,
                ad: 'Proje ve Ödev Değerlendirme',
                alt: 'Konu, teslim ve 100 puanlık ölçekle puanlama',
                onTap: () => ac(const ProjectTrackingView()),
              ),
            ]),
            const SizedBox(height: 18),
            const GrupBasligi('REHBERLİK'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              GrupSatiri(
                key: const ValueKey('evrak_rehberlik'),
                ikon: Icons.psychology_outlined,
                ad: 'Rehberlik ve BEP',
                alt: 'BEP, rehberlik dosyası, görüşme formları',
                onTap: () => ac(const GuidanceHubScreen()),
              ),
            ]),
            const SizedBox(height: 18),
            const GrupBasligi('OKUL ETKİNLİKLERİ VE İDARİ İŞLER'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              _BelirliGunSatiri(onTap: () => ac(const SpecialDaysView())),
              GrupSatiri(
                key: const ValueKey('evrak_kulupler'),
                ikon: Icons.groups_2_outlined,
                ad: 'Sosyal Kulüpler',
                alt: 'EK-4 çizelgesi, yıllık plan, faaliyet raporu',
                onTap: () => ac(const ClubsHubScreen()),
              ),
              GrupSatiri(
                key: const ValueKey('evrak_eokul_foto'),
                ikon: Icons.photo_camera_front_outlined,
                ad: 'e-Okul Foto',
                alt: 'Öğrenci fotoğrafı, tam 133×171 piksel',
                onTap: () => ac(const EokulFotoMerkeziEkrani()),
              ),
            ]),
            const SizedBox(height: 18),
            const GrupBasligi('SINIFA BAĞLI EVRAKLAR'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              GrupSatiri(
                key: const ValueKey('evrak_sinif'),
                ikon: Icons.class_outlined,
                ad: 'Sınıf Evrakları',
                alt: 'Sınıf seçip açılır: oturma planı, listeler',
                onTap: () => ClassListScreen.ac(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// "Belirli Gün ve Haftalar" satırı; altında yaklaşan etkinlikli gün.
class _BelirliGunSatiri extends StatefulWidget {
  const _BelirliGunSatiri({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BelirliGunSatiri> createState() => _BelirliGunSatiriState();
}

class _BelirliGunSatiriState extends State<_BelirliGunSatiri> {
  late final Future<String?> _siradaki = _bul();

  /// Önümüzdeki iki haftada pano/tören çalışması yapılan ilk gün.
  Future<String?> _bul() async =>
      siradakiBelirliGun(await SpecialDaysRepository().upcoming(gunSayisi: 14), DateTime.now());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _siradaki,
      builder: (context, s) => GrupSatiri(
        key: const ValueKey('evrak_belirli_gunler'),
        ikon: Icons.event_available_outlined,
        ad: 'Belirli Gün ve Haftalar',
        alt: s.data ?? 'Çizelge, etkinlik planı, çalışma raporu, pano',
        onTap: widget.onTap,
      ),
    );
  }
}

/// Belirli Gün satırının durumu: [yakin] içindeki ilk etkinlikli gün ve
/// ona kalan süre; yoksa `null`.
String? siradakiBelirliGun(List<({SpecialDay madde, DateTime tarih})> yakin, DateTime bugun) {
  final ilk = yakin.where((y) => y.madde.etkinlikli).firstOrNull;
  if (ilk == null) return null;
  final gun = DateTime(ilk.tarih.year, ilk.tarih.month, ilk.tarih.day)
      .difference(DateTime(bugun.year, bugun.month, bugun.day))
      .inDays;
  // Bir hafta bugünden önce başladıysa `upcoming` ilk gününü bugün verir.
  final ne = gun == 0
      ? (ilk.madde.tur == 'aralik' ? 'bu hafta' : 'bugün')
      : gun == 1
          ? 'yarın'
          : '$gun gün sonra';
  return 'Sıradaki: ${ilk.madde.ad} · $ne';
}
