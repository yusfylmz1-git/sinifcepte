import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/utils/name_formatter.dart';

/// Ad-soyad standardi gocu (surum 16).
///
/// Yeni kayitlar bicimlendirilerek yaziliyor ama ESKI kayitlar oldugu
/// gibi duruyordu: ayni listede "Yusuf YILMAZ" ile "Semih Uzum" yan
/// yana gorunuyordu. Cihazdan cekilen gercek veri boyleydi:
///   Abdurrahman Baksal, Gulcicek Basaran, Semih Uzum...
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> eskiVeri() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT,
        last_name TEXT
      )
    ''');
    // Cihazdan cekilen gercek adlar
    for (final ad in [
      ['Abdurrahman', 'Baksal'],
      ['Gülçiçek', 'Başaran'],
      ['Semih', 'Üzüm'],
      ['şeyma', 'kisa'],
      ['MURAT', 'KEŞLİ'],
      ['ışıl', 'işık'],
    ]) {
      await db.insert('students', {'first_name': ad[0], 'last_name': ad[1]});
    }
    return db;
  }

  /// Uretimdeki `_migrateNameFormat` ile ayni mantik.
  Future<void> goc(Database db) async {
    final rows = await db.query('students',
        columns: ['id', 'first_name', 'last_name']);
    final batch = db.batch();
    for (final r in rows) {
      batch.update(
        'students',
        {
          'first_name':
              NameFormatter.formatFirstName((r['first_name'] as String?) ?? ''),
          'last_name':
              NameFormatter.formatLastName((r['last_name'] as String?) ?? ''),
        },
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  test('KRITIK: mevcut kayitlar standarda cevriliyor', () async {
    final db = await eskiVeri();
    await goc(db);

    final rows = await db.query('students', orderBy: 'id ASC');
    final adlar = rows
        .map((r) => '${r['first_name']} ${r['last_name']}')
        .toList();

    expect(adlar[0], 'Abdurrahman BAKSAL');
    expect(adlar[1], 'Gülçiçek BAŞARAN');
    expect(adlar[2], 'Semih ÜZÜM');
    await db.close();
  });

  test('KRITIK: kucuk yazilmis kayitlar duzeliyor', () async {
    final db = await eskiVeri();
    await goc(db);

    final r = (await db.query('students', where: 'id = 4')).single;
    // "kisa" NOKTALI i ile yazilmis; dogrusu KİSA.
    // (Noktasiz "kısa" olsaydi KISA olurdu.)
    expect('${r['first_name']} ${r['last_name']}', 'Şeyma KİSA');
    await db.close();
  });

  test('KRITIK: tamamen buyuk yazilmis ad duzeliyor', () async {
    final db = await eskiVeri();
    await goc(db);

    final r = (await db.query('students', where: 'id = 5')).single;
    // Ad bas harf buyuk, soyad tamamen buyuk kalir
    expect('${r['first_name']} ${r['last_name']}', 'Murat KEŞLİ');
    await db.close();
  });

  test('KRITIK: Turkce harfler gocte bozulmuyor', () async {
    final db = await eskiVeri();
    await goc(db);

    final r = (await db.query('students', where: 'id = 6')).single;
    // "isil isik" -> "Isil ISIK" degil, "Işıl İŞIK" olmali
    expect(r['first_name'], 'Işıl');
    expect(r['last_name'], 'İŞIK');
    await db.close();
  });

  test('KRITIK: goc iki kez calisirsa veri bozulmaz', () async {
    // Bicimlendirme kararli olmali: goc yanlislikla tekrar calisirsa
    // "YILMAZ" -> "Yilmaz" gibi bir bozulma OLMAMALI.
    final db = await eskiVeri();
    await goc(db);
    final ilk = await db.query('students', orderBy: 'id ASC');

    await goc(db);
    final ikinci = await db.query('students', orderBy: 'id ASC');

    for (var i = 0; i < ilk.length; i++) {
      expect(ikinci[i]['first_name'], ilk[i]['first_name']);
      expect(ikinci[i]['last_name'], ilk[i]['last_name']);
    }
    await db.close();
  });

  test('bos ad alani cokme uretmiyor', () async {
    final db = await eskiVeri();
    await db.insert('students', {'first_name': '', 'last_name': null});

    // `returnsNormally` async fonksiyonda ise yaramaz: Future donunce
    // hemen "normal" sayar. Dogrudan await edip hata firlatmadigini
    // dogrulamak gerekiyor.
    await goc(db);

    final r = (await db.query('students', orderBy: 'id DESC')).first;
    expect(r['first_name'], '');
    expect(r['last_name'], '');
    await db.close();
  });
}
