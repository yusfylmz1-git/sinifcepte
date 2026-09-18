import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_totp.dart';

/// Tahta kilidi TOTP testleri — Python tarafıyla uyum kanıtı.
///
/// ## Bu testin varlık sebebi
///
/// Kilit açma iki dilde çalışıyor: öğretmenin telefonu (Dart) kodu
/// üretiyor, tahta (Python) doğruluyor. İki taraf aynı sonucu
/// vermezse öğretmen doğru kodu girer ve tahta reddeder — sahada
/// teşhisi çok zor bir hata.
///
/// Uyum, ortak kodla değil **ortak standartla** sağlanıyor: iki taraf
/// da RFC 6238 Ek B test vektörlerini geçmek zorunda. Python karşılığı:
/// `sinifcepte-tahta/tests/test_totp.py::TestRfc6238AltinDegerler`.
///
/// Bu dosyadaki vektörler o dosyadakilerle **birebir aynıdır**. Biri
/// değişirse diğeri de değişmeli.
void main() {
  // RFC 6238 Ek B: secret "12345678901234567890" (ASCII), SHA-1.
  final rfcSecret = base64Url.encode(
    utf8.encode('12345678901234567890'),
  );

  // Base32 karşılığı — RFC vektörleri bunu kullanıyor.
  const rfcSecretBase32 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  DateTime an(int unixSaniye) =>
      DateTime.fromMillisecondsSinceEpoch(unixSaniye * 1000, isUtc: true);

  group('RFC 6238 Ek B altın değerleri', () {
    // (unix zaman, beklenen 8 haneli kod)
    // https://datatracker.ietf.org/doc/html/rfc6238#appendix-B
    const vektorler = <List<Object>>[
      [59, '94287082'],
      [1111111109, '07081804'],
      [1111111111, '14050471'],
      [1234567890, '89005924'],
      [2000000000, '69279037'],
    ];

    for (final vektor in vektorler) {
      final zaman = vektor[0] as int;
      final beklenen = vektor[1] as String;

      test('8 hane, t=$zaman → $beklenen', () {
        expect(
          TahtaTotp.kodUret(rfcSecretBase32, an: an(zaman), hane: 8),
          beklenen,
        );
      });

      test('6 hane, t=$zaman → ${beklenen.substring(2)}', () {
        // 6 hane, 8 hanenin son 6 basamağıdır (mod 10^6).
        expect(
          TahtaTotp.kodUret(rfcSecretBase32, an: an(zaman), hane: 6),
          beklenen.substring(2),
        );
      });
    }

    test('KRİTİK: 20000000000 (32 bit taşması)', () {
      // Bu vektör 32 bitlik tam sayıyı aşıyor. Dart'ta `int` 64 bit
      // olduğu için sorun çıkmaması gerekir, ama sayaç hesabında
      // taşma olursa bu test yakalar.
      expect(
        TahtaTotp.kodUret(rfcSecretBase32, an: an(20000000000), hane: 8),
        '65353130',
      );
    });
  });

  group('Secret çözme', () {
    test('dolgusuz base32 kabul edilir', () {
      // İdarecinin telefonu dolgusuz (=) üretebilir.
      const dolgusuz = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      expect(
        TahtaTotp.kodUret(dolgusuz, an: an(59), hane: 8),
        '94287082',
      );
    });

    test('küçük harf kabul edilir', () {
      expect(
        TahtaTotp.kodUret(rfcSecretBase32.toLowerCase(), an: an(59), hane: 8),
        '94287082',
      );
    });

    test('boşluk ve tire atılır', () {
      const parcali = 'GEZD GNBV GY3T QOJQ-GEZD-GNBV GY3T QOJQ';
      expect(
        TahtaTotp.kodUret(parcali, an: an(59), hane: 8),
        '94287082',
      );
    });

    test('boş secret hata verir', () {
      expect(
        () => TahtaTotp.kodUret('', an: an(59)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('base32 olmayan karakter hata verir', () {
      expect(
        () => TahtaTotp.kodUret('bu-gecerli-degil-1892!!', an: an(59)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('geçersiz hane sayısı hata verir', () {
      expect(
        () => TahtaTotp.kodUret(rfcSecretBase32, an: an(59), hane: 4),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Kod biçimi', () {
    test('varsayılan 6 hane', () {
      final kod = TahtaTotp.kodUret(rfcSecretBase32, an: an(1111111109));
      expect(kod.length, 6);
    });

    test('yalnızca rakam içerir', () {
      final kod = TahtaTotp.kodUret(rfcSecretBase32, an: an(1111111109));
      expect(RegExp(r'^\d{6}$').hasMatch(kod), isTrue);
    });

    test('baştaki sıfırlar korunur', () {
      // t=1111111109 → 8 hane "07081804", 6 hane "081804".
      // Sıfır kırpılırsa 5 haneli kod çıkar ve tahta reddeder.
      final kod = TahtaTotp.kodUret(rfcSecretBase32, an: an(1111111109));
      expect(kod, '081804');
      expect(kod.length, 6);
    });

    test('aynı 30 sn penceresinde kod değişmez', () {
      final basi = TahtaTotp.kodUret(rfcSecretBase32, an: an(1111111080));
      final sonu = TahtaTotp.kodUret(rfcSecretBase32, an: an(1111111109));
      expect(basi, sonu);
    });

    test('pencere değişince kod değişir', () {
      final once = TahtaTotp.kodUret(rfcSecretBase32, an: an(1111111109));
      final sonra = TahtaTotp.kodUret(rfcSecretBase32, an: an(1111111140));
      expect(once, isNot(sonra));
    });
  });

  group('Kalan süre', () {
    test('pencere başında tam adım', () {
      // 1111111080 % 30 == 0 → tam pencere başı.
      expect(TahtaTotp.kalanSaniye(an: an(1111111080)), 30);
    });

    test('pencere sonunda 1 saniye', () {
      expect(TahtaTotp.kalanSaniye(an: an(1111111109)), 1);
    });

    test('her zaman 1-30 arası', () {
      for (var i = 0; i < 60; i++) {
        final kalan = TahtaTotp.kalanSaniye(an: an(1111111080 + i));
        expect(kalan, inInclusiveRange(1, 30));
      }
    });
  });

  group('QR yükü ayrıştırma', () {
    test('geçerli yük ayrıştırılır', () {
      final yuk = TahtaTotp.qrAyristir('SC1:meb_16_123456:tahta_8B:a1b2c3:29218');

      expect(yuk, isNotNull);
      expect(yuk!.okulId, 'meb_16_123456');
      expect(yuk.tahtaId, 'tahta_8B');
      expect(yuk.nonce, 'a1b2c3');
      expect(yuk.unixDakika, 29218);
    });

    test('baştaki/sondaki boşluk tolere edilir', () {
      final yuk = TahtaTotp.qrAyristir('  SC1:okul:tahta:nonce:100  ');
      expect(yuk, isNotNull);
    });

    test('yanlış önek reddedilir', () {
      // Başka bir uygulamanın QR'ı tarandığında sessizce çalışmayan
      // kod vermek yerine null dönmeli.
      expect(TahtaTotp.qrAyristir('XX1:okul:tahta:nonce:100'), isNull);
    });

    test('eksik alan reddedilir', () {
      expect(TahtaTotp.qrAyristir('SC1:okul:tahta:nonce'), isNull);
    });

    test('SC1\'e fazla alan reddedilir', () {
      // `SC1` tam 5 alan. Fazlası bozuk bir QR demek; sessizce kabul
      // etmek yanlış veriyle çalışmak olurdu.
      expect(TahtaTotp.qrAyristir('SC1:okul:tahta:nonce:100:fazla'), isNull);
    });

    test('sayı olmayan dakika reddedilir', () {
      expect(TahtaTotp.qrAyristir('SC1:okul:tahta:nonce:dun'), isNull);
    });

    test('boş okul kimliği reddedilir', () {
      expect(TahtaTotp.qrAyristir('SC1::tahta:nonce:100'), isNull);
    });

    test('boş tahta kimliği reddedilir', () {
      expect(TahtaTotp.qrAyristir('SC1:okul::nonce:100'), isNull);
    });

    test('tamamen alakasız metin reddedilir', () {
      expect(TahtaTotp.qrAyristir('https://ornek.com'), isNull);
      expect(TahtaTotp.qrAyristir(''), isNull);
    });
  });

  group('SC2 — yerel ağdan açma', () {
    // `SC2` tahtanın yerel sunucusu çalışırken yazılıyor: sonuna IP ve
    // port ekleniyor, telefon oraya doğrudan istek gönderiyor ve
    // öğretmen 6 hane yazmıyor (kullanıcı isteği, 18 Eylül 2026).
    //
    // İlk dört alan `SC1` ile AYNI — biçim geriye uyumlu.

    test('KRİTİK: IP ve port okunuyor', () {
      final yuk = TahtaTotp.qrAyristir(
        'SC2:meb_775214:tahta_8B:a1b2:29218:192.168.1.50:8443',
      );

      expect(yuk, isNotNull);
      expect(yuk!.okulId, 'meb_775214');
      expect(yuk.tahtaId, 'tahta_8B');
      expect(yuk.ip, '192.168.1.50');
      expect(yuk.port, 8443);
      expect(yuk.agdanAcilabilir, isTrue);
    });

    test('KRİTİK: açma adresi doğru kuruluyor', () {
      // Telefon bu adrese POST gönderecek; yanlışsa tahta hiç
      // açılmaz ve sebebi görünmez.
      final yuk = TahtaTotp.qrAyristir(
        'SC2:okul:tahta:n:100:10.0.0.7:8443',
      );

      expect(yuk!.acmaAdresi, 'http://10.0.0.7:8443/ac');
    });

    test('SC1 ağdan açılamaz ama geçerli kalıyor', () {
      // Eski tahta veya ağ yok: 6 hane yolu çalışmaya devam etmeli.
      final yuk = TahtaTotp.qrAyristir('SC1:okul:tahta:n:100');

      expect(yuk, isNotNull);
      expect(yuk!.agdanAcilabilir, isFalse);
      expect(yuk.ip, isEmpty);
      expect(yuk.port, isNull);
    });

    test('KRİTİK: bozuk IP QR\'ı geçersiz KILMIYOR', () {
      // Ağ yolu kullanılamaz ama 6 hane yolu çalışmalı. `null`
      // dönseydi öğretmen "bu QR tahtaya ait değil" görür ve
      // sınıfta mahsur kalırdı.
      final yuk = TahtaTotp.qrAyristir(
        'SC2:okul:tahta:n:100:bu-ip-degil:8443',
      );

      expect(yuk, isNotNull, reason: 'QR geçerli kalmalı');
      expect(yuk!.agdanAcilabilir, isFalse);
      expect(yuk.okulId, 'okul');
    });

    test('bozuk port da aynı şekilde ele alınıyor', () {
      for (final port in ['abc', '0', '-1', '70000', '']) {
        final yuk = TahtaTotp.qrAyristir(
          'SC2:okul:tahta:n:100:192.168.1.5:$port',
        );
        expect(yuk, isNotNull, reason: 'port=$port');
        expect(yuk!.agdanAcilabilir, isFalse, reason: 'port=$port');
      }
    });

    test('IP aralık dışı sayı içeriyorsa reddediliyor', () {
      final yuk = TahtaTotp.qrAyristir(
        'SC2:okul:tahta:n:100:999.1.1.1:8443',
      );
      expect(yuk!.agdanAcilabilir, isFalse);
    });

    test('SC2 eksik alanla reddediliyor', () {
      // 7 alan şart; 6 alanlı bir SC2 bozuk demektir.
      expect(
        TahtaTotp.qrAyristir('SC2:okul:tahta:n:100:192.168.1.5'),
        isNull,
      );
    });

    test('SC2 fazla alanla reddediliyor', () {
      expect(
        TahtaTotp.qrAyristir('SC2:okul:tahta:n:100:192.168.1.5:8443:x'),
        isNull,
      );
    });

    test('okul eşleşmesi SC2 için de çalışıyor', () {
      // Ağdan açma, okul kontrolünü ATLAMAMALI: başka okulun
      // tahtasına istek göndermek anlamsız.
      final yuk = TahtaTotp.qrAyristir(
        'SC2:meb_775214:tahta:n:100:192.168.1.5:8443',
      );

      expect(yuk!.ayniOkul('meb_775214'), isTrue);
      expect(yuk.ayniOkul('meb_123456'), isFalse);
    });
  });

  group('Okul eşleşmesi', () {
    test('aynı okul kabul edilir', () {
      final yuk = TahtaTotp.qrAyristir('SC1:meb_16_1:t:n:100')!;
      expect(yuk.ayniOkul('meb_16_1'), isTrue);
    });

    test('KRİTİK: başka okulun tahtası reddedilir', () {
      // Öğretmen komşu okulun tahtasının QR'ını tararsa, sessizce
      // çalışmayan bir kod üretmek yerine sebebi söylenmeli.
      final yuk = TahtaTotp.qrAyristir('SC1:meb_34_999:t:n:100')!;
      expect(yuk.ayniOkul('meb_16_1'), isFalse);
    });
  });

  group('Öğretmen ayrımı', () {
    test('KRİTİK: bir öğretmenin secret\'i başkasının kodunu üretmez', () {
      const secretA = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      const secretB = 'MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43U';

      final kodA = TahtaTotp.kodUret(secretA, an: an(1111111109));
      final kodB = TahtaTotp.kodUret(secretB, an: an(1111111109));

      expect(kodA, isNot(kodB));
    });
  });

  // `rfcSecret` yalnızca base32 dönüşümünün doğruluğunu belgelemek için
  // duruyor; testler base32 biçimini kullanıyor.
  test('belge: ASCII secret\'in base32 karşılığı', () {
    expect(rfcSecret, isNotEmpty);
    expect(rfcSecretBase32.length, 32);
  });

  group('Secret üretimi (idareci öğretmen eklerken)', () {
    test('üretilen secret kod üretebiliyor', () {
      // Üretim → çözme → kod turu kapanmalı; base32 kodlaması bozuksa
      // idareci öğretmen ekler ama öğretmen hiç kod üretemez.
      final secret = TahtaTotp.secretUret();
      final kod = TahtaTotp.kodUret(secret, an: an(1111111109));

      expect(kod.length, 6);
      expect(RegExp(r'^\d{6}$').hasMatch(kod), isTrue);
    });

    test('dolgusuz base32 üretir', () {
      // Python tarafı dolgusuzu kabul ediyor; '=' eklemek gereksiz
      // uzunluk ve elle girişte karışıklık demek.
      expect(TahtaTotp.secretUret(), isNot(contains('=')));
    });

    test('yalnızca base32 alfabesi', () {
      final secret = TahtaTotp.secretUret();
      expect(RegExp(r'^[A-Z2-7]+$').hasMatch(secret), isTrue);
    });

    test('20 bayt için 32 karakter (RFC 4226 önerisi)', () {
      // 20 bayt = 160 bit; base32'de 5 bit/karakter → 32 karakter.
      expect(TahtaTotp.secretUret().length, 32);
    });

    test('KRİTİK: her çağrı farklı secret üretir', () {
      // Tahmin edilebilir veya tekrar eden secret, bir öğretmenin
      // başkasının adına kilit açması demekti.
      final kume = <String>{};
      for (var i = 0; i < 200; i++) {
        kume.add(TahtaTotp.secretUret());
      }
      expect(kume.length, 200);
    });

    test('KRİTİK: iki secret birbirinin kodunu kabul etmez', () {
      final a = TahtaTotp.secretUret();
      final b = TahtaTotp.secretUret();

      final kodA = TahtaTotp.kodUret(a, an: an(1111111109));
      final kodB = TahtaTotp.kodUret(b, an: an(1111111109));

      expect(kodA, isNot(kodB));
    });
  });
}
