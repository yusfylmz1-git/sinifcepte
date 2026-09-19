import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/tahta_imza.dart';

/// Tahta imzalama anahtarının güvenli saklanması.
///
/// ## İki katman birlikte (kullanıcı kararı)
///
/// 1. **Güvenli depo** — anahtar Android Keystore / iOS Keychain içinde
///    durur. Uygulama yönetir, idareci hiç görmek zorunda değil.
/// 2. **Yedek dışa aktarma** — idareci anahtarı base64 olarak alıp
///    kendi güvenli yerine kaydedebilir.
///
/// İkinci katman şart, çünkü **anahtar kaybolursa geri dönüşü yok**:
/// yeni yapılandırma yayımlanamaz ve her tahtaya yeni doğrulama
/// anahtarı elden dağıtmak gerekir. Telefon değişimi, fabrika ayarları
/// veya uygulama silinmesi bunu tetikler.
///
/// ## Neden `shared_preferences` değil
///
/// `shared_preferences` düz metin saklar ve cihaz yedeklemelerine
/// dahil olur. Özel imzalama anahtarı için yanlış yer: yedeği okuyan
/// biri geçerli yapılandırma üretebilir ve tüm tahtaları açabilir.
///
/// ## Anahtar neyi koruyor, neyi korumuyor
///
/// Koruduğu: flash bellek kopyalansa bile saldırgan **geçerli
/// yapılandırma üretemez** (tahtada yalnızca doğrulama anahtarı var).
///
/// Korumadığı: tahtanın kilidini açmayı. Panelin kaynak düğmesi kilidi
/// zaten atlıyor ve ETAP yönetici şifreleri kamuya açık. Bu anahtar
/// yapılandırmanın **bütünlüğünü** korur, tahtanın erişimini değil.
class TahtaAnahtarDeposu {
  TahtaAnahtarDeposu({FlutterSecureStorage? depo})
      : _depo = depo ??
            const FlutterSecureStorage(
              // `encryptedSharedPreferences` BİLEREK verilmiyor:
              // kullanımdan kalktı (Google'ın Jetpack Security kitaplığı
              // bırakıldı), v11'de kaldırılıyor ve verilse bile yok
              // sayılıyor. Paket ilk erişimde kendi şifrelemesine göç
              // ettiriyor.
              // Kurucuda `IOSOptions` (somut), metot imzalarında
              // `AppleOptions` (soyut üst tip) geçiyor — paketin
              // 10.x'teki tip düzeni böyle. `AppleOptions` burada
              // örneklenemez.
              iOptions: IOSOptions(
                // Cihaz bir kez açıldıktan sonra erişilebilir; arka
                // planda çalışan kod da anahtara ulaşabilsin. `always`
                // seçilse yedeklemelere de girerdi.
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _depo;

  /// Depo anahtarı. Okul kimliği içermiyor: bir cihazda tek okul
  /// yönetilir (`docs/design-okul-admin-google-veli.md`: "v1 tek okul").
  static const String _anahtarAdi = 'tahta_imzalama_anahtari_v1';

  /// Anahtarın üretildiği anı saklar; idareciye "ne zaman oluşturuldu"
  /// bilgisi gösterilir.
  static const String _tarihAdi = 'tahta_imzalama_anahtari_tarih_v1';

  /// Yedeğin alındığı an.
  ///
  /// ## Neden saklanıyor
  ///
  /// Anahtar artık **otomatik** üretiliyor (kullanıcı kararı,
  /// 18 Eylül 2026: *"anahtar oluşturma teknik iş, müdür neden var
  /// olduğunu anlayamaz"*). Müdürün tek gerçek görevi yedeği almak;
  /// anahtar kaybolursa geri dönüşü yok.
  ///
  /// Bu yüzden "yedek alındı mı" ayrıca tutuluyor: alınmadıysa ekran
  /// uyarı gösteriyor, alındıysa sessizleşiyor. Aksi hâlde müdür
  /// uyarıyı her açılışta görür ve gürültüye dönüşür.
  static const String _yedekAdi = 'tahta_yedek_alindi_v1';

  /// Kayıtlı anahtar var mı?
  Future<bool> anahtarVarMi() async {
    try {
      return await _depo.containsKey(key: _anahtarAdi);
    } catch (e, stackTrace) {
      debugPrint('anahtarVarMi hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Kayıtlı özel anahtarı okur; yoksa `null`.
  Future<Uint8List?> ozelAnahtarOku() async {
    try {
      final base64Deger = await _depo.read(key: _anahtarAdi);
      if (base64Deger == null || base64Deger.isEmpty) return null;

      final baytlar = TahtaImza.anahtarBase64Coz(base64Deger);

      // Bozuk kayıt sessizce kullanılmamalı: 64 bayt değilse imzalama
      // çöker ve sebebi anlaşılmaz.
      if (baytlar.length != 64) {
        debugPrint(
          'Kayıtlı anahtar bozuk (${baytlar.length} bayt, 64 bekleniyordu)',
        );
        return null;
      }
      return baytlar;
    } catch (e, stackTrace) {
      debugPrint('ozelAnahtarOku hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Anahtar yoksa üretir ve saklar; varsa mevcut olanı döndürür.
  ///
  /// **Üzerine yazmaz.** Mevcut anahtarı kazara değiştirmek, daha önce
  /// dağıtılmış tüm tahtaların doğrulama anahtarını geçersiz kılardı;
  /// bu yüzden yenileme ayrı ve açık bir işlem ([anahtariDegistir]).
  Future<Uint8List?> anahtarHazirla() async {
    final mevcut = await ozelAnahtarOku();
    if (mevcut != null) return mevcut;

    try {
      final cift = TahtaImza.anahtarCiftiUret();
      await _depo.write(
        key: _anahtarAdi,
        value: TahtaImza.anahtarBase64(cift.ozelAnahtar),
      );
      await _depo.write(
        key: _tarihAdi,
        value: DateTime.now().toIso8601String(),
      );
      return cift.ozelAnahtar;
    } catch (e, stackTrace) {
      debugPrint('anahtarHazirla hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Anahtarı **bilerek** yeniler.
  ///
  /// Dağıtılmış tüm tahtalar geçersiz kalır: her birine yeni doğrulama
  /// anahtarı gitmeli. Çağıran taraf kullanıcıyı bu konuda uyarmak
  /// zorunda — bu yüzden ayrı bir metot.
  Future<Uint8List?> anahtariDegistir() async {
    try {
      await _depo.delete(key: _anahtarAdi);
      await _depo.delete(key: _tarihAdi);

      // YEDEK BAYRAĞI da siliniyor.
      //
      // Silinmediğinde ekran yeni anahtar için de "yedek alındı"
      // diyordu. Müdür elindeki ESKİ 88 karakteri saklamaya devam
      // ediyor ve yeni anahtar hiç yedeklenmemiş oluyordu.
      //
      // Sonucu telefon değişince ortaya çıkardı: eski yedekten
      // geri yüklenen anahtar tahtalardakiyle uyuşmaz, tüm tahtalar
      // "imza geçersiz" der ve hepsine elden gitmek gerekir —
      // bulut yedeğinin önlemek için var olduğu senaryonun ta
      // kendisi (bağımsız incelemede bildirildi, 19 Eylül 2026'da
      // doğrulandı).
      await _depo.delete(key: _yedekAdi);
    } catch (e, stackTrace) {
      debugPrint('anahtariDegistir silme hatası: $e\n$stackTrace');
      return null;
    }
    return anahtarHazirla();
  }

  /// Anahtarın üretildiği an; bilinmiyorsa `null`.
  Future<DateTime?> uretimTarihi() async {
    try {
      final ham = await _depo.read(key: _tarihAdi);
      if (ham == null || ham.isEmpty) return null;
      return DateTime.tryParse(ham);
    } catch (e, stackTrace) {
      debugPrint('uretimTarihi hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Müdür yedeği aldı mı?
  Future<bool> yedekAlindiMi() async {
    try {
      final ham = await _depo.read(key: _yedekAdi);
      return ham != null && ham.isNotEmpty;
    } catch (e, stackTrace) {
      debugPrint('yedekAlindiMi hatası: $e\n$stackTrace');
      // Okunamıyorsa "alınmadı" sayılıyor: uyarıyı fazladan
      // göstermek, alınmamış bir yedeği alınmış sanmaktan iyi.
      return false;
    }
  }

  /// Yedeğin alındığını işaretler.
  ///
  /// Çağıran taraf bunu yalnızca **kopyalama gerçekleştiğinde**
  /// çağırmalı; diyaloğu açmak yedek almak değil.
  Future<void> yedekAlindiIsaretle() async {
    try {
      await _depo.write(
        key: _yedekAdi,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e, stackTrace) {
      debugPrint('yedekAlindiIsaretle hatası: $e\n$stackTrace');
    }
  }

  /// Anahtarın base64 gösterimi — **yalnızca anahtar**, açıklama yok.
  ///
  /// ## Neden ayrı metot
  ///
  /// Yedek metni 20 satırlık açıklama içeriyor ve idareci anahtarı
  /// onun içinden **elle seçmeye** çalışıyordu. Sahada bu yaşandı
  /// (18 Eylül 2026): seçim bir karakter kaydı, base64'teki `/`
  /// düştü ve 88 karakterlik anahtar 87 karaktere indi.
  ///
  /// Sonuç sessiz değil ama teşhisi zor: anahtar hiç çözülemiyor
  /// (`Invalid base64-encoded string`) ve idareci "yedeğim bozuk mu,
  /// uygulama mı hatalı" diye kalıyor. `/` ve `+` base64'te sık
  /// geçtiği için tekrar etmesi kaçınılmazdı.
  ///
  /// Arayüz artık anahtarı kendi kutusunda gösteriyor ve tek dokunuşla
  /// kopyalatıyor.
  Future<String?> anahtarBase64Oku() async {
    final anahtar = await ozelAnahtarOku();
    if (anahtar == null) return null;
    return TahtaImza.anahtarBase64(anahtar);
  }

  /// İdarecinin kendi saklayacağı yedek metni.
  ///
  /// Anahtar kaybolursa geri dönüşü olmadığı için idareciye bu metni
  /// güvenli bir yere kaydetmesi söylenir. Metin, ne olduğunu ve
  /// paylaşılmaması gerektiğini **kendi içinde** anlatıyor: yedeği
  /// sonradan bulan kişi bunun ne olduğunu bilemezse işe yaramaz.
  Future<String?> yedekMetniUret({required String okulAdi}) async {
    final anahtar = await ozelAnahtarOku();
    if (anahtar == null) return null;

    final tarih = await uretimTarihi();
    final tarihSatiri = tarih == null
        ? 'bilinmiyor'
        : '${tarih.day}.${tarih.month}.${tarih.year}';

    return '''
SINIFCEPTE TAHTA IMZALAMA ANAHTARI — GİZLİ

Okul        : $okulAdi
Üretim      : $tarihSatiri

BU ANAHTARI KİMSEYLE PAYLAŞMAYIN.

Ne işe yarar: Tahtalara gönderdiğiniz yapılandırma dosyasını (nöbetçi
listesi, duyurular, zil saatleri) bu anahtarla imzalıyoruz. Tahta
yalnızca bu anahtarla imzalanmış dosyaları kabul eder.

Neden yedekliyorsunuz: Telefonunuz değişirse veya uygulama silinirse
anahtar kaybolur. Kaybolursa yeni yapılandırma yayımlayamazsınız ve
her tahtaya elden yeni anahtar kurmanız gerekir.

Nereye kaydedin: Parola yöneticisi veya kilitli bir yer. E-posta veya
WhatsApp'a göndermeyin.

ANAHTAR (base64):
${TahtaImza.anahtarBase64(anahtar)}
''';
  }

  /// Geri yüklemenin neden başarısız olduğunu söyleyen sonuç.
  ///
  /// Eskiden yalnızca `bool` dönüyordu ve arayüz sebebi tahmin
  /// etmek zorundaydı. Sahada en sık görülen sebep **eksik karakter**
  /// (18 Eylül 2026: idareci anahtarı elle seçince base64'teki `/`
  /// düştü); "yedek geçersiz" demek o durumda yardımcı olmuyor,
  /// "88 karakter olmalı, 87 var" oluyor.
  static String? geriYuklemeSebebi(String base64Anahtar) {
    final temiz = base64Anahtar.trim();
    if (temiz.isEmpty) return 'Anahtar boş.';

    // 64 bayt → 88 karakter (86 veri + '=='). Base64 uzunluğu 4'ün
    // katı olmak zorunda; elle kopyalamada tek karakter düşmesi tam
    // olarak burada yakalanıyor.
    if (temiz.length != 88) {
      return 'Anahtar 88 karakter olmalı, ${temiz.length} karakter '
          'girildi. Eksik veya fazla karakter var — yedeği elle '
          'seçmek yerine "Anahtarı Kopyala" düğmesini kullanın.';
    }
    return null;
  }

  /// Yedekten anahtarı geri yükler.
  ///
  /// Yalnızca 64 baytlık geçerli bir Ed25519 özel anahtarını kabul
  /// eder; yanlış metin yapıştırıldığında sessizce bozuk anahtar
  /// saklamak, sonraki her imzayı geçersiz kılardı.
  Future<bool> yedektenGeriYukle(String base64Anahtar) async {
    try {
      final temiz = base64Anahtar.trim();
      if (temiz.isEmpty) return false;

      final baytlar = TahtaImza.anahtarBase64Coz(temiz);
      if (baytlar.length != 64) {
        debugPrint(
          'Geri yükleme reddedildi: ${baytlar.length} bayt '
          '(64 bekleniyordu)',
        );
        return false;
      }

      // Anahtarın gerçekten çalıştığını kanıtla: imzala ve doğrula.
      //
      // Doğru uzunlukta ama bozuk bir dizi de 64 bayt olabilir; o
      // anahtarla üretilen dosyaları tahta reddeder ve idareci sebebini
      // anlamaz. Kaydetmeden önce sınıyoruz.
      final deneme = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final imza = TahtaImza.imzala(deneme, baytlar);
      final dogrulamaAnahtari = Uint8List.fromList(baytlar.sublist(32));
      if (!TahtaImza.dogrula(deneme, imza, dogrulamaAnahtari)) {
        debugPrint('Geri yükleme reddedildi: anahtar imza üretemiyor');
        return false;
      }

      await _depo.write(key: _anahtarAdi, value: temiz);
      await _depo.write(
        key: _tarihAdi,
        value: DateTime.now().toIso8601String(),
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('yedektenGeriYukle hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Tahtalara gömülecek doğrulama anahtarı (base64); anahtar yoksa `null`.
  Future<String?> dogrulamaAnahtariBase64() async {
    final ozel = await ozelAnahtarOku();
    if (ozel == null) return null;
    return TahtaImza.anahtarBase64(Uint8List.fromList(ozel.sublist(32)));
  }

  /// Anahtarı tamamen siler.
  ///
  /// KVKK "silme hakkı" ve hesap silme akışı için. Silindikten sonra
  /// dağıtılmış tahtalar yeni yapılandırma alamaz.
  Future<bool> sil() async {
    try {
      await _depo.delete(key: _anahtarAdi);
      await _depo.delete(key: _tarihAdi);
      return true;
    } catch (e, stackTrace) {
      debugPrint('Anahtar silme hatası: $e\n$stackTrace');
      return false;
    }
  }
}
