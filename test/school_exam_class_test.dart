import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';

/// Okul sinavinin sinif bilgisi (Faz 2.3).
///
/// `addSchoolExam` sinif adini `basvuru_linki` sutununa yaziyordu ama
/// `ExamModel.fromMap` onu `sinif` sutunundan okuyordu; ustelik tabloda
/// `sinif` sutunu hic yoktu. Iki sonuc dogurdu:
///   1. Ogretmenin sectigi sinif kartta hep "Okul" gorunuyordu.
///   2. Ekran dolu bir "basvuru linki" gorup tiklanabilir baglanti ciziyor,
///      dokununca "5-A"yi adres olarak acmaya calisiyordu.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('fromMap sinif adini `sinif` sutunundan okur', () {
    final exam = ExamModel.fromMap(
      {
        'id': 1,
        'doc_id': 'okul_1',
        'sinav_adi': '1. Dönem 2. Yazılı',
        'kurum': 'OKUL',
        'sinav_tarihi': DateTime(2026, 12, 10).toIso8601String(),
        'sinif': '5-A',
      },
      isFav: false,
      isSchool: true,
    );

    expect(exam.className, '5-A');
    expect(exam.applicationLink, isNull,
        reason: 'sinif adi link alanina sizmamali');
  });

  test('sinif adi basvuru linki olarak gosterilmez', () {
    final exam = ExamModel.fromMap(
      {
        'doc_id': 'okul_2',
        'sinav_adi': 'Deneme',
        'kurum': 'OKUL',
        'sinav_tarihi': DateTime(2026, 11, 1).toIso8601String(),
        'sinif': '7-B',
      },
      isFav: false,
      isSchool: true,
    );

    // Ekran bu kosulla tiklanabilir baglanti ciziyor.
    final linkGosterilir =
        exam.applicationLink != null && exam.applicationLink!.isNotEmpty;
    expect(linkGosterilir, isFalse);
  });

  group('Surum 13 gocu', () {
    Future<Database> eskiSema() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      await db.execute('''
        CREATE TABLE kisisel_sinavlar (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          doc_id TEXT,
          sinav_adi TEXT NOT NULL,
          kurum TEXT NOT NULL,
          sinav_tarihi TEXT NOT NULL,
          son_basvuru_tarihi TEXT,
          basvuru_linki TEXT
        )
      ''');
      return db;
    }

    /// Uretimdeki gocun aynisi.
    Future<void> goc(Database db) async {
      await db.execute('ALTER TABLE kisisel_sinavlar ADD COLUMN sinif TEXT');
      await db.execute('''
        UPDATE kisisel_sinavlar
        SET sinif = basvuru_linki, basvuru_linki = NULL
        WHERE basvuru_linki IS NOT NULL
          AND basvuru_linki != ''
          AND basvuru_linki NOT LIKE 'http%'
      ''');
    }

    test('yanlis sutundaki sinif adi dogru sutuna tasinir', () async {
      final db = await eskiSema();
      await db.insert('kisisel_sinavlar', {
        'doc_id': 'okul_1',
        'sinav_adi': 'Yazılı',
        'kurum': 'OKUL',
        'sinav_tarihi': '2026-12-10T00:00:00.000',
        'basvuru_linki': '5-A', // eski hatali yazim
      });

      await goc(db);

      final row = (await db.query('kisisel_sinavlar')).single;
      expect(row['sinif'], '5-A');
      expect(row['basvuru_linki'], isNull,
          reason: 'artik sahte link gosterilmemeli');
      await db.close();
    });

    test('gercek basvuru linki korunur', () async {
      final db = await eskiSema();
      await db.insert('kisisel_sinavlar', {
        'doc_id': 'meb_1',
        'sinav_adi': 'LGS',
        'kurum': 'MEB',
        'sinav_tarihi': '2027-06-01T00:00:00.000',
        'basvuru_linki': 'https://meb.gov.tr/basvuru',
      });

      await goc(db);

      final row = (await db.query('kisisel_sinavlar')).single;
      expect(row['basvuru_linki'], 'https://meb.gov.tr/basvuru',
          reason: 'http ile baslayan gercek link silinmemeli');
      expect(row['sinif'], isNull);
      await db.close();
    });

    test('bos link alani dokunulmadan kalir', () async {
      final db = await eskiSema();
      await db.insert('kisisel_sinavlar', {
        'doc_id': 'okul_2',
        'sinav_adi': 'Sözlü',
        'kurum': 'OKUL',
        'sinav_tarihi': '2026-10-01T00:00:00.000',
        'basvuru_linki': '',
      });

      await goc(db);

      final row = (await db.query('kisisel_sinavlar')).single;
      expect(row['sinif'], isNull);
      await db.close();
    });
  });
}
