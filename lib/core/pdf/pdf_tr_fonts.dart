import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;


/// PDF Türkçe fontları — pakete gömülü Noto Sans, ağ yok.
///
/// Helvetica ş/ğ/ı/ü/ö/ç basamaz. `PdfGoogleFonts` ilk çağrıda font
/// indirir ve ŞÖK/BEP gibi ekranlarda ANR üretir.
class PdfTrFonts {
  PdfTrFonts._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  /// Süregelen yükleme. Aynı anda ikinci bir yükleme başlatılmaz.
  static Future<({pw.Font regular, pw.Font bold})>? _yukleme;

  /// Fontları yükler; ikinci çağrı ilkinin sonucunu bekler.
  ///
  /// ## Neden `??=` yetmiyordu
  ///
  /// Eski hâli şöyleydi:
  ///
  ///     _regular ??= pw.Font.ttf(await rootBundle.load(...));
  ///
  /// `await` içeren bir `??=` ATOMİK DEĞİL. İki çağrı aynı anda gelirse
  /// ikisi de `_regular`ı `null` görür, ikisi de 825 KB'lık fontu
  /// ayrıştırır. Ölçüldü: beş eşzamanlı çağrıda font **10 kez**
  /// okunuyordu (test/pdf_font_race_test.dart).
  ///
  /// `PdfPreview` `build` geri çağrısını birden çok kez tetiklediği
  /// için bu yarış gerçekten oluşuyordu — gereksiz iş ve bellek.
  ///
  /// NOT: Bu, "Belge Hazırlanıyor" takılmasının sebebi DEĞİLDİ. Cihaz
  /// ölçümünde font 14-20 ms'de hazır oluyordu; asıl sebep [kaydet]
  /// açıklamasında.
  static Future<({pw.Font regular, pw.Font bold})> load() {
    final hazir = (_regular, _bold);
    if (hazir.$1 != null && hazir.$2 != null) {
      return Future.value((regular: hazir.$1!, bold: hazir.$2!));
    }
    return _yukleme ??= _yukle();
  }

  /// Asset okuma üst sınırı.
  ///
  /// `rootBundle.load` normalde milisaniyeler sürer. Takılırsa hata
  /// vermeli ki sonsuz "Belge Hazırlanıyor" yerine sebep görünsün.
  static const _asetZamanAsimi = Duration(seconds: 12);

  static Future<({pw.Font regular, pw.Font bold})> _yukle() async {
    try {
      final r = await rootBundle
          .load('assets/fonts/NotoSans-Regular.ttf')
          .timeout(_asetZamanAsimi);
      final b = await rootBundle
          .load('assets/fonts/NotoSans-Bold.ttf')
          .timeout(_asetZamanAsimi);
      _regular = pw.Font.ttf(r);
      _bold = pw.Font.ttf(b);
      return (regular: _regular!, bold: _bold!);
    } finally {
      // Hata durumunda yeniden denenebilsin.
      _yukleme = null;
    }
  }

  @visibleForTesting
  static void resetCache() {
    _regular = null;
    _bold = null;
    _yukleme = null;
  }

  /// Belgeyi bayta çevirir.
  ///
  /// ## Neden bu yardımcı var
  ///
  /// `pdf` paketi **3.12.0**'da belgeyi ayrı izolatta kaydetmeye başladı
  /// ("Save in an isolate when available"). VS Code'un hata ayıklayıcısı
  /// bağlıyken o izolat duraklatılmış başlıyor ve devam ettirilmiyor;
  /// `save()` hiç dönmüyor ve PDF ekranı sonsuza kadar "Belge
  /// Hazırlanıyor"da donuyordu — hata da vermiyordu.
  ///
  /// Cihazda ölçüldü:
  ///
  ///     3.12.0 + VS Code F5   -> 10 sn zaman aşımı, belge üretilmiyor
  ///     3.12.0 + release/adb  -> çalışıyor
  ///     3.11.3                -> her durumda çalışıyor
  ///
  /// Bu yüzden `pubspec.yaml` içinde sürüm **3.11.3'e sabitlendi**.
  /// Yükseltmeden önce F5 ile başlatıp kabloyu çekerek PDF açmayı
  /// deneyin.
  ///
  /// Zaman aşımı yine de duruyor: izolat açamayan bir cihazda kullanıcı
  /// sonsuz bekleme yerine anlaşılır bir hata görür.
  static Future<Uint8List> kaydet(pw.Document pdf) async {
    try {
      return await pdf.save().timeout(_kaydetZamanAsimi);
    } on TimeoutException {
      throw TimeoutException(
        'Belge hazırlanamadı. Uygulamayı kapatıp yeniden açmayı deneyin.',
        _kaydetZamanAsimi,
      );
    }
  }

  /// Belge üretimi için üst sınır.
  ///
  /// Ölçüm: sağlıklı çalışmada `save()` ~900 ms sürüyor. 20 saniye
  /// yavaş cihazda bile rahat sınır.
  static const _kaydetZamanAsimi = Duration(seconds: 20);

  /// Belgeye verilecek hazır tema.
  ///
  /// ## Neden bu yardımcı var
  /// Belgeler `pw.Document()` çağırıp temayı elle kuruyordu; 26
  /// üreticiden yalnızca 3'ü font yüklüyordu. Fontsuz belgelerde
  /// `pdf` paketi Helvetica'ya düşüyor ve Türkçe harfleri basamıyor:
  ///
  ///   `Unable to find a font to draw "ı" (U+131)`
  ///
  /// Çıktıda bu harflerin yerine siyah kutu görünüyordu.
  ///
  /// ## İtalik neden fallback ile çözülüyor
  /// Pakette yalnızca Regular ve Bold TTF var. `fontItalic`
  /// tanımlanmazsa italik metin gene Helvetica'ya düşüyor ve aynı
  /// kutular çıkıyordu — ekran görüntüsünde "Toplantı" → "Toplant▮"
  /// olarak görülen hata buydu. İtalik için Regular kullanılır:
  /// harfler eğik olmaz ama METİN DOĞRU BASILIR. [fontFallback] ise
  /// hangi stil istenirse istensin son çare olarak devrededir.
  static Future<pw.ThemeData> theme() async {
    final f = await load();
    return pw.ThemeData.withFont(
      base: f.regular,
      bold: f.bold,
      italic: f.regular,
      boldItalic: f.bold,
      fontFallback: [f.regular, f.bold],
    );
  }

  /// Türkçe fontları hazır bir belge üretir.
  ///
  /// Yeni PDF üreticileri `pw.Document()` yerine bunu çağırmalı;
  /// böylece font bağlamayı unutmak mümkün olmaz.
  static Future<pw.Document> document() async =>
      pw.Document(theme: await theme());
}
