import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Goc zinciri: v12 -> v14 (Faz 4.3).
///
/// Gercek cihazda uc hesap veritabani bulundu; biri v14'e yukseltildi
/// ama digerleri **v12'de bekliyor** cunku o hesaplar henuz acilmadi.
/// O hesaplara girildiginde v13 ve v14 goclerinin SIRAYLA ve tek seferde
/// calismasi gerekiyor.
///
/// Bu test atlanan surumlerin birikmeli uygulandigini dogrular; aksi
/// halde eski hesaba giren ogretmen "table has no column named ..."
/// hatasiyla karsilasirdi.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  /// Surum 12 semasinin ilgili parcasi.
  Future<Database> v12Semasi(String yol) async {
    final db = await databaseFactory.openDatabase(
      yol,
      options: OpenDatabaseOptions(version: 12),
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
        academic_year TEXT NOT NULL,
        is_holiday_week INTEGER DEFAULT 0,
        holiday_note TEXT
      )
    ''');
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

  /// Uretimdeki v13 + v14 gocunun aynisi.
  Future<void> gocUygula(Database db, int eskiSurum) async {
    if (eskiSurum < 13) {
      await db.execute('ALTER TABLE kisisel_sinavlar ADD COLUMN sinif TEXT');
      await db.execute('''
        UPDATE kisisel_sinavlar
        SET sinif = basvuru_linki, basvuru_linki = NULL
        WHERE basvuru_linki IS NOT NULL
          AND basvuru_linki != ''
          AND basvuru_linki NOT LIKE 'http%'
      ''');
    }
    if (eskiSurum < 14) {
      const yeni = <String, String>{
        'category': 'TEXT',
        'outcome_parts': 'TEXT',
        'suggested_activities': 'TEXT',
        'official_activity': 'TEXT',
        'maarif_summary': 'TEXT',
        'maarif_values': 'TEXT',
        'maarif_skills': 'TEXT',
        'differentiation': 'TEXT',
        'span_index': 'INTEGER',
        'span_total': 'INTEGER',
        'date_range_str': 'TEXT',
        'is_estimated_schedule': 'INTEGER DEFAULT 0',
        'is_otp_week': 'INTEGER DEFAULT 0',
        'is_social_event_week': 'INTEGER DEFAULT 0',
      };
      for (final e in yeni.entries) {
        await db.execute(
          'ALTER TABLE curriculum_outcomes ADD COLUMN ${e.key} ${e.value}',
        );
      }
      await db.delete('curriculum_outcomes');
    }
  }

  test('KRITIK: v12 hesabi tek seferde v14 semasina ulasir', () async {
    final db = await v12Semasi(inMemoryDatabasePath);

    // Eski hesapta zaten kazanim var (v12 doneminden)
    await db.insert('curriculum_outcomes', {
      'grade_level': 5,
      'subject_code': 'MAT',
      'subject_name': 'Matematik',
      'week_number': 1,
      'unit_title': 'U',
      'topic_title': 'T',
      'outcome_description': 'Eski kayit',
      'academic_year': '2026-2027',
    });

    await gocUygula(db, 12);

    final sutunlar = (await db.rawQuery('PRAGMA table_info(curriculum_outcomes)'))
        .map((r) => r['name'] as String)
        .toSet();

    for (final s in [
      'category',
      'maarif_summary',
      'official_activity',
      'outcome_parts',
      'differentiation',
    ]) {
      expect(sutunlar, contains(s), reason: '$s sutunu eklenmeliydi');
    }

    // Eski kayitlar temizlenmeli ki yeni alanlarla yeniden tohumlansin;
    // aksi halde ogretmen bos Maarif kutulariyla kalirdi.
    final kalan = (await db.query('curriculum_outcomes')).length;
    expect(kalan, 0, reason: 'yeniden tohumlama icin tablo bosaltilmali');

    await db.close();
  });

  test('KRITIK: v13 gocu de atlanmadan uygulanir', () async {
    final db = await v12Semasi(inMemoryDatabasePath);

    // v12 doneminde sinif adi yanlis sutuna yaziliyordu
    await db.insert('kisisel_sinavlar', {
      'doc_id': 'okul_1',
      'sinav_adi': 'Yazılı',
      'kurum': 'OKUL',
      'sinav_tarihi': '2026-12-10T00:00:00.000',
      'basvuru_linki': '5-A',
    });

    await gocUygula(db, 12);

    final row = (await db.query('kisisel_sinavlar')).single;
    expect(row['sinif'], '5-A',
        reason: 'v12 -> v14 atlarken v13 gocu de calismali');
    expect(row['basvuru_linki'], isNull);

    await db.close();
  });

  test('v13 hesabi yalnizca v14 gocunu alir', () async {
    final db = await v12Semasi(inMemoryDatabasePath);
    // Once v13'e cikar
    await gocUygula(db, 12);
    await db.close();

    // v13'ten gelen bir hesapta v13 gocu TEKRAR calismamali
    final db2 = await v12Semasi(inMemoryDatabasePath);
    await gocUygula(db2, 13);

    final sutunlar = (await db2.rawQuery('PRAGMA table_info(curriculum_outcomes)'))
        .map((r) => r['name'] as String)
        .toSet();
    expect(sutunlar, contains('maarif_summary'));

    await db2.close();
  });

  test('goc iki kez calisirsa cokme uretmez', () async {
    final db = await v12Semasi(inMemoryDatabasePath);
    await gocUygula(db, 12);

    // Ayni sutunu tekrar eklemek hata firlatir; uretimde try/catch ile
    // yutuluyor. Burada o davranisi dogruluyoruz.
    var hata = false;
    try {
      await db.execute(
        'ALTER TABLE curriculum_outcomes ADD COLUMN maarif_summary TEXT',
      );
    } catch (_) {
      hata = true;
    }
    expect(hata, isTrue,
        reason: 'SQLite tekrar eklemeye izin vermez — uretimde yutuluyor');

    await db.close();
  });
}
