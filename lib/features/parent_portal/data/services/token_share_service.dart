import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../models/parent_token_model.dart';
import '../../../../core/pdf/pdf_tr_fonts.dart';

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
2. Yukarıdaki referans kodunu girin.
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
    final doc = await PdfTrFonts.document();
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

    await Printing.layoutPdf(onLayout: (format) async => PdfTrFonts.kaydet(doc));
  }

  /// 📲 Tüm Sınıf Veli Kodlarını WhatsApp'ta Toplu Paylaşım (KVKK & Okul Numarasız Güvenli Format)
  static void shareClassTokensViaWhatsApp({
    required ClassModel classModel,
    required TeacherProfileModel teacher,
    required List<StudentModel> students,
    required Map<int, ParentTokenModel> tokens,
  }) {
    if (students.isEmpty) return;

    final schoolTitle = teacher.fullSchoolTitle.isNotEmpty ? teacher.fullSchoolTitle : teacher.schoolName;
    final buffer = StringBuffer();
    buffer.writeln('🏫 *SınıfCepte Veli Bilgilendirme Sistemi*');
    if (schoolTitle.isNotEmpty) {
      buffer.writeln('📍 *$schoolTitle*');
    }
    buffer.writeln('📋 *${classModel.name} Sınıfı Veli Giriş Kodları Listesi*');
    buffer.writeln('');
    buffer.writeln('Sayın Velilerimiz,');
    buffer.writeln('Öğrencimizin sınıf duyurularını, ders programını ve öğretmen bilgilendirmelerini takip edebilmeniz için bağlantı kodlarınız aşağıda yer almaktadır:');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');

    for (final student in students) {
      final token = student.id != null ? tokens[student.id] : null;
      if (token != null && token.isValid) {
        final maskedName = _maskLastName(student.fullName);
        buffer.writeln('• *$maskedName* ➔ `${token.code}`');
      } else {
        final maskedName = _maskLastName(student.fullName);
        buffer.writeln('• $maskedName ➔ _(Kod henüz üretilmedi)_');
      }
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📲 *Nasıl Giriş Yapılır?*');
    buffer.writeln('1. SınıfCepte uygulamasını açın ve *"Veli Girişi"* butonuna dokunun.');
    buffer.writeln('2. Yukarıdaki listede öğrencinizin karşısındaki referans kodunu girin.');
    buffer.writeln('3. Güvenlik doğrulaması için *kendi öğrencinizin okul numarasını* girerek sisteme bağlanın.');
    buffer.writeln('');
    buffer.writeln('🔒 *Güvenlik Notu:* Kodlar öğrenciye özeldir. Giriş esnasında doğru okul numarası zorunludur.');

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: '${classModel.name} Veli Giriş Kodları',
      ),
    );
  }

  /// 📄 Tüm Sınıf İçin Resmî A4 Veli Referans Kodları Tablosu PDF Çıktısı (Okul Numarasız - Güvenli)
  static Future<void> printOrSaveClassPdf({
    required ClassModel classModel,
    required TeacherProfileModel teacher,
    required List<StudentModel> students,
    required Map<int, ParentTokenModel> tokens,
  }) async {
    final pdf = await PdfTrFonts.document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final schoolTitle = teacher.fullSchoolTitle.isNotEmpty ? teacher.fullSchoolTitle : teacher.schoolName;
    final nowFormatted = DateFormat('dd.MM.yyyy').format(DateTime.now());

    // Öğrencileri alfabetik veya mevcut sıra ile listele
    final sortedStudents = List<StudentModel>.from(students);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (pw.Context ctx) => pw.Column(
          children: [
            pw.Text(
              'T.C. MİLLÎ EĞİTİM BAKANLIĞI',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            if (schoolTitle.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                schoolTitle,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
              ),
            ],
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                border: pw.Border.all(color: PdfColors.indigo900, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Center(
                child: pw.Text(
                  '${classModel.name} SINIFI VELİ BİLGİLENDİRME SİSTEMİ GİRİŞ KODLARI LİSTESİ',
                  style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Sınıf / Şube: ${classModel.name}', style: const pw.TextStyle(fontSize: 9.5)),
                pw.Text('Öğretmen: ${teacher.fullName}', style: const pw.TextStyle(fontSize: 9.5)),
                pw.Text('Tarih: $nowFormatted', style: const pw.TextStyle(fontSize: 9.5)),
              ],
            ),
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (pw.Context ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.6, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.amber700, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                '📌 GÜVENLİK VE GİRİŞ TALİMATI: Sayın velilerimiz, SınıfCepte uygulaması "Veli Girişi" ekranından yukarıdaki referans kodunuzu ve güvenlik doğrulaması amacıyla kendi çocuğunuzun okul numarasını girerek güvenle bağlanabilirsiniz. Kodlar tekil olup başkalarıyla paylaşılmamalıdır.',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.brown900),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SınıfCepte Veli Bilgilendirme ve İletişim Portalı', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        build: (pw.Context ctx) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
              columnWidths: const {
                0: pw.FixedColumnWidth(28), // Sıra
                1: pw.FlexColumnWidth(4.0), // Öğrenci Adı Soyadı (Maskeli)
                2: pw.FlexColumnWidth(3.0), // Veli Referans Kodu
                3: pw.FlexColumnWidth(2.5), // Son Geçerlilik
              },
              children: [
                // Tablo Başlık Satırı
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo100),
                  children: [
                    _buildPdfHeaderCell('Sıra'),
                    _buildPdfHeaderCell('Öğrenci Adı Soyadı', align: pw.TextAlign.left),
                    _buildPdfHeaderCell('Veli Referans Kodu', align: pw.TextAlign.center),
                    _buildPdfHeaderCell('Son Geçerlilik', align: pw.TextAlign.center),
                  ],
                ),
                // Öğrenci Satırları
                ...List.generate(sortedStudents.length, (index) {
                  final student = sortedStudents[index];
                  final token = student.id != null ? tokens[student.id] : null;
                  final isEven = index % 2 == 0;
                  final rowBg = isEven ? PdfColors.white : PdfColors.grey100;
                  final maskedName = _maskLastName(student.fullName);

                  final hasValidToken = token != null && token.isValid;
                  final codeText = hasValidToken ? token.code : 'Üretilmedi';
                  final expText = hasValidToken ? DateFormat('dd.MM.yyyy').format(token.expiresAt) : '-';

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      _buildPdfTableCell('${index + 1}', align: pw.TextAlign.center),
                      _buildPdfTableCell(maskedName, align: pw.TextAlign.left, isBold: true),
                      _buildPdfTableCell(
                        codeText,
                        align: pw.TextAlign.center,
                        isBold: hasValidToken,
                        textColor: hasValidToken ? PdfColors.indigo900 : PdfColors.grey600,
                      ),
                      _buildPdfTableCell(expText, align: pw.TextAlign.center),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => PdfTrFonts.kaydet(pdf));
  }

  static String _maskLastName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length <= 1) return trimmed;
    final firstName = parts.sublist(0, parts.length - 1).join(' ');
    final lastName = parts.last;
    final initial = lastName.isNotEmpty ? '${lastName[0].toUpperCase()}.' : '';
    return '$firstName $initial'.trim();
  }

  static pw.Widget _buildPdfHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildPdfTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor textColor = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
        textAlign: align,
      ),
    );
  }
}
