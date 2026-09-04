/// SınıfCepte - Öğrenci İsim ve Soyisim Formatlayıcı (KVKK & Liste Standardı)
class StudentNameFormatter {
  StudentNameFormatter._();

  /// Öğrencinin soyadının yalnızca ilk harfini ve nokta bırakır.
  ///
  /// Örnekler:
  /// - "Ahmet Yılmaz" -> "Ahmet Y."
  /// - "Mehmet Ali Kaya" -> "Mehmet Ali K."
  /// - "Ayşe" -> "Ayşe"
  /// - "Elif Nur Dağdelen" -> "Elif Nur D."
  static String maskLastName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length <= 1) return trimmed;
    final firstName = parts.sublist(0, parts.length - 1).join(' ');
    final lastName = parts.last;
    final initial = lastName.isNotEmpty ? '${lastName[0].toUpperCase()}.' : '';
    return '$firstName $initial'.trim();
  }

  /// Örnek: "108 - Ahmet Y."
  static String formatWithNumber({
    required int number,
    required String fullName,
  }) {
    final masked = maskLastName(fullName);
    return '$number - $masked';
  }

  /// Örnek: "108 - Ahmet Y. - SC-8A-9402"
  static String formatRowWithCode({
    required int number,
    required String fullName,
    required String code,
  }) {
    final masked = maskLastName(fullName);
    return '$number - $masked - $code';
  }

  /// Toplu WhatsApp/PDF Paylaşımı İçin (Okul Numarasız - 2FA Güvenlik Korumalı)
  /// Örnek: "• Ahmet Y.  ➔  SC-8A-9402"
  static String formatPublicRowWithCode({
    required String fullName,
    required String code,
  }) {
    final masked = maskLastName(fullName);
    return '• $masked  ➔  $code';
  }
}
