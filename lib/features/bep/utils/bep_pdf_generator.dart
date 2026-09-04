import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../data/models/student_model.dart';
import '../../outcomes/data/models/curriculum_outcome_model.dart';
import '../data/models/bep_models.dart';

class BepPdfGenerator {
  BepPdfGenerator._();

  static const _headerFill = PdfColor.fromInt(0xFF7B9BB8);
  static const _altFill = PdfColor.fromInt(0xFFF3F6F9);

  // Asagidaki uc sabit artik YEDEK. Ogretmen secim yapmadiysa satir
  // bos kalmasin diye durur. Once bunlar dogrudan basiliyordu; her
  // ogrencinin BEP'inde ayni metin cikiyordu.
  static const _defaultMethods =
      'Anlatım Yöntemi, Bilgisayar Destekli Öğretim Yöntemi, '
      'Doğrudan Öğretim Yöntemi, Soru-Cevap Tekniği';
  static const _defaultMaterials =
      'Akıllı Tahta, Bilgisayar, Ekran Görüntüleri, Projeksiyon, '
      'Yazılım ve Uygulama Dosyaları';
  static const _defaultAssess =
      'Kısa Cevaplı Sınav, Ölçüt Bağımlı Ölçü Aracı, Sözlü Sınav, '
      'Uygulamalı Sınav';

  static Future<Uint8List> build({
    required BepPlan plan,
    required StudentModel student,
    required String className,
    required String schoolName,
    required String teacherName,
    required String principalName,
    required List<BepLongGoal> goals,
    List<UniqueOutcomeHit> bank = const [],
  }) async {
    final pdf = await PdfTrFonts.document();
    final school = (plan.schoolName.isNotEmpty ? plan.schoolName : schoolName)
        .trim()
        .toUpperCase();
    final dates = planDateRange(plan.academicYear, plan.startMonth);
    final hitsByCode = <String, UniqueOutcomeHit>{
      for (final h in bank)
        if (h.code.isNotEmpty) h.code: h,
    };

    final shorts = <BepShortGoal>[
      for (final g in goals) ...g.shorts,
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Taslak BEP. Okul BEP dosyası (EK-1…EK-7) yerine geçmez. '
                'SınıfCepte MEB resmi ürünü değildir.',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
            ),
            pw.Text(
              'Sayfa ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
        build: (ctx) => [
          pw.Center(
            child: pw.Text(
              school.isEmpty ? '................................ OKULU' : school,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Center(
            child: pw.Text(
              '${plan.academicYear} Eğitim Öğretim Yılı',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              '${plan.subject} (${plan.track.label}'
              '${plan.gradeLevel > 0 ? ' ${plan.gradeLevel}. sınıf' : ''}) '
              'Dersi Bireyselleştirilmiş Eğitim Planı',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Öğrencinin Adı-Soyadı: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                ),
                pw.TextSpan(
                  text: student.fullName,
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ],
            ),
          ),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Sınıf: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                ),
                pw.TextSpan(
                  text: className,
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ],
            ),
          ),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Numarası: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                ),
                pw.TextSpan(
                  text: student.schoolNumber > 0 ? '${student.schoolNumber}' : '',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ],
            ),
          ),
          if (plan.diagnosis.isNotEmpty || plan.ramDecision.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                [
                  if (plan.diagnosis.isNotEmpty) 'Eğitsel tanı: ${plan.diagnosis}',
                  if (plan.ramDecision.isNotEmpty) 'RAM: ${plan.ramDecision}',
                ].join('   '),
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ),
          pw.SizedBox(height: 6),
          _planTable(
            goals: goals,
            shorts: shorts,
            hitsByCode: hitsByCode,
            dates: dates,
          ),
          pw.SizedBox(height: 4),
          _environmentRow(plan),
          pw.SizedBox(height: 16),
          _signatures(
            plan: plan,
            teacherName: teacherName,
            principalName: principalName,
          ),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  static pw.Widget _planTable({
    required List<BepLongGoal> goals,
    required List<BepShortGoal> shorts,
    required Map<String, UniqueOutcomeHit> hitsByCode,
    required String dates,
  }) {
    final headers = [
      'Öğrenme Alanı',
      'Öğrenme Çıktısı',
      'Süreç Bileşenleri',
      'Yöntem ve Teknik',
      'Kullanılacak Materyaller',
      'Eğilimler',
      'Başlangıç-Bitiş Tarihi',
      'Ölçüt',
      'Ölçme-Değerlendirme',
    ];
    final widths = {
      0: const pw.FlexColumnWidth(1.15),
      1: const pw.FlexColumnWidth(1.35),
      2: const pw.FlexColumnWidth(1.7),
      3: const pw.FlexColumnWidth(1.2),
      4: const pw.FlexColumnWidth(1.2),
      5: const pw.FlexColumnWidth(0.85),
      6: const pw.FlexColumnWidth(0.85),
      7: const pw.FlexColumnWidth(0.55),
      8: const pw.FlexColumnWidth(1.15),
    };

    final data = <List<String>>[];
    if (shorts.isEmpty) {
      data.add([
        '—',
        'Henüz Yapamıyor işaretlenmedi.',
        '',
        '',
        '',
        '',
        dates,
        '4/5 (%80)',
        '',
      ]);
    } else {
      var i = 0;
      for (final long in goals) {
        for (final s in long.shorts) {
          i++;
          final hit = hitsByCode[s.outcomeCode ?? ''];
          final steps = (hit?.steps ?? const <String>[])
              .where((e) => e.trim().isNotEmpty)
              .join('\n');
          data.add([
            long.title,
            '$i. ${s.outcomeDescription?.trim().isNotEmpty == true ? s.outcomeDescription! : s.behavior}',
            steps,
            s.method.trim().isNotEmpty ? s.method : _defaultMethods,
            s.materials.trim().isNotEmpty ? s.materials : _defaultMaterials,
            hit?.values ?? '',
            dates,
            s.criterion.trim().isNotEmpty ? s.criterion : '4/5 (%80)',
            s.assessment.trim().isNotEmpty ? s.assessment : _defaultAssess,
          ]);
        }
      }
    }

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(width: 0.45, color: PdfColors.blueGrey700),
      headerDecoration: const pw.BoxDecoration(color: _headerFill),
      headerStyle: pw.TextStyle(
        fontSize: 6.6,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 6.4, height: 1.2),
      cellAlignment: pw.Alignment.topLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      columnWidths: widths,
      headers: headers,
      data: data,
      oddRowDecoration: const pw.BoxDecoration(color: _altFill),
    );
  }

  /// Egitim ortami duzenlemeleri blogu.
  ///
  /// Onceden bu uc kutu SADECE BASLIK basiyordu: `box('', 'Sosyal
  /// Etkilesim Ortami')` — govde metni basligin kendisiydi, icerik
  /// alani yoktu. Ogretmenin girdigi tedbirler belgeye cikmiyordu.
  static pw.Widget _environmentRow(BepPlan plan) {
    pw.Widget box(String title, String body) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.45, color: PdfColors.blueGrey700),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 6.6, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(body, style: const pw.TextStyle(fontSize: 6.3)),
              ],
            ),
          ),
        );
    // Bos kutu resmi belgede kotu duruyor; ogretmen girmediyse
    // yaygin varsayilan yazilir.
    String ya(String girilen, String yedek) =>
        girilen.trim().isNotEmpty ? girilen.trim() : yedek;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        box(
          'Fiziksel Ortam Düzenlemeleri',
          ya(plan.physicalArrangements,
              'Öğretmene yakın oturtma, dikkat dağıtıcı uyaranların azaltılması'),
        ),
        box(
          'Sosyal Etkileşim Ortamı',
          ya(plan.socialArrangements,
              'Akran desteği eşleştirmesi, olumlu davranış pekiştirme'),
        ),
        box(
          'Dijital Destekler',
          ya(plan.digitalSupports,
              'Etkileşimli tahta uygulamaları, video destekli anlatım'),
        ),
      ],
    );
  }

  static pw.Widget _signatures({
    required BepPlan plan,
    required String teacherName,
    required String principalName,
  }) {
    String nameFor(String needle, String fallback) {
      for (final m in plan.committee) {
        if (m.role.toLowerCase().contains(needle) && m.name.trim().isNotEmpty) {
          return m.name.trim();
        }
      }
      return fallback;
    }

    final slots = [
      ('Öğrenci Velisi', nameFor('veli', '')),
      ('Sınıf Rehber Öğretmeni', nameFor('sınıf', '')),
      ('Branş Öğretmeni', nameFor('ders', teacherName)),
      ('Rehber Öğretmen', nameFor('rehber', '')),
      ('Birim Başkanı', nameFor('başkan', principalName)),
    ];
    return pw.Row(
      children: [
        for (final s in slots)
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  s.$1,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.2),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  s.$2.isEmpty ? 'İmza' : s.$2,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7.4, fontWeight: pw.FontWeight.bold),
                ),
                if (s.$2.isNotEmpty)
                  pw.Text(
                    'İmza',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String planDateRange(String academicYear, String startMonth) {
    final parts = academicYear.split('-');
    final y1 = int.tryParse(parts.isNotEmpty ? parts.first : '') ?? DateTime.now().year;
    final y2 = parts.length > 1
        ? (int.tryParse(parts[1]) ?? y1 + 1)
        : y1 + 1;
    const map = {
      'Eylül': 9,
      'Ekim': 10,
      'Kasım': 11,
      'Aralık': 12,
      'Ocak': 1,
      'Şubat': 2,
      'Mart': 3,
      'Nisan': 4,
      'Mayıs': 5,
    };
    final month = map[startMonth] ?? 9;
    final startYear = month >= 9 ? y1 : y2;
    String two(int n) => n.toString().padLeft(2, '0');
    return '01.${two(month)}.$startYear - 31.05.$y2';
  }
}
