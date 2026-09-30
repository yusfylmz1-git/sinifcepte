import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/backup/geri_yukleme_akisi.dart';
import 'package:sinifcepte/core/backup/tam_yedek.dart';

/// Geri yükleme ekranı: kapsam, uyarılar, onay kapısı (plan §16).
/// Dosya işlemleri `tam_yedek_test.dart`'ta; burada ekran davranışı.
void main() {
  final calisma = Directory.systemTemp.createTempSync('geri_yukleme_ekrani');
  tearDownAll(() {
    try {
      calisma.deleteSync(recursive: true);
    } catch (_) {}
  });

  var uygulandi = 0;

  Future<GeriYuklemeEkraniState> kur(
    WidgetTester tester, {
    HazirYedek? yedek,
    Object? incelemeHatasi,
    Object? uygulamaHatasi,
  }) async {
    uygulandi = 0;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: GeriYuklemeEkrani(
          inceleyici: (_) async {
            if (incelemeHatasi != null) throw incelemeHatasi;
            return yedek!;
          },
          mevcutKapsam: () async => (sinif: 4, ogrenci: 120, fotograf: 90),
          uygulayici: (_) async {
            if (uygulamaHatasi != null) throw uygulamaHatasi;
            uygulandi++;
          },
        ),
      ),
    ));
    return tester.state<GeriYuklemeEkraniState>(find.byType(GeriYuklemeEkrani));
  }

  Finder geriYukle() => find.ancestor(
      of: find.text('Geri yükle'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

  testWidgets('KRITIK: kapsam ve silinecek veri gösteriliyor; onaysız geri yükleme yok', (tester) async {
    final s = await kur(tester,
        yedek: HazirYedek.test(calismaDizini: calisma, sinif: 3, ogrenci: 95, fotograf: 80));
    await s.incele('yedek.sinifcepte');
    await tester.pump();

    expect(find.text('Yedek tarihi: 30.09.2026 14:30'), findsOneWidget);
    expect(find.text('Yedekte: 3 sınıf, 95 öğrenci, 80 fotoğraf'), findsOneWidget);
    expect(find.textContaining('Bu cihazdaki 4 sınıf, 120 öğrenci ve 90 fotoğraf SİLİNİP'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(geriYukle()).onPressed, isNull);

    await tester.tap(find.text('Mevcut verilerin silineceğini anlıyorum'));
    await tester.pump();
    await tester.tap(geriYukle());
    await tester.pump();
    await tester.pump();
    expect(uygulandi, 1);
    expect(find.textContaining('Geri yükleme tamamlandı: 3 sınıf, 95 öğrenci, 80 fotoğraf'), findsOneWidget);
  });

  testWidgets('KRITIK: başka hesabın yedeği ve eski biçim ayrıca uyarılıyor', (tester) async {
    final s = await kur(tester,
        yedek: HazirYedek.test(calismaDizini: calisma, baskaHesap: true, fotografli: false, fotoKaydi: 2));
    await s.incele('x');
    await tester.pump();
    expect(find.textContaining('BAŞKA bir hesaptan'), findsOneWidget);
    expect(find.textContaining('eski biçimde ve fotoğraf içermiyor'), findsOneWidget);
    expect(find.textContaining('2 fotoğrafın dosyası yedekte yok'), findsOneWidget);
  });

  testWidgets('temiz yedekte gereksiz uyarı yok', (tester) async {
    final s = await kur(tester, yedek: HazirYedek.test(calismaDizini: calisma, fotograf: 5));
    await s.incele('x');
    await tester.pump();
    expect(find.textContaining('BAŞKA'), findsNothing);
    expect(find.textContaining('eski biçimde'), findsNothing);
    expect(find.textContaining('dosyası yedekte yok'), findsNothing);
  });

  testWidgets('bozuk dosya: anlaşılır hata, geri yükleme düğmesi yok', (tester) async {
    final s = await kur(tester, incelemeHatasi: YedekHatasi('Bu dosya SınıfCepte yedeği değil.'));
    await s.incele('x');
    await tester.pump();
    expect(find.text('Bu dosya SınıfCepte yedeği değil.'), findsOneWidget);
    expect(geriYukle(), findsNothing);
  });

  testWidgets('KRITIK: uygulama düşerse "önceki verileriniz yerinde" deniyor, başarı denmiyor', (tester) async {
    final s = await kur(tester,
        yedek: HazirYedek.test(calismaDizini: calisma), uygulamaHatasi: StateError('disk dolu'));
    await s.incele('x');
    await tester.pump();
    await tester.tap(find.text('Mevcut verilerin silineceğini anlıyorum'));
    await tester.pump();
    await tester.tap(geriYukle());
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('önceki verileriniz yerinde bırakıldı'), findsOneWidget);
    expect(find.textContaining('Geri yükleme tamamlandı'), findsNothing);
  });

  test('KRITIK: menüdeki yedek penceresinde geri yükleme yolu var', () {
    final s = File('lib/shared/widgets/app_drawer.dart').readAsStringSync();
    expect(s, contains('GeriYuklemeEkrani()'));
    expect(s, contains('e-Okul fotoğrafları dahil'));
  });
}
