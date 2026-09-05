import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Iki paketin de PdfColor'i var; palet olcumu 'pdf' paketininkini
// kullanir, metin cikarma syncfusion'i.
import 'package:pdf/pdf.dart' show PdfColor;
import 'package:syncfusion_flutter_pdf/pdf.dart' hide PdfColor;

import 'package:sinifcepte/features/documents/data/special_days_repository.dart';
import 'package:sinifcepte/features/documents/utils/pano_layouts.dart';
import 'package:sinifcepte/features/documents/utils/pano_palette.dart';
import 'package:sinifcepte/features/documents/utils/special_day_pdf_generator.dart';

/// Pano kurgulari — on ayri pano duzeni.
///
/// ## Neden bu testler var
/// Ogretmen bir kurgu secip PDF aliyor. Kurgu derlenmesi yetmez;
/// gercekten sayfa uretmeli, icerigi tasimalidir. Bos veya tek sayfalik
/// bir cikti ogretmeni panonun basinda birakir.
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
    final gunler = await SpecialDaysRepository().all();
    final gun = gunler.firstWhere((g) => g.ad == ad);
    final icerik = await PanoContentRepository().forDay(ad);
    return (gun, icerik);
  }

  Future<(int, String)> uret(
    PanoKurgu kurgu,
    SpecialDay gun,
    PanoContent? icerik,
  ) async {
    final b = await SpecialDayPdfGenerator.panoKurgusu(
      kurgu: kurgu,
      gun: gun,
      icerik: icerik,
      schoolName: 'Mimar Sinan İlkokulu',
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: b);
    final metin =
        PdfTextExtractor(doc).extractText().replaceAll(RegExp(r'\s+'), ' ');
    final sayfa = doc.pages.count;
    doc.dispose();
    return (sayfa, metin);
  }

  group('Kurgu secimi', () {
    test('KRITIK: icerigi olmayan kurgu listelenmez', () async {
      // Kural: alani bos olan kurgu listelenmez. Ogretmene
      // calismayacak bir secenek sunmak, bos PDF demektir.
      //
      // Bu kural bir gun adiyla degil, bos icerikle sinanir: veri
      // zenginlestikce "su gunun su alani bos" varsayimi eskiyor
      // (20 gunun hepsine oncesiSonrasi eklendiginde bu test Orman
      // Haftasi uzerinden yanlis alarm vermisti).
      final (gun, _) = await gunGetir('Orman Haftası');
      const bos = PanoContent(ad: 'Deneme', kaynak: 'genel', ozet: 'Ozet.');
      final uygun = PanoKurgular.uygunOlanlar(gun, bos);

      expect(uygun, isNot(contains(PanoKurgu.onceSonra)),
          reason: 'oncesiSonrasi bos');
      expect(uygun, isNot(contains(PanoKurgu.tarihSeridi)),
          reason: 'kronoloji bos');
      expect(uygun, isNot(contains(PanoKurgu.kavramSozlugu)),
          reason: 'sozluk bos');
      expect(uygun, contains(PanoKurgu.devBaslik),
          reason: 'dev baslik her gun calisir');
      expect(uygun, contains(PanoKurgu.kartDestesi),
          reason: 'kart destesi ozetten turetilir');
    });

    test('KRITIK: zengin icerikli gunde cok kurgu cikar', () async {
      final (gun, icerik) = await gunGetir(
        'Ulusal Egemenlik ve Çocuk Bayramı',
      );
      final uygun = PanoKurgular.uygunOlanlar(gun, icerik);

      expect(uygun.length, greaterThanOrEqualTo(5),
          reason: '23 Nisan icerigi zengin, secenek bol olmali');
      expect(uygun, contains(PanoKurgu.tarihSeridi));
      expect(uygun, contains(PanoKurgu.merkezVecize));
      expect(uygun, contains(PanoKurgu.siirDuvari));
      expect(uygun, contains(PanoKurgu.biliyorMuydunuz));
    });

    test('her kurgunun tanimi var', () {
      for (final k in PanoKurgu.values) {
        final t = PanoKurgular.tanimlar[k];
        expect(t, isNotNull, reason: '$k tanimsiz');
        expect(t!.ad.trim(), isNotEmpty);
        expect(t.aciklama.trim(), isNotEmpty);
      }
    });
  });

  group('Kurgu uretimi', () {
    test('KRITIK: uygun her kurgu gercekten sayfa uretir', () async {
      final (gun, icerik) = await gunGetir(
        'Ulusal Egemenlik ve Çocuk Bayramı',
      );
      final uygun = PanoKurgular.uygunOlanlar(gun, icerik);

      for (final k in uygun) {
        final (sayfa, metin) = await uret(k, gun, icerik);
        expect(sayfa, greaterThan(0),
            reason: '${PanoKurgular.tanimlar[k]!.ad} sayfa uretmedi');
        expect(metin.trim(), isNotEmpty,
            reason: '${PanoKurgular.tanimlar[k]!.ad} bos cikti');
      }
    }, timeout: const Timeout(Duration(seconds: 180)));

    test('KRITIK: dev baslik harfleri gunun adini tasir', () async {
      final (gun, icerik) = await gunGetir('Orman Haftası');
      final (sayfa, metin) = await uret(PanoKurgu.devBaslik, gun, icerik);

      // "ORMAN HAFTASI" 12 harf -> sayfa basina 4 -> 3 sayfa.
      expect(sayfa, 3);
      expect(metin, contains('O'));
      expect(metin, contains('KES'), reason: 'kesme isareti bulunmali');
      expect(metin, contains('harf sayfası'));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('KRITIK: tarih seridi kronolojiyi tasir', () async {
      final (gun, icerik) = await gunGetir(
        'Ulusal Egemenlik ve Çocuk Bayramı',
      );
      final (sayfa, metin) = await uret(PanoKurgu.tarihSeridi, gun, icerik);

      expect(sayfa, greaterThanOrEqualTo(1));
      expect(metin, contains('TARİH ŞERİDİ'));
      // Kısaltma da açık yazım da geçerli. Kronoloji derinleştirilirken
      // "TBMM" açılarak yazıldı; panoyu okuyan ilkokul öğrencisi
      // kısaltmayı çözmek zorunda kalmasın diye. Aranan şey Meclis'in
      // anılması, hangi biçimde yazıldığı değil.
      expect(
        metin.contains('TBMM') || metin.contains('Büyük Millet Meclisi'),
        isTrue,
        reason: 'tarih şeridinde Meclis anılmıyor',
      );
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('KRITIK: biliyor muydunuz olgulari tasir', () async {
      final (gun, icerik) = await gunGetir(
        'Ulusal Egemenlik ve Çocuk Bayramı',
      );
      final (sayfa, metin) =
          await uret(PanoKurgu.biliyorMuydunuz, gun, icerik);

      expect(sayfa, 1, reason: 'tek sayfada kalmali');
      expect(metin, contains('BİLİYOR MUYDUNUZ'));
      expect(metin, contains('armağan'));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('KRITIK: ON KURGUNUN HEPSI uretilir', () async {
      // Kizilay Haftasi havuz semasiyla yazilmis ilk gun: on kurgunun
      // hepsini besleyecek veriyi tasiyor. Bir kurgu burada uretilmiyorsa
      // sema ile cizim arasinda kopukluk var demektir.
      final (gun, icerik) = await gunGetir('Kızılay Haftası');
      final uygun = PanoKurgular.uygunOlanlar(gun, icerik);

      expect(uygun.length, PanoKurgu.values.length,
          reason: 'Kizilay tum kurgulari beslemeli, cikan: '
              '${uygun.map((k) => PanoKurgular.tanimlar[k]!.ad).join(", ")}');

      for (final k in PanoKurgu.values) {
        final (sayfa, metin) = await uret(k, gun, icerik);
        expect(sayfa, greaterThan(0),
            reason: '${PanoKurgular.tanimlar[k]!.ad} sayfa uretmedi');
        expect(metin.length, greaterThan(40),
            reason: '${PanoKurgular.tanimlar[k]!.ad} icerik tasimiyor');
      }
    }, timeout: const Timeout(Duration(seconds: 240)));

    test('KRITIK: once-sonra karsilastirmayi tasir', () async {
      final (gun, icerik) = await gunGetir('Kızılay Haftası');
      final (sayfa, metin) = await uret(PanoKurgu.onceSonra, gun, icerik);

      expect(sayfa, greaterThanOrEqualTo(1));
      expect(metin, contains('ÖNCE'));
      expect(metin, contains('SONRA'));
      expect(metin, contains('Afet çantası önceden hazırlanır'));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('KRITIK: soru-cevap kapakcigi cevabi tasir', () async {
      final (gun, icerik) = await gunGetir('Kızılay Haftası');
      final (sayfa, metin) = await uret(PanoKurgu.soruCevap, gun, icerik);

      expect(sayfa, greaterThanOrEqualTo(1));
      expect(metin, contains('Kızılay ne zaman kuruldu?'));
      expect(metin, contains('katlayın'), reason: 'katlama yonergesi');
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('KRITIK: siir duvari dortlukleri tasir', () async {
      final (gun, icerik) = await gunGetir(
        'Ulusal Egemenlik ve Çocuk Bayramı',
      );
      final (sayfa, metin) = await uret(PanoKurgu.siirDuvari, gun, icerik);

      expect(sayfa, 1);
      expect(metin, contains('ŞİİR DUVARI'));
      expect(metin, contains('Yirmi üç Nisan'));
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('Kural: pano herkesin kullanabilecegi olmali', () {
    test('KRITIK: hicbir kurgu sube veya ogretmen adi tasimaz', () async {
      // panoKurgusu() zaten className/teacherName ALMIYOR — imza
      // seviyesinde engellenmis. Bu test o guvenceyi ciktida dogrular.
      final (gun, icerik) = await gunGetir(
        'Ulusal Egemenlik ve Çocuk Bayramı',
      );
      for (final k in PanoKurgular.uygunOlanlar(gun, icerik)) {
        final (_, metin) = await uret(k, gun, icerik);
        expect(metin, isNot(contains(RegExp(r'\b\d\s*[-/]\s*[A-ZÇĞİÖŞÜ]\b'))),
            reason: '${PanoKurgular.tanimlar[k]!.ad} sube adi tasiyor');
      }
    }, timeout: const Timeout(Duration(seconds: 180)));

    test('ogrenci dolduran kurgularda bos ad satiri var', () async {
      final (gun, icerik) = await gunGetir(
        'Ulusal Egemenlik ve Çocuk Bayramı',
      );
      final (_, metin) = await uret(PanoKurgu.ogrenciAgaci, gun, icerik);
      expect(metin, contains('Adı Soyadı'));
      expect(metin, contains('Sınıfı'),
          reason: 'sube basili degil, ogrenci elle yazar');
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('Kapsam: 20 gunun tamami', () {
    test('KRITIK: her gun en az yedi kurgu uretebiliyor', () async {
      // Ogretmene secenek sunmanin karsiligi bu. Bir gun iki kurguya
      // dusuyorsa o gunun icerigi eksik demektir; tablo bunu gosterir.
      SpecialDaysRepository.resetCache();
      PanoContentRepository.resetCache();
      final gunler = await SpecialDaysRepository().withActivities();
      final repo = PanoContentRepository();

      final zayif = <String>[];
      var toplam = 0;
      for (final g in gunler) {
        final icerik = await repo.forDay(g.ad);
        if (icerik == null) continue;
        final n = PanoKurgular.uygunOlanlar(g, icerik).length;
        toplam += n;
        if (n < 7) zayif.add('${g.ad}: $n kurgu');
      }

      expect(zayif, isEmpty,
          reason: 'icerigi eksik gunler: ${zayif.join(" | ")}');
      expect(toplam, greaterThanOrEqualTo(150),
          reason: 'toplam pano secenegi: $toplam');
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('KRITIK: her gunun her kurgusu sayfa uretir', () async {
      // En pahali test ama en degerlisi: 180+ PDF gercekten uretiliyor mu.
      // Bir gunun bir alani bozuksa (bos kronoloji, eksik cevap) burada
      // cikar — ogretmenin elinde bos PDF kalmaz.
      SpecialDaysRepository.resetCache();
      PanoContentRepository.resetCache();
      final gunler = await SpecialDaysRepository().withActivities();
      final repo = PanoContentRepository();

      final hatalar = <String>[];
      var uretilen = 0;
      for (final g in gunler) {
        final icerik = await repo.forDay(g.ad);
        if (icerik == null) continue;
        for (final k in PanoKurgular.uygunOlanlar(g, icerik)) {
          final (sayfa, metin) = await uret(k, g, icerik);
          uretilen++;
          if (sayfa < 1 || metin.trim().length < 40) {
            hatalar.add('${g.ad} / ${PanoKurgular.tanimlar[k]!.ad}');
          }
        }
      }

      expect(hatalar, isEmpty, reason: 'bos cikan: ${hatalar.join(" | ")}');
      expect(uretilen, greaterThanOrEqualTo(150),
          reason: 'uretilen pano sayisi: $uretilen');
    }, timeout: const Timeout(Duration(seconds: 600)));
  });

  group('Palet: siyah-beyaz baski', () {
    test('KRITIK: her gunun paleti gri merdivene oturur', () async {
      // Ogretmenlerin cogu s/b yaziciyla basiyor. Renk gri tonuna
      // dustugunde koyu/orta/acik birbirinden ayrilabilmeli.
      double luma(PdfColor c) =>
          0.299 * c.red * 255 + 0.587 * c.green * 255 + 0.114 * c.blue * 255;

      final gunler = await SpecialDaysRepository().all();
      for (final g in gunler) {
        final p = PanoPalette.of(g.ad);
        final lk = luma(p.koyu), lo = luma(p.orta), la = luma(p.acik);

        expect(lk, inInclusiveRange(42, 62), reason: '${g.ad}: koyu bandi');
        expect(lo, inInclusiveRange(92, 118), reason: '${g.ad}: orta bandi');
        expect(la, inInclusiveRange(200, 228), reason: '${g.ad}: acik bandi');
        expect((lk - lo).abs(), greaterThanOrEqualTo(40),
            reason: '${g.ad}: koyu ile orta s/b baskida karisir');
      }
    });
  });
}
