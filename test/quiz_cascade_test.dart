import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kolon silinince notlarina ne oluyor? (Faz 2.3)
///
/// Semada `ON DELETE CASCADE` yaziyor ama sqflite'ta yabanci anahtarlar
/// baglanti basina `PRAGMA foreign_keys = ON` calistirilmazsa SESSIZCE
/// devre disi kalir. O durumda kolon silinir, notlar tabloda oksuz kalir
/// ve ortalamalar silinmis kolonun notlariyla hesaplanmaya devam eder.
///
/// Bu test pragmanin gercekten ise yaradigini kanitlar.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> kur({required bool foreignKeys}) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (d) async {
          if (foreignKeys) {
            await d.execute('PRAGMA foreign_keys = ON');
          }
        },
        onCreate: (d, _) async {
          await d.execute('''
            CREATE TABLE quiz_kolonlari (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cizelge_id INTEGER NOT NULL,
              baslik TEXT NOT NULL
            )
          ''');
          await d.execute('''
            CREATE TABLE quiz_notlari (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              kolon_id INTEGER NOT NULL,
              ogrenci_id INTEGER NOT NULL,
              puan INTEGER,
              UNIQUE(kolon_id, ogrenci_id),
              FOREIGN KEY (kolon_id) REFERENCES quiz_kolonlari (id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );
    final kolonId = await db.insert(
        'quiz_kolonlari', {'cizelge_id': 1, 'baslik': '1. Quiz'});
    for (var ogrenci = 1; ogrenci <= 3; ogrenci++) {
      await db.insert('quiz_notlari',
          {'kolon_id': kolonId, 'ogrenci_id': ogrenci, 'puan': 80 + ogrenci});
    }
    return db;
  }

  test('pragma acikken kolon silinince notlari da silinir', () async {
    final db = await kur(foreignKeys: true);
    expect((await db.query('quiz_notlari')).length, 3);

    await db.delete('quiz_kolonlari', where: 'id = ?', whereArgs: [1]);

    expect((await db.query('quiz_notlari')).length, 0,
        reason: 'oksuz not kalmamali');
    await db.close();
  });

  test('pragma kapaliyken notlar oksuz kalir (regresyon bekcisi)', () async {
    final db = await kur(foreignKeys: false);

    await db.delete('quiz_kolonlari', where: 'id = ?', whereArgs: [1]);

    expect((await db.query('quiz_notlari')).length, 3,
        reason: 'pragma unutulursa bu olur; uretimde _onConfigure calistiriyor');
    await db.close();
  });

  test('UNIQUE(kolon_id, ogrenci_id) ayni ogrenciye ikinci not yazdirmaz',
      () async {
    final db = await kur(foreignKeys: true);

    await db.insert(
      'quiz_notlari',
      {'kolon_id': 1, 'ogrenci_id': 1, 'puan': 95},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final rows = await db.query('quiz_notlari',
        where: 'kolon_id = ? AND ogrenci_id = ?', whereArgs: [1, 1]);
    expect(rows.length, 1, reason: 'not cogaltilmamali, guncellenmeli');
    expect(rows.first['puan'], 95);
    await db.close();
  });
}
