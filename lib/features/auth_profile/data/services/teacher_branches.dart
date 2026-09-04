/// Okul türüne göre öğretmen branşları.
///
/// ## Neden gerekliydi
/// Branş ilk kayıtta hiç sorulmuyordu; yalnızca profil ekranından
/// serbest metin olarak girilebiliyordu. Sonuç: okul dizininde
/// `branch: ""` — sınıf öğretmeni kadroya birini eklerken "kim hangi
/// derse giriyor" bilgisi yoktu, listede yalnızca isimler görünüyordu.
///
/// Liste kapalı değildir: MEB branşları değişiyor (yeni seçmeli dersler,
/// Harezmî atölyeleri), katı bir liste öğretmeni kilitlerdi. Bu yüzden
/// her listenin sonunda [other] bulunur ve elle giriş açılır.
class TeacherBranches {
  const TeacherBranches._();

  /// Listede olmayan branş için tetikleyici.
  ///
  /// Kendisi geçerli bir branş DEĞİLDİR: seçilince kullanıcıdan metin
  /// istenir ([isValid] bunu reddeder).
  static const String other = 'Diğer (elle yaz)';

  /// Her kademede ortak olanlar.
  static const List<String> _common = [
    'Rehberlik',
    'Bilişim Teknolojileri',
    'Görsel Sanatlar',
    'Müzik',
    'Beden Eğitimi',
    'Din Kültürü ve Ahlak Bilgisi',
    'Özel Eğitim',
  ];

  static const List<String> _primary = [
    // İlkokulda sınıf öğretmenliği bir branştır; ortaokul ve lisede
    // ise bir görevdir (rehber öğretmen), o yüzden yalnızca burada.
    'Sınıf Öğretmeni',
    'Okul Öncesi',
    'İngilizce',
  ];

  static const List<String> _middle = [
    'Türkçe',
    'Matematik',
    // Ortaokulda Fen tek derstir; lisede Fizik/Kimya/Biyoloji ayrılır.
    'Fen Bilimleri',
    'Sosyal Bilgiler',
    'İngilizce',
    'Almanca',
    'Teknoloji ve Tasarım',
    'Harezmî Atölyesi',
  ];

  static const List<String> _high = [
    'Türk Dili ve Edebiyatı',
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'İngilizce',
    'Almanca',
    'Fransızca',
    'Sağlık Bilgisi',
  ];

  static const List<String> _vocational = [
    'Meslek Dersleri',
    'Muhasebe ve Finansman',
    'Çocuk Gelişimi',
    'Bilişim Teknolojileri (Meslek)',
    'Elektrik-Elektronik',
    'Makine Teknolojisi',
  ];

  static const List<String> _religious = [
    'Meslek Dersleri (İHL)',
    'Arapça',
    'Kur\'an-ı Kerim',
    'Temel Dini Bilgiler',
    'Siyer',
  ];

  /// Verilen okul türü için branş listesi.
  ///
  /// Tanınmayan tür (veri dosyalarında "Diğer" çok sık) genel listeye
  /// düşer: öğretmeni boş bir seçicide bırakmak yerine ortak branşları
  /// ve her kademeden yaygın olanları sunar.
  static List<String> forSchoolType(String schoolType) {
    final t = _fold(schoolType);

    final List<String> specific;
    if (t.contains('ilkokul')) {
      specific = _primary;
    } else if (t.contains('imam hatip ortaokul')) {
      specific = [..._middle, ..._religious];
    } else if (t.contains('ortaokul')) {
      specific = _middle;
    } else if (t.contains('imam hatip')) {
      specific = [..._high, ..._religious];
    } else if (t.contains('mesleki') || t.contains('teknik')) {
      specific = [..._high, ..._vocational];
    } else if (t.contains('lise')) {
      specific = _high;
    } else if (t.contains('anaokul') || t.contains('okul oncesi')) {
      specific = ['Okul Öncesi'];
    } else {
      // Bilinmeyen tür: her kademeden yaygın branşlar.
      specific = [
        'Sınıf Öğretmeni',
        ..._middle,
        'Türk Dili ve Edebiyatı',
        'Fizik',
        'Kimya',
        'Biyoloji',
        'Tarih',
        'Coğrafya',
      ];
    }

    // Sırayı koruyarak tekrarları at (ör. İngilizce iki listede de var).
    final seen = <String>{};
    final result = <String>[];
    for (final b in [...specific, ..._common]) {
      if (seen.add(b)) result.add(b);
    }
    result.add(other);
    return result;
  }

  /// Kaydedilebilir bir branş mı?
  static bool isValid(String branch) {
    final trimmed = branch.trim();
    return trimmed.isNotEmpty && trimmed != other;
  }

  /// Türkçe güvenli karşılaştırma anahtarı.
  ///
  /// `toLowerCase()` Türkçe'de bozulur: 'İ' harfi 'i' + birleşen nokta
  /// üretir ve eşleşme kaçar. Karşılaştırmadan önce sorunlu harfler
  /// açıkça sadeleştirilir.
  static String _fold(String raw) {
    const map = {
      'İ': 'i', 'I': 'i', 'ı': 'i',
      'Ş': 's', 'ş': 's',
      'Ğ': 'g', 'ğ': 'g',
      'Ü': 'u', 'ü': 'u',
      'Ö': 'o', 'ö': 'o',
      'Ç': 'c', 'ç': 'c',
    };
    final buffer = StringBuffer();
    for (final ch in raw.split('')) {
      buffer.write(map[ch] ?? ch.toLowerCase());
    }
    return buffer.toString();
  }
}
