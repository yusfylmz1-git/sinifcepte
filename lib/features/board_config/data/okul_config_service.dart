import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/okul_config_model.dart';
import '../utils/tahta_imza.dart';

/// `okul_config` üretimi ve flash belleğe aktarımı.
///
/// İdarecinin telefonunda çalışır: yapılandırmayı toplar, **imzalar** ve
/// iki dosya hâlinde paylaşıma açar. Öğretmen bunları flash belleğe
/// kopyalar, tahta okur.
///
/// ## Neden imzalama anahtarı bu sınıfta saklanmıyor
///
/// Anahtar çağıran tarafından verilir ([uret] parametresi). Sebep:
/// `flutter_secure_storage` projede yok ve `shared_preferences` özel
/// anahtar için **yanlış yer** — düz metin olarak, yedeklemelere dahil
/// şekilde saklanır.
///
/// Bu sınıf saklama kararını vermiyor; arayüzü sabitliyor. Anahtar
/// nerede duracak sorusu ayrı bir karar (güvenli depo paketi eklemek mi,
/// idarecinin dışa aktarıp kendi saklaması mı) ve o karar verilene kadar
/// burada yanlış bir varsayım kalmasın.
///
/// ## Tahta ağa çıkmıyor
///
/// Bu servisin ürettiği dosya tek yönlü köprünün tamamı: tahta Firestore'a
/// hiç bağlanmaz. Bu, Firebase'in Flutter Linux desteksizliğini, Firestore
/// maliyetini, MEB ağı/AP izolasyonunu ve KVKK'yı birlikte çözen karardı.
///
/// Karşı taraf: `sinifcepte-tahta/sinifcepte_tahta/cekirdek/yapilandirma.py`
class OkulConfigService {
  OkulConfigService._();

  /// Üretilen dosyaların konulacağı klasör adı.
  static const String _klasorAdi = 'tahta_yapilandirma';

  /// Yapılandırmayı imzalar ve iki dosyayı diske yazar.
  ///
  /// Dönen [UretimSonucu] dosya yollarını taşır; paylaşım [paylas] ile
  /// yapılır. İkisi ayrı: idareci dosyayı paylaşmadan önce gözden
  /// geçirmek isteyebilir.
  ///
  /// [ozelAnahtar] 64 baytlık Ed25519 özel anahtarı. Bu cihazdan
  /// dışarı çıkmaz; yalnızca imza üretmek için kullanılır.
  static Future<UretimSonucu> uret({
    required OkulConfigModel config,
    required Uint8List ozelAnahtar,
  }) async {
    // Eksik alanları ÜRETİM anında yakala.
    //
    // Tahta tarafı `okulId`, `okulAdi` ve `zil` yoksa dosyayı reddediyor
    // (`yapilandirma.py`). Hatayı sahada değil burada görmek gerekir:
    // idareci flash belleği okula götürdükten sonra öğrenmesi kabul
    // edilemez.
    final eksikler = config.eksikAlanlar();
    if (eksikler.isNotEmpty) {
      return UretimSonucu.hata(
        'Şu alanlar eksik: ${eksikler.join(", ")}',
      );
    }

    try {
      final paket = TahtaImza.paketle(
        yapilandirma: config.toJson(),
        ozelAnahtar: ozelAnahtar,
      );

      // Kendi imzamızı doğrula.
      //
      // Bu adım savunma amaçlı: bozuk bir anahtar veya kütüphane
      // sürümü sorunu yüzünden geçersiz imza üretilirse, tahta
      // "imza geçersiz" derken sebebi anlaşılmaz. Burada yakalanırsa
      // hata idarecinin elinde kalır.
      final dogrulamaAnahtari = _dogrulamaAnahtariCikar(ozelAnahtar);
      if (!TahtaImza.dogrula(
        paket.jsonBaytlari,
        paket.imza,
        dogrulamaAnahtari,
      )) {
        return UretimSonucu.hata(
          'İmza doğrulanamadı. Anahtar bozuk olabilir.',
        );
      }

      final klasor = await _klasorHazirla();

      final jsonDosya = File(
        '${klasor.path}${Platform.pathSeparator}'
        '${TahtaYapilandirmaPaketi.jsonDosyaAdi}',
      );
      final imzaDosya = File(
        '${klasor.path}${Platform.pathSeparator}'
        '${TahtaYapilandirmaPaketi.imzaDosyaAdi}',
      );

      // İmzalanan baytlar ile yazılan baytlar AYNI olmalı.
      //
      // `writeAsString` kullanılsaydı kodlama/satır sonu dönüşümü
      // imzayı geçersiz kılabilirdi. `writeAsBytes` ham baytları yazar.
      await jsonDosya.writeAsBytes(paket.jsonBaytlari, flush: true);
      await imzaDosya.writeAsBytes(paket.imza, flush: true);

      // ÜÇÜNCÜ dosya: tahtanın imzayı doğrulayacağı açık anahtar.
      //
      // Bir dönem hiç üretilmiyordu. Tahta onu arıyor ve bulamayınca
      // "Doğrulama anahtarı yok" deyip duruyordu; müdür o dosyanın
      // var olduğunu bile bilmiyordu (19 Eylül 2026, ETAP'ta gerçek
      // kurulumda görüldü — dosya elle türetilerek kurtarıldı).
      //
      // Yalnızca AÇIK anahtar yazılıyor. Özel anahtar cihazdan
      // çıkmıyor: flash bellek kopyalansa bile saldırgan geçerli
      // yapılandırma üretemez.
      final anahtarDosya = File(
        '${klasor.path}${Platform.pathSeparator}'
        '${TahtaYapilandirmaPaketi.anahtarDosyaAdi}',
      );
      await anahtarDosya.writeAsString(
        base64Encode(dogrulamaAnahtari),
        flush: true,
      );

      return UretimSonucu.basarili(
        jsonYolu: jsonDosya.path,
        imzaYolu: imzaDosya.path,
        anahtarYolu: anahtarDosya.path,
        baytSayisi: paket.jsonBaytlari.length,
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (OkulConfigService.uret) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------');
      return UretimSonucu.hata('Dosya yazılamadı: $e');
    }
  }

  /// Üretilen iki dosyayı paylaşım penceresiyle dışa aktarır.
  ///
  /// İkisi **birlikte** paylaşılır: imzasız dosyayı tahta reddeder, tek
  /// başına imza da işe yaramaz. Ayrı ayrı paylaşmak, öğretmenin birini
  /// atlamasına yol açardı.
  static Future<bool> paylas(UretimSonucu sonuc) async {
    if (!sonuc.basarili) return false;

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(sonuc.jsonYolu),
            XFile(sonuc.imzaYolu),
            XFile(sonuc.anahtarYolu),
          ],
          subject: 'SınıfCepte tahta yapılandırması',
          text: 'Bu iki dosyayı flash belleğin kök dizinine kopyalayın. '
              'İkisi birlikte gerekli.',
        ),
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('OkulConfigService.paylas hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Tahtaya gömülecek doğrulama anahtarını üretir (base64).
  ///
  /// Kurulum sırasında tahtaya bir kez yazılır. Özel anahtarın aksine
  /// bu değer gizli değildir: yalnızca doğrulama yapar, imza üretemez.
  static String dogrulamaAnahtariBase64(Uint8List ozelAnahtar) =>
      TahtaImza.anahtarBase64(_dogrulamaAnahtariCikar(ozelAnahtar));

  /// Yeni anahtar çifti üretir.
  ///
  /// Okul ilk kez kurulurken bir kez çağrılır. Özel anahtar kaybolursa
  /// yeni yapılandırma yayımlanamaz ve tahtalara yeni doğrulama
  /// anahtarı dağıtmak gerekir — bu yüzden idareciye yedeklemesi
  /// söylenmeli.
  static TahtaAnahtarCifti anahtarUret() => TahtaImza.anahtarCiftiUret();

  /// Ed25519 özel anahtarının son 32 baytı doğrulama anahtarıdır.
  ///
  /// RFC 8032 biçimi: 64 baytlık özel anahtar = 32 bayt tohum +
  /// 32 bayt doğrulama anahtarı.
  static Uint8List _dogrulamaAnahtariCikar(Uint8List ozelAnahtar) {
    if (ozelAnahtar.length != 64) {
      throw ArgumentError(
        'Ed25519 özel anahtarı 64 bayt olmalı, verilen: ${ozelAnahtar.length}',
      );
    }
    return Uint8List.fromList(ozelAnahtar.sublist(32));
  }

  static Future<Directory> _klasorHazirla() async {
    final belgeler = await getApplicationDocumentsDirectory();
    final klasor = Directory(
      '${belgeler.path}${Platform.pathSeparator}$_klasorAdi',
    );
    if (!await klasor.exists()) {
      await klasor.create(recursive: true);
    }
    return klasor;
  }
}

/// `okul_config` üretiminin sonucu.
class UretimSonucu {
  final bool basarili;
  final String jsonYolu;
  final String imzaYolu;

  /// Doğrulama anahtarı dosyasının yolu.
  ///
  /// Üçü birlikte paylaşılıyor: biri eksik giderse tahta çalışmaz ve
  /// sebebi sahada anlaşılmaz.
  final String anahtarYolu;

  final int baytSayisi;
  final String hataMesaji;

  const UretimSonucu._({
    required this.basarili,
    this.jsonYolu = '',
    this.imzaYolu = '',
    this.anahtarYolu = '',
    this.baytSayisi = 0,
    this.hataMesaji = '',
  });

  factory UretimSonucu.basarili({
    required String jsonYolu,
    required String imzaYolu,
    required String anahtarYolu,
    required int baytSayisi,
  }) =>
      UretimSonucu._(
        basarili: true,
        jsonYolu: jsonYolu,
        imzaYolu: imzaYolu,
        anahtarYolu: anahtarYolu,
        baytSayisi: baytSayisi,
      );

  factory UretimSonucu.hata(String mesaj) =>
      UretimSonucu._(basarili: false, hataMesaji: mesaj);
}
