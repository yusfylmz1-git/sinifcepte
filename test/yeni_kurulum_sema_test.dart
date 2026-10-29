import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/data/repositories/exam_operations_repository.dart';

/// Sıfırdan kurulan veritabanı, yükseltilen veritabanıyla aynı sütunlara
/// sahip olmalı.
///
/// ## Neden (29 Ekim 2026)
/// Sürüm 13 göçü `kisisel_sinavlar.sinif` sütununu yalnız YÜKSELTİLEN
/// cihazlara ekliyordu; `_createDB` tabloyu sütunsuz kuruyordu. Play'den
/// ilk kez kuran her öğretmende "Okulum" yazılı sınavı kaydedilemiyor,
/// pencere sessizce kapanıyordu. Göç testi elle yazılmış eski şemada
/// çalıştığı için yeni kurulum yolu hiç sınanmamıştı. Sınav İşlemleri
/// taslağı çizilirken görüldü.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'yeni_kurulum_sema_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.resetForTests();
  });

  Future<Set<String>> sutunlar(Database db, String tablo) async =>
      (await db.rawQuery('PRAGMA table_info($tablo)')).map((r) => r['name'] as String).toSet();

  test('KRITIK: göçle eklenen her sütun sıfırdan kurulumda da var', () async {
    final db = await DatabaseHelper.instance.database;
    // Satıra bölünmüş dizeler ('ALTER TABLE x ADD COLUMN ' '...') birleştirilir.
    final kaynak = File('lib/core/database/database_helper.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r"'\s*\n\s*'"), '');

    final beklenen = <String, Set<String>>{};
    void ekle(String t, String c) => beklenen.putIfAbsent(t, () => {}).add(c);
    for (final m in RegExp(r'ALTER TABLE (\w+)\s+ADD COLUMN (\w+)').allMatches(kaynak)) {
      ekle(m.group(1)!, m.group(2)!);
    }
    for (final m in RegExp(r"_safeAddColumn\(db, '(\w+)', '(\w+)'").allMatches(kaynak)) {
      ekle(m.group(1)!, m.group(2)!);
    }

    // Sütun adı değişkenden gelen göçler elle listelenir. Yeni bir döngülü
    // göç eklenirse aşağıdaki sayı tutmaz ve bu liste güncellenmek zorunda kalır.
    const dongulu = <String, List<String>>{
      'bep_coarse': ['evaluated_at', 'evaluated_by'],
      'bep_short_goals': ['materials', 'assessment'],
      'bep_plans': ['physical_arrangements', 'social_arrangements', 'digital_supports'],
      'curriculum_outcomes': [
        'is_maarif', 'source_portal', 'source_program', //
        'category', 'outcome_parts', 'suggested_activities', 'official_activity',
        'maarif_summary', 'maarif_values', 'maarif_skills', 'differentiation',
        'span_index', 'span_total', 'date_range_str', 'is_estimated_schedule',
        'is_otp_week', 'is_social_event_week',
      ],
    };
    // 5 döngülü göç + _safeAddColumn'un kendi gövdesi.
    expect(RegExp(r'ADD COLUMN \$').allMatches(kaynak).length, 6,
        reason: 'döngülü göç sayısı değişti; yukarıdaki listeyi güncelleyin');
    for (final e in dongulu.entries) {
      for (final c in e.value) {
        ekle(e.key, c);
      }
    }

    expect(beklenen['kisisel_sinavlar'], contains('sinif'), reason: 'tarama kendini sınar');
    expect(beklenen.values.expand((s) => s).length, greaterThan(40));

    final eksik = <String>[];
    for (final e in beklenen.entries) {
      final var_ = await sutunlar(db, e.key);
      for (final c in e.value) {
        if (!var_.contains(c)) eksik.add('${e.key}.$c');
      }
    }
    expect(eksik, isEmpty, reason: '_createDB bu sütunları kurmuyor');
  });

  test('KRITIK: yeni kurulumda okul sınavı sınıfıyla kaydedilir', () async {
    final repo = ExamOperationsRepository();
    final id = await repo.addSchoolExam(ExamModel(
      id: '',
      title: '5-A Matematik 1. Yazılı',
      examDate: DateTime(2026, 11, 10),
      category: 'OKUL',
      isSchoolExam: true,
      className: '5-A',
    ));
    expect(id, greaterThan(0));
    final okul = (await repo.getAllExams()).where((e) => e.isSchoolExam).single;
    expect(okul.title, '5-A Matematik 1. Yazılı');
    expect(okul.className, '5-A');
  });

  test('sütunsuz kurulmuş cihaz açılışta onarılır', () async {
    final db = await DatabaseHelper.instance.database;
    // Hatalı sürümün kurduğu tablo.
    await db.execute('DROP TABLE kisisel_sinavlar');
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
    await db.insert('kisisel_sinavlar', {
      'doc_id': 'okul_1',
      'sinav_adi': 'Eski kayıt',
      'kurum': 'OKUL',
      'sinav_tarihi': '2026-11-10T00:00:00.000',
    });
    expect(await sutunlar(db, 'kisisel_sinavlar'), isNot(contains('sinif')));

    await DatabaseHelper.instance.closeConnection();
    final yeniden = await DatabaseHelper.instance.database;
    expect(await sutunlar(yeniden, 'kisisel_sinavlar'), contains('sinif'));
    expect((await yeniden.query('kisisel_sinavlar')).single['sinav_adi'], 'Eski kayıt',
        reason: 'onarım kayıtları silmemeli');
  });
}
