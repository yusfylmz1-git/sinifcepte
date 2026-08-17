import 'dart:io';
import 'package:flutter/material.dart'
    show BuildContext, ScaffoldMessenger, SnackBar, Text, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../data/models/exam_analysis_model.dart';

/// SınıfCepte - MEB Uyumlu Resmî Sınav Analiz Raporu PDF Motoru
class ExamAnalysisPdfGenerator {
  ExamAnalysisPdfGenerator._();

  /// MEB Soru Bazlı ve Klasik Sınav Analiz Raporunu PDF olarak üretir ve paylaşır
  static Future<void> generateAndShare({
    required BuildContext context,
    required ExamAnalysisModel exam,
    required TeacherProfileModel teacherProfile,
  }) async {
    try {
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final pdf = pw.Document();

      final isLandscape = exam.isQuestionBased && exam.questionCount > 6;
      final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

      final sortedStudents = List<StudentExamScore>.from(exam.studentScores)
        ..sort((a, b) => a.studentNumber.compareTo(b.studentNumber));

      final qRates = exam.questionSuccessRates;
      final qAvgs = exam.questionAverages;
      final dist = exam.gradeDistribution;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
          header: (pw.Context ctx) => _buildOfficialHeader(
            teacherProfile: teacherProfile,
            exam: exam,
          ),
          footer: (pw.Context ctx) => _buildOfficialFooter(
            teacherProfile: teacherProfile,
            pageNumber: '${ctx.pageNumber} / ${ctx.pagesCount}',
          ),
          build: (pw.Context ctx) => [
            pw.SizedBox(height: 8),

            // Sınav Bilgi Kartı
            _buildExamInfoSummary(exam),
            pw.SizedBox(height: 10),

            // Öğrenci Soru Notları Tablosu
            _buildStudentScoreTable(exam, sortedStudents),
            pw.SizedBox(height: 12),

            // İstatistik ve Soru Başarı Analiz Özeti
            _buildAnalysisSummary(exam, qRates, qAvgs, dist),
            pw.SizedBox(height: 12),
          ],
        ),
      );

      final fileName = 'Sinav_Analizi_${exam.className}_${exam.examTitle.replaceAll(' ', '_')}.pdf';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${exam.className} ${exam.subjectName} ${exam.examTitle} Sınav Analiz Raporu',
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisPdf.generateAndShare) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-------------------------------------------------------------------------------');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sınav Analiz PDF oluşturulamadı: $e')),
        );
      }
    }
  }

  /// PDF Üst Başlık (MEB Anteti)
  static pw.Widget _buildOfficialHeader({
    required TeacherProfileModel teacherProfile,
    required ExamAnalysisModel exam,
  }) {
    final schoolName = teacherProfile.schoolName.isNotEmpty
        ? teacherProfile.schoolName.toUpperCase()
        : 'T.C. MİLLÎ EĞİTİM BAKANLIĞI';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('T.C.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text('MİLLÎ EĞİTİM BAKANLIĞI', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(schoolName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(
          '${exam.className} SINIFI ${exam.subjectName.toUpperCase()} DERSİ ${exam.examTitle.toUpperCase()} SINAV ANALİZ VE DEĞERLENDİRME FORMU',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.grey600, thickness: 1),
      ],
    );
  }

  /// Sınav Özet Bilgileri Çizelgesi
  static pw.Widget _buildExamInfoSummary(ExamAnalysisModel exam) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Sınıf: ${exam.className}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text('Ders: ${exam.subjectName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text('Sınav Tarihi: ${exam.examDate}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'Sınav Türü: ${exam.isQuestionBased ? "Soru Bazlı (${exam.questionCount} Soru)" : "Klasik (Tek Puan)"}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Katılan: ${exam.studentCount} Öğrenci',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue800),
          ),
        ],
      ),
    );
  }

  /// Öğrenci ve Soru Puanları Tablosu
  static pw.Widget _buildStudentScoreTable(
    ExamAnalysisModel exam,
    List<StudentExamScore> students,
  ) {
    final hasQuestions = exam.isQuestionBased && exam.questionCount > 0;

    // Sütun Başlıkları
    final List<String> headers = ['Sıra', 'No', 'Adı Soyadı'];
    if (hasQuestions) {
      for (int i = 0; i < exam.questionCount; i++) {
        final maxP = exam.questionMaxScores[i].toStringAsFixed(0);
        headers.add('S${i + 1}\n($maxP p)');
      }
    }
    headers.add('Toplam\n(100)');
    headers.add('Sonuç');

    // Sütun Genişlikleri
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FixedColumnWidth(24),
      1: const pw.FixedColumnWidth(34),
      2: const pw.FlexColumnWidth(3.0),
    };

    int currentIdx = 3;
    if (hasQuestions) {
      for (int i = 0; i < exam.questionCount; i++) {
        columnWidths[currentIdx++] = const pw.FixedColumnWidth(28);
      }
    }
    columnWidths[currentIdx++] = const pw.FixedColumnWidth(40);
    columnWidths[currentIdx] = const pw.FixedColumnWidth(36);

    // Satır Verileri
    final List<List<String>> data = [];
    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      final List<String> row = [
        (i + 1).toString(),
        s.studentNumber > 0 ? s.studentNumber.toString() : '-',
        s.studentName,
      ];

      if (hasQuestions) {
        for (int q = 0; q < exam.questionCount; q++) {
          if (q < s.questionScores.length) {
            row.add(s.questionScores[q].toStringAsFixed(0));
          } else {
            row.add('0');
          }
        }
      }

      row.add(s.totalScore.toStringAsFixed(0));
      row.add(s.totalScore >= 50.0 ? 'GEÇTİ' : 'KALDI');
      data.add(row);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {
        2: pw.Alignment.centerLeft, // Öğrenci adı sola hizalı
      },
      columnWidths: columnWidths,
    );
  }

  /// İstatistiksel Analiz ve Başarı Raporu Özeti
  static pw.Widget _buildAnalysisSummary(
    ExamAnalysisModel exam,
    Map<int, double> qRates,
    Map<int, double> qAvgs,
    Map<String, int> dist,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('GENEL SINAV İSTATİSTİKLERİ VE DEĞERLENDİRME', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sınıf Ortalaması: ${exam.classAverage.toStringAsFixed(1)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
              pw.Text('Başarı Oranı (>=50): %${exam.passRate.toStringAsFixed(1)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.green800)),
              pw.Text('En Yüksek: ${exam.highestScore.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('En Düşük: ${exam.lowestScore.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('Standart Sapma: ${exam.standardDeviation.toStringAsFixed(1)}', style: const pw.TextStyle(fontSize: 8.5)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),

          // Not Dağılımı ve Soru Başarıları
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Sol: Not Dağılımı
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Not Dağılımı:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.SizedBox(height: 2),
                    ...dist.entries.map((e) => pw.Text('• ${e.key}: ${e.value} Öğrenci', style: const pw.TextStyle(fontSize: 7.5))),
                  ],
                ),
              ),

              // Sağ: Soru Başarı Oranları (Varsa)
              if (exam.isQuestionBased && qRates.isNotEmpty)
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Soru Bazında Doğruluk / Başarı Yüzdesi:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.SizedBox(height: 2),
                      pw.Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: qRates.entries.map((e) {
                          final avgP = qAvgs[e.key]?.toStringAsFixed(1) ?? '0';
                          return pw.Text(
                            'S${e.key + 1}: %${e.value.toStringAsFixed(0)} ($avgP p)',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              color: e.value >= 70
                                  ? PdfColors.green800
                                  : e.value < 50
                                      ? PdfColors.red800
                                      : PdfColors.orange800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// PDF Alt İmza Alanı
  static pw.Widget _buildOfficialFooter({
    required TeacherProfileModel teacherProfile,
    required String pageNumber,
  }) {
    final teacherName = teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName : 'Ders Öğretmeni';
    final principalName = teacherProfile.schoolPrincipalName.isNotEmpty ? teacherProfile.schoolPrincipalName : 'Okul Müdürü';

    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey500, thickness: 0.5),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Öğretmen İmza
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(teacherName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('Ders Öğretmeni', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 18),
                pw.Text('İmza: ........................', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              ],
            ),
            pw.Text(pageNumber, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            // Okul Müdürü İmza
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(principalName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('Okul Müdürü', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 18),
                pw.Text('İmza / Mühür: ........................', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
