import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/pdf/pdf_tr_fonts.dart';

/// Font yükleyicinin eşzamanlı çağrı davranışı.
///
/// ## Neden bu test var
///
/// Eski hâli şuydu:
///
///     _regular ??= pw.Font.ttf(await rootBundle.load(...));
///
/// `await` içeren `??=` ATOMİK DEĞİL: iki çağrı aynı anda gelirse ikisi
/// de alanı `null` görür ve ikisi de 825 KB'lık fontu ayrıştırır.
/// `pw.Font.ttf` ağır bir işlem; iki kopya ana iş parçacığında
/// birbirini bekletince belge üretimi dakikalarca sürüyordu.
///
/// `PdfPreview` `build` geri çağrısını birden çok kez tetiklediği için
/// bu yarış gerçekten oluşuyordu — "Belge Hazırlanıyor" ekranında
/// takılmanın sebebi buydu. Yalnızca İLK açılışta görülüyordu; sonraki
/// açılışlarda fontlar önbellekte hazır olduğu için sorun kaybolyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Kaç kez asset okunduğunu sayar.
  var okumaSayisi = 0;

  setUp(() {
    okumaSayisi = 0;
    PdfTrFonts.resetCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final ad = utf8.decode(message!.buffer.asUint8List());
      if (ad.contains('NotoSans')) {
        okumaSayisi++;
      }
      final f = File(ad);
      if (f.existsSync()) {
        return Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData();
      }
      return null;
    });
  });

  test('KRITIK: es zamanli cagrilar fontu bir kez yukler', () async {
    // Bes cagri AYNI ANDA baslatilir — PdfPreview'in davranisi bu.
    final sonuclar = await Future.wait([
      PdfTrFonts.load(),
      PdfTrFonts.load(),
      PdfTrFonts.load(),
      PdfTrFonts.load(),
      PdfTrFonts.load(),
    ]);

    // Iki font dosyasi var; her biri BIR kez okunmali.
    expect(
      okumaSayisi,
      2,
      reason: 'font $okumaSayisi kez okundu — yaris durumu var, '
          'es zamanli cagrilar ayni yuklemeyi paylasmali',
    );

    // Hepsi ayni nesneyi almali.
    for (final s in sonuclar) {
      expect(identical(s.regular, sonuclar.first.regular), isTrue);
      expect(identical(s.bold, sonuclar.first.bold), isTrue);
    }
  });

  test('onbellek sonrasi tekrar okumaz', () async {
    await PdfTrFonts.load();
    expect(okumaSayisi, 2);

    await PdfTrFonts.load();
    await PdfTrFonts.load();
    expect(okumaSayisi, 2, reason: 'onbellek calismiyor');
  });

  test('tema es zamanli istendiginde de tek yukleme', () async {
    await Future.wait([
      PdfTrFonts.theme(),
      PdfTrFonts.theme(),
      PdfTrFonts.document(),
    ]);
    expect(okumaSayisi, 2);
  });
}
