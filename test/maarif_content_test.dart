import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/features/outcomes/data/models/curriculum_outcome_model.dart';

/// Maarif icerigi artik kartlara ulasiyor (Faz 4.3).
///
/// JSON 34 alan tasiyordu ama tabloda 15 sutun vardi ve tohumlama elle
/// esleme yapiyordu. Sonuc: Maarif ders ozeti, resmi etkinlik, degerler,
/// beceriler ve farklilastirma APK ile tasiniyor, acilista ayristiriliyor
/// ve ATILIYORDU. `outcome_carousel_card.dart` icinde bunlari gosteren
/// kartlar vardi ama uygulamanin ilk gunuden beri BOS goruntuleniyordu.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  /// Surum 14 semasi (Maarif sutunlariyla).
  Future<Database> sema() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    await db.execute('''
      CREATE TABLE curriculum_outcomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_id TEXT,
        grade_level INTEGER NOT NULL,
        subject_code TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        publisher TEXT,
        full_title TEXT,
        week_number INTEGER NOT NULL,
        teaching_week_number INTEGER,
        unit_title TEXT NOT NULL,
        topic_title TEXT NOT NULL,
        outcome_code TEXT,
        outcome_description TEXT NOT NULL,
        category TEXT,
        academic_year TEXT NOT NULL,
        is_holiday_week INTEGER DEFAULT 0,
        holiday_note TEXT,
        outcome_parts TEXT,
        suggested_activities TEXT,
        official_activity TEXT,
        maarif_summary TEXT,
        maarif_values TEXT,
        maarif_skills TEXT,
        differentiation TEXT,
        span_index INTEGER,
        span_total INTEGER,
        date_range_str TEXT,
        is_estimated_schedule INTEGER DEFAULT 0,
        is_otp_week INTEGER DEFAULT 0,
        is_social_event_week INTEGER DEFAULT 0
      )
    ''');
    return db;
  }

  /// Gercek JSON'daki bir kaydin ayni yapisi.
  Map<String, dynamic> ornekJson() => {
        'id': 'out_primary_2026_1_BEDEN_w1',
        'gradeLevel': 1,
        'subjectCode': 'BEDEN',
        'subjectName': 'BEDEN EĞİTİMİ VE SPOR',
        'publisher': 'TYMM (Maarif Modeli)',
        'fullTitle': '1. Sınıf - BEDEN EĞİTİMİ',
        'category': 'core',
        'weekNumber': 1,
        'teachingWeekNumber': 1,
        'unitTitle': 'Hareket Becerileri',
        'topicTitle': 'Hareket Kavramları',
        'outcomeCode': 'BEO.1.1.1',
        'outcomeDescription': 'Oyunlarda hareket kavramlarını uygulayabilme',
        'academicYear': '2026-2027',
        'isHolidayWeek': false,
        'maarifSummary': 'Bu hafta bedensel koordinasyon ve estetik algı '
            'teknikleriyle uygulamalı olarak işlenir.',
        'officialActivity': 'Hareket kavramları hakkında öğrencilere '
            'hayattan örnekler verilerek merak uyandırılır (E1.1).',
        'maarifValues': 'D4. Dostluk, D9. Sabır',
        'maarifSkills': 'SB.2.1. Akıl yürütme',
        'differentiation': 'Zenginleştirme: hikâye oluşturma',
        'suggestedActivities': ['Sayı kartları oyunu', 'Grup çalışması'],
        'outcomeParts': [
          {
            'code': 'BEO.1.1.1',
            'text': 'Oyunlarda hareket kavramlarını uygulayabilme',
            'steps': ['a) Beden farkındalığını ayırt eder.'],
          }
        ],
        'dateRange': {'formatted': '8-12 Eylül 2026'},
      };

  group('Tohumlama yolu: JSON -> model -> veritabani -> model', () {
    test('KRITIK: Maarif icerigi kartlara ulasiyor', () async {
      final db = await sema();

      // Tohumlamanin yaptigi is (database_helper.dart ile ayni)
      final model = CurriculumOutcomeModel.fromJson(ornekJson());
      final row = model.toMap()..remove('id');
      await db.insert('curriculum_outcomes', row);

      // Deponun yaptigi is
      final geri = CurriculumOutcomeModel.fromMap(
        (await db.query('curriculum_outcomes')).single,
      );

      // Arayuzdeki "MAARIF DERS OZETI" paneli bunlari gosteriyor
      expect(geri.maarifSummary, contains('bedensel koordinasyon'),
          reason: 'panel artik bos olmamali');
      expect(geri.officialActivity, contains('merak uyandırılır'));
      expect(geri.maarifValues, contains('Dostluk'));
      expect(geri.maarifSkills, contains('Akıl yürütme'));
      expect(geri.differentiation, contains('Zenginleştirme'));

      await db.close();
    });

    test('KRITIK: kazanim parcalari (kod/metin/adimlar) korunuyor', () async {
      final db = await sema();
      final model = CurriculumOutcomeModel.fromJson(ornekJson());
      await db.insert('curriculum_outcomes', model.toMap()..remove('id'));

      final geri = CurriculumOutcomeModel.fromMap(
        (await db.query('curriculum_outcomes')).single,
      );

      expect(geri.outcomeParts, hasLength(1));
      expect(geri.outcomeParts.first.code, 'BEO.1.1.1');
      expect(geri.outcomeParts.first.steps, hasLength(1));
      expect(geri.outcomeParts.first.steps.first, contains('Beden'));

      await db.close();
    });

    test('onerilen etkinlikler listesi korunuyor', () async {
      final db = await sema();
      final model = CurriculumOutcomeModel.fromJson(ornekJson());
      await db.insert('curriculum_outcomes', model.toMap()..remove('id'));

      final geri = CurriculumOutcomeModel.fromMap(
        (await db.query('curriculum_outcomes')).single,
      );

      expect(geri.suggestedActivities, hasLength(2));
      expect(geri.suggestedActivities.first, 'Sayı kartları oyunu');

      await db.close();
    });

    test('ic ice dateRange.formatted alani cozuluyor', () async {
      final db = await sema();
      final model = CurriculumOutcomeModel.fromJson(ornekJson());
      await db.insert('curriculum_outcomes', model.toMap()..remove('id'));

      final geri = CurriculumOutcomeModel.fromMap(
        (await db.query('curriculum_outcomes')).single,
      );

      expect(geri.dateRangeStr, '8-12 Eylül 2026');
      await db.close();
    });

    test('temel alanlar bozulmadi', () async {
      final db = await sema();
      final model = CurriculumOutcomeModel.fromJson(ornekJson());
      await db.insert('curriculum_outcomes', model.toMap()..remove('id'));

      final geri = CurriculumOutcomeModel.fromMap(
        (await db.query('curriculum_outcomes')).single,
      );

      expect(geri.docId, 'out_primary_2026_1_BEDEN_w1');
      expect(geri.gradeLevel, 1);
      expect(geri.subjectCode, 'BEDEN');
      expect(geri.outcomeCode, 'BEO.1.1.1');
      expect(geri.category, 'core');
      await db.close();
    });
  });

  group('Eksik alanlara dayaniklilik', () {
    test('Maarif alanlari bos olan kayit da yuklenir', () async {
      final db = await sema();
      final json = ornekJson()
        ..remove('maarifSummary')
        ..remove('officialActivity')
        ..remove('outcomeParts')
        ..remove('suggestedActivities');

      final model = CurriculumOutcomeModel.fromJson(json);
      await db.insert('curriculum_outcomes', model.toMap()..remove('id'));

      final geri = CurriculumOutcomeModel.fromMap(
        (await db.query('curriculum_outcomes')).single,
      );

      expect(geri.maarifSummary, isNull);
      expect(geri.outcomeParts, isEmpty);
      expect(geri.suggestedActivities, isEmpty);
      // Temel alan yine gelmeli
      expect(geri.outcomeDescription, isNotEmpty);
      await db.close();
    });

    test('bozuk outcomeParts cokme uretmez', () async {
      final db = await sema();
      await db.insert('curriculum_outcomes', {
        'grade_level': 1,
        'subject_code': 'X',
        'subject_name': 'X',
        'week_number': 1,
        'unit_title': 'U',
        'topic_title': 'T',
        'outcome_description': 'D',
        'academic_year': '2026-2027',
        'outcome_parts': 'bu gecerli json degil {{{',
      });

      final row = (await db.query('curriculum_outcomes')).single;
      expect(() => CurriculumOutcomeModel.fromMap(row), returnsNormally);
      expect(CurriculumOutcomeModel.fromMap(row).outcomeParts, isEmpty);
      await db.close();
    });
  });

  group('toMap semayla uyumlu', () {
    test('KRITIK: toMap yalnizca var olan sutunlari yaziyor', () async {
      final db = await sema();
      final model = CurriculumOutcomeModel.fromJson(ornekJson());

      // Olmayan bir sutuna yazmaya calisirsa SQLite hata firlatir.
      // `category` sutunu eksikti; bu test onu yakalar.
      await expectLater(
        db.insert('curriculum_outcomes', model.toMap()..remove('id')),
        completes,
      );

      await db.close();
    });

    test('outcome_parts gecerli JSON olarak saklanir', () {
      final model = CurriculumOutcomeModel.fromJson(ornekJson());
      final row = model.toMap();
      final raw = row['outcome_parts'] as String;

      expect(() => jsonDecode(raw), returnsNormally);
      expect(jsonDecode(raw), isA<List<dynamic>>());
    });
  });
}
