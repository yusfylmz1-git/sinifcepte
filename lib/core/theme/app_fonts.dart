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
  ///
  /// `null` = sistem fontu. Gömülü Outfit **variable font** idi ve Flutter
  /// variable font'larda her farklı `fontWeight` için çalışma zamanında
  /// ağır bir dönüşüm yapıyor. Çok sayıda farklı kalınlık kullanan
  /// ekranlarda (veli bağlantı kartı gibi) bu, çizimi kilitleyecek kadar
  /// yavaşlatıyordu.
  ///
  /// Sistem fontu her cihazda hazırdır, sıfır maliyetlidir ve Türkçe
  /// karakterleri sorunsuz gösterir. Statik ağırlıklı Outfit dosyaları
  /// temin edilirse buraya geri dönülebilir.
  static const String? display = null;

  /// Kod/numara gösterimi için tek aralıklı font.
  ///
  /// Aynı gerekçeyle sistem monospace fontu kullanılıyor.
  static const String mono = 'monospace';

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
