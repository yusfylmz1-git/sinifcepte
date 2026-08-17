import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_design_tokens.dart';

/// SınıfCepte - Global UI-UX-MAX Tasarım Sistemi ve Tema Motoru
abstract class AppTheme {
  /// Koyu Tema (Dark Mode UI-UX-MAX)
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.darkCardBackground,
        onSurface: AppColors.textPrimaryDark,
        error: AppColors.danger,
        onError: Colors.white,
      ),

      // Tipografi
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryDark,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.outfit(
          color: AppColors.textPrimaryDark,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryDark,
          fontSize: 14.5,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: AppColors.textSecondaryDark,
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      // App Bar Teması
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark, size: 22),
      ),

      // Card Teması
      cardTheme: CardThemeData(
        color: AppColors.darkCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignTokens.borderRadiusLg,
          side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
      ),

      // 🔘 Elevated Button Teması (Kibar ve Standart 40px)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, AppDesignTokens.buttonHeightStandard),
          padding: AppDesignTokens.buttonPaddingStandard,
          textStyle: AppDesignTokens.buttonFontStandard,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignTokens.borderRadiusMd,
          ),
        ),
      ),

      // 🔘 Outlined Button Teması
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          elevation: 0,
          side: const BorderSide(color: AppColors.glassBorder, width: 1.2),
          minimumSize: const Size(0, AppDesignTokens.buttonHeightStandard),
          padding: AppDesignTokens.buttonPaddingStandard,
          textStyle: AppDesignTokens.buttonFontStandard,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignTokens.borderRadiusMd,
          ),
        ),
      ),

      // 🔘 Text Button Teması
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: AppDesignTokens.buttonFontStandard,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignTokens.borderRadiusSm,
          ),
        ),
      ),

      // 📝 Input Decoration (TextField) Teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
      ),

      // 🏷️ Chip Teması
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.borderRadiusSm),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // 💬 Dialog & Bottom Sheet Teması
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCardBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.borderRadiusXl),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCardBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesignTokens.radiusXl)),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.borderRadiusLg),
      ),
    );
  }

  /// Açık Tema (Light Mode UI-UX-MAX)
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.danger,
        onError: Colors.white,
      ),

      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryLight,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.outfit(
          color: AppColors.textPrimaryLight,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryLight,
          fontSize: 14.5,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: AppColors.textSecondaryLight,
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: GoogleFonts.outfit(
          color: AppColors.textPrimaryLight,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight, size: 22),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignTokens.borderRadiusLg,
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),

      // 🔘 Elevated Button Teması (Kibar ve Standart 40px)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, AppDesignTokens.buttonHeightStandard),
          padding: AppDesignTokens.buttonPaddingStandard,
          textStyle: AppDesignTokens.buttonFontStandard,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignTokens.borderRadiusMd,
          ),
        ),
      ),

      // 🔘 Outlined Button Teması
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          elevation: 0,
          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
          minimumSize: const Size(0, AppDesignTokens.buttonHeightStandard),
          padding: AppDesignTokens.buttonPaddingStandard,
          textStyle: AppDesignTokens.buttonFontStandard,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignTokens.borderRadiusMd,
          ),
        ),
      ),

      // 🔘 Text Button Teması
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: AppDesignTokens.buttonFontStandard,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignTokens.borderRadiusSm,
          ),
        ),
      ),

      // 📝 Input Decoration (TextField) Teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
      ),

      // 🏷️ Chip Teması
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: AppColors.primary,
        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.borderRadiusSm),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // 💬 Dialog & Bottom Sheet Teması
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.borderRadiusXl),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesignTokens.radiusXl)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.borderRadiusLg),
      ),
    );
  }
}
