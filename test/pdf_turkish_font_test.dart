import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:sinifcepte/core/pdf/pdf_tr_fonts.dart';

/// PDF'lerde Turkce karakter basiliyor mu?
///
/// ## Neden bu test var
/// 26 PDF ureticiden yalnizca 3'u font yukluyordu; digerleri
/// `pw.Document()` cagirip temasiz birakiyordu. Fontsuz belgede `pdf`
/// paketi Helvetica'ya dusuyor ve su uyariyi veriyor:
///
///   Unable to find a font to draw "ı" (U+131)
///
/// Ciktida o harflerin yerine SIYAH KUTU goruluyordu. Ustelik font
/// yukleyen uc dosya da yalnizca base+bold tanimliyordu; ITALIK metin
/// yine Helvetica'ya dusup ayni kutulari uretiyordu ("Toplantı" ->
/// "Toplant▮").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final ad = utf8.decode(message!.buffer.asUint8List());
      final f = File(ad);
      if (f.existsSync()) {
        return Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData();
      }
      return null;
    });
  });

  /// Tum Turkce ozel harfler.
  const trHarfler = 'ışğüöçİŞĞÜÖÇ';

  test('KRITIK: tema dort stilde de Turkce fontu tasiyor', () async {
    final t = await PdfTrFonts.theme();
    final s = t.defaultTextStyle;
    // Italik ve kalin-italik BOS BIRAKILIRSA Helvetica'ya duser.
    expect(s.fontNormal, isNotNull);
    expect(s.fontBold, isNotNull);
    expect(s.fontItalic, isNotNull, reason: 'italik metin kutu basardi');
    expect(s.fontBoldItalic, isNotNull);
    expect(s.fontFallback, isNotEmpty, reason: 'son care fontu olmali');
  });

  test('KRITIK: italik ve kalin metinde Turkce harf KUTU cikmiyor', () async {
    // `pdf` paketi cizemedigi harf icin yer tutucu (kutu) koyup
    // "Unable to find a font to draw" uyarisi basiyor. Uyariyi
    // yakalarsak kutu cikmis demektir.
    final uyarilar = <String>[];
    await runZoned(
      () async {
        final doc = await PdfTrFonts.document();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Column(
            children: [
              pw.Text(trHarfler),
              pw.Text('Toplantı $trHarfler',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
              pw.Text('Sınıf $trHarfler',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Planı $trHarfler',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  )),
            ],
          ),
        ));
        await doc.save();
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) {
          if (line.contains('Unable to find a font')) uyarilar.add(line);
        },
      ),
    );

    expect(uyarilar, isEmpty,
        reason: 'Su harfler kutu olarak basiliyor: ${uyarilar.join(" | ")}');
  });

  test('KRITIK: PdfTrFonts.document() temali belge uretir', () async {
    // Ureticiler `pw.Document()` yerine bunu cagirmali; boylece font
    // baglamayi unutmak mumkun olmaz.
    final doc = await PdfTrFonts.document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        children: [
          pw.Text('Sınıf Rehberlik Planı — İstanbul Şişli'),
          pw.Text('Toplantı (idari çalışma)',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
          pw.Text('KALIN ĞÜŞİÖÇ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ));
    final bytes = await doc.save();
    expect(bytes.length, greaterThan(1000));
  });

  test('KRITIK: hicbir uretici temasiz pw.Document() kullanmiyor', () {
    // Yeni bir uretici eklenirken font baglamak unutulursa bu test
    // kirmizi yanar.
    final bozuk = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // Temayi KURAN dosya; temasiz belge uretmesi dogru.
      if (f.path.endsWith('pdf_tr_fonts.dart')) continue;
      final kod = f.readAsStringSync();
      if (kod.contains('pw.Document()')) {
        bozuk.add(f.path);
      }
    }
    expect(bozuk, isEmpty,
        reason: 'Bu dosyalar temasiz belge uretiyor, Turkce harfler '
            'kutu cikar: ${bozuk.join(", ")}');
  });
}
