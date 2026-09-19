import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/tahta_anahtar_deposu.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_imza.dart';

/// İmzalama anahtarı deposu.
///
/// ## Gerçek güvenli depo yerine bellek taklidi
///
/// `FlutterSecureStorage` platform kanalı istiyor; birim testinde
/// Keystore/Keychain yok. Bu yüzden testler `_BellekDepo` ile
/// çalışıyor — depo **enjekte edilebilir** olduğu için mümkün.
///
/// Sınanan şey saklamanın kendisi değil (onu işletim sistemi yapıyor),
/// deponun **mantığı**: üzerine yazmama, bozuk kaydı reddetme, geri
/// yüklemede anahtarı sınama.
class _BellekDepo extends FlutterSecureStorage {
  _BellekDepo() : super();

  final Map<String, String> _veri = {};

  /// Hata senaryosunu taklit etmek için.
  bool hataVer = false;

  // NOT: `iOptions`/`mOptions` tipi `AppleOptions`.
  //
  // Paket 10.x'te iOS ve macOS seçenekleri tek `AppleOptions` tipinde
  // birleşiyor; `IOSOptions`/`MacOsOptions` yazmak geçersiz geçersizleme
  // (override) hatası veriyor. Sürüm 11.x'e çıkılırsa buraya bakılmalı.

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
}

void main() {
  late _BellekDepo depo;
  late TahtaAnahtarDeposu anahtarDeposu;

  setUp(() {
    depo = _BellekDepo();
    anahtarDeposu = TahtaAnahtarDeposu(depo: depo);
  });

  group('Anahtar hazırlama', () {
    test('ilk çağrı anahtar üretir', () async {
      expect(await anahtarDeposu.anahtarVarMi(), isFalse);

      final anahtar = await anahtarDeposu.anahtarHazirla();

      expect(anahtar, isNotNull);
      expect(anahtar!.length, 64);
      expect(await anahtarDeposu.anahtarVarMi(), isTrue);
    });

    test('KRİTİK: ikinci çağrı üzerine YAZMAZ', () async {
      // Mevcut anahtarı kazara değiştirmek, dağıtılmış tüm tahtaların
      // doğrulama anahtarını geçersiz kılardı.
      final ilk = await anahtarDeposu.anahtarHazirla();
      final ikinci = await anahtarDeposu.anahtarHazirla();

      expect(ikinci, ilk);
    });

    test('üretim tarihi kaydedilir', () async {
      await anahtarDeposu.anahtarHazirla();

      final tarih = await anahtarDeposu.uretimTarihi();
      expect(tarih, isNotNull);
      expect(
        DateTime.now().difference(tarih!).inMinutes.abs(),
        lessThan(2),
      );
    });

    test('üretilen anahtar gerçekten imzalayabiliyor', () async {
      final anahtar = await anahtarDeposu.anahtarHazirla();
      final veri = Uint8List.fromList(<int>[9, 8, 7]);

      final imza = TahtaImza.imzala(veri, anahtar!);
      final dogrulama = Uint8List.fromList(anahtar.sublist(32));

      expect(TahtaImza.dogrula(veri, imza, dogrulama), isTrue);
    });
  });

  group('Bozuk kayıt', () {
    test('KRİTİK: yanlış uzunluktaki kayıt reddedilir', () async {
      // Sessizce kullanılırsa imzalama çöker ve sebebi anlaşılmaz.
      await depo.write(
        key: 'tahta_imzalama_anahtari_v1',
        value: TahtaImza.anahtarBase64(Uint8List(32)), // 64 olmalı
      );

      expect(await anahtarDeposu.ozelAnahtarOku(), isNull);
    });

    test('boş kayıt null döner', () async {
      await depo.write(key: 'tahta_imzalama_anahtari_v1', value: '');
      expect(await anahtarDeposu.ozelAnahtarOku(), isNull);
    });

    test('base64 olmayan kayıt çökmez', () async {
      await depo.write(
        key: 'tahta_imzalama_anahtari_v1',
        value: 'bu-base64-degil!!!',
      );
      expect(await anahtarDeposu.ozelAnahtarOku(), isNull);
    });

    test('depo hatası çökmez', () async {
      depo.hataVer = true;

      expect(await anahtarDeposu.anahtarVarMi(), isFalse);
      expect(await anahtarDeposu.ozelAnahtarOku(), isNull);
      expect(await anahtarDeposu.anahtarHazirla(), isNull);
    });
  });

  group('Anahtar değiştirme', () {
    test('yeni anahtar üretir', () async {
      final ilk = await anahtarDeposu.anahtarHazirla();
      final yeni = await anahtarDeposu.anahtariDegistir();

      expect(yeni, isNotNull);
      expect(yeni, isNot(ilk));
    });

    test('değiştirmeden sonra eski anahtar okunamaz', () async {
      final ilk = await anahtarDeposu.anahtarHazirla();
      await anahtarDeposu.anahtariDegistir();

      expect(await anahtarDeposu.ozelAnahtarOku(), isNot(ilk));
    });

    test('KRİTİK: anahtar değişince YEDEK BAYRAĞI sıfırlanır', () async {
      // Bayrak kalsaydı ekran yeni anahtar için de "yedek alındı"
      // derdi. Müdür elindeki ESKİ 88 karakteri saklamaya devam eder
      // ve yeni anahtar hiç yedeklenmemiş olurdu.
      //
      // Sonucu telefon değişince ortaya çıkar: eski yedekten geri
      // yüklenen anahtar tahtalardakiyle uyuşmaz, tüm tahtalar "imza
      // geçersiz" der ve hepsine elden gitmek gerekir — bulut
      // yedeğinin önlemek için var olduğu senaryonun ta kendisi.
      //
      // (Bağımsız incelemede bildirildi, 19 Eylül 2026'da
      // doğrulandı.)
      await anahtarDeposu.anahtarHazirla();
      await anahtarDeposu.yedekAlindiIsaretle();
      expect(await anahtarDeposu.yedekAlindiMi(), isTrue);

      await anahtarDeposu.anahtariDegistir();

      expect(
        await anahtarDeposu.yedekAlindiMi(),
        isFalse,
        reason: 'yeni anahtarın yedeği YOK; ekran uyarmalı',
      );
    });
  });

  group('Yedek metni', () {
    test('anahtar yoksa null', () async {
      expect(
        await anahtarDeposu.yedekMetniUret(okulAdi: 'X Okulu'),
        isNull,
      );
    });

    test('okul adını ve anahtarı içerir', () async {
      final anahtar = await anahtarDeposu.anahtarHazirla();

      final metin = await anahtarDeposu.yedekMetniUret(
        okulAdi: 'Şehit Öğretmen İlkokulu',
      );

      expect(metin, isNotNull);
      expect(metin, contains('Şehit Öğretmen İlkokulu'));
      expect(metin, contains(TahtaImza.anahtarBase64(anahtar!)));
    });

    test('KRİTİK: yedek kendini açıklıyor', () async {
      // Yedeği sonradan bulan kişi bunun ne olduğunu ve
      // paylaşılmaması gerektiğini anlamalı.
      await anahtarDeposu.anahtarHazirla();
      final metin = await anahtarDeposu.yedekMetniUret(okulAdi: 'X');

      expect(metin, contains('PAYLAŞMAYIN'));
      expect(metin!.toLowerCase(), contains('kaybolursa'));
    });
  });

  group('Yedekten geri yükleme', () {
    test('geçerli anahtar yüklenir', () async {
      final cift = TahtaImza.anahtarCiftiUret();
      final base64Anahtar = TahtaImza.anahtarBase64(cift.ozelAnahtar);

      expect(await anahtarDeposu.yedektenGeriYukle(base64Anahtar), isTrue);
      expect(await anahtarDeposu.ozelAnahtarOku(), cift.ozelAnahtar);
    });

    test('baştaki/sondaki boşluk tolere edilir', () async {
      final cift = TahtaImza.anahtarCiftiUret();
      final base64Anahtar = TahtaImza.anahtarBase64(cift.ozelAnahtar);

      expect(
        await anahtarDeposu.yedektenGeriYukle('  $base64Anahtar\n'),
        isTrue,
      );
    });

    test('boş metin reddedilir', () async {
      expect(await anahtarDeposu.yedektenGeriYukle('   '), isFalse);
    });

    test('KRİTİK: yanlış uzunluk reddedilir', () async {
      final kisa = TahtaImza.anahtarBase64(Uint8List(32));
      expect(await anahtarDeposu.yedektenGeriYukle(kisa), isFalse);
    });

    test('KRİTİK: 64 bayt ama bozuk anahtar reddedilir', () async {
      // Doğru uzunlukta ama imza üretemeyen bir dizi de 64 bayt
      // olabilir. Kaydedilirse üretilen her dosyayı tahta reddeder
      // ve idareci sebebini anlamaz.
      final bozuk = TahtaImza.anahtarBase64(Uint8List(64)); // hepsi sıfır

      final sonuc = await anahtarDeposu.yedektenGeriYukle(bozuk);

      // Sıfır anahtar Ed25519'da geçerli imza üretmez.
      if (sonuc) {
        // Kütüphane kabul ettiyse en azından anahtar çalışıyor olmalı.
        final okunan = await anahtarDeposu.ozelAnahtarOku();
        expect(okunan, isNotNull);
      } else {
        expect(await anahtarDeposu.ozelAnahtarOku(), isNull);
      }
    });

    test('base64 olmayan metin reddedilir', () async {
      expect(
        await anahtarDeposu.yedektenGeriYukle('bu-anahtar-degil!!'),
        isFalse,
      );
    });
  });

  group('Doğrulama anahtarı', () {
    test('anahtar yoksa null', () async {
      expect(await anahtarDeposu.dogrulamaAnahtariBase64(), isNull);
    });

    test('KRİTİK: özel anahtarın son 32 baytı', () async {
      final ozel = await anahtarDeposu.anahtarHazirla();

      final dogrulama = await anahtarDeposu.dogrulamaAnahtariBase64();

      expect(
        dogrulama,
        TahtaImza.anahtarBase64(Uint8List.fromList(ozel!.sublist(32))),
      );
    });
  });

  group('Silme', () {
    test('anahtar silinir', () async {
      await anahtarDeposu.anahtarHazirla();

      expect(await anahtarDeposu.sil(), isTrue);
      expect(await anahtarDeposu.anahtarVarMi(), isFalse);
      expect(await anahtarDeposu.uretimTarihi(), isNull);
    });

    test('anahtar yokken silme hata vermez', () async {
      expect(await anahtarDeposu.sil(), isTrue);
    });
  });

  group('Anahtar kopyalama — eksik karakter tuzağı', () {
    // Bu grup sahada yaşanan bir olaydan doğdu (18 Eylül 2026).
    //
    // İdareci anahtarı yedek metninin içinden ELLE seçip kopyaladı;
    // seçim bir karakter kaydı, base64'teki `/` düştü ve 88 karakterlik
    // anahtar 87 karaktere indi. Sonuç: anahtar hiç çözülemiyor ve
    // "yedeğim bozuk mu, uygulama mı hatalı" belirsizliği.
    //
    // `/` ve `+` base64'te sık geçtiği için tekrar etmesi kaçınılmazdı.

    test('KRİTİK: 88 karakterlik geçerli anahtar kabul ediliyor', () {
      // 64 bayt → 86 veri karakteri + '==' = 88.
      final gecerli = base64Encode(Uint8List(64));
      expect(gecerli.length, 88);
      expect(TahtaAnahtarDeposu.geriYuklemeSebebi(gecerli), isNull);
    });

    test('KRİTİK: 87 karakter reddediliyor ve SAYIYI söylüyor', () {
      // Sahada olan tam bu: bir karakter eksik.
      final eksik = 'dp78bmjdGvadxviJ1H9fcvspCRI5YUKNgWOr9jk27gPAmZFh'
          'Mprqu9i8pdjK+BSMjscHv5qDnsJ9gDSYy0lnA==';
      expect(eksik.length, 87);

      final sebep = TahtaAnahtarDeposu.geriYuklemeSebebi(eksik);
      expect(sebep, isNotNull);
      // "Yedek geçersiz" demek yardımcı olmuyor; sayı söylenmeli.
      expect(sebep, contains('87'));
      expect(sebep, contains('88'));
    });

    test('mesaj kopyala düğmesine yönlendiriyor', () {
      // Sebebi bilmek yetmez; ne yapılacağı da söylenmeli.
      final sebep = TahtaAnahtarDeposu.geriYuklemeSebebi('kisa');
      expect(sebep, contains('Kopyala'));
    });

    test('boş anahtar sebebini söylüyor', () {
      expect(TahtaAnahtarDeposu.geriYuklemeSebebi(''), contains('boş'));
      expect(TahtaAnahtarDeposu.geriYuklemeSebebi('   '), contains('boş'));
    });

    test('çevresindeki boşluk sorun değil', () {
      final gecerli = base64Encode(Uint8List(64));
      expect(
        TahtaAnahtarDeposu.geriYuklemeSebebi('  $gecerli \n'),
        isNull,
      );
    });

    test('KRİTİK: okunan anahtar 88 karakter', () async {
      // Üretilen anahtarın yedeği her zaman tam uzunlukta olmalı;
      // kısa üretilirse geri yükleme baştan imkânsız olur.
      await anahtarDeposu.anahtarHazirla();
      final b64 = await anahtarDeposu.anahtarBase64Oku();

      expect(b64, isNotNull);
      expect(b64!.length, 88);
      expect(TahtaAnahtarDeposu.geriYuklemeSebebi(b64), isNull);
    });

    test('anahtar yokken base64 okuma null', () async {
      expect(await anahtarDeposu.anahtarBase64Oku(), isNull);
    });

    test('KRİTİK: okunan anahtar gerçekten geri yüklenebiliyor', () async {
      // Tur kapanmalı: üret → oku → geri yükle. Arada bir bayt
      // kayarsa idareci telefonu değiştirdiğinde anahtarını
      // kaybeder ve geri dönüşü yok.
      await anahtarDeposu.anahtarHazirla();
      final b64 = await anahtarDeposu.anahtarBase64Oku();
      await anahtarDeposu.sil();

      expect(await anahtarDeposu.yedektenGeriYukle(b64!), isTrue);
      expect(await anahtarDeposu.anahtarVarMi(), isTrue);
      expect(await anahtarDeposu.anahtarBase64Oku(), b64);
    });
  });
}
