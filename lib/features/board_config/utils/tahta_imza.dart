import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// Tahta yapılandırmasının imzalanması (Ed25519, RFC 8032).
///
/// ## Güven modeli
///
/// İmzalama anahtarı **yalnızca idarecinin telefonunda** durur. Tahtada
/// sadece doğrulama anahtarı (public key) bulunur. Sonuç: flash bellek
/// kaybolsa, kopyalansa veya bir öğrencinin eline geçse bile geçerli
/// yapılandırma üretilemez.
///
/// Bu yüzden bu sınıfın tahta tarafında bir karşılığı **yok**: Python
/// çekirdeği (`cekirdek/yapilandirma.py`) yalnızca doğrulama yapar,
/// imzalama yapmaz. Asimetri kasıtlıdır.
///
/// ## Neden ayrı imza dosyası, JSON'un içine gömülü değil
///
/// İmza JSON'un **baytları** üzerinde hesaplanır. İmzayı JSON'un içine
/// koymak "imzayı hesaplarken imza alanını çıkar" gibi kırılgan bir
/// kanonikleştirme gerektirir; alan sırası veya boşluk değişirse imza
/// bozulur ve tahta yapılandırmayı reddeder. Ayrı `.sig` dosyası bu
/// sınıf hatayı tamamen ortadan kaldırır.
///
/// Karşı taraf: `sinifcepte-tahta/sinifcepte_tahta/cekirdek/yapilandirma.py`
class TahtaImza {
  TahtaImza._();

  /// Yeni bir imzalama anahtar çifti üretir.
  ///
  /// Okul ilk kez kurulurken bir kez çağrılır. Özel anahtar idarecinin
  /// cihazında güvenli şekilde saklanmalı; kaybedilirse yeni yapılandırma
  /// yayımlanamaz ve tahtalara yeni doğrulama anahtarı dağıtmak gerekir.
  static TahtaAnahtarCifti anahtarCiftiUret() {
    final cift = ed.generateKey();
    return TahtaAnahtarCifti(
      ozelAnahtar: Uint8List.fromList(cift.privateKey.bytes),
      dogrulamaAnahtari: Uint8List.fromList(cift.publicKey.bytes),
    );
  }

  /// Verilen baytları imzalar.
  ///
  /// [ozelAnahtar] 64 baytlık Ed25519 özel anahtarıdır
  /// ([TahtaAnahtarCifti.ozelAnahtar]).
  static Uint8List imzala(Uint8List veri, Uint8List ozelAnahtar) {
    if (ozelAnahtar.length != 64) {
      throw ArgumentError(
        'Ed25519 özel anahtarı 64 bayt olmalı, verilen: ${ozelAnahtar.length}',
      );
    }
    final imza = ed.sign(ed.PrivateKey(ozelAnahtar), veri);
    return Uint8List.fromList(imza);
  }

  /// İmzayı doğrular.
  ///
  /// Üretim akışında tahta tarafı doğrular; bu metot mobil tarafta
  /// **kendi ürettiği dosyayı sınamak** için var. Dosya tahtaya
  /// gitmeden önce burada doğrulanırsa, sahada "imza geçersiz" hatası
  /// yaşanmaz.
  static bool dogrula(
    Uint8List veri,
    Uint8List imza,
    Uint8List dogrulamaAnahtari,
  ) {
    if (dogrulamaAnahtari.length != 32) return false;
    if (imza.length != 64) return false;
    try {
      return ed.verify(ed.PublicKey(dogrulamaAnahtari), veri, imza);
    } catch (_) {
      // Bozuk anahtar/imza biçimi: doğrulanamadı demektir, çökmek değil.
      return false;
    }
  }

  /// Yapılandırma JSON'unu tahtanın okuduğu biçimde baytlara çevirir.
  ///
  /// **Kritik:** İmza bu baytlar üzerinde hesaplanır ve tahtaya giden
  /// dosya da tam olarak bu baytlar olmalıdır. Aynı veriyi ikinci kez
  /// farklı biçimde (girinti, alan sırası, satır sonu) yazmak imzayı
  /// geçersiz kılar. Bu yüzden üretim ve imzalama aynı çıktıyı paylaşır:
  /// [TahtaYapilandirmaPaketi.jsonBaytlari].
  static Uint8List jsonBaytlari(Map<String, Object?> yapilandirma) {
    // `JsonEncoder.withIndent` okunabilir çıktı verir; idareci gerektiğinde
    // dosyayı gözle kontrol edebilsin. Girinti imzayı etkiler ama sorun
    // değil: imza ve dosya aynı baytlardan üretiliyor.
    const kodlayici = JsonEncoder.withIndent('  ');
    return Uint8List.fromList(utf8.encode(kodlayici.convert(yapilandirma)));
  }

  /// Yapılandırmayı imzalayıp tahtaya gidecek paketi üretir.
  ///
  /// Dönen paketteki iki dosya birlikte taşınmalıdır; biri eksikse tahta
  /// yapılandırmayı reddeder (imzasız dosya kabul edilmez).
  static TahtaYapilandirmaPaketi paketle({
    required Map<String, Object?> yapilandirma,
    required Uint8List ozelAnahtar,
  }) {
    final baytlar = jsonBaytlari(yapilandirma);
    final imza = imzala(baytlar, ozelAnahtar);
    return TahtaYapilandirmaPaketi(jsonBaytlari: baytlar, imza: imza);
  }

  /// Anahtarı saklamak/taşımak için base64'e çevirir.
  static String anahtarBase64(Uint8List anahtar) => base64.encode(anahtar);

  /// Base64 anahtarı geri okur.
  static Uint8List anahtarBase64Coz(String base64Anahtar) =>
      Uint8List.fromList(base64.decode(base64Anahtar.trim()));
}

/// Ed25519 anahtar çifti.
class TahtaAnahtarCifti {
  /// 64 baytlık özel anahtar. İdarecinin cihazında kalır, ASLA dağıtılmaz.
  final Uint8List ozelAnahtar;

  /// 32 baytlık doğrulama anahtarı. Tahtalara dağıtılır.
  final Uint8List dogrulamaAnahtari;

  const TahtaAnahtarCifti({
    required this.ozelAnahtar,
    required this.dogrulamaAnahtari,
  });

  /// Tahta kurulumuna gömülecek doğrulama anahtarı (base64).
  String get dogrulamaAnahtariBase64 =>
      TahtaImza.anahtarBase64(dogrulamaAnahtari);
}

/// Tahtaya gidecek iki dosya: yapılandırma ve imzası.
class TahtaYapilandirmaPaketi {
  /// `okul_config.json` içeriği (tam olarak bu baytlar yazılmalı).
  final Uint8List jsonBaytlari;

  /// `okul_config.sig` içeriği.
  final Uint8List imza;

  const TahtaYapilandirmaPaketi({
    required this.jsonBaytlari,
    required this.imza,
  });

  /// Flash bellekteki dosya adları.
  ///
  /// **ÜÇÜ birlikte** gerekli. Tahta tarafı üçünü de arıyor
  /// (`servis/ana.py`): imzasız dosya kabul edilmez, anahtarsız imza
  /// da doğrulanamaz.
  ///
  /// Doğrulama anahtarı bir dönem hiç üretilmiyordu ve ekran "bu iki
  /// dosyayı kopyalayın" diyordu. Tahta ise üçüncüyü arıyor ve
  /// bulamayınca "Doğrulama anahtarı yok" deyip duruyordu — müdür o
  /// dosyanın var olduğunu bile bilmiyordu (19 Eylül 2026, ETAP'ta
  /// gerçek kurulumda görüldü).
  static const String jsonDosyaAdi = 'okul_config.json';
  static const String imzaDosyaAdi = 'okul_config.sig';

  /// Tahtaya gömülecek **açık** anahtar (base64, 32 bayt).
  ///
  /// Özel anahtar bu dosyaya GİRMEZ; flash bellek kopyalansa bile
  /// saldırgan geçerli yapılandırma üretemez.
  static const String anahtarDosyaAdi = 'dogrulama_anahtari.b64';

  /// İnsan tarafından okunabilir JSON (günlük/hata ayıklama için).
  String get jsonMetni => utf8.decode(jsonBaytlari);
}
