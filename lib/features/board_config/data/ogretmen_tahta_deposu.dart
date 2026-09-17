import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Öğretmenin kendi tahta açma bilgisi (öğretmen tarafı).
///
/// ## İdareci tarafından farklı
///
/// `TahtaOgretmenDeposu` idarecinin telefonunda **tüm okulun**
/// öğretmenlerini tutar. Bu sınıf öğretmenin telefonunda **yalnızca
/// kendisini** tutar: kod, ad, okul ve TOTP secret'ı.
///
/// ## Secret nereden geliyor
///
/// İdareci öğretmeni ekler, uygulama secret üretir ve bir QR gösterir
/// (`SCT1:{okulId}:{kod}:{ad}:{secret}`). Öğretmen o QR'ı kendi
/// telefonunda okutur ve bu depoya kaydeder. Google Authenticator
/// mantığı.
///
/// ## Neden güvenli depo
///
/// Secret, öğretmenin tahtayı açma yetkisidir. `shared_preferences` düz
/// metin saklar ve cihaz yedeklemelerine dahil olur; yedeği okuyan biri
/// o öğretmenin adına kilidi açabilirdi.
class OgretmenTahtaDeposu {
  OgretmenTahtaDeposu({FlutterSecureStorage? depo})
      : _depo = depo ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _depo;

  static const String _kayit = 'ogretmen_tahta_kaydi_v1';

  /// Kurulum QR yükünün öneki.
  ///
  /// Tahtanın gösterdiği `SC1`'den **farklı**: o yük kilit açma isteği,
  /// bu yük kurulum bilgisi taşır. Öğretmen yanlış QR'ı okutursa
  /// anlamsız hata görmek yerine ne yapması gerektiğini duymalı.
  static const String kurulumOneki = 'SCT1';

  /// Kayıtlı bilgi var mı?
  Future<bool> kayitliMi() async {
    try {
      return await _depo.containsKey(key: _kayit);
    } catch (e, stackTrace) {
      debugPrint('kayitliMi hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Kayıtlı bilgiyi okur; yoksa `null`.
  Future<OgretmenTahtaKaydi?> oku() async {
    try {
      final ham = await _depo.read(key: _kayit);
      if (ham == null || ham.isEmpty) return null;

      final cozulen = jsonDecode(ham);
      if (cozulen is! Map<String, dynamic>) return null;

      final kayit = OgretmenTahtaKaydi.fromJson(cozulen);
      // Secret'ı olmayan kayıt işe yaramaz: kod üretilemez.
      if (kayit.totpSecret.isEmpty || kayit.kod.isEmpty) return null;
      return kayit;
    } catch (e, stackTrace) {
      debugPrint('Öğretmen tahta kaydı okuma hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Kurulum QR yükünü ayrıştırıp kaydeder.
  ///
  /// Biçim: `SCT1:{okulId}:{kod}:{ad}:{secret}`
  ///
  /// Geçersizse `null` döner — çağıran taraf kullanıcıya sebebini
  /// söylemeli. Sessizce başarısız olmak, öğretmenin defalarca aynı
  /// QR'ı okutmasına yol açar.
  Future<OgretmenTahtaKaydi?> qrIleKaydet(String hamYuk) async {
    final kayit = qrAyristir(hamYuk);
    if (kayit == null) return null;

    try {
      await _depo.write(key: _kayit, value: jsonEncode(kayit.toJson()));
      return kayit;
    } catch (e, stackTrace) {
      debugPrint('Öğretmen tahta kaydı yazma hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Kurulum yükünü ayrıştırır (kaydetmez).
  ///
  /// Ayrı metot: arayüz önce ayrıştırıp kullanıcıya "şu okul, şu kod —
  /// doğru mu?" diye gösterebilir.
  static OgretmenTahtaKaydi? qrAyristir(String hamYuk) {
    final parcalar = hamYuk.trim().split(':');
    if (parcalar.length != 5) return null;
    if (parcalar[0] != kurulumOneki) return null;

    final okulId = parcalar[1].trim();
    final kod = parcalar[2].trim();
    final ad = parcalar[3].trim();
    final secret = parcalar[4].trim();

    if (okulId.isEmpty || kod.isEmpty || secret.isEmpty) return null;

    return OgretmenTahtaKaydi(
      okulId: okulId,
      kod: kod,
      ad: ad,
      totpSecret: secret,
    );
  }

  /// Kaydı siler (öğretmen okul değiştirdi, cihaz devredildi).
  Future<bool> sil() async {
    try {
      await _depo.delete(key: _kayit);
      return true;
    } catch (e, stackTrace) {
      debugPrint('Öğretmen tahta kaydı silme hatası: $e\n$stackTrace');
      return false;
    }
  }
}

/// Öğretmenin kendi tahta açma bilgisi.
class OgretmenTahtaKaydi {
  /// Kanonik okul kimliği. Tahtanın QR'ındaki okulla eşleşmeli.
  final String okulId;

  /// Tahtada elle girilebilen kısa kod (`AYILMAZ`).
  final String kod;

  final String ad;

  /// TOTP secret'ı (base32). Bu değer ekranda **gösterilmez**.
  final String totpSecret;

  const OgretmenTahtaKaydi({
    required this.okulId,
    required this.kod,
    required this.ad,
    required this.totpSecret,
  });

  factory OgretmenTahtaKaydi.fromJson(Map<String, dynamic> j) =>
      OgretmenTahtaKaydi(
        okulId: (j['okulId'] as String?) ?? '',
        kod: (j['kod'] as String?) ?? '',
        ad: (j['ad'] as String?) ?? '',
        totpSecret: (j['totpSecret'] as String?) ?? '',
      );

  Map<String, Object?> toJson() => {
        'okulId': okulId,
        'kod': kod,
        'ad': ad,
        'totpSecret': totpSecret,
      };
}
