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

  /// Yalnızca OKUMA düşer (Keystore anlık hatası); yazma çalışır.
  bool okumaHatasi = false;

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
    if (hataVer || okumaHatasi) throw Exception('depo erişilemiyor');
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
  String? hamOku(String key) => _veri[key];
}

const _v1 = 'ogretmen_tahta_kaydi_v1';
const _v2 = 'ogretmen_tahta_kayitlari_v2';

void main() {
  late _BellekDepo depo;
  late OgretmenTahtaDeposu ogretmenDepo;

  setUp(() {
    depo = _BellekDepo();
    ogretmenDepo = OgretmenTahtaDeposu(depo: depo);
  });

  const gecerliYuk = 'SCT1:meb_16_123456:AYILMAZ:A. Yılmaz:GEZDGNBVGY3TQOJQ';
  const ikinciOkul = 'SCT1:meb_34_9:BDEMIR:B. Demir:MFRGGZDFMZTWQ2LK';

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

    test('altıncı alan okul adı; yedinci alan reddedilir', () {
      final k = OgretmenTahtaDeposu.qrAyristir('SCT1:okul:kod:ad:secret:Okul Adi');
      expect(k!.okulAdi, 'Okul Adi');
      expect(k.totpSecret, 'secret');
      expect(
        OgretmenTahtaDeposu.qrAyristir('SCT1:okul:kod:ad:secret:okul:fazla'),
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
      expect(OgretmenTahtaDeposu.qrAyristir('SCT1:okul:kod:ad::Okul'), isNull);
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

      final okunan = (await ogretmenDepo.tumu()).single;
      expect(okunan.kod, 'AYILMAZ');
      expect(okunan.okulId, 'meb_16_123456');
      expect(okunan.totpSecret, 'GEZDGNBVGY3TQOJQ');
    });

    test('Türkçe ad bozulmadan saklanır', () async {
      await ogretmenDepo.qrIleKaydet(
        'SCT1:meb_16_1:SUKRU:Şükrü Çağlayan:GEZDGNBVGY3TQOJQ',
      );

      final okunan = (await ogretmenDepo.tumu()).single;
      expect(okunan.ad, 'Şükrü Çağlayan');
    });

    test('geçersiz QR kaydedilmez', () async {
      expect(await ogretmenDepo.qrIleKaydet('SC1:a:b:c:d'), isNull);
      expect(await ogretmenDepo.kayitliMi(), isFalse);
    });

    test('KRİTİK: başka okulun karekodu EKLENİR, öncekinin yerine geçmez', () async {
      // İki okulda ders veren öğretmen (görevlendirme, ücretli): ilk
      // sürümde ikinci okul birincinin üzerine yazılıyordu.
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      await ogretmenDepo.qrIleKaydet(ikinciOkul);

      final liste = await ogretmenDepo.tumu();
      expect(liste.map((k) => k.okulId), ['meb_16_123456', 'meb_34_9']);
      expect(liste.map((k) => k.kod), ['AYILMAZ', 'BDEMIR']);
    });

    test('KRİTİK: aynı okulun yeni karekodu o okulun kaydının yerine geçer', () async {
      // Secret yenilendi: eski secret'la kod üretmeye devam etmemeli.
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      await ogretmenDepo.qrIleKaydet(ikinciOkul);
      await ogretmenDepo.qrIleKaydet(
        'SCT1:meb_16_123456:AYILMAZ:A. Yılmaz:KRSXG5CTMVRXEZLU',
      );

      final liste = await ogretmenDepo.tumu();
      expect(liste, hasLength(2));
      final ilk = liste.firstWhere((k) => k.okulId == 'meb_16_123456');
      expect(ilk.totpSecret, 'KRSXG5CTMVRXEZLU');
    });

    test('KRİTİK: okuma hatasında yazılmaz (öbür okullar silinmesin)', () async {
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      await ogretmenDepo.qrIleKaydet(ikinciOkul);
      final once = depo.hamOku(_v2);

      depo.okumaHatasi = true;
      final sonuc = await ogretmenDepo.qrIleKaydet(
        'SCT1:meb_06_1:CKAYA:C. Kaya:GEZDGNBVGY3TQOJQ',
      );
      expect(sonuc, isNull);
      expect(await ogretmenDepo.sil('meb_16_123456'), isFalse);
      expect(depo.hamOku(_v2), once);
    });

    test('kayıt yokken liste boş', () async {
      expect(await ogretmenDepo.tumu(), isEmpty);
      expect(await ogretmenDepo.kayitliMi(), isFalse);
    });

    test('bir okul silinir, öbürü kalır', () async {
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      await ogretmenDepo.qrIleKaydet(ikinciOkul);

      expect(await ogretmenDepo.sil('meb_16_123456'), isTrue);
      expect((await ogretmenDepo.tumu()).single.okulId, 'meb_34_9');

      expect(await ogretmenDepo.sil('meb_34_9'), isTrue);
      expect(await ogretmenDepo.tumu(), isEmpty);
    });

    test('okul adı (Ana Program, 6. alan) saklanır ve gösterilir', () async {
      await ogretmenDepo.qrIleKaydet(
        'SCT1:meb_775214:YYILMAZ:Yusuf Yilmaz:KRSXG5CTMVRXEZLU:Mimar Sinan Ortaokulu',
      );
      final k = (await ogretmenDepo.tumu()).single;
      expect(k.okulAdi, 'Mimar Sinan Ortaokulu');
      expect(k.okulGorunenAdi, 'Mimar Sinan Ortaokulu');
      expect(k.totpSecret, 'KRSXG5CTMVRXEZLU');
    });

    test('okul adı yoksa kurum kodu gösterilir', () async {
      await ogretmenDepo.qrIleKaydet('SCT1:meb_775214:K:A:S');
      expect((await ogretmenDepo.tumu()).single.okulGorunenAdi,
          'Kurum kodu 775214');
    });
  });

  group('Eski tek kayıttan taşıma', () {
    const eskiJson = '{"okulId":"meb_16_123456","kod":"YUSUFYILMA",'
        '"ad":"Yusuf YILMAZ","totpSecret":"GEZDGNBVGY3TQOJQ"}';

    test('KRİTİK: güncellemeden önceki kayıt kaybolmuyor', () async {
      // Telefonda kurulu öğretmen uygulama güncellenince yeniden
      // karekod okutmak zorunda kalmamalı.
      depo.hamYaz(_v1, eskiJson);

      expect((await ogretmenDepo.tumu()).single.kod, 'YUSUFYILMA');
      expect(depo.hamOku(_v1), isNull);
      expect(depo.hamOku(_v2), isNotNull);
      expect((await ogretmenDepo.tumu()).single.kod, 'YUSUFYILMA');
    });

    test('taşınan kaydın yanına ikinci okul eklenir', () async {
      depo.hamYaz(_v1, eskiJson);
      await ogretmenDepo.qrIleKaydet(
        'SCT1:meb_775214:YYILMAZ:Yusuf Yilmaz:KRSXG5CTMVRXEZLU:Mimar Sinan Ortaokulu',
      );
      expect((await ogretmenDepo.tumu()).map((k) => k.okulId),
          ['meb_16_123456', 'meb_775214']);
    });

    test('silinen taşınmış okul geri gelmiyor', () async {
      depo.hamYaz(_v1, eskiJson);
      expect(await ogretmenDepo.sil('meb_16_123456'), isTrue);
      expect(await ogretmenDepo.tumu(), isEmpty);
    });
  });

  group('Bozuk kayıt', () {
    test('bozuk JSON çökmez', () async {
      depo.hamYaz(_v2, '{bu json degil');
      expect(await ogretmenDepo.tumu(), isEmpty);
      depo.hamYaz(_v2, '');
      depo.hamYaz(_v1, '{bu json degil');
      expect(await ogretmenDepo.tumu(), isEmpty);
    });

    test('KRİTİK: secret\'i olmayan kayıt listeye girmez', () async {
      // Kod üretilemeyeceği için kayıt işe yaramaz; "kayıtlıyım ama
      // çalışmıyor" durumundansa hiç kayıtlı olmamak iyidir.
      depo.hamYaz(
        _v2,
        '[{"okulId":"o","kod":"K","ad":"A","totpSecret":""},'
            '{"okulId":"p","kod":"K","ad":"A","totpSecret":"S"}]',
      );
      expect((await ogretmenDepo.tumu()).single.okulId, 'p');
    });

    test('kodu olmayan eski kayıt taşınmaz', () async {
      depo.hamYaz(_v1, '{"okulId":"o","kod":"","ad":"A","totpSecret":"S"}');
      expect(await ogretmenDepo.tumu(), isEmpty);
    });

    test('liste yerine nesne gelirse boş', () async {
      depo.hamYaz(_v2, '{"okulId":"o"}');
      expect(await ogretmenDepo.tumu(), isEmpty);
    });

    test('depo hatası çökmez', () async {
      depo.hataVer = true;

      expect(await ogretmenDepo.kayitliMi(), isFalse);
      expect(await ogretmenDepo.tumu(), isEmpty);
      expect(await ogretmenDepo.qrIleKaydet(gecerliYuk), isNull);
    });
  });

  group('Okul eşleşmesi', () {
    test('KRİTİK: başka okulun tahtası fark edilir', () async {
      // Öğretmen komşu okulun tahtasının QR'ını tararsa, sessizce
      // çalışmayan kod üretmek yerine sebep söylenmeli.
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      final kayit = (await ogretmenDepo.tumu()).single;

      final tahtaYuku = TahtaTotp.qrAyristir(
        'SC1:meb_34_999:tahta_1:nonce:29218',
      )!;

      expect(tahtaYuku.ayniOkul(kayit.okulId), isFalse);
    });

    test('kendi okulunun tahtası eşleşir', () async {
      await ogretmenDepo.qrIleKaydet(gecerliYuk);
      final kayit = (await ogretmenDepo.tumu()).single;

      final tahtaYuku = TahtaTotp.qrAyristir(
        'SC1:meb_16_123456:tahta_1:nonce:29218',
      )!;

      expect(tahtaYuku.ayniOkul(kayit.okulId), isTrue);
    });
  });
}
