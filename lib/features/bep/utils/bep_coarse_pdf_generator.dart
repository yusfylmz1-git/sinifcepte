import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../data/models/student_model.dart';
import '../data/models/bep_models.dart';

/// Kaba Değerlendirme Formu (KDF).
///
/// ## Ne işe yarar
/// BEP hazırlamadan önce öğretmen, dersin kazanımlarını tek tek
/// "yapıyor / yapamıyor" diye işaretler. Yapamadıkları BEP'in kısa
/// dönemli amaçları olur — yani bu form planın **girdisidir**.
///
/// İşaretleme ve "yapamıyor → plana al" bağı uygulamada zaten vardı
/// (`bep_coarse` tablosu, [BepRepository.setCoarse]). Eksik olan
/// belgenin kendisiydi: öğretmen işaretliyor ama o formu okul
/// dosyasına koyamıyordu.
///
/// ## Neden ayrı üretici
/// BEP planı yatay A4 ve dokuz sütunlu; KDF dikey ve iki sütunlu
/// (amaç + değerlendirme). Ortak olan yalnızca künye ve imza bloğu,
/// onlar da bu belgede farklı: KDF'de "değerlendiren" alanı var,
/// BEP'te yok.
class BepCoarsePdfGenerator {
  BepCoarsePdfGenerator._();

  static const _baslikDolgu = PdfColor.fromInt(0xFF7B9BB8);
  static const _satirDolgu = PdfColor.fromInt(0xFFF3F6F9);

  /// Formu üretir.
  ///
  /// [marks] boşsa üretim yapılmaz — boş bir değerlendirme formu
  /// imzalanacak bir belge değildir; çağıran bunu kontrol etmeli.
  static Future<Uint8List> build({
    required BepPlan plan,
    required StudentModel student,
    required String className,
    required String schoolName,
    required List<BepCoarseMark> marks,
    required String evaluatedAt,
    required String evaluatedBy,
  }) async {
    final pdf = await PdfTrFonts.document();

    final okul = (plan.schoolName.isNotEmpty ? plan.schoolName : schoolName)
        .trim()
        .toUpperCase();

    // Uzun amaç başlığına göre gruplanır — ERBAA'daki düzen de bu.
    // `unit_title` tabloda zaten tutuluyor.
    final gruplar = <String, List<BepCoarseMark>>{};
    for (final m in marks) {
      final baslik = m.unitTitle.trim().isEmpty ? 'Genel' : m.unitTitle.trim();
      gruplar.putIfAbsent(baslik, () => []).add(m);
    }

    final yapamiyor = marks.where((m) => !m.canDo).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
        build: (ctx) => [
          _kunye(
            okul: okul,
            plan: plan,
            student: student,
            className: className,
            evaluatedAt: evaluatedAt,
            evaluatedBy: evaluatedBy,
          ),
          pw.SizedBox(height: 10),
          for (final giris in gruplar.entries) ...[
            _grup(giris.key, giris.value),
            pw.SizedBox(height: 8),
          ],
          pw.SizedBox(height: 4),
          _ozet(marks.length, yapamiyor),
          pw.SizedBox(height: 20),
          _imzalar(),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  static pw.Widget _kunye({
    required String okul,
    required BepPlan plan,
    required StudentModel student,
    required String className,
    required String evaluatedAt,
    required String evaluatedBy,
  }) {
    // Değerlendirme yapılmadan önce açılan planlarda künye boş
    // olabilir; noktalı satır elle doldurulacak yeri gösterir.
    String ya(String deger) =>
        deger.trim().isEmpty ? '.......................' : deger.trim();

    return pw.Column(
      children: [
        pw.Text('T.C.',
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
        pw.Text('MİLLÎ EĞİTİM BAKANLIĞI',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(
          okul.isEmpty
              ? '................................ OKULU MÜDÜRLÜĞÜ'
              : (okul.endsWith('MÜDÜRLÜĞÜ') ? okul : '$okul MÜDÜRLÜĞÜ'),
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '${plan.academicYear} EĞİTİM-ÖĞRETİM YILI',
          style: const pw.TextStyle(fontSize: 8.5),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 0.8),
              bottom: pw.BorderSide(width: 0.8),
            ),
          ),
          child: pw.Text(
            'KABA DEĞERLENDİRME FORMU',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
        // İki sütunlu künye — ERBAA'daki düzen.
        pw.Table(
          border: pw.TableBorder.all(width: 0.45, color: PdfColors.blueGrey700),
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(children: [
              _alan('Öğrencinin Adı Soyadı', student.fullName),
              _alan('Ders', plan.subject),
            ]),
            pw.TableRow(children: [
              _alan('Sınıfı', className),
              _alan(
                'Öğrenci Numarası',
                student.schoolNumber > 0 ? '${student.schoolNumber}' : '',
              ),
            ]),
            pw.TableRow(children: [
              _alan('Değerlendirme Tarihi', ya(evaluatedAt)),
              _alan('Değerlendiren', ya(evaluatedBy)),
            ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _alan(String etiket, String deger) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
              text: '$etiket: ',
              style:
                  pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: deger.trim().isEmpty ? '—' : deger.trim(),
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ]),
        ),
      );

  /// Bir uzun dönemli amaç ve altındaki işaretler.
  static pw.Widget _grup(String baslik, List<BepCoarseMark> satirlar) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const pw.BoxDecoration(color: _baslikDolgu),
          child: pw.Text(
            baslik,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(width: 0.45, color: PdfColors.blueGrey700),
          columnWidths: const {
            0: pw.FlexColumnWidth(3.4),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _satirDolgu),
              children: [
                _hucre('Kısa Dönemli Amaçlar', kalin: true),
                _hucre('Değerlendirme', kalin: true, orta: true),
              ],
            ),
            for (final m in satirlar)
              pw.TableRow(children: [
                _hucre(m.description),
                _hucre(
                  m.canDo ? '+ Yapıyor' : '− Yapamıyor',
                  orta: true,
                  kalin: true,
                ),
              ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _hucre(String metin,
          {bool kalin = false, bool orta = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(
          metin,
          textAlign: orta ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: kalin ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  /// Sonuç özeti: kaç amaç değerlendirildi, kaçı plana giriyor.
  ///
  /// Öğretmenin belgeyi imzalamadan önce göreceği asıl bilgi bu.
  static pw.Widget _ozet(int toplam, int yapamiyor) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.45, color: PdfColors.blueGrey700),
        ),
        child: pw.Text(
          '$toplam amaç değerlendirilmiş, $yapamiyor amaç '
          '"Yapamıyor" olarak işaretlenmiştir. Bu amaçlar '
          'Bireyselleştirilmiş Eğitim Planına kısa dönemli amaç '
          'olarak alınır.',
          style: const pw.TextStyle(fontSize: 8),
        ),
      );

  /// İmza bloğu — SADECE GÖREV ADI, kimsenin ismi yazılmaz.
  ///
  /// BEP raporunda aynı karar verilmişti: önceden basılmış bir ad,
  /// kurul üyesi değiştiğinde belgeyi yanlış kılıyor ve öğretmen
  /// PDF'i bastıktan sonra düzeltemiyor.
  static pw.Widget _imzalar() {
    const gorevler = [
      'Değerlendiren Öğretmen',
      'Rehber Öğretmen',
      'Okul Müdürü',
    ];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final gorev in gorevler)
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(gorev,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 24),
                pw.Container(
                  height: 0.5,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 14),
                  color: PdfColors.blueGrey700,
                ),
                pw.SizedBox(height: 2),
                pw.Text('Adı Soyadı / İmza',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 6.6)),
              ],
            ),
          ),
      ],
    );
  }
}
