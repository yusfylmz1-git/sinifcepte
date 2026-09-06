import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../data/models/student_model.dart';
import '../data/council_minutes.dart';

/// Zümre / ŞÖK taslak tutanak PDF'i.
class CouncilMinutesPdfGenerator {
  CouncilMinutesPdfGenerator._();

  static Future<Uint8List> build({
    required CouncilKind kind,
    required CouncilPeriod period,
    required String schoolName,
    required String teacherName,
    required String principalName,
    required String branch,
    required String academicYear,
    required String meetingDate,
    required String meetingTime,
    required String meetingLocation,
    required String chairName,
    required String secretaryName,
    required List<CouncilAttendee> attendees,
    required List<CouncilAgendaItem> agenda,
    String? city,
    String? district,
    String? className,
    List<StudentModel> students = const [],
    int meetingNo = 1,
  }) async {
    final pdf = await PdfTrFonts.document();
    final title = CouncilMinutes.documentTitle(
      kind: kind,
      period: period,
      branch: branch,
      className: className,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        header: (ctx) => _header(
          schoolName: schoolName,
          city: city,
          district: district,
          academicYear: academicYear,
          title: title,
        ),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _infoTable(
            meetingNo: meetingNo,
            period: period,
            kind: kind,
            meetingDate: meetingDate,
            meetingTime: meetingTime,
            meetingLocation: meetingLocation,
            chairName: chairName,
            secretaryName: secretaryName,
            branch: branch,
            className: className,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'I. KATILIMCILAR',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          _attendeeTable(attendees),
          pw.SizedBox(height: 8),
          pw.Text(
            'II. GÜNDEM MADDELERİ VE ALINAN KARARLAR',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            CouncilMinutes.decisionHint,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          ...agenda.map(_agendaBlock),
          pw.SizedBox(height: 10),
          pw.Text(
            'III. İMZA SİRKÜSÜ (toplantıya katılmayan üyeler dâhil)',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          _signatureTable(attendees),
          pw.SizedBox(height: 14),
          _approvalRow(
            teacherName: teacherName,
            principalName: principalName,
            kind: kind,
          ),
        ],
      ),
    );

    if (kind == CouncilKind.sok) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          header: (ctx) => _header(
            schoolName: schoolName,
            city: city,
            district: district,
            academicYear: academicYear,
            title:
                '${(className ?? '').toUpperCase()} ŞÖK ÖĞRENCİ DEĞERLENDİRME IZGARASI',
          ),
          footer: (ctx) => _footer(ctx),
          build: (ctx) => [
            pw.Text(
              // "Bu ızgara e-Okul EK-5 yerine geçmez" cümlesi kaldırıldı:
              // belgeyi idarenin gözünde geçersiz gösteriyordu.
              // Boş alanların elle doldurulacağı bilgisi İŞLEVSEL,
              // o kalıyor.
              'Kişilik, sağlık ve ekonomik durum sütunları boş bırakılmıştır; '
              'kurul toplantısında elle doldurulur.',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 6),
            _studentGrid(students),
          ],
        ),
      );
    }

    return PdfTrFonts.kaydet(pdf);
  }

  static pw.Widget _header({
    required String schoolName,
    required String academicYear,
    required String title,
    String? city,
    String? district,
  }) {
    final school = schoolName.trim().isEmpty
        ? '................................................... OKULU MÜDÜRLÜĞÜ'
        : (schoolName.toUpperCase().endsWith('MÜDÜRLÜĞÜ')
            ? schoolName.toUpperCase()
            : '${schoolName.toUpperCase()} MÜDÜRLÜĞÜ');
    final loc = [
      if (district != null && district.trim().isNotEmpty) district.trim().toUpperCase(),
      if (city != null && city.trim().isNotEmpty) city.trim().toUpperCase(),
    ].join(' / ');

    return pw.Column(
      children: [
        pw.Text('T.C.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(
          'MİLLÎ EĞİTİM BAKANLIĞI',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        ),
        if (loc.isNotEmpty)
          pw.Text(loc, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        pw.Text(school, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(
          '$academicYear EĞİTİM-ÖĞRETİM YILI',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 0.8),
              bottom: pw.BorderSide(width: 0.8),
            ),
          ),
          child: pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                CouncilMinutes.disclaimer,
                style: const pw.TextStyle(fontSize: 6.2, color: PdfColors.grey700),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _infoTable({
    required int meetingNo,
    required CouncilPeriod period,
    required CouncilKind kind,
    required String meetingDate,
    required String meetingTime,
    required String meetingLocation,
    required String chairName,
    required String secretaryName,
    required String branch,
    String? className,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.6),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell('TOPLANTI NO', header: true),
            _cell('$meetingNo'),
            _cell('DÖNEM', header: true),
            _cell(CouncilMinutes.periodLabel(period)),
          ],
        ),
        pw.TableRow(
          children: [
            _cell('TARİH', header: true),
            _cell(meetingDate),
            _cell('SAAT', header: true),
            _cell(meetingTime),
          ],
        ),
        pw.TableRow(
          children: [
            _cell('YER', header: true),
            _cell(meetingLocation),
            _cell(kind == CouncilKind.sok ? 'ŞUBE' : 'BRANŞ / ALAN', header: true),
            _cell(kind == CouncilKind.sok ? (className ?? '-') : branch),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('BAŞKAN', header: true),
            _cell(chairName),
            _cell('YAZMAN', header: true),
            _cell(secretaryName.isEmpty ? '................................' : secretaryName),
          ],
        ),
      ],
    );
  }

  static pw.Widget _attendeeTable(List<CouncilAttendee> attendees) {
    final rows = attendees.isEmpty
        ? const [CouncilAttendee(name: '................................', branch: '..................')]
        : attendees;
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(width: 0.5),
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2.4),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(52),
      },
      headers: const ['S.NO', 'ADI SOYADI', 'BRANŞI / GÖREVİ', 'KATILIM', 'GÖREV'],
      data: [
        for (var i = 0; i < rows.length; i++)
          [
            '${i + 1}',
            rows[i].name,
            rows[i].branch,
            rows[i].present ? 'Katıldı' : 'Katılmadı',
            rows[i].isChair ? 'Başkan' : 'Üye',
          ],
      ],
    );
  }

  static pw.Widget _agendaBlock(CouncilAgendaItem item) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GÜNDEM: ${item.text}',
            style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'KARAR: ${item.decision.trim().isEmpty ? '................................' : item.decision.trim()}',
            style: const pw.TextStyle(fontSize: 7.6, height: 1.25),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureTable(List<CouncilAttendee> attendees) {
    final rows = [
      ...attendees,
      if (attendees.length < 6)
        for (var i = attendees.length; i < 6; i++)
          const CouncilAttendee(
            name: '................................',
            branch: '..................',
            present: true,
          ),
    ];
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(width: 0.5),
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2.2),
        3: const pw.FixedColumnWidth(90),
      },
      headers: const ['S.NO', 'ADI SOYADI', 'BRANŞI', 'İMZA'],
      data: [
        for (var i = 0; i < rows.length; i++)
          ['${i + 1}', rows[i].name, rows[i].branch, ''],
      ],
    );
  }

  static pw.Widget _approvalRow({
    required String teacherName,
    required String principalName,
    required CouncilKind kind,
  }) {
    final leftTitle = kind == CouncilKind.sok
        ? 'Şube Rehber Öğretmeni / Kurul Başkanı'
        : 'Zümre Başkanı';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Text(teacherName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text(leftTitle, style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(height: 16),
            pw.Text('İmza', style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
        pw.Column(
          children: [
            pw.Text('UYGUNDUR', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              principalName.trim().isEmpty ? 'Okul Müdürü' : principalName,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Okul Müdürü', style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(height: 16),
            pw.Text('İmza / Mühür', style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _studentGrid(List<StudentModel> students) {
    final rows = students.isEmpty
        ? List.generate(
            8,
            (i) => ['${i + 1}', '', '', '', '', '', '', '', '', '', ''],
          )
        : [
            for (var i = 0; i < students.length; i++)
              [
                '${i + 1}',
                students[i].schoolNumber > 0 ? '${students[i].schoolNumber}' : '',
                students[i].fullName.toUpperCase(),
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
              ],
          ];

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(width: 0.4),
      headerStyle: pw.TextStyle(fontSize: 6.4, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 6.4),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FixedColumnWidth(36),
        2: const pw.FlexColumnWidth(2.6),
        3: const pw.FlexColumnWidth(1.1),
        4: const pw.FlexColumnWidth(1.1),
        5: const pw.FlexColumnWidth(1.1),
        6: const pw.FlexColumnWidth(1.2),
        7: const pw.FlexColumnWidth(1.2),
        8: const pw.FlexColumnWidth(1.1),
        9: const pw.FlexColumnWidth(1.6),
        10: const pw.FlexColumnWidth(1.2),
      },
      headers: const [
        'S.NO',
        'OKUL NO',
        'ADI SOYADI',
        'KİŞİLİK',
        'BESLENME',
        'SAĞLIK',
        'SOSYAL İLİŞKİ',
        'EKONOMİK',
        'BAŞARI',
        'ALINACAK ÖNLEM',
        'GÖREVLİ',
      ],
      data: rows,
    );
  }

  static pw.Widget _cell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.6,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
