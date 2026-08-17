import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// SınıfCepte - Resmî MEB Dönem Sonu / Yıl Sonu ve Veli Toplantısı Kümülatif PDF Motoru
class ParticipationCumulativePdfGenerator {
  ParticipationCumulativePdfGenerator._();

  static String _cleanText(String text) {
    if (text.isEmpty) return '';
    final noEmoji = text.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27FF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F600}-\u{1F64F}\u{2300}-\u{23FF}\u{2B50}\u{2705}\u{274C}\u{2B06}\u{2194}\u{2714}\u{2716}\u{2757}]',
        unicode: true,
      ),
      '',
    );
    return noEmoji.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Öğrencinin başarı ve katılım istatistiğine göre pedagojik, gerçekçi geri bildirim üretir
  static String _generateSmartFeedback({
    required double hwRate,
    required double matRate,
    required double avgStars,
    required List<String> tags,
    required List<String> notes,
  }) {
    // 1. Öğretmenin özel notu varsa önceliklendir
    if (notes.isNotEmpty) {
      return _cleanText(notes.last);
    }
    // 2. Özel davranış etiketi varsa göster
    if (tags.isNotEmpty) {
      return tags.take(2).map(_cleanText).join(', ');
    }

    // 3. İstatistiğe göre gerçekçi pedagojik değerlendirme
    if (hwRate >= 90 && matRate >= 90 && avgStars >= 2.6) {
      return 'Ders içi katılımı ve ödev bilinci çok yüksek. Tebrik edilmeli.';
    } else if (hwRate >= 80 && avgStars >= 2.4) {
      return 'Dersi dikkatle dinliyor ve sorumluluklarını yerine getiriyor.';
    } else if (hwRate < 60 && matRate < 70) {
      return 'Ödev ve araç-gereç takibinde veli desteği artırılmalı.';
    } else if (hwRate < 60) {
      return 'Ödev teslimlerinde aksama var, ev takibi önerilir.';
    } else if (matRate < 70) {
      return 'Ders araç-gereçlerini düzenli getirmesi hatırlatılmalı.';
    } else if (avgStars < 2.0) {
      return 'Derse katılım ve odaklanma konusunda cesaretlendirilmeli.';
    } else {
      return 'İstikrarlı ve olumlu katılımı devam etmektedir.';
    }
  }

  /// 1. İdareye Teslim Edilecek Resmî Dönem / Yıl Sonu Katılım ve Ödev Çizelgesi (A4 PDF)
  static Future<Uint8List> generateOfficialAdministrativePdf({
    required Map<String, dynamic> reportData,
    required String teacherName,
    required String termName,
    String? schoolName,
    String? principalName,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final resolvedSchool = schoolName != null && schoolName.isNotEmpty
        ? _cleanText(schoolName)
        : '................................................... OKULU';

    final className = _cleanText(reportData['className'] as String? ?? 'Sınıf');
    final subjectName = _cleanText(reportData['subjectName'] as String? ?? 'Ders');
    final totalLessons = reportData['totalLessons'] as int? ?? 0;
    final studentCount = reportData['studentCount'] as int? ?? 0;
    final avgHwRate = (reportData['classAverageHwRate'] as num?)?.toDouble() ?? 100.0;
    final avgMatRate = (reportData['classAverageMatRate'] as num?)?.toDouble() ?? 100.0;
    final totalStars = reportData['classTotalStars'] as int? ?? 0;
    final students = (reportData['students'] as List<dynamic>? ?? []);

    final teacher = _cleanText(teacherName.isNotEmpty ? teacherName : 'Ders Öğretmeni');
    final principal = _cleanText(principalName != null && principalName.isNotEmpty ? principalName : 'Okul Müdürü');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        build: (pw.Context context) {
          return [
            // 1. Resmî MEB Başlık
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('T.C.', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  pw.Text('MİLLÎ EĞİTİM BAKANLIĞI', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  pw.Text(resolvedSchool.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 13)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'DÖNEM SONU DERS İÇİ KATILIM, ÖDEV VE GELİŞİM RESMÎ ÇİZELGESİ',
                    style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blue900),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    _cleanText(termName),
                    style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.grey800),
                  ),
                  pw.Divider(thickness: 1.2, color: PdfColors.grey700),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // 2. Oturum ve Sınıf KPI Kutusu
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Sınıf / Şube: $className', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text('Ders: $subjectName', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                    pw.SizedBox(height: 2),
                    pw.Text('Toplam İşlenen / Değerlendirilen Ders: $totalLessons Saat', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Öğrenci Mevcudu: $studentCount', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text('Sınıf Ödev Teslim Başarısı: %${avgHwRate.toStringAsFixed(1)}', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.green800)),
                      pw.SizedBox(height: 2),
                      pw.Text('Araç-Gereç / Kitap Uyumu: %${avgMatRate.toStringAsFixed(1)}', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('Toplam Katılım Yıldızı Puanı: $totalStars', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // 3. Resmî Öğrenci Çizelgesi Tablosu
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(22), // S.No
                1: pw.FixedColumnWidth(36), // Okul No
                2: pw.FlexColumnWidth(3.0), // Adı Soyadı
                3: pw.FixedColumnWidth(32), // Ders
                4: pw.FixedColumnWidth(56), // Ödev (Y/E/Y)
                5: pw.FixedColumnWidth(44), // Ödev %
                6: pw.FixedColumnWidth(44), // Materyal %
                7: pw.FixedColumnWidth(48), // Yıldız Ort.
                8: pw.FlexColumnWidth(3.0), // Öne Çıkan Davranışlar / Görüş
              },
              children: [
                // Başlık
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _buildHeaderCell('No', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Okul No', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Öğrenci Adı Soyadı', fontBold),
                    _buildHeaderCell('Ders', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Ödev (Y/E/Y)', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Ödev %', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Materyal %', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Katılım (Ort.)', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Öne Çıkan Davranış & Görüş', fontBold),
                  ],
                ),
                // Satırlar
                for (int i = 0; i < students.length; i++) ...[
                  () {
                    final s = students[i] as Map<String, dynamic>;
                    final isEven = i % 2 == 0;
                    final sNum = s['studentNumber']?.toString() ?? '-';
                    final sName = _cleanText(s['studentName']?.toString() ?? 'Öğrenci');
                    final sLessons = s['totalEvaluatedSessions']?.toString() ?? '0';
                    final hwDone = s['homeworkDone']?.toString() ?? '0';
                    final hwPart = s['homeworkPartial']?.toString() ?? '0';
                    final hwNone = s['homeworkNone']?.toString() ?? '0';
                    final hwRateNum = (s['homeworkRate'] as num?)?.toDouble() ?? 100.0;
                    final matRateNum = (s['materialsRate'] as num?)?.toDouble() ?? 100.0;
                    final avgStarsNum = (s['averageStars'] as num?)?.toDouble() ?? 3.0;

                    final tags = (s['tags'] as List<dynamic>?)?.map((t) => _cleanText(t.toString())).where((t) => t.isNotEmpty).toSet().toList() ?? [];
                    final notes = (s['notes'] as List<dynamic>?)?.map((n) => _cleanText(n.toString())).where((n) => n.isNotEmpty).toList() ?? [];

                    final feedbackStr = _generateSmartFeedback(
                      hwRate: hwRateNum,
                      matRate: matRateNum,
                      avgStars: avgStarsNum,
                      tags: tags,
                      notes: notes,
                    );

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.white : PdfColors.grey100,
                      ),
                      children: [
                        _buildCell('${i + 1}', fontRegular, align: pw.TextAlign.center),
                        _buildCell(sNum, fontBold, align: pw.TextAlign.center),
                        _buildCell(sName, fontBold),
                        _buildCell(sLessons, fontRegular, align: pw.TextAlign.center),
                        _buildCell('$hwDone / $hwPart / $hwNone', fontRegular, align: pw.TextAlign.center),
                        _buildCell('%${hwRateNum.toStringAsFixed(0)}', fontBold, align: pw.TextAlign.center),
                        _buildCell('%${matRateNum.toStringAsFixed(0)}', fontRegular, align: pw.TextAlign.center),
                        _buildCell('${avgStarsNum.toStringAsFixed(1)} / 3.0', fontBold, align: pw.TextAlign.center),
                        _buildCell(feedbackStr, fontRegular),
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
                    pw.Text(teacher, style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.Text('Ders Öğretmeni', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    pw.SizedBox(height: 22),
                    pw.Text('İmza: .........................', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(principal, style: pw.TextStyle(font: fontBold, fontSize: 10)),
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

  /// 2. Veli Toplantısı Sınıf Değerlendirme Kılavuzu (A4 PDF)
  static Future<Uint8List> generateParentMeetingGuidePdf({
    required Map<String, dynamic> reportData,
    required String teacherName,
    String? schoolName,
    String? meetingDateText,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final resolvedSchool = schoolName != null && schoolName.isNotEmpty
        ? _cleanText(schoolName)
        : '................................................... OKULU';

    final className = _cleanText(reportData['className'] as String? ?? 'Sınıf');
    final subjectName = _cleanText(reportData['subjectName'] as String? ?? 'Ders');
    final students = (reportData['students'] as List<dynamic>? ?? []);
    final teacher = _cleanText(teacherName.isNotEmpty ? teacherName : 'Ders Öğretmeni');
    final dateNote = meetingDateText != null && meetingDateText.isNotEmpty
        ? ' • $meetingDateText İtibarıyla'
        : '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(resolvedSchool.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'VELİ TOPLANTISI DERS İÇİ KATILIM, ÖDEV VE PERFORMANS KILAVUZU',
                    style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.indigo900),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text('$className Sınıfı • $subjectName Dersi$dateNote', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                  pw.Divider(thickness: 1.2, color: PdfColors.indigo700),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(22), // S.No
                1: pw.FixedColumnWidth(36), // Okul No
                2: pw.FlexColumnWidth(3.0), // Adı Soyadı
                3: pw.FixedColumnWidth(56), // Ödev Durumu
                4: pw.FixedColumnWidth(54), // Materyal
                5: pw.FixedColumnWidth(52), // Katılım
                6: pw.FlexColumnWidth(3.8), // Veliye İletilecek Özet Görüş & Not
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo800),
                  children: [
                    _buildHeaderCell('No', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Okul No', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Öğrenci Adı Soyadı', fontBold),
                    _buildHeaderCell('Ödev Başarısı', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Araç-Gereç', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Katılım (Ort.)', fontBold, align: pw.TextAlign.center),
                    _buildHeaderCell('Veliye İletilecek Özet Bilgi & Öneri', fontBold),
                  ],
                ),
                for (int i = 0; i < students.length; i++) ...[
                  () {
                    final s = students[i] as Map<String, dynamic>;
                    final isEven = i % 2 == 0;
                    final sNum = s['studentNumber']?.toString() ?? '-';
                    final sName = _cleanText(s['studentName']?.toString() ?? 'Öğrenci');
                    final hwRateNum = (s['homeworkRate'] as num?)?.toDouble() ?? 100.0;
                    final matRateNum = (s['materialsRate'] as num?)?.toDouble() ?? 100.0;
                    final avgStarsNum = (s['averageStars'] as num?)?.toDouble() ?? 3.0;

                    String hwSummary = '%${hwRateNum.toStringAsFixed(0)} Tam';
                    if (hwRateNum < 70) hwSummary = '%${hwRateNum.toStringAsFixed(0)} (Eksik)';

                    final tags = (s['tags'] as List<dynamic>?)?.map((t) => _cleanText(t.toString())).where((t) => t.isNotEmpty).toSet().toList() ?? [];
                    final notes = (s['notes'] as List<dynamic>?)?.map((n) => _cleanText(n.toString())).where((n) => n.isNotEmpty).toList() ?? [];

                    final tipStr = _generateSmartFeedback(
                      hwRate: hwRateNum,
                      matRate: matRateNum,
                      avgStars: avgStarsNum,
                      tags: tags,
                      notes: notes,
                    );

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.white : PdfColors.grey100,
                      ),
                      children: [
                        _buildCell('${i + 1}', fontRegular, align: pw.TextAlign.center),
                        _buildCell(sNum, fontBold, align: pw.TextAlign.center),
                        _buildCell(sName, fontBold),
                        _buildCell(hwSummary, fontBold, align: pw.TextAlign.center),
                        _buildCell('%${matRateNum.toStringAsFixed(0)}', fontRegular, align: pw.TextAlign.center),
                        _buildCell('${avgStarsNum.toStringAsFixed(1)} / 3.0', fontBold, align: pw.TextAlign.center),
                        _buildCell(tipStr, fontRegular),
                      ],
                    );
                  }(),
                ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(teacher, style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text('Ders Öğretmeni', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// 3. Bireysel Veli Gelişim Karnesi (Tek Sayfa A4 PDF)
  static Future<Uint8List> generateIndividualStudentCardPdf({
    required Map<String, dynamic> studentData,
    required String className,
    required String subjectName,
    required String teacherName,
    String? schoolName,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final resolvedSchool = schoolName != null && schoolName.isNotEmpty
        ? _cleanText(schoolName)
        : '................................................... OKULU';

    final sName = _cleanText(studentData['studentName']?.toString() ?? 'Öğrenci');
    final sNum = studentData['studentNumber']?.toString() ?? '-';
    final totalSessions = studentData['totalEvaluatedSessions']?.toString() ?? '0';
    final hwRate = (studentData['homeworkRate'] as num?)?.toDouble() ?? 100.0;
    final matRate = (studentData['materialsRate'] as num?)?.toDouble() ?? 100.0;
    final totalStars = studentData['totalStars']?.toString() ?? '0';
    final avgStarsNum = (studentData['averageStars'] as num?)?.toDouble() ?? 3.0;
    final avgStars = avgStarsNum.toStringAsFixed(1);
    final tags = (studentData['tags'] as List<dynamic>?)?.map((t) => _cleanText(t.toString())).where((t) => t.isNotEmpty).toSet().toList() ?? [];
    final notes = (studentData['notes'] as List<dynamic>?)?.map((n) => _cleanText(n.toString())).where((n) => n.isNotEmpty).toList() ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Başlık
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(resolvedSchool.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 13)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'BİREYSEL ÖĞRENCİ GELİŞİM VE DERS İÇİ KATILIM ÖZETİ',
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue900),
                    ),
                    pw.Divider(thickness: 1.2, color: PdfColors.blue700),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Öğrenci Profil Kartı
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Öğrenci: $sName', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                        pw.SizedBox(height: 2),
                        pw.Text('Okul No: $sNum • Sınıf: $className', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Ders: $subjectName', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue800)),
                        pw.SizedBox(height: 2),
                        pw.Text('Değerlendirilen Ders: $totalSessions Saat', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // KPI İlerleme Çubukları
              pw.Text('Ders İçi Katılım & Sorumluluk Göstergeleri', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),

              _buildProgressBar(title: 'Ödev Teslim Başarısı', percentage: hwRate, fontBold: fontBold, fontRegular: fontRegular, color: PdfColors.green700),
              pw.SizedBox(height: 8),
              _buildProgressBar(title: 'Araç-Gereç / Kitap Hazırlığı', percentage: matRate, fontBold: fontBold, fontRegular: fontRegular, color: PdfColors.blue700),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.amber300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Derse Katılım Ortalaması: $avgStars / 3.0 Puan', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.amber900)),
                    pw.Text('Toplam Yıldız Puanı: $totalStars', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.amber900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // Davranış Rozetleri
              if (tags.isNotEmpty) ...[
                pw.Text('Öne Çıkan Davranış ve Nitelikler', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blueGrey800)),
                pw.SizedBox(height: 6),
                pw.Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((t) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border: pw.Border.all(color: PdfColors.blue300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(t, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue900)),
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 16),
              ],

              // Öğretmen Gözlem ve Notları
              pw.Text('Öğretmen Gözlem Notları ve Değerlendirmeleri', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: notes.isNotEmpty
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: notes.map((n) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Text('• $n', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                          );
                        }).toList(),
                      )
                    : pw.Text(
                        _generateSmartFeedback(
                          hwRate: hwRate,
                          matRate: matRate,
                          avgStars: avgStarsNum,
                          tags: tags,
                          notes: [],
                        ),
                        style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: PdfColors.grey800),
                      ),
              ),
              pw.Spacer(),

              // İmza
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Veli Görüşü / İmza', style: pw.TextStyle(font: fontBold, fontSize: 9.5)),
                      pw.SizedBox(height: 20),
                      pw.Text('İmza: .........................', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(_cleanText(teacherName), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.Text('Ders Öğretmeni', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      pw.SizedBox(height: 20),
                      pw.Text('İmza: .........................', style: pw.TextStyle(font: fontRegular, fontSize: 8.5)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildProgressBar({
    required String title,
    required double percentage,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required PdfColor color,
  }) {
    final clamped = percentage.clamp(0.0, 100.0);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 9.5)),
            pw.Text('%${clamped.toStringAsFixed(0)}', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: color)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Container(
          height: 7,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              height: 7,
              width: (clamped / 100) * 500,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
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
