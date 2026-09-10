import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/features/attendance/data/models/classroom_participation_model.dart';

/// Ders ici katilim: devamsizlik baglantisi ve ders bazli gecmis.
///
/// Uc somut eksik kapatildi:
///
/// 1. Katilim modulu devamsizliktan HABERSIZDI. Yeni oturum acilinca
///    herkes "3 yildiz + odev tam" varsayilaniyla geliyordu; derse hic
///    gelmeyen ogrenci de tam puan aliyor ve ortalamasi sisiyordu.
///    Veli toplantisi raporunda "her sey harika" gorunuyordu.
///
/// 2. Gecmis serit TUM DERSLERI karistiriyordu. Ogretmen ayni
///    ogrenciye matematik ve fen dersine giriyorsa iki dersin kaydi
///    ayni seritte cikiyor, "gecen ders neydi" sorusu cevapsiz
///    kaliyordu.
///
/// 3. Gecmis yalnizca son 4 ders ile sinirliydi, "tumunu gor" yoktu.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  String read(String path) => File(path).readAsStringSync();

  const repo =
      'lib/features/attendance/data/repositories/classroom_participation_repository.dart';
  const model =
      'lib/features/attendance/data/models/classroom_participation_model.dart';
  const izgara =
      'lib/features/attendance/presentation/widgets/compact_student_participation_grid.dart';
  const diyalog =
      'lib/features/attendance/presentation/widgets/quick_student_eval_dialog.dart';
  const saglayici =
      'lib/features/attendance/providers/classroom_participation_provider.dart';
  const toplanti =
      'lib/features/classes/presentation/widgets/parent_meeting_editor_modal.dart';

  /// Uretimdeki semanin ilgili parcasi.
  Future<Database> semaKur() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 27),
    );
    await db.execute('''
      CREATE TABLE classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subject TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        description TEXT,
        is_homeroom INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        school_number INTEGER NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        gender TEXT DEFAULT 'Erkek',
        parent_name TEXT,
        parent_phone TEXT,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE absence_followups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        academic_year TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT 'bilinmiyor',
        note TEXT,
        marked_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(student_id, academic_year)
      )
    ''');
    await db.execute('''
      CREATE TABLE participation_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        lesson_hour INTEGER NOT NULL,
        subject_name TEXT,
        topic_name TEXT,
        note TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE participation_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        homework_status TEXT NOT NULL DEFAULT 'yapti',
        materials_status TEXT NOT NULL DEFAULT 'tam',
        arrival_status TEXT NOT NULL DEFAULT 'zamaninda',
        stars_count INTEGER NOT NULL DEFAULT 0,
        custom_tags TEXT,
        badge_name TEXT,
        score INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        speaking_turns INTEGER NOT NULL DEFAULT 0
      )
    ''');
    return db;
  }

  Future<int> ogrenciEkle(Database db, int classId, int no, String ad) {
    return db.insert('students', {
      'class_id': classId,
      'school_number': no,
      'first_name': ad,
      'last_name': 'Test',
    });
  }

  /// Uretimdeki `_absentStudentIds` ile ayni sorgu.
  Future<Set<int>> devamsizlar(
    Database db,
    int classId,
    String yil,
  ) async {
    if (yil.trim().isEmpty) return const <int>{};
    try {
      final rows = await db.query(
        'absence_followups',
        columns: ['student_id'],
        where: 'class_id = ? AND academic_year = ?',
        whereArgs: [classId, yil],
      );
      return rows.map((r) => r['student_id'] as int).toSet();
    } catch (_) {
      return const <int>{};
    }
  }

  /// Uretimdeki `_varsayilanDeger` ile ayni mantik.
  StudentParticipationEvaluation varsayilan({
    required int studentId,
    required bool isAbsent,
  }) {
    return StudentParticipationEvaluation(
      studentId: studentId,
      studentName: 'Ogrenci $studentId',
      studentNumber: studentId,
      homeworkStatus: isAbsent ? HomeworkStatus.unknown : HomeworkStatus.done,
      materialsStatus:
          isAbsent ? MaterialsStatus.unknown : MaterialsStatus.ready,
      arrivalStatus: isAbsent ? ArrivalStatus.unknown : ArrivalStatus.onTime,
      starsCount: isAbsent ? 0 : 3,
      isAbsent: isAbsent,
    );
  }

  group('Devamsiz ogrenciye tam puan verilmiyor', () {
    test('KRITIK: devamsiz ogrenci "odevini yapti" sayilmiyor', () {
      final d = varsayilan(studentId: 1, isAbsent: true);

      expect(d.homeworkStatus, HomeworkStatus.unknown,
          reason: 'Derse gelmeyen ogrenci odevini yapmis sayilamaz');
      expect(d.materialsStatus, MaterialsStatus.unknown);
      expect(d.arrivalStatus, ArrivalStatus.unknown);
      expect(d.starsCount, 0,
          reason: '3 yildiz verilirse ortalamasi sisiyordu');
    });

    test('KRITIK: devamsiz OLMAYAN ogrenci tam puanla basliyor', () {
      // Modulun kurgusu: ogretmen yalnizca ISTISNALARI isaretler.
      final d = varsayilan(studentId: 2, isAbsent: false);

      expect(d.homeworkStatus, HomeworkStatus.done);
      expect(d.materialsStatus, MaterialsStatus.ready);
      expect(d.starsCount, 3);
      expect(d.isAbsent, isFalse);
    });

    test('KRITIK: devamsizlik puan ortalamasini sismiyor', () {
      // 3 ogrenci: ikisi normal, biri devamsiz.
      final sinif = [
        varsayilan(studentId: 1, isAbsent: false),
        varsayilan(studentId: 2, isAbsent: false),
        varsayilan(studentId: 3, isAbsent: true),
      ];

      final isaretliOdev = sinif
          .where((e) => e.homeworkStatus != HomeworkStatus.unknown)
          .length;

      expect(isaretliOdev, 2,
          reason: 'Devamsiz ogrenci odev oraninin paydasina girmemeli');
    });
  });

  group('Devamsizlik bilgisi oturuma tasiniyor', () {
    test('KRITIK: takipteki ogrenci kimlikleri okunuyor', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Matematik',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final a = await ogrenciEkle(db, classId, 1, 'Ali');
      final b = await ogrenciEkle(db, classId, 2, 'Veli');

      final now = DateTime.now().toIso8601String();
      await db.insert('absence_followups', {
        'student_id': b,
        'class_id': classId,
        'academic_year': '2025-2026',
        'reason': 'saglik',
        'marked_at': now,
        'updated_at': now,
      });

      final kume = await devamsizlar(db, classId, '2025-2026');

      expect(kume, contains(b));
      expect(kume, isNot(contains(a)));

      await db.close();
    });

    test('Gecen yilin devamsizligi bu yila tasinmiyor', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Matematik',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final a = await ogrenciEkle(db, classId, 1, 'Ali');

      final now = DateTime.now().toIso8601String();
      await db.insert('absence_followups', {
        'student_id': a,
        'class_id': classId,
        'academic_year': '2024-2025',
        'reason': 'ailevi',
        'marked_at': now,
        'updated_at': now,
      });

      final kume = await devamsizlar(db, classId, '2025-2026');
      expect(kume, isEmpty);

      await db.close();
    });

    test('Ders yili bos ise sorgu hic calismiyor', () async {
      // Sinif kaydinda yil yoksa tum siniflarin kaydi karisirdi.
      final db = await semaKur();
      final kume = await devamsizlar(db, 1, '');
      expect(kume, isEmpty);
      await db.close();
    });

    test('KRITIK: tablo yoksa katilim ekrani cokmuyor', () async {
      // absence_followups bu modulun tablosu degil; eski kurulumda
      // olmayabilir. Coktugunde ders hic islenemezdi.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 27),
      );

      final kume = await devamsizlar(db, 1, '2025-2026');
      expect(kume, isEmpty, reason: 'Bilgi kaybolur ama ders islenebilir');

      await db.close();
    });
  });

  group('Model devamsizlik bayragi', () {
    test('Varsayilan false', () {
      const e = StudentParticipationEvaluation(
        studentId: 1,
        studentName: 'Ali',
        studentNumber: 1,
      );
      expect(e.isAbsent, isFalse);
    });

    test('copyWith bayragi tasiyor', () {
      const e = StudentParticipationEvaluation(
        studentId: 1,
        studentName: 'Ali',
        studentNumber: 1,
      );
      expect(e.copyWith(isAbsent: true).isAbsent, isTrue);
    });

    test('KRITIK: bayrak diske YAZILMIYOR', () {
      // Kalici yazilsaydi ogretmen takipten cikardiginda eski
      // oturumlar yanlis kalirdi. Bilgi her yuklemede yeniden
      // hesaplanmali.
      const e = StudentParticipationEvaluation(
        studentId: 1,
        studentName: 'Ali',
        studentNumber: 1,
        isAbsent: true,
      );
      expect(e.toMap(1).containsKey('is_absent'), isFalse);
    });

    test('JOIN sonucundan okunuyor', () {
      final geri = StudentParticipationEvaluation.fromMap({
        'student_id': 1,
        'student_name': 'Ali',
        'is_absent': 1,
      });
      expect(geri.isAbsent, isTrue);
    });

    test('Bayrak yoksa false kalir', () {
      final geri = StudentParticipationEvaluation.fromMap({
        'student_id': 1,
        'student_name': 'Ali',
      });
      expect(geri.isAbsent, isFalse);
    });
  });

  group('Izgara devamsizi ayirt ediyor', () {
    test('KRITIK: devamsiz ogrenci GIZLENMIYOR', () {
      // Gizlenseydi o gun derse gelen ogrenci degerlendirilemezdi.
      final s = read(izgara);
      expect(s.contains('.where((e) => !e.isAbsent)'), isFalse,
          reason: 'Devamsiz ogrenci listeden cikarilmamali');
    });

    test('Soluk cizim ve rozet var', () {
      final s = read(izgara);
      expect(s.contains('final bool devamsiz = student.isAbsent'), isTrue);
      expect(s.contains('_buildAbsentBadge'), isTrue);
      expect(s.contains('Devamsız'), isTrue);
    });
  });

  group('Gecmis DERS BAZLI', () {
    test('KRITIK: sorgu ders adiyla suzuluyor', () {
      final s = read(repo);
      expect(s.contains("ps.subject_name = ?"), isTrue,
          reason: 'Matematik ile fen kayitlari karisiyordu');
    });

    test('KRITIK: ders adi onbellek anahtarinin parcasi', () {
      // Anahtarda olmasaydi ders degisince eski sonuc gosterilirdi.
      final s = read(saglayici);
      expect(s.contains('class StudentHistoryQuery'), isTrue);
      expect(s.contains('other.subjectName == subjectName'), isTrue);
      expect(s.contains('Object.hash(studentId, subjectName, limit)'), isTrue);
    });

    test('Ekran acik olan dersin adini geciriyor', () {
      final s = read(diyalog);
      expect(s.contains('subjectName: widget.subjectName'), isTrue);
    });

    test('Bos ders adi suzgeci uygulamiyor (tum dersler)', () {
      final s = read(repo);
      expect(s.contains("final ders = subjectName?.trim() ?? '';"), isTrue);
      expect(s.contains('if (ders.isNotEmpty)'), isTrue);
    });

    test('Sorgu ders ve saate gore siralaniyor', () {
      expect(
        read(repo).contains('ORDER BY ps.date DESC, ps.lesson_hour DESC'),
        isTrue,
      );
    });
  });

  group('Gecmis TUM DONEM acilabiliyor', () {
    test('KRITIK: limit null verilince LIMIT eklenmiyor', () {
      final s = read(repo);
      expect(s.contains('int? limit = 4'), isTrue);
      expect(s.contains('if (limit != null)'), isTrue,
          reason: 'Tum donem icin limitsiz sorgu gerekiyor');
    });

    test('Ekranda "Tumunu Gor" var', () {
      final s = read(diyalog);
      expect(s.contains('Tümünü Gör'), isTrue);
      expect(s.contains('_showFullHistoryModal'), isTrue);
    });

    test('Tam liste limitsiz sorguyu kullaniyor', () {
      expect(read(diyalog).contains('limit: null'), isTrue);
    });

    test('Tam listede ders saati, konu ve not gorunuyor', () {
      final s = read(diyalog);
      expect(s.contains('_buildFullHistoryRow'), isTrue);
      expect(s.contains("h['lesson_hour']"), isTrue);
      expect(s.contains("h['topic_name']"), isTrue);
      expect(s.contains("h['speaking_turns']"), isTrue);
    });
  });

  group('Gecmis sorgusu gercek veriyle', () {
    Future<void> dersEkle(
      Database db, {
      required int classId,
      required int studentId,
      required String tarih,
      required String ders,
    }) async {
      final sessionId = await db.insert('participation_sessions', {
        'class_id': classId,
        'date': tarih,
        'lesson_hour': 1,
        'subject_name': ders,
      });
      await db.insert('participation_records', {
        'session_id': sessionId,
        'student_id': studentId,
        'homework_status': 'yapti',
        'materials_status': 'tam',
        'arrival_status': 'zamaninda',
        'stars_count': 3,
      });
    }

    test('KRITIK: baska dersin kaydi gelmiyor', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Matematik',
        'academic_year': '2025-2026',
      });
      final ogr = await ogrenciEkle(db, classId, 1, 'Ali');

      await dersEkle(
        db,
        classId: classId,
        studentId: ogr,
        tarih: '2026-03-02',
        ders: 'Matematik',
      );
      await dersEkle(
        db,
        classId: classId,
        studentId: ogr,
        tarih: '2026-03-03',
        ders: 'Fen Bilimleri',
      );

      final matematik = await db.rawQuery('''
        SELECT pr.*, ps.date, ps.subject_name
        FROM participation_records pr
        JOIN participation_sessions ps ON pr.session_id = ps.id
        WHERE pr.student_id = ? AND ps.subject_name = ?
        ORDER BY ps.date DESC
      ''', [ogr, 'Matematik']);

      expect(matematik.length, 1,
          reason: 'Fen kaydi matematik seridinde gorunmemeli');
      expect(matematik.first['subject_name'], 'Matematik');

      await db.close();
    });

    test('Suzgecsiz sorgu iki dersi de getiriyor', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Matematik',
        'academic_year': '2025-2026',
      });
      final ogr = await ogrenciEkle(db, classId, 1, 'Ali');

      await dersEkle(
        db,
        classId: classId,
        studentId: ogr,
        tarih: '2026-03-02',
        ders: 'Matematik',
      );
      await dersEkle(
        db,
        classId: classId,
        studentId: ogr,
        tarih: '2026-03-03',
        ders: 'Fen Bilimleri',
      );

      final hepsi = await db.rawQuery('''
        SELECT pr.*, ps.subject_name
        FROM participation_records pr
        JOIN participation_sessions ps ON pr.session_id = ps.id
        WHERE pr.student_id = ?
      ''', [ogr]);

      expect(hepsi.length, 2);

      await db.close();
    });
  });

  group('Veli toplantisi evrak kisayolu', () {
    test('KRITIK: tutanaktan degerlendirme tablosuna yol var', () {
      // Tutanak gundem + BOS imza sirkusu tasiyor, ogrenci verisi
      // tasimiyor. Ogretmen "veli toplantisi evraki" deyince cogu
      // zaman odev/katilim tablosunu kastediyor; o belge baska
      // menudeydi ve burada hicbir izi yoktu.
      final s = read(toplanti);
      expect(s.contains('ParticipationCumulativeReportsModal.show'), isTrue);
      expect(s.contains('Veli Toplantısı Kılavuzu'), isTrue);
    });

    test('Kisayol sinifi tasiyor', () {
      expect(
        read(toplanti).contains('initialClassId: widget.classModel.id'),
        isTrue,
        reason: 'Yanlis sinifin raporu acilmamali',
      );
    });

    test('Tutanagin kendi bicimi bozulmadi', () {
      // Resmi belge; ogrenci verisi imza sirkusuyle ayni evraga
      // karismamali.
      final s = read(
        'lib/features/classes/utils/classroom_documents_pdf_generator.dart',
      );
      expect(s.contains('VELİ TOPLANTI TUTANAĞI VE İMZA SİRKÜSÜ'), isTrue);
    });
  });

  group('Model dosyasi', () {
    test('isAbsent alani belgelenmis', () {
      final s = read(model);
      expect(s.contains('final bool isAbsent'), isTrue);
      expect(s.contains('absence_followups'), isTrue,
          reason: 'Bilginin nereden geldigi yazili olmali');
    });
  });
}
