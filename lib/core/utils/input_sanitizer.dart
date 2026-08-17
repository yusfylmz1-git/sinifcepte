import 'package:flutter/services.dart';

/// SınıfCepte - Kullanıcı Girdisi Temizleyici ve Doğrulayıcı (Input Sanitizer & Shield)
class InputSanitizer {
  InputSanitizer._();

  /// Sınıf Adı Clean Formatter (Örn: "5a", "beşa", "5 a" -> "5-A")
  static String cleanClassName(String rawInput) {
    if (rawInput.trim().isEmpty) return '';

    // 1. Türkçe Karakter Uyumlu Büyük Harf Çevrimi
    String cleaned = rawInput.trim()
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ş', 'Ş')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ç', 'Ç')
        .replaceAll('ö', 'Ö')
        .replaceAll('ü', 'Ü')
        .toUpperCase();

    // 2. Özel format kontrolü: (Sayı veya Sayı Okunuşu) + (Noktalama/Boşluk) + (Tek Harf)
    // Örn: "5 B", "5.B", "5?B", "BEŞ-A", "ON BİR C", "12/A"
    final pattern = RegExp(r'^(BİR|İKİ|ÜÇ|DÖRT|BEŞ|ALTI|YEDİ|SEKİZ|DOKUZ|ON|ON\s+BİR|ON\s+İKİ|\d{1,2})[^A-ZÇĞİÖŞÜ0-9]*([A-ZÇĞİÖŞÜ])$');
    final match = pattern.firstMatch(cleaned);

    if (match != null) {
      String gradeStr = match.group(1)!;
      final branch = match.group(2)!;

      // Eğer sayıyla değil yazıyla yazılmışsa rakama çevir
      final Map<String, String> wordToNum = {
        'BİR': '1', 'İKİ': '2', 'ÜÇ': '3', 'DÖRT': '4', 'BEŞ': '5',
        'ALTI': '6', 'YEDİ': '7', 'SEKİZ': '8', 'DOKUZ': '9', 'ON': '10',
        'ON BİR': '11', 'ON İKİ': '12'
      };

      // Eğer 'ON BİR' gibi boşluklu yazılmışsa, normalize etmek için boşlukları tek boşluğa indirelim
      gradeStr = gradeStr.replaceAll(RegExp(r'\s+'), ' ');
      final gradeNum = wordToNum[gradeStr] ?? gradeStr;

      return '$gradeNum-$branch';
    }

    // 3. Eğer normal 5-A formatı değil de "LAB 1", "KÜTÜPHANE" gibi özel bir isimse:
    // Sadece çoklu boşlukları tek boşluğa indirgeyip şık bir formata getirelim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  /// Öğrenci Okul Numarası Sanitizer (Sadece Rakam)
  static String sanitizeStudentNumber(String input) {
    return input.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Boşluk, Virgül veya Noktalı Virgülle Ayrılmış Soru Puanları Ayrıştırıcı ("10 15 25" veya "10, 15, 25" -> [10, 15, 25])
  static List<double> parseSpaceSeparatedScores(String rawText) {
    if (rawText.trim().isEmpty) return [];

    // Boşluk, virgül veya noktalı virgül ile ayrılmış sayıları parçalar
    final parts = rawText.trim().split(RegExp(r'[\s,;]+'));
    final List<double> scores = [];

    for (var part in parts) {
      if (part.isEmpty) continue;
      final parsed = double.tryParse(part.replaceAll(',', '.'));
      if (parsed != null && parsed >= 0) {
        scores.add(parsed);
      }
    }

    return scores;
  }

  /// Soru puanları toplamı 100 mü kontrolü
  static bool validateTotalHundred(List<double> scores) {
    if (scores.isEmpty) return false;
    final total = scores.fold<double>(0.0, (sum, val) => sum + val);
    return (total - 100.0).abs() < 0.001;
  }
}

/// Sınıf Adı İçin Otomatize Formatter (TextInputFormatter)
class ClassNameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final formatted = InputSanitizer.cleanClassName(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
