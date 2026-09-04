import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:sinifcepte/shared/screens/pdf_preview_screen.dart';

/// PDF onizleme ekraninin yeniden kurulma davranisi.
///
/// ## Neden bu testler var
///
/// "Belge Hazirlaniyor" ekraninda sonsuz takilma sikayeti vardi.
/// Sebep zinciri:
///
///   1. `onZoomChanged` -> `setState` -> `build()` yeniden calisir
///   2. `PdfPreview` YENI bir widget olarak kurulur
///   3. Paket onizlemeyi sifirlayip yeniden rasterize etmeye calisir
///   4. Onceki rasterizasyon suruyorsa istek SESSIZCE atilir
///      (printing paketi, raster.dart:98 `if (_rastering) return;`)
///   5. Ekran bos kalir ve bir daha dolmaz
///
/// Paket bu durumda hata URETMIYOR; `onError` da tetiklenmiyor. Bu
/// yuzden ekran sonsuza kadar yukleniyor gorunumunde kaliyordu.
///
/// Cozum: yakinlastirma durumu `ValueNotifier` ile tutulur, `setState`
/// cagrilmaz. Bu testler o guvenceyi korur.
void main() {
  /// Uretimin kac kez cagrildigini sayar.
  var uretimSayisi = 0;

  /// Basit ama gecerli bir PDF uretir.
  Future<Uint8List> sahteUretici(PdfPageFormat f) async {
    uretimSayisi++;
    // Gercek PDF uretmeye gerek yok; ekranin uretim cagrisini
    // sayiyoruz. Bos bayt dizisi rasterizasyonda hata verir ama
    // testin olctugu sey uretim SAYISI.
    return Uint8List.fromList(<int>[]);
  }

  setUp(() => uretimSayisi = 0);

  testWidgets('KRITIK: belge tek kez uretilir', (tester) async {
    // PdfPreview `build` geri cagrisini birden cok kez tetikliyor.
    // Her seferinde belgeyi bastan uretmek hem yavas, hem de es
    // zamanli iki uretimin birbirini beklemesine yol aciyordu.
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewScreen(
          title: 'Test',
          fileName: 'test.pdf',
          documentBuilder: sahteUretici,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(
      uretimSayisi,
      lessThanOrEqualTo(1),
      reason: 'belge birden cok kez uretiliyor — onbellek calismiyor',
    );
  });

  testWidgets('KRITIK: ekranda yakinlastirma ipucu var', (tester) async {
    // Ipucu `ValueListenableBuilder` icinde; `setState` ile degil.
    // Metin gorunuyorsa yapi dogru kurulmus demektir.
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewScreen(
          title: 'Test',
          fileName: 'test.pdf',
          documentBuilder: sahteUretici,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Yakınlaştırmak için'),
      findsOneWidget,
      reason: 'yakinlastirma ipucu ValueListenableBuilder ile cizilmeli',
    );
  });

  testWidgets('KRITIK: uretim hata verirse hata ekrani gelir',
      (tester) async {
    // Paketin onError'i bazi yollarda hic cagrilmiyor; hatayi kendimiz
    // yakalayip basiyoruz. Aksi halde ekran yukleniyor gorunumunde
    // sonsuza kadar kaliyordu.
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewScreen(
          title: 'Test',
          fileName: 'test.pdf',
          documentBuilder: (f) async => throw StateError('uretim patladi'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Belge Görüntülenemedi'), findsOneWidget);
    expect(
      find.text('Yeniden dene'),
      findsOneWidget,
      reason: 'kullanicinin elinde bir eylem olmali',
    );
  });

  testWidgets('KRITIK: zaman asiminda anlasilir mesaj', (tester) async {
    // Uretim hic donmezse kullanici sonsuza kadar beklemez.
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewScreen(
          title: 'Test',
          fileName: 'test.pdf',
          documentBuilder: (f) => Completer<Uint8List>().future,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Zaman asimi 45 saniye; bekleyip kontrol et.
    await tester.pump(const Duration(seconds: 46));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Belge Görüntülenemedi'), findsOneWidget);
    expect(
      find.textContaining('beklenenden uzun sürdü'),
      findsOneWidget,
      reason: 'zaman asimi mesaji teknik hata yerine anlasilir olmali',
    );
  });
}
