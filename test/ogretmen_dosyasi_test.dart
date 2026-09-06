import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/documents/data/teacher_file_repository.dart';

import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/documents/data/teacher_file_model.dart';
import 'package:sinifcepte/features/documents/data/teacher_file_texts.dart';
import 'package:sinifcepte/features/documents/utils/teacher_file_pdf_generator.dart';

/// Öğretmen ders yılı dosyası.
///
/// ## Neden bu testler var
/// Kullanıcı istedi: *"öğretmenin bir teftişte kullanacağı
/// materyalleri, mesela kişisel bilgiler - atatürk resmi -
/// istiklalmarşı gibi güzel bir hazır şablon"*.
///
/// İki şey kritik:
///   * **Metin doğruluğu** — İstiklâl Marşı'nın on kıtası ve
///     Gençliğe Hitabe eksiksiz basılmalı. Teftişte bakılan belgede
///     eksik kıta kusurdur.
///   * **Sayfa taşmaması** — marş tek sayfaya sığmalı; iki sayfaya
///     taşarsa dosyada yanlış görünür.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu paylasirlarsa
  // "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'ogretmen_dosyasi_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    // PDF gömülü font yüklüyor; varlık isteği diskten karşılanır.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final f = File(utf8.decode(message!.buffer.asUint8List()));
      return f.existsSync()
          ? Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData()
          : null;
    });
  });

  const teacher = TeacherProfileModel(
    id: 't1',
    firstName: 'Ayşe',
    lastName: 'Çağrıöz',
    branch: 'Bilişim Teknolojileri',
    schoolName: 'Şehit Öğretmen Ortaokulu',
    schoolPrincipalName: 'Muğdat ŞIHOĞLU',
    email: 'ayse@example.com',
  );

  const bilgi = TeacherFileInfo(
    nationalId: '12345678901',
    registryNo: '987654',
    graduation: 'Gazi Üniversitesi / Bilgisayar ve Öğretim Teknolojileri',
    startedDutyAt: '15.09.2015',
    startedSchoolAt: '01.09.2022',
    title: 'Bilişim Teknolojileri Öğretmeni',
    employmentType: 'Kadrolu',
    phone: '05001234567',
    bloodType: '0 Rh+',
  );

  const dersler = [
    TeacherFileLesson(
        ders: 'Bilişim Teknolojileri', sinif: '5-A', gun: 'Pazartesi', saat: 0),
    TeacherFileLesson(
        ders: 'Bilişim Teknolojileri', sinif: '6-B', gun: 'Salı', saat: 2),
    TeacherFileLesson(
        ders: 'Kodlama', sinif: '7-C', gun: 'Cuma', saat: 5),
  ];

  const siniflar = [
    TeacherFileClass(
        ad: '5-A', ders: 'Bilişim Teknolojileri', ogrenciSayisi: 24),
    TeacherFileClass(
        ad: '6-B', ders: 'Bilişim Teknolojileri', ogrenciSayisi: 28),
  ];

  String duz(String h) => h.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<({String metin, int sayfa})> uret(TeacherFileDoc belge) async {
    final bytes = await TeacherFilePdfGenerator.tekBelge(
      belge: belge,
      teacher: teacher,
      bilgi: bilgi,
      dersler: dersler,
      siniflar: siniflar,
      academicYear: '2026-2027',
    );
    final doc = PdfDocument(inputBytes: bytes);
    final sonuc = (
      metin: duz(PdfTextExtractor(doc).extractText()),
      sayfa: doc.pages.count,
    );
    doc.dispose();
    return sonuc;
  }

  group('Resmi metinler', () {
    test('KRITIK: Istiklal Marsi on kita', () {
      expect(TeacherFileTexts.istiklalMarsi.length, 10,
          reason: 'İstiklâl Marşı on kıtadır');
    });

    test('KRITIK: her kita dort misra (son kita bes)', () {
      for (var i = 0; i < 9; i++) {
        final misra = TeacherFileTexts.istiklalMarsi[i].split('\n').length;
        expect(misra, 4, reason: '${i + 1}. kıta $misra mısra');
      }
      // Onuncu kıta beş mısradır — son iki mısra marşın kapanışıdır.
      expect(TeacherFileTexts.istiklalMarsi[9].split('\n').length, 5,
          reason: '10. kıta beş mısradır');
    });

    test('KRITIK: marsin ilk ve son misrasi dogru', () {
      expect(TeacherFileTexts.istiklalMarsi.first,
          startsWith('Korkma, sönmez bu şafaklarda yüzen al sancak;'));
      expect(TeacherFileTexts.istiklalMarsi.last,
          endsWith('Hakkıdır, Hakk\'a tapan, milletimin istiklâl!'));
    });

    test('KRITIK: hitabe uc paragraf ve dogru kapanis', () {
      expect(TeacherFileTexts.gencligeHitabe.length, 3);
      expect(TeacherFileTexts.gencligeHitabe.last,
          endsWith('damarlarındaki asil kanda mevcuttur!'));
      expect(TeacherFileTexts.gencligeHitabe.first,
          startsWith('Ey Türk gençliği!'));
    });
  });

  group('Istiklal Marsi sayfasi', () {
    test('KRITIK: TEK sayfaya sigar', () async {
      // İki sayfaya taşarsa dosyada yanlış görünür.
      final r = await uret(TeacherFileDoc.istiklalMarsi);
      expect(r.sayfa, 1, reason: 'marş ${r.sayfa} sayfaya taşmış');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: on kitanin ilk misralari BASILIYOR', () async {
      final r = await uret(TeacherFileDoc.istiklalMarsi);
      // Her kıtanın ilk mısrası belgede geçmeli: bir kıta düşerse
      // yakalanır.
      for (final kita in TeacherFileTexts.istiklalMarsi) {
        final ilk = duz(kita.split('\n').first);
        expect(r.metin.contains(ilk), isTrue,
            reason: 'kıta basılmamış: $ilk');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('sair kunyesi var', () async {
      final r = await uret(TeacherFileDoc.istiklalMarsi);
      expect(r.metin.contains('Mehmet Âkif ERSOY'), isTrue);
      expect(r.metin.contains('İSTİKLÂL MARŞI'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Genclige Hitabe sayfasi', () {
    test('KRITIK: TEK sayfa ve tam metin', () async {
      final r = await uret(TeacherFileDoc.gencligeHitabe);
      expect(r.sayfa, 1, reason: 'hitabe ${r.sayfa} sayfaya taşmış');
      expect(r.metin.contains('Ey Türk gençliği!'), isTrue);
      expect(r.metin.contains('Muhtaç olduğun kudret'), isTrue);
      expect(r.metin.contains('ATATÜRK'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Kisisel bilgiler formu', () {
    test('KRITIK: ozluk bilgileri basiliyor', () async {
      final r = await uret(TeacherFileDoc.kisiselBilgiler);
      expect(r.metin.contains('12345678901'), isTrue, reason: 'TC yok');
      expect(r.metin.contains('987654'), isTrue, reason: 'sicil yok');
      expect(r.metin.contains('15.09.2015'), isTrue, reason: 'tarih yok');
      expect(r.metin.contains('0 Rh+'), isTrue, reason: 'kan grubu yok');
      expect(r.metin.contains('Ayşe'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: bos alan NOKTALI satir olur', () async {
      // Öğretmen bilgileri doldurmadıysa belge yine basılabilmeli.
      final bytes = await TeacherFilePdfGenerator.tekBelge(
        belge: TeacherFileDoc.kisiselBilgiler,
        teacher: teacher,
        bilgi: const TeacherFileInfo(),
        dersler: const [],
        siniflar: const [],
        academicYear: '2026-2027',
      );
      final doc = PdfDocument(inputBytes: bytes);
      final metin = duz(PdfTextExtractor(doc).extractText());
      doc.dispose();

      expect(metin.contains('...........'), isTrue,
          reason: 'boş alan için noktalı satır basılmamış');
      // Profilden gelenler yine dolu olmalı.
      expect(metin.contains('Ayşe'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Ders programi', () {
    test('KRITIK: girilen dersler cizelgede', () async {
      final r = await uret(TeacherFileDoc.dersProgrami);
      expect(r.metin.contains('5-A'), isTrue);
      expect(r.metin.contains('6-B'), isTrue);
      expect(r.metin.contains('PAZARTESİ'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('ders yoksa BOS cizelge basilir', () async {
      final bytes = await TeacherFilePdfGenerator.tekBelge(
        belge: TeacherFileDoc.dersProgrami,
        teacher: teacher,
        bilgi: bilgi,
        dersler: const [],
        siniflar: const [],
        academicYear: '2026-2027',
      );
      final doc = PdfDocument(inputBytes: bytes);
      final metin = duz(PdfTextExtractor(doc).extractText());
      final sayfa = doc.pages.count;
      doc.dispose();

      expect(sayfa, 1);
      expect(metin.contains('PAZARTESİ'), isTrue,
          reason: 'boş çizelge de gün başlıklarını basmalı');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Resmi evrak niteligi', () {
    test('KRITIK: her belge TEK sayfa, kunyesi tam', () async {
      for (final belge in TeacherFileDoc.values) {
        final r = await uret(belge);
        expect(r.sayfa, 1,
            reason: '${belge.ad}: ${r.sayfa} sayfa (taşmış)');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('KRITIK: ogretim yili DEGISKEN, 2024-2025 sabiti yok',
        () async {
      final r = await uret(TeacherFileDoc.kisiselBilgiler);
      expect(r.metin.contains('2026-2027'), isTrue);
      expect(r.metin.contains('2024-2025'), isFalse,
          reason: 'yıl elle yazılmış');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: imzada isim BASILMAZ', () async {
      // BEP ve KDF'de aynı karar verilmişti.
      final r = await uret(TeacherFileDoc.kisiselBilgiler);
      expect(r.metin.contains('Muğdat ŞIHOĞLU'), isFalse,
          reason: 'müdür adı imza bloğunda basılı');
      expect(r.metin.contains('Okul Müdürü'), isTrue);
      expect(r.metin.contains('Adı Soyadı / İmza'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: "Taslak" ve cekince ibaresi YOK', () async {
      for (final belge in [
        TeacherFileDoc.kapak,
        TeacherFileDoc.kisiselBilgiler,
        TeacherFileDoc.zumreTutanagi,
      ]) {
        final r = await uret(belge);
        expect(r.metin.contains('Taslak'), isFalse, reason: belge.ad);
        expect(r.metin.contains('TASLAK'), isFalse, reason: belge.ad);
        expect(r.metin.contains('yerine geçmez'), isFalse, reason: belge.ad);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('KRITIK: Turkce harfler basiliyor', () async {
      final r = await uret(TeacherFileDoc.istiklalMarsi);
      final trHarf =
          r.metin.split('').where((c) => 'ışğüöçİŞĞÜÖÇâîû'.contains(c));
      expect(trHarf.length, greaterThan(80),
          reason: 'Türkçe harfler kayıp: ${trHarf.length} adet');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Tum dosya', () {
    test('KRITIK: tumu tek PDF, belge sayisi kadar sayfa', () async {
      final bytes = await TeacherFilePdfGenerator.tumDosya(
        teacher: teacher,
        bilgi: bilgi,
        dersler: dersler,
        siniflar: siniflar,
        academicYear: '2026-2027',
      );
      final doc = PdfDocument(inputBytes: bytes);
      final sayfa = doc.pages.count;
      doc.dispose();

      expect(sayfa, TeacherFileDoc.values.length,
          reason: 'her belge bir sayfa olmalı');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('KRITIK: secili belgeler basilir, digerleri BASILMAZ', () async {
      final bytes = await TeacherFilePdfGenerator.tumDosya(
        teacher: teacher,
        bilgi: bilgi,
        dersler: dersler,
        siniflar: siniflar,
        secili: {
          TeacherFileDoc.istiklalMarsi,
          TeacherFileDoc.gencligeHitabe,
        },
        academicYear: '2026-2027',
      );
      final doc = PdfDocument(inputBytes: bytes);
      final metin = duz(PdfTextExtractor(doc).extractText());
      final sayfa = doc.pages.count;
      doc.dispose();

      expect(sayfa, 2);
      expect(metin.contains('İSTİKLÂL MARŞI'), isTrue);
      expect(metin.contains('KİŞİSEL BİLGİ FORMU'), isFalse,
          reason: 'seçilmeyen belge basılmış');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Ozluk modeli', () {
    test('bos model isEmpty', () {
      expect(const TeacherFileInfo().isEmpty, isTrue);
      expect(bilgi.isEmpty, isFalse);
    });

    test('dolu alan sayisi dogru', () {
      expect(bilgi.doluAlanSayisi, TeacherFileInfo.toplamAlanSayisi);
      expect(const TeacherFileInfo(registryNo: '123').doluAlanSayisi, 1);
    });

    test('KRITIK: map cevrimi kayipsiz', () {
      final geri = TeacherFileInfo.fromMap(bilgi.toMap());
      expect(geri.nationalId, bilgi.nationalId);
      expect(geri.bloodType, bilgi.bloodType);
      expect(geri.graduation, bilgi.graduation);
    });
  });

  group('Ozluk deposu', () {
    setUp(() async => DatabaseHelper.instance.resetForTests());

    test('KRITIK: yazilan geri okunur', () async {
      final repo = TeacherFileRepository();
      await repo.write(bilgi);
      final geri = await repo.read();

      expect(geri.nationalId, '12345678901');
      expect(geri.registryNo, '987654');
      expect(geri.bloodType, '0 Rh+');
      expect(geri.startedDutyAt, '15.09.2015');
    });

    test('kayit yoksa BOS model doner', () async {
      final geri = await TeacherFileRepository().read();
      expect(geri.isEmpty, isTrue);
    });

    test('KRITIK: alan SILINEBILIR', () async {
      // Ogretmen bir alani temizlediginde eski deger kalmamali.
      final repo = TeacherFileRepository();
      await repo.write(bilgi);
      await repo.write(bilgi.copyWith(phone: ''));

      final geri = await repo.read();
      expect(geri.phone, isEmpty, reason: 'eski telefon kalmis');
      expect(geri.registryNo, '987654', reason: 'digerleri silinmis');
    });

    test('KRITIK: takvim ayarlarina DOKUNMAZ', () async {
      // Ayni tabloyu paylasiyoruz; onek yanlis olsaydi egitim
      // baslangic tarihi ezilirdi.
      final db = await DatabaseHelper.instance.database;
      await TeacherFileRepository().write(bilgi);

      final takvim = await db.query(
        'sistem_ayarlari',
        where: 'anahtar = ?',
        whereArgs: ['egitim_baslangic'],
      );
      expect(takvim, isNotEmpty, reason: 'takvim ayari silinmis');
    });
  });
}
