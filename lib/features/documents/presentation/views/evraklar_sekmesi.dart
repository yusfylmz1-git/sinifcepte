import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../clubs/presentation/screens/clubs_hub_screen.dart';
import '../../../exam_operations/presentation/views/exam_operations_menu_view.dart';
import '../../../guidance/presentation/screens/guidance_hub_screen.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../../student_photos/presentation/eokul_foto_merkezi_ekrani.dart';
import 'annual_plans_view.dart';
import 'daily_plans_view.dart';
import 'documents_hub_view.dart';
import 'special_days_view.dart';
import 'teacher_file_view.dart';

/// Evraklar sekmesi: sınıfa bağlı olmayan bütün evrakların TEK kataloğu.
///
/// ## Neden alt çubukta (17 Ekim 2026)
/// Evraklara beş ayrı kapıdan giriliyordu: ana sayfadaki "Diğer Evraklar",
/// "Sınav İşlemleri" ve "Rehberlik" kartları, üç çizgili menüdeki
/// "Raporlar" ve "e-Okul foto". Öğretmen bir belgeyi ararken önce hangi
/// kapıdan gireceğini bulmak zorundaydı. Artık hepsi burada; ana sayfa ve
/// Cepte araması yalnız kısayol verir.
///
/// Sınıfa BAĞLI evraklar (oturma planı, nöbetçi listesi, öğrenci listesi,
/// veli rehberi) buraya taşınmaz: önce "hangi sınıf?" sorusunu gerektirir,
/// evleri Sınıflar sekmesi. Son kart öğretmeni oraya götürür; aynı ekranı
/// ikinci bir kapıdan açmaz.
class EvraklarSekmesi extends ConsumerWidget {
  const EvraklarSekmesi({super.key});

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          children: [
            _baslik(isDark, 'Dosya ve planlar'),
            // Teftişte ilk istenen dosya bu; listenin başında durur.
            _kart(
              isDark,
              ad: 'Öğretmen Dosyası',
              aciklama:
                  'Kapak, Atatürk köşesi, İstiklâl Marşı, özlük künyesi · '
                  '13 resmî evrak',
              ikon: Icons.badge_outlined,
              onTap: () => ac(const TeacherFileView()),
            ),
            _kart(
              isDark,
              ad: 'Yıllık Planlar',
              aciklama:
                  'Ünitelendirilmiş yıllık ders planı taslağı · MEB TYMM uyumlu, '
                  'A4 yatay PDF çıktısı · zümre onayı gerekir',
              ikon: Icons.calendar_month_rounded,
              onTap: () => ac(const AnnualPlansView()),
            ),
            _kart(
              isDark,
              ad: 'Günlük Planlar',
              aciklama:
                  'TYMM ders işleniş planı taslağı · Seviye, sınıf ve branş '
                  'bazlı PDF çıktısı · zümre onayı gerekir',
              ikon: Icons.menu_book_rounded,
              onTap: () => ac(const DailyPlansView()),
            ),
            _kart(
              isDark,
              ad: 'Kurul Tutanakları',
              aciklama:
                  'Zümre öğretmenler kurulu · şube öğretmenler kurulu (ŞÖK) · '
                  'gündem hazır, kararı düzenleyip yazdırın',
              ikon: Icons.groups_rounded,
              onTap: () => ac(const DocumentsHubView()),
            ),
            _baslik(isDark, 'Sınav ve rehberlik'),
            // Raporların ayrı bir merkezi yok: soru analizi ve karne
            // görüşü Sınav İşlemleri'nde, katılım raporları Ders İçi
            // Katılım'da (belge, onu üreten işin yanında durur).
            _kart(
              isDark,
              ad: 'Sınav İşlemleri',
              aciklama:
                  'Quiz ve sözlü notları, proje, sınav takvimi · soru analizi '
                  've e-Okul karne görüşü',
              ikon: Icons.assignment_rounded,
              onTap: () => ac(const ExamOperationsMenuView()),
            ),
            _kart(
              isDark,
              ad: 'Rehberlik ve BEP',
              aciklama:
                  'Sınıf rehberlik planı, BEP gelişim raporları, özel eğitim, '
                  'görüşme formları',
              ikon: Icons.psychology_rounded,
              onTap: () => ac(const GuidanceHubScreen()),
            ),
            _baslik(isDark, 'Okul etkinlikleri ve idari işler'),
            _kart(
              isDark,
              ad: 'Belirli Gün ve Haftalar',
              aciklama: 'Çizelge · etkinlik planı, çalışma raporu, pano PDF',
              ikon: Icons.event_available_rounded,
              onTap: () => ac(const SpecialDaysView()),
            ),
            _kart(
              isDark,
              ad: 'Sosyal Kulüpler',
              aciklama:
                  'EK-4 çizelgesi · yıllık plan, üye listesi, faaliyet raporu',
              ikon: Icons.groups_2_outlined,
              onTap: () => ac(const ClubsHubScreen()),
            ),
            _kart(
              isDark,
              ad: 'e-Okul Foto',
              aciklama: 'Öğrenci fotoğrafı, tam 133×171 piksel',
              ikon: Icons.photo_camera_front_outlined,
              onTap: () => ac(const EokulFotoMerkeziEkrani()),
            ),
            const SizedBox(height: 8),
            _kart(
              isDark,
              ad: 'Sınıf Evrakları',
              aciklama:
                  'Oturma planı, nöbetçi listesi, öğrenci listesi, veli rehberi · '
                  'Sınıflar sekmesinde',
              ikon: Icons.class_outlined,
              onTap: () => ref.read(navigationIndexProvider.notifier).state =
                  AnaSekme.siniflar,
            ),
          ],
        ),
      ),
    );
  }

  /// Bölüm başlığı. toUpperCase() YOK: Dart 'i'yi 'I' yapar.
  Widget _baslik(bool isDark, String metin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        metin,
        style: AppFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _kart(
    bool isDark, {
    required String ad,
    required String aciklama,
    required IconData ikon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(ikon, size: 19, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad,
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        aciklama,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: isDark ? Colors.white38 : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
