import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/name_formatter.dart';
import '../data/models/guidance_plan_model.dart';

/// Bir haftanın rehberlik etkinliği: plan satırı, ORGM metni ve öğretmenin kaydı.
typedef RehberlikHaftasi = ({
  GuidancePlanItem madde,
  GuidanceActivity? etkinlik,
  GuidanceLogEntry? kayit,
});

/// Sınıf rehberlik etkinliği uygulama kaydı — her hafta bir sayfa.
///
/// ## Neden (29 Ekim 2026)
/// Kullanıcı: "Rehberlik dosyası her hafta çıktı alınabilir düzende
/// olmalı. Bizde yalnız yapıldı/yapılmadı raporu var, yapılan etkinliğin
/// çıktısını vermiyoruz." Yıllık takip çizelgesi neyin yapıldığını
/// gösteriyordu, ne yapıldığını değil. Bu belge haftanın kazanımını,
/// ORGM etkinliğinin uygulama basamaklarını, öğretmenin notunu ve
/// uygulama tarihini dosyaya konacak biçimde verir.
///
/// Çalışma yaprakları ORGM kitabında resimdir, veri paketinde yok;
/// belge kitabın sayfasını gösterir.
class RehberlikEtkinlikPdf {
  RehberlikEtkinlikPdf._();

  static const _dolgu = PdfColor.fromInt(0xFFEDEDED);

  static Future<Uint8List> olustur({
    required List<RehberlikHaftasi> haftalar,
    required String schoolName,
    required String className,
    required String teacherName,
    required String academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();
    final okul = schoolName.trim().isEmpty
        ? '.................................. OKULU'
        : trUpper(schoolName.trim());

    for (final h in haftalar) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(50, 42, 50, 40),
          header: (_) => pw.Container(
            width: double.infinity,
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              children: [
                pw.Text(okul, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('$academicYear EĞİTİM ÖĞRETİM YILI', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text(
                  'SINIF REHBERLİK ETKİNLİĞİ UYGULAMA KAYDI',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${trUpper(className)} · ${h.madde.hafta ?? '-'}. hafta',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ),
          build: (_) => _hafta(h, className: className, teacherName: teacherName),
        ),
      );
    }

    return PdfTrFonts.kaydet(pdf);
  }

  static List<pw.Widget> _hafta(
    RehberlikHaftasi h, {
    required String className,
    required String teacherName,
  }) {
    final m = h.madde;
    final e = h.etkinlik;
    final k = h.kayit;
    final uygulandi = k?.uygulandi == true;
    final tarih = k?.uygulanmaTarihi;
    final tarihMetni = tarih == null
        ? '..... / ..... / ..........'
        : '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}';
    final etkinlikAdi = e?.etkinlikAdi ?? m.etkinlikAdi ?? '';

    final bilgi = <(String, String)>[
      ('Sınıf / Şube', trUpper(className)),
      ('Hafta', '${m.hafta ?? '-'}. hafta${m.tarihAraligi.isNotEmpty ? ' (${m.tarihAraligi})' : ''}'),
      if (e != null && e.gelisimAlani.isNotEmpty)
        ('Gelişim / Yeterlik Alanı',
            [e.gelisimAlani, if (e.yeterlikAlani.isNotEmpty) e.yeterlikAlani].join(' / ')),
      ('Kazanım', e?.kazanim.isNotEmpty == true ? e!.kazanim : m.kazanim),
      if (etkinlikAdi.isNotEmpty) ('Etkinlik', etkinlikAdi),
      if (e != null && e.sure.isNotEmpty) ('Süre', e.sure),
      ('Uygulama Tarihi', tarihMetni),
      ('Durum', uygulandi ? '[X] Uygulandı   [  ] Uygulanmadı' : '[  ] Uygulandı   [  ] Uygulanmadı'),
    ];

    return [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
        columnWidths: const {0: pw.FixedColumnWidth(118), 1: pw.FlexColumnWidth()},
        children: [
          for (final (ad, deger) in bilgi)
            pw.TableRow(
              children: [
                pw.Container(
                  color: _dolgu,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  child: pw.Text(ad, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  child: pw.Text(deger, style: const pw.TextStyle(fontSize: 8.5)),
                ),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 10),
      if (e == null)
        _bolum(
          'Uygulama',
          metin: 'Bu hafta için ORGM etkinlik metni bulunamadı. Kazanımın nasıl işlendiğini aşağıya yazınız.',
        )
      else ...[
        if (e.onHazirlik.isNotEmpty) _bolum('Ön Hazırlık', maddeler: e.onHazirlik),
        if (e.aracGerecler.isNotEmpty) _bolum('Araç-Gereçler', maddeler: e.aracGerecler),
        if (e.surec.isNotEmpty) _bolum('Uygulama Basamakları', maddeler: e.surec, numarali: true),
        if (e.degerlendirme.isNotEmpty) _bolum('Kazanımın Değerlendirilmesi', metin: e.degerlendirme),
        if (e.ozelGereksinimUyarlamalari.isNotEmpty)
          _bolum('Özel Gereksinimli Öğrenciler İçin Uyarlamalar', maddeler: e.ozelGereksinimUyarlamalari),
      ],
      _bolum('Öğretmenin Notu / Gözlemler', metin: k?.not.trim() ?? '', bosSatir: (k?.not.trim() ?? '').isEmpty ? 4 : 0),
      if (e != null && e.kaynakSayfa > 0)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2, bottom: 8),
          child: pw.Text(
            'Kaynak: MEB ORGM Sınıf Rehberlik Etkinlikleri, s. ${e.kaynakSayfa}. '
            'Etkinliğin çalışma yaprakları kitabın bu sayfasındadır.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
          ),
        ),
      pw.SizedBox(height: 14),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
          children: [
            pw.Text(
              teacherName.trim().isNotEmpty ? teacherName.trim() : '..............................',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 8.5)),
          ],
        ),
      ),
    ];
  }

  static pw.Widget _bolum(
    String baslik, {
    List<String> maddeler = const [],
    String metin = '',
    bool numarali = false,
    int bosSatir = 0,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            color: _dolgu,
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Text(baslik, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          if (metin.isNotEmpty)
            pw.Text(metin, style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.5)),
          for (var i = 0; i < maddeler.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 14,
                    child: pw.Text(numarali ? '${i + 1}.' : '•', style: const pw.TextStyle(fontSize: 8.5)),
                  ),
                  pw.Expanded(
                    child: pw.Text(maddeler[i], style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.5)),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < bosSatir; i++)
            pw.Container(
              height: 18,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.4)),
              ),
            ),
        ],
      ),
    );
  }
}
