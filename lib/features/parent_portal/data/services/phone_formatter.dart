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
}
