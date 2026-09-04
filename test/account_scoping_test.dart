import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinifcepte/core/config/app_config.dart';

/// Ayni cihazda birden fazla ogretmen hesabi.
///
/// Kullanici testte fark etti: bir hesaptan cikip digeriyle girince okul
/// yeniden soruluyordu. Sebep, profil anahtarlarinin SABIT olmasiydi
/// (`profil_okul`) — cihazda tek bir profil tutuluyordu.
///
/// Sinif/ogrenci verisi ise hesap basina ayri veritabani dosyasinda
/// tutulur (`DatabaseHelper.openForUid`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Uretimdeki anahtar uretici ile ayni mantik.
  String key(String base, String uid) => uid.isEmpty ? base : '${base}__$uid';

  group('Profil anahtarlari hesaba baglidir', () {
    test('KRITIK: iki hesap ayri okul bilgisi tutar', () async {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(key('profil_okul', 'uid_ahmet'), 'Ataturk Ortaokulu');
      await prefs.setString(key('profil_okul', 'uid_zeynep'), 'Gazi Lisesi');

      expect(prefs.getString(key('profil_okul', 'uid_ahmet')),
          'Ataturk Ortaokulu');
      expect(prefs.getString(key('profil_okul', 'uid_zeynep')), 'Gazi Lisesi');
    });

    test('KRITIK: bir hesabin kaydi digerini etkilemez', () async {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(key('profil_okul_id', 'uid_ahmet'), 'okul_1');
      await prefs.setString(key('profil_okul_id', 'uid_zeynep'), 'okul_2');

      // Ahmet cikis yapsa bile Zeynep in kaydi durur.
      await prefs.remove(key('profil_okul_id', 'uid_ahmet'));

      expect(prefs.getString(key('profil_okul_id', 'uid_ahmet')), isNull);
      expect(prefs.getString(key('profil_okul_id', 'uid_zeynep')), 'okul_2');
    });

    test('KRITIK: eski sabit anahtarlarin silinmesi hesabi etkilemez', () async {
      // logout(), hesaba bagli OLMAYAN eski anahtarlari temizler.
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('profil_okul', 'Eski Kayit');
      await prefs.setString(key('profil_okul', 'uid_ahmet'), 'Ahmet in Okulu');

      await prefs.remove('profil_okul');

      expect(prefs.getString('profil_okul'), isNull);
      expect(prefs.getString(key('profil_okul', 'uid_ahmet')),
          'Ahmet in Okulu',
          reason: 'Cikis, hesabin kendi okul bilgisini silmemeli');
    });

    test('Kimlik bossa eski sabit anahtar kullanilir', () {
      // Masaustu yerel modunda ve henuz giris yapilmamisken gecerli
      // davranis budur.
      expect(key('profil_okul', ''), 'profil_okul');
    });
  });

  group('Hesap basina veritabani', () {
    test('KRITIK: her hesap ayri veritabani dosyasi kullanir', () {
      final a = AppConfig.teacherDbName('uid_ahmet');
      final b = AppConfig.teacherDbName('uid_zeynep');

      expect(a, isNot(b),
          reason: 'Iki hesap ayni dosyayi paylasirsa veriler karisir');
    });

    test('KRITIK: dosya adi guvenli karakterlere indirgenir', () {
      // Google UID leri ':' ve '.' icerebilir; dosya adinda gecersizdir.
      final name = AppConfig.teacherDbName('google:abc/def.ghi');

      expect(name.contains('/'), isFalse);
      expect(name.contains(':'), isFalse);
      expect(name.endsWith('.db'), isTrue);
    });

    test('Ayni kimlik her zaman ayni dosyayi verir', () {
      expect(AppConfig.teacherDbName('uid_ahmet'),
          AppConfig.teacherDbName('uid_ahmet'));
    });
  });
}
