import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../clubs/presentation/screens/clubs_hub_screen.dart';
import 'special_days_view.dart';

/// Sınıf dışı resmî evraklar.
///
/// ## Neden bu ekran var
/// Burada eskiden "Analiz & Rapor" kartı duruyordu. O kart bir **iş**
/// değil, bir **çıktı türü** tanımlıyordu: öğretmen "rapor işi
/// yapayım" diye düşünmez, "sınav sonucuna bakayım" der. Bu yüzden
/// içindeki üç rapor kendi işinin altına taşındı:
///
/// * Soru bazlı sınav analizi → Sınav İşlemleri
/// * e-Okul karne görüşü      → Sınav İşlemleri
/// * Katılım raporları        → Ders İçi Katılım
///
/// Kalan yer, hiçbir sınıfa bağlı olmayan evraklara ayrıldı:
/// öğretmen dosyası, sosyal kulüp planı, belirli gün ve haftalar.
/// Bunlar sırayla eklenecek.
class OtherDocumentsView extends StatelessWidget {
  const OtherDocumentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    /// Planlanan belgeler. `hazir: false` olanlar gri görünür.
    const planlanan = <({String ad, String aciklama, IconData ikon})>[
      (
        ad: 'Öğretmen Dosyası',
        aciklama: 'Özlük bilgileri, ders programı ve yıllık plan özeti',
        ikon: Icons.badge_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Diğer Evraklar',
        subtitle: 'Öğretmen Dosyası & Planlar',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _tasindiNotu(isDark),
            const SizedBox(height: 18),
            _hazirKart(
              context,
              isDark,
              ad: 'Belirli Gün ve Haftalar',
              aciklama: 'Çizelge · etkinlik planı, çalışma raporu, pano PDF',
              ikon: Icons.event_available_rounded,
              hedef: const SpecialDaysView(),
            ),
            const SizedBox(height: 18),
            _hazirKart(
              context,
              isDark,
              ad: 'Sosyal Kulüpler',
              aciklama: 'EK-4 çizelgesi · yıllık plan, üye listesi, faaliyet raporu',
              ikon: Icons.groups_2_outlined,
              hedef: const ClubsHubScreen(),
            ),
            const SizedBox(height: 18),
            Text(
              'Yakında',
              style: AppFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            for (final b in planlanan) _yakindaKart(isDark, b),
          ],
        ),
      ),
    );
  }

  /// Kullanıma hazır belge kartı.
  Widget _hazirKart(
    BuildContext context,
    bool isDark, {
    required String ad,
    required String aciklama,
    required IconData ikon,
    required Widget hedef,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => hedef),
        ),
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
    );
  }

  /// Taşınan raporların nereye gittiğini söyler.
  ///
  /// Kullanıcı alışkanlığı önemli: bu ekranda sınav analizini arayan
  /// öğretmen "kayboldu" sanmasın.
  Widget _tasindiNotu(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.moving_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(
                'Raporlar taşındı',
                style: AppFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sınav analizi ve karne görüşü artık Sınav İşlemleri’nde, '
            'katılım raporu Ders İçi Katılım’da. Her rapor, verisini '
            'ürettiğiniz ekranın yanında.',
            style: AppFonts.outfit(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yakindaKart(
    bool isDark,
    ({String ad, String aciklama, IconData ikon}) b,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(b.ikon,
                size: 19, color: isDark ? Colors.white38 : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.ad,
                  style: AppFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  b.aciklama,
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Yakında',
              style: AppFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
