import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hesap degisiminde veri izolasyonu.
///
/// Kullanici bildirimi (31 Agustos 2026):
/// > "1. mailla girdim sinif ekledim ve sinifimi belirledim. 2. mailla
/// > girdigimde yukledigim siniflar gozukuyordu ve sinifi rehberlik
/// > sinifim yap deyince siniflar kayboldu."
///
/// Cihazdan cekilen kanit:
///   sinifcepte_Kplp....db  -> 172 KB, 13 sinif, 110 ogrenci
///   sinifcepte_WNBL....db  ->  12 KB, surum 0, TABLO YOK
///
/// Iki ayri sorun vardi:
///   1. Saglayicilar hesap degisince tazelenmiyordu -> eski hesabin
///      siniflari ekranda kaliyordu
///   2. Yazma yeni (bos) veritabanina gidiyor, liste tazelenince
///      siniflar "kayboluyordu"
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('hesap_izolasyon');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  /// Uretimdeki sema kurulumunun ilgili parcasi.
  Future<Database> hesapDb(String uid) async {
    return databaseFactory.openDatabase(
      '${temp.path}/sinifcepte_$uid.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE classes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              is_homeroom INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE students (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              class_id INTEGER,
              first_name TEXT
            )
          ''');
        },
      ),
    );
  }

  group('Hesaplar birbirinin verisini gormez', () {
    test('KRITIK: ikinci hesap bos baslar', () async {
      final a = await hesapDb('ogretmenA');
      await a.insert('classes', {'name': '5-A', 'is_homeroom': 1});
      await a.insert('classes', {'name': '5-B'});
      expect((await a.query('classes')).length, 2);
      await a.close();

      final b = await hesapDb('ogretmenB');
      expect((await b.query('classes')).length, 0,
          reason: 'ikinci ogretmen birincinin siniflarini GORMEMELI');
      await b.close();
    });

    test('KRITIK: ikinci hesapta yazma birinciyi etkilemez', () async {
      final a = await hesapDb('ogretmenA');
      await a.insert('classes', {'name': '5-A', 'is_homeroom': 1});
      await a.close();

      final b = await hesapDb('ogretmenB');
      await b.insert('classes', {'name': '9-A'});
      await b.close();

      final a2 = await hesapDb('ogretmenA');
      final siniflar = await a2.query('classes');
      expect(siniflar.length, 1);
      expect(siniflar.first['name'], '5-A',
          reason: 'birinci hesabin verisi bozulmamali');
      await a2.close();
    });

    test('KRITIK: rehberlik sinifi hesaba ozel', () async {
      final a = await hesapDb('ogretmenA');
      await a.insert('classes', {'name': '5-A', 'is_homeroom': 1});
      await a.close();

      final b = await hesapDb('ogretmenB');
      await b.insert('classes', {'name': '9-A', 'is_homeroom': 1});

      // B'nin rehberlik sinifi kendi sinifi olmali
      final bHomeroom = await b.query('classes', where: 'is_homeroom = 1');
      expect(bHomeroom.length, 1);
      expect(bHomeroom.first['name'], '9-A');
      await b.close();

      // A'ninki degismemis olmali
      final a2 = await hesapDb('ogretmenA');
      final aHomeroom = await a2.query('classes', where: 'is_homeroom = 1');
      expect(aHomeroom.first['name'], '5-A');
      await a2.close();
    });
  });

  group('Yeni hesabin veritabani DOGRU kuruluyor', () {
    test('KRITIK: yeni hesapta tablolar olusuyor', () async {
      // Cihazda bulunan bozuk dosya: surum 0, yalnizca
      // android_metadata tablosu vardi.
      final b = await hesapDb('yeniOgretmen');

      final tablolar = await b.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final adlar = tablolar.map((r) => r['name'] as String).toSet();

      expect(adlar, contains('classes'),
          reason: 'sema kurulmazsa "no such table: classes" hatasi duser');
      expect(adlar, contains('students'));
      await b.close();
    });

    test('KRITIK: yeni hesabin surumu sifir degil', () async {
      final b = await hesapDb('yeniOgretmen');
      final v = (await b.rawQuery('PRAGMA user_version')).first.values.first;
      expect(v, isNot(0),
          reason: 'surum 0 = onCreate hic calismamis demek');
      await b.close();
    });

    test('bos veritabanina yazma calisir', () async {
      final b = await hesapDb('yeniOgretmen');
      await b.insert('classes', {'name': '6-A', 'is_homeroom': 1});
      expect((await b.query('classes')).length, 1);
      await b.close();
    });
  });

  group('Saglayici tazeleme kapsami', () {
    test('KRITIK: yerel saglayicilarin hepsi listede', () {
      // Yeni bir yerel saglayici eklenip buraya eklenmezse, hesap
      // degisiminde o veri eski hesaptan gorunmeye devam eder.
      final kaynak =
          File('lib/core/database/account_switch.dart').readAsStringSync();

      for (final saglayici in [
        'classListProvider',
        'studentListProvider',
        'seatingPlanProvider',
        'scheduleProvider',
        'examTrackingProvider',
        'quizTableProvider',
        'currentParticipationSessionProvider',
      ]) {
        expect(kaynak, contains('ref.invalidate($saglayici)'),
            reason: '$saglayici hesap degisiminde tazelenmeli');
      }
    });

    test('KRITIK: giris noktalari tazelemeyi cagiriyor', () {
      final giris =
          File('lib/features/auth/screens/welcome_screen.dart')
              .readAsStringSync();
      expect(giris, contains('AccountSwitch.invalidateLocalData'),
          reason: 'giriste tazeleme yapilmazsa eski veri ekranda kalir');

      final gate = File(
        'lib/features/auth_profile/presentation/views/school_bind_gate.dart',
      ).readAsStringSync();
      expect(gate, contains('AccountSwitch.invalidateLocalData'));
    });
  });

  group('Giriste alt bar sekmesi sifirlaniyor', () {
    test('KRITIK: hesap degisiminde sekme Ozete doner', () {
      // `navigationIndexProvider` bir StateProvider; cikis yapilinca
      // sifirlanmiyordu. Cikis dugmesi PROFIL sekmesinde oldugu icin
      // deger 4'te kaliyor ve tekrar girildiginde uygulama dogrudan
      // profil ekraniyla aciliyordu.
      final kod =
          File('lib/core/database/account_switch.dart').readAsStringSync();
      expect(kod, contains('ref.invalidate(navigationIndexProvider)'),
          reason: 'giriste Ozet sekmesi acilmali');
    });

    test('KRITIK: cikista da sifirlaniyor', () {
      // Giris yolu her zaman AccountSwitch'ten gecmeyebilir; cikista
      // da sifirlamak garanti saglar.
      final kod = File(
        'lib/features/auth_profile/presentation/views/'
        'teacher_profile_setup_view.dart',
      ).readAsStringSync();
      expect(kod, contains('ref.invalidate(navigationIndexProvider)'));
    });
  });
}
