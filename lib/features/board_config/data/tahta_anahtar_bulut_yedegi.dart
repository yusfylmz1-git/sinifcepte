import 'package:flutter/foundation.dart';

import '../../../core/cloud/firestore_client.dart';

/// İmzalama anahtarının bulut yedeği.
///
/// ## Neden var (kullanıcı kararı, 18 Eylül 2026)
///
/// Anahtar kaybolursa geri dönüşü yok: yeni yapılandırma yayımlanamaz
/// ve her tahtaya elden gitmek gerekir. Müdürün metin yedeği alması
/// bekleniyordu ama sahada bu **olmuyor** — kullanıcı: *"bence yedeği
/// direkt buluta yedeklesin."*
///
/// Telefon değişince anahtar kendiliğinden geri geliyor; müdürün
/// hiçbir şey yapması gerekmiyor.
///
/// ## KABUL EDİLEN RİSK — gizlenmiyor
///
/// Özel anahtar bulutta **düz** duruyor. Kullanıcı parolasız yedeği
/// bilerek seçti (alternatif: müdürün belirlediği parolayla şifreli
/// yedek).
///
/// Sonucu: Firebase hesabı ele geçirilirse saldırgan **tüm okulların**
/// tahtalarına geçerli yapılandırma üretebilir. Bu, "özel anahtar
/// cihazdan çıkmaz" kararının terk edilmesi demek.
///
/// Gerekçe: kilit zaten "caydırıcı katman" olarak konumlandırılıyor
/// ve panelin kaynak düğmesiyle atlanıyor (MEB şartnamesi md.
/// 1.11.3). Anahtar kaybı ise gerçek ve sık bir zarar; teorik saldırı
/// riskinden daha büyük.
///
/// Şifreli yedeğe geçilmek istenirse: `yedekle()` çağrısına parola
/// eklenir ve `geriYukle()` onu ister. Şema aynı kalır.
///
/// ## Yol
///
/// ```text
/// school_boards/{schoolId}/gizli/imzalama_anahtari
/// ```
///
/// `gizli` alt koleksiyonu **ayrı**: `school_boards/{schoolId}`
/// okumaya oturumlu herkese açık (pano içeriği tahtada zaten
/// görünüyor). Anahtar oraya yazılsaydı okuldaki her öğretmen
/// okuyabilirdi. Kural burada okuma ve yazmayı yalnızca o okulun
/// onaylı yöneticisine veriyor.
class TahtaAnahtarBulutYedegi {
  TahtaAnahtarBulutYedegi({FirestoreClient? client})
      : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const String _kok = 'school_boards';
  static const String _belge = 'imzalama_anahtari';

  static String yedekPath(String schoolId) =>
      '$_kok/$schoolId/gizli/$_belge';

  /// Anahtarı buluta yedekler.
  ///
  /// Sessizce başarısız olmuyor: çağıran taraf sonucu kullanıcıya
  /// gösterebilsin diye `bool` dönüyor. Ama yedekleme başarısız
  /// olsa da **anahtar cihazda çalışmaya devam ediyor** — bu bir
  /// kolaylık katmanı, çalışma şartı değil.
  Future<bool> yedekle({
    required String schoolId,
    required String base64Anahtar,
  }) async {
    if (schoolId.isEmpty || base64Anahtar.isEmpty) return false;

    // 64 bayt → 88 karakter. Bozuk bir değeri yedeklemek, geri
    // yüklendiğinde sessizce geçersiz imza üretirdi.
    if (base64Anahtar.length != 88) {
      debugPrint(
        'Bulut yedeği reddedildi: anahtar ${base64Anahtar.length} '
        'karakter (88 bekleniyordu)',
      );
      return false;
    }

    return _client.setDoc(
      yedekPath(schoolId),
      {
        'anahtar': base64Anahtar,
        'yedeklenmeZamani': DateTime.now().toIso8601String(),
      },
      merge: false,
    );
  }

  /// Buluttaki yedeği okur; yoksa `null`.
  ///
  /// Telefon değiştiren müdür için: uygulama açılışında çağrılıyor ve
  /// cihazda anahtar yoksa bu yedek geri yükleniyor.
  Future<String?> oku({required String schoolId}) async {
    if (schoolId.isEmpty) return null;

    final veri = await _client.getDoc(yedekPath(schoolId));
    if (veri == null) return null;

    final anahtar = (veri['anahtar'] as String?) ?? '';
    if (anahtar.length != 88) {
      // Bozuk yedeği kullanmak, her imzayı sessizce geçersiz
      // kılardı — sahada teşhisi en zor hata sınıfı.
      debugPrint(
        'Bulut yedeği bozuk: ${anahtar.length} karakter '
        '(88 bekleniyordu)',
      );
      return null;
    }
    return anahtar;
  }

  /// Yedeğin ne zaman alındığı; yoksa `null`.
  Future<DateTime?> yedekZamani({required String schoolId}) async {
    if (schoolId.isEmpty) return null;

    final veri = await _client.getDoc(yedekPath(schoolId));
    if (veri == null) return null;
    return DateTime.tryParse((veri['yedeklenmeZamani'] as String?) ?? '');
  }

  /// Yedeği siler.
  ///
  /// Anahtar yenilendiğinde eski yedek kalmamalı: geri yüklenirse
  /// tahtalardaki yeni doğrulama anahtarıyla uyuşmaz ve "imza
  /// geçersiz" hatası verir.
  Future<bool> sil({required String schoolId}) async {
    if (schoolId.isEmpty) return false;
    return _client.deleteDoc(yedekPath(schoolId));
  }
}
