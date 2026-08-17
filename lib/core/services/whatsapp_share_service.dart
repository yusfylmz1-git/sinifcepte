import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// SınıfCepte - Akıllı WhatsApp Şablon Motoru & Paylaşım Servisi
class WhatsAppShareService {
  WhatsAppShareService._();

  /// Ders İçi Katılım & Davranış Özeti Oluşturucu
  static String generateClassSummaryText({
    required String className,
    required String subjectName,
    required int totalStudents,
    required List<String> starStudentNames, // Yıldız / Olumlu alanlar
    required List<String> needsWorkStudentNames, // Geliştirilmeli olanlar
  }) {
    final buffer = StringBuffer();
    final today = DateTime.now();
    final dateStr = '${today.day}.${today.month}.${today.year}';

    buffer.writeln('📚 *SınıfCepte Ders Bilgilendirmesi*');
    buffer.writeln('🏫 *Sınıf:* $className');
    buffer.writeln('📖 *Ders:* $subjectName ($dateStr)');
    buffer.writeln('-----------------------------------');

    // Senaryo 1: Tüm Sınıf Başarılı
    if (needsWorkStudentNames.isEmpty && starStudentNames.length == totalStudents) {
      buffer.writeln('🌟 *Harika Haber!* Bugünü tüm sınıfımız eksiksiz ders katılımı ve yüksek motivasyonla tamamlamıştır. Tüm öğrencilerimizi tebrik ediyoruz! 👏👏');
    }
    // Senaryo 2: 1-4 Kişi Öne Çıktıysa İsim İsim Detay
    else if (starStudentNames.isNotEmpty && starStudentNames.length <= 4) {
      buffer.writeln('⭐ *Dersin Yıldız Öğrencileri:*');
      for (var name in starStudentNames) {
        buffer.writeln('• $name 🌟');
      }
      if (needsWorkStudentNames.isNotEmpty) {
        buffer.writeln('\n⚠️ *Ders Takibi Gerekenler:*');
        for (var name in needsWorkStudentNames) {
          buffer.writeln('• $name');
        }
      }
    }
    // Senaryo 3: 5+ Kişi Öne Çıktıysa Sayısal Özet Metni
    else {
      buffer.writeln('📊 *Ders Katılım Özeti:*');
      buffer.writeln('• Yıldız Derecesi Alan: ${starStudentNames.length} öğrenci ⭐');
      if (needsWorkStudentNames.isNotEmpty) {
        buffer.writeln('• Ekstra Destek Gereken: ${needsWorkStudentNames.length} öğrenci ✍️');
      }
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('✨ _SınıfCepte Öğretmen Asistanı ile gönderilmiştir._');

    return buffer.toString();
  }

  /// Metni Panoya Kopyalama Yardımcısı
  static Future<bool> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (e, stackTrace) {
      debugPrint('Panoya kopyalama hatası: $e\n$stackTrace');
      return false;
    }
  }
}
