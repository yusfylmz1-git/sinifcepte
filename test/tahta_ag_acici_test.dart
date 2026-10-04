/// Tahtayı yerel ağdan açan istemci.
///
/// ## Neden gerçek HTTP sunucusu kullanılıyor
///
/// `HttpClient`'ı sahtelemek yerine testte gerçek bir `HttpServer`
/// açılıyor. Sebep: sınanmak istenen şey **ağ davranışı** —
/// bağlantı kurulamaması, zaman aşımı, bozuk yanıt. Sahte bir
/// istemci bunları taklit eder ama gerçek yollardan geçmez ve
/// sahadaki hata sınıflarını kaçırır.
///
/// Sunucular `127.0.0.1` üzerinde ve port 0 ile (işletim sistemi boş
/// port seçer) açılıyor; testler paralel koşarken çakışmıyor.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/tahta_ag_acici.dart';

/// Belirtilen yanıtı veren tek kullanımlık sunucu.
Future<HttpServer> _sunucuAc({
  required int durumKodu,
  required Object govde,
  Duration? gecikme,
  void Function(Map<String, dynamic> istek)? yakala,
}) async {
  final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  unawaited(() async {
    await for (final istek in sunucu) {
      if (gecikme != null) await Future<void>.delayed(gecikme);

      if (yakala != null) {
        final ham = await utf8.decoder.bind(istek).join();
        try {
          yakala(jsonDecode(ham) as Map<String, dynamic>);
        } catch (_) {
          yakala({});
        }
      }

      istek.response.statusCode = durumKodu;
      istek.response.headers.contentType = ContentType.json;
      istek.response.write(
        govde is String ? govde : jsonEncode(govde),
      );
      await istek.response.close();
    }
  }());

  return sunucu;
}

String _adres(HttpServer s) => 'http://127.0.0.1:${s.port}/ac';

void main() {
  group('Başarılı açma', () {
    test('KRİTİK: tahta kabul edince açıldı dönüyor', () async {
      final sunucu = await _sunucuAc(
        durumKodu: 200,
        govde: {'tamam': true, 'mesaj': 'Hoş geldiniz, Yusuf YILMAZ'},
      );

      final acici = TahtaAgAcici();
      final sonuc = await acici.ac(adres: _adres(sunucu), kod: '123456');
      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.acildi, isTrue);
      expect(sonuc.durum, AgAcmaDurumu.acildi);
      expect(sonuc.kullaniciMesaji, contains('Yusuf YILMAZ'));
    });

    test('KRİTİK: kod gövdede doğru gönderiliyor', () async {
      // Kod yanlış alanda giderse tahta hiç açılmaz ve sebebi
      // görünmez: tahta "kod girilmedi" der, telefon "reddedildi".
      Map<String, dynamic>? alinan;
      final sunucu = await _sunucuAc(
        durumKodu: 200,
        govde: {'tamam': true, 'mesaj': 'ok'},
        yakala: (istek) => alinan = istek,
      );

      final acici = TahtaAgAcici();
      await acici.ac(adres: _adres(sunucu), kod: '987654');
      acici.kapat();
      await sunucu.close(force: true);

      expect(alinan, isNotNull);
      expect(alinan!['kod'], '987654');
    });
  });

  group('Tahta reddetti — ULAŞILDI ama açılmadı', () {
    test('KRİTİK: tamam=false reddedildi sayılıyor', () async {
      final sunucu = await _sunucuAc(
        durumKodu: 200,
        govde: {'tamam': false, 'mesaj': 'Kod geçersiz.'},
      );

      final acici = TahtaAgAcici();
      final sonuc = await acici.ac(adres: _adres(sunucu), kod: '000000');
      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.acildi, isFalse);
      expect(sonuc.durum, AgAcmaDurumu.reddedildi);
    });

    test('200 dışı durum kodu reddedildi sayılıyor', () async {
      final sunucu = await _sunucuAc(durumKodu: 400, govde: {'tamam': false});

      final acici = TahtaAgAcici();
      final sonuc = await acici.ac(adres: _adres(sunucu), kod: 'x');
      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.durum, AgAcmaDurumu.reddedildi);
    });
  });

  group('Ulaşılamadı — kodu SUÇLAMAMALI', () {
    test('KRİTİK: kapalı porta istek ulasilamadi dönüyor', () async {
      // Bu ayrım kritik: "ulaşılamadı" durumunda öğretmene "kodunuz
      // yanlış" demek onu kodu yenilemeye iter, oysa sorun ağda.
      final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = sunucu.port;
      await sunucu.close(force: true);

      final acici = TahtaAgAcici(
        zamanAsimi: const Duration(milliseconds: 800),
      );
      final sonuc = await acici.ac(
        adres: 'http://127.0.0.1:$port/ac',
        kod: '123456',
      );
      acici.kapat();

      expect(sonuc.durum, AgAcmaDurumu.ulasilamadi);
      expect(sonuc.acildi, isFalse);
    });

    test('KRİTİK: ulaşılamadı mesajı 6 hane yoluna yönlendiriyor', () async {
      final sonuc = await TahtaAgAcici(
        zamanAsimi: const Duration(milliseconds: 500),
      ).ac(adres: 'http://127.0.0.1:1/ac', kod: '123456');

      final mesaj = sonuc.kullaniciMesaji.toLowerCase();
      expect(mesaj, contains('elle'));
      // Kodu suçlamamalı.
      expect(mesaj, isNot(contains('geçersiz')));
    });

    test('bozuk adres çökmüyor', () async {
      final acici = TahtaAgAcici(
        zamanAsimi: const Duration(milliseconds: 500),
      );
      final sonuc = await acici.ac(adres: 'bu bir adres değil', kod: 'x');
      acici.kapat();

      expect(sonuc.durum, AgAcmaDurumu.ulasilamadi);
    });

    test('KRİTİK: yavaş tahta zaman aşımına düşüyor', () async {
      // Öğretmen ders başında bekliyor; sonsuza kadar beklememeli.
      final sunucu = await _sunucuAc(
        durumKodu: 200,
        govde: {'tamam': true},
        gecikme: const Duration(seconds: 3),
      );

      final acici = TahtaAgAcici(
        zamanAsimi: const Duration(milliseconds: 400),
      );
      final baslangic = DateTime.now();
      final sonuc = await acici.ac(adres: _adres(sunucu), kod: '123456');
      final gecen = DateTime.now().difference(baslangic);

      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.durum, AgAcmaDurumu.ulasilamadi);
      expect(gecen.inSeconds, lessThan(3),
          reason: 'zaman aşımı beklenenden geç tetiklendi');
    });

    test('bozuk JSON yanıtı çökmüyor', () async {
      final sunucu = await _sunucuAc(
        durumKodu: 200,
        govde: 'bu json degil{{{',
      );

      final acici = TahtaAgAcici();
      final sonuc = await acici.ac(adres: _adres(sunucu), kod: 'x');
      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.durum, AgAcmaDurumu.ulasilamadi);
    });

    test('eksik alanlı yanıt reddedildi sayılıyor', () async {
      // `tamam` yoksa açılmış sayılmamalı: belirsizlikte kilidi açık
      // varsaymak yanlış tarafta hata yapmak olurdu.
      final sunucu = await _sunucuAc(durumKodu: 200, govde: {'baska': 1});

      final acici = TahtaAgAcici();
      final sonuc = await acici.ac(adres: _adres(sunucu), kod: 'x');
      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.acildi, isFalse);
    });
  });

  group('Kullanıcı mesajları — üç durum ayrı', () {
    test('KRİTİK: açıldı, reddedildi ve ulaşılamadı farklı metin', () async {
      // Aynı metni vermek öğretmeni yanlış yönlendirirdi: ağ sorunu
      // ile yanlış kod bambaşka iki şey ve çözümleri de farklı.
      //
      // Kurucu özel olduğu için sonuçlar GERÇEK yollardan üretiliyor.
      final acikSunucu = await _sunucuAc(
        durumKodu: 200,
        govde: {'tamam': true, 'mesaj': 'Hoş geldiniz'},
      );
      final redSunucu = await _sunucuAc(
        durumKodu: 200,
        govde: {'tamam': false, 'mesaj': ''},
      );

      final acici = TahtaAgAcici(
        zamanAsimi: const Duration(milliseconds: 600),
      );

      final acildi = await acici.ac(adres: _adres(acikSunucu), kod: 'x');
      final reddedildi = await acici.ac(adres: _adres(redSunucu), kod: 'x');
      final ulasilamadi =
          await acici.ac(adres: 'http://127.0.0.1:1/ac', kod: 'x');

      acici.kapat();
      await acikSunucu.close(force: true);
      await redSunucu.close(force: true);

      expect(acildi.kullaniciMesaji, isNot(reddedildi.kullaniciMesaji));
      expect(reddedildi.kullaniciMesaji, isNot(ulasilamadi.kullaniciMesaji));

      // Üçü de boş olmamalı: sessiz ekran en kötü sonuç.
      for (final s in [acildi, reddedildi, ulasilamadi]) {
        expect(s.kullaniciMesaji, isNotEmpty);
      }
    });
  });

  group('Content-Length — tahta bu başlığı okuyor', () {
    test('KRİTİK: istek Content-Length taşıyor, chunked değil', () async {
      // Tahtanın sunucusu (Python `BaseHTTPRequestHandler`) gövde
      // uzunluğunu bu başlıktan okuyor. `contentLength` verilmezse
      // Dart `Transfer-Encoding: chunked` kullanıyor ve başlığı HİÇ
      // göndermiyor; tahta uzunluğu 0 sayıp HTTP 400 dönüyor — kodu
      // hiç doğrulamadan.
      //
      // Sahada bu "tahta kodu kabul etmedi" olarak görünüyordu ve
      // öğretmen doğru kodu tekrar tekrar deniyordu (19 Eylül 2026,
      // cihazda logcat ile ölçüldü).
      //
      // `dart:io` `HttpServer` chunked'ı saydam çözdüğü için bu
      // testin BAŞLIĞA bakması gerekiyor; gövdeyi okumak yetmez ve
      // kusur yine kaçardı.
      String? uzunluk;
      String? aktarim;

      final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(() async {
        await for (final istek in sunucu) {
          uzunluk = istek.headers.value('content-length');
          aktarim = istek.headers.value('transfer-encoding');
          await utf8.decoder.bind(istek).join();
          istek.response.statusCode = 200;
          istek.response.write(jsonEncode({'tamam': true, 'mesaj': 'ok'}));
          await istek.response.close();
        }
      }());

      final acici = TahtaAgAcici();
      await acici.ac(adres: _adres(sunucu), kod: '167580');
      acici.kapat();
      await sunucu.close(force: true);

      expect(uzunluk, isNotNull,
          reason: 'Content-Length yok — tahta HTTP 400 döner');
      expect(int.parse(uzunluk!), greaterThan(0));
      expect(aktarim, isNot('chunked'));
    });

    test('Content-Length gövdenin gerçek bayt uzunluğu', () async {
      // Türkçe karakter gövdede yoksa da olabilir; yine de uzunluk
      // KARAKTER değil BAYT sayısı olmalı. Yanlışsa tahta gövdeyi
      // eksik okur ve JSON çözümlemesi başarısız olur.
      String? uzunluk;
      String? govde;

      final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(() async {
        await for (final istek in sunucu) {
          uzunluk = istek.headers.value('content-length');
          govde = await utf8.decoder.bind(istek).join();
          istek.response.statusCode = 200;
          istek.response.write(jsonEncode({'tamam': true}));
          await istek.response.close();
        }
      }());

      final acici = TahtaAgAcici();
      await acici.ac(adres: _adres(sunucu), kod: '123456');
      acici.kapat();
      await sunucu.close(force: true);

      expect(int.parse(uzunluk!), utf8.encode(govde!).length);
    });
  });

  group('Kilitleme — telefondan (tahta 0.7.1+)', () {
    /// Yolu ve gövdeyi kaydeden sunucu.
    Future<(HttpServer, List<String>, List<Map<String, dynamic>>)> kaydeden({
      required int durumKodu,
      required Object govde,
    }) async {
      final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final yollar = <String>[];
      final govdeler = <Map<String, dynamic>>[];
      unawaited(() async {
        await for (final istek in sunucu) {
          yollar.add(istek.uri.path);
          final ham = await utf8.decoder.bind(istek).join();
          govdeler.add(jsonDecode(ham) as Map<String, dynamic>);
          istek.response.statusCode = durumKodu;
          istek.response.headers.contentType = ContentType.json;
          istek.response.write(govde is String ? govde : jsonEncode(govde));
          await istek.response.close();
        }
      }());
      return (sunucu, yollar, govdeler);
    }

    test('KRİTİK: /kilitle yoluna telefon koduyla gidiyor', () async {
      final (sunucu, yollar, govdeler) = await kaydeden(
        durumKodu: 200,
        govde: {'tamam': true, 'mesaj': 'Tahta kilitlendi.'},
      );
      final acici = TahtaAgAcici();
      final sonuc = await acici.kilitle(
        adres: 'http://127.0.0.1:${sunucu.port}/kilitle',
        kod: '246810',
      );
      acici.kapat();
      await sunucu.close(force: true);

      expect(yollar, ['/kilitle']);
      expect(govdeler.single['kod'], '246810');
      expect(sonuc.basarili, isTrue);
      expect(sonuc.kullaniciMesaji, 'Tahta kilitlendi.');
    });

    test('eski tahta (404) için yazılım güncellenmeli diyor', () async {
      final (sunucu, _, _) = await kaydeden(durumKodu: 404, govde: {'tamam': false});
      final acici = TahtaAgAcici();
      final sonuc = await acici.kilitle(
        adres: 'http://127.0.0.1:${sunucu.port}/kilitle',
        kod: '246810',
      );
      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.basarili, isFalse);
      expect(sonuc.kullaniciMesaji, contains('güncellemeli'));
    });

    test('KRİTİK: ulaşılamazsa tahtadaki Kilitle düğmesine yönlendiriyor', () async {
      final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = sunucu.port;
      await sunucu.close(force: true);

      final acici = TahtaAgAcici(zamanAsimi: const Duration(seconds: 1));
      final sonuc = await acici.kilitle(
        adres: 'http://127.0.0.1:$port/kilitle',
        kod: '246810',
      );
      acici.kapat();

      expect(sonuc.durum, AgAcmaDurumu.ulasilamadi);
      expect(sonuc.kullaniciMesaji, contains('"Kilitle"'));
      // Açma mesajı ("kodu elle girin") kilitlemede yanlış olurdu.
      expect(sonuc.kullaniciMesaji, isNot(contains('elle girin')));
    });
  });

  // Saha bilgisi (4 Ekim 2026): öğretmenler okul ağına hiç bağlanmıyor,
  // mobil veri kullanıyor. Her karekodda 4 sn bekleyip kırmızı
  // "ulaşılamadı" göstermek sistemi bozuk gösteriyordu.
  group('Mobil veri — ağ hiç denenmiyor', () {
    test('KRİTİK: yerel ağ yoksa beklemeden yerelAgYok dönüyor', () async {
      // Yönlendirilemeyen adres: denenseydi zaman aşımına kadar beklerdi.
      final acici = TahtaAgAcici(
        zamanAsimi: const Duration(seconds: 3),
        yerelAgKontrol: () async => false,
      );
      final saat = Stopwatch()..start();
      final sonuc = await acici.ac(adres: 'http://10.255.255.1:8443/ac', kod: '123456');
      acici.kapat();

      expect(sonuc.durum, AgAcmaDurumu.yerelAgYok);
      expect(saat.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(sonuc.acildi, isFalse);
    });

    test('yerel ağ varsa yine deneniyor', () async {
      var soruldu = false;
      final acici = TahtaAgAcici(
        zamanAsimi: const Duration(milliseconds: 300),
        yerelAgKontrol: () async => soruldu = true,
      );
      final sonuc = await acici.ac(adres: 'http://10.255.255.1:8443/ac', kod: '123456');
      acici.kapat();

      expect(soruldu, isTrue);
      expect(sonuc.durum, AgAcmaDurumu.ulasilamadi);
    });

    test('aynı cihazdaki adres ağ denetiminden etkilenmiyor', () async {
      final sunucu = await _sunucuAc(durumKodu: 200, govde: {'tamam': true});
      final acici = TahtaAgAcici(yerelAgKontrol: () async => false);
      final sonuc = await acici.ac(adres: _adres(sunucu), kod: '123456');
      acici.kapat();
      await sunucu.close(force: true);

      expect(sonuc.acildi, isTrue);
    });

    test('KRİTİK: kilitlemede mobil veri açıkça söyleniyor', () async {
      final acici = TahtaAgAcici(yerelAgKontrol: () async => false);
      final sonuc = await acici.kilitle(adres: 'http://10.255.255.1:8443/kilitle', kod: '123456');
      acici.kapat();

      expect(sonuc.durum, AgAcmaDurumu.yerelAgYok);
      expect(sonuc.kullaniciMesaji, contains('mobil veri'));
      expect(sonuc.kullaniciMesaji, contains('"Kilitle"'));
    });

    test('arayüz adları: Wi-Fi/kablo/erişim noktası evet, hücresel/VPN hayır', () {
      for (final ad in ['wlan0', 'swlan0', 'eth0', 'en0', 'ap0', 'bridge100', 'p2p-wlan0-0']) {
        expect(TahtaAgAcici.yerelAgArayuzuMu(ad), isTrue, reason: ad);
      }
      for (final ad in ['rmnet_data0', 'ccmni0', 'pdp_ip0', 'tun0', 'dummy0', 'v4-rmnet_data0', 'lo']) {
        expect(TahtaAgAcici.yerelAgArayuzuMu(ad), isFalse, reason: ad);
      }
    });
  });
}
