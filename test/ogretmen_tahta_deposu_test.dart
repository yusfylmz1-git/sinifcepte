import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/ogretmen_tahta_deposu.dart';
import 'package:sinifcepte/features/board_config/data/tahta_ogretmen_deposu.dart';
import 'package:sinifcepte/features/board_config/models/okul_config_model.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_totp.dart';

/// Öğretmenin kendi tahta açma bilgisi (öğretmen tarafı).
///
/// ## En değerli test burada
///
/// `kurulum_qr_turu`: idareci tarafı QR üretiyor, öğretmen tarafı onu
/// ayrıştırıyor ve secret'tan kod üretiliyor. İki taraf farklı sınıflar
/// olduğu için biçim uyuşmazlığı sahada "QR okumuyor" diye görünür ve
/// teşhisi zor olur.
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

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (hataVer) throw Exception('depo erişilemiyor');
    return _veri.containsKey(key);
  }

  void hamYaz(String key, String value) => _veri[key] = value;
}

void main() {
  late _BellekDepo depo;
  late OgretmenTahtaDeposu ogretmenDepo;

  setUp(() {
    depo = _BellekDepo();
    ogretmenDepo = OgretmenTahtaDeposu(depo: depo);
  });

  const gecerliYuk = 'SCT1:meb_16_123456:AYILMAZ:A. Yılmaz:GEZDGNBVGY3TQOJQ';

  group('KRİTİK: iki tarafın QR biçimi uyuşuyor', () {
    test('idarecinin ürettiği QR öğretmen tarafında ayrıştırılır', () {
      // İdareci tarafı (TahtaOgretmenDeposu) üretiyor, öğretmen tarafı
      // (OgretmenTahtaDeposu) ayrıştırıyor. Biçim uyuşmazsa sahada
      // "QR okumuyor" diye görünür.
      const ogretmen = PanoOgretmeni(
        kod: 'AYILMAZ',
        ad: 'A. Yılmaz',
        totpSecret: 'GEZDGNBVGY3TQOJQ',
      );

      final uretilen = TahtaOgretmenDeposu.kurulumQrYuku(
        okulId: 'meb_16_1',
        ogretmen: ogretmen,
      );

      final ayristirilan = OgretmenTahtaDeposu.qrAyristir(uretilen);

      expect(ayristirilan, isNotNull);
      expect(ayristirilan!.okulId, 'meb_16_1');
      expect(ayristirilan.kod, 'AYILMAZ');
      // Ad karekodda ASCII'ye katlanıyor (okuyucu kodlama tahmini).
      expect(ayristirilan.ad, 'A. Yilmaz');
      expect(ayristirilan.totpSecret, 'GEZDGNBVGY3TQOJQ');
    });

    test('KRİTİK: ayrıştırılan secret gerçekten kod üretiyor', () {
      // Uçtan uca: idareci ekler → QR → öğretmen kaydeder → kod.
      final kayit = OgretmenTahtaDeposu.qrAyristir(gecerliYuk)!;

      final kod = TahtaTotp.kodUret(
        kayit.totpSecret,
        an: DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000, isUtc: true),
      );

      expect(kod.length, 6);
      expect(RegExp(r'^\d{6}$').hasMatch(kod), isTrue);
    });

    test('gerçek üretilmiş secret ile tur kapanıyor', () {
      // Sabit secret yerine gerçekten üretilmiş olanla.
      final secret = TahtaTotp.secretUret();
      const kod = 'BDEMIR';

      final yuk = TahtaOgretmenDeposu.kurulumQrYuku(
        okulId: 'meb_34_9',
        ogretmen: PanoOgretmeni(kod: kod, ad: 'B. Demir', totpSecret: secret),
      );

      final kayit = OgretmenTahtaDeposu.qrAyristir(yuk)!;
      expect(kayit.totpSecret, secret);
      expect(TahtaTotp.kodUret(kayit.totpSecret).length, 6);
    });
  });

  group('QR ayrıştırma — geçersiz girdiler', () {
    test('KRİTİK: tahtanın QR\'ı kurulum olarak kabul edilmez', () {
      // Öğretmen yanlış QR'ı okutursa sebebi söylenmeli; sessizce
      // başarısız olmak defalarca denemeye yol açar.
      const tahtaninQri = 'SC1:meb_16_1:tahta_8B:nonce:29218';
      expect(OgretmenTahtaDeposu.qrAyristir(tahtaninQri), isNull);
    });

    test('yanlış önek reddedilir', () {
      expect(
        OgretmenTahtaDeposu.qrAyristir('XXX1:okul:kod:ad:secret'),
        isNull,
      );
    });

    test('eksik alan reddedilir', () {
      expect(OgretmenTahtaDeposu.qrAyristir('SCT1:okul:kod:ad'), isNull);
    });

    test('fazla alan reddedilir', () {
      expect(
        OgretmenTahtaDeposu.qrAyristir('SCT1:okul:kod:ad:secret:fazla'),
        isNull,
      );
    });

    test('boş okul kimliği reddedilir', () {
      expect(OgretmenTahtaDeposu.qrAyristir('SCT1::kod:ad:secret'), isNull);
    });

    test('boş kod reddedilir', () {
      expect(OgretmenTahtaDeposu.qrAyristir('SCT1:okul::ad:secret'), isNull);
    });

    test('KRİTİK: boş secret reddedilir', () {
      // Secret'sız kayıt hiç kod üretemez; kaydetmek anlamsız.
      expect(OgretmenTahtaDeposu.qrAyristir('SCT1:okul:kod:ad:'), isNull);
    });

    test('boş ad kabul edilir (kod yeterli)', () {
      final kayit = OgretmenTahtaDeposu.qrAyristir('SCT1:okul:KOD::secret');
      expect(kayit, isNotNull);
      expect(kayit!.ad, isEmpty);
    });

    test('alakasız metin reddedilir', () {
      expect(OgretmenTahtaDeposu.qrAyristir('https://ornek.com'), isNull);
      expect(OgretmenTahtaDeposu.qrAyristir(''), isNull);
    });

    test('baştaki/sondaki boşluk tolere edilir', () {
      expect(OgretmenTahtaDeposu.qrAyristir('  $gecerliYuk  '), isNotNull);
    });
  });

  group('Kaydetme ve okuma', () {
    test('kayıt saklanır ve geri okunur', () async {
      final kaydedilen = await ogretmenDepo.qrIleKaydet(gecerliYuk);

      expect(kaydedilen, isNotNull);
      expect(await ogretmenDepo.kayitliMi(), isTrue);

      final okunan = await ogretmenDepo.oku();
      expect(okunan!.kod, 'AYILMAZ');
      expect(okunan.okulId, 'meb_16_123456');
      expect(okunan.totpSecret, 'GEZDGNBVGY3TQOJQ');
    });

    test('Türkçe ad bozulmadan saklanır', () async {
      await ogretmenDepo.qrIleKaydet(
        'SCT1:meb_16_1:SUKRU:Şükrü Çağlayan:GEZDGNBVGY3TQOJQ',
      );

      final okunan = await ogretmenDepo.oku();
      expect(okunan!.ad, 'Şükrü Çağlayan');
    });

    test('geçersiz QR kaydedilmez', () async {
      expect(await ogretmenDepo.qrIleKaydet('SC1:a:b:c:d'), isNull);
      expect(await ogretmenDepo.kayitliMi(), isFalse);
    });

    test('ikinci kayıt öncekini değiştirir', () async {
      // Öğretmen okul değiştirdi veya secret yenilendi.
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      await ogretmenDepo.qrIleKaydet(
        'SCT1:meb_34_9:BDEMIR:B. Demir:MFRGGZDFMZTWQ2LK',
      );

      final okunan = await ogretmenDepo.oku();
      expect(okunan!.kod, 'BDEMIR');
      expect(okunan.okulId, 'meb_34_9');
    });

    test('kayıt yokken oku null döner', () async {
      expect(await ogretmenDepo.oku(), isNull);
      expect(await ogretmenDepo.kayitliMi(), isFalse);
    });

    test('kayıt silinir', () async {
      await ogretmenDepo.qrIleKaydet(gecerliYuk);

      expect(await ogretmenDepo.sil(), isTrue);
      expect(await ogretmenDepo.oku(), isNull);
    });
  });

  group('Bozuk kayıt', () {
    test('bozuk JSON çökmez', () async {
      depo.hamYaz('ogretmen_tahta_kaydi_v1', '{bu json degil');
      expect(await ogretmenDepo.oku(), isNull);
    });

    test('KRİTİK: secret\'i olmayan kayıt null döner', () async {
      // Kod üretilemeyeceği için kayıt işe yaramaz; "kayıtlıyım ama
      // çalışmıyor" durumundansa hiç kayıtlı olmamak iyidir.
      depo.hamYaz(
        'ogretmen_tahta_kaydi_v1',
        '{"okulId":"o","kod":"K","ad":"A","totpSecret":""}',
      );
      expect(await ogretmenDepo.oku(), isNull);
    });

    test('kodu olmayan kayıt null döner', () async {
      depo.hamYaz(
        'ogretmen_tahta_kaydi_v1',
        '{"okulId":"o","kod":"","ad":"A","totpSecret":"S"}',
      );
      expect(await ogretmenDepo.oku(), isNull);
    });

    test('liste gelirse null döner', () async {
      depo.hamYaz('ogretmen_tahta_kaydi_v1', '[]');
      expect(await ogretmenDepo.oku(), isNull);
    });

    test('depo hatası çökmez', () async {
      depo.hataVer = true;

      expect(await ogretmenDepo.kayitliMi(), isFalse);
      expect(await ogretmenDepo.oku(), isNull);
      expect(await ogretmenDepo.qrIleKaydet(gecerliYuk), isNull);
    });
  });

  group('Okul eşleşmesi', () {
    test('KRİTİK: başka okulun tahtası fark edilir', () async {
      // Öğretmen komşu okulun tahtasının QR'ını tararsa, sessizce
      // çalışmayan kod üretmek yerine sebep söylenmeli.
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      final kayit = await ogretmenDepo.oku();

      final tahtaYuku = TahtaTotp.qrAyristir(
        'SC1:meb_34_999:tahta_1:nonce:29218',
      )!;

      expect(tahtaYuku.ayniOkul(kayit!.okulId), isFalse);
    });

    test('kendi okulunun tahtası eşleşir', () async {
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      final kayit = await ogretmenDepo.oku();

      final tahtaYuku = TahtaTotp.qrAyristir(
        'SC1:meb_16_123456:tahta_1:nonce:29218',
      )!;

      expect(tahtaYuku.ayniOkul(kayit!.okulId), isTrue);
    });
  });
}
