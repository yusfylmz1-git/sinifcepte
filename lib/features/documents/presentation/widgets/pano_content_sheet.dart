import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../data/special_days_repository.dart';
import '../../utils/special_day_pdf_generator.dart';
import 'pano_kurgu_sheet.dart';

/// Belirli gün belgesi: üç PDF + sınıf içi etkinlik örnekleri.
class PanoContentSheet extends StatelessWidget {
  const PanoContentSheet({
    super.key,
    required this.gun,
    required this.icerik,
    this.schoolName = '',
    this.className = '',
    this.teacherName = '',
    this.academicYear = '',
  });

  final SpecialDay gun;
  final PanoContent? icerik;

  /// Resmî belgelerin künyesi için.
  final String schoolName;
  final String className;
  final String teacherName;
  final String academicYear;

  static Future<void> show(
    BuildContext context, {
    required SpecialDay gun,
    required PanoContent? icerik,
    String schoolName = '',
    String className = '',
    String teacherName = '',
    String academicYear = '',
  }) {
    return ResponsiveBottomSheet.show(
      context: context,
      child: PanoContentSheet(
        gun: gun,
        icerik: icerik,
        schoolName: schoolName,
        className: className,
        teacherName: teacherName,
        academicYear: academicYear,
      ),
    );
  }

  Future<void> _planPdf(BuildContext context) => PdfPreviewScreen.open(
        context,
        title: 'Etkinlik planı',
        subtitle: gun.ad,
        fileName: 'Etkinlik_Plani_${gun.ad}.pdf',
        documentBuilder: (_) => SpecialDayPdfGenerator.etkinlikPlani(
          gun: gun,
          icerik: icerik,
          schoolName: schoolName,
          className: className,
          teacherName: teacherName,
          academicYear: academicYear,
        ),
      );

  Future<void> _raporPdf(BuildContext context) => PdfPreviewScreen.open(
        context,
        title: 'Çalışma raporu',
        subtitle: gun.ad,
        fileName: 'Calisma_Raporu_${gun.ad}.pdf',
        documentBuilder: (_) => SpecialDayPdfGenerator.kutlamaRaporu(
          gun: gun,
          icerik: icerik,
          schoolName: schoolName,
          className: className,
          teacherName: teacherName,
          academicYear: academicYear,
        ),
      );

  /// Pano kurgularını listeler.
  ///
  /// Doğrudan PDF açmak yerine seçim ekranı gelir: her günün içeriğinden
  /// ortalama dokuz farklı pano üretilebiliyor ve hangisinin uygun
  /// olduğunu öğretmen bilir — sınıfı, süresi ve fotokopi imkânı ona göre.
  Future<void> _panoSec(BuildContext context) => PanoKurguSheet.show(
        context,
        gun: gun,
        icerik: icerik,
        schoolName: schoolName,
        academicYear: academicYear,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final i = icerik;

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
        const SizedBox(height: 14),
        _belgeDugmeleri(context),
        if (i == null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _bilgi(
              isDark,
              'Bu gün için sınıf etkinlik örneği henüz eklenmedi. '
              'Plan, rapor ve pano PDF’i yine de alınabilir.',
            ),
          )
        else if (i.etkinlikler.isNotEmpty) ...[
          const SizedBox(height: 18),
          _bolum(isDark, 'Sınıf içi etkinlik örnekleri',
              Icons.local_activity_outlined, const Color(0xFF10B981)),
          const SizedBox(height: 8),
          for (final e in i.etkinlikler) _etkinlikKart(isDark, e),
        ],
      ],
    );
  }

  Widget _belgeDugmeleri(BuildContext context) {
    Widget dugme(String ad, IconData ikon, VoidCallback onTap) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(ikon, size: 18),
          label: Text(ad),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dugme('Etkinlik planı', Icons.description_outlined, () => _planPdf(context)),
        const SizedBox(height: 8),
        dugme('Çalışma raporu', Icons.fact_check_outlined, () => _raporPdf(context)),
        const SizedBox(height: 8),
        dugme('Pano çalışmaları', Icons.dashboard_customize_outlined,
            () => _panoSec(context)),
      ],
    );
  }

  Widget _bolum(bool isDark, String baslik, IconData ikon, Color renk) {
    return Row(
      children: [
        Icon(ikon, size: 15, color: renk),
        const SizedBox(width: 6),
        Text(
          baslik,
          style: AppFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: renk,
          ),
        ),
      ],
    );
  }

  Widget _etkinlikKart(bool isDark, PanoActivity e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.ad,
            style: AppFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (e.malzeme.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Malzeme: ${e.malzeme.join(', ')}',
              style: AppFonts.outfit(
                fontSize: 11.5,
                height: 1.35,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
          if (e.adimlar.isNotEmpty) ...[
            const SizedBox(height: 7),
            for (var k = 0; k < e.adimlar.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 17,
                      child: Text(
                        '${k + 1}.',
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.adimlar[k],
                        style: AppFonts.outfit(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _bilgi(bool isDark, String metin) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        metin,
        style: AppFonts.outfit(
          fontSize: 12,
          height: 1.45,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }
}
