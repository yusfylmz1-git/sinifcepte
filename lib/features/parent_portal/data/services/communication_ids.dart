import 'dart:math';

/// Bulut iletişim dokümanları için çakışmayan kimlik üretici.
///
/// Kimlikler önceden yalnızca zaman damgasıydı (`rep_<ms>`, `apt_<ms>`,
/// `ann_<ms>`). Bu kayıtlar Firestore'a `setDoc(..., merge: false)` ile
/// yazılıyor; yani aynı kimlik ikinci kez yazıldığında ilk kayıt tamamen
/// silinip yerine yenisi geçiyor.
///
/// Sonuç: aynı sınıfın iki velisi aynı milisaniyede "bugün erken alınacak"
/// bildirimi gönderirse biri diğerinin kaydını yok ediyordu — ve kimse
/// bunu fark etmiyordu, çünkü yazma işlemi başarılı dönüyordu.
///
/// Bu sınıf kimliğe hem yazarın kimliğini hem de rastgele bir sonek
/// ekleyerek çakışmayı iki katmanda engeller.
class CommunicationIds {
  const CommunicationIds._();

  static final Random _rnd = Random.secure();

  /// Mesaj gövdesi üst sınırı.
  ///
  /// Firestore doküman sınırı 1 MiB'dir. Sınır yokken yapıştırılan çok
  /// uzun bir metin gönderimi sessizce başarısız kılabiliyordu.
  static const int maxBodyLength = 4000;

  /// Yazar kimliğini doküman adında güvenle kullanılabilir hâle getirir.
  ///
  /// Firestore doküman adında '/' yasaktır; Google UID'leri ise ':' ve
  /// '.' içerebilir. Kimliği kısaltıp yalnızca güvenli karakterleri
  /// bırakırız — benzersizliği rastgele sonek zaten sağlar.
  static String _safeAuthor(String authorUid) {
    final cleaned = authorUid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) return 'anon';
    return cleaned.length <= 24 ? cleaned : cleaned.substring(0, 24);
  }

  static String _suffix() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(6, (_) => alphabet[_rnd.nextInt(alphabet.length)])
        .join();
  }

  static String _build(String prefix, String authorUid, DateTime? now) {
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return '${prefix}_${_safeAuthor(authorUid)}_${stamp}_${_suffix()}';
  }

  /// Veli–öğretmen mesajı kimliği.
  static String message({required String authorUid, DateTime? now}) =>
      _build('msg', authorUid, now);

  /// Veli durum bildirimi kimliği.
  static String statusReport({required String authorUid, DateTime? now}) =>
      _build('rep', authorUid, now);

  /// Randevu talebi kimliği.
  static String appointment({required String authorUid, DateTime? now}) =>
      _build('apt', authorUid, now);

  /// Sınıf duyurusu kimliği.
  static String announcement({required String authorUid, DateTime? now}) =>
      _build('ann', authorUid, now);

  /// Destek talebi kimliği.
  ///
  /// Aynı anda iki kullanıcı talep gönderirse birbirlerinin kaydını
  /// ezmemeli; zaman damgası tek başına yetmez, rastgele sonek gerekir.
  static String supportRequest({required String authorUid, DateTime? now}) =>
      _build('sup', authorUid, now);

  /// Mesaj gövdesini üst sınıra kırpar.
  static String clampBody(String body) {
    if (body.length <= maxBodyLength) return body;
    return body.substring(0, maxBodyLength);
  }
}
