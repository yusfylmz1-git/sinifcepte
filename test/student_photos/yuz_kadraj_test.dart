import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/student_photos/data/yuz_bulucu.dart';
import 'package:sinifcepte/features/student_photos/domain/foto_isleme.dart';
import 'package:sinifcepte/features/student_photos/domain/kirpma_hesabi.dart';
import 'package:sinifcepte/features/student_photos/domain/ogrenci_foto.dart';
import 'package:sinifcepte/features/student_photos/domain/yuz_kadraj.dart';
import 'package:sinifcepte/features/student_photos/presentation/foto_hizalama_ekrani.dart';
import 'package:sinifcepte/features/student_photos/providers/ogrenci_foto_providers.dart';

/// Faz 4 (kullanıcı kararı: YALNIZ otomatik hizalama).
void main() {
  YuzBilgisi yuz(double x, double y, double g, double h, {bool gozler = true, double? egim}) => YuzBilgisi(
        x: x,
        y: y,
        genislik: g,
        yukseklik: h,
        solGoz: gozler ? math.Point(x + g * 0.3, y + h * 0.4) : null,
        sagGoz: gozler ? math.Point(x + g * 0.7, y + h * 0.4) : null,
        egimDerece: egim,
      );

  group('kadraj önerisi', () {
    test('KRITIK: gözler %42 hattında, yatayda ortalı, oran 133:171, yüz ~%55', () {
      final o = kadrajOner([yuz(800, 600, 400, 500)], 2000, 1500)!;
      final a = o.alan;
      expect(a.genislik / a.yukseklik, closeTo(eokulOran, 0.01));
      final gozY = 600 + 500 * 0.4;
      expect((gozY - a.y) / a.yukseklik, closeTo(gozHattiOrani, 0.01));
      expect(a.x + a.genislik / 2, closeTo(1000, 1));
      expect(500 / a.yukseklik, closeTo(yuzYuksekligiOrani, 0.01));
      expect(o.uyarilar, isEmpty);
    });

    test('yüz yoksa öneri yok', () {
      expect(kadrajOner(const [], 2000, 1500), isNull);
    });

    test('KRITIK: birden fazla yüzde en büyüğü seçiliyor ve uyarılıyor', () {
      final o = kadrajOner([yuz(100, 100, 100, 120), yuz(900, 500, 300, 380)], 2000, 1500)!;
      expect(o.alan.x + o.alan.genislik / 2, closeTo(1050, 1), reason: 'büyük yüzün ortası');
      expect(o.uyarilar.single, contains('2 yüz bulundu'));
    });

    test('kenardaki yüzde kadraj görüntü içinde kalıyor', () {
      final o = kadrajOner([yuz(0, 0, 200, 250)], 2000, 1500)!;
      expect(o.alan.x >= 0 && o.alan.y >= 0, isTrue);
      expect(o.uyarilar.any((u) => u.contains('kenara yakın')), isTrue);
    });

    test('çok yakın çekilmiş yüzde sığan en büyük kadraj', () {
      final o = kadrajOner([yuz(100, 50, 1200, 1400)], 1500, 1500)!;
      final a = o.alan;
      expect(a.x + a.genislik <= 1500 && a.y + a.yukseklik <= 1500, isTrue);
      expect(a.genislik / a.yukseklik, closeTo(eokulOran, 0.01));
      expect(o.uyarilar.any((u) => u.contains('çok yakın')), isTrue);
    });

    test('eğik baş uyarılıyor, düz baş uyarılmıyor (otomatik döndürme yok)', () {
      expect(kadrajOner([yuz(800, 600, 400, 500, egim: 9)], 2000, 1500)!.uyarilar.single, contains('9° eğik'));
      expect(kadrajOner([yuz(800, 600, 400, 500, egim: 3)], 2000, 1500)!.uyarilar, isEmpty);
    });

    test('göz noktası yoksa kutudan tahmin', () {
      final o = kadrajOner([yuz(800, 600, 400, 500, gozler: false)], 2000, 1500)!;
      expect(o.alan.x + o.alan.genislik / 2, closeTo(1000, 1));
    });

    test('önerilen alan ekran durumuna ve geri aynı alana çevriliyor', () {
      const alan = KirpmaAlani(700, 300, 600, 771);
      final d = KirpmaDurumu.alandan(alan, 2000, 1500, 266, 342);
      final geri = d.alan(2000, 1500, 266);
      expect((geri.x - alan.x).abs() <= 1 && (geri.y - alan.y).abs() <= 1, isTrue, reason: '$geri');
      expect((geri.genislik - alan.genislik).abs() <= 1, isTrue);
    });
  });

  group('hizalama ekranında', () {
    // 1200×1600 beyaz görüntü, "yüz" kırmızı dikdörtgen SOL ÜSTTE
    // (60..300, 80..380). Ortada olsaydı varsayılan ortalanmış kadraj da
    // onu merkeze alırdı ve test öneriyi değil tesadüfü ölçerdi (bozma
    // denemesi bunu yakaladı).
    CalismaGoruntusu goruntu() {
      final r = img.Image(width: 1200, height: 1600);
      img.fill(r, color: img.ColorRgb8(255, 255, 255));
      img.fillRect(r, x1: 60, y1: 80, x2: 300, y2: 380, color: img.ColorRgb8(220, 0, 0));
      return calismaGoruntusuHazirla(Uint8List.fromList(img.encodeJpg(r)));
    }

    Future<void> ac(WidgetTester tester, YuzBulucu bulucu) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [yuzBulucuProvider.overrideWithValue(bulucu)],
        child: MaterialApp(
          home: FotoHizalamaEkrani(
            ogrenci: StudentModel(id: 1, classId: 1, schoolNumber: 7, firstName: 'Ali', lastName: 'CAN'),
            sinifAdi: '5-A',
            calisma: goruntu(),
            kaynak: FotoKaynagi.kamera,
            mevcutFotoVar: false,
            arkaPlan: <T>(FutureOr<T> Function() is_) async => is_(),
          ),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    testWidgets('KRITIK: öneri gerçekten uygulanıyor — çıktının ortasında yüz var', (tester) async {
      await ac(tester, _SahteBulucu([yuz(60, 80, 240, 300, gozler: false)]));
      expect(find.text('Yüze göre hizalandı; gerekirse elle düzeltin.'), findsOneWidget);
      expect(find.textContaining('Yüz tanıma yapmaz'), findsOneWidget);

      await tester.tap(find.text('Devam'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      final foto = tester.widget<Image>(find.byType(Image).first).image as MemoryImage;
      final c = img.decodeJpg(foto.bytes)!;
      expect((c.width, c.height), (133, 171));
      // Kutu kadrajın ~%21–%76'sında: ortası kırmızı, en üstü beyaz.
      final orta = c.getPixel(66, 83);
      expect(orta.r > 180 && orta.g < 80, isTrue, reason: 'orta ${orta.r},${orta.g},${orta.b}');
      final ust = c.getPixel(66, 8);
      expect(ust.r > 200 && ust.g > 200, isTrue, reason: 'üst ${ust.r},${ust.g},${ust.b}');
    });

    testWidgets('yüz bulunmazsa elle hizalama söyleniyor', (tester) async {
      await ac(tester, _SahteBulucu(const []));
      expect(find.text('Yüz bulunamadı; fotoğrafı elle hizalayın.'), findsOneWidget);
    });

    testWidgets('desteklenmeyen cihazda (Windows) düğme yok, arama yapılmıyor', (tester) async {
      final b = _SahteBulucu(const [], destekli: false);
      await ac(tester, b);
      expect(find.text('Yüzü bul ve otomatik hizala'), findsNothing);
      expect(b.cagri, 0);
    });
  });
}

class _SahteBulucu implements YuzBulucu {
  _SahteBulucu(this.yuzler, {this.destekli = true});
  final List<YuzBilgisi> yuzler;
  @override
  final bool destekli;
  int cagri = 0;

  @override
  Future<List<YuzBilgisi>> bul(CalismaGoruntusu goruntu) async {
    cagri++;
    return yuzler;
  }
}
