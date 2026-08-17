import 'dart:io';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/models/class_model.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';

/// Resmî Sınıf Evrakları ve Çizelgeler PDF Motoru
class ClassroomDocumentsPdfGenerator {
  ClassroomDocumentsPdfGenerator._();

  /// 1. Resmî Sınıf Öğrenci Listesi Formu
  static Future<void> generateStudentListPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await _generateAndShare(
      context: context,
      fileName: 'Sinif_Listesi_${classModel.name}.pdf',
      shareText: '${classModel.name} Sınıf Öğrenci Listesi',
      builder: (fontRegular, fontBold) {
        final pdf = pw.Document();
        final sortedStudents = List<StudentModel>.from(students)
          ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
            header: (pw.Context ctx) => _buildOfficialHeader(
              schoolName: teacherProfile.schoolName,
              title: '${classModel.name} SINIFI ÖĞRENCİ LİSTESİ',
              academicYear: '2024-2025 EĞİTİM-ÖĞRETİM YILI',
            ),
            footer: (pw.Context ctx) => _buildOfficialFooter(
              teacherName: teacherProfile.fullName,
              principalName: teacherProfile.schoolPrincipalName,
              pageNumber: '${ctx.pageNumber} / ${ctx.pagesCount}',
            ),
            build: (pw.Context ctx) => [
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(30), // Sıra No
                  1: const pw.FixedColumnWidth(55), // Okul No
                  2: const pw.FlexColumnWidth(3), // Adı Soyadı
                  3: const pw.FixedColumnWidth(50), // Cinsiyet
                  4: const pw.FlexColumnWidth(2), // Açıklama / İmza
                },
                headers: ['Sıra', 'Okul No', 'Adı Soyadı', 'Cinsiyet', 'Açıklama / İmza'],
                data: List.generate(sortedStudents.length, (index) {
                  final s = sortedStudents[index];
                  return [
                    '${index + 1}',
                    s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                    s.fullName,
                    s.gender,
                    '',
                  ];
                }),
              ),
              pw.SizedBox(height: 12),
              _buildClassSummaryStats(sortedStudents),
            ],
          ),
        );
        return pdf;
      },
    );
  }

  /// 2. Ders İçi Not & Değerlendirme Çizelgesi Formu (A4 Yatay / Landscape)
  static Future<void> generateEvaluationSheetPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await _generateAndShare(
      context: context,
      fileName: 'Degerlendirme_Cizelgesi_${classModel.name}.pdf',
      shareText: '${classModel.name} Ders İçi Değerlendirme Çizelgesi',
      builder: (fontRegular, fontBold) {
        final pdf = pw.Document();
        final sortedStudents = List<StudentModel>.from(students)
          ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(28),
            theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
            header: (pw.Context ctx) => _buildOfficialHeader(
              schoolName: teacherProfile.schoolName,
              title: '${classModel.name} SINIFI ${classModel.subject.toUpperCase()} DERS İÇİ DEĞERLENDİRME ÇİZELGESİ',
              academicYear: '2024-2025 EĞİTİM-ÖĞRETİM YILI',
            ),
            footer: (pw.Context ctx) => _buildOfficialFooter(
              teacherName: teacherProfile.fullName,
              principalName: teacherProfile.schoolPrincipalName,
              pageNumber: '${ctx.pageNumber} / ${ctx.pagesCount}',
            ),
            build: (pw.Context ctx) => [
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FixedColumnWidth(28), // Sıra
                  1: const pw.FixedColumnWidth(48), // No
                  2: const pw.FixedColumnWidth(130), // Ad Soyad
                  3: const pw.FixedColumnWidth(35), // 1
                  4: const pw.FixedColumnWidth(35), // 2
                  5: const pw.FixedColumnWidth(35), // 3
                  6: const pw.FixedColumnWidth(35), // 4
                  7: const pw.FixedColumnWidth(35), // 5
                  8: const pw.FixedColumnWidth(35), // 6
                  9: const pw.FixedColumnWidth(35), // 7
                  10: const pw.FixedColumnWidth(35), // 8
                  11: const pw.FixedColumnWidth(35), // 9
                  12: const pw.FixedColumnWidth(35), // 10
                  13: const pw.FlexColumnWidth(1), // Ortalama / Not
                },
                headers: [
                  'Sıra',
                  'No',
                  'Adı Soyadı',
                  '1. Etk.',
                  '2. Etk.',
                  '3. Etk.',
                  '4. Etk.',
                  '5. Etk.',
                  'Ödev 1',
                  'Ödev 2',
                  'Proje',
                  'Sözlü',
                  'Ders İçi',
                  'Sonuç / Not',
                ],
                data: List.generate(sortedStudents.length, (index) {
                  final s = sortedStudents[index];
                  return [
                    '${index + 1}',
                    s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                    s.fullName,
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                  ];
                }),
              ),
            ],
          ),
        );
        return pdf;
      },
    );
  }

  /// 3. Haftalık Sınıf Nöbet Çizelgesi Formu
  static Future<void> generateDutySchedulePdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await _generateAndShare(
      context: context,
      fileName: 'Nobet_Cizelgesi_${classModel.name}.pdf',
      shareText: '${classModel.name} Haftalık Sınıf Nöbet Çizelgesi',
      builder: (fontRegular, fontBold) {
        final pdf = pw.Document();
        final days = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA'];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildOfficialHeader(
                    schoolName: teacherProfile.schoolName,
                    title: '${classModel.name} SINIFI HAFTALIK NÖBETÇİ ÖĞRENCİ ÇİZELGESİ',
                    academicYear: '2024-2025 EĞİTİM-ÖĞRETİM YILI',
                  ),
                  pw.SizedBox(height: 16),
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                    headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(90), // Gün
                      1: const pw.FlexColumnWidth(2), // 1. Nöbetçi Öğrenci
                      2: const pw.FlexColumnWidth(2), // 2. Nöbetçi Öğrenci
                      3: const pw.FlexColumnWidth(2), // Görev / Nöbet Yeri
                      4: const pw.FixedColumnWidth(60), // İmza
                    },
                    headers: ['Gün', '1. Nöbetçi Öğrenci', '2. Nöbetçi Öğrenci', 'Nöbet Görevi / Yeri', 'İmza'],
                    data: days.map((day) {
                      return [
                        day,
                        '',
                        '',
                        'Sınıf Düzeni & Havalandırma',
                        '',
                      ];
                    }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NÖBETÇİ ÖĞRENCİNİN GÖREV VE SORUMLULUKLARI:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.SizedBox(height: 4),
                        pw.Text('1. Teneffüslerde sınıfın pencerelerini açarak sınıfı havalandırmak.', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('2. Yazı tahtasının temizliğini sağlamak ve tebeşir/kalem düzenini korumak.', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('3. Sınıfta meydana gelen olağan dışı durumları ders öğretmenine veya nöbetçi öğretmene bildirmek.', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('4. Gün sonunda sınıfın genel düzenini kontrol etmek.', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  _buildOfficialFooter(
                    teacherName: teacherProfile.fullName,
                    principalName: teacherProfile.schoolPrincipalName,
                    pageNumber: '1 / 1',
                  ),
                ],
              );
            },
          ),
        );
        return pdf;
      },
    );
  }

  /// 4. Sosyal Kulüp Öğrenci Dağılım Çizelgesi Formu
  static Future<void> generateClubDistributionPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await _generateAndShare(
      context: context,
      fileName: 'Sosyal_Kulup_Listesi_${classModel.name}.pdf',
      shareText: '${classModel.name} Sosyal Kulüp Öğrenci Dağılım Çizelgesi',
      builder: (fontRegular, fontBold) {
        final pdf = pw.Document();
        final sortedStudents = List<StudentModel>.from(students)
          ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
            header: (pw.Context ctx) => _buildOfficialHeader(
              schoolName: teacherProfile.schoolName,
              title: '${classModel.name} SINIFI SOSYAL KULÜP DAĞILIM ÇİZELGESİ',
              academicYear: '2024-2025 EĞİTİM-ÖĞRETİM YILI',
            ),
            footer: (pw.Context ctx) => _buildOfficialFooter(
              teacherName: teacherProfile.fullName,
              principalName: teacherProfile.schoolPrincipalName,
              pageNumber: '${ctx.pageNumber} / ${ctx.pagesCount}',
            ),
            build: (pw.Context ctx) => [
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30), // Sıra
                  1: const pw.FixedColumnWidth(55), // No
                  2: const pw.FlexColumnWidth(3), // Ad Soyad
                  3: const pw.FlexColumnWidth(3), // Seçilen Sosyal Kulüp
                  4: const pw.FlexColumnWidth(2), // Görevi (Başkan / Üye)
                },
                headers: ['Sıra', 'Okul No', 'Adı Soyadı', 'Seçtiği Sosyal Kulüp', 'Görevi'],
                data: List.generate(sortedStudents.length, (index) {
                  final s = sortedStudents[index];
                  return [
                    '${index + 1}',
                    s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                    s.fullName,
                    '',
                    'Üye',
                  ];
                }),
              ),
            ],
          ),
        );
        return pdf;
      },
    );
  }

  /// 5. Acil Durum & Veli İletişim Listesi (KVKK Uyumlu)
  static Future<void> generateEmergencyContactListPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await _generateAndShare(
      context: context,
      fileName: 'Acil_Durum_Iletisim_${classModel.name}.pdf',
      shareText: '${classModel.name} Acil Durum ve Veli İletişim Listesi',
      builder: (fontRegular, fontBold) {
        final pdf = pw.Document();
        final sortedStudents = List<StudentModel>.from(students)
          ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
            header: (pw.Context ctx) => _buildOfficialHeader(
              schoolName: teacherProfile.schoolName,
              title: '${classModel.name} SINIFI ACİL DURUM VE VELİ İLETİŞİM BİLGİ LİSTESİ',
              academicYear: '2024-2025 EĞİTİM-ÖĞRETİM YILI',
            ),
            footer: (pw.Context ctx) => _buildOfficialFooter(
              teacherName: teacherProfile.fullName,
              principalName: teacherProfile.schoolPrincipalName,
              pageNumber: '${ctx.pageNumber} / ${ctx.pagesCount}',
            ),
            build: (pw.Context ctx) => [
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                child: pw.Text(
                  'GİZLİ & HASSAS BELGE: Bu liste yalnızca acil durumlarda sınıf rehber öğretmeni tarafından kullanılmak üzere düzenlenmiştir. 3. şahıslarla paylaşılamaz.',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28), // Sıra
                  1: const pw.FixedColumnWidth(50), // No
                  2: const pw.FlexColumnWidth(3), // Ad Soyad
                  3: const pw.FlexColumnWidth(2.5), // Veli Telefon
                  4: const pw.FlexColumnWidth(2.5), // Özel Durum / Not
                },
                headers: ['Sıra', 'Okul No', 'Adı Soyadı', 'Veli Telefonu', 'Özel Durum / Sağlık'],
                data: List.generate(sortedStudents.length, (index) {
                  final s = sortedStudents[index];
                  return [
                    '${index + 1}',
                    s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                    s.fullName,
                    s.parentPhone?.isNotEmpty == true ? s.parentPhone! : '-',
                    s.notes?.isNotEmpty == true ? s.notes! : '-',
                  ];
                }),
              ),
            ],
          ),
        );
        return pdf;
      },
    );
  }

  // --- ORTAK BAŞLIK, ALT BİLGİ VE YARDIMCILAR ---

  static pw.Widget _buildOfficialHeader({
    required String schoolName,
    required String title,
    required String academicYear,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'T.C.',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'MİLLÎ EĞİTİM BAKANLIĞI',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          schoolName.toUpperCase(),
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          academicYear,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildOfficialFooter({
    required String teacherName,
    required String principalName,
    required String pageNumber,
  }) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(teacherName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 20),
                pw.Text('İmza: ........................', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
            pw.Text(pageNumber, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(principalName.isNotEmpty ? principalName : 'Okul Müdürü', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Okul Müdürü', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 20),
                pw.Text('İmza / Mühür: ........................', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildClassSummaryStats(List<StudentModel> students) {
    final girls = students.where((s) => s.gender.toLowerCase().contains('kız')).length;
    final boys = students.where((s) => s.gender.toLowerCase().contains('erkek')).length;
    final total = students.length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text('Kız Öğrenci: $girls', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text('Erkek Öğrenci: $boys', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text('Toplam Öğrenci: $total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue800)),
        ],
      ),
    );
  }

  static Future<void> _generateAndShare({
    required BuildContext context,
    required String fileName,
    required String shareText,
    required pw.Document Function(pw.Font fontRegular, pw.Font fontBold) builder,
  }) async {
    try {
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final pdf = builder(fontRegular, fontBold);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: shareText,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Evrak PDF oluşturma hatası: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evrak hazırlanırken bir hata oluştu: $e'),
          ),
        );
      }
    }
  }
}
