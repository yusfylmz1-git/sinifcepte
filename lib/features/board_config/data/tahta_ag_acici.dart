import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Tahtayı yerel ağ üzerinden açar — öğretmen 6 hane yazmadan.
///
/// ## Neden var
///
/// Kullanıcı tespiti (18 Eylül 2026): *"Tahtada internet varsa QR ile
/// okuma olmalı, kimse kodla uğraşmaz."*
///
/// QR okutulunca telefon tahtanın adresini öğreniyor ve kodu doğrudan
/// gönderiyor. Öğretmen hiçbir şey yazmıyor.
///
/// ## Bulut yok
///
/// İstek telefondan tahtaya **doğrudan** gidiyor: okul ağı içinde,
/// internet gerekmeden. Firestore maliyeti yok, gecikme yok ve "tahta
/// ağa çıkmaz" argümanı korunuyor.
///
/// ## Başarısızlık normal
///
/// Bu bir **kolaylık katmanı**. Şu durumlarda çalışmaz ve çalışmaması
/// beklenir:
///
/// - Telefonun Wi-Fi'si kapalı (mobil veride tahtaya erişilemez)
/// - FATİH ağında AP izolasyonu açık (cihazlar birbirini görmez)
/// - Misafir ağı ile tahta ağı ayrı
/// - Tahtanın IP'si DHCP ile değişmiş ve QR bayatlamış
///
/// Hepsinde çağıran taraf **6 hane yoluna** düşmeli; ekran kodu
/// gösterip öğretmenin elle girmesini istemeli.
class TahtaAgAcici {
  TahtaAgAcici({HttpClient? istemci, Duration? zamanAsimi})
      : _istemci = istemci ?? HttpClient(),
        _zamanAsimi = zamanAsimi ?? const Duration(seconds: 4);

  final HttpClient _istemci;

  /// Ağ beklemesi için üst sınır.
  ///
  /// Kısa tutuluyor: öğretmen ders başında bekliyor ve ağ yoksa 6
  /// hane yoluna hızlıca düşmesi gerekiyor. 4 saniye, yerel ağdaki
  /// bir isteğin fazlasıyla üstünde.
  final Duration _zamanAsimi;

  /// Kodu tahtaya gönderir.
  ///
  /// Dönen sonuç üç durumu ayırıyor: açıldı, tahta reddetti, ulaşılamadı.
  /// Üçü farklı mesaj gerektiriyor — "ulaşılamadı" durumunda öğretmene
  /// "kodunuz yanlış" demek yanlış yönlendirme olurdu.
  Future<AgAcmaSonucu> ac({
    required String adres,
    required String kod,
  }) async {
    Uri uri;
    try {
      uri = Uri.parse(adres);
    } on FormatException {
      return const AgAcmaSonucu._(durum: AgAcmaDurumu.ulasilamadi);
    }

    try {
      final istek = await _istemci
          .postUrl(uri)
          .timeout(_zamanAsimi);

      istek.headers.contentType = ContentType.json;

      // `contentLength` AÇIKÇA veriliyor.
      //
      // Verilmezse Dart `Transfer-Encoding: chunked` kullanıyor ve
      // `Content-Length` başlığını hiç göndermiyor. Tahtanın
      // `BaseHTTPRequestHandler` tabanlı sunucusu o başlığı okuyor,
      // bulamayınca uzunluğu 0 sayıp **HTTP 400** dönüyor — kodu hiç
      // doğrulamadan.
      //
      // Sahada bu, "tahta kodu kabul etmedi" olarak görünüyordu ve
      // öğretmen kodu tekrar tekrar deniyordu. Oysa kod doğruydu;
      // tahta onu hiç görmemişti (19 Eylül 2026, cihazda logcat ile
      // ölçüldü: kod="167580" gitti, tahta 400 döndü).
      //
      // Testler bunu kaçırmıştı: `dart:io` `HttpServer` chunked'ı
      // saydam biçimde çözüyor, Python'un sunucusu çözmüyor.
      final istekGovdesi = utf8.encode(jsonEncode({'kod': kod}));
      istek.contentLength = istekGovdesi.length;
      istek.add(istekGovdesi);

      final yanit = await istek.close().timeout(_zamanAsimi);
      final govde = await yanit
          .transform(utf8.decoder)
          .join()
          .timeout(_zamanAsimi);

      if (yanit.statusCode != 200) {
        debugPrint('Tahta ${yanit.statusCode} döndü');
        return const AgAcmaSonucu._(durum: AgAcmaDurumu.reddedildi);
      }

      final veri = jsonDecode(govde) as Map<String, dynamic>;
      final tamam = veri['tamam'] == true;
      final mesaj = (veri['mesaj'] as String?) ?? '';

      return AgAcmaSonucu._(
        durum: tamam ? AgAcmaDurumu.acildi : AgAcmaDurumu.reddedildi,
        mesaj: mesaj,
      );
    } catch (e) {
      // Ağ hataları burada toplanıyor: bağlantı yok, zaman aşımı,
      // bozuk yanıt. Hepsi aynı sonuca varıyor — 6 hane yoluna düş.
      //
      // `debugPrint` release'de susuyor ama bu bilinçli: sahada
      // öğretmenin göreceği şey mesaj, günlük değil.
      debugPrint('Tahtaya ağdan ulaşılamadı: $e');
      return const AgAcmaSonucu._(durum: AgAcmaDurumu.ulasilamadi);
    }
  }

  void kapat() => _istemci.close(force: true);
}

enum AgAcmaDurumu {
  /// Tahta kodu kabul etti, kilit açıldı.
  acildi,

  /// Tahtaya ulaşıldı ama kod kabul edilmedi.
  ///
  /// Sebep tahtada: kod yanlış, süresi geçmiş veya öğretmen listede
  /// yok. Telefon sebebi bilmiyor ve bilmemeli.
  reddedildi,

  /// Tahtaya hiç ulaşılamadı.
  ///
  /// Wi-Fi kapalı, AP izolasyonu, yanlış IP, tahta kapalı. Öğretmene
  /// "kod yanlış" DEMEMELİ — 6 hane yolu önerilmeli.
  ulasilamadi,
}

class AgAcmaSonucu {
  const AgAcmaSonucu._({required this.durum, this.mesaj = ''});

  final AgAcmaDurumu durum;

  /// Tahtanın döndüğü mesaj ("Hoş geldiniz, ..." gibi).
  final String mesaj;

  bool get acildi => durum == AgAcmaDurumu.acildi;

  /// Öğretmene gösterilecek metin.
  ///
  /// Üç durum ayrı mesaj alıyor: "ulaşılamadı" durumunda kodu
  /// suçlamak yanlış yönlendirme olurdu.
  String get kullaniciMesaji {
    switch (durum) {
      case AgAcmaDurumu.acildi:
        return mesaj.isEmpty ? 'Tahta açıldı.' : mesaj;
      case AgAcmaDurumu.reddedildi:
        return mesaj.isEmpty
            ? 'Tahta kodu kabul etmedi. Aşağıdaki kodu elle girin.'
            : mesaj;
      case AgAcmaDurumu.ulasilamadi:
        return 'Tahtaya ağdan ulaşılamadı. Aşağıdaki kodu tahtaya '
            'elle girin.';
    }
  }
}
