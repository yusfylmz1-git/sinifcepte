import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Cihazda kalıcı tanı kaydı.
///
/// ## Neden gerekli
///
/// "Belge Hazırlanıyor" takılması yalnızca **kablo çıkınca** görülüyor;
/// kablo takılıyken belge açılıyor. `debugPrint` ise yalnızca kablo
/// bağlıyken okunabiliyor — yani sorunun görüldüğü koşulda elimizde
/// hiçbir kanıt kalmıyordu.
///
/// Bu sınıf satırları cihazdaki bir dosyaya yazar. Kullanıcı kablosuz
/// dener, sonra kabloyu takar, dosya okunur.
///
/// ## Kullanım
///
///     await TaniLog.yaz('PDF: üretim başladı');
///
/// Dosya: `<uygulama belgeleri>/tani.log`
/// Bilgisayardan okumak için:
///
///     adb shell "run-as com.sinifcepte.sinifcepte cat \
///       /data/data/com.sinifcepte.sinifcepte/app_flutter/tani.log"
///
/// ## Ömrü
///
/// Bu geçici bir tanı aracıdır. Sorun çözülünce kaldırılmalı; kalıcı
/// bir günlükleme altyapısı değil. Dosya [_maxBayt] boyutunu aşarsa
/// baştan başlar, böylece sınırsız büyümez.
class TaniLog {
  TaniLog._();

  static const _dosyaAdi = 'tani.log';

  /// Dosya bu boyutu aşarsa sıfırlanır (256 KB).
  static const _maxBayt = 256 * 1024;

  static File? _dosya;
  static Future<File>? _hazirlik;

  /// Yazma sırası — eşzamanlı çağrılar birbirinin üstüne yazmasın.
  static Future<void> _sira = Future.value();

  static Future<File> _dosyayiAc() async {
    final d = await getApplicationDocumentsDirectory();
    final f = File('${d.path}/$_dosyaAdi');
    if (!await f.exists()) {
      await f.create(recursive: true);
    } else if (await f.length() > _maxBayt) {
      await f.writeAsString('');
    }
    return f;
  }

  /// Bir satır yazar. Hata durumunda sessizce vazgeçer — tanı aracı
  /// uygulamayı çökertmemeli.
  ///
  /// RELEASE derlemede hiçbir şey yapmaz: gerçek kullanıcının cihazında
  /// dosya yazma maliyeti olmasın. Tanı yalnızca geliştirme sırasında
  /// gerekiyor.
  static Future<void> yaz(String satir) {
    if (!kDebugMode) return Future.value();

    // Konsola da yaz: kablo takılıyken iki kanaldan da görülür.
    debugPrint(satir);

    _sira = _sira.then((_) async {
      try {
        _dosya ??= await (_hazirlik ??= _dosyayiAc());
        final zaman = DateTime.now().toIso8601String().substring(11, 23);
        await _dosya!.writeAsString(
          '$zaman  $satir\n',
          mode: FileMode.append,
          flush: true, // kablo çıkarken kaybolmasın
        );
      } catch (_) {
        // Yazamıyorsak tanı yapamayız ama uygulama çalışmaya devam eder.
      }
    });
    return _sira;
  }

  /// Dosyanın tam yolu — kullanıcıya göstermek için.
  static Future<String> yol() async {
    final d = await getApplicationDocumentsDirectory();
    return '${d.path}/$_dosyaAdi';
  }

  /// Birikmiş kaydı okur.
  static Future<String> oku() async {
    try {
      final f = await (_hazirlik ??= _dosyayiAc());
      return f.readAsString();
    } catch (e) {
      return 'okunamadı: $e';
    }
  }

  /// Kaydı temizler — yeni bir deneme öncesi.
  static Future<void> temizle() async {
    try {
      final f = await (_hazirlik ??= _dosyayiAc());
      await f.writeAsString('');
    } catch (_) {
      // yok say
    }
  }
}
