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
