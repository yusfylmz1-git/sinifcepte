/// Öğretmen branşını müfredat `subject_code` ile eşler. Eşleşmezse null —
/// seçici o kademedeki tüm dersleri listeler.
class BepSubjectCodes {
  BepSubjectCodes._();

  static const Map<String, String> _map = {
    'matematik': 'MAT',
    'türkçe': 'TURKCE',
    'turkce': 'TURKCE',
    'fen bilimleri': 'FEN',
    'fen': 'FEN',
    'sosyal bilgiler': 'SOSYAL',
    'ingilizce': 'ING',
    'bilişim teknolojileri': 'BILISIM',
    'bilişim teknolojileri ve yazılım': 'BILISIM',
    'din kültürü ve ahlak bilgisi': 'DKAB',
    'görsel sanatlar': 'GORSEL',
    'müzik': 'MUZIK',
    'beden eğitimi': 'BEDEN',
    'türk dili ve edebiyatı': 'TDE',
    'fizik': 'FIZIK',
    'kimya': 'KIMYA',
    'biyoloji': 'BIYO',
    'tarih': 'TARIH',
    'coğrafya': 'COG',
    'felsefe': 'FEL',
  };

  static String? guess(String branch) {
    final key = branch.trim().toLowerCase();
    if (key.isEmpty) return null;
    if (_map.containsKey(key)) return _map[key];
    for (final e in _map.entries) {
      if (key.contains(e.key) || e.key.contains(key)) return e.value;
    }
    return null;
  }

  /// Yayınevi satırlarını eler; dropdown'da her ders bir kez çıkar.
  static List<Map<String, dynamic>> uniqueByCode(
    List<Map<String, dynamic>> subjects,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final s in subjects) {
      final code = (s['subject_code'] as String? ?? '').trim();
      if (code.isEmpty || !seen.add(code)) continue;
      out.add(s);
    }
    return out;
  }
}
