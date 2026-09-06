import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';

/// Yeni kazanım paketinin telefona gerçekten inmesi.
///
/// ## Neden bu test var
/// Öğretmen APK'yı kurduktan sonra sordu: *"kurulumu baştan silip
/// yüklemen gerek?"* Sezgisi doğruydu — tohumlama koşulu şuydu:
///
///     if (count >= 1000 && !force) return;
///
/// Telefonda eski veriden 9087 kayıt duruyordu, yani yeni paket APK
/// ile geliyor ama **hiç yüklenmiyordu**. Kaynak sütunları
/// (`is_maarif`, `source_portal`) eklendiğinde bu görünür oldu:
/// sütunlar geliyor ama boş kalıyor ve Maarif rozeti hiçbir yerde
/// çıkmıyordu.
///
/// Çözüm uygulamayı silmek değildi — 30.000 öğretmen uygulamayı
/// silemez ve silmek sınıf, öğrenci, BEP verisini de götürür.
/// Pakete bir sürüm damgası konuldu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'kazanim_tohumlama_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
  });

  group('Paket surumu damgasi', () {
    test('KRITIK: paket surumu ARTMIS olmali', () {
      // Veri bu sürümde değişti (MEB'in Eylül 2026 planları + kaynak
      // alanları). Damga artmazsa telefondaki eski veri yerinde
      // kalır ve rozet hiçbir yerde çıkmaz.
      expect(DatabaseHelper.kazanimPaketSurumu, greaterThan(1),
          reason: 'paket değişti ama sürüm damgası artmamış');
    });

    test('KRITIK: ilk acilista veri yuklenir', () async {
      final db = await DatabaseHelper.instance.database;
      final once = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) c FROM curriculum_outcomes')) ??
          0;
      expect(once, 0, reason: 'temiz veritabanı beklenmişti');

      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();

      final sonra = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) c FROM curriculum_outcomes')) ??
          0;
      expect(sonra, greaterThan(1000), reason: 'veri yüklenmedi');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('KRITIK: PAKET DEGISINCE veri yeniden yazilir', () async {
      // Asıl kusur buydu: eski veri duruyorsa yeni paket hiç
      // yüklenmiyordu.
      final db = await DatabaseHelper.instance.database;
      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();

      // Telefondaki durumu taklit et: veri dolu ama ESKİ paketten.
      // Kaynak alanlarını boşalt ve damgayı geriye al.
      await db.rawUpdate(
          'UPDATE curriculum_outcomes SET is_maarif = 0, source_portal = NULL');
      await DatabaseHelper.instance
          .syncMetadataVersionGuncelle('curriculum_asset_version', 1);

      final eskiSayi = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) c FROM curriculum_outcomes')) ??
          0;
      expect(eskiSayi, greaterThan(1000), reason: 'kurgu hazırlanamadı');

      // force VERİLMEDEN çağrılıyor — gerçek açılıştaki gibi.
      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();

      final rozetli = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) c FROM curriculum_outcomes WHERE is_maarif = 1')) ??
          0;
      expect(rozetli, greaterThan(0),
          reason: 'paket değişmesine rağmen veri yenilenmedi — '
              'Maarif rozeti hiçbir derste çıkmaz');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('paket AYNIYSA gereksiz yeniden yazma YAPILMAZ', () async {
      // Her açılışta 10.000 kayıt yeniden yazmak telefonu yorar.
      final db = await DatabaseHelper.instance.database;
      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();

      // Bir kaydı işaretle: yeniden yazılırsa işaret kaybolur.
      await db.rawUpdate(
          "UPDATE curriculum_outcomes SET unit_title = 'DOKUNULMADI' "
          'WHERE id = (SELECT MIN(id) FROM curriculum_outcomes)');

      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();

      final kalan = Sqflite.firstIntValue(await db.rawQuery(
              "SELECT COUNT(*) c FROM curriculum_outcomes "
              "WHERE unit_title = 'DOKUNULMADI'")) ??
          0;
      expect(kalan, 1, reason: 'paket aynıyken tablo yeniden yazılmış');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('KRITIK: yuklenen veride kaynak alanlari DOLU', () async {
      final db = await DatabaseHelper.instance.database;
      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();

      final maarif = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) c FROM curriculum_outcomes WHERE is_maarif = 1')) ??
          0;
      final eski = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) c FROM curriculum_outcomes WHERE is_maarif = 0')) ??
          0;

      // İkisi de olmalı: başlangıçta HER kayıt Maarif işaretliydi ve
      // bu, Maarif'in yürürlükte olmadığı sınıflarda yanıltıcıydı.
      expect(maarif, greaterThan(0), reason: 'hiç Maarif kaydı yok');
      expect(eski, greaterThan(0),
          reason: 'her kayıt Maarif işaretli — eski durum geri gelmiş');

      final portal = Sqflite.firstIntValue(await db.rawQuery(
              "SELECT COUNT(*) c FROM curriculum_outcomes "
              "WHERE source_portal IN ('tymm', 'dogm')")) ??
          0;
      expect(portal, greaterThan(0), reason: 'kaynak alanı boş gelmiş');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
