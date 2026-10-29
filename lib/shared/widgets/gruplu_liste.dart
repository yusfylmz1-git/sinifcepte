import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';

/// Gruplu liste: harf aralıklı küçük grup başlığı, altında tek yüzeyde
/// satırlar; her satırda simge, ad ve sınıfın durumunu söyleyen alt satır.
///
/// ## Neden ortak (29 Ekim 2026)
/// Düzen Rehberlik Dosyası'nda kuruldu ve kullanıcı onayladı. Sınav
/// İşlemleri ve Evraklar da aynı düzene geçiyor; kullanıcının şikâyeti
/// her sayfanın kendi kart, rozet ve renk dilini konuşmasıydı ("bizde
/// çok karışık"). Tek parça olunca sayfalar birbirine benzer kalır.

/// Grubun zaman etiketi: içindeki aylardan biri bu aysa "bu ay", bir
/// sonraki aysa "yaklaşıyor".
String? zamanEtiketi(List<int> aylar, DateTime simdi) {
  if (aylar.contains(simdi.month)) return 'bu ay';
  if (aylar.contains(simdi.month % 12 + 1)) return 'yaklaşıyor';
  return null;
}

Color _yazi(bool isDark) => isDark ? Colors.white : const Color(0xFF0F172A);
Color _soluk(bool isDark) => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color _yuzey(bool isDark) => isDark ? const Color(0xFF1E293B) : Colors.white;
Color _cizgi(bool isDark) => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
Color _uyari(bool isDark) => isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

class GrupBasligi extends StatelessWidget {
  const GrupBasligi(this.baslik, {super.key, this.etiket});

  final String baslik;

  /// "bu ay", "yaklaşıyor" gibi; yoksa çizilmez.
  final String? etiket;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(baslik,
            style: AppFonts.outfit(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: _soluk(isDark), letterSpacing: 0.7)),
        if (etiket != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(etiket!,
                style: AppFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: _uyari(isDark))),
          ),
        ],
      ],
    );
  }
}

/// Bir gruptaki satırlar tek yüzeyde, araları ince çizgi.
class GrupKutusu extends StatelessWidget {
  const GrupKutusu({super.key, required this.satirlar});

  final List<Widget> satirlar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: _yuzey(isDark),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cizgi(isDark)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < satirlar.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: _cizgi(isDark)),
              satirlar[i],
            ],
          ],
        ),
      ),
    );
  }
}

class GrupSatiri extends StatelessWidget {
  const GrupSatiri({
    super.key,
    required this.ikon,
    required this.ad,
    required this.alt,
    this.onTap,
    this.uyari = false,
  });

  final IconData ikon;
  final String ad;

  /// Durum: "32 öğrenci", "Sıradaki: … · 12 gün kaldı"…
  final String alt;

  /// Yoksa satır açılmaz, sağdaki ok çizilmez.
  final VoidCallback? onTap;

  /// Eksik bir şey var: alt satır turuncu ve kalın yazılır.
  final bool uyari;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(ikon, size: 18, color: isDark ? AppColors.primaryLight : AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad, style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _yazi(isDark))),
                  const SizedBox(height: 2),
                  Text(
                    alt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.outfit(
                      fontSize: 11.2,
                      fontWeight: uyari ? FontWeight.w600 : FontWeight.w400,
                      color: uyari ? _uyari(isDark) : _soluk(isDark),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black26),
          ],
        ),
      ),
    );
  }
}
