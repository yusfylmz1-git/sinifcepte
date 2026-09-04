import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Veri yedekleme (bagimsiz denetim bulgusu).
///
/// Profil ekranindaki "Verileri Yedekle" dugmesi YALNIZCA bir mesaj
/// gosteriyordu:
///
///   onPressed: () {
///     ScaffoldMessenger.of(context).showSnackBar(
///       const SnackBar(content: Text('Veri Yedekleme Dosyasi Hazirlandi!')),
///     );
///   }
///
/// Hicbir dosya yazilmiyordu. Ogretmene "verin guvende" dedirtip
/// telefonu bozuldugunda bir yili kaybettirecek bir yalandi.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sinifcepte_backup_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  /// Icinde veri olan gercek bir SQLite dosyasi uretir.
  Future<String> ornekVeritabani() async {
    final yol = '${temp.path}/kaynak.db';
    final db = await databaseFactory.openDatabase(yol);
    await db.execute('CREATE TABLE ogrenciler (id INTEGER, ad TEXT)');
    await db.insert('ogrenciler', {'id': 1, 'ad': 'Ahmet'});
    await db.insert('ogrenciler', {'id': 2, 'ad': 'Ayşe'});
    await db.close();
    return yol;
  }

  group('Yedek gercekten dosya uretiyor', () {
    test('KRITIK: kopyalanan dosya bos degil', () async {
      final kaynak = await ornekVeritabani();
      final hedef = '${temp.path}/yedek.sinifcepte';

      await File(kaynak).copy(hedef);

      final f = File(hedef);
      expect(await f.exists(), isTrue, reason: 'dosya yazilmali');
      expect(await f.length(), greaterThan(0),
          reason: 'bos dosya yedek degildir');
    });

    test('KRITIK: yedekteki veri okunabiliyor', () async {
      final kaynak = await ornekVeritabani();
      final hedef = '${temp.path}/yedek.sinifcepte';
      await File(kaynak).copy(hedef);

      // Yedegi acip icindeki veriyi dogrula
      final db = await databaseFactory.openDatabase(hedef);
      final rows = await db.query('ogrenciler');
      expect(rows.length, 2, reason: 'ogrenciler yedekte olmali');
      expect(rows.first['ad'], 'Ahmet');
      await db.close();
    });

    test('Turkce karakterler bozulmuyor', () async {
      final kaynak = await ornekVeritabani();
      final hedef = '${temp.path}/yedek.sinifcepte';
      await File(kaynak).copy(hedef);

      final db = await databaseFactory.openDatabase(hedef);
      final rows = await db.query('ogrenciler', where: 'id = 2');
      expect(rows.first['ad'], 'Ayşe');
      await db.close();
    });
  });

  group('SQLite imza dogrulamasi', () {
    /// `BackupService._isSqlite` ile ayni mantik.
    Future<bool> sqliteMi(File f) async {
      try {
        final bytes = await f.openRead(0, 16).first;
        const imza = 'SQLite format 3';
        return String.fromCharCodes(bytes.take(imza.length)) == imza;
      } catch (_) {
        return false;
      }
    }

    test('KRITIK: gercek veritabani taninir', () async {
      final kaynak = await ornekVeritabani();
      expect(await sqliteMi(File(kaynak)), isTrue);
    });

    test('KRITIK: yanlis dosya reddedilir', () async {
      // Ogretmen yanlis dosya secerse veritabani bozulur ve HER SEYINI
      // kaybeder. Imza kontrolu bunu onler.
      final sahte = File('${temp.path}/foto.jpg');
      await sahte.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      expect(await sqliteMi(sahte), isFalse);
    });

    test('bos dosya reddedilir', () async {
      final bos = File('${temp.path}/bos.db');
      await bos.writeAsBytes([]);
      expect(await sqliteMi(bos), isFalse);
    });

    test('metin dosyasi reddedilir', () async {
      final metin = File('${temp.path}/not.txt');
      await metin.writeAsString('bu bir veritabani degil');
      expect(await sqliteMi(metin), isFalse);
    });
  });

  group('Geri yukleme', () {
    test('KRITIK: geri yuklenen veri dogru', () async {
      final kaynak = await ornekVeritabani();
      final yedek = '${temp.path}/yedek.sinifcepte';
      await File(kaynak).copy(yedek);

      // Kaynak bozulur (ogretmen veri kaybeder)
      final db = await databaseFactory.openDatabase(kaynak);
      await db.delete('ogrenciler');
      await db.close();

      final bosDb = await databaseFactory.openDatabase(kaynak);
      expect((await bosDb.query('ogrenciler')).length, 0);
      await bosDb.close();

      // Geri yukle
      await File(yedek).copy(kaynak);

      final geriDb = await databaseFactory.openDatabase(kaynak);
      final rows = await geriDb.query('ogrenciler');
      expect(rows.length, 2, reason: 'veri geri gelmeli');
      await geriDb.close();
    });
  });

  group('Dugme artik yalan soylemiyor', () {
    test('KRITIK: yedek dugmesi BackupService cagiriyor', () {
      final s = File(
        'lib/features/auth_profile/presentation/views/'
        'teacher_profile_setup_view.dart',
      ).readAsStringSync();

      expect(s, contains('BackupService.instance.exportDatabase'),
          reason: 'dugme gercek yedekleme yapmali');

      // Eski yalan mesaj geri gelmemeli
      expect(s.contains("Text('Veri Yedekleme Dosyası Hazırlandı! 💾')"),
          isFalse,
          reason: 'dosya yazmadan "hazirlandi" denmemeli');
    });
  });
}
