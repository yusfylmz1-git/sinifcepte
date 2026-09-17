import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/tahta_ogretmen_deposu.dart';
import 'package:sinifcepte/features/board_config/models/okul_config_model.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_totp.dart';

/// Tahta açma yetkisi olan öğretmenlerin listesi (idareci tarafı).
///
/// ## Bu testin yakaladığı asıl risk
///
/// `okul_config` bir süre **boş öğretmen listesiyle** üretiliyordu:
/// `PanoOgretmeni` yalnızca modelde tanımlıydı, hiçbir yerde
/// doldurulmuyordu. O dosyayla kurulan tahtada hiç kimse TOTP veya PIN
/// ile kilidi açamazdı. Bu depo o boşluğu kapatıyor.
///
/// Gerçek güvenli depo yerine bellek taklidi kullanılıyor: Keystore/
/// Keychain platform kanalı istiyor ve birim testinde yok.
class _BellekDepo extends FlutterSecureStorage {
  _BellekDepo() : super();

  final Map<String, String> _veri = {};
  bool hataVer = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (hataVer) throw Exception('depo erişilemiyor');
    return _veri[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (hataVer) throw Exception('depo erişilemiyor');
    if (value == null) {
      _veri.remove(key);
    } else {
      _veri[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (hataVer) throw Exception('depo erişilemiyor');
    _veri.remove(key);
  }

  /// Bozuk kayıt senaryosu için doğrudan yazma.
  void hamYaz(String key, String value) => _veri[key] = value;
}

void main() {
  late _BellekDepo depo;
  late TahtaOgretmenDeposu ogretmenler;

  setUp(() {
    depo = _BellekDepo();
    ogretmenler = TahtaOgretmenDeposu(depo: depo);
  });

  group('Öğretmen ekleme', () {
    test('ilk öğretmen eklenir ve secret üretilir', () async {
      final kayit = await ogretmenler.ekle(ad: 'A. Yılmaz');

      expect(kayit, isNotNull);
      expect(kayit!.ad, 'A. Yılmaz');
      expect(kayit.totpSecret, isNotEmpty);
      expect((await ogretmenler.oku()).length, 1);
    });

    test('KRİTİK: üretilen secret gerçekten kod üretebiliyor', () async {
      // Secret bozuksa idareci öğretmeni ekler, öğretmen QR'ı okutur
      // ama hiç kod üretemez — sahada teşhisi zor.
      final kayit = await ogretmenler.ekle(ad: 'B. Demir');

      final kod = TahtaTotp.kodUret(
        kayit!.totpSecret,
        an: DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000, isUtc: true),
      );

      expect(kod.length, 6);
    });

    test('boş ad reddedilir', () async {
      expect(await ogretmenler.ekle(ad: '   '), isNull);
      expect(await ogretmenler.oku(), isEmpty);
    });

    test('KRİTİK: her öğretmen farklı secret alır', () async {
      final a = await ogretmenler.ekle(ad: 'A. Yılmaz');
      final b = await ogretmenler.ekle(ad: 'B. Demir');

      expect(a!.totpSecret, isNot(b!.totpSecret));
    });

    test('KRİTİK: aynı kod ikinci kez eklenemez', () async {
      // Mevcut öğretmenin secret'ını kazara değiştirmek, onun
      // telefonundaki kaydı geçersiz kılar ve sebebi anlaşılmaz.
      await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'OGR001');
      final ikinci = await ogretmenler.ekle(ad: 'Başkası', kod: 'OGR001');

      expect(ikinci, isNull);
      expect((await ogretmenler.oku()).length, 1);
    });

    test('elle verilen kod büyük harfe çevrilir', () async {
      final kayit = await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'ogr001');
      expect(kayit!.kod, 'OGR001');
    });
  });

  group('Kod türetme — tahta klavyesinde Türkçe düzen olmayabilir', () {
    test('KRİTİK: Türkçe harfler ASCII\'ye iner', () async {
      final kayit = await ogretmenler.ekle(ad: 'Şükrü Çağlayan');

      // Ş→S, ü→U, ç→C, ğ→G olmalı; kod tahtada elle giriliyor.
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(kayit!.kod), isTrue);
      expect(kayit.kod, contains('SUKRU'));
    });

    test('İ harfi tuzağı', () async {
      // Türkçe'de 'İ'.toLowerCase() bozuk sonuç verir; trFold bunu
      // doğru ele alıyor.
      final kayit = await ogretmenler.ekle(ad: 'İbrahim Işık');

      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(kayit!.kod), isTrue);
      expect(kayit.kod, startsWith('IBRAHIM'));
    });

    test('noktalama atılır', () async {
      final kayit = await ogretmenler.ekle(ad: 'A. Yılmaz-Demir');
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(kayit!.kod), isTrue);
    });

    test('kod 10 karakterle sınırlı', () async {
      final kayit = await ogretmenler.ekle(
        ad: 'Abdurrahman Muhammedoglu Uzunisimli',
      );
      // Sayı eklenirse biraz uzayabilir ama makul kalmalı.
      expect(kayit!.kod.length, lessThanOrEqualTo(12));
    });

    test('KRİTİK: aynı isimde iki öğretmen çakışmaz', () async {
      final a = await ogretmenler.ekle(ad: 'Ali Veli');
      final b = await ogretmenler.ekle(ad: 'Ali Veli');

      expect(b, isNotNull);
      expect(b!.kod, isNot(a!.kod));
      expect((await ogretmenler.oku()).length, 2);
    });
  });

  group('Silme ve yenileme', () {
    test('öğretmen silinir', () async {
      final kayit = await ogretmenler.ekle(ad: 'A. Yılmaz');

      expect(await ogretmenler.sil(kayit!.kod), isTrue);
      expect(await ogretmenler.oku(), isEmpty);
    });

    test('olmayan kod silinmez', () async {
      expect(await ogretmenler.sil('YOK999'), isFalse);
    });

    test('silme büyük/küçük harf duyarsız', () async {
      await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'OGR001');
      expect(await ogretmenler.sil('ogr001'), isTrue);
    });

    test('secret yenilenince değişir, kod ve ad korunur', () async {
      final eski = await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'OGR001');

      final yeni = await ogretmenler.secretYenile('OGR001');

      expect(yeni, isNotNull);
      expect(yeni!.kod, eski!.kod);
      expect(yeni.ad, eski.ad);
      expect(yeni.totpSecret, isNot(eski.totpSecret));
    });

    test('olmayan öğretmenin secret\'i yenilenmez', () async {
      expect(await ogretmenler.secretYenile('YOK999'), isNull);
    });

    test('temizle hepsini siler', () async {
      await ogretmenler.ekle(ad: 'A. Yılmaz');
      await ogretmenler.ekle(ad: 'B. Demir');

      expect(await ogretmenler.temizle(), isTrue);
      expect(await ogretmenler.oku(), isEmpty);
    });
  });

  group('Kalıcılık ve bozuk kayıt', () {
    test('kayıtlar geri okunur', () async {
      await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'OGR001');
      await ogretmenler.ekle(ad: 'B. Demir', kod: 'OGR002');

      final liste = await ogretmenler.oku();

      expect(liste.length, 2);
      expect(liste.map((o) => o.kod), containsAll(['OGR001', 'OGR002']));
      expect(liste.every((o) => o.totpSecret.isNotEmpty), isTrue);
    });

    test('bozuk JSON çökmez, boş liste döner', () async {
      depo.hamYaz('tahta_ogretmenleri_v1', '{bu json degil');
      expect(await ogretmenler.oku(), isEmpty);
    });

    test('liste yerine nesne gelirse boş döner', () async {
      depo.hamYaz('tahta_ogretmenleri_v1', '{"kod":"X"}');
      expect(await ogretmenler.oku(), isEmpty);
    });

    test('kodsuz kayıtlar süzülür', () async {
      depo.hamYaz(
        'tahta_ogretmenleri_v1',
        '[{"kod":"","ad":"Kodsuz"},{"kod":"OGR001","ad":"Geçerli"}]',
      );

      final liste = await ogretmenler.oku();
      expect(liste.length, 1);
      expect(liste.first.kod, 'OGR001');
    });

    test('depo hatası çökmez', () async {
      depo.hataVer = true;

      expect(await ogretmenler.oku(), isEmpty);
      expect(await ogretmenler.ekle(ad: 'A. Yılmaz'), isNull);
    });
  });

  group('Kurulum QR yükü', () {
    test('biçim doğru', () {
      const ogretmen = PanoOgretmeni(
        kod: 'OGR001',
        ad: 'A. Yılmaz',
        totpSecret: 'GEZDGNBVGY3TQOJQ',
      );

      final yuk = TahtaOgretmenDeposu.kurulumQrYuku(
        okulId: 'meb_16_1',
        ogretmen: ogretmen,
      );

      expect(yuk, 'SCT1:meb_16_1:OGR001:A. Yılmaz:GEZDGNBVGY3TQOJQ');
    });

    test('KRİTİK: önek tahtanın QR\'ından farklı', () {
      // `SC1` tahtadan telefona kilit açma isteği taşır; `SCT1`
      // idareciden öğretmene kurulum bilgisi. Aynı önek olsaydı iki
      // akış karışır ve öğretmen anlamsız hata görürdü.
      const ogretmen = PanoOgretmeni(kod: 'K', ad: 'A', totpSecret: 'S');
      final yuk = TahtaOgretmenDeposu.kurulumQrYuku(
        okulId: 'o',
        ogretmen: ogretmen,
      );

      expect(yuk, startsWith('SCT1:'));
      expect(TahtaTotp.qrAyristir(yuk), isNull);
    });

    test('addaki iki nokta ayırıcıyı bozmaz', () async {
      const ogretmen = PanoOgretmeni(
        kod: 'OGR001',
        ad: 'A: Yılmaz: Test',
        totpSecret: 'SECRET',
      );

      final yuk = TahtaOgretmenDeposu.kurulumQrYuku(
        okulId: 'meb_16_1',
        ogretmen: ogretmen,
      );

      // 5 alan olmalı: SCT1, okul, kod, ad, secret
      expect(yuk.split(':').length, 5);
      expect(yuk.split(':').last, 'SECRET');
    });
  });
}
