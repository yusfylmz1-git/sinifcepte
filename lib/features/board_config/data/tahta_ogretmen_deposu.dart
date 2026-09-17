import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/turkish_text.dart';
import '../models/okul_config_model.dart';
import '../utils/tahta_totp.dart';

/// Tahta açma yetkisi olan öğretmenlerin listesi (idareci tarafı).
///
/// ## Neden güvenli depoda
///
/// Kayıtlar her öğretmenin **TOTP secret'ını** taşıyor. Secret, o
/// öğretmenin tahtayı açma yetkisidir: sızarsa başkası onun adına
/// kilidi açabilir. `shared_preferences` düz metin saklar ve cihaz
/// yedeklemelerine dahil olur — bu liste için yanlış yer.
///
/// ## Neden idareci üretiyor (kullanıcı kararı)
///
/// Alternatifler öğretmenin kendi secret'ını üretip idareciye
/// göndermesi ya da sunucu tarafında üretim olurdu. İlki 40 öğretmenli
/// okulda elle toplama zahmeti, ikincisi yeni Cloud Function ve yeni
/// bulut koleksiyonu (maliyet + karmaşıklık) demekti.
///
/// Seçilen yol: idareci ekler, uygulama secret üretir, öğretmen QR
/// okutup kendi telefonuna kaydeder — Google Authenticator mantığı.
///
/// ## Bu liste buluta gitmiyor
///
/// Yalnızca `okul_config` dosyasına (imzalı, flash bellekle) ve QR
/// yoluyla öğretmenin telefonuna. Firestore'a yazılmıyor: secret'ın
/// bulutta durması için hiçbir sebep yok ve KVKK yüzeyini büyütürdü.
class TahtaOgretmenDeposu {
  TahtaOgretmenDeposu({FlutterSecureStorage? depo})
      : _depo = depo ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _depo;

  static const String _liste = 'tahta_ogretmenleri_v1';

  /// Kayıtlı öğretmenleri okur.
  Future<List<PanoOgretmeni>> oku() async {
    try {
      final ham = await _depo.read(key: _liste);
      if (ham == null || ham.isEmpty) return const [];

      final cozulen = jsonDecode(ham);
      if (cozulen is! List) {
        debugPrint('Öğretmen listesi bozuk (liste değil), boş dönülüyor');
        return const [];
      }

      return cozulen
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => PanoOgretmeni(
              kod: (m['kod'] as String?) ?? '',
              ad: (m['ad'] as String?) ?? '',
              totpSecret: (m['totpSecret'] as String?) ?? '',
              pinHash: (m['pinHash'] as String?) ?? '',
            ),
          )
          .where((o) => o.kod.isNotEmpty)
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Öğretmen listesi okuma hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Yeni öğretmen ekler ve TOTP secret'ını üretir.
  ///
  /// Kod verilmezse addan türetilir. Aynı kod varsa **eklemez**: mevcut
  /// öğretmenin secret'ını kazara değiştirmek, onun telefonundaki kaydı
  /// geçersiz kılar ve öğretmen sebebini anlamaz.
  ///
  /// Dönen kayıt secret'ı taşır; çağıran taraf QR göstermek için
  /// kullanır.
  Future<PanoOgretmeni?> ekle({
    required String ad,
    String? kod,
  }) async {
    final temizAd = ad.trim();
    if (temizAd.isEmpty) return null;

    final mevcut = await oku();
    final yeniKod = (kod?.trim().isNotEmpty ?? false)
        ? kod!.trim().toUpperCase()
        : _kodUret(temizAd, mevcut);

    if (mevcut.any((o) => o.kod.toUpperCase() == yeniKod)) {
      debugPrint('Öğretmen kodu zaten var: $yeniKod');
      return null;
    }

    final kayit = PanoOgretmeni(
      kod: yeniKod,
      ad: temizAd,
      totpSecret: _secretUret(),
    );

    final basarili = await _yaz([...mevcut, kayit]);
    return basarili ? kayit : null;
  }

  /// Öğretmeni siler.
  ///
  /// Silindikten sonra üretilen `okul_config` onu içermez; ama
  /// tahtadaki ESKİ dosya hâlâ geçerlidir. Çağıran taraf idareciye
  /// "yeni dosyayı tahtalara götürün" demelidir.
  Future<bool> sil(String kod) async {
    final mevcut = await oku();
    final kalan = mevcut
        .where((o) => o.kod.toUpperCase() != kod.trim().toUpperCase())
        .toList();

    if (kalan.length == mevcut.length) return false;
    return _yaz(kalan);
  }

  /// Bir öğretmenin secret'ını yeniler.
  ///
  /// Telefonu değişen veya secret'ı sızan öğretmen için. Eski secret
  /// geçersiz olur; öğretmen yeni QR'ı okutmak zorunda.
  Future<PanoOgretmeni?> secretYenile(String kod) async {
    final mevcut = await oku();
    final index = mevcut.indexWhere(
      (o) => o.kod.toUpperCase() == kod.trim().toUpperCase(),
    );
    if (index < 0) return null;

    final eski = mevcut[index];
    final yeni = PanoOgretmeni(
      kod: eski.kod,
      ad: eski.ad,
      totpSecret: _secretUret(),
      pinHash: eski.pinHash,
    );

    final liste = [...mevcut]..[index] = yeni;
    final basarili = await _yaz(liste);
    return basarili ? yeni : null;
  }

  /// Tümünü siler (hesap silme / KVKK).
  Future<bool> temizle() async {
    try {
      await _depo.delete(key: _liste);
      return true;
    } catch (e, stackTrace) {
      debugPrint('Öğretmen listesi temizleme hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Öğretmenin telefonuna okutulacak QR yükü.
  ///
  /// Biçim: `SCT1:{okulId}:{kod}:{ad}:{secret}`
  ///
  /// `SCT1` öneki tahtanın gösterdiği `SC1`'den **farklı**: o yük
  /// tahtadan telefona kilit açma isteği taşır, bu yük idareciden
  /// öğretmene kurulum bilgisi taşır. Aynı önek kullanılsaydı iki akış
  /// karışır ve öğretmen yanlış QR'ı okutup anlamsız hata görürdü.
  static String kurulumQrYuku({
    required String okulId,
    required PanoOgretmeni ogretmen,
  }) {
    // Ad içindeki ':' ayırıcıyı bozar; boşlukla değiştiriliyor.
    final guvenliAd = ogretmen.ad.replaceAll(':', ' ').trim();
    return 'SCT1:$okulId:${ogretmen.kod}:$guvenliAd:${ogretmen.totpSecret}';
  }

  Future<bool> _yaz(List<PanoOgretmeni> liste) async {
    try {
      await _depo.write(
        key: _liste,
        value: jsonEncode(liste.map((o) => o.toJson()).toList()),
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('Öğretmen listesi yazma hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Addan öğretmen kodu türetir (`A. Yılmaz` → `AYILMAZ`).
  ///
  /// Türkçe harfler ASCII'ye iniyor: kod tahtada elle girilebiliyor ve
  /// tahtanın klavyesinde Türkçe düzen olmayabilir. `trFold` projede
  /// zaten bu iş için var.
  static String _kodUret(String ad, List<PanoOgretmeni> mevcut) {
    final temel = trFold(ad)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final kisa = temel.isEmpty
        ? 'OGR'
        : (temel.length > 10 ? temel.substring(0, 10) : temel);

    // Çakışma varsa sayı ekle.
    var aday = kisa;
    var sayac = 2;
    while (mevcut.any((o) => o.kod.toUpperCase() == aday)) {
      aday = '$kisa$sayac';
      sayac++;
    }
    return aday;
  }

  static String _secretUret() => TahtaTotp.secretUret();
}
