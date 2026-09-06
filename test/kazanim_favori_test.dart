import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';

/// Favoriye eklenen ders boş açılıyordu.
///
/// ## Neden bu test var
/// Öğretmen bildirdi: *"bilişime girdim sadece 40. hafta kartı
/// görünüyor"* → *"pardon favori ekleyince görünmüyormuş"*.
///
/// Ölçüm: veri sağlamdı (Bilişim 5-6. sınıfta 39 hafta tam). Sorun
/// `publisher` alanının anlamının bu sürümde değişmesiydi — artık
/// yalnızca okul türü ve çoğu derste **boş**. Ama uygulama dört
/// yerde hâlâ "MEB Yayınları" varsayıyordu.
///
/// Sonuç: favori `5_BILISIM_` diye kaydediliyor, açılırken publisher
/// "MEB Yayınları" sanılıyor, sorgu `publisher = 'MEB Yayınları'` ile
/// süzüyor ve hiçbir kayıt bulamıyordu. Geriye yalnızca 40. hafta
/// (yaz tatili) kartı kalıyordu — o hafta veritabanından değil,
/// takvimden üretiliyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'kazanim_favori_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();
  });

  group('Yayinci normallestirmesi', () {
    test('KRITIK: "MEB Yayinlari" BOS sayilir', () {
      // Bu bir okul türü değil, eski verideki "bilinmiyor" değeriydi.
      expect(DatabaseHelper.yayinciNormalize('MEB Yayınları'), '');
      expect(DatabaseHelper.yayinciNormalize(''), '');
      expect(DatabaseHelper.yayinciNormalize(null), '');
      expect(DatabaseHelper.yayinciNormalize('  '), '');
    });

    test('KRITIK: gercek okul turleri AYRI kalir', () {
      // Aynı sınıfın Anadolu ve Fen Lisesi planları farklı içerik
      // taşıyor; birleştirilirse biri ötekini ezer.
      expect(DatabaseHelper.yayinciNormalize('Anadolu Lisesi'),
          'Anadolu Lisesi');
      expect(DatabaseHelper.yayinciNormalize('Fen Lisesi'), 'Fen Lisesi');
    });
  });

  group('Favori dersi acmak', () {
    test('KRITIK: "MEB Yayinlari" ile acilan ders BOS gelmez', () async {
      // Eski favoriler ve ders programı bu değeri gönderiyor.
      final kayitlar = await DatabaseHelper.instance.kazanimlariGetir(
        gradeLevel: 5,
        subjectCode: 'BILISIM',
        publisher: 'MEB Yayınları',
      );
      expect(kayitlar, isNotEmpty,
          reason: 'ders boş açılıyor — yalnızca 40. hafta kartı kalır');
      expect(kayitlar.length, greaterThan(30),
          reason: '39 haftanın çoğu eksik');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('KRITIK: bos publisher ile de acilir', () async {
      // Yeni favoriler bu biçimde kaydediliyor.
      final kayitlar = await DatabaseHelper.instance.kazanimlariGetir(
        gradeLevel: 5,
        subjectCode: 'BILISIM',
        publisher: '',
      );
      expect(kayitlar, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('okul turu suzgeci CALISMAYA devam eder', () async {
      // Normalleştirme her şeyi birleştirmemeli: lise planları okul
      // türüne göre ayrı.
      final anadolu = await DatabaseHelper.instance.kazanimlariGetir(
        gradeLevel: 11,
        subjectCode: 'COGRAFYA',
        publisher: 'Anadolu Lisesi',
      );
      final fen = await DatabaseHelper.instance.kazanimlariGetir(
        gradeLevel: 11,
        subjectCode: 'COGRAFYA',
        publisher: 'Fen Lisesi',
      );
      if (anadolu.isNotEmpty && fen.isNotEmpty) {
        for (final k in anadolu) {
          expect(k['publisher'], 'Anadolu Lisesi',
              reason: 'okul türü süzgeci karışmış');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Ogretmenin kendi notlari', () {
    test('KRITIK: "MEB Yayinlari" ile yazilan not BOS ile okunur', () async {
      // Öğretmenin emeği kaybolmamalı: not eski değerle yazılmış
      // olabilir, yeni değerle aranıyor.
      await DatabaseHelper.instance.saveOutcomeNote(
        grade: 5,
        subjectCode: 'BILISIM',
        publisher: 'MEB Yayınları',
        weekNumber: 3,
        noteText: 'Bu hafta laboratuvarda yapılacak',
      );

      final okunan = await DatabaseHelper.instance.getOutcomeNote(
        grade: 5,
        subjectCode: 'BILISIM',
        publisher: '',
        weekNumber: 3,
      );
      expect(okunan, 'Bu hafta laboratuvarda yapılacak',
          reason: 'not kaydedildi ama bulunamıyor');
    });

    test('KRITIK: bos ile yazilan not "MEB Yayinlari" ile de okunur',
        () async {
      await DatabaseHelper.instance.saveOutcomeNote(
        grade: 6,
        subjectCode: 'BILISIM',
        publisher: '',
        weekNumber: 5,
        noteText: 'Sunum haftası',
      );

      final okunan = await DatabaseHelper.instance.getOutcomeNote(
        grade: 6,
        subjectCode: 'BILISIM',
        publisher: 'MEB Yayınları',
        weekNumber: 5,
      );
      expect(okunan, 'Sunum haftası');
    });

    test('ders bazinda not listesi de eslesir', () async {
      await DatabaseHelper.instance.saveOutcomeNote(
        grade: 5,
        subjectCode: 'MAT',
        publisher: 'MEB Yayınları',
        weekNumber: 7,
        noteText: 'Tekrar',
      );

      final notlar = await DatabaseHelper.instance.getAllOutcomeNotesForSubject(
        grade: 5,
        subjectCode: 'MAT',
        publisher: '',
      );
      expect(notlar[7], 'Tekrar');
    });
  });
}
