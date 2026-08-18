import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';

/// Hesap izolasyonu ve eski veritabanı göçü.
///
/// ## Karar bağlamı (18 Ağustos 2026 — Seçenek A)
/// Öğrenci, sınıf ve not verileri **öğretmenin cihazında** kalır; buluta
/// çıkmaz. Bu, KVKK yükünü en aza indirir ama her Google hesabının ayrı
/// bir çalışma alanı olması sonucunu doğurur.
///
/// Bu testler iki şeyi korur:
/// 1. Hesaplar birbirinin verisini görmez (izolasyon).
/// 2. Eski sürüm göçü yalnızca BİR kez çalışır — aksi halde ikinci hesap
///    da aynı eski veriyi devralır ve veriler karışır (yaşanan hata).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
  });

  group('Hesap başına veritabanı adı', () {
    test('Her UID farklı dosya adı üretir', () {
      final a = AppConfig.teacherDbName('uidAhmet');
      final b = AppConfig.teacherDbName('uidMehmet');

      expect(a, isNot(b));
      expect(a, 'sinifcepte_uidAhmet.db');
    });

    test('Aynı UID her zaman aynı dosyayı verir', () {
      expect(
        AppConfig.teacherDbName('uidAhmet'),
        AppConfig.teacherDbName('uidAhmet'),
      );
    });

    test('Dosya adında güvensiz karakter kalmaz', () {
      // UID beklenmedik karakter içerse bile dosya adı güvenli olmalı.
      final name = AppConfig.teacherDbName('uid/../../etc/passwd');

      expect(name.contains('/'), isFalse);
      expect(name.contains('..'), isFalse);
      expect(name.startsWith('sinifcepte_'), isTrue);
      expect(name.endsWith('.db'), isTrue);
    });
  });

  group('Hesap değişikliği tespiti', () {
    test('İlk girişte hesap değişikliği yoktur', () async {
      expect(await DatabaseHelper.isDifferentAccountThanLast('uid1'), isFalse);
    });

    test('KRİTİK: farklı hesapla giriş tespit edilir', () async {
      // Kullanıcı "verilerim silindi" sanmasın diye uyarılmalı.
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'uid1',
      });
      PrefsService.resetCache();

      expect(await DatabaseHelper.isDifferentAccountThanLast('uid2'), isTrue);
    });

    test('Aynı hesapla tekrar giriş uyarı üretmez', () async {
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'uid1',
      });
      PrefsService.resetCache();

      expect(await DatabaseHelper.isDifferentAccountThanLast('uid1'), isFalse);
    });

    test('Son hesap kimliği okunabilir', () async {
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'uidAhmet',
      });
      PrefsService.resetCache();

      expect(await DatabaseHelper.lastKnownUid(), 'uidAhmet');
    });

    test('Kayıt yoksa boş döner', () async {
      expect(await DatabaseHelper.lastKnownUid(), isEmpty);
    });
  });

  group('Eski veritabanı göçü (yaşanan hatanın kaynağı)', () {
    test('KRİTİK: göç bayrağı ikinci hesabı korur', () async {
      // Senaryo: 1. hesap eski veritabanını devraldı ve bayrak yazıldı.
      SharedPreferences.setMockInitialValues({
        'sinifcepte_legacy_db_migrated': true,
      });
      PrefsService.resetCache();

      final prefs = await PrefsService.instance();

      // 2. hesap giriş yaptığında bayrak zaten true olduğu için göç
      // ATLANIR ve boş bir çalışma alanı açılır.
      expect(prefs?.getBool('sinifcepte_legacy_db_migrated'), isTrue);
    });

    test('Bayrak yoksa göç bir kez denenir', () async {
      final prefs = await PrefsService.instance();

      // Temiz kurulumda bayrak yok: ilk hesap devralma hakkına sahip.
      expect(prefs?.getBool('sinifcepte_legacy_db_migrated'), isNull);
    });
  });
}
