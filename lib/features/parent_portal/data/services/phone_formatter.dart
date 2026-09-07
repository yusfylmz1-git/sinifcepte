/// Veli telefon numaralarını arama ve WhatsApp için biçimlendirir.
///
/// Numaralar e-Okul listesinden, elle girişten veya yapıştırmadan geliyor;
/// bu yüzden `0532...`, `+90 532...`, `0090 532...`, `(0532) 123-45-67`
/// gibi çok farklı yazımlar aynı anda karşımıza çıkıyor.
///
/// Eski mantık `00` uluslararası önekini tanımıyordu: `0090 532 ...`
/// numarası `900905321234567` hâline gelip WhatsApp'ı açamıyordu.
class PhoneFormatter {
  const PhoneFormatter._();

  /// Türkiye ülke kodu.
  static const String _countryCode = '90';

  /// Ülke kodu olmadan geçerli bir numaranın hane sayısı (5XXXXXXXXX).
  static const int _nationalLength = 10;

  /// WhatsApp bağlantısı için ülke kodlu, yalnızca rakamlardan oluşan
  /// numara üretir. Numara geçersizse null döner.
  static String? toWhatsApp(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    // '00' uluslararası çevirme öneki (0090 532...).
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // Yerel '0' öneki (0532...).
    if (digits.length > _nationalLength && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Ülke kodu zaten varsa tekrar ekleme.
    if (digits.length == _nationalLength + _countryCode.length &&
        digits.startsWith(_countryCode)) {
      return digits;
    }

    if (digits.length == _nationalLength) {
      return '$_countryCode$digits';
    }

    // Beklenmeyen uzunluk: yanlış numaraya mesaj göndermektense
    // açmamak daha güvenli.
    return null;
  }

  /// `tel:` bağlantısı için numarayı hazırlar.
  ///
  /// Arama tarafında '+' anlamlıdır ve korunur; kullanıcının girdiği
  /// biçim olduğu gibi bırakılır.
  static String? toDial(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    final digitCount = cleaned.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount < _nationalLength) return null;
    return cleaned;
  }

  /// Ekranda ve belgede gösterilecek biçim: `0 (5XX) XXX XX XX`.
  ///
  /// Aynı işlev veli rehberi ekranında ve veli iletişim PDF'inde
  /// AYRI AYRI kopyalanmıştı; biri düzeltilip diğeri unutulabilirdi.
  /// Tek fark boş değerin karşılığıydı, o da [emptyPlaceholder] ile
  /// veriliyor (ekran boş bırakır, tablo '-' basar).
  ///
  /// Tanınmayan biçim olduğu gibi döner: öğretmen sabit hat veya
  /// yurt dışı numarası girmiş olabilir, numarayı yutmak yerine
  /// göstermek doğru.
  static String toDisplay(String? raw, {String emptyPlaceholder = ''}) {
    if (raw == null || raw.trim().isEmpty) return emptyPlaceholder;

    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    String bicimle(String d) =>
        '0 (${d.substring(0, 3)}) ${d.substring(3, 6)} '
        '${d.substring(6, 8)} ${d.substring(8, 10)}';

    if (cleaned.length == 11 && cleaned.startsWith('0')) {
      return bicimle(cleaned.substring(1));
    }
    if (cleaned.length == _nationalLength && cleaned.startsWith('5')) {
      return bicimle(cleaned);
    }
    if (cleaned.length == 12 && cleaned.startsWith(_countryCode)) {
      return bicimle(cleaned.substring(2));
    }

    // Aşırı uzun girdi satırı taşırıyordu.
    if (raw.length > 20) return '${raw.substring(0, 17)}...';
    return raw;
  }
}
