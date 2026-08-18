import 'package:flutter/material.dart';

/// Uygulama fontları — **pakete gömülü**, internetten indirilmez.
///
/// ## Neden google_fonts paketi kullanılmıyor
/// `google_fonts` fontları çalışma zamanında indirir ve önbelleğe alır.
/// İlk açılışta ağ yavaşsa veya engelliyse metin çizimi bekler ve ekran
/// donmuş görünür — kullanıcı bunu "öğrenciye basınca donuyor" olarak
/// bildirdi.
///
/// Ayrıca proje anayasası uygulamanın internetsiz çalışmasını şart
/// koşuyor (offline-first). Font indirmek bu ilkeyi sessizce deliyordu.
///
/// Fontlar variable (değişken ağırlıklı) sürümdür: tek dosya tüm
/// kalınlıkları taşır, paket boyutu 372 KB'de kalır.
class AppFonts {
  AppFonts._();

  /// Ana arayüz fontu.
  static const String display = 'Outfit';

  /// Kod/numara gösterimi için tek aralıklı font (referans kodları).
  static const String mono = 'FiraCode';

  /// [GoogleFonts.outfit] yerine kullanılır — aynı imza, sıfır ağ isteği.
  static TextStyle outfit({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }

  /// [GoogleFonts.firaCode] yerine kullanılır.
  static TextStyle firaCode({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: mono,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
