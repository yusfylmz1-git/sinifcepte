import 'package:flutter/material.dart';
import '../../../../core/services/whatsapp_share_service.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../data/models/classroom_participation_model.dart';
import 'participation_pdf_generator.dart';

/// SınıfCepte - Ders İçi Katılım & Performans WhatsApp Mesaj Motoru
class ParticipationWhatsAppHelper {
  ParticipationWhatsAppHelper._();

  /// Sınıf veli grubu için gün sonu bilgilendirme ve tebrik metni üretir
  static String generateDailyClassSummary({
    required ClassroomParticipationSession session,
    required String teacherName,
    String? schoolName,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('📢 *${session.className} - DERS GÜNLÜĞÜ VE DEĞERLENDİRME*');
    if (schoolName != null && schoolName.isNotEmpty) {
      buffer.writeln('🏫 $schoolName');
    }
    buffer.writeln('📅 *Tarih:* ${session.date} | *Ders:* ${session.lessonHour}. Saat (${session.subjectName})');
    if (session.topicName != null && session.topicName!.isNotEmpty) {
      buffer.writeln('📖 *İşlenen Konu:* ${session.topicName}');
    }
    buffer.writeln('----------------------------------------');

    // Ödev Özeti
    buffer.writeln('📚 *Ödev Kontrol Durumu:*');
    buffer.writeln('   • Eksiksiz Yapan: ${session.homeworkDoneCount} / ${session.totalStudents} öğrenci (%${session.homeworkCompletionRate.toStringAsFixed(0)})');
    if (session.homeworkNoneCount > 0) {
      buffer.writeln('   • Ödev Teslim Etmeyen: ${session.homeworkNoneCount} öğrenci');
    }

    // Araç-Gereç Durumu
    buffer.writeln('🎒 *Araç-Gereç (Kitap/Defter):* %${session.materialsReadinessRate.toStringAsFixed(0)} tam');

    // Derste Yıldız Kazanan / Aktif Katılan Öğrenciler
    if (session.starStudentNames.isNotEmpty) {
      buffer.writeln('\n🌟 *Günün Parlayanları (Aktif Katılım):*');
      for (var name in session.starStudentNames) {
        buffer.writeln('   ✨ $name');
      }
    }

    buffer.writeln('\n💡 *Öğretmen Notu:*');
    buffer.writeln('Öğrencilerimizin dersteki ilgi ve gayretleri için teşekkür eder, ödev kontrollerinin evde de velilerimizce desteklenmesini rica ederim.');
    buffer.writeln('\nİyi günler dilerim.');
    buffer.writeln('👨‍🏫 *${teacherName.isNotEmpty ? teacherName : 'Ders Öğretmeni'}*');

    return buffer.toString();
  }

  /// Tüm öğrencilerin tek tek özetlendiği detaylı liste metni üretir
  static String generateDetailedStudentListMessage({
    required ClassroomParticipationSession session,
    required String teacherName,
    String? schoolName,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('📋 *${session.className} - DERS İÇİ KATILIM VE DEĞERLENDİRME LİSTESİ*');
    if (schoolName != null && schoolName.isNotEmpty) {
      buffer.writeln('🏫 $schoolName');
    }
    buffer.writeln('📅 *Tarih:* ${session.date} | *Ders:* ${session.lessonHour}. Saat (${session.subjectName})');
    buffer.writeln('========================================');

    for (var eval in session.evaluations) {
      // Ödev
      String hw = 'Ödev: ';
      if (eval.homeworkStatus == HomeworkStatus.done) {
        hw += 'Yaptı ✓';
      } else if (eval.homeworkStatus == HomeworkStatus.partial) {
        hw += 'Eksik ±';
      } else if (eval.homeworkStatus == HomeworkStatus.none) {
        hw += 'Yapmadı ✗';
      } else {
        hw += 'Yok';
      }

      // Materyal
      String mat = eval.materialsStatus == MaterialsStatus.ready ? 'Defter/Kitap: Getirdi 📚' : 'Defter/Kitap: Getirmedi ❌';

      // Zamanlama
      String arr = eval.arrivalStatus == ArrivalStatus.onTime ? 'Zamanında Geldi ⏰' : 'Geç Geldi ⌛';

      // Katılım
      String star = eval.starsCount > 0 ? 'Katılım: ${eval.starEmoji} (${eval.starLabel})' : 'Katılım: -';

      // Özel Not / Etiket
      final noteParts = <String>[];
      if (eval.customTags.isNotEmpty) noteParts.add(eval.customTags.join(', '));
      if (eval.note != null && eval.note!.trim().isNotEmpty) noteParts.add(eval.note!.trim());
      final noteStr = noteParts.isNotEmpty ? ' | Not: ${noteParts.join(' ')}' : '';

      buffer.writeln('🔹 *${eval.studentNumber}* - *${eval.studentName}* | $hw | $mat | $arr | $star$noteStr');
    }

    buffer.writeln('========================================');
    buffer.writeln('👨‍🏫 *${teacherName.isNotEmpty ? teacherName : 'Ders Öğretmeni'}*');

    return buffer.toString();
  }

  /// Tekil öğrenci velisine özel tebrik veya durum bilgilendirme metni üretir
  static String generateIndividualStudentMessage({
    required StudentParticipationEvaluation eval,
    required String subjectName,
    required String date,
    required String teacherName,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Sayın Velimiz,');
    buffer.writeln('Öğrencimiz *${eval.studentName}* ($subjectName dersi - $date) günü;');

    if (eval.starsCount > 0) {
      buffer.writeln('🌟 Derse çok aktif katılarak *${eval.starsCount} Başarı Yıldızı* kazanmıştır. Tebrik ederim!');
    }

    if (eval.homeworkStatus == HomeworkStatus.done) {
      buffer.writeln('📚 Ev ödevini eksiksiz ve özenli bir şekilde tamamlamıştır.');
    } else if (eval.homeworkStatus == HomeworkStatus.partial) {
      buffer.writeln('⚠️ Ev ödevinde bazı eksikler tespit edilmiştir, lütfen kontrol ediniz.');
    } else if (eval.homeworkStatus == HomeworkStatus.none) {
      buffer.writeln('❌ Bugün verilmiş olan ödevini teslim etmemiştir. Evde takibini rica ederim.');
    }

    if (eval.materialsStatus == MaterialsStatus.missing) {
      buffer.writeln('🎒 Ders araç-gereçlerini (kitap/defter) yanında getirmeyi unutmuştur.');
    }

    if (eval.customTags.isNotEmpty) {
      buffer.writeln('🏷️ Gözlem: ${eval.customTags.join(', ')}');
    }

    if (eval.note != null && eval.note!.isNotEmpty) {
      buffer.writeln('📝 Not: ${eval.note}');
    }

    buffer.writeln('\nBilgilerinize sunar, başarılar dilerim.');
    buffer.writeln('👨‍🏫 *${teacherName.isNotEmpty ? teacherName : 'Ders Öğretmeni'}*');

    return buffer.toString();
  }

  /// WhatsApp Önizleme ve Kopyalama Modal'ı
  static void showWhatsAppModal({
    required BuildContext context,
    required String messageText,
    required String title,
  }) {
    ResponsiveBottomSheet.show(
      context: context,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.25)),
            ),
            child: SelectableText(
              messageText,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final success = await WhatsAppShareService.copyToClipboard(messageText);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'WhatsApp mesaj metni panoya kopyalandı! 📋'
                                : 'Kopyalama başarısız.',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Panoya Kopyala ve Paylaş'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// WhatsApp Sınıf Paylaşımı Seçenek Modalı (Özet Günlük veya Detaylı Öğrenci Listesi)
  static void showClassShareOptions({
    required BuildContext context,
    required ClassroomParticipationSession session,
    required String teacherName,
    String? schoolName,
  }) {
    ResponsiveBottomSheet.show(
      context: context,
      title: '${session.className} WhatsApp Paylaşımı',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFF25D366).withValues(alpha: 0.1),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF25D366),
              child: Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
            ),
            title: const Text('Grup İçin Günlük Ders Özeti', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Ödev oranları, araç-gereç durumu ve günün yıldız öğrencileri'),
            onTap: () {
              Navigator.pop(context);
              final msg = generateDailyClassSummary(
                session: session,
                teacherName: teacherName,
                schoolName: schoolName,
              );
              showWhatsAppModal(
                context: context,
                messageText: msg,
                title: '${session.className} WhatsApp Günlüğü',
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF0284C7),
              child: Icon(Icons.format_list_numbered_rounded, color: Colors.white, size: 20),
            ),
            title: const Text('Detaylı Öğrenci Değerlendirme Listesi', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Tüm öğrencilerin ödev, materyal, geliş ve yıldız listesi'),
            onTap: () {
              Navigator.pop(context);
              final msg = generateDetailedStudentListMessage(
                session: session,
                teacherName: teacherName,
                schoolName: schoolName,
              );
              showWhatsAppModal(
                context: context,
                messageText: msg,
                title: '${session.className} Detaylı Öğrenci Listesi',
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFFE11D48).withValues(alpha: 0.1),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE11D48),
              child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            ),
            title: const Text('Resmî PDF Raporunu Paylaş (WhatsApp)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('A4 formatında ders değerlendirme çizelgesini PDF olarak gönder'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await ParticipationPdfGenerator.shareOrPrintClassPdf(
                  session: session,
                  teacherName: teacherName,
                  schoolName: schoolName,
                );
              } catch (e, stackTrace) {
                debugPrint('PDF Paylaşım Hatası: $e\n$stackTrace');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF oluşturulurken bir hata oluştu.')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
