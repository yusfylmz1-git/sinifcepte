import 'dart:io';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/models/class_model.dart';
import 'classroom_documents_pdf_generator.dart';
import '../../../core/pdf/pdf_tr_fonts.dart';

/// MEB Standartlarında Resmî Sınıf Veli İletişim ve Acil Durum Çizelgesi PDF Motoru
class ParentContactsPdfGenerator {
  ParentContactsPdfGenerator._();

  /// Telefon Numarasını Standart Türkiye Formatına (0 5XX XXX XX XX) Çevirici
  static String formatPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '-';
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 11 && cleaned.startsWith('0')) {
      return '0 (${cleaned.substring(1, 4)}) ${cleaned.substring(4, 7)} ${cleaned.substring(7, 9)} ${cleaned.substring(9, 11)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('5')) {
      return '0 (${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)} ${cleaned.substring(6, 8)} ${cleaned.substring(8, 10)}';
    } else if (cleaned.length == 12 && cleaned.startsWith('90')) {
      return '0 (${cleaned.substring(2, 5)}) ${cleaned.substring(5, 8)} ${cleaned.substring(8, 10)} ${cleaned.substring(10, 12)}';
    }
    if (phone.length > 20) {
      return '${phone.substring(0, 17)}...';
    }
    return phone;
  }

  static Future<void> generateAndShare({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
  }) async {
    try {
      final pdf = await PdfTrFonts.document();


      // Öğrencileri okul numarasına göre sırala
      final sortedStudents = List<StudentModel>.from(students)
        ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

      final totalCount = sortedStudents.length;
      final withPhoneCount = sortedStudents.where((s) => s.parentPhone != null && s.parentPhone!.trim().isNotEmpty).length;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (pw.Context ctx) => _buildHeader(classModel),
          footer: (pw.Context ctx) => _buildFooter(ctx, totalCount, withPhoneCount),
          build: (pw.Context ctx) {
            return [
              pw.SizedBox(height: 12),
              _buildContactsTable(sortedStudents),
            ];
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Veli_Iletisim_Listesi_${classModel.name}.pdf');
      await file.writeAsBytes(await PdfTrFonts.kaydet(pdf));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${classModel.name} Sınıfı Veli İletişim ve Acil Durum Çizelgesi',
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ParentContactsPdfGenerator) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('--------------------------------------------------------------------------');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veli listesi PDF evrakı oluşturulurken hata meydana geldi.')),
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
          ClassroomDocumentsPdfGenerator.ogretimYili(classModel),
          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Center(
            child: pw.Text(
              '${classModel.name} SINIFI VELİ İLETİŞİM VE ACİL DURUM ÇİZELGESİ',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildContactsTable(List<StudentModel> students) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(24), // S.No
        1: pw.FixedColumnWidth(36), // Okul No
        2: pw.FlexColumnWidth(3.0), // Öğrenci Adı Soyadı
        3: pw.FixedColumnWidth(32), // Cinsiyet
        4: pw.FlexColumnWidth(2.5), // Veli Adı / Yakınlığı
        5: pw.FlexColumnWidth(2.7), // Veli Telefonu
        6: pw.FlexColumnWidth(3.0), // Acil Durum / Not
      },
      children: [
        // Başlık Satırı
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableHeaderCell('S.No'),
            _buildTableHeaderCell('No'),
            _buildTableHeaderCell('Öğrenci Adı Soyadı', align: pw.TextAlign.left),
            _buildTableHeaderCell('Cins.'),
            _buildTableHeaderCell('Veli Adı / Yakınlığı', align: pw.TextAlign.left),
            _buildTableHeaderCell('Veli Telefonu', align: pw.TextAlign.left),
            _buildTableHeaderCell('Acil Durum / Özel Not', align: pw.TextAlign.left),
          ],
        ),
        // Öğrenci Satırları
        ...List.generate(students.length, (index) {
          final s = students[index];
          final isEven = index % 2 == 0;
          final rowBg = isEven ? PdfColors.white : PdfColors.grey100;
          final hasPhone = s.parentPhone?.trim().isNotEmpty == true;
          final phoneText = formatPhoneNumber(s.parentPhone);

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              _buildTableCell('${index + 1}', align: pw.TextAlign.center),
              _buildTableCell('${s.schoolNumber}', align: pw.TextAlign.center, isBold: true),
              _buildTableCell(s.fullName, align: pw.TextAlign.left, isBold: true),
              _buildTableCell(s.gender.isNotEmpty ? s.gender[0] : '-', align: pw.TextAlign.center),
              _buildTableCell(
                s.parentName?.trim().isNotEmpty == true ? s.parentName! : '-',
                align: pw.TextAlign.left,
              ),
              _buildTableCell(
                phoneText,
                align: pw.TextAlign.left,
                color: hasPhone ? PdfColors.blue900 : PdfColors.grey600,
              ),
              _buildTableCell(
                s.notes?.trim().isNotEmpty == true ? s.notes! : '-',
                align: pw.TextAlign.left,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx, int total, int withPhone) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Toplam Öğrenci: $total  •  Telefonu Kayıtlı Veli: $withPhone  •  Eksik: ${total - withPhone}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
                pw.Text(
                  'Tarih: ...... / ...... / 202...   •   Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Sınıf Rehber Öğretmeni', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.SizedBox(height: 20),
                pw.Text('İmza: ........................................', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
