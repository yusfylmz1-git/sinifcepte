import 'package:flutter/material.dart';

/// SınıfCepte - Global Tasarım Sistemi Belirteçleri (Design Tokens)
abstract class AppDesignTokens {
  // ----------------------------------------------------
  // 1. Kenarlık Kıvrımları (Border Radii)
  // ----------------------------------------------------
  static const double radiusXs = 6.0;   // Rozetler, mini etiketler
  static const double radiusSm = 8.0;   // Kompakt butonlar, çipler
  static const double radiusMd = 12.0;  // Standart butonlar, input alanları
  static const double radiusLg = 16.0;  // Kartlar, diyaloglar
  static const double radiusXl = 20.0;  // Büyük hero kartlar, alt sayfalar
  static const double radiusPill = 999.0; // Tam yuvarlak hap butonlar

  static final BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadiusPill = BorderRadius.circular(radiusPill);

  // ----------------------------------------------------
  // 2. Boşluklar (Spacings)
  // ----------------------------------------------------
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 20.0;
  static const double spaceXxl = 28.0;
  static const double space3xl = 36.0;

  // ----------------------------------------------------
  // 3. Standart Buton Boyut Kademeleri (Button Size Tiers)
  // ----------------------------------------------------
  // Compact (S - 32px): Kart içi mini aksiyonlar, filtre çiğleri, ara/whatsapp
  static const double buttonHeightCompact = 32.0;
  static const EdgeInsets buttonPaddingCompact = EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0);
  static const TextStyle buttonFontCompact = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.2);

  // Standard (M - 40px): Diyalog butonları, sayfa içi işlem butonları, filtreler
  static const double buttonHeightStandard = 40.0;
  static const EdgeInsets buttonPaddingStandard = EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0);
  static const TextStyle buttonFontStandard = TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, letterSpacing: 0.2);

  // Primary CTA (L - 46px): Sihirbaz bitirme, büyük başlatıcılar
  static const double buttonHeightCta = 46.0;
  static const EdgeInsets buttonPaddingCta = EdgeInsets.symmetric(horizontal: 18.0, vertical: 11.0);
  static const TextStyle buttonFontCta = TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, letterSpacing: 0.3);

  // ----------------------------------------------------
  // 4. Gölgelendirmeler (Shadows & Micro-Elevations)
  // ----------------------------------------------------
  static List<BoxShadow> shadowSoft(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowCard(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> shadowPrimaryGlow(Color primaryColor) => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.25),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];
}
