import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models/classroom_participation_model.dart';

/// SınıfCepte - Resmî MEB Ders İçi Katılım & Gelişim PDF Rapor Motoru
class ParticipationPdfGenerator {
  ParticipationPdfGenerator._();

  /// Emojileri ve PDF fontunun desteklemediği yabancı sembolleri temizler
  static String _cleanPdfText(String text) {
    if (text.isEmpty) return '';
    // Tüm emoji ve özel sembol bloklarını temizle
    final noEmoji = text.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27FF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F600}-\u{1F64F}\u{2300}-\u{23FF}\u{2B50}\u{2705}\u{274C}]',
        unicode: true,
      ),
      '',
    );
    // Fazla boşlukları temizle
    return noEmoji.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Sınıfın günlük ders içi katılım ve ödev değerlendirme tutanağını üretir
  static Future<Uint8List> generateClassDailyReportPdf({
    required ClassroomParticipationSession session,
    required String teacherName,
    String? schoolName,
    String? principalName,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final resolvedSchoolName = schoolName != null && schoolName.isNotEmpty
        ? _cleanPdfText(schoolName)
        : '................................................... OKULU';

    final cleanedTeacherName = _cleanPdfText(teacherName.isNotEmpty ? teacherName : 'Ders Öğretmeni');
    final cleanedPrincipalName = _cleanPdfText(principalName != null && principalName.isNotEmpty ? principalName : 'Okul Müdürü');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return [
            // 1. MEB Resmî Başlık
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'T.C.',
                    style: pw.TextStyle(font: fontBold, fontSize: 11),
                  ),
                  pw.Text(
                    'MİLLÎ EĞİTİM BAKANLIĞI',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Text(
                    resolvedSchoolName.toUpperCase(),
                    style: pw.TextStyle(font: fontBold, fontSize: 13),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'DERS İÇİ KATILIM, ÖDEV VE PERFORMANS DEĞERLENDİRME ÇİZELGESİ',
                    style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blue900),
                  ),
                  pw.Divider(thickness: 1.2, color: PdfColors.grey700),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // 2. Oturum Bilgileri & KPI Kutusu
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Sınıf: ${_cleanPdfText(session.className)}', style: pw.TextStyle(font: fontBold, fontSize: 10.5)),
                    pw.SizedBox(height: 2),
                    pw.Text('Ders: ${_cleanPdfText(session.subjectName)} (${session.lessonHour}. Saat)', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                    pw.SizedBox(height: 2),
                    pw.Text('Tarih: ${session.date}', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                    if (session.topicName != null && session.topicName!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('İşlenen Konu: ${_cleanPdfText(session.topicName!)}', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                    ],
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Öğrenci Sayısı: ${session.totalStudents}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text('Ödev Teslim Oranı: %${session.homeworkCompletionRate.toStringAsFixed(0)}', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.green800)),
                      pw.SizedBox(height: 2),
                      pw.Text('Araç-Gereç Uyumu: %${session.materialsReadinessRate.toStringAsFixed(0)}', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('Toplam Katılım Yıldızı: ${session.totalStarsAwarded}', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // 3. Öğrenci Değerlendirme Tablosu
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(22), // S.No
                1: pw.FixedColumnWidth(36), // Okul No
                2: pw.FlexColumnWidth(3.2), // Ad Soyad
                3: pw.FixedColumnWidth(48), // Ödev
                4: pw.FixedColumnWidth(48), // Materyal
                5: pw.FixedColumnWidth(54), // Geliş
                6: pw.FixedColumnWidth(66), // Katılım
                7: pw.FlexColumnWidth(2.4), // Gözlem / Not
              },
              children: [
                // Başlık Satırı
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _buildHeaderCell('No', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Okul No', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Öğrenci Adı Soyadı', fontBold),
                    _buildHeaderCell('Ödev', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Materyal', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Geliş', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Derse Katılım', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Gözlem / Özel Not', fontBold),
                  ],
                ),
                // Öğrenci Satırları
                for (int i = 0; i < session.evaluations.length; i++) ...[
                  () {
                    final e = session.evaluations[i];
                    final isEven = i % 2 == 0;

                    // Ödev metni (Temiz Türkçe - Kırık kutu karakteri yok)
                    String hwLabel;
                    switch (e.homeworkStatus) {
                      case HomeworkStatus.done:
                        hwLabel = 'Yaptı';
                        break;
                      case HomeworkStatus.partial:
                        hwLabel = 'Eksik';
                        break;
                      case HomeworkStatus.none:
                        hwLabel = 'Yapmadı';
                        break;
                      case HomeworkStatus.notGiven:
                        hwLabel = '-';
                        break;
                    }

                    // Materyal metni
                    String matLabel = e.materialsStatus == MaterialsStatus.ready ? 'Getirdi' : 'Eksik';

                    // Zamanlama metni
                    String arrLabel = e.arrivalStatus == ArrivalStatus.onTime ? 'Zamanında' : 'Geç';

                    // Katılım metni
                    String starText;
                    if (e.starsCount == 3) {
                      starText = '3 Yıldız (Çok İyi)';
                    } else if (e.starsCount == 2) {
                      starText = '2 Yıldız (İyi)';
                    } else if (e.starsCount == 1) {
                      starText = '1 Yıldız';
                    } else {
                      starText = '-';
                    }

                    // Not / Etiket metni (Emojilerden %100 arındırılmış temiz Türkçe metin)
                    final noteParts = <String>[];
                    if (e.customTags.isNotEmpty) {
                      final cleanedTags = e.customTags
                          .map(_cleanPdfText)
                          .where((t) => t.isNotEmpty)
                          .toList();
                      if (cleanedTags.isNotEmpty) {
                        noteParts.add(cleanedTags.join(', '));
                      }
                    }
                    if (e.note != null && e.note!.trim().isNotEmpty) {
                      final cleanedNote = _cleanPdfText(e.note!.trim());
                      if (cleanedNote.isNotEmpty) {
                        noteParts.add(cleanedNote);
                      }
                    }
                    final finalNote = noteParts.isNotEmpty ? noteParts.join(' • ') : '-';

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.white : PdfColors.grey100,
                      ),
                      children: [
                        _buildCell('${i + 1}', fontRegular, align: pw.TextAlign.center),
                        _buildCell('${e.studentNumber}', fontBold, align: pw.TextAlign.center),
                        _buildCell(_cleanPdfText(e.studentName), fontBold),
                        _buildCell(hwLabel, fontRegular, align: pw.TextAlign.center),
                        _buildCell(matLabel, fontRegular, align: pw.TextAlign.center),
                        _buildCell(arrLabel, fontRegular, align: pw.TextAlign.center),
                        _buildCell(starText, fontRegular, align: pw.TextAlign.center),
                        _buildCell(finalNote, fontRegular),
                      ],
                    );
                  }(),
                ],
              ],
            ),
            pw.SizedBox(height: 24),

            // 4. Resmî İmza Blokları
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Text(cleanedTeacherName, style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.Text('Ders Öğretmeni', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    pw.SizedBox(height: 22),
                    pw.Text('İmza: .........................', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(cleanedPrincipalName, style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.Text('Okul Müdürü / Mühür', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    pw.SizedBox(height: 22),
                    pw.Text('İmza - Mühür: .........................', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Doğrudan yazdırma veya PDF paylaşım iletişim kutusunu açar
  static Future<void> shareOrPrintClassPdf({
    required ClassroomParticipationSession session,
    required String teacherName,
    String? schoolName,
    String? principalName,
  }) async {
    final pdfBytes = await generateClassDailyReportPdf(
      session: session,
      teacherName: teacherName,
      schoolName: schoolName,
      principalName: principalName,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${session.className}_Katilim_Raporu_${session.date}.pdf',
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.0,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.0,
          color: PdfColors.black,
        ),
      ),
    );
  }
}
