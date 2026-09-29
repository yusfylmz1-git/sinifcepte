import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sinifcepte/features/student_photos/data/foto_paylasim.dart';
import 'package:sinifcepte/features/student_photos/domain/foto_isleme.dart';
import 'package:sinifcepte/features/student_photos/domain/kirpma_hesabi.dart';

/// Faz 2: elle hizalama hesabı, çalışma görüntüsü, dosya adı.
void main() {
  // Çerçeve: 266×342 ekran pikseli (133:171).
  const cg = 266.0;
  const cy = 342.0;

  group('kırpma hesabı', () {
    test('KRITIK: açılışta görüntü çerçeveyi kaplıyor ve ortalı', () {
      for (final (g, y) in [(2000, 1500), (1500, 2000), (1000, 1000)]) {
        final d = KirpmaDurumu.baslangic(g, y, cg, cy);
        expect(d.x <= 0 && d.y <= 0, isTrue);
        expect(d.x + g * d.olcek >= cg - 1e-6, isTrue);
        expect(d.y + y * d.olcek >= cy - 1e-6, isTrue);
        final a = d.alan(g, y, cg);
        expect((a.x - (g - a.genislik) / 2).abs() <= 1, isTrue, reason: 'yatay ortalı');
        expect((a.y - (y - a.yukseklik) / 2).abs() <= 1, isTrue, reason: 'dikey ortalı');
      }
    });

    test('KRITIK: kırpma alanı her durumda tam 133:171 ve görüntü içinde', () {
      const g = 2000, y = 1500;
      for (final s in [0.1, 0.2, 0.5, 1.3]) {
        for (final (x0, y0) in [(0.0, 0.0), (-500.0, -300.0), (-99999.0, -99999.0), (50.0, 50.0)]) {
          final d = KirpmaDurumu(s, x0, y0).sinirla(g, y, cg, cy);
          final a = d.alan(g, y, cg);
          expect(a.x >= 0 && a.y >= 0, isTrue);
          expect(a.x + a.genislik <= g && a.y + a.yukseklik <= y, isTrue, reason: '$a');
          expect(a.genislik / a.yukseklik, closeTo(eokulOran, 0.01), reason: '$a');
        }
      }
    });

    test('sınırlama: boş kenar bırakmıyor, aşırı yakınlaştırmıyor', () {
      const g = 2000, y = 1500;
      final enKucuk = KirpmaDurumu.enKucukOlcek(g, y, cg, cy);
      final kucuk = const KirpmaDurumu(0.01, 100, 100).sinirla(g, y, cg, cy);
      expect(kucuk.olcek, enKucuk);
      expect(kucuk.x <= 0 && kucuk.y <= 0, isTrue);
      final buyuk = const KirpmaDurumu(100, 0, 0).sinirla(g, y, cg, cy);
      expect(buyuk.olcek, closeTo(enKucuk * KirpmaDurumu.enFazlaYakinlastirma, 1e-9));
    });

    test('KRITIK: iki parmak yakınlaştırmada parmağın altındaki nokta yerinde kalıyor', () {
      const bas = KirpmaDurumu(0.2, -50, -40);
      // Ekranda (100,120) altındaki görüntü noktası:
      const gx = (100 - -50) / 0.2, gy = (120 - -40) / 0.2;
      final d = KirpmaDurumu.hareket(
        baslangic: bas,
        odakBaslangicX: 100,
        odakBaslangicY: 120,
        odakX: 110,
        odakY: 125,
        carpan: 2,
      );
      expect(d.olcek, 0.4);
      expect(d.x + gx * d.olcek, closeTo(110, 1e-9));
      expect(d.y + gy * d.olcek, closeTo(125, 1e-9));
    });

    test('açı düzeltmesi tuvali büyütünce çerçevenin ortası aynı yerde kalıyor', () {
      const d = KirpmaDurumu(0.5, -300, -200);
      // Çerçeve ortasının görüntüdeki yeri (merkeze göre):
      final eskiMerkez = ((cg / 2 - d.x) / d.olcek - 2000 / 2, (cy / 2 - d.y) / d.olcek - 1500 / 2);
      final t = d.tasi(eskiG: 2000, eskiY: 1500, yeniG: 2100, yeniY: 1620, cerceveG: cg, cerceveY: cy);
      final yeniMerkez = ((cg / 2 - t.x) / t.olcek - 2100 / 2, (cy / 2 - t.y) / t.olcek - 1620 / 2);
      expect(yeniMerkez.$1, closeTo(eskiMerkez.$1, 1e-6));
      expect(yeniMerkez.$2, closeTo(eskiMerkez.$2, 1e-6));
    });
  });

  group('çalışma görüntüsü', () {
    Uint8List jpeg(int g, int y) {
      final r = img.Image(width: g, height: y);
      img.fill(r, color: img.ColorRgb8(30, 90, 160));
      return Uint8List.fromList(img.encodeJpg(r, quality: 70));
    }

    test('KRITIK: büyük fotoğraf 2000 piksele küçülüyor, oran korunuyor', () {
      final c = calismaGoruntusuHazirla(jpeg(3000, 4000));
      expect((c.genislik, c.yukseklik), (1500, 2000));
      final d = img.decodeJpg(c.jpeg)!;
      expect((d.width, d.height), (1500, 2000), reason: 'bildirilen ölçü gerçek ölçüyle aynı');
    });

    test('küçük fotoğraf büyütülmüyor', () {
      final c = calismaGoruntusuHazirla(jpeg(640, 480));
      expect((c.genislik, c.yukseklik), (640, 480));
    });

    test('KRITIK: EXIF yönü çalışma görüntüsünde uygulanmış', () {
      final r = img.Image(width: 400, height: 300);
      r.exif.imageIfd.orientation = 6;
      final c = calismaGoruntusuHazirla(Uint8List.fromList(img.encodeJpg(r)));
      expect((c.genislik, c.yukseklik), (300, 400));
      expect(img.decodeJpg(c.jpeg)!.exif.imageIfd.orientation, anyOf(isNull, 1),
          reason: 'yön iki kez uygulanmasın');
    });

    test('HEIC anlaşılır hatayla reddediliyor', () {
      final sahte = Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits, 0, 0, 0, 0]);
      expect(
        () => calismaGoruntusuHazirla(sahte),
        throwsA(isA<FotoIslemeHatasi>().having((e) => e.mesaj, 'mesaj', contains('HEIC'))),
      );
    });

    test('KRITIK: devasa görüntü AÇILMADAN reddediliyor (bellek taşması)', () {
      // Yalnızca başlığı 10000×10000 diyen PNG: çözülseydi 400 MB.
      final png = _pngBasligi(10000, 10000);
      expect(
        () => calismaGoruntusuHazirla(png),
        throwsA(isA<FotoIslemeHatasi>().having((e) => e.mesaj, 'mesaj', contains('çok büyük'))),
      );
    });

    test('ölçüsü okunamayan (kesik) dosya anlaşılır hatayla reddediliyor', () {
      // Yalnızca imza + IHDR. Not: bu test "ölçü okunamazsa açma" ek
      // önlemini ayırt ETMİYOR — tam çözücü de bu dosyayı reddediyor
      // (bozma denemesiyle ölçüldü, 30 Eylül 2026).
      final kesik = Uint8List.fromList(_pngBasligi(10000, 10000).sublist(0, 33));
      expect(() => calismaGoruntusuHazirla(kesik), throwsA(isA<FotoIslemeHatasi>()));
    });

    test('saydam PNG siyah değil beyaz zeminle', () {
      final r = img.Image(width: 300, height: 300, numChannels: 4);
      img.fill(r, color: img.ColorRgba8(0, 0, 0, 0));
      final c = calismaGoruntusuHazirla(Uint8List.fromList(img.encodePng(r)));
      final px = img.decodeJpg(c.jpeg)!.getPixel(150, 150);
      expect(px.r > 240 && px.g > 240 && px.b > 240, isTrue, reason: '${px.r},${px.g},${px.b}');
    });

    test('açı düzeltmesi: köşeler beyaz, sıfır açı aynı görüntüyü döndürür', () {
      final c = calismaGoruntusuHazirla(jpeg(600, 800));
      expect(identical(calismaGoruntusunuDondur(c, 0), c), isTrue);
      final d = calismaGoruntusunuDondur(c, 10);
      expect(d.genislik > 600 && d.yukseklik > 800, isTrue);
      final kose = img.decodeJpg(d.jpeg)!.getPixel(1, 1);
      expect(kose.r > 230 && kose.g > 230, isTrue);
    });

    test('KRITIK: küçük kırpma alanı "düşük çözünürlük" uyarısı taşıyor', () {
      final c = calismaGoruntusuHazirla(jpeg(1000, 1000));
      final iyi = calismadanUret(c, const KirpmaAlani(0, 0, 700, 900));
      expect(iyi.kaliteUyarilari, isEmpty);
      final kucuk = calismadanUret(c, const KirpmaAlani(0, 0, 100, 129));
      expect(kucuk.kaliteUyarilari, [kaliteDusukCozunurluk]);
      expect(img.decodeJpg(kucuk.jpeg)!.width, 133, reason: 'ölçü yine tam');
    });
  });

  group('dosya adı', () {
    test('KRITIK: <no>_<Ad>_<SOYAD>.jpg, Türkçe harfler korunuyor', () {
      expect(eokulDosyaAdi(okulNo: 1234, ad: 'İsmail', soyad: 'IŞIK'), '1234_İsmail_IŞIK.jpg');
      expect(eokulDosyaAdi(okulNo: 7, ad: 'Ayşe Nur', soyad: 'ÇELİK'), '7_Ayşe_Nur_ÇELİK.jpg');
    });

    test('dosya sisteminin yasakladığı karakterler çıkarılıyor', () {
      final ad = eokulDosyaAdi(okulNo: 5, ad: 'A/b\\c:d*e?"f<g>h|', soyad: '  X  ');
      expect(ad, '5_Abcdefgh_X.jpg');
      expect(eokulDosyaAdi(okulNo: 5, ad: '../..', soyad: 'Y'), '5_...._Y.jpg');
    });

    test('çok uzun ad kısaltılıyor, uzantı korunuyor', () {
      final ad = eokulDosyaAdi(okulNo: 1, ad: 'A' * 200, soyad: 'B');
      expect(ad.length, 84);
      expect(ad.endsWith('.jpg'), isTrue);
    });
  });
}

/// Başlığı büyük ölçü söyleyen PNG: imza + IHDR + küçük IDAT + IEND.
/// Başlık okunur; tam çözülseydi yüzlerce MB bellek isterdi.
Uint8List _pngBasligi(int g, int y) {
  List<int> parca(String tur, List<int> veri) {
    final govde = [...tur.codeUnits, ...veri];
    return [..._be32(veri.length), ...govde, ..._be32(_crc32(govde))];
  }

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...parca('IHDR', [..._be32(g), ..._be32(y), 8, 2, 0, 0, 0]),
    ...parca('IDAT', [0x78, 0x9C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01]),
    ...parca('IEND', const []),
  ]);
}

List<int> _be32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];

int _crc32(List<int> veri) {
  var c = 0xFFFFFFFF;
  for (final b in veri) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}
