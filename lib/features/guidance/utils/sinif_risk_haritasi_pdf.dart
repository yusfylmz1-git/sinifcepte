import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/name_formatter.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../../classes/utils/classroom_documents_pdf_generator.dart';

/// Sınıf risk haritasının risk alanları, resmî formdaki sırayla.
///
/// Sınıf rehber öğretmeni sınıfının risk haritasını oluşturur
/// (Psikososyal Koruma, Önleme ve Krize Müdahale Hizmetleri Yönergesi
/// md. 10/1-b) ve kasım ayında bir örneğini rehberlik servisine verir.
/// Sütunlar okullarda kullanılan formla aynı (kullanıcının örneği,
/// 29 Ekim 2026).
const List<String> sinifRiskAlanlari = [
  'Anne en fazla ilkokul mezunu',
  'Baba en fazla ilkokul mezunu',
  'Tek çocuk olan',
  '5 ve üstü kardeşi olan',
  'Anne ve babası ayrı yaşayan',
  'Anne ve babası boşanmış olan',
  'Yalnızca annesi ile yaşayan',
  'Yalnızca babası ile yaşayan',
  'Annesi hayatta olmayan',
  'Babası hayatta olmayan',
  'Anne ve babası hayatta olmayan',
  'Şehit çocuğu',
  'Yalnızca büyükanne/büyükbabasıyla yaşayan',
  'Yalnızca diğer akrabalarıyla yaşayan',
  'Koruyucu aile gözetiminde olan',
  'Sevgi evlerinde kalan',
  'Sosyal Hizmetler Çocuk Esirgeme Kurumunda kalan',
  'Ailesinde süreğen hastalığı olan',
  'Ailesinde ruhsal hastalığı olan',
  'Ailesinde bağımlı birey bulunan (alkol/madde)',
  'Ailesinde cezai hükmü bulunan',
  'Ailesi mevsimlik işçi olan',
  'Aile içi şiddete maruz kalan',
  'Özel yetenekli tanısı olan',
  'Yetersizlik alanında özel eğitim raporu olan',
  'Süreğen hastalığı olan',
  'Ruhsal hastalığı olan',
  'Danışmanlık tedbir kararı olan',
  'Eğitim tedbir kararı olan',
  'Maddi sıkıntı yaşayan',
  'Sürekli devamsız olan',
  'Bir işte çalışan',
  'Akademik başarısı düşük',
  'Riskli akran grubuna dahil olan',
  'Diğer',
];

/// Sınıf risk haritası PDF'i (A4 yatay).
///
/// Öğrenci adları sınıf listesinden gelir; işaretler kâğıt üzerinde
/// konur. Uygulama risk bilgisini SAKLAMAZ: sağlık, aile ve yargı
/// bilgisi özel nitelikli kişisel veridir (KVKK md. 6).
class SinifRiskHaritasiPdf {
  SinifRiskHaritasiPdf._();

  static const double _siraGenislik = 16;
  static const double _noGenislik = 24;
  static const double _adGenislik = 104;

  /// Döndürülmüş başlıkların yüksekliği; en uzun alan iki satıra sığar.
  static const double _baslikYukseklik = 118;

  static Future<Uint8List> olustur({
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
    DateTime? tarih,
  }) async {
    final pdf = await PdfTrFonts.document();
    final ogrenciler = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));
    final gun = tarih ?? DateTime.now();
    final tarihMetni = '${gun.day.toString().padLeft(2, '0')}.'
        '${gun.month.toString().padLeft(2, '0')}.${gun.year}';
    final okul = teacherProfile.schoolName.trim().isNotEmpty
        ? trUpper(teacherProfile.schoolName.trim())
        : 'OKUL MÜDÜRLÜĞÜ';
    final ogretmen = teacherProfile.fullName.trim();

    final sayfa = PdfPageFormat.a4.landscape;
    const kenar = 18.0;
    final alanGenislik = (sayfa.width -
            2 * kenar -
            _siraGenislik -
            _noGenislik -
            _adGenislik) /
        sinifRiskAlanlari.length;

    const ince = pw.BorderSide(color: PdfColors.black, width: 0.5);
    final kenarlik = pw.TableBorder.all(color: PdfColors.black, width: 0.5);

    pw.Widget hucre(String metin, {bool kalin = false, pw.Alignment hiza = pw.Alignment.center}) =>
        pw.Container(
          alignment: hiza,
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
          child: pw.Text(
            metin,
            style: pw.TextStyle(fontSize: 7, fontWeight: kalin ? pw.FontWeight.bold : null),
            maxLines: 1,
          ),
        );

    pw.Widget dikBaslik(String metin) => pw.Container(
          height: _baslikYukseklik,
          alignment: pw.Alignment.bottomCenter,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          // unconstrained: yoksa metin sütun genişliğine (~19 pt) sıkışıp
          // her kelimede alt satıra iniyordu.
          child: pw.Transform.rotateBox(
            angle: math.pi / 2,
            unconstrained: true,
            child: pw.SizedBox(
              width: _baslikYukseklik - 6,
              child: pw.Text(
                metin,
                style: const pw.TextStyle(fontSize: 5.6, lineSpacing: 0.4),
                maxLines: 2,
              ),
            ),
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: sayfa,
        margin: const pw.EdgeInsets.all(kenar),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(
              children: [
                pw.Expanded(child: pw.SizedBox()),
                pw.Text('GİZLİDİR', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Text(okul, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(
              '${trUpper(classModel.name)} SINIFI RİSK HARİTASI',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              ClassroomDocumentsPdfGenerator.ogretimYili(classModel),
              style: const pw.TextStyle(fontSize: 7.5),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Öğrenci Sayısı: ${ogrenciler.length}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Tarih: $tarihMetni', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
          ),
        ),
        build: (ctx) => [
          pw.Table(
            border: kenarlik,
            columnWidths: {
              0: const pw.FixedColumnWidth(_siraGenislik),
              1: const pw.FixedColumnWidth(_noGenislik),
              2: const pw.FixedColumnWidth(_adGenislik),
              for (var i = 0; i < sinifRiskAlanlari.length; i++)
                3 + i: pw.FixedColumnWidth(alanGenislik),
            },
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                verticalAlignment: pw.TableCellVerticalAlignment.bottom,
                children: [
                  dikBaslik('Sıra No'),
                  dikBaslik('Okul Numarası'),
                  pw.Container(
                    height: _baslikYukseklik,
                    alignment: pw.Alignment.bottomLeft,
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                      'Öğrencinin Adı Soyadı',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  for (final alan in sinifRiskAlanlari) dikBaslik(alan),
                ],
              ),
              for (var i = 0; i < ogrenciler.length; i++)
                pw.TableRow(
                  children: [
                    hucre('${i + 1}'),
                    hucre(ogrenciler[i].schoolNumber > 0 ? '${ogrenciler[i].schoolNumber}' : '-'),
                    hucre(ogrenciler[i].fullName, hiza: pw.Alignment.centerLeft),
                    for (var k = 0; k < sinifRiskAlanlari.length; k++) pw.SizedBox(height: 13),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: const pw.BoxDecoration(border: pw.Border(left: ince)),
                  child: pw.Text(
                    'Risk alanları objektif olarak belirlenebilen durumlardır. Gözlem, görüşme ve bireyi '
                    'tanıma teknikleriyle risk grubunda olduğu görülen öğrenci (ör. akran zorbalığına uğrayan, '
                    'sınıfta dışlanan, ihmal ya da istismara uğrayan, teknoloji bağımlılığı olan) "Diğer" '
                    'sütununda işaretlenir. Bu belge gizlidir; bir örneği kasım ayı içinde rehberlik ve '
                    'psikolojik danışma servisine teslim edilir.',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800, lineSpacing: 1),
                  ),
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Column(
                children: [
                  pw.SizedBox(height: 14),
                  pw.Text(
                    ogretmen.isNotEmpty ? ogretmen : '..............................',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }
}
