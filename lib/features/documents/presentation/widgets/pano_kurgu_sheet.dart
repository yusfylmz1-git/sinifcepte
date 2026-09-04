import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../data/special_days_repository.dart';
import '../../utils/pano_layouts.dart';
import '../../utils/special_day_pdf_generator.dart';

/// Bir belirli gün için pano kurgusu seçme ekranı.
///
/// ## Neden liste, tek düğme değil
///
/// Tek "Pano" düğmesi "bu günü böyle kutlayın" der. Öğretmenin sınıfı,
/// süresi ve fotokopi imkânı farklı; aynı panoyu herkes asamaz. Bu ekran
/// o günün içeriğinden üretilebilen kurguları listeler — ortalama dokuz
/// seçenek çıkar.
///
/// İçerikte karşılığı olmayan kurgu LİSTELENMEZ ([PanoKurgular.uygunOlanlar]).
/// Öğretmene çalışmayacak bir seçenek göstermek, onu boş bir PDF'e
/// götürmek demektir.
class PanoKurguSheet extends StatelessWidget {
  const PanoKurguSheet({
    super.key,
    required this.gun,
    required this.icerik,
    this.schoolName = '',
    this.academicYear = '',
  });

  final SpecialDay gun;
  final PanoContent? icerik;

  /// Panoya yalnızca okul adı ve öğretim yılı basılır.
  ///
  /// Şube ve öğretmen adı BASILMAZ: aynı çıktıyı okuldaki her öğretmen
  /// kullanabilmeli (bkz. tool/PANO_ICERIK_KURALLARI.md).
  final String schoolName;
  final String academicYear;

  static Future<void> show(
    BuildContext context, {
    required SpecialDay gun,
    required PanoContent? icerik,
    String schoolName = '',
    String academicYear = '',
  }) {
    return ResponsiveBottomSheet.show(
      context: context,
      child: PanoKurguSheet(
        gun: gun,
        icerik: icerik,
        schoolName: schoolName,
        academicYear: academicYear,
      ),
    );
  }

  Future<void> _ac(BuildContext context, PanoKurgu kurgu) {
    final t = PanoKurgular.tanimlar[kurgu]!;
    return PdfPreviewScreen.open(
      context,
      title: t.ad,
      subtitle: gun.ad,
      fileName: 'Pano_${gun.ad}_${t.ad}.pdf',
      documentBuilder: (_) => SpecialDayPdfGenerator.panoKurgusu(
        kurgu: kurgu,
        gun: gun,
        icerik: icerik,
        schoolName: schoolName,
        academicYear: academicYear,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kurgular = PanoKurgular.uygunOlanlar(gun, icerik);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          gun.tarihMetni,
          style: AppFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          gun.ad,
          style: AppFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${kurgular.length} pano çalışması. Birini seçin; kesip asmaya '
          'hazır PDF olarak açılır.',
          style: AppFonts.outfit(
            fontSize: 12.5,
            height: 1.45,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 14),
        for (final k in kurgular) _kurguKart(context, isDark, k),
        const SizedBox(height: 4),
        _bilgi(
          isDark,
          'Panoya okul adınız basılır; şube ve öğretmen adı basılmaz — '
          'aynı çıktıyı okuldaki her öğretmen kullanabilir. Renkler '
          'siyah-beyaz yazıcıda da okunacak biçimde seçildi.',
        ),
      ],
    );
  }

  Widget _kurguKart(BuildContext context, bool isDark, PanoKurgu kurgu) {
    final t = PanoKurgular.tanimlar[kurgu]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => _ac(context, kurgu),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _ikon(kurgu),
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.ad,
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t.aciklama,
                        style: AppFonts.outfit(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _etiket(isDark, t.sayfaNotu, AppColors.primary),
                          _etiket(
                            isDark,
                            t.hazirlikMetni,
                            t.hazirlik == 'yok'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                          ),
                          if (t.ogrenciDoldurur)
                            _etiket(
                              isDark,
                              'Öğrenci doldurur',
                              const Color(0xFFF59E0B),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Icon(
                    Icons.chevron_right,
                    size: 19,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _etiket(bool isDark, String metin, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        metin,
        style: AppFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? renk.withValues(alpha: 0.95) : renk,
        ),
      ),
    );
  }

  Widget _bilgi(bool isDark, String metin) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        metin,
        style: AppFonts.outfit(
          fontSize: 11.5,
          height: 1.5,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  /// Kurgunun ne olduğunu bir bakışta anlatan simge.
  static IconData _ikon(PanoKurgu k) => switch (k) {
        PanoKurgu.devBaslik => Icons.text_fields,
        PanoKurgu.tarihSeridi => Icons.timeline,
        PanoKurgu.onceSonra => Icons.compare_arrows,
        PanoKurgu.merkezVecize => Icons.format_quote,
        PanoKurgu.ogrenciAgaci => Icons.park_outlined,
        PanoKurgu.soruCevap => Icons.quiz_outlined,
        PanoKurgu.siirDuvari => Icons.menu_book_outlined,
        PanoKurgu.biliyorMuydunuz => Icons.lightbulb_outline,
        PanoKurgu.sozPanosu => Icons.draw_outlined,
        PanoKurgu.kartDestesi => Icons.dashboard_customize_outlined,
        PanoKurgu.kavramSozlugu => Icons.abc_outlined,
      };
}
