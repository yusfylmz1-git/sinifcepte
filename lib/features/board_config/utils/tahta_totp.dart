import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Tahta kilidi için TOTP kodu üretir (RFC 6238).
///
/// ## Neden `otp` paketi değil, elle yazım
///
/// Üç sebep:
///
/// 1. `otp` paketi ~13 ay durgun ve "MAJOR BEHAVIOR CHANGE IN 3.1.0"
///    notu taşıyor. Kilit açma yolunda sessiz davranış değişikliği
///    kabul edilemez.
/// 2. `crypto` paketi zaten projede (`pubspec.yaml`) ve HMAC-SHA1
///    sağlıyor; yeni bağımlılık gerekmiyor.
/// 3. Tahta tarafı (Python) da aynı standardı elle uyguluyor. İki taraf
///    da elle yazarsa uyum riski kütüphane sürümlerine değil **teste**
///    bağlı kalır — ve test RFC 6238 Ek B vektörleriyle yapılıyor.
///
/// ## Karşı taraf
///
/// Python karşılığı: `sinifcepte-tahta/sinifcepte_tahta/cekirdek/totp.py`
/// (`kod_uret`). İki taraf aynı RFC vektörlerini geçmek zorundadır;
/// `test/tahta_totp_test.dart` bunu kanıtlar.
///
/// ## Saat kayması — bu sınıf tek başına yeterli değil
///
/// Tahta internetsiz çalışıyor, yani NTP yok. Tahtanın saati şaşarsa
/// TOTP **tamamen** çalışmaz: öğretmen doğru kodu girer, tahta
/// reddeder. Bu yüzden USB anahtar ve PIN yolları zorunludur — süs
/// değil, TOTP'nin doğasından gelen bir gereklilik.
class TahtaTotp {
  TahtaTotp._();

  /// RFC 6238 varsayılan zaman adımı (saniye).
  static const int adimSn = 30;

  /// Öğretmene gösterilen hane sayısı.
  static const int haneSayisi = 6;

  /// Base32 secret'i bayta çevirir.
  ///
  /// Dolgu (padding) tuzağı: idarecinin telefonu dolgusuz secret
  /// üretebilir. Dolgu tamamlanmazsa çözme başarısız olur ve tahta
  /// hiçbir öğretmeni tanımaz. Küçük harf, boşluk ve tire de kabul
  /// edilir — secret elle girilebiliyor.
  static Uint8List _secretCoz(String secretBase32) {
    final temiz = secretBase32
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase();

    if (temiz.isEmpty) {
      throw ArgumentError('TOTP secret\'i boş');
    }

    const alfabe = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var bitTamponu = 0;
    var bitSayisi = 0;
    final cikti = <int>[];

    for (final karakter in temiz.split('')) {
      if (karakter == '=') continue;
      final deger = alfabe.indexOf(karakter);
      if (deger < 0) {
        throw ArgumentError('TOTP secret\'i base32 değil: "$secretBase32"');
      }
      bitTamponu = (bitTamponu << 5) | deger;
      bitSayisi += 5;
      if (bitSayisi >= 8) {
        bitSayisi -= 8;
        cikti.add((bitTamponu >> bitSayisi) & 0xFF);
      }
    }

    if (cikti.isEmpty) {
      throw ArgumentError('TOTP secret\'i çözülemedi: "$secretBase32"');
    }

    return Uint8List.fromList(cikti);
  }

  /// Verilen an için TOTP kodunu üretir.
  ///
  /// [an] verilmezse şu an kullanılır. Test ve çapraz doğrulama için
  /// sabit bir an verilebilir.
  static String kodUret(
    String secretBase32, {
    DateTime? an,
    int hane = haneSayisi,
  }) {
    if (hane < 6 || hane > 10) {
      throw ArgumentError('Hane sayısı 6-10 arası olmalı, verilen: $hane');
    }

    final anahtar = _secretCoz(secretBase32);
    final saniye = (an ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final sayac = saniye ~/ adimSn;

    // RFC 4226: sayaç 8 baytlık big-endian.
    final sayacBaytlari = ByteData(8)..setUint64(0, sayac, Endian.big);

    final ozet =
        Hmac(sha1, anahtar).convert(sayacBaytlari.buffer.asUint8List()).bytes;

    // Dinamik kırpma (RFC 4226 §5.3): son baytın alt 4 biti ofseti verir.
    final ofset = ozet[ozet.length - 1] & 0x0F;
    final parca = ((ozet[ofset] & 0x7F) << 24) |
        ((ozet[ofset + 1] & 0xFF) << 16) |
        ((ozet[ofset + 2] & 0xFF) << 8) |
        (ozet[ofset + 3] & 0xFF);

    final bolen = _onunKuvveti(hane);
    return (parca % bolen).toString().padLeft(hane, '0');
  }

  /// Yeni TOTP secret'i üretir (base32, dolgusuz).
  ///
  /// İdareci bir öğretmen eklediğinde çağrılır; üretilen secret hem
  /// `okul_config`'e (tahta doğrulayacak) hem QR ile öğretmenin
  /// telefonuna (kod üretecek) gider.
  ///
  /// 20 bayt = 160 bit, RFC 4226'nın önerdiği uzunluk.
  /// `Random.secure()` işletim sisteminin entropi kaynağını kullanır:
  /// tahmin edilebilir secret, başkasının adına kilit açmak demekti.
  ///
  /// Python karşılığı: `cekirdek/totp.py::secret_uret`.
  static String secretUret({int baytSayisi = 20}) {
    const alfabe = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rastgele = Random.secure();

    // Base32: her 5 bit bir karakter. Dolgu (=) eklenmiyor; çözücü
    // tarafı zaten dolgusuzu kabul ediyor.
    final baytlar = List<int>.generate(baytSayisi, (_) => rastgele.nextInt(256));

    var bitTamponu = 0;
    var bitSayisi = 0;
    final cikti = StringBuffer();

    for (final bayt in baytlar) {
      bitTamponu = (bitTamponu << 8) | bayt;
      bitSayisi += 8;
      while (bitSayisi >= 5) {
        bitSayisi -= 5;
        cikti.write(alfabe[(bitTamponu >> bitSayisi) & 0x1F]);
      }
    }
    if (bitSayisi > 0) {
      cikti.write(alfabe[(bitTamponu << (5 - bitSayisi)) & 0x1F]);
    }

    return cikti.toString();
  }

  /// Kodun geçerli kalacağı saniye sayısı.
  ///
  /// Arayüzde geri sayım göstermek için: öğretmen kodu yazarken
  /// süresinin dolduğunu görmeli, yoksa "yanlış kod" sanır.
  static int kalanSaniye({DateTime? an}) {
    final saniye = (an ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return adimSn - (saniye % adimSn);
  }

  /// Tahtanın gösterdiği QR yükünü ayrıştırır.
  ///
  /// İki biçim destekleniyor:
  ///
  /// ```text
  /// SC1:{okulId}:{tahtaId}:{nonce}:{unixDakika}
  /// SC2:{okulId}:{tahtaId}:{nonce}:{unixDakika}:{ip}:{port}
  /// ```
  ///
  /// `SC2` tahtanın **yerel ağ sunucusu** çalışırken yazılıyor: telefon
  /// IP'ye doğrudan istek gönderip kilidi açabiliyor, öğretmen 6 hane
  /// yazmıyor (kullanıcı isteği, 18 Eylül 2026).
  ///
  /// İlk dört alan ikisinde de aynı — eski telefonlar `SC2`'yi
  /// okuyamaz ama yeni telefonlar `SC1`'i okuyabilir, yani biçim
  /// ileriye doğru güvenli.
  ///
  /// Geçersizse `null` döner — çağıran taraf kullanıcıya "bu QR
  /// SınıfCepte tahtasına ait değil" demelidir. Sessizce çökmek, yanlış
  /// QR tarayan öğretmene hiçbir şey anlatmaz.
  static TahtaQrYuku? qrAyristir(String ham) {
    final parcalar = ham.trim().split(':');
    if (parcalar.length < 5) return null;

    final onek = parcalar[0];
    if (onek != 'SC1' && onek != 'SC2') return null;

    // Alan sayısı öneke uymalı: `SC1`'e fazladan alan eklenmiş bir
    // QR bozuk demektir, sessizce kabul edilmemeli.
    if (onek == 'SC1' && parcalar.length != 5) return null;
    if (onek == 'SC2' && parcalar.length != 7) return null;

    final dakika = int.tryParse(parcalar[4]);
    if (dakika == null) return null;

    if (parcalar[1].isEmpty || parcalar[2].isEmpty) return null;

    String ip = '';
    int? port;
    if (onek == 'SC2') {
      ip = parcalar[5].trim();
      port = int.tryParse(parcalar[6]);

      // IP veya port bozuksa ağ yolu kullanılamaz ama QR'ın geri
      // kalanı geçerli: 6 hane yolu çalışsın diye `null` DÖNMÜYORUZ.
      if (!_ipGecerliMi(ip) || port == null || port <= 0 || port > 65535) {
        ip = '';
        port = null;
      }
    }

    return TahtaQrYuku(
      okulId: parcalar[1],
      tahtaId: parcalar[2],
      nonce: parcalar[3],
      unixDakika: dakika,
      ip: ip,
      port: port,
    );
  }

  /// Kaba IPv4 denetimi.
  ///
  /// Tam doğrulama gerekmiyor: değer yalnızca bir HTTP isteğinde
  /// kullanılıyor ve yanlışsa istek başarısız olup 6 hane yoluna
  /// düşülüyor. Amaç, açıkça saçma değerleri (boş, harf içeren)
  /// elemek.
  /// Adres YEREL AĞDA mı?
  ///
  /// ## Neden biçim denetimi yetmiyor
  ///
  /// İlk sürüm yalnızca "dört parça, her biri 0-255" diye bakıyordu.
  /// `8.8.8.8` de, bir saldırganın sunucusu da geçiyordu.
  ///
  /// Saldırı (bağımsız incelemede bildirildi, 19 Eylül 2026'da
  /// doğrulandı): öğrenci kendi telefonunda sahte bir `SC2` karekodu
  /// gösterir — `okulId` gerçek kurum kodudur, yani okul denetimi
  /// geçer. Öğretmen "tahtadaki karekod" sanıp okutur ve telefonu
  /// **canlı TOTP kodunu** saldırganın sunucusuna POST eder. Kod 30
  /// saniye geçerli; saldırgan onu gerçek tahtaya yazar.
  ///
  /// Kilit açma kodu tahtaya gitmeli, internete değil. Bu yüzden
  /// yalnızca **özel ağ** adresleri kabul ediliyor (RFC 1918 + bağlantı
  /// yerel + geri döngü).
  ///
  /// Yanlış tarafta hata yapmak: geçerli bir tahtayı reddetmek
  /// öğretmeni 6 hane yoluna düşürür (akış devam eder). Sahte bir
  /// adresi kabul etmek ise kodu sızdırır ve geri dönüşü yoktur.
  static bool _ipGecerliMi(String ip) {
    final parcalar = ip.split('.');
    if (parcalar.length != 4) return false;

    final sayilar = <int>[];
    for (final p in parcalar) {
      // Baştaki sıfır reddediliyor: `010.0.0.1` bazı çözümleyicilerde
      // sekizlik okunur ve farklı bir adrese gider.
      if (p.isEmpty || (p.length > 1 && p.startsWith('0'))) return false;
      final sayi = int.tryParse(p);
      if (sayi == null || sayi < 0 || sayi > 255) return false;
      sayilar.add(sayi);
    }

    return _ozelAgMi(sayilar);
  }

  /// RFC 1918 özel ağ, bağlantı yerel veya geri döngü mü?
  ///
  /// Okul ağları bu aralıklarda: FATİH altyapısı `10.x` ya da
  /// `192.168.x`, bazı okullarda `172.16-31.x`.
  static bool _ozelAgMi(List<int> o) {
    // 10.0.0.0/8
    if (o[0] == 10) return true;
    // 172.16.0.0/12
    if (o[0] == 172 && o[1] >= 16 && o[1] <= 31) return true;
    // 192.168.0.0/16
    if (o[0] == 192 && o[1] == 168) return true;
    // 169.254.0.0/16 — DHCP yokken kendi kendine atanan adres
    if (o[0] == 169 && o[1] == 254) return true;
    // 127.0.0.0/8 — geri döngü; testler ve aynı makinede çalışma
    if (o[0] == 127) return true;
    return false;
  }

  static int _onunKuvveti(int kuvvet) {
    var sonuc = 1;
    for (var i = 0; i < kuvvet; i++) {
      sonuc *= 10;
    }
    return sonuc;
  }
}

/// Tahta ekranındaki QR kodun içeriği.
class TahtaQrYuku {
  final String okulId;
  final String tahtaId;
  final String nonce;
  final int unixDakika;

  /// Tahtanın yerel ağ adresi — `SC2` biçiminde gelir, yoksa boş.
  ///
  /// Doluysa telefon kilidi doğrudan açabilir; öğretmen 6 hane
  /// yazmaz. Boşsa (eski tahta, ağ yok, port dolu) 6 hane yolu
  /// kullanılır.
  final String ip;

  /// Tahtanın dinlediği port; `ip` boşsa `null`.
  final int? port;

  const TahtaQrYuku({
    required this.okulId,
    required this.tahtaId,
    required this.nonce,
    required this.unixDakika,
    this.ip = '',
    this.port,
  });

  /// Tahta ağdan açılabilir mi?
  ///
  /// Bu bir **kolaylık**, şart değil: `false` olduğunda 6 hane yolu
  /// çalışmaya devam ediyor.
  bool get agdanAcilabilir => ip.isNotEmpty && port != null;

  /// Açma isteğinin gideceği adres.
  String get acmaAdresi => 'http://$ip:$port/ac';

  /// Öğretmenin okulu tahtanın okuluyla aynı mı?
  ///
  /// Farklıysa kod üretilmemeli: başka okulun tahtasına ait QR
  /// tarandığında sessizce çalışmayan bir kod vermek yerine sebebi
  /// söylenmeli.
  bool ayniOkul(String ogretmeninOkulId) => okulId == ogretmeninOkulId;

  /// Karekod TAZE mi? (varsayılan tolerans: 2 dakika)
  ///
  /// ## Neden gerekli
  ///
  /// `unixDakika` ayrıştırılıyordu ama **hiçbir yerde
  /// kullanılmıyordu** (bağımsız incelemede bildirildi, 19 Eylül
  /// 2026'da doğrulandı). Yani tahtanın ekranından çekilmiş bir
  /// fotoğraf süresiz geçerliydi.
  ///
  /// Tahta karekodu 30 saniyede bir yeniliyor; bunun tek sebebi
  /// fotoğrafın tekrar kullanılmasını kısıtlamaktı ve telefon o
  /// koruma­yı hiç uygulamıyordu.
  ///
  /// ## Neden 2 dakika, 30 saniye değil
  ///
  /// Tahta ile telefonun saatleri birkaç saniye kayabilir, öğretmen
  /// karekodu okutup ekrana bakana kadar da zaman geçer. Sınır çok
  /// darsa geçerli karekodlar reddedilir ve öğretmen sebebini
  /// anlamaz. 2 dakika, fotoğrafı anlamlı biçimde kısıtlarken
  /// meşru kullanımı bozmuyor.
  bool tazeMi({DateTime? an, Duration tolerans = const Duration(minutes: 2)}) {
    final simdi = (an ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final simdikiPencere = simdi ~/ TahtaTotp.adimSn;
    final fark = (simdikiPencere - unixDakika).abs();
    return fark * TahtaTotp.adimSn <= tolerans.inSeconds;
  }

  @override
  String toString() =>
      'TahtaQrYuku(okul: $okulId, tahta: $tahtaId, dakika: $unixDakika'
      '${agdanAcilabilir ? ", ag: $ip:$port" : ""})';
}
