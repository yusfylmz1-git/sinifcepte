import 'package:flutter/material.dart';

/// SınıfCepte - UI-UX-MAX Renk Paleti (Color System)
abstract class AppColors {
  // Arka Planlar (Backgrounds)
  static const Color darkBackground = Color(0xFF0F172A); // Deep Slate
  static const Color darkCardBackground = Color(0xFF1E293B); // Slate Navy
  static const Color lightBackground = Color(0xFFF8FAFC); // Clean Ice White
  static const Color lightCardBackground = Color(0xFFFFFFFF);

  // Ana Renkler (Primary & Secondary)
  static const Color primary = Color(0xFF6366F1); // Indigo Moru
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF3B82F6); // Electric Blue
  static const Color accent = Color(0xFF10B981); // Emerald Green

  // Durum Renkleri (Status Badges & Indicators)
  static const Color success = Color(0xFF10B981); // Var / Geldi 🟢
  static const Color warning = Color(0xFFF59E0B); // Geç / İzinli 🟡
  static const Color danger = Color(0xFFEF4444); // Yok / Gelmedi 🔴
  static const Color info = Color(0xFF06B6D4); // Cyan Info 🔵

  // Cam (Glassmorphism) Efekti Renkleri
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassFillDark = Color(0x221E293B);
  static const Color glassFillLight = Color(0xCCFFFFFF);

  // Metin Renkleri (Typography Colors)
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Radyan Gradyanlar (Gradients)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientDark = LinearGradient(
    colors: [Color(0x33334155), Color(0x110F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
