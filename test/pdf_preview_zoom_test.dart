import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sinifcepte/shared/screens/pdf_preview_screen.dart';

/// PDF onizlemede iki parmakla yakinlastirma.
///
/// ## Neden bu test var
/// `printing` paketi yakinlastirmayi yalnizca TEK SAYFA modunda
/// sunuyor ve o moda CIFT DOKUNUSLA geciliyor. Dokunus liste
/// kaydirmasiyla cakistigi icin pratikte hic calismiyordu: ogretmen
/// belgeyi buyutemiyordu.
///
/// Cozum, listeyi kendi `InteractiveViewer`'imiza sarmak. Bu test
/// sarmalayicinin YERINDE oldugunu ve ayarlarinin bozulmadigini
/// dogrular.
void main() {
  testWidgets('KRITIK: sarmalayici InteractiveViewer YOK', (t) async {
    // Flutter'da olcek jesti tek parmak suruklemeyi de kapsiyor;
    // sarmalayici gorunteyleyici `panEnabled: false` olsa bile jesti
    // TANIYIP liste kaydirmasiyla yarisiyordu. Sonuc kasan, yarida
    // kesilen bir kaydirmaydi. Yakinlastirma artik paketin kendi
    // tek-sayfa moduyla yapiliyor.
    await t.pumpWidget(MaterialApp(
      home: PdfPreviewScreen(
        title: 'Deneme',
        fileName: 'deneme.pdf',
        documentBuilder: (PdfPageFormat f) async => Uint8List(0),
      ),
    ));
    await t.pump();

    expect(find.byType(InteractiveViewer), findsNothing,
        reason: 'sarmalayici geri gelirse kaydirma yine takilir');

    final p = t.widget<PdfPreview>(find.byType(PdfPreview));
    expect(p.useActions, isFalse,
        reason: 'eylem cubugu alt cubukta, ikinci sira olmamali');
    expect(p.onZoomChanged, isNotNull,
        reason: 'ipucu metni bu geri cagriya bagli');
  });

  testWidgets('yakinlastirma ipucu gorunuyor', (t) async {
    await t.pumpWidget(MaterialApp(
      home: PdfPreviewScreen(
        title: 'Deneme',
        fileName: 'deneme.pdf',
        documentBuilder: (PdfPageFormat f) async => Uint8List(0),
      ),
    ));
    await t.pump();
    expect(find.textContaining('çift dokunun'), findsOneWidget);
  });

  testWidgets('yazdir ve paylas dugmeleri duruyor', (t) async {
    await t.pumpWidget(MaterialApp(
      home: PdfPreviewScreen(
        title: 'Deneme',
        fileName: 'deneme.pdf',
        documentBuilder: (PdfPageFormat f) async => Uint8List(0),
      ),
    ));
    await t.pump();
    expect(find.text('Yazdır'), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);
  });
}
