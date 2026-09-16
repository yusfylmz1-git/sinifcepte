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
  /// Biçim: `SC1:{okulId}:{tahtaId}:{nonce}:{unixDakika}`
  ///
  /// Geçersizse `null` döner — çağıran taraf kullanıcıya "bu QR
  /// SınıfCepte tahtasına ait değil" demelidir. Sessizce çökmek, yanlış
  /// QR tarayan öğretmene hiçbir şey anlatmaz.
  static TahtaQrYuku? qrAyristir(String ham) {
    final parcalar = ham.trim().split(':');
    if (parcalar.length != 5) return null;
    if (parcalar[0] != 'SC1') return null;

    final dakika = int.tryParse(parcalar[4]);
    if (dakika == null) return null;

    if (parcalar[1].isEmpty || parcalar[2].isEmpty) return null;

    return TahtaQrYuku(
      okulId: parcalar[1],
      tahtaId: parcalar[2],
      nonce: parcalar[3],
      unixDakika: dakika,
    );
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

  const TahtaQrYuku({
    required this.okulId,
    required this.tahtaId,
    required this.nonce,
    required this.unixDakika,
  });

  /// Öğretmenin okulu tahtanın okuluyla aynı mı?
  ///
  /// Farklıysa kod üretilmemeli: başka okulun tahtasına ait QR
  /// tarandığında sessizce çalışmayan bir kod vermek yerine sebebi
  /// söylenmeli.
  bool ayniOkul(String ogretmeninOkulId) => okulId == ogretmeninOkulId;

  @override
  String toString() =>
      'TahtaQrYuku(okul: $okulId, tahta: $tahtaId, dakika: $unixDakika)';
}
