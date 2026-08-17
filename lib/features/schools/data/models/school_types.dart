/// Tek okul türü tablosu (modal, normalizer, shard).
class SchoolTypes {
  SchoolTypes._();

  static const allFilter = 'Tümü';

  static const values = <String>[
    'İlkokul',
    'Ortaokul',
    'İmam Hatip Ortaokulu',
    'Anadolu Lisesi',
    'Fen Lisesi',
    'Anadolu İmam Hatip Lisesi',
    'Mesleki ve Teknik Anadolu Lisesi',
    'Sosyal Bilimler Lisesi',
    'Özel Okul / Kolej',
    'BİLSEM',
    'Diğer',
  ];

  static const filterChips = <String>[allFilter, ...values];

  static String inferFromName(String rawName) {
    final n = rawName.toLowerCase();
    if (n.contains('bilsem') || n.contains('bilim ve sanat')) return 'BİLSEM';
    if (n.contains('özel') || n.contains('kolej')) return 'Özel Okul / Kolej';
    if (n.contains('sosyal bilimler')) return 'Sosyal Bilimler Lisesi';
    if (n.contains('fen lisesi')) return 'Fen Lisesi';
    if (n.contains('mesleki') || n.contains('mtal') || n.contains('teknik anadolu')) {
      return 'Mesleki ve Teknik Anadolu Lisesi';
    }
    if (n.contains('imam hatip lisesi') || n.contains(' ihl') || n.contains('anadolu imam')) {
      return 'Anadolu İmam Hatip Lisesi';
    }
    if (n.contains('imam hatip ortaokulu') || n.contains(' iho')) {
      return 'İmam Hatip Ortaokulu';
    }
    if (n.contains('anadolu lisesi') || n.contains('çpal') || n.contains('çok programlı')) {
      return 'Anadolu Lisesi';
    }
    if (n.contains('ortaokul')) return 'Ortaokul';
    if (n.contains('ilkokul')) return 'İlkokul';
    return 'Diğer';
  }

  static bool isExcludedInstitution(String rawName) {
    final n = rawName.toLowerCase();
    if (n.contains('milli eğitim müdürlüğü') || n.contains('mem ')) return true;
    if (n.contains('ilçe milli') || n.contains('il milli')) return true;
    if (n.contains('bakanlık')) return true;
    return false;
  }
}
