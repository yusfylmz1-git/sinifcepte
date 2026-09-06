import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../models/lesson_model.dart';
import '../models/schedule_settings.dart';
import '../../../core/pdf/pdf_tr_fonts.dart';

/// SınıfCepte - MEB Standartlarında A4 Haftalık Ders Programı PDF Üreticisi
class SchedulePdfGenerator {
  SchedulePdfGenerator._();

  static const List<String> _weekDays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
  ];

  static Future<void> printOrShareWeeklySchedule({
    required BuildContext context,
    required List<LessonModel> lessons,
    required ScheduleSettings settings,
    required TeacherProfileModel profile,
  }) async {
    try {
      final doc = await PdfTrFonts.document();

      // Türkçe Fontları Yükle

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. ÜST BAŞLIK
                _buildHeader(profile),
                pw.SizedBox(height: 14),

                // 2. HAFTALIK DERS MATRİS TABLOSU
                pw.Expanded(
                  child: _buildScheduleTable(lessons, settings),
                ),
                pw.SizedBox(height: 12),

                // 3. İMZA VE ONAY ALANI
                _buildFooter(profile),
              ],
            );
          },
        ),
      );

      final fileName = 'Haftalik_Ders_Programi_${DateTime.now().year}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => PdfTrFonts.kaydet(doc),
        name: fileName,
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (SchedulePdfGenerator) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-------------------------------------------------------------------');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ders programı PDF dosyası oluşturulurken bir hata oluştu.')),
        );
      }
    }
  }

  static pw.Widget _buildHeader(
    TeacherProfileModel profile,
  ) {
    final school = profile.schoolName.isNotEmpty ? profile.schoolName.toUpperCase() : 'MİLLÎ EĞİTİM BAKANLIĞI';
    final teacher = profile.fullName.isNotEmpty ? profile.fullName : 'Öğretmen';
    final branch = profile.branch.isNotEmpty ? profile.branch : 'Branş Belirtilmedi';

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                school,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue900),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'ÖĞRETMEN HAFTALIK DERS DAĞITIM ÇİZELGESİ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Öğretmen: $teacher ($branch)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Eğitim Öğretim Yılı: 2025 - 2026',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScheduleTable(
    List<LessonModel> lessons,
    ScheduleSettings settings,
  ) {
    final headers = ['Ders / Saat', ..._weekDays];

    // Satırları oluştur (Ders saatleri + Öğle arası)
    final rows = <List<String>>[];

    for (int i = 0; i < settings.dailyLessonCount; i++) {
      // Öğle arası satırı ekle
      if (settings.hasLunchBreak && i == settings.lunchBreakAfterLesson) {
        final lunchTime = settings.calculateLunchTimeRange();
        rows.add(['ÖĞLE ARASI\n$lunchTime', 'ÖĞLE ARASI', 'ÖĞLE ARASI', 'ÖĞLE ARASI', 'ÖĞLE ARASI', 'ÖĞLE ARASI']);
      }

      final timeRange = settings.calculateTimeRange(i);
      final row = <String>['${i + 1}. Ders\n$timeRange'];

      for (final day in _weekDays) {
        final lesson = lessons.where((l) => l.day == day && l.lessonHourIndex == i).firstOrNull;
        if (lesson != null) {
          row.add('${lesson.className}\n${lesson.lessonName}');
        } else {
          row.add('-');
        }
      }
      rows.add(row);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.center,
      cellStyle: pw.TextStyle(fontSize: 9.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      columnWidths: {
        0: const pw.FixedColumnWidth(85), // Saat sütunu
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1),
      },
    );
  }

  static pw.Widget _buildFooter(
    TeacherProfileModel profile,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'Yukarıdaki ders programı .../.../2026 tarihinde yürürlüğe girmiştir.',
          style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
        ),
        pw.Row(
          children: [
            pw.Column(
              children: [
                pw.Text(profile.fullName.isNotEmpty ? profile.fullName : 'Öğretmen',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                pw.SizedBox(height: 2),
                pw.Text('Ders Öğretmeni', style: pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 18),
                pw.Text('İmza: ...................', style: pw.TextStyle(fontSize: 8.5)),
              ],
            ),
            pw.SizedBox(width: 50),
            pw.Column(
              children: [
                pw.Text('Okul Müdürü', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                pw.SizedBox(height: 2),
                pw.Text('Mühür / İmza', style: pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 18),
                pw.Text('İmza: ...................', style: pw.TextStyle(fontSize: 8.5)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
