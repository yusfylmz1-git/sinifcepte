import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Tahtayı yerel ağ üzerinden açar ya da kilitler — öğretmen 6 hane
/// yazmadan.
///
/// ## Neden var
///
/// Kullanıcı tespiti (18 Eylül 2026): *"Tahtada internet varsa QR ile
/// okuma olmalı, kimse kodla uğraşmaz."*
///
/// QR okutulunca telefon tahtanın adresini öğreniyor ve kodu doğrudan
/// gönderiyor. Öğretmen hiçbir şey yazmıyor.
///
/// Kilitleme (1 Ekim 2026, kullanıcı kararı): ders bitince öğretmen
/// telefondan da kilitleyebiliyor. Aynı gövde (telefon kodu): tahta
/// kodsuz kilitleme isteğini reddediyor, yoksa aynı ağdaki bir öğrenci
/// dersin ortasında tahtayı tekrar tekrar kilitleyebilirdi.
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
/// Açmada çağıran taraf **6 hane yoluna** düşmeli; kilitlemede tahtadaki
/// "Kilitle" düğmesi aynı işi yapıyor.
class TahtaAgAcici {
  TahtaAgAcici({
    HttpClient? istemci,
    Duration? zamanAsimi,
    Future<bool> Function()? yerelAgKontrol,
  })  : _istemci = istemci ?? HttpClient(),
        _zamanAsimi = zamanAsimi ?? const Duration(seconds: 4),
        _yerelAgKontrol = yerelAgKontrol ?? yerelAgVarMi;

  final HttpClient _istemci;

  /// Telefon yerel bir ağda mı (testte değiştirilebilir).
  final Future<bool> Function() _yerelAgKontrol;

  /// Telefon Wi-Fi'de (ya da kabloyla) bir yerel ağda mı?
  ///
  /// ## Neden (4 Ekim 2026, saha bilgisi)
  ///
  /// Kullanıcı: *"Öğretmenler okul ağına hiç bağlanmıyor, kendi
  /// internetlerini kullanıyor."* Yalnız mobil verideki telefon tahtanın
  /// okul ağındaki adresine ulaşamaz. Yine de deneniyordu: her karekod
  /// okutuşunda 4 saniye "gönderiliyor", ardından kırmızı "ulaşılamadı"
  /// — sistem bozukmuş gibi görünüyordu. Kod zaten ekranda.
  ///
  /// Arayüz adına bakılıyor; paket eklemeden. Bilinmiyorsa `true`
  /// (denemenin zararı yalnız birkaç saniye). Masaüstünde hep `true`.
  static Future<bool> yerelAgVarMi() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return true;
    try {
      final arayuzler =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      return arayuzler.any((a) => yerelAgArayuzuMu(a.name));
    } catch (_) {
      return true;
    }
  }

  /// Arayüz adı bir yerel ağ mı: Wi-Fi (`wlan0`, iOS `en0`), kablo
  /// (`eth0`), telefonun ya da tahtanın erişim noktası (`ap0`, `swlan0`,
  /// `bridge100`). Hücresel (`rmnet_data0`, `ccmni0`, `pdp_ip0`) ve VPN
  /// (`tun0`) değil.
  static bool yerelAgArayuzuMu(String ad) {
    final a = ad.toLowerCase();
    const yerel = [
      'wlan', 'swlan', 'wifi', 'wi-fi', 'eth', 'en', 'ap', 'bridge', 'p2p',
    ];
    return yerel.any(a.startsWith);
  }

  /// Ağ beklemesi için üst sınır.
  ///
  /// Kısa tutuluyor: öğretmen ders başında bekliyor ve ağ yoksa 6
  /// hane yoluna hızlıca düşmesi gerekiyor. 4 saniye, yerel ağdaki
  /// bir isteğin fazlasıyla üstünde.
  final Duration _zamanAsimi;

  /// Kodu tahtaya gönderip kilidi açar.
  ///
  /// Dönen sonuç üç durumu ayırıyor: açıldı, tahta reddetti, ulaşılamadı.
  /// Üçü farklı mesaj gerektiriyor — "ulaşılamadı" durumunda öğretmene
  /// "kodunuz yanlış" demek yanlış yönlendirme olurdu.
  Future<AgAcmaSonucu> ac({
    required String adres,
    required String kod,
  }) =>
      _gonder(adres: adres, kod: kod, islem: AgIslem.ac);

  /// Tahtayı kilitler (`POST /kilitle`, tahta 0.7.1+). Gövde açmayla aynı.
  Future<AgAcmaSonucu> kilitle({
    required String adres,
    required String kod,
  }) =>
      _gonder(adres: adres, kod: kod, islem: AgIslem.kilitle);

  Future<AgAcmaSonucu> _gonder({
    required String adres,
    required String kod,
    required AgIslem islem,
  }) async {
    Uri uri;
    try {
      uri = Uri.parse(adres);
    } on FormatException {
      return AgAcmaSonucu._(durum: AgAcmaDurumu.ulasilamadi, islem: islem);
    }

    // Mobil verideyse hiç deneme: 4 sn bekletip hata göstermesin.
    // Aynı cihazdaki adres (test, masaüstü deneme) ağdan bağımsız.
    final ayniCihaz = uri.host == '127.0.0.1' || uri.host == 'localhost';
    if (!ayniCihaz && !await _yerelAgKontrol()) {
      return AgAcmaSonucu._(durum: AgAcmaDurumu.yerelAgYok, islem: islem);
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

      // Eski tahta (0.7.0 ve öncesi) `/kilitle` bilmiyor: 404.
      if (yanit.statusCode == 404 && islem == AgIslem.kilitle) {
        return AgAcmaSonucu._(
          durum: AgAcmaDurumu.reddedildi,
          islem: islem,
          mesaj: 'Bu tahtanın yazılımı telefondan kilitlemeyi henüz '
              'desteklemiyor; okul idaresi tahtayı güncellemeli.',
        );
      }

      if (yanit.statusCode != 200) {
        debugPrint('Tahta ${yanit.statusCode} döndü');
        return AgAcmaSonucu._(durum: AgAcmaDurumu.reddedildi, islem: islem);
      }

      final veri = jsonDecode(govde) as Map<String, dynamic>;
      final tamam = veri['tamam'] == true;
      final mesaj = (veri['mesaj'] as String?) ?? '';

      return AgAcmaSonucu._(
        durum: tamam ? AgAcmaDurumu.acildi : AgAcmaDurumu.reddedildi,
        islem: islem,
        mesaj: mesaj,
      );
    } catch (e) {
      // Ağ hataları burada toplanıyor: bağlantı yok, zaman aşımı,
      // bozuk yanıt. Hepsi aynı sonuca varıyor — 6 hane yoluna düş.
      //
      // `debugPrint` release'de susuyor ama bu bilinçli: sahada
      // öğretmenin göreceği şey mesaj, günlük değil.
      debugPrint('Tahtaya ağdan ulaşılamadı: $e');
      return AgAcmaSonucu._(durum: AgAcmaDurumu.ulasilamadi, islem: islem);
    }
  }

  void kapat() => _istemci.close(force: true);
}

/// İsteğin türü: mesajlar buna göre seçiliyor.
enum AgIslem { ac, kilitle }

enum AgAcmaDurumu {
  /// Tahta kodu kabul etti (açıldı ya da kilitlendi).
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

  /// Telefon yalnız mobil veride: hiç denenmedi (öğretmenlerin olağan
  /// hâli). Açmada uyarı gösterilmez, kod zaten ekranda.
  yerelAgYok,
}

class AgAcmaSonucu {
  const AgAcmaSonucu._({
    required this.durum,
    this.islem = AgIslem.ac,
    this.mesaj = '',
  });

  final AgAcmaDurumu durum;
  final AgIslem islem;

  /// Tahtanın döndüğü mesaj ("Hoş geldiniz, ..." gibi).
  final String mesaj;

  bool get acildi => durum == AgAcmaDurumu.acildi;

  /// İstek tahtada kabul edildi mi (açma ya da kilitleme)?
  bool get basarili => durum == AgAcmaDurumu.acildi;

  /// Öğretmene gösterilecek metin.
  ///
  /// Üç durum ayrı mesaj alıyor: "ulaşılamadı" durumunda kodu
  /// suçlamak yanlış yönlendirme olurdu.
  String get kullaniciMesaji {
    if (islem == AgIslem.kilitle) {
      switch (durum) {
        case AgAcmaDurumu.acildi:
          return mesaj.isEmpty ? 'Tahta kilitlendi.' : mesaj;
        case AgAcmaDurumu.reddedildi:
          return mesaj.isEmpty
              ? 'Tahta kilitleme isteğini kabul etmedi. Tahtadaki '
                  '"Kilitle" düğmesini kullanın.'
              : mesaj;
        case AgAcmaDurumu.ulasilamadi:
          return 'Tahtaya ağdan ulaşılamadı. Tahtadaki "Kilitle" '
              'düğmesini kullanın.';
        case AgAcmaDurumu.yerelAgYok:
          return 'Telefonunuz okulun ağında değil (mobil veri). '
              'Tahtadaki "Kilitle" düğmesini kullanın.';
      }
    }
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
      case AgAcmaDurumu.yerelAgYok:
        return 'Aşağıdaki kodu tahtaya girin.';
    }
  }
}
