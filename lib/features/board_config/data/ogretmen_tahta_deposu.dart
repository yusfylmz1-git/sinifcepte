import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Öğretmenin kendi tahta açma bilgileri (öğretmen tarafı).
///
/// ## İdareci tarafından farklı
///
/// `TahtaOgretmenDeposu` idarecinin telefonunda **tüm okulun**
/// öğretmenlerini tutar. Bu sınıf öğretmenin telefonunda **yalnızca
/// kendisini** tutar: kod, ad, okul ve TOTP secret'ı.
///
/// ## Okul başına bir kayıt
///
/// İlk sürüm tek kayıt tutuyordu: ikinci okulun karekodu birincisinin
/// üzerine yazılıyordu. Görevlendirme, ücretli öğretmenlik ya da iki
/// okulda ders veren branş öğretmeni yaygın; ikinci okula kaydolan
/// öğretmen birincinin tahtalarını açamaz oluyordu (1 Ekim 2026).
///
/// Artık her okul (`okulId`) için bir kayıt var. Tahtanın karekodu
/// okulu taşıdığı için telefon doğru kaydı kendisi seçiyor. Aynı okulun
/// yeni karekodu (secret yenilendi, öğretmen yeniden eklendi) o okulun
/// kaydının yerine geçiyor.
///
/// ## Secret nereden geliyor
///
/// İdareci öğretmeni ekler, Ana Program secret üretir ve bir karekod
/// gösterir (`SCT1:{okulId}:{kod}:{ad}:{secret}[:{okulAdi}]`). Öğretmen
/// onu kendi telefonunda okutur. Google Authenticator mantığı.
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

  /// Tek kayıtlı eski biçim; ilk okumada listeye taşınıyor.
  static const String _eskiKayit = 'ogretmen_tahta_kaydi_v1';
  static const String _kayitlar = 'ogretmen_tahta_kayitlari_v2';

  /// Kurulum QR yükünün öneki.
  ///
  /// Tahtanın gösterdiği `SC1`'den **farklı**: o yük kilit açma isteği,
  /// bu yük kurulum bilgisi taşır. Öğretmen yanlış QR'ı okutursa
  /// anlamsız hata görmek yerine ne yapması gerektiğini duymalı.
  static const String kurulumOneki = 'SCT1';

  /// En az bir okul kayıtlı mı?
  Future<bool> kayitliMi() async => (await tumu()).isNotEmpty;

  /// Kayıtlı okullar (eklenme sırasıyla). Okunamazsa boş liste.
  Future<List<OgretmenTahtaKaydi>> tumu() async {
    try {
      return await _oku();
    } catch (e, stackTrace) {
      debugPrint('Öğretmen tahta kayıtları okuma hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Kurulum QR yükünü ayrıştırıp kaydeder; o okulun eski kaydının
  /// yerine geçer, başka okulların kayıtlarına dokunmaz.
  ///
  /// Geçersizse ya da yazılamazsa `null` döner — çağıran taraf
  /// kullanıcıya sebebini söylemeli.
  Future<OgretmenTahtaKaydi?> qrIleKaydet(String hamYuk) async {
    final kayit = qrAyristir(hamYuk);
    if (kayit == null) return null;

    try {
      // Okuma HATASINDA yazılmıyor: boş liste sanıp tek kayıtla
      // yazmak, öbür okulların kayıtlarını silerdi.
      final liste = await _oku();
      final yeni = [
        for (final k in liste)
          if (k.okulId != kayit.okulId) k,
        kayit,
      ];
      await _yaz(yeni);
      return kayit;
    } catch (e, stackTrace) {
      debugPrint('Öğretmen tahta kaydı yazma hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Bir okulun kaydını siler (öğretmen o okuldan ayrıldı).
  Future<bool> sil(String okulId) async {
    try {
      final liste = await _oku();
      await _yaz([
        for (final k in liste)
          if (k.okulId != okulId) k,
      ]);
      return true;
    } catch (e, stackTrace) {
      debugPrint('Öğretmen tahta kaydı silme hatası: $e\n$stackTrace');
      return false;
    }
  }

  static const String _sonTahta = 'son_tahta_v1';

  /// Son okutulan, ağdan ulaşılabilen tahta: telefondan kilitlemek için.
  ///
  /// Kilit açıkken tahtada karekod görünmüyor; telefon tahtanın adresini
  /// açarken okuttuğu karekoddan hatırlamak zorunda (1 Ekim 2026).
  Future<void> sonTahtaKaydet(SonTahta tahta) async {
    try {
      await _depo.write(key: _sonTahta, value: jsonEncode(tahta.toJson()));
    } catch (e, stackTrace) {
      debugPrint('Son tahta yazılamadı: $e\n$stackTrace');
    }
  }

  Future<SonTahta?> sonTahta() async {
    try {
      final ham = await _depo.read(key: _sonTahta);
      if (ham == null || ham.isEmpty) return null;
      final cozulen = jsonDecode(ham);
      if (cozulen is! Map<String, dynamic>) return null;
      return SonTahta.fromJson(cozulen);
    } catch (e, stackTrace) {
      debugPrint('Son tahta okunamadı: $e\n$stackTrace');
      return null;
    }
  }

  /// Depo hatası ATAR (çağıran ayırt edebilsin); bozuk içerik boş sayılır.
  Future<List<OgretmenTahtaKaydi>> _oku() async {
    final ham = await _depo.read(key: _kayitlar);
    if (ham != null && ham.isNotEmpty) return _listeCoz(ham);

    // Eski tek kayıt: listeye taşı. Taşıma yazılamasa da kayıt
    // döndürülüyor — öğretmen derse girebilmeli; bir sonraki okumada
    // yeniden denenir.
    final eski = await _depo.read(key: _eskiKayit);
    final kayit = eski == null ? null : _tekCoz(eski);
    if (kayit == null) return const [];
    try {
      await _depo.write(key: _kayitlar, value: jsonEncode([kayit.toJson()]));
      await _depo.delete(key: _eskiKayit);
    } catch (e, stackTrace) {
      debugPrint('Eski tahta kaydı taşınamadı: $e\n$stackTrace');
    }
    return [kayit];
  }

  Future<void> _yaz(List<OgretmenTahtaKaydi> liste) async {
    if (liste.isEmpty) {
      await _depo.delete(key: _kayitlar);
    } else {
      await _depo.write(
        key: _kayitlar,
        value: jsonEncode([for (final k in liste) k.toJson()]),
      );
    }
    // Taşınmamış eski kayıt silinen okulu geri getirmesin.
    await _depo.delete(key: _eskiKayit);
  }

  static List<OgretmenTahtaKaydi> _listeCoz(String ham) {
    try {
      final cozulen = jsonDecode(ham);
      if (cozulen is! List) return const [];
      final sonuc = <String, OgretmenTahtaKaydi>{};
      for (final e in cozulen) {
        if (e is! Map<String, dynamic>) continue;
        final k = OgretmenTahtaKaydi.fromJson(e);
        if (k.gecerli) sonuc[k.okulId] = k;
      }
      return sonuc.values.toList();
    } catch (e, stackTrace) {
      debugPrint('Bozuk tahta kayıt listesi: $e\n$stackTrace');
      return const [];
    }
  }

  static OgretmenTahtaKaydi? _tekCoz(String ham) {
    try {
      final cozulen = jsonDecode(ham);
      if (cozulen is! Map<String, dynamic>) return null;
      final k = OgretmenTahtaKaydi.fromJson(cozulen);
      return k.gecerli ? k : null;
    } catch (e, stackTrace) {
      debugPrint('Bozuk eski tahta kaydı: $e\n$stackTrace');
      return null;
    }
  }

  /// Kurulum yükünü ayrıştırır (kaydetmez).
  ///
  /// `SCT1:{okulId}:{kod}:{ad}:{secret}` ya da sonunda okul adıyla
  /// (`…:{okulAdi}`, Ana Program). Okul adı yalnızca gösterim için.
  static OgretmenTahtaKaydi? qrAyristir(String hamYuk) {
    final parcalar = hamYuk.trim().split(':');
    if (parcalar.length != 5 && parcalar.length != 6) return null;
    if (parcalar[0] != kurulumOneki) return null;

    final okulId = parcalar[1].trim();
    final kod = parcalar[2].trim();
    final ad = parcalar[3].trim();
    final secret = parcalar[4].trim();
    final okulAdi = parcalar.length == 6 ? parcalar[5].trim() : '';

    if (okulId.isEmpty || kod.isEmpty || secret.isEmpty) return null;

    return OgretmenTahtaKaydi(
      okulId: okulId,
      kod: kod,
      ad: ad,
      totpSecret: secret,
      okulAdi: okulAdi,
    );
  }
}

/// Öğretmenin bir okuldaki tahta açma bilgisi.
class OgretmenTahtaKaydi {
  /// Kanonik okul kimliği. Tahtanın QR'ındaki okulla eşleşmeli.
  final String okulId;

  /// Tahtada elle girilebilen kısa kod (`AYILMAZ`).
  final String kod;

  final String ad;

  /// TOTP secret'ı (base32). Bu değer ekranda **gösterilmez**.
  final String totpSecret;

  /// Okulun adı (ASCII'ye katlanmış); eski karekodlarda boş.
  final String okulAdi;

  const OgretmenTahtaKaydi({
    required this.okulId,
    required this.kod,
    required this.ad,
    required this.totpSecret,
    this.okulAdi = '',
  });

  /// Secret'ı ya da kodu olmayan kayıt işe yaramaz: kod üretilemez.
  bool get gecerli =>
      okulId.isNotEmpty && kod.isNotEmpty && totpSecret.isNotEmpty;

  /// Ekranda okulu anlatan ad: okul adı yoksa kurum kodu.
  String get okulGorunenAdi {
    if (okulAdi.isNotEmpty) return okulAdi;
    final kurum = okulId.startsWith('meb_') ? okulId.substring(4) : okulId;
    return 'Kurum kodu $kurum';
  }

  factory OgretmenTahtaKaydi.fromJson(Map<String, dynamic> j) =>
      OgretmenTahtaKaydi(
        okulId: (j['okulId'] as String?) ?? '',
        kod: (j['kod'] as String?) ?? '',
        ad: (j['ad'] as String?) ?? '',
        totpSecret: (j['totpSecret'] as String?) ?? '',
        okulAdi: (j['okulAdi'] as String?) ?? '',
      );

  Map<String, Object?> toJson() => {
        'okulId': okulId,
        'kod': kod,
        'ad': ad,
        'totpSecret': totpSecret,
        'okulAdi': okulAdi,
      };
}

/// Telefonun son okuttuğu, ağdan ulaşılabilen tahta.
class SonTahta {
  final String okulId;

  /// Karekoddaki tahta kimliği (`tahta_5A`).
  final String tahtaId;
  final String ip;
  final int port;
  final DateTime zaman;

  const SonTahta({
    required this.okulId,
    required this.tahtaId,
    required this.ip,
    required this.port,
    required this.zaman,
  });

  String get kilitlemeAdresi => 'http://$ip:$port/kilitle';

  /// Ekranda: `tahta_5A` → `5A`; sınıfsız tahta → `tahta`.
  String get gorunenAd {
    final ad = tahtaId.startsWith('tahta_') ? tahtaId.substring(6) : tahtaId;
    return ad.isEmpty ? 'tahta' : ad;
  }

  factory SonTahta.fromJson(Map<String, dynamic> j) => SonTahta(
        okulId: (j['okulId'] as String?) ?? '',
        tahtaId: (j['tahtaId'] as String?) ?? '',
        ip: (j['ip'] as String?) ?? '',
        port: (j['port'] as num?)?.toInt() ?? 0,
        zaman: DateTime.tryParse((j['zaman'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, Object?> toJson() => {
        'okulId': okulId,
        'tahtaId': tahtaId,
        'ip': ip,
        'port': port,
        'zaman': zaman.toIso8601String(),
      };
}
