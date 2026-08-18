import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../models/parent_token_model.dart';

/// Veli baglanti kodunun paylasimi ve PDF ciktisi.
///
/// ## Neden ayri dosyada
/// Bu islevler pdf, printing ve share_plus paketlerine baglidir; ucu de
/// native platform kanali acar. Ayni dosyada durduklarinda veli baglanti
/// karti ACILIRKEN yukleniyorlar ve ekranin donmasina yol aciyorlardi --
/// oysa yalnizca kullanici paylas/yazdir dediginde gerekiyorlar.
///
/// Ayri dosyada tutulmalari, kartin bu paketlere hic dokunmadan
/// acilmasini saglar.
class TokenShareService {
  TokenShareService._();

  static void shareViaWhatsApp({
    required ParentTokenModel token,
    required StudentModel student,
    required ClassModel classModel,
    required TeacherProfileModel teacher,
  }) {
    final schoolTitle = teacher.fullSchoolTitle.isNotEmpty ? teacher.fullSchoolTitle : teacher.schoolName;
    final expFormatted = DateFormat('dd.MM.yyyy').format(token.expiresAt);

    final message = '''
🏫 *SınıfCepte Veli Bilgilendirme Sistemi*
📍 *${schoolTitle.isNotEmpty ? schoolTitle : 'Okulumuz'}*

Sayın Velimiz,
Öğrencimiz *${student.fullName}* (${classModel.name} / No: ${student.schoolNumber}) için hazırlanan sınıf duyuruları, ders öğretmenleri ve bilgilendirmeleri takip edebilmeniz için bağlantı kodunuz:

🔑 *Giriş Kodu:* `${token.code}`
🔒 *Güvenlik Doğrulaması:* Öğrenci Okul No (*${student.schoolNumber}*)
⏳ *Son Geçerlilik:* $expFormatted (7 Gün)

📲 *Nasıl Giriş Yapılır?*
1. SınıfCepte uygulamasını açın ve "Veli Girişi"ni seçin.
2. Yukarıdaki 8 haneli kodu girin veya QR kodu taratın.
3. Öğrencinin okul numarasını onaylayarak sınıfa bağlanın.
''';

    SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: '${student.fullName} - Veli Giriş Kodu',
      ),
    );
  }

  static Future<void> printOrSavePdf({
    required ParentTokenModel token,
    required StudentModel student,
    required ClassModel classModel,
    required TeacherProfileModel teacher,
  }) async {
    final doc = pw.Document();
    final schoolTitle = teacher.fullSchoolTitle.isNotEmpty ? teacher.fullSchoolTitle : teacher.schoolName;
    final expFormatted = DateFormat('dd.MM.yyyy').format(token.expiresAt);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('SINIFCEPTE VELİ BİLGİLENDİRME KARTI', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                pw.SizedBox(height: 4),
                pw.Text(schoolTitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 10),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Öğrenci: ${student.fullName}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Sınıf: ${classModel.name}  |  Okul No: ${student.schoolNumber}', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text('Öğretmen: ${teacher.fullName}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(8)),
                      child: pw.Text(token.code, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: token.code,
                  width: 110,
                  height: 110,
                ),
                pw.SizedBox(height: 10),

                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(color: PdfColors.amber50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(
                    'Giriş esnasında güvenlik amacıyla öğrencinin okul numarası (${student.schoolNumber}) sorulacaktır. Bu kod $expFormatted tarihine kadar geçerlidir.',
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.brown800),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
