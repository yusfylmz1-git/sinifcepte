import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sikistirilmis varlik okuma (Faz 4.3).
///
/// Yayin APK'si 83.8 MB idi; 36 MB'i `assets/data`. Flutter varliklari
/// APK'ya sikistirmadan koyuyor ama bu dosyalar saf JSON oldugu icin
/// cok iyi sikisiyor. Mobil veriyle indirecek ogretmen icin 32 MB
/// gercek bir engel.
///
/// Bu testler `tool/compress_assets.dart` ciktisinin gercekten
/// okunabilir oldugunu ve Turkce karakterlerin bozulmadigini dogrular.
void main() {
  group('Sikistirilmis dosyalar uretilmis', () {
    test('KRITIK: kazanim verisi .gz olarak var', () {
      final gz = File('assets/data/official_maarif_kazanimlar.json.gz');
      expect(gz.existsSync(), isTrue,
          reason: 'dart run tool/compress_assets.dart calistirilmali');
    });

    test('KRITIK: .gz dosyasi cok daha kucuk', () {
      final duz = File('assets/data/official_maarif_kazanimlar.json');
      final gz = File('assets/data/official_maarif_kazanimlar.json.gz');
      if (!duz.existsSync() || !gz.existsSync()) return;

      expect(gz.lengthSync(), lessThan(duz.lengthSync() ~/ 5),
          reason: 'en az 5 kat kucuk olmali (olculen: ~15 kat)');
    });

    test('okul dosyalari da sikistirilmis', () {
      final manifest = File('assets/data/schools/schools_manifest.json.gz');
      expect(manifest.existsSync(), isTrue);
    });
  });

  group('Sikistirilmis icerik dogru cozuluyor', () {
    test('KRITIK: gecerli JSON olarak geri aciliyor', () {
      final gz = File('assets/data/official_maarif_kazanimlar.json.gz');
      if (!gz.existsSync()) return;

      final metin = utf8.decode(gzip.decode(gz.readAsBytesSync()));
      final veri = jsonDecode(metin);

      expect(veri, isA<List<dynamic>>());
      expect((veri as List).length, greaterThan(9000),
          reason: 'kayit sayisi korunmali');
    });

    test('KRITIK: Turkce karakterler bozulmuyor', () {
      final gz = File('assets/data/official_maarif_kazanimlar.json.gz');
      if (!gz.existsSync()) return;

      // Latin-1 ile cozulseydi "s", "g", "I" bozulurdu.
      final metin = utf8.decode(gzip.decode(gz.readAsBytesSync()));

      expect(metin, contains('ı'), reason: 'noktasiz i korunmali');
      expect(metin, contains('ş'));
      expect(metin, contains('ğ'));
      expect(metin, contains('İ'), reason: 'noktali buyuk I korunmali');
    });

    test('Maarif icerigi sikistirilmis surumde duruyor', () {
      final gz = File('assets/data/official_maarif_kazanimlar.json.gz');
      if (!gz.existsSync()) return;

      final veri = jsonDecode(utf8.decode(gzip.decode(gz.readAsBytesSync())))
          as List<dynamic>;

      final maarifli = veri.where((r) {
        final m = r as Map<String, dynamic>;
        final ozet = m['maarifSummary'];
        return ozet is String && ozet.isNotEmpty;
      });

      expect(maarifli, isNotEmpty,
          reason: 'sikistirma Maarif icerigini atmamali');
    });

    test('okul manifesti cozulebiliyor', () {
      final gz = File('assets/data/schools/schools_manifest.json.gz');
      if (!gz.existsSync()) return;

      final metin = utf8.decode(gzip.decode(gz.readAsBytesSync()));
      expect(() => jsonDecode(metin), returnsNormally);
    });
  });

  group('pubspec yalnizca sikistirilmisi paketliyor', () {
    test('KRITIK: buyuk JSON duz haliyle paketlenmiyor', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      // Duz dosya listede olsaydi hem .json hem .json.gz APK'ya girer,
      // sikistirma hicbir sey kazandirmazdi.
      expect(
        pubspec.contains('- assets/data/official_maarif_kazanimlar.json\n'),
        isFalse,
        reason: 'duz surum paketlenirse kazanc sifirlanir',
      );
      expect(
        pubspec.contains('assets/data/official_maarif_kazanimlar.json.gz'),
        isTrue,
      );
    });

    test('KRITIK: klasor jokeri kullanilmiyor', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      // `- assets/data/` gibi bir joker her iki surumu de paketler.
      expect(pubspec.contains('- assets/data/\n'), isFalse,
          reason: 'joker duz dosyalari da paketler');
      expect(pubspec.contains('- assets/data/schools/\n'), isFalse);
    });
  });
}
