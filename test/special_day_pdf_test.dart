import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/features/documents/data/special_days_repository.dart';
import 'package:sinifcepte/features/documents/utils/special_day_pdf_generator.dart';

/// Belirli gun icin uretilen iki resmi belge.
///
/// ## Neden bu testler var
/// Ogretmen bu gunlerde IKI kez evrak uretiyor: once "ne yapacagiz"
/// (plan, idareye onceden verilir), sonra "ne yaptik" (rapor, ogretmen
/// dosyasina konur ve mudur imzalar). Ikisi de gercekten uretilmeli;
/// derlenmesi yetmez.
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

  Future<(SpecialDay, PanoContent?)> gunGetir(String ad) async {
    SpecialDaysRepository.resetCache();
    PanoContentRepository.resetCache();
    final gun = (await SpecialDaysRepository().all())
        .firstWhere((e) => e.ad == ad);
    final icerik = await PanoContentRepository().forDay(ad);
    return (gun, icerik);
  }

  test('KRITIK: etkinlik plani uretiliyor', () async {
    final (gun, icerik) = await gunGetir('Ulusal Egemenlik ve Çocuk Bayramı');
    final b = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan Ortaokulu',
      className: '5-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    expect(b.length, greaterThan(2000));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: calisma raporu uretiliyor', () async {
    final (gun, icerik) = await gunGetir('Cumhuriyet Bayramı');
    final b = await SpecialDayPdfGenerator.kutlamaRaporu(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan Ortaokulu',
      className: '5-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    expect(b.length, greaterThan(2000));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: icerigi OLMAYAN gunde de belge uretilir', () async {
    // 61 maddenin cogunda hazir icerik yok; PDF yine de basilmali,
    // ogretmen kendi planini elle doldursun.
    final (gun, _) = await gunGetir('Vergi Haftası');
    final plan = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: null,
      schoolName: '',
      className: '',
      teacherName: '',
      academicYear: '2026-2027',
    );
    final rapor = await SpecialDayPdfGenerator.kutlamaRaporu(
      gun: gun,
      icerik: null,
      schoolName: '',
      className: '',
      teacherName: '',
      academicYear: '2026-2027',
    );
    expect(plan.length, greaterThan(1000));
    expect(rapor.length, greaterThan(1000));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: kurul tipi gun (tarihi degisken) belge uretir', () async {
    // "Enerji Tasarrufu Haftasi (Ocak ayinin 2. haftasi)" — tarih
    // hesaplanamaz ama belge yine de basilabilmeli.
    final (gun, icerik) = await gunGetir('Enerji Tasarrufu Haftası');
    expect(gun.kesinTarihli, isFalse);
    final b = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Okul',
      className: '5-A',
      teacherName: 'Öğretmen',
      academicYear: '2026-2027',
    );
    expect(b.length, greaterThan(1000));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: etkinlik plani senaryodur, sinif calismasi icermez', () async {
    final (gun, icerik) = await gunGetir('İlköğretim Haftası');
    final plan = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '3-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: plan);
    final metin = PdfTextExtractor(doc).extractText();
    final sayfa = doc.pages.count;
    doc.dispose();

    final duz = metin.replaceAll(RegExp(r'\s+'), ' ');
    expect(sayfa, inInclusiveRange(1, 3),
        reason: 'bos imza sayfasi olmamali');
    expect(duz, isNot(contains('SINIF ÇALIŞMALARI')));
    expect(duz, isNot(contains('PANO BAŞLIKLARI')));
    expect(duz, isNot(contains('Merhaba Okulum panosu')));
    expect(duz, contains('PROGRAM AKIŞI'));
    expect(duz, contains('Sunucu:'));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: calisma raporu tek sayfada kalir', () async {
    final (gun, icerik) = await gunGetir('İlköğretim Haftası');
    final rapor = await SpecialDayPdfGenerator.kutlamaRaporu(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '3-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: rapor);
    final metin = PdfTextExtractor(doc).extractText();
    final sayfa = doc.pages.count;
    doc.dispose();

    final duz = metin.replaceAll(RegExp(r'\s+'), ' ');
    expect(sayfa, 1, reason: 'rapor bos ikinci sayfa acmamali');
    expect(duz, contains('UYGULANAN PROGRAM'));
    expect(duz, isNot(contains('Merhaba Okulum panosu')));
    expect(duz, isNot(contains('Okulumu boyuyorum')));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: 23 Nisan plani senaryodur', () async {
    final (gun, icerik) = await gunGetir(
      'Ulusal Egemenlik ve Çocuk Bayramı',
    );
    expect(icerik!.mebKaynakli, isTrue);
    final plan = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '4-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: plan);
    final duz = PdfTextExtractor(doc)
        .extractText()
        .replaceAll(RegExp(r'\s+'), ' ');
    final sayfa = doc.pages.count;
    doc.dispose();

    expect(sayfa, inInclusiveRange(1, 5),
        reason: 'bos imza sayfasi olmamali');
    expect(duz, contains('KUTLAMA PROGRAMI'));
    expect(duz, contains('Görevli'));
    expect(duz, contains('PROGRAM AKIŞI'));
    expect(duz, contains('Sunucu:'));
    expect(duz, contains('Egemenlik millete aittir'));
    expect(duz, contains('Sandalye kapmaca'));
    expect(duz, contains('Çuval yarışı'));
    expect(duz, contains('Yumurta taşıma'));
    expect(duz, contains('Müzik dinletisi'));
    expect(duz, contains('Oynanış'));
    expect(duz.toLowerCase(), isNot(contains('40 dakika')));
    expect(duz.toLowerCase(), isNot(contains('ders süresi')));
    expect(duz, isNot(contains('SINIF ÇALIŞMALARI')));
    expect(duz, isNot(contains('PANO BAŞLIKLARI')));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: 15 Temmuz plani senaryodur', () async {
    final (gun, icerik) = await gunGetir(
      '15 Temmuz Demokrasi ve Millî Birlik Günü',
    );
    final plan = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan Ortaokulu',
      className: '5-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: plan);
    final duz = PdfTextExtractor(doc)
        .extractText()
        .replaceAll(RegExp(r'\s+'), ' ');
    final sayfa = doc.pages.count;
    doc.dispose();

    // Üst sınır 5: program yedi maddeye çıktı ve konuşma metinleri
    // zenginleşti. Sınırın amacı sayfa saymak değil, planın bir
    // *senaryo* olarak kalmasını korumak — aşağıdaki isNot() koşulları
    // sınıf çalışması/pano içeriğinin buraya sızmadığını doğruluyor.
    expect(sayfa, inInclusiveRange(1, 5));
    expect(duz, contains('PROGRAM AKIŞI'));
    expect(duz, contains('Sunucu:'));
    expect(duz, isNot(contains('SINIF ÇALIŞMALARI')));
    expect(duz, isNot(contains('PANO BAŞLIKLARI')));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: Ilkogretim Haftasi uc belgeyi de uretir', () async {
    final (gun, icerik) = await gunGetir('İlköğretim Haftası');
    expect(icerik, isNotNull);
    expect(icerik!.torenVar, isTrue);
    expect(icerik.etkinlikler.length, greaterThanOrEqualTo(3));
    final plan = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '3-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final rapor = await SpecialDayPdfGenerator.kutlamaRaporu(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '3-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final pano = await SpecialDayPdfGenerator.panoCalismasi(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '3-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    expect(plan.length, greaterThan(2000));
    expect(rapor.length, greaterThan(2000));
    expect(pano.length, greaterThan(2000));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: Ataturk Haftasi uc belgeyi de uretir', () async {
    final (gun, icerik) = await gunGetir('Atatürk Haftası');
    expect(icerik, isNotNull);
    expect(icerik!.torenVar, isTrue);
    final plan = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan Ortaokulu',
      className: '5-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final rapor = await SpecialDayPdfGenerator.kutlamaRaporu(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan Ortaokulu',
      className: '5-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final pano = await SpecialDayPdfGenerator.panoCalismasi(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan Ortaokulu',
      className: '5-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    expect(plan.length, greaterThan(2000));
    expect(rapor.length, greaterThan(2000));
    expect(pano.length, greaterThan(2000));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: pano calismasi PDF uretiliyor', () async {
    final (gun, icerik) = await gunGetir('Ulusal Egemenlik ve Çocuk Bayramı');
    final b = await SpecialDayPdfGenerator.panoCalismasi(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan Ortaokulu',
      className: '5-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    expect(b.length, greaterThan(2000));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: 23 Nisan pano afis ve kes-yapistir paketi', () async {
    final (gun, icerik) = await gunGetir(
      'Ulusal Egemenlik ve Çocuk Bayramı',
    );
    expect(icerik!.zenginPano, isTrue);
    expect(icerik.panoDortlukler.length, 4);
    final b = await SpecialDayPdfGenerator.panoCalismasi(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '4-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: b);
    final duz = PdfTextExtractor(doc)
        .extractText()
        .replaceAll(RegExp(r'\s+'), ' ');
    final sayfa = doc.pages.count;
    doc.dispose();

    expect(sayfa, 3);
    expect(duz, contains('23 Nisan Dileğim'));
    expect(duz, contains('Mustafa Kemal Atatürk'));
    expect(duz, contains('TBMM'));
    expect(duz, contains('Biliyor muydunuz'));
    expect(duz, contains('KES'));
    expect(duz, contains('Burayı sen çiz'));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: pano sube ve ogretmen adi tasimaz, okul adi tasir', () async {
    // Pano duvara asilir ve ayni cikti her ogretmen tarafindan
    // kullanilabilmelidir. Uzerinde "4-A" yazarsa o pano tek subenin mali
    // olur. Okul adi ise panoyu okula ait kilar, kimseyi disarida birakmaz.
    //
    // Plan ve rapor resmi evraktir; onlarda sube ve hazirlayan adi DURUR
    // (asagida ayrica dogrulanir).
    final (gun, icerik) = await gunGetir(
      'Ulusal Egemenlik ve Çocuk Bayramı',
    );
    final pano = await SpecialDayPdfGenerator.panoCalismasi(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '4-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final panoDoc = PdfDocument(inputBytes: pano);
    final panoMetin = PdfTextExtractor(panoDoc)
        .extractText()
        .replaceAll(RegExp(r'\s+'), ' ');
    panoDoc.dispose();

    expect(panoMetin, isNot(contains('4-A')),
        reason: 'sube adi panoyu tek sinifa kilitler');
    expect(panoMetin.toUpperCase(), isNot(contains('YUSUF')),
        reason: 'ogretmen adi panoya basilmaz');
    // Zengin pano okul adini afis basligina buyuk harfle basar.
    expect(panoMetin.toUpperCase(), contains('MİMAR SİNAN'),
        reason: 'okul adi panoda durur');
    expect(panoMetin, contains('Adı:'),
        reason: 'ogrenci adi icin bos satir bulunmali');

    // Plan resmi evrak: sube ve hazirlayan adi burada DURMALI.
    final plan = await SpecialDayPdfGenerator.etkinlikPlani(
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      className: '4-A',
      teacherName: 'Yusuf YILMAZ',
      academicYear: '2026-2027',
    );
    final planDoc = PdfDocument(inputBytes: plan);
    final planMetin = PdfTextExtractor(planDoc)
        .extractText()
        .replaceAll(RegExp(r'\s+'), ' ');
    planDoc.dispose();

    expect(planMetin, contains('4-A'),
        reason: 'plan resmi evraktir, sube adi tasir');
    expect(planMetin, contains('Yusuf YILMAZ'),
        reason: 'plan resmi evraktir, hazirlayan adi tasir');
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('KRITIK: duz pano da sube tasimaz', () async {
    // Duz pano yolu, vecize/dilek karti TASIMAYAN gunler icindir.
    //
    // 20 gunun hepsi artik zengin icerik tasidigi icin bu yol gercek
    // veriyle tetiklenmiyor; ama icerigi eksik bir gun eklenirse yine
    // devreye girer. O yuzden yolu gercek gunden bagimsiz sinariz —
    // testi bir gunun icerigine baglamak, icerik zenginlestikce
    // testi kirilgan yapiyor.
    final (gun, _) = await gunGetir('Atatürk Haftası');
    const icerik = PanoContent(
      ad: 'Atatürk Haftası',
      kaynak: 'genel',
      ozet: 'Sade icerikli gun ornegi.',
      panoBaslik: 'ATATÜRK HAFTASI',
      sloganlar: ['Hayatta en hakiki mürşit ilimdir'],
    );
    expect(icerik.zenginPano, isFalse, reason: 'duz pano yolu bekleniyor');

    final pano = await SpecialDayPdfGenerator.panoCalismasi(
      gun: gun,
      icerik: icerik,
      schoolName: 'Cumhuriyet Ortaokulu',
      className: '7-B',
      teacherName: 'Ayşe DEMİR',
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: pano);
    final metin =
        PdfTextExtractor(doc).extractText().replaceAll(RegExp(r'\s+'), ' ');
    doc.dispose();

    expect(metin, isNot(contains('7-B')),
        reason: 'sube adi panoyu tek sinifa kilitler');
    expect(metin.toUpperCase(), isNot(contains('AYŞE')),
        reason: 'ogretmen adi panoya basilmaz');
    expect(metin, contains('Cumhuriyet Ortaokulu'),
        reason: 'okul adi panoda durur');
    expect(metin, contains('Adı Soyadı'),
        reason: 'ogrenci icin bos ad satiri bulunmali');
    expect(metin, contains('Sınıfı:'),
        reason: 'sube basili degil, ogrenci elle yazar');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
