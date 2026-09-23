/// Türkçe metin karşılaştırma yardımcıları.
///
/// ## Neden gerekli
/// `toLowerCase()` Türkçe için yanlış sonuç veriyor ve arama kutularında
/// öğrenciyi **bulunamaz** hâle getiriyordu:
///
///   * Öğretmen Türkçe karakter yazmadan arıyor: "Isil" yazınca
///     "Işıl Demir" bulunmuyordu ("Gulsah" → "Gülşah" de öyle).
///   * Bu, telefon klavyesinde çok yaygın: öğretmen hızlıca ASCII yazıyor.
///
/// Çözüm: iki tarafı da aksansız ASCII'ye indirgemek. Böylece "Isil",
/// "isil", "IŞIL" ve "Işıl" hepsi eşleşir.
///
/// Aynı katlama `teacher_branches.dart` içinde özel bir kopya olarak
/// duruyordu; tek kaynağa taşındı ki arama ekranları da faydalansın.
library;

const Map<String, String> _foldMap = {
  'İ': 'i', 'I': 'i', 'ı': 'i', 'i': 'i',
  'Ş': 's', 'ş': 's',
  'Ğ': 'g', 'ğ': 'g',
  'Ü': 'u', 'ü': 'u',
  'Ö': 'o', 'ö': 'o',
  'Ç': 'c', 'ç': 'c',
  'Â': 'a', 'â': 'a',
  'Î': 'i', 'î': 'i',
  'Û': 'u', 'û': 'u',
};

/// Metni karşılaştırmaya uygun hâle getirir: küçük harf + aksansız.
///
/// Yalnızca **karşılaştırma** için kullanılır; kullanıcıya gösterilecek
/// metinde asla kullanılmamalı (öğrencinin adı "Işıl" olarak kalmalı).
String trFold(String raw) {
  final buffer = StringBuffer();
  for (final ch in raw.split('')) {
    buffer.write(_foldMap[ch] ?? ch.toLowerCase());
  }
  return buffer.toString();
}

/// [haystack] içinde [needle] aranıyor mu? (Türkçe duyarsız)
///
/// Boş arama her zaman eşleşir; arama kutusu boşken liste tam görünür.
bool trContains(String haystack, String needle) {
  final n = needle.trim();
  if (n.isEmpty) return true;
  return trFold(haystack).contains(trFold(n));
}

const Map<String, String> _asciiMap = {
  'Ç': 'C', 'ç': 'c', 'Ğ': 'G', 'ğ': 'g', 'İ': 'I', 'ı': 'i',
  'Ö': 'O', 'ö': 'o', 'Ş': 'S', 'ş': 's', 'Ü': 'U', 'ü': 'u',
  'Â': 'A', 'â': 'a', 'Î': 'I', 'î': 'i', 'Û': 'U', 'û': 'u',
};

/// Karekoda yazılacak metni ASCII'ye katlar — büyük/küçük harf KORUNUR.
///
/// ## Neden
///
/// Karekod bayt kipinde karakter kümesi yazmıyor; okuyucu tahmin ediyor.
/// Gerçek okuyucuyla (zbar) sınanınca UTF-8 `Şükrü` Shift-JIS sanılıp
/// bozuldu. Daha kötüsü `ş`/`Ç` gibi harflerin ikinci baytı orada çok
/// baytlı karakter başı ve arkasındaki `:` ayırıcısını yutabiliyor —
/// `qrAyristir` 5 alan bulamaz, kurulum "geçersiz karekod" der
/// (23 Eylül 2026, tahta deposunda bulundu).
///
/// [trFold]'dan farkı: o karşılaştırma için küçük harfe indiriyor; bu
/// gösterim için harfi koruyor. Karşılığı olmayan karakter atılıyor.
String asciiKatla(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    final karsilik = _asciiMap[ch];
    if (karsilik != null) {
      buffer.write(karsilik);
    } else if (rune < 128) {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}
