import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/name_formatter.dart';
import '../data/models/guidance_plan_model.dart';

/// Sınıf rehberlik planı — yıllık uygulama takip çizelgesi.
///
/// ## Neden hazır planların kopyası değil
/// Piyasadaki çıktılar üç aylık yatay Excel dökümü: yıl başında bir
/// kez basılıp dolaba konuyor, yıl sonunda kimse neyin uygulandığını
/// bilmiyor. Bu belge **uygulama kaydı**: her satırda işaret kutusu,
/// üstte "36 haftanın 31'i uygulandı" özeti, öğretmenin haftalık
/// notları. İmzalanıp dosyaya konduğunda gerçekten yapılan işi
/// gösterir.
class GuidancePlanPdfGenerator {
  GuidancePlanPdfGenerator._();

  // Resmî evrak paleti.
  //
  // Uygulama renkleri (mor başlık, lila zemin) ekranda hoş duruyor
  // ama basılı belgede kurumsal görünmüyor; MEB yazışmaları sade
  // siyah-beyazdır ve çoğu okul yazıcısı zaten renkli basmaz.
  static const _baslikDolgu = PdfColor.fromInt(0xFFD9D9D9);
  static const _altDolgu = PdfColor.fromInt(0xFFF2F2F2);
  static const _tatilDolgu = PdfColor.fromInt(0xFFE8E8E8);
  static const _kenar = PdfColors.black;

  static Future<Uint8List> build({
    required List<GuidancePlanItem> plan,
    required Map<int, GuidanceLogEntry> kayitlar,
    required int gradeLevel,
    required String className,
    required String schoolName,
    required String teacherName,
    required String academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();

    final uygulanabilir = plan.where((e) => e.uygulanabilir).toList();
    final uygulanan = uygulanabilir
        .where((e) => kayitlar[e.siraNo]?.uygulandi == true)
        .length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // Resmî Yazışmalarda Uygulanacak Usul ve Esaslar'a göre
        // kenar boşlukları 2,5 cm'dir (~71 punto). Önceki 22 punto
        // (~0,8 cm) belgeyi sayfaya yapışık gösteriyordu.
        //
        // Sol/sağ biraz daraltıldı: bu belge dokuz sütunlu bir
        // çizelge, tam 2,5 cm'de sütunlar okunmaz hâle geliyor.
        margin: const pw.EdgeInsets.fromLTRB(42, 71, 42, 50),
        header: (_) => _ustBilgi(
          schoolName: schoolName,
          className: className,
          gradeLevel: gradeLevel,
          academicYear: academicYear,
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          _ozetSeridi(uygulanan, uygulanabilir.length),
          pw.SizedBox(height: 8),
          _tablo(plan, kayitlar),
          pw.SizedBox(height: 14),
          _imzalar(teacherName),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  static pw.Widget _ustBilgi({
    required String schoolName,
    required String className,
    required int gradeLevel,
    required String academicYear,
  }) {
    // "5-A" -> sube "A". Sinif adi "5/A", "5 A" gibi de yazilabiliyor.
    final m = RegExp(
      r'[-/ ]\s*([A-Za-zÇĞİÖŞÜçğıöşü]+)\s*$',
    ).firstMatch(className.trim());
    final sube = m != null ? trUpper(m.group(1)!) : '….';

    // Başlık bloğu sayfa genişliğini KAPLAMALI; yoksa `Column`
    // içeriğe göre daralıp ortalama görsel olarak kayıyor.
    return pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            schoolName.trim().isEmpty
                ? '.................................. OKULU'
                : trUpper(schoolName),
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '$academicYear EĞİTİM ÖĞRETİM YILI',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 2),
          // Baslik MEB plan sablonundaki ifadeyle ayni olmali:
          // "…. ŞUBESİ 5. SINIF REHBERLİK PLANI". Idare belgeyi bu
          // adla tanidigi icin kendi ifademizi uydurmuyoruz;
          // "UYGULAMA ÇİZELGESİ" alt basliga alindi.
          pw.Text(
            '$sube ŞUBESİ $gradeLevel. SINIF REHBERLİK PLANI',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Üstteki ilerleme özeti — belgenin ayırt edici parçası.
  static pw.Widget _ozetSeridi(int uygulanan, int toplam) {
    final yuzde = toplam == 0 ? 0 : (uygulanan * 100 / toplam).round();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.black),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Uygulanan Kazanım Sayısı',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '$uygulanan / $toplam   (%$yuzde)',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tablo(
    List<GuidancePlanItem> plan,
    Map<int, GuidanceLogEntry> kayitlar,
  ) {
    final satirlar = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _baslikDolgu),
        children: [
          _hucre('Hafta', baslik: true, ortala: true),
          _hucre('Tarih', baslik: true),
          _hucre('Kazanım / Çalışma', baslik: true),
          _hucre('Etkinlik', baslik: true),
          _hucre('Uyg.', baslik: true),
          _hucre('Öğretmen Notu', baslik: true),
        ],
      ),
    ];

    var i = 0;
    for (final m in plan) {
      // Tatil satırı tek hücrede birleşik görünür.
      if (m.tatilMi) {
        satirlar.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _tatilDolgu),
            children: [
              _hucre(''),
              _hucre(m.tarihAraligi),
              _hucre(m.kazanim, kalin: true),
              _hucre(''),
              _hucre(''),
              _hucre(''),
            ],
          ),
        );
        continue;
      }

      final kayit = m.siraNo == null ? null : kayitlar[m.siraNo];
      final uygulandi = kayit?.uygulandi ?? false;
      i++;

      satirlar.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? _altDolgu : PdfColors.white,
          ),
          children: [
            _hucre(m.hafta == null ? '' : '${m.hafta}'),
            _hucre(m.tarihAraligi),
            _hucre(
              m.idariIsMi ? '${m.kazanim}  (idari çalışma)' : m.kazanim,
              italik: m.idariIsMi,
            ),
            _hucre(m.etkinlikAdi ?? ''),
            // İdari işler işaretlenmez; kutu yalnızca kazanımlarda.
            _hucre(
              m.idariIsMi ? '—' : (uygulandi ? '[X]' : '[  ]'),
              ortala: true,
              kalin: uygulandi,
            ),
            _hucre(kayit?.not ?? ''),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.4, color: _kenar),
      columnWidths: {
        // "Hafta" basligi 0.5'te "Haft/a" diye bolunuyordu.
        0: const pw.FlexColumnWidth(0.62),
        1: const pw.FlexColumnWidth(1.3),
        2: const pw.FlexColumnWidth(4.2),
        3: const pw.FlexColumnWidth(2.0),
        4: const pw.FlexColumnWidth(0.6),
        5: const pw.FlexColumnWidth(2.2),
      },
      children: satirlar,
    );
  }

  static pw.Widget _hucre(
    String metin, {
    bool baslik = false,
    bool kalin = false,
    bool italik = false,
    bool ortala = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      alignment: ortala ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        metin,
        textAlign: ortala ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: baslik ? 7.2 : 6.8,
          height: 1.25,
          fontWeight: (baslik || kalin)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          fontStyle: italik ? pw.FontStyle.italic : pw.FontStyle.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  /// İmza bloğu — resmî evrak düzeni.
  ///
  /// Hazırlayan ve görüş veren yan yana, müdür onayı ("Uygundur")
  /// ayrı ve sağ altta durur: MEB yazışmalarında onay makamı imza
  /// satırlarıyla aynı hizada değil, altında ve ayrı gösterilir.
  static pw.Widget _imzalar(String teacherName) {
    pw.Widget kutu(String unvan, String ad) => pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(
            unvan,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            ad.trim().isEmpty ? '…………………………' : ad,
            style: const pw.TextStyle(fontSize: 7.5),
          ),
          pw.Container(
            width: 90,
            margin: const pw.EdgeInsets.only(top: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 0.4, color: PdfColors.black),
              ),
            ),
            child: pw.Text(
              'İmza',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 6.5),
            ),
          ),
        ],
      ),
    );

    return pw.Column(
      children: [
        pw.Row(
          children: [
            kutu('Sınıf Rehber Öğretmeni', teacherName),
            kutu('Okul Rehber Öğretmeni', ''),
          ],
        ),
        pw.SizedBox(height: 16),
        // Onay makamı: resmî evrakta "Uygundur" ibaresi ve tarih,
        // imza satırlarının altında sağda durur.
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            children: [
              pw.Text('… / … / 20…', style: const pw.TextStyle(fontSize: 7.5)),
              pw.SizedBox(height: 2),
              pw.Text(
                'UYGUNDUR',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text('…………………………', style: const pw.TextStyle(fontSize: 7.5)),
              pw.Text(
                'Okul Müdürü',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
