/// Ad-soyad yazım standardı: **Yusuf YILMAZ**.
///
/// ## Neden gerekli
/// Kullanıcı ne yazarsa o kalıyordu: "yusuf yılmaz", "YUSUF YILMAZ",
/// "Yusuf yılmaz". Aynı öğretmen profilde bir türlü, veli ekranında
/// başka türlü görünüyordu. Öğrenci listesi, PDF çıktıları ve veli
/// bildirimleri de aynı dertten muzdaripti.
///
/// Tek standart: **ad Baş Harfi Büyük, soyad TAMAMEN BÜYÜK.**
/// Bu, MEB evraklarındaki yaygın yazımdır ve soyadı bir bakışta ayırır.
///
/// ## Türkçe tuzağı
/// `toUpperCase()` ve `toLowerCase()` Türkçe için **bozuktur**:
///
/// ```
/// 'işık'.toUpperCase()  → 'IŞIK'   ama doğrusu 'İŞIK'
/// 'I'.toLowerCase()     → 'i'      ama doğrusu 'ı'
/// ```
///
/// Bir öğretmenin soyadını ekranda yanlış yazmak kabul edilemez;
/// bu yüzden dönüşüm elle yapılır.
library;

/// Türkçe karakterlerin büyük–küçük eşleşmesi.
const Map<String, String> _kucukten = {
  'i': 'İ',
  'ı': 'I',
  'ş': 'Ş',
  'ğ': 'Ğ',
  'ü': 'Ü',
  'ö': 'Ö',
  'ç': 'Ç',
  'â': 'Â',
  'î': 'Î',
  'û': 'Û',
};

const Map<String, String> _buyukten = {
  'İ': 'i',
  'I': 'ı',
  'Ş': 'ş',
  'Ğ': 'ğ',
  'Ü': 'ü',
  'Ö': 'ö',
  'Ç': 'ç',
  'Â': 'â',
  'Î': 'î',
  'Û': 'û',
};

/// Türkçe'ye uygun büyük harf.
String trUpper(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_kucukten[ch] ?? ch.toUpperCase());
  }
  return b.toString();
}

/// Türkçe'ye uygun küçük harf.
String trLower(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_buyukten[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}

/// Ad-soyad biçimlendirici.
class NameFormatter {
  NameFormatter._();

  /// Adı "Yusuf" biçimine getirir: her kelimenin baş harfi büyük.
  ///
  /// Çok adlı isimler korunur: "ali riza" → "Ali Rıza".
  /// Kesme ve tire içeren adlar da doğru işlenir: "ayşe-nur" → "Ayşe-Nur".
  static String formatFirstName(String raw) {
    final temiz = _normalize(raw);
    if (temiz.isEmpty) return '';

    return temiz
        .split(' ')
        .map(_capitalizeWord)
        .join(' ');
  }

  /// Soyadı "YILMAZ" biçimine getirir: tamamen büyük.
  static String formatLastName(String raw) {
    final temiz = _normalize(raw);
    if (temiz.isEmpty) return '';
    return trUpper(temiz);
  }

  /// Tam ad: **Yusuf YILMAZ**.
  static String format({required String firstName, required String lastName}) {
    final ad = formatFirstName(firstName);
    final soyad = formatLastName(lastName);

    if (ad.isEmpty) return soyad;
    if (soyad.isEmpty) return ad;
    return '$ad $soyad';
  }

  /// Tek parça hâlde gelen adı biçimlendirir.
  ///
  /// **Son kelime soyad sayılır.** Veli adı, öğretmen adı gibi tek
  /// alanda toplanan yerlerde kullanılır: "yusuf can yılmaz" →
  /// "Yusuf Can YILMAZ".
  static String formatFull(String raw) {
    final temiz = _normalize(raw);
    if (temiz.isEmpty) return '';

    final parcalar = temiz.split(' ');
    if (parcalar.length == 1) {
      // Tek kelime: soyad mı ad mı bilinmez. Ad varsayılır — "YILMAZ"
      // yazmak, adı olduğu hâlde bağırmak olurdu.
      return _capitalizeWord(parcalar.first);
    }

    final soyad = parcalar.last;
    final ad = parcalar.sublist(0, parcalar.length - 1);
    return '${ad.map(_capitalizeWord).join(' ')} ${trUpper(soyad)}';
  }

  /// Kısa gösterim: **Yusuf Y.**
  ///
  /// Dar alanlarda (kart, ızgara) kullanılır.
  static String formatShort({
    required String firstName,
    required String lastName,
  }) {
    final ad = formatFirstName(firstName);
    final soyad = _normalize(lastName);

    if (soyad.isEmpty) return ad;
    if (ad.isEmpty) return trUpper(soyad);

    return '$ad ${trUpper(soyad[0])}.';
  }

  /// Baş harfler: "Yusuf Yılmaz" → "YY"
  static String initials({
    required String firstName,
    required String lastName,
  }) {
    final a = _normalize(firstName);
    final s = _normalize(lastName);

    final b = StringBuffer();
    if (a.isNotEmpty) b.write(trUpper(a[0]));
    if (s.isNotEmpty) b.write(trUpper(s[0]));

    return b.isEmpty ? '?' : b.toString();
  }

  /// Fazla boşlukları temizler, baştaki/sondaki boşluğu atar.
  ///
  /// Kullanıcı "  yusuf   yılmaz  " yazabiliyor; ham hâliyle
  /// kaydedilirse arama ve sıralama bozulur.
  static String _normalize(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Bir kelimenin baş harfini büyütür, kalanını küçültür.
  ///
  /// Tire ve kesme sonrası da büyütülür: "ayşe-nur" → "Ayşe-Nur".
  static String _capitalizeWord(String word) {
    if (word.isEmpty) return '';

    final b = StringBuffer();
    var sonrakiBuyuk = true;

    for (final ch in word.split('')) {
      if (sonrakiBuyuk) {
        b.write(trUpper(ch));
        sonrakiBuyuk = false;
      } else {
        b.write(trLower(ch));
      }

      // Tire ve kesmeden sonraki harf de büyük olmalı.
      if (ch == '-' || ch == "'") sonrakiBuyuk = true;
    }

    return b.toString();
  }
}
