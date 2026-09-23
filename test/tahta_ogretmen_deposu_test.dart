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

  /// Platform kanalına kaç kez gidildi.
  ///
  /// Gerçek cihazda her tur Keystore'a iniyor ve yavaş Keystore'lu
  /// telefonlarda ~340 ms sürüyor (ölçüldü: Redmi/MediaTek,
  /// `Slow Binder: BpBinder transact took 339 ms`). Sayı önemli:
  /// üç tur ANR eşiğini (5 sn) aşıp "uygulama yanıt vermiyor"
  /// veriyordu.
  int okumaSayisi = 0;
  int yazmaSayisi = 0;

  void sayaclariSifirla() {
    okumaSayisi = 0;
    yazmaSayisi = 0;
  }

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
    okumaSayisi++;
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
    yazmaSayisi++;
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
      final kayit = (await ogretmenler.ekle(ad: 'A. Yılmaz')).kayit;

      expect(kayit, isNotNull);
      expect(kayit!.ad, 'A. Yılmaz');
      expect(kayit.totpSecret, isNotEmpty);
      expect((await ogretmenler.oku()).length, 1);
    });

    test('KRİTİK: üretilen secret gerçekten kod üretebiliyor', () async {
      // Secret bozuksa idareci öğretmeni ekler, öğretmen QR'ı okutur
      // ama hiç kod üretemez — sahada teşhisi zor.
      final kayit = (await ogretmenler.ekle(ad: 'B. Demir')).kayit;

      final kod = TahtaTotp.kodUret(
        kayit!.totpSecret,
        an: DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000, isUtc: true),
      );

      expect(kod.length, 6);
    });

    test('boş ad reddedilir ve sebebini söyler', () async {
      final sonuc = await ogretmenler.ekle(ad: '   ');
      expect(sonuc.basarili, isFalse);
      expect(sonuc.kayit, isNull);
      // Arayüz artık sebebi tahmin etmiyor, depo söylüyor.
      expect(sonuc.hata, isNotNull);
      expect(await ogretmenler.oku(), isEmpty);
    });

    test('KRİTİK: her öğretmen farklı secret alır', () async {
      final a = (await ogretmenler.ekle(ad: 'A. Yılmaz')).kayit;
      final b = (await ogretmenler.ekle(ad: 'B. Demir')).kayit;

      expect(a!.totpSecret, isNot(b!.totpSecret));
    });

    test('KRİTİK: aynı kod ikinci kez eklenemez', () async {
      // Mevcut öğretmenin secret'ını kazara değiştirmek, onun
      // telefonundaki kaydı geçersiz kılar ve sebebi anlaşılmaz.
      await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'OGR001');
      final ikinci = (await ogretmenler.ekle(ad: 'Başkası', kod: 'OGR001')).kayit;

      expect(ikinci, isNull);
      expect((await ogretmenler.oku()).length, 1);
    });

    test('elle verilen kod büyük harfe çevrilir', () async {
      final kayit = (await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'ogr001')).kayit;
      expect(kayit!.kod, 'OGR001');
    });
  });

  group('Kod kuralı — ad baş harfi + soyad', () {
    // Bu grup kullanıcı itirazından doğdu (18 Eylül 2026):
    // *"neden YUSUFYILMA olarak kaldı, mantıklı bir kod
    // üretilemez mi?"*
    //
    // İlk sürüm tüm adı birleştirip 10 karaktere kesiyordu:
    //   Yusuf YILMAZ → YUSUFYILMAZ → YUSUFYILMA  (ortadan kopuk)
    //
    // Baş harf + soyad okulun günlük dilinde de böyle: "Y. Yılmaz".

    test('KRİTİK: tam ad verilince kelime ortasından KESİLMİYOR', () {
      expect(TahtaOgretmenDeposu.kodTuret('Yusuf YILMAZ'), 'YYILMAZ');
    });

    test('kısaltmalı ad da aynı sonucu veriyor', () {
      // Bu zaten çalışıyordu; kural değişikliği bozmamalı.
      expect(TahtaOgretmenDeposu.kodTuret('A. Yılmaz'), 'AYILMAZ');
    });

    test('orta ad baş harfe inmiyor, atlanıyor', () {
      // "ANCAGLAYAN" kodu uzatır ve tahtada yazmayı zorlaştırır.
      expect(
        TahtaOgretmenDeposu.kodTuret('Ayşe Nur Çağlayan'),
        'ACAGLAYAN',
      );
    });

    test('tek kelime olduğu gibi kalıyor', () {
      expect(TahtaOgretmenDeposu.kodTuret('Madonna'), 'MADONNA');
    });

    test('uzun soyad 12 karakterde sınırlanıyor', () {
      final kod = TahtaOgretmenDeposu.kodTuret('Ali Abdurrahmanoglulari');
      expect(kod.length, lessThanOrEqualTo(12));
      expect(kod, startsWith('AABDURRAHMA'));
    });

    test('KRİTİK: Türkçe harfler ASCII\'ye iniyor', () {
      // Tahtanın klavyesinde Türkçe düzen olmayabilir.
      expect(TahtaOgretmenDeposu.kodTuret('Şükrü Çağlayan'), 'SCAGLAYAN');
      expect(TahtaOgretmenDeposu.kodTuret('İbrahim Işık'), 'IISIK');
      expect(TahtaOgretmenDeposu.kodTuret('Ömer Güngör'), 'OGUNGOR');
    });

    test('boş ad OGR veriyor', () {
      expect(TahtaOgretmenDeposu.kodTuret(''), 'OGR');
      expect(TahtaOgretmenDeposu.kodTuret('   '), 'OGR');
      expect(TahtaOgretmenDeposu.kodTuret('...'), 'OGR');
    });

    test('kod yalnızca A-Z0-9 içeriyor', () {
      for (final ad in [
        'Yusuf YILMAZ',
        'A. Yılmaz-Demir',
        'Şükrü Çağlayan',
        'İbrahim Işık',
        "Ayşe'nin Oğlu",
      ]) {
        final kod = TahtaOgretmenDeposu.kodTuret(ad);
        expect(
          RegExp(r'^[A-Z0-9]+$').hasMatch(kod),
          isTrue,
          reason: '$ad → $kod',
        );
      }
    });

    test('KRİTİK: aynı soyadlı iki öğretmen çakışmıyor', () async {
      // Kardeş, eş — gerçek bir durum.
      final a = (await ogretmenler.ekle(ad: 'Ali YILMAZ')).kayit;
      final b = (await ogretmenler.ekle(ad: 'Ayşe YILMAZ')).kayit;

      expect(a!.kod, 'AYILMAZ');
      expect(b!.kod, isNot('AYILMAZ'));
      expect(b.kod, 'AYILMAZ2');
    });
  });

  group('Kod türetme — tahta klavyesinde Türkçe düzen olmayabilir', () {
    test('KRİTİK: Türkçe harfler ASCII\'ye iner', () async {
      final kayit = (await ogretmenler.ekle(ad: 'Şükrü Çağlayan')).kayit;

      // Ş→S, ç→C, ğ→G olmalı; kod tahtada elle giriliyor.
      //
      // Kural ad baş harfi + soyad: "Şükrü Çağlayan" → "SCAGLAYAN".
      // Bu test bir dönem `contains('SUKRU')` bekliyordu — o, tüm adı
      // birleştiren eski kuraldı ve `YUSUFYILMA` gibi ortadan kopuk
      // kodlar üretiyordu.
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(kayit!.kod), isTrue);
      expect(kayit.kod, 'SCAGLAYAN');
    });

    test('İ harfi tuzağı', () async {
      // Türkçe'de 'İ'.toLowerCase() bozuk sonuç verir; trFold bunu
      // doğru ele alıyor.
      final kayit = (await ogretmenler.ekle(ad: 'İbrahim Işık')).kayit;

      // 'İ' ve 'ı' ikisi de ASCII'ye inmeli: "İbrahim Işık" → "IISIK".
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(kayit!.kod), isTrue);
      expect(kayit.kod, 'IISIK');
    });

    test('noktalama atılır', () async {
      final kayit = (await ogretmenler.ekle(ad: 'A. Yılmaz-Demir')).kayit;
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(kayit!.kod), isTrue);
    });

    test('kod 10 karakterle sınırlı', () async {
      final kayit = (await ogretmenler.ekle(
        ad: 'Abdurrahman Muhammedoglu Uzunisimli',
      )).kayit;
      // Sayı eklenirse biraz uzayabilir ama makul kalmalı.
      expect(kayit!.kod.length, lessThanOrEqualTo(12));
    });

    test('KRİTİK: aynı isimde iki öğretmen çakışmaz', () async {
      final a = (await ogretmenler.ekle(ad: 'Ali Veli')).kayit;
      final b = (await ogretmenler.ekle(ad: 'Ali Veli')).kayit;

      expect(b, isNotNull);
      expect(b!.kod, isNot(a!.kod));
      expect((await ogretmenler.oku()).length, 2);
    });
  });

  group('Silme ve yenileme', () {
    test('öğretmen silinir', () async {
      final kayit = (await ogretmenler.ekle(ad: 'A. Yılmaz')).kayit;

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
      final eski = (await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'OGR001')).kayit;

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

      final sonuc = await ogretmenler.ekle(ad: 'A. Yılmaz');
      expect(sonuc.basarili, isFalse);
      // Depo yazamadığında sebep "aynı kod var" DEĞİL. Arayüz eskiden
      // bunu tahmin ediyordu ve idareci yanlış yere bakıyordu.
      expect(sonuc.hata, contains('yazılamadı'));
    });
  });

  group('Güvenli depo turu sayısı — ANR koruması', () {
    late _BellekDepo depo;
    late TahtaOgretmenDeposu ogretmenler;

    setUp(() {
      depo = _BellekDepo();
      ogretmenler = TahtaOgretmenDeposu(depo: depo);
    });

    test('KRİTİK: ekleme en fazla bir okuma + bir yazma yapıyor', () async {
      depo.sayaclariSifirla();
      final sonuc = await ogretmenler.ekle(ad: 'A. Yılmaz');

      expect(sonuc.basarili, isTrue);

      // Gerçek cihazda her tur Keystore'a iniyor (~340 ms ölçüldü).
      // Arayüz eskiden ekledikten sonra listeyi YENİDEN okuyordu ve
      // toplam üç tur ANR eşiğini aşıyordu:
      //   ANR in com.sinifcepte.sinifcepte
      //   Reason: Input dispatching timed out (Waited 5000ms)
      //
      // Bu yüzden `ekle()` güncel listeyi kendisi döndürüyor;
      // çağıranın üçüncü tura ihtiyacı yok.
      expect(depo.okumaSayisi, 1, reason: 'fazladan okuma turu var');
      expect(depo.yazmaSayisi, 1, reason: 'fazladan yazma turu var');
    });

    test('KRİTİK: dönen liste eklenen kaydı içeriyor', () async {
      // Bu, üçüncü turu gereksiz kılan şey. Liste dönmezse çağıran
      // taraf depoyu yeniden okumak zorunda kalır ve ANR geri gelir.
      final sonuc = await ogretmenler.ekle(ad: 'A. Yılmaz');

      expect(sonuc.liste, hasLength(1));
      expect(sonuc.liste.first.kod, sonuc.kayit!.kod);
      expect(sonuc.liste.first.totpSecret, sonuc.kayit!.totpSecret);
    });

    test('dönen liste önceki kayıtları da taşıyor', () async {
      await ogretmenler.ekle(ad: 'A. Yılmaz');
      final sonuc = await ogretmenler.ekle(ad: 'B. Demir');

      expect(sonuc.liste, hasLength(2));
    });

    test('başarısız eklemede liste kaybolmuyor', () async {
      await ogretmenler.ekle(ad: 'A. Yılmaz', kod: 'OGR001');

      // Aynı kod: eklenmez ama arayüz elindeki listeyi kaybetmemeli.
      final sonuc = await ogretmenler.ekle(ad: 'Başkası', kod: 'OGR001');

      expect(sonuc.basarili, isFalse);
      expect(sonuc.liste, hasLength(1));
      expect(sonuc.liste.first.ad, 'A. Yılmaz');
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

      // Ad ASCII: karekod okuyucusu UTF-8'i başka kodlama sanabiliyor.
      expect(yuk, 'SCT1:meb_16_1:OGR001:A. Yilmaz:GEZDGNBVGY3TQOJQ');
    });

    test('KRİTİK: Türkçe ad karekod yükünü ASCII dışına çıkarmıyor', () {
      // `ş`/`ç` ile biten ad: ikinci bayt Shift-JIS'te ':' ayırıcısını
      // yutabiliyordu.
      const ogretmen = PanoOgretmeni(
        kod: 'BKOC',
        ad: 'Barış Koç',
        totpSecret: 'GEZDGNBVGY3TQOJQ',
      );

      final yuk = TahtaOgretmenDeposu.kurulumQrYuku(
        okulId: 'meb_16_1',
        ogretmen: ogretmen,
      );

      expect(yuk.runes.every((r) => r < 128), isTrue, reason: yuk);
      expect(yuk.split(':')[3], 'Baris Koc');
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
