import 'dart:io';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/models/class_model.dart';
import '../models/seating_plan_model.dart';

/// Gerçekçi Sınıf Oturma Planı A4 PDF Motoru
class SeatingPlanPdfGenerator {
  SeatingPlanPdfGenerator._();

  static Future<void> generateAndShare({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required SeatingPlanModel plan,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildHeader(classModel),
              pw.SizedBox(height: 12),
              _buildClassroomFrontElements(),
              pw.SizedBox(height: 16),
              pw.Expanded(
                child: _buildClassroomBlocks(plan, students),
              ),
              pw.SizedBox(height: 12),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Sinif_Oturma_Plani_${classModel.name}.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${classModel.name} Sınıfı Oturma Planı Krokisi',
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Oturma planı PDF hatası: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulurken hata oluştu: $e')),
        );
      }
    }
  }

  static pw.Widget _buildHeader(ClassModel classModel) {
    return pw.Column(
      children: [
        pw.Text(
          'T.C. MİLLÎ EĞİTİM BAKANLIĞI',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '2024-2025 EĞİTİM-ÖĞRETİM YILI',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            '${classModel.name} SINIFI OTURMA PLANI KROKİSİ',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildClassroomFrontElements() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Pencereler
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.blue50,
          ),
          child: pw.Text('[ PENCERE KENARI ]', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        ),

        // Öğretmen Masası
        pw.Container(
          width: 80,
          height: 28,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.brown, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            color: PdfColors.brown100,
          ),
          child: pw.Center(
            child: pw.Text('Öğretmen Masası', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ),
        ),

        // Yazı Tahtası
        pw.Container(
          width: 140,
          height: 28,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            color: PdfColors.green900,
          ),
          child: pw.Center(
            child: pw.Text(
              'YAZI TAHTASI',
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
            ),
          ),
        ),

        // Kapı
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.orange800, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.orange50,
          ),
          child: pw.Text('[ KAPI / GİRİŞ ]', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
        ),
      ],
    );
  }

  static pw.Widget _buildClassroomBlocks(SeatingPlanModel plan, List<StudentModel> students) {
    final blocks = plan.columns;
    final rows = plan.rows;

    List<String> blockTitles;
    if (blocks == 2) {
      blockTitles = ['PENCERE KENARI', 'KAPI KENARI'];
    } else if (blocks == 4) {
      blockTitles = ['PENCERE', 'ORTA 1', 'ORTA 2', 'KAPI'];
    } else {
      blockTitles = ['PENCERE KENARI', 'ORTA SIRA', 'KAPI KENARI'];
    }

    // Satır sayısına göre dinamik yükseklik
    final deskHeight = rows > 7 ? 20.0 : (rows > 5 ? 24.0 : 28.0);
    final fontSize = rows > 7 ? 6.5 : 7.5;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: List.generate(blocks, (blockIndex) {
        return pw.Expanded(
          child: pw.Container(
            margin: pw.EdgeInsets.only(right: blockIndex < blocks - 1 ? 8 : 0),
            child: pw.Column(
              children: [
                // Blok Başlığı
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    blockTitles[blockIndex],
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),

                // Sıralar
                ...List.generate(rows, (rowIndex) {
                  return _buildPdfDualDesk(
                    blockIndex: blockIndex,
                    rowIndex: rowIndex,
                    students: students,
                    assignments: plan.assignments,
                    deskHeight: deskHeight,
                    fontSize: fontSize,
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }

  static pw.Widget _buildPdfDualDesk({
    required int blockIndex,
    required int rowIndex,
    required List<StudentModel> students,
    required Map<int, String> assignments,
    required double deskHeight,
    required double fontSize,
  }) {
    final leftPos = '$blockIndex,$rowIndex,0';
    final rightPos = '$blockIndex,$rowIndex,1';

    final leftStudent = _getStudentAtPos(leftPos, students, assignments);
    final rightStudent = _getStudentAtPos(rightPos, students, assignments);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.all(2.5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 2, bottom: 1.5),
            child: pw.Text('${rowIndex + 1}. Sıra', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
          ),
          pw.Row(
            children: [
              pw.Expanded(child: _buildPdfSeat(leftStudent, deskHeight, fontSize)),
              pw.SizedBox(width: 2.5),
              pw.Expanded(child: _buildPdfSeat(rightStudent, deskHeight, fontSize)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfSeat(StudentModel? student, double deskHeight, double fontSize) {
    if (student != null) {
      final isGirl = student.gender.toLowerCase().contains('kız');
      final bgColor = isGirl ? PdfColors.pink50 : PdfColors.blue50;
      final borderColor = isGirl ? PdfColors.pink400 : PdfColors.blue400;

      return pw.Container(
        height: deskHeight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.5),
        decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: borderColor, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (student.schoolNumber > 0 && deskHeight > 20)
              pw.Text('No: ${student.schoolNumber}', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey800)),
            pw.Text(
              student.fullName,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      return pw.Container(
        height: deskHeight,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5, style: pw.BorderStyle.dashed),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        child: pw.Center(
          child: pw.Text('BOŞ', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
        ),
      );
    }
  }

  static StudentModel? _getStudentAtPos(String pos, List<StudentModel> all, Map<int, String> assignments) {
    for (var entry in assignments.entries) {
      if (entry.value == pos) {
        return all.where((s) => s.id == entry.key).firstOrNull;
      }
    }
    return null;
  }

  static pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Not: Koyu renkler erkek, açık/pembe renkler kız öğrencileri gösterir.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
            pw.Text('Tarih: ...... / ...... / 202...', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Sınıf Rehber Öğretmeni', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
            pw.SizedBox(height: 22),
            pw.Text('İmza: ........................................', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }
}
