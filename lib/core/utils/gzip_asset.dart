import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sıkıştırılmış varlık okuyucu.
///
/// ## Neden gerekli
/// Yayın APK'sı 83.8 MB idi ve bunun 36 MB'ı `assets/data`. Flutter
/// varlıkları APK'ya **sıkıştırmadan** koyuyor; bu dosyalar ise saf metin
/// (JSON) olduğu için çok iyi sıkışıyor:
///
///   * `official_maarif_kazanimlar.json` : 23.9 MB → 1.6 MB
///   * `assets/data/schools/*`           : 10.6 MB → 1.0 MB
///
/// Mobil veriyle indirecek öğretmen için 31 MB gerçek bir engel.
///
/// ## Nasıl çalışır
/// Derleme öncesi `tool/compress_assets.dart` `.json` dosyalarının
/// yanına `.json.gz` üretir. Bu sınıf önce sıkıştırılmışı dener, yoksa
/// düz dosyaya döner — böylece sıkıştırma adımı atlanmış bir çalışma
/// ortamında da uygulama çalışmaya devam eder.
class GzipAsset {
  GzipAsset._();

  /// [assetPath] içeriğini metin olarak okur.
  ///
  /// Önce `<assetPath>.gz` denenir. Bulunamazsa düz dosya okunur.
  static Future<String> loadString(String assetPath) async {
    try {
      final data = await rootBundle.load('$assetPath.gz');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      // Türkçe karakterler için UTF-8 çözümlemesi şart; varsayılan
      // Latin-1 olsaydı "ş", "ğ", "İ" bozulurdu.
      return utf8.decode(gzip.decode(bytes));
    } catch (e) {
      // Sıkıştırılmış sürüm yoksa ya da bozuksa düz dosyaya dön.
      // Uygulama varlık okuyamazsa müfredat hiç yüklenmez; bu yüzden
      // sessizce vazgeçmek yerine geri düşülür.
      debugPrint('GzipAsset: $assetPath.gz okunamadı, düz dosyaya dönülüyor ($e)');
      return rootBundle.loadString(assetPath);
    }
  }
}
