import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/features/analytics/data/models/exam_analysis_model.dart';

/// Girmeyen ogrencinin GERCEK veritabanindan gidip gelmesi (Faz 2.4).
///
/// Model testleri dogru calissa bile isaret degeri diskte kaybolursa
/// ogretmen ekrani kapatip actiginda girmeyen ogrenci yeniden 0 olur ve
/// ortalama yine bozulur. Bu test tam turu kanitlar.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> kur() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    await db.execute('''
      CREATE TABLE sinavlar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sinav_adi TEXT, sinif TEXT, ders TEXT, tarih TEXT,
        ortalama REAL, not_sayisi INTEGER, sinav_tipi TEXT,
        soru_sayisi INTEGER, soru_puanlari TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sinav_notlari (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sinav_id INTEGER NOT NULL,
        ogrenci_id INTEGER,
        ogrenci_ad_soyad TEXT,
        notu INTEGER,
        toplam_not REAL,
        soru_bazli_notlar TEXT
      )
    ''');
    return db;
  }

  test('KRITIK: girmeyen ogrenci diskten geri gelince hala girmeyen', () async {
    final db = await kur();

    final ogrenciler = [
      const StudentExamScore(
        studentName: 'Giren A',
        studentNumber: 1,
        questionScores: [70],
        totalScore: 70,
      ),
      const StudentExamScore(
        studentName: 'Giren B',
        studentNumber: 2,
        questionScores: [70],
        totalScore: 70,
      ),
      const StudentExamScore(
        studentName: 'Gelmedi',
        studentNumber: 3,
        questionScores: [0],
        totalScore: 0,
        isAbsent: true,
      ),
    ];

    final sinav = ExamAnalysisModel(
      examTitle: '1. Yazılı',
      className: '5-A',
      subjectName: 'Matematik',
      examDate: '2026-11-15',
      examType: 'klasik',
      questionMaxScores: const [100],
      studentScores: ogrenciler,
    );

    // Kaydet
    final map = sinav.toMap()..remove('id');
    final sinavId = await db.insert('sinavlar', map);
    for (final o in ogrenciler) {
      await db.insert('sinav_notlari', o.toMap(sinavId: sinavId));
    }

    // Geri oku
    final sinavRow = (await db.query('sinavlar', where: 'id = ?', whereArgs: [sinavId])).first;
    final notRows = await db.query('sinav_notlari',
        where: 'sinav_id = ?', whereArgs: [sinavId], orderBy: 'id ASC');
    final geri = ExamAnalysisModel.fromMap(sinavRow, notRows);

    final gelmeyen = geri.studentScores.firstWhere((s) => s.studentName == 'Gelmedi');
    expect(gelmeyen.isAbsent, isTrue, reason: 'isaret diskte kaybolmamali');
    expect(gelmeyen.totalScore, 0.0, reason: 'negatif isaret arayuze sizmamali');

    expect(geri.studentCount, 2);
    expect(geri.classAverage, 70.0,
        reason: 'girmeyen sayilsaydi 46.67 cikardi');
    expect(geri.passRate, 100.0);
    expect(geri.lowestScore, 70.0);

    await db.close();
  });

  test('gercek 0 alan ogrenci diskten girmeyen olarak donmez', () async {
    final db = await kur();

    const sifirAlan = StudentExamScore(
      studentName: 'Sifir aldi',
      studentNumber: 1,
      questionScores: [0],
      totalScore: 0,
    );

    await db.insert('sinav_notlari', sifirAlan.toMap(sinavId: 1));
    final row = (await db.query('sinav_notlari')).first;
    final geri = StudentExamScore.fromMap(row);

    expect(geri.isAbsent, isFalse);
    expect(geri.totalScore, 0.0);
    await db.close();
  });

  test('soru bazli sinavda girmeyen soru oranlarini bozmaz', () async {
    final db = await kur();

    final ogrenciler = [
      StudentExamScore(
        studentName: 'A',
        studentNumber: 1,
        questionScores: const [10, 10],
        totalScore: 20,
      ),
      StudentExamScore(
        studentName: 'Gelmedi',
        studentNumber: 2,
        questionScores: const [0, 0],
        totalScore: 0,
        isAbsent: true,
      ),
    ];

    for (final o in ogrenciler) {
      await db.insert('sinav_notlari', o.toMap(sinavId: 1));
    }

    final rows = await db.query('sinav_notlari', orderBy: 'id ASC');
    final geri = ExamAnalysisModel.fromMap(
      {
        'id': 1,
        'sinav_adi': 'Test',
        'sinif': '5-A',
        'ders': 'Matematik',
        'tarih': '2026-11-15',
        'sinav_tipi': 'soru_bazli',
        'soru_puanlari': jsonEncode([10, 10]),
      },
      rows,
    );

    expect(geri.questionSuccessRates[0], 100.0,
        reason: 'tek giren ogrenci soruyu tam yapmis');
    expect(geri.questionSuccessRates[1], 100.0);
    await db.close();
  });
}
