import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sinifcepte/features/student_photos/domain/foto_isleme.dart';

/// e-Okul fotoğrafı: tam 133×171, esnetmeden, EXIF'siz.
///
/// Doğrulama `image` paketinin kendi çözücüsüyle yapılıyor; üretenle aynı
/// kod doğrulasa da piksel ölçüsü kodlayıcıdan bağımsız okunuyor.
void main() {
  Uint8List jpeg(int g, int y, {int yon = 1, img.Color? renk}) {
    final r = img.Image(width: g, height: y);
    img.fill(r, color: renk ?? img.ColorRgb8(20, 60, 120));
    if (yon != 1) r.exif.imageIfd.orientation = yon;
    return Uint8List.fromList(img.encodeJpg(r));
  }

  group('ölçü', () {
    for (final (g, y) in [(4000, 3000), (3000, 4000), (133, 171), (1080, 1080), (500, 2000)]) {
      test('KRITIK: $g×$y kaynaktan tam 133×171', () {
        final cikti = standartFotoUret(duzeltilmisGoruntu(jpeg(g, y)));
        final c = img.decodeJpg(cikti)!;
        expect((c.width, c.height), (133, 171));
      });
    }

    test('KRITIK: esnetme yok — kırpma alanı 133:171 oranında', () {
      for (final (g, y) in [(4000, 3000), (3000, 4000), (1000, 1000), (400, 2000)]) {
        final a = kirpmaAlani(g, y);
        expect(a.genislik / a.yukseklik, closeTo(eokulOran, 0.01), reason: '$g×$y');
        expect(a.x + a.genislik <= g && a.y + a.yukseklik <= y, isTrue);
      }
    });

    test('KRITIK: üretilen fotoğraf gerçekten kırpılıyor, esnetilmiyor', () {
      // 2000×1000: ortadaki 133:171 alan (x≈611–1389) yeşil, kenarlar
      // kırmızı. Esnetilse çıktının sol/sağ kenarı kırmızı olurdu —
      // ölçü yine 133×171 çıkacağı için ölçü testi bunu göremez.
      final r = img.Image(width: 2000, height: 1000);
      img.fill(r, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(r, x1: 590, y1: 0, x2: 1410, y2: 999, color: img.ColorRgb8(0, 255, 0));
      final cikti = img.decodeJpg(standartFotoUret(
          duzeltilmisGoruntu(Uint8List.fromList(img.encodeJpg(r)))))!;
      for (final x in [1, 66, 131]) {
        final px = cikti.getPixel(x, 85);
        expect(px.g > 200 && px.r < 60, isTrue, reason: 'x=$x: ${px.r},${px.g},${px.b}');
      }
    });

    test('kırpma alanı merkeze kaydırılabilir ama görüntüden taşmaz', () {
      final a = kirpmaAlani(4000, 3000, merkezX: 0.0, merkezY: 1.0, olcek: 0.5);
      expect(a.x, 0);
      expect(a.y + a.yukseklik, 3000);
    });

    test('taşan kırpma reddediliyor', () {
      expect(
        () => standartFotoUret(duzeltilmisGoruntu(jpeg(400, 400)),
            alan: const KirpmaAlani(300, 0, 133, 171)),
        throwsA(isA<FotoIslemeHatasi>()),
      );
    });
  });

  group('yön ve meta veri', () {
    test('KRITIK: EXIF yönü uygulanıyor (telefon yatay kaydedip döndür diyor)', () {
      // 6 = 90° saat yönü: 4000×3000 kayıt, dikey fotoğraf.
      final g = duzeltilmisGoruntu(jpeg(4000, 3000, yon: 6));
      expect((g.width, g.height), (3000, 4000));
    });

    test('KRITIK: çıktıda EXIF yok (konum, cihaz, saat)', () {
      final kaynak = img.Image(width: 800, height: 1000);
      kaynak.exif.imageIfd['Make'] = img.IfdValueAscii('TelefonMarkasi');
      kaynak.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
      final cikti = standartFotoUret(
          duzeltilmisGoruntu(Uint8List.fromList(img.encodeJpg(kaynak))));
      final c = img.decodeJpg(cikti)!;
      expect(c.exif.isEmpty, isTrue);
      expect(String.fromCharCodes(cikti).contains('TelefonMarkasi'), isFalse);
    });

    test('küçük açı düzeltmesi yine 133×171', () {
      final cikti = standartFotoUret(duzeltilmisGoruntu(jpeg(1200, 1600)), dondurDerece: 4);
      expect(img.decodeJpg(cikti)!.width, 133);
    });
  });

  group('doğrulama', () {
    test('resim olmayan dosya', () {
      expect(() => duzeltilmisGoruntu(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<FotoIslemeHatasi>()));
    });

    test('KRITIK: yanlış ölçülü JPEG kabul edilmiyor', () {
      expect(() => dogrula(jpeg(134, 171)), throwsA(isA<FotoIslemeHatasi>()));
      expect(() => dogrula(Uint8List.fromList(img.encodePng(img.Image(width: 133, height: 171)))),
          throwsA(isA<FotoIslemeHatasi>()));
      dogrula(jpeg(133, 171));
    });
  });
}
