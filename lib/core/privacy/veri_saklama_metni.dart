/// Uygulamanın veriyi nerede sakladığını anlatan TEK metin.
///
/// ## Neden tek yerde (17 Ekim 2026)
/// Ekranlarda birbiriyle çelişen ve artık doğru olmayan cümleler vardı:
/// "%100 yerel, internet gerektirmez", "tüm verileriniz yalnızca bu
/// cihazda", "şifreli SQLite". Oysa veli bağlantıları, mesajlar ve
/// duyurular bulutta tutuluyor; yerel veritabanı da şifreli değil.
/// Gizlilik anlatımı yanıltıcı olursa KVKK açısından risktir.
///
/// Doğru olan şu: öğrenci, sınıf, not ve katılım bilgileri cihazda kalır
/// (veri sahipliği kararı, Seçenek A); velilerle iletişim için gereken
/// bağlantılar ve yazışmalar bulutta tutulur.
///
/// `veri_saklama_metni_test.dart` eski iddiaların koda geri dönmesini
/// engeller.
class VeriSaklamaMetni {
  VeriSaklamaMetni._();

  /// Menü, karşılama gibi dar yerler için.
  static const String kisa = 'Öğrenci ve sınıf bilgileri bu cihazda kalır.';

  /// Profil ve ayarlar gibi açıklama yapılabilen yerler için.
  static const String uzun =
      'Öğrenci, sınıf, not ve katılım bilgileri yalnızca bu cihazda '
      'saklanır, internete gönderilmez. Veli bağlantıları, mesajlar ve '
      'duyurular ise velilerle iletişim için bulutta (Google Firebase) '
      'tutulur.';
}
