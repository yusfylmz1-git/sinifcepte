import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/core/utils/turkish_text.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/student_photos/data/foto_albumu_pdf.dart';
import 'package:sinifcepte/features/student_photos/data/foto_depolama.dart';
import 'package:sinifcepte/features/student_photos/data/foto_disa_aktarici.dart';
import 'package:sinifcepte/features/student_photos/domain/disa_aktarim_plani.dart';
import 'package:sinifcepte/features/student_photos/domain/ogrenci_foto.dart';

/// Faz 5: dışa aktarma planı, ZIP paketi, PDF albüm ve kontrol listesi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // PDF gömülü Türkçe fontu yüklüyor; varlık isteği diskten karşılanır.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final f = File(utf8.decode(message!.buffer.asUint8List()));
      return f.existsSync() ? Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData() : null;
    });
  });

  const a5 = ClassModel(id: 1, name: '5/A', subject: 'Türkçe', academicYear: '2026-2027');
  const b5 = ClassModel(id: 2, name: '5-B', subject: 'Türkçe', academicYear: '2026-2027');

  StudentModel ogr(int id, int no, String ad, String soyad, {int sinif = 1}) =>
      StudentModel(id: id, classId: sinif, schoolNumber: no, firstName: ad, lastName: soyad);

  OgrenciFoto foto(int ogrenciId, {int no = 0, String ad = '', String? yol, String ozet = 'x', String durum = FotoDurumu.hazir, DateTime? cekim}) =>
      OgrenciFoto(
        id: ogrenciId.toRadixString(16).padLeft(32, '0'),
        studentId: ogrenciId,
        revision: 1,
        status: durum,
        standardPath: yol ?? 'h/$ogrenciId/${ogrenciId.toRadixString(16).padLeft(32, '0')}/standard.jpg',
        width: 133,
        height: 171,
        byteSize: 1,
        checksum: ozet,
        sourceType: FotoKaynagi.dosya,
        capturedSchoolNumber: no,
        capturedFullName: ad,
        identityConfirmedAt: DateTime(2026, 9, 30),
        capturedAt: cekim ?? DateTime(2026, 9, 30),
        approvedAt: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
      );

  final zaman = DateTime(2026, 9, 30, 14, 30, 5);

  group('plan', () {
    test('KRITIK: sınıf klasörü, okunaklı dosya adı, numara sırası', () {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(10, 1234, 'İsmail', 'IŞIK'), ogr(11, 5, 'Ali', 'CAN')]),
        ],
        fotolar: {10: foto(10, no: 1234, ad: 'İsmail IŞIK'), 11: foto(11, no: 5, ad: 'Ali CAN')},
        zaman: zaman,
      );
      expect(plan.kalemler.map((k) => k.paketYolu), ['5-A/5_Ali_CAN.jpg', '5-A/1234_İsmail_IŞIK.jpg']);
      expect(plan.paketAdi, 'SinifCepte_Fotograflar_2026-2027_20260930_143005');
      expect(plan.uretilebilir, isTrue);
    });

    test('KRITIK: aynı güvenli ada düşen iki sınıf ayrı klasöre, kararlı ekle', () {
      const c = ClassModel(id: 3, name: '5-a', subject: 'x', academicYear: '2026-2027');
      final plan = disaAktarimPlanla(
        siniflar: [
          (c, [ogr(30, 1, 'C', 'C', sinif: 3)]),
          (a5, [ogr(10, 1, 'A', 'A')]),
        ],
        fotolar: {30: foto(30, no: 1, ad: 'C C'), 10: foto(10, no: 1, ad: 'A A')},
        zaman: zaman,
      );
      final klasor = {for (final k in plan.kalemler) k.sinif.id: k.klasor};
      expect(klasor[1], '5-A', reason: 'küçük kimlikli sınıf eksiz');
      expect(klasor[3], '5-a_(2)', reason: 'Windows büyük/küçük harf ayırmaz');
    });

    test('aynı numara farklı sınıflarda sorun değil (klasörler ayrı)', () {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(10, 102, 'Ayşe', 'YILMAZ')]),
          (b5, [ogr(20, 102, 'Elif', 'DEMİR', sinif: 2)]),
        ],
        fotolar: {10: foto(10, no: 102, ad: 'Ayşe YILMAZ'), 20: foto(20, no: 102, ad: 'Elif DEMİR')},
        zaman: zaman,
      );
      expect(plan.engelleyenler, isEmpty);
      expect(plan.aktarilacak.length, 2);
    });

    test('KRITIK: engeller ve eksikler doğru ayrılıyor', () {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [
            ogr(1, 1, 'Tamam', 'KİŞİ'),
            ogr(2, 2, 'Fotosuz', 'KİŞİ'),
            ogr(3, 3, 'Kayıp', 'DOSYA'),
            ogr(4, 4, 'Soyadsız', ''),
            ogr(5, 7, 'Çift', 'BİR'),
            ogr(6, 7, 'Çift', 'İKİ'),
            ogr(8, 8, 'Yeni', 'AD'),
          ]),
        ],
        fotolar: {
          1: foto(1, no: 1, ad: 'Tamam KİŞİ'),
          3: foto(3, no: 3, ad: 'Kayıp DOSYA'),
          4: foto(4, no: 4, ad: 'Soyadsız'),
          5: foto(5, no: 7, ad: 'Çift BİR'),
          6: foto(6, no: 7, ad: 'Çift İKİ'),
          8: foto(8, no: 8, ad: 'Eski AD'),
        },
        dosyaVar: (f) => f.studentId != 3,
        zaman: zaman,
      );
      final durum = {for (final k in plan.kalemler) k.ogrenci.id: k.durum};
      expect(durum, {
        1: AktarimDurumu.tamam,
        2: AktarimDurumu.fotografYok,
        3: AktarimDurumu.dosyaKayip,
        4: AktarimDurumu.adEksik,
        5: AktarimDurumu.numaraCakismasi,
        6: AktarimDurumu.numaraCakismasi,
        8: AktarimDurumu.kimlikFarkli,
      });
      expect(plan.uretilebilir, isFalse);
      expect(plan.engelNedeni, contains('4 öğrencide'));
      expect(plan.eksikler.length, 2);
    });

    test('yalnızca eksikler varsa paket yine üretilebilir', () {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(1, 1, 'A', 'B'), ogr(2, 2, 'C', 'D')]),
        ],
        fotolar: {1: foto(1, no: 1, ad: 'A B')},
        zaman: zaman,
      );
      expect(plan.uretilebilir, isTrue);
      expect(plan.eksikler.single.ogrenci.id, 2);
    });

    test('güvenli klasör adı', () {
      expect(guvenliKlasorAdi('5/A'), '5-A');
      expect(guvenliKlasorAdi(' 10 A Şubesi. '), '10_A_Şubesi');
      expect(guvenliKlasorAdi('..'), 'Sinif');
      expect(guvenliKlasorAdi('a:b*c?'), 'a-b-c-');
    });

    test('farklı öğretim yıllı sınıflarda paket adında yıl yok', () {
      const eski = ClassModel(id: 9, name: '6-A', subject: 'x', academicYear: '2025-2026');
      final plan = disaAktarimPlanla(siniflar: [(a5, const []), (eski, const [])], fotolar: const {}, zaman: zaman);
      expect(plan.paketAdi, 'SinifCepte_Fotograflar_20260930_143005');
    });
  });

  group('CSV', () {
    test('KRITIK: Excel Türkçe: BOM, noktalı virgül, CRLF, Türkçe harfler', () {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(1, 12, 'Şule', 'ÇAĞLAR')]),
        ],
        fotolar: {1: foto(1, no: 12, ad: 'Şule ÇAĞLAR', ozet: 'abc')},
        zaman: zaman,
      );
      final csv = eslestirmeCsv(plan);
      expect(csv.startsWith('\uFEFFSınıf;Okul No;Ad;Soyad;Klasör;Dosya Adı;SHA-256\r\n'), isTrue);
      expect(csv, contains('5/A;12;Şule;ÇAĞLAR;5-A;12_Şule_ÇAĞLAR.jpg;abc\r\n'));
    });

    test('KRITIK: formül enjeksiyonu ve ayırıcı kaçışı', () {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(1, 1, '=HYPERLINK("x")', 'A;B')]),
        ],
        fotolar: const {},
        zaman: zaman,
      );
      final csv = eksiklerCsv(plan);
      expect(csv, contains('"\'=HYPERLINK(""x"")"'));
      expect(csv, contains('"A;B"'));
      expect(csv, contains('Fotoğraf yok'));
    });
  });

  group('ZIP paketi', () {
    late Directory kok;
    late FotoDepolama depolama;
    late Directory hedef;

    setUp(() async {
      kok = await Directory.systemTemp.createTemp('disa_aktarim');
      depolama = FotoDepolama(Directory(p.join(kok.path, 'student_photos')));
      hedef = Directory(p.join(kok.path, 'cikti'));
    });
    tearDown(() async {
      try {
        await kok.delete(recursive: true);
      } catch (_) {}
    });

    Future<OgrenciFoto> kaydet(int id, int no, String ad, int renk) async {
      final r = img.Image(width: 133, height: 171);
      img.fill(r, color: img.ColorRgb8(renk, 50, 50));
      final bayt = Uint8List.fromList(img.encodeJpg(r));
      final yol = FotoDepolama.standartYol('h', id, id.toRadixString(16).padLeft(32, '0'));
      final ozet = await depolama.atomikYaz(yol, bayt);
      return foto(id, no: no, ad: ad, yol: yol, ozet: ozet);
    }

    Future<DisaAktarimPlani> kur() async {
      final f1 = await kaydet(1, 1234, 'İsmail IŞIK', 10);
      final f2 = await kaydet(2, 5, 'Ali CAN', 200);
      final f3 = await kaydet(3, 102, 'Elif DEMİR', 120);
      return disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(1, 1234, 'İsmail', 'IŞIK'), ogr(2, 5, 'Ali', 'CAN'), ogr(4, 9, 'Fotosuz', 'ÖĞRENCİ')]),
          (b5, [ogr(3, 102, 'Elif', 'DEMİR', sinif: 2)]),
        ],
        fotolar: {1: f1, 2: f2, 3: f3},
        zaman: zaman,
      );
    }

    test('KRITIK: sınıf klasörleri, Türkçe adlar, baytlar birebir, kontrol listeleri ayrı klasörde', () async {
      final plan = await kur();
      final s = await FotoDisaAktarici(depolama).zipUret(
        plan: plan,
        hedefDizin: hedef,
        kontrolPdf: Uint8List.fromList(utf8.encode('%PDF-sahte')),
      );
      expect(s.tamMi, isTrue);
      expect((s.eklenenFoto, s.beklenenFoto), (3, 3));

      final zipBayt = await s.zip.readAsBytes();
      final arsiv = ZipDecoder().decodeBytes(zipBayt, verify: true);
      final kokAd = plan.paketAdi;
      final adlar = arsiv.files.where((f) => f.isFile).map((f) => f.name).toSet();
      expect(adlar, {
        '$kokAd/5-A/1234_İsmail_IŞIK.jpg',
        '$kokAd/5-A/5_Ali_CAN.jpg',
        '$kokAd/5-B/102_Elif_DEMİR.jpg',
        '$kokAd/Kontrol_Listeleri/eslestirme.csv',
        '$kokAd/Kontrol_Listeleri/eksikler.csv',
        '$kokAd/Kontrol_Listeleri/kontrol_listesi.pdf',
      });
      for (final k in plan.aktarilacak) {
        final f = arsiv.findFile('$kokAd/${k.paketYolu}')!;
        expect(sha256.convert(f.content as List<int>).toString(), k.foto!.checksum);
        // Tür İÇERİK AÇILMADAN okunmalı: kütüphane içeriği açınca türü
        // STORE'a çeviriyor; `verify: true` da hepsini önceden açıyor.
        // İlk iki denemede bu yüzden test hiçbir şey ölçmüyordu.
        final ham = ZipDecoder().decodeBytes(zipBayt).findFile('$kokAd/${k.paketYolu}')!;
        expect(ham.compressionType, ArchiveFile.STORE, reason: 'JPEG yeniden sıkıştırılmaz');
      }
      final eksik = utf8.decode(arsiv.findFile('$kokAd/Kontrol_Listeleri/eksikler.csv')!.content as List<int>);
      expect(eksik, contains('9;Fotosuz;ÖĞRENCİ;Fotoğraf yok'));
    });

    test('KRITIK: Türkçe dosya adları ZIP\'te UTF-8 olarak işaretli (Windows bozuk göstermesin)', () async {
      final s = await FotoDisaAktarici(depolama).zipUret(plan: await kur(), hedefDizin: hedef);
      final b = await s.zip.readAsBytes();
      // İlk yerel dosya başlığı: imza 50 4B 03 04, genel amaçlı bayrak 6. bayt.
      expect(b.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
      final bayrak = b[6] | (b[7] << 8);
      expect(bayrak & 0x800, 0x800);
    });

    test('KRITIK: plandan sonra değişen fotoğraf pakete karışmıyor, açıkça listeleniyor', () async {
      final plan = await kur();
      // İkinci öğrencinin fotoğrafı plan kurulduktan sonra değişti.
      final degisen = plan.aktarilacak.firstWhere((k) => k.ogrenci.id == 2);
      await depolama.dosya(degisen.foto!.standardPath).writeAsBytes([1, 2, 3]);
      final s = await FotoDisaAktarici(depolama).zipUret(plan: plan, hedefDizin: hedef);
      expect(s.tamMi, isFalse, reason: 'eksik paket "başarılı" sayılmaz');
      expect((s.eklenenFoto, s.beklenenFoto), (2, 3));
      expect(s.hatalar.single, contains('5-A/5_Ali_CAN.jpg'));
      final arsiv = ZipDecoder().decodeBytes(await s.zip.readAsBytes());
      expect(arsiv.files.any((f) => f.name.endsWith('5_Ali_CAN.jpg')), isFalse);
    });

    test('KRITIK: iptal edilince yarım paket kalmıyor', () async {
      final plan = await kur();
      var n = 0;
      await expectLater(
        FotoDisaAktarici(depolama).zipUret(plan: plan, hedefDizin: hedef, iptalMi: () => n++ >= 1),
        throwsA(isA<DisaAktarimIptal>()),
      );
      expect(hedef.listSync().whereType<File>(), isEmpty);
    });

    test('KRITIK: diske yazılan paket bozuksa "hazır" denmiyor, paket siliniyor', () async {
      final plan = await kur();
      Future<void> boz(File zip) async {
        final b = await zip.readAsBytes();
        // İlk fotoğrafın JPEG başlangıcından sonraki bir baytı değiştir.
        final i = b.indexOf(0xFF, 40);
        b[i + 20] ^= 0xFF;
        await zip.writeAsBytes(b);
      }

      await expectLater(
        FotoDisaAktarici(depolama).zipUret(plan: plan, hedefDizin: hedef, kapandiktanSonra: boz),
        throwsA(isA<DisaAktarimHatasi>().having((e) => e.mesaj, 'mesaj', contains('doğrulanamadı'))),
      );
      expect(hedef.listSync().whereType<File>(), isEmpty);
    });

    test('engelli plan paket üretmiyor', () async {
      final f = await kaydet(1, 1, 'Eski AD', 10);
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(1, 1, 'Yeni', 'AD')]),
        ],
        fotolar: {1: f},
        zaman: zaman,
      );
      await expectLater(
        FotoDisaAktarici(depolama).zipUret(plan: plan, hedefDizin: hedef),
        throwsA(isA<DisaAktarimHatasi>()),
      );
      expect(await hedef.exists() ? hedef.listSync() : const [], isEmpty);
    });

    test('fotoğraf okuma yalnızca özeti tutanları veriyor', () async {
      final plan = await kur();
      await depolama.dosya(plan.aktarilacak.first.foto!.standardPath).writeAsBytes([9]);
      final m = await FotoDisaAktarici(depolama).fotolariOku(plan);
      expect(m.length, 2);
    });
  });

  group('PDF', () {
    String duz(String h) => h.replaceAll(RegExp(r'\s+'), ' ').trim();

    (DisaAktarimPlani, Map<String, Uint8List>) kalabalik(int n) {
      final ogrenciler = [for (var i = 1; i <= n; i++) ogr(i, i, 'Öğrenci$i', 'ŞAHİN')];
      final r = img.Image(width: 133, height: 171);
      final bayt = Uint8List.fromList(img.encodeJpg(r));
      final fotolar = <int, OgrenciFoto>{
        for (var i = 1; i <= n; i++)
          if (i != 3) i: foto(i, no: i, ad: 'Öğrenci$i ŞAHİN'),
      };
      final plan = disaAktarimPlanla(siniflar: [(a5, ogrenciler)], fotolar: fotolar, zaman: zaman);
      return (plan, {for (final f in fotolar.values) f.id: bayt});
    }

    test('KRITIK: albüm çok sayfaya taşıyor, Türkçe metin doğru, fotoğrafsız kart var', () async {
      final (plan, bayt) = kalabalik(40);
      final b = await albumPdfUret(plan: plan, fotoBaytlari: bayt, ayarlar: const AlbumAyarlari());
      final doc = PdfDocument(inputBytes: b);
      final metin = duz(PdfTextExtractor(doc).extractText());
      final sayfa = doc.pages.count;
      doc.dispose();
      final y = AlbumYerlesimi.hesapla(const AlbumAyarlari());
      expect(sayfa, (40 / y.sayfadaOgrenci(3)).ceil());
      expect(metin, contains('5/A · Fotoğraf albümü · 2026-2027'));
      expect(metin, contains('No: 40'));
      expect(metin, contains('Öğrenci40 ŞAHİN'));
      expect(metin, contains('Fotoğraf yok'));
      expect(metin, isNot(contains('kimlik eşleştirme belgesi değildir')));
    });

    test('fotoğrafsızlar istenmezse albümde yok', () async {
      final (plan, bayt) = kalabalik(5);
      final b = await albumPdfUret(
          plan: plan, fotoBaytlari: bayt, ayarlar: const AlbumAyarlari(fotografsizlar: false));
      final doc = PdfDocument(inputBytes: b);
      final metin = duz(PdfTextExtractor(doc).extractText());
      doc.dispose();
      expect(metin, isNot(contains('Fotoğraf yok')));
      expect(metin, isNot(contains('Öğrenci3 ')));
    });

    test('KRITIK: kimlik alanları kapalıysa "yalnız görsel albüm" uyarısı', () async {
      final (plan, bayt) = kalabalik(3);
      final b = await albumPdfUret(
        plan: plan,
        fotoBaytlari: bayt,
        ayarlar: const AlbumAyarlari(adSoyad: false, okulNo: false, siraNo: false),
      );
      final doc = PdfDocument(inputBytes: b);
      final metin = duz(PdfTextExtractor(doc).extractText());
      doc.dispose();
      expect(metin, contains('Yalnız görsel albüm — kimlik eşleştirme belgesi değildir.'));
    });

    test('sıra numarası albüm konumu, okul numarası değil', () async {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(1, 900, 'Zeynep', 'A'), ogr(2, 100, 'Ahmet', 'B')]),
        ],
        fotolar: const {},
        zaman: zaman,
      );
      final b = await albumPdfUret(
        plan: plan,
        fotoBaytlari: const {},
        ayarlar: const AlbumAyarlari(siraNo: true, sira: AlbumSirasi.numaraAzalan),
      );
      final doc = PdfDocument(inputBytes: b);
      final metin = duz(PdfTextExtractor(doc).extractText());
      doc.dispose();
      expect(metin, contains('1. No: 900'));
      expect(metin, contains('2. No: 100'));
    });

    test('KRITIK: kontrol listesi dosya adını ve engel durumunu gösteriyor', () async {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(1, 1234, 'İsmail', 'IŞIK'), ogr(2, 8, 'Yeni', 'AD')]),
        ],
        fotolar: {1: foto(1, no: 1234, ad: 'İsmail IŞIK'), 2: foto(2, no: 8, ad: 'Eski AD')},
        zaman: zaman,
      );
      final b = await kontrolListesiPdfUret(plan: plan, fotoBaytlari: const {}, zaman: zaman);
      final doc = PdfDocument(inputBytes: b);
      final metin = duz(PdfTextExtractor(doc).extractText());
      doc.dispose();
      expect(metin, contains('e-Okul fotoğraf eşleştirme kontrol listesi · 5/A'));
      expect(metin, contains('5-A/1234_İsmail_IŞIK.jpg'));
      expect(metin, contains('Kimlik kontrolü gerekli'));
    });
  });

  group('albüm yerleşimi ve sıra', () {
    test('KRITIK: her sütun/ölçek/yön birleşiminde sayfaya en az bir satır sığıyor', () {
      for (final sutun in [2, 3, 4]) {
        for (final o in AlbumOlcegi.values) {
          for (final yatay in [false, true]) {
            final a = AlbumAyarlari(sutun: sutun, olcek: o, yatay: yatay, siraNo: true, sinif: true, cekimTarihi: true);
            final y = AlbumYerlesimi.hesapla(a);
            expect(y.sayfadaSatir, greaterThanOrEqualTo(1), reason: '$sutun sütun $o yatay=$yatay');
            expect(y.fotoGenislik <= y.kartGenislik, isTrue);
            expect(y.fotoYukseklik / y.fotoGenislik, closeTo(171 / 133, 1e-9), reason: 'oran korunur');
          }
        }
      }
    });

    test('KRITIK: sığmayan büyük ölçek güvenli ölçeğe iniyor ve bunu söylüyor', () {
      final y = AlbumYerlesimi.hesapla(const AlbumAyarlari(sutun: 2, olcek: AlbumOlcegi.buyuk, yatay: true));
      expect(y.olcekDusuruldu, isTrue);
      expect(y.olcek.index < AlbumOlcegi.buyuk.index, isTrue);
      final normal = AlbumYerlesimi.hesapla(const AlbumAyarlari());
      expect(normal.olcekDusuruldu, isFalse);
    });

    test('KRITIK: Türk alfabesi sırası', () {
      final adlar = ['Zeynep', 'Şule', 'Çağla', 'Cem', 'İlker', 'Ilgaz', 'Ömer', 'Oya', 'ali can', 'Alican', 'Ğ'];
      adlar.sort(trKarsilastir);
      expect(adlar, ['ali can', 'Alican', 'Cem', 'Çağla', 'Ğ', 'Ilgaz', 'İlker', 'Oya', 'Ömer', 'Şule', 'Zeynep']);
    });

    test('albüm sıraları', () {
      final plan = disaAktarimPlanla(
        siniflar: [
          (a5, [ogr(3, 30, 'Şule', 'A'), ogr(1, 10, 'Zeynep', 'B'), ogr(2, 20, 'Cem', 'C')]),
        ],
        fotolar: {
          1: foto(1, no: 10, ad: 'Zeynep B', cekim: DateTime(2026, 9, 3)),
          3: foto(3, no: 30, ad: 'Şule A', cekim: DateTime(2026, 9, 1)),
        },
        zaman: zaman,
      );
      List<int> s(AlbumSirasi x) => albumSirasi(plan.kalemler, x).map((k) => k.ogrenci.schoolNumber).toList();
      expect(s(AlbumSirasi.numaraArtan), [10, 20, 30]);
      expect(s(AlbumSirasi.numaraAzalan), [30, 20, 10]);
      expect(s(AlbumSirasi.adSoyad), [20, 30, 10]);
      expect(s(AlbumSirasi.sinifListesi), [10, 20, 30]);
      expect(s(AlbumSirasi.cekimSirasi), [30, 10, 20], reason: 'fotoğrafsız sonda');
    });
  });
}
