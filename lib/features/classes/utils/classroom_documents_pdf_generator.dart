import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../data/models/student_model.dart';
import '../../../../data/models/class_model.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/date_formatter.dart';

/// SınıfCepte - T.C. Millî Eğitim Bakanlığı Resmî Standartlarına %100 Uyumlu PDF Motoru
/// Resmî Yazışmalarda Uygulanacak Usul ve Esaslar Hakkında Yönetmelik & MEB Matbu Evrak Formatı.
class ClassroomDocumentsPdfGenerator {
  ClassroomDocumentsPdfGenerator._();

  /// Belgeye basılacak öğretim yılı satırı.
  ///
  /// Önce 13 yerde `'2024-2025 EĞİTİM-ÖĞRETİM YILI'` ELLE yazılıydı
  /// ve her yıl eskiyordu. Kulüp PDF'i aynı hatayı çözerken not
  /// düşmüştü: *"Sınıf belgelerinde yıl elle yazılmıştı."*
  ///
  /// Sınıfın KENDİ kaydı tercih edilir: geçen yılın sınıfının evrakı
  /// açıldığında arşiv belgesi olarak doğru yılı gösterir. Kayıt
  /// boşsa takvimden hesaplanır — belge yılsız kalmaz.
  static String ogretimYili(ClassModel classModel) {
    final yil = classModel.academicYear.trim();
    final secilen =
        yil.isNotEmpty ? yil : AppDateFormatter.academicYearLabel();
    return '$secilen EĞİTİM-ÖĞRETİM YILI';
  }

  // ==========================================
  // 1. RESMÎ SINIF ÖĞRENCİ LİSTESİ FORMU
  // ==========================================
  static Future<Uint8List> generateStudentListPdfBytes({
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();

    final sortedStudents = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context ctx) => _buildOfficialHeader(
          schoolName: teacherProfile.schoolName,
          title: '${classModel.name} SINIFI ÖĞRENCİ İMZA VE NOT LİSTESİ',
          academicYear: ogretimYili(classModel),
          documentCode: 'MEB.ÖĞR.01',
        ),
        footer: (pw.Context ctx) => _buildOfficialFooter(
          teacherName: teacherProfile.fullName,
          principalName: teacherProfile.schoolPrincipalName,
          pageNumber: 'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        ),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            columnWidths: {
              // Genişlikler gömülü Noto Sans'a göre. Önce Roboto'ya
              // göre ölçülmüştü ve başlıklar iki satıra sarıyordu
              // ("S.NO", "CİNSİYETİ").
              0: const pw.FixedColumnWidth(34), // Sıra
              1: const pw.FixedColumnWidth(58), // No
              2: const pw.FlexColumnWidth(3), // Ad Soyad
              3: const pw.FixedColumnWidth(62), // Cinsiyet
              4: const pw.FlexColumnWidth(2.5), // İmza / Açıklama
            },
            headers: ['S.NO', 'OKUL NO', 'ADI VE SOYADI', 'CİNSİYET', 'İMZA / AÇIKLAMA'],
            data: List.generate(sortedStudents.length, (index) {
              final s = sortedStudents[index];
              return [
                '${index + 1}',
                s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                s.fullName.toUpperCase(),
                s.gender.toUpperCase(),
                '',
              ];
            }),
          ),
          pw.SizedBox(height: 10),
          _buildClassSummaryStats(sortedStudents),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 2. DERS İÇİ DEĞERLENDİRME ÇİZELGESİ (A4 YATAY / LANDSCAPE)
  // ==========================================
  static Future<Uint8List> generateEvaluationSheetPdfBytes({
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();

    final sortedStudents = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (pw.Context ctx) => _buildOfficialHeader(
          schoolName: teacherProfile.schoolName,
          title: '${classModel.name} SINIFI ${classModel.subject.toUpperCase()} DERSİ DERS İÇİ ETKİNLİK VE DEĞERLENDİRME ÇİZELGESİ',
          academicYear: ogretimYili(classModel),
          documentCode: 'MEB.DEĞ.02',
        ),
        footer: (pw.Context ctx) => _buildOfficialFooter(
          teacherName: teacherProfile.fullName,
          principalName: teacherProfile.schoolPrincipalName,
          pageNumber: 'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        ),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 7.8, color: PdfColors.black),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
            cellAlignment: pw.Alignment.center,
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FixedColumnWidth(44),
              2: const pw.FixedColumnWidth(135),
              3: const pw.FixedColumnWidth(34),
              4: const pw.FixedColumnWidth(34),
              5: const pw.FixedColumnWidth(34),
              6: const pw.FixedColumnWidth(34),
              7: const pw.FixedColumnWidth(34),
              8: const pw.FixedColumnWidth(34),
              9: const pw.FixedColumnWidth(34),
              10: const pw.FixedColumnWidth(34),
              11: const pw.FixedColumnWidth(34),
              12: const pw.FixedColumnWidth(34),
              13: const pw.FlexColumnWidth(1),
            },
            headers: [
              'S.NO',
              'NO',
              'ADI VE SOYADI',
              '1. ETK.',
              '2. ETK.',
              '3. ETK.',
              '4. ETK.',
              '5. ETK.',
              'ÖDEV 1',
              'ÖDEV 2',
              'PROJE',
              'SÖZLÜ',
              'KATILIM',
              'DÖNEM NOTU',
            ],
            data: List.generate(sortedStudents.length, (index) {
              final s = sortedStudents[index];
              return [
                '${index + 1}',
                s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                s.fullName.toUpperCase(),
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

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 3. HAFTALIK SINIF NÖBET ÇİZELGESİ (MEB RESMÎ FORMATI)
  // ==========================================
  static Future<Uint8List> generateCustomDutySchedulePdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    required int dailyDutyCount,
    required Map<String, List<String>> dayAssignments,
    List<String>? dutyRules,
  }) async {
    final pdf = await PdfTrFonts.document();

    final days = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA'];

    final defaultDutyRules = dutyRules ?? [
      '1. Teneffüslerde sınıfın pencerelerini açarak sınıfın düzenli olarak havalandırılmasını sağlamak.',
      '2. Yazı tahtasının temizliğini sağlamak, tahta kalemi ve silgi düzenini muhafaza etmek.',
      '3. Sınıf demirbaşlarına (sıra, masa, akıllı tahta vb.) zarar verilmesini önlemek ve olağan dışı durumları nöbetçi öğretmene bildirmek.',
      '4. Gün sonunda sınıfın genel düzen ve temizliğini kontrol ederek derslik kapısını kapatmak.',
    ];

    final headers = <String>['GÜNLER'];
    for (int i = 1; i <= dailyDutyCount; i++) {
      headers.add('$i. NÖBETÇİ ÖĞRENCİ\n(NO - ADI SOYADI)');
    }
    headers.add('NÖBET GÖREVİ VE YERİ');
    headers.add('İMZA');

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(80),
    };
    for (int i = 1; i <= dailyDutyCount; i++) {
      columnWidths[i] = const pw.FlexColumnWidth(2.5);
    }
    columnWidths[dailyDutyCount + 1] = const pw.FlexColumnWidth(2.2);
    columnWidths[dailyDutyCount + 2] = const pw.FixedColumnWidth(55);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildOfficialHeader(
                schoolName: teacherProfile.schoolName,
                title: '${classModel.name} SINIFI HAFTALIK NÖBETÇİ ÖĞRENCİ ÇİZELGESİ',
                academicYear: ogretimYili(classModel),
                documentCode: 'MEB.NÖB.03',
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                columnWidths: columnWidths,
                headers: headers,
                data: days.map((day) {
                  final assignedStudents = dayAssignments[day] ?? [];
                  final row = <String>[day];
                  for (int i = 0; i < dailyDutyCount; i++) {
                    row.add(i < assignedStudents.length ? assignedStudents[i].toUpperCase() : '');
                  }
                  row.add('${classModel.name} Dersliği & Havalandırma');
                  row.add('');
                  return row;
                }).toList(),
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NÖBETÇİ ÖĞRENCİLERİN GÖREV VE SORUMLULUKLARI (MEB Kurumları Yönetmeliği):',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.2, color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 4),
                    ...defaultDutyRules.map((rule) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Text(rule, style: const pw.TextStyle(fontSize: 7.8, color: PdfColors.black)),
                        )),
                  ],
                ),
              ),
              pw.Spacer(),
              _buildOfficialFooter(
                teacherName: teacherProfile.fullName,
                principalName: teacherProfile.schoolPrincipalName,
                pageNumber: 'Sayfa 1 / 1',
              ),
            ],
          );
        },
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 4. VELİ DAVETİYE MEKTUBU (TEK A4'TE 8 ADET RESMÎ KUPON)
  // ==========================================
  static Future<Uint8List> generate8in1ParentInvitationPdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    required String meetingDate,
    required String meetingTime,
    required String meetingLocation,
    String? agendaSummary,
    String? customNote,
  }) async {
    final pdf = await PdfTrFonts.document();

    final resolvedSchool = teacherProfile.schoolName.isNotEmpty ? teacherProfile.schoolName : 'OKUL MÜDÜRLÜĞÜ';
    final resolvedTeacher = teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName : 'Sınıf Rehber Öğretmeni';

    pw.Widget buildSingleInvitationCard(int index) {
      return pw.Container(
        margin: const pw.EdgeInsets.all(2.5),
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.6, style: pw.BorderStyle.dashed),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Resmî Antet Satırı
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'T.C. $resolvedSchool'.toUpperCase(),
                    maxLines: 1,
                    style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ),
                pw.Text('✂ Kesiniz', style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.black)),
              ],
            ),
            pw.Divider(height: 3, thickness: 0.5, color: PdfColors.black),

            // Belge Başlığı
            pw.Center(
              child: pw.Text(
                '${classModel.name} SINIFI VELİ TOPLANTI DAVETİYESİ',
                style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 2),

            // Resmî Çağrı Metni
            pw.Text(
              'Sayın Velimiz,',
              style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Öğrencimizin eğitim durumu, sınıf hedefleri ve başarı durumunu değerlendirmek üzere düzenlenecek toplantımıza teşriflerinizi rica ederim.',
              style: const pw.TextStyle(fontSize: 6.2, height: 1.15),
            ),
            pw.SizedBox(height: 3),

            // Toplantı Bilgi Tablosu
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: pw.Text('TARİH: $meetingDate', style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: pw.Text('SAAT: $meetingTime', style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: pw.Text('YER: $meetingLocation', style: const pw.TextStyle(fontSize: 6.2)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: pw.Text('GÜNDEM: ${agendaSummary ?? "Ders Başarısı & Rehberlik"}', maxLines: 1, style: const pw.TextStyle(fontSize: 6.0)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 2),

            // İmza ve Not
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    customNote ?? '* Katılımınız öğrencimiz için büyük önem taşımaktadır.',
                    style: pw.TextStyle(fontSize: 5.5, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(resolvedTeacher, style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 5.2)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        build: (pw.Context ctx) {
          return pw.GridView(
            crossAxisCount: 2,
            childAspectRatio: 1.48,
            children: List.generate(8, (i) => buildSingleInvitationCard(i)),
          );
        },
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 5. SINIF KURALLARI AFİŞİ (RESMÎ PANO SÖZLEŞMESİ)
  // ==========================================
  static Future<Uint8List> generateClassroomRulesPosterPdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    required List<String> rules,
  }) async {
    final pdf = await PdfTrFonts.document();

    final resolvedSchool = teacherProfile.schoolName.isNotEmpty ? teacherProfile.schoolName : 'OKULUMUZ';
    final resolvedTeacher = teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName : 'Sınıf Rehber Öğretmeni';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('T.C.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('MİLLÎ EĞİTİM BAKANLIĞI', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                pw.Text(resolvedSchool.toUpperCase(), style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(ogretimYili(classModel), style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '${classModel.name} SINIFI ORTAK YAŞAM KURALLARI VE SINIF SÖZLEŞMESİ',
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),

                // Kurallar Tablosu
                pw.Expanded(
                  child: pw.ListView.separated(
                    itemCount: rules.length,
                    separatorBuilder: (context, index) => pw.SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
                        ),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'MADDE ${index + 1}: ',
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                rules[index],
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                pw.SizedBox(height: 10),
                pw.Divider(thickness: 0.8, color: PdfColors.black),
                pw.SizedBox(height: 6),

                // Resmî İmzalar
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Sınıf Temsilcisi', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 12),
                        pw.Text('İmza: ........................', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(resolvedTeacher, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 7.5)),
                        pw.SizedBox(height: 4),
                        pw.Text('İmza: ........................', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('UYGUNDUR', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text(teacherProfile.schoolPrincipalName.isNotEmpty ? teacherProfile.schoolPrincipalName : 'Okul Müdürü', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Okul Müdürü', style: const pw.TextStyle(fontSize: 7.5)),
                        pw.Text('Mühür / İmza', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 6. VELİ TOPLANTI TUTANAĞI & İMZA SİRKÜSÜ (RESMÎ MEB TUTANAĞI)
  // ==========================================
  static Future<Uint8List> generateParentMeetingMinutesPdfBytes({
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
    String? meetingType,
    String? meetingDate,
    String? meetingTime,
    String? meetingLocation,
    List<String>? agendaItems,
    List<String>? decisions,
  }) async {
    final pdf = await PdfTrFonts.document();

    final sortedStudents = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    final defaultAgenda = agendaItems ?? [
      '1. Açılış, yoklama ve velilerle tanışma.',
      '2. Sınıfın genel akademik başarı durumu ve ders hedeflerinin görüşülmesi.',
      '3. Öğrenci devamsızlıkları, geç kalmalar ve okul kuralları hakkında bilgilendirme.',
      '4. Sosyal kulüpler, rehberlik faaliyetleri ve sınav hazırlık süreçleri.',
      '5. Okul-aile birliği ve sınıf temsilcisi seçimi.',
      '6. Dilek, temenniler ve kapanış.',
    ];

    final defaultDecisions = decisions ?? [
      '1. Öğrencilerin ders çalışma saatleri ve günlük ödev takibinin velilerce düzenli yapılmasına karar verildi.',
      '2. Devamsızlık sınırına yaklaşan öğrencilerin velilerine anında SMS/bilgilendirme yapılması kararlaştırıldı.',
      '3. Sınıf kitaplığının zenginleştirilmesi için kitap bağışı kampanyası düzenlenmesine karar verildi.',
      '4. Bir sonraki veli toplantısının dönem ortasında ara toplantı olarak yapılması uygun görüldü.',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context ctx) => _buildOfficialHeader(
          schoolName: teacherProfile.schoolName,
          title: '${classModel.name} SINIFI VELİ TOPLANTI TUTANAĞI VE İMZA SİRKÜSÜ',
          academicYear: ogretimYili(classModel),
          documentCode: 'MEB.TOP.04',
        ),
        footer: (pw.Context ctx) => _buildOfficialFooter(
          teacherName: teacherProfile.fullName,
          principalName: teacherProfile.schoolPrincipalName,
          pageNumber: 'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        ),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 6),
          // Toplantı Bilgi Matrisi
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('TOPLANTI NO / TÜRÜ', isHeader: true),
                  _buildTableCell('[ X ] ${meetingType ?? "1. Dönem Sene Başı Toplantısı"}'),
                  _buildTableCell('TOPLANTI TARİHİ', isHeader: true),
                  _buildTableCell(meetingDate ?? '..... / ..... / 202...'),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('TOPLANTI SAATİ', isHeader: true),
                  _buildTableCell(meetingTime ?? '..... : .....'),
                  _buildTableCell('TOPLANTI YERİ', isHeader: true),
                  _buildTableCell(meetingLocation ?? '${classModel.name} Sınıfı Dersliği'),
                ],
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('TOPLANTI BAŞKANI', isHeader: true),
                  _buildTableCell(teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName : 'Sınıf Rehber Öğretmeni'),
                  _buildTableCell('YAZMAN VELİ / ÖĞR.', isHeader: true),
                  _buildTableCell('...................................................'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Gündem Maddeleri
          pw.Text('I. GÜNDEM MADDELERİ:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.black, width: 0.6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: defaultAgenda
                  .map((item) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(item, style: const pw.TextStyle(fontSize: 8)),
                      ))
                  .toList(),
            ),
          ),
          pw.SizedBox(height: 8),

          // Alınan Kararlar
          pw.Text('II. GÜNDEM MADDELERİNİN GÖRÜŞÜLMESİ VE ALINAN KARARLAR:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.black, width: 0.6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: defaultDecisions
                  .map((item) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(item, style: const pw.TextStyle(fontSize: 8)),
                      ))
                  .toList(),
            ),
          ),
          pw.SizedBox(height: 10),

          // Katılımcı Veli İmza Sirküsü
          pw.Text('III. TOPLANTIYA KATILAN VELİLERİN İMZA SİRKÜSÜ LİSTESİ:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 7.8, color: PdfColors.black),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FixedColumnWidth(44),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(1.6),
              5: const pw.FixedColumnWidth(55),
            },
            headers: ['S.NO', 'NO', 'ÖĞRENCİ ADI SOYADI', 'KATILAN VELİ ADI SOYADI', 'YAKINLIĞI', 'İMZA'],
            data: List.generate(sortedStudents.length, (index) {
              final s = sortedStudents[index];
              return [
                '${index + 1}',
                s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                s.fullName.toUpperCase(),
                '',
                '',
                '',
              ];
            }),
          ),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 7. BİREYSEL VELİ GÖRÜŞME FORMU (MEB STANDART FORMU)
  // ==========================================
  static Future<Uint8List> generateParentInterviewFormPdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    StudentModel? student,
    String? interviewDate,
    String? parentName,
    String? parentRelation,
    String? interviewReason,
    String? discussionSummary,
    String? decisionsTaken,
  }) async {
    final pdf = await PdfTrFonts.document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildOfficialHeader(
                schoolName: teacherProfile.schoolName,
                title: 'BİREYSEL VELİ GÖRÜŞME KAYIT VE TAKİP FORMU',
                academicYear: ogretimYili(classModel),
                documentCode: 'MEB.REH.05',
              ),
              pw.SizedBox(height: 8),

              // Kimlik ve Görüşme Bilgileri
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('ÖĞRENCİ ADI SOYADI', isHeader: true),
                      _buildTableCell(student?.fullName.toUpperCase() ?? '...................................................'),
                      _buildTableCell('OKUL NO / SINIF', isHeader: true),
                      _buildTableCell('${student != null && student.schoolNumber > 0 ? student.schoolNumber : "......"} / ${classModel.name}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('GÖRÜŞÜLEN VELİ', isHeader: true),
                      _buildTableCell(parentName?.toUpperCase() ?? '...................................................'),
                      _buildTableCell('YAKINLIK DERECESİ', isHeader: true),
                      _buildTableCell(parentRelation ?? '[  ] Anne   [  ] Baba   [  ] Vasi'),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('GÖRÜŞME TARİHİ / SAATİ', isHeader: true),
                      _buildTableCell(interviewDate ?? '..... / ..... / 202...   .... : ....'),
                      _buildTableCell('GÖRÜŞME TALEBİ', isHeader: true),
                      _buildTableCell('[  ] Öğretmen   [  ] Veli   [  ] İdare'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // 1. Görüşme Konusu
              _buildSectionBox(
                title: '1. GÖRÜŞME NEDENİ VE ELE ALINAN KONULAR:',
                content: interviewReason ??
                    '[  ] Akademik Başarı ve Ders Takibi         [  ] Devamsızlık ve Geç Kalma Alışkanlığı\n'
                    '[  ] Okul ve Sınıf Kurallarına Uyum          [  ] Sosyal Uyum & Arkadaşlık İlişkileri\n'
                    '[  ] Ödev ve Sorumluluk Bilinci Geliştirme   [  ] Rehberlik ve Yönlendirme İhtiyacı',
                minHeight: 55,
              ),
              pw.SizedBox(height: 8),

              // 2. Görüşme İçeriği ve Veli Görüşü
              _buildSectionBox(
                title: '2. GÖRÜŞÜLEN HUSUSLAR VE VELİ BEYANI:',
                content: discussionSummary ??
                    '\n\n\n\n................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................',
                minHeight: 110,
              ),
              pw.SizedBox(height: 8),

              // 3. Alınan Kararlar
              _buildSectionBox(
                title: '3. ALINAN KARARLAR VE ORTAK TAKİP PLANI:',
                content: decisionsTaken ??
                    '\n\n\n................................................................................................................................................................................................................................................................................................................................................................................................................................................',
                minHeight: 85,
              ),
              pw.Spacer(),

              // Resmî İmzalar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(parentName?.isNotEmpty == true ? parentName!.toUpperCase() : 'GÖRÜŞÜLEN VELİ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('İmza: .............................', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName.toUpperCase() : 'SINIF REHBER ÖĞRETMENİ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 7.5)),
                      pw.Text('İmza: .............................', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 8. BİREYSEL ÖĞRENCİ GÖRÜŞME FORMU (MEB ORGM REHBERLİK FORMU)
  // ==========================================
  static Future<Uint8List> generateStudentInterviewFormPdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    StudentModel? student,
    String? interviewDate,
    String? interviewTopic,
    String? studentStatement,
    String? teacherObservation,
    String? actionPlan,
  }) async {
    final pdf = await PdfTrFonts.document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildOfficialHeader(
                schoolName: teacherProfile.schoolName,
                title: 'BİREYSEL ÖĞRENCİ GÖRÜŞME VE REHBERLİK FORMU',
                academicYear: ogretimYili(classModel),
                documentCode: 'MEB.REH.06 (GİZLİ)',
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(3.5),
                decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.black, width: 0.6)),
                child: pw.Text(
                  'GİZLİLİK İLKESİ: Bu formdaki bilgiler MEB Rehberlik Hizmetleri Yönetmeliği 18. maddesi gereğince gizlidir. Yetkisiz 3. kişilerle paylaşılamaz.',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 6),

              // Öğrenci Bilgileri Tablosu
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('ÖĞRENCİ ADI SOYADI', isHeader: true),
                      _buildTableCell(student?.fullName.toUpperCase() ?? '...................................................'),
                      _buildTableCell('OKUL NO / ŞUBE', isHeader: true),
                      _buildTableCell('${student != null && student.schoolNumber > 0 ? student.schoolNumber : "......"} / ${classModel.name}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('GÖRÜŞME TARİHİ / SAATİ', isHeader: true),
                      _buildTableCell(interviewDate ?? '..... / ..... / 202...   .... : ....'),
                      _buildTableCell('GÖRÜŞME BAŞLATICI', isHeader: true),
                      _buildTableCell('[  ] Öğrenci   [  ] Öğretmen   [  ] İdare'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // 1. Görüşme Konusu
              _buildSectionBox(
                title: '1. GÖRÜŞME NEDENİ VE ODAK ALANI:',
                content: interviewTopic ??
                    '[  ] Akademik Başarı ve Ders Çalışma Alışkanlığı   [  ] Akran Zorbalığı ve Dışlanma Durumu\n'
                    '[  ] Sınıf İçi Uyum ve Davranış Gelişimi            [  ] Ailevi ve Duygusal Problemler\n'
                    '[  ] Sınav Kaygısı ve Gelecek Hedefleri            [  ] Okul Devamsızlığı ve Motivasyon Kaybı',
                minHeight: 50,
              ),
              pw.SizedBox(height: 8),

              // 2. Öğrencinin İfadesi
              _buildSectionBox(
                title: '2. ÖĞRENCİNİN İFADESİ VE GÖRÜŞME İÇERİĞİ:',
                content: studentStatement ??
                    '\n\n\n\n................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................',
                minHeight: 110,
              ),
              pw.SizedBox(height: 8),

              // 3. Öğretmenin Değerlendirmesi ve Takip
              _buildSectionBox(
                title: '3. ÖĞRETMENİN GÖZLEMİ VE YAPILAN YÖNLENDİRME / TAKİP PLANI:',
                content: actionPlan ??
                    '[  ] Okul Rehberlik Servisine (PDR) Yönlendirildi.\n'
                    '[  ] Veli ile İletişime Geçilerek Bilgilendirildi.\n'
                    '[  ] Sınıf İçi Gözlem ve Destek Planı Başlatıldı.\n'
                    'Sonraki Takip Tarihi: ..... / ..... / 202...',
                minHeight: 80,
              ),
              pw.Spacer(),

              // İmzalar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(student?.fullName.toUpperCase() ?? 'GÖRÜŞÜLEN ÖĞRENCİ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('İmza: .............................', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName.toUpperCase() : 'SINIF REHBER ÖĞRETMENİ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 7.5)),
                      pw.Text('İmza: .............................', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 9. BEP (BİREYSELLEŞTİRİLMİŞ EĞİTİM PLANI) TAKİP FORMU
  // ==========================================
  static Future<Uint8List> generateBepTrackingFormPdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    StudentModel? student,
    String? subjectName,
    String? ramDecision,
    List<Map<String, String>>? goalsList,
  }) async {
    final pdf = await PdfTrFonts.document();

    final resolvedSubject = subjectName ?? classModel.subject;
    final defaultGoals = goalsList ?? [
      {'goal': 'Ders kazanımlarına uygun temel kavramları tanır ve açıklar.', 'method': 'Bireysel Anlatım & Görsel Destek', 'status': 'Devam Ediyor'},
      {'goal': 'Verilen basit yönergeleri adım adım takip ederek tamamlar.', 'method': 'Adım Adım Pekiştirme', 'status': 'Başarıldı'},
      {'goal': 'Ders içi etkinliklere akranlarıyla iş birliği içinde katılır.', 'method': 'Akran Desteği & Grup Çalışması', 'status': 'Devam Ediyor'},
      {'goal': 'Ödev ve sınıf sorumluluklarını zamanında teslim eder.', 'method': 'Veli İş Birliği & Takip Çizelgesi', 'status': 'Geliştirilmeli'},
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context ctx) => _buildOfficialHeader(
          schoolName: teacherProfile.schoolName,
          title: 'BEP (BİREYSELLEŞTİRİLMİŞ EĞİTİM PLANI) DÖNEMLİK GELİŞİM FORMU',
          academicYear: ogretimYili(classModel),
          documentCode: 'MEB.ÖZG.07',
        ),
        footer: (pw.Context ctx) => _buildOfficialFooter(
          teacherName: teacherProfile.fullName,
          principalName: teacherProfile.schoolPrincipalName,
          pageNumber: 'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        ),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 6),
          // Öğrenci & RAM Tanı Bilgileri
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('ÖĞRENCİ ADI SOYADI', isHeader: true),
                  _buildTableCell(student?.fullName.toUpperCase() ?? '...................................................'),
                  _buildTableCell('OKUL NO / SINIF', isHeader: true),
                  _buildTableCell('${student != null && student.schoolNumber > 0 ? student.schoolNumber : "......"} / ${classModel.name}'),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('DERS ADI', isHeader: true),
                  _buildTableCell(resolvedSubject.toUpperCase()),
                  _buildTableCell('RAM KARAR VE TANISI', isHeader: true),
                  _buildTableCell(ramDecision ?? 'Hafif Düzey / Kaynaştırma Eğitimi'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // BEP Kazanım Tablosu
          pw.Text('BİREYSELLEŞTİRİLMİŞ KAZANIM VE GELİŞİM DEĞERLENDİRME TABLOSU:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 7.8, color: PdfColors.black),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(65),
              4: const pw.FixedColumnWidth(50),
            },
            headers: ['S.NO', 'KAZANIM VE HEDEFLER (UZUN / KISA)', 'UYGULANAN YÖNTEM VE MATERYAL', 'DEĞERLENDİRME', 'İMZA'],
            data: List.generate(defaultGoals.length, (index) {
              final g = defaultGoals[index];
              return [
                '${index + 1}',
                g['goal'] ?? '',
                g['method'] ?? '',
                g['status'] ?? '',
                '',
              ];
            }),
          ),
          pw.SizedBox(height: 10),

          // Değerlendirme ve İmzalar
          _buildSectionBox(
            title: 'DÖNEM SONU GENEL DEĞERLENDİRME VE BEP BİRİMİ KARARI:',
            content:
                'Öğrencinin bireysel hedefleri doğrultusunda ders içi uyarlamalar yapılmış, sadeleştirilmiş sınav ve ek süre uygulamalarıyla desteklenmiştir. Sonraki dönem çalışmalarına devam edilecektir.',
            minHeight: 50,
          ),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 10. ÖĞRENCİ TANIMA FİŞİ (BİREYİ TANIMA FORMU - A4 TEK SAYFA)
  // ==========================================
  static Future<Uint8List> generateStudentInfoSheetPdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    StudentModel? student,
  }) async {
    final pdf = await PdfTrFonts.document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildOfficialHeader(
                schoolName: teacherProfile.schoolName,
                title: 'ÖĞRENCİ TANIMA FİŞİ (BİREYİ TANIMA FORMU)',
                academicYear: ogretimYili(classModel),
                documentCode: 'MEB.REH.08',
              ),
              pw.SizedBox(height: 6),

              // 1. Kimlik Bilgileri
              pw.Text('1. ÖĞRENCİ KİMLİK BİLGİLERİ:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                children: [
                  pw.TableRow(children: [
                    _buildTableCell('ADI VE SOYADI', isHeader: true),
                    _buildTableCell(student?.fullName.toUpperCase() ?? '...................................................'),
                    _buildTableCell('OKUL NO / SINIFI', isHeader: true),
                    _buildTableCell('${student != null && student.schoolNumber > 0 ? student.schoolNumber : "......"} / ${classModel.name}'),
                  ]),
                  pw.TableRow(children: [
                    _buildTableCell('CİNSİYETİ', isHeader: true),
                    _buildTableCell(student?.gender.toUpperCase() ?? '[  ] Kız    [  ] Erkek'),
                    _buildTableCell('DOĞUM TARİHİ / YERİ', isHeader: true),
                    _buildTableCell('..... / ..... / 20.....  /  .....................'),
                  ]),
                ],
              ),
              pw.SizedBox(height: 6),

              // 2. Aile Bilgileri
              pw.Text('2. AİLE VE SOSYO-EKONOMİK DURUM:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                children: [
                  pw.TableRow(children: [
                    _buildTableCell('ANNE ADI / MESLEĞİ', isHeader: true),
                    _buildTableCell('.................................. / ..................................'),
                    _buildTableCell('ANNE TELEFONU', isHeader: true),
                    _buildTableCell(student?.parentPhone ?? '05... ... .. ..'),
                  ]),
                  pw.TableRow(children: [
                    _buildTableCell('BABA ADI / MESLEĞİ', isHeader: true),
                    _buildTableCell('.................................. / ..................................'),
                    _buildTableCell('BABA TELEFONU', isHeader: true),
                    _buildTableCell('05... ... .. ..'),
                  ]),
                  pw.TableRow(children: [
                    _buildTableCell('ANNE-BABA DURUMU', isHeader: true),
                    _buildTableCell('[  ] Birlikte    [  ] Ayrı / Boşanmış    [  ] Vefat'),
                    _buildTableCell('KARDEŞ SAYISI', isHeader: true),
                    _buildTableCell('Toplam ..... Kardeş (..... sırada)'),
                  ]),
                  pw.TableRow(children: [
                    _buildTableCell('İKÂMET / ÇALIŞMA ODASI', isHeader: true),
                    _buildTableCell('[  ] Kendi Evi    [  ] Kira    [  ] Ayrı Odası Var'),
                    _buildTableCell('ULAŞIM ŞEKLİ', isHeader: true),
                    _buildTableCell('[  ] Yürüyerek    [  ] Servis    [  ] Veli'),
                  ]),
                ],
              ),
              pw.SizedBox(height: 6),

              // 3. Sağlık Durumu
              pw.Text('3. SAĞLIK VE ÖZEL GEREKSİNİMLER:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.black, width: 0.6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Kronik Rahatsızlık / Alerji: ${student?.notes ?? "...................................................................................................................."}', style: const pw.TextStyle(fontSize: 7.8)),
                    pw.SizedBox(height: 2),
                    pw.Text('Kullandığı Cihaz / İlaç: [  ] Gözlük    [  ] İşitme Cihazı    [  ] Düzenli İlaç: ....................................', style: const pw.TextStyle(fontSize: 7.8)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // 4. İlgi ve Yetenekler
              pw.Text('4. İLGİ ALANLARI, YETENEKLER VE HEDEFLER:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.black, width: 0.6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('İlgi Duyduğu Alanlar / Dersler: ............................................................................................................................', style: const pw.TextStyle(fontSize: 7.8)),
                    pw.SizedBox(height: 2),
                    pw.Text('Hobileri ve Spor / Sanat Faaliyetleri: ...................................................................................................................', style: const pw.TextStyle(fontSize: 7.8)),
                    pw.SizedBox(height: 2),
                    pw.Text('Gelecekte Hedeflediği Meslek / Alan: ....................................................................................................................', style: const pw.TextStyle(fontSize: 7.8)),
                  ],
                ),
              ),
              pw.Spacer(),

              _buildOfficialFooter(
                teacherName: teacherProfile.fullName,
                principalName: teacherProfile.schoolPrincipalName,
                pageNumber: 'Sayfa 1 / 1',
              ),
            ],
          );
        },
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 11. GEZİ & SOSYAL ETKİNLİK VELİ İZİN BELGESİ (TEK A4'TE 2 RESMÎ İZİN FORMU)
  // ==========================================
  static Future<Uint8List> generateFieldTripPermissionPdfBytes({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    required String eventName,
    required String destination,
    required String eventDate,
    required String departureReturnTime,
    String? transportType,
    String? costText,
  }) async {
    final pdf = await PdfTrFonts.document();

    final resolvedSchool = teacherProfile.schoolName.isNotEmpty ? teacherProfile.schoolName : 'OKUL MÜDÜRLÜĞÜ';
    final resolvedTeacher = teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName : 'Sınıf Rehber Öğretmeni';

    pw.Widget buildSinglePermissionSlip() {
      return pw.Container(
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.7, style: pw.BorderStyle.dashed),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('T.C. $resolvedSchool'.toUpperCase(), style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold)),
                pw.Text('✂ Kesim Çizgisi', style: const pw.TextStyle(fontSize: 6.8)),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                'SOSYAL ETKİNLİK VE GEZİ VELİ İZİN BELGESİ (MUVAFAKATNAME)',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${resolvedSchool.toUpperCase()} MÜDÜRLÜĞÜNE,',
              style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Velisi bulunduğum ${classModel.name} sınıfı ........... numaralı ................................................................ isimli öğrencinin aşağıda ayrıntıları belirtilen gezi / sosyal etkinliğe katılmasına izin veriyorum.',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
            pw.SizedBox(height: 5),

            // Etkinlik Detay Tablosu
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              children: [
                pw.TableRow(children: [
                  _buildTableCell('ETKİNLİK ADI', isHeader: true),
                  _buildTableCell(eventName),
                  _buildTableCell('GİDİLECEK YER', isHeader: true),
                  _buildTableCell(destination),
                ]),
                pw.TableRow(children: [
                  _buildTableCell('ETKİNLİK TARİHİ', isHeader: true),
                  _buildTableCell(eventDate),
                  _buildTableCell('GİDİŞ - DÖNÜŞ SAATİ', isHeader: true),
                  _buildTableCell(departureReturnTime),
                ]),
                pw.TableRow(children: [
                  _buildTableCell('ULAŞIM ŞEKLİ', isHeader: true),
                  _buildTableCell(transportType ?? 'Okul Servisi / Otobüs'),
                  _buildTableCell('ÜCRET / KATKI', isHeader: true),
                  _buildTableCell(costText ?? 'Ücretsiz'),
                ]),
              ],
            ),
            pw.SizedBox(height: 6),

            // İmzalar
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VELİ ADI SOYADI: .......................................', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                    pw.Text('İLETİŞİM TELEFONU: ....................................', style: const pw.TextStyle(fontSize: 7.2)),
                    pw.Text('İMZA / TARİH: ...........................................', style: const pw.TextStyle(fontSize: 7.2)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(resolvedTeacher, style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 6.8)),
                    pw.SizedBox(height: 4),
                    pw.Text('UYGUNDUR - Okul Müdürü Onayı', style: pw.TextStyle(fontSize: 6.5, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context ctx) {
          return pw.Column(
            children: [
              pw.Expanded(child: buildSinglePermissionSlip()),
              pw.Divider(height: 8, thickness: 0.6, color: PdfColors.black),
              pw.Expanded(child: buildSinglePermissionSlip()),
            ],
          );
        },
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 12. SOSYAL KULÜP ÖĞRENCİ DAĞILIM ÇİZELGESİ
  // ==========================================
  static Future<Uint8List> generateClubDistributionPdfBytes({
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();

    final sortedStudents = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context ctx) => _buildOfficialHeader(
          schoolName: teacherProfile.schoolName,
          title: '${classModel.name} SINIFI SOSYAL KULÜP ÖĞRENCİ DAĞILIM ÇİZELGESİ',
          academicYear: ogretimYili(classModel),
          documentCode: 'MEB.KUL.09',
        ),
        footer: (pw.Context ctx) => _buildOfficialFooter(
          teacherName: teacherProfile.fullName,
          principalName: teacherProfile.schoolPrincipalName,
          pageNumber: 'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        ),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 8.2, color: PdfColors.black),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FixedColumnWidth(50),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2),
            },
            headers: ['S.NO', 'OKUL NO', 'ADI VE SOYADI', 'SEÇTİĞİ SOSYAL KULÜP', 'GÖREVİ'],
            data: List.generate(sortedStudents.length, (index) {
              final s = sortedStudents[index];
              return [
                '${index + 1}',
                s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                s.fullName.toUpperCase(),
                '',
                'Üye',
              ];
            }),
          ),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // 13. ACİL DURUM & VELİ İLETİŞİM LİSTESİ (KVKK UYUMLU RESMÎ REHBERLİK LİSTESİ)
  // ==========================================
  static Future<Uint8List> generateEmergencyContactListPdfBytes({
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();

    final sortedStudents = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context ctx) => _buildOfficialHeader(
          schoolName: teacherProfile.schoolName,
          title: '${classModel.name} SINIFI ACİL DURUM VE VELİ İLETİŞİM LİSTESİ',
          academicYear: ogretimYili(classModel),
          documentCode: 'MEB.ACİ.10 (HASSAS)',
        ),
        footer: (pw.Context ctx) => _buildOfficialFooter(
          teacherName: teacherProfile.fullName,
          principalName: teacherProfile.schoolPrincipalName,
          pageNumber: 'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
        ),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(3.5),
            decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.black, width: 0.6)),
            child: pw.Text(
              'GİZLİDİR: Bu liste yalnızca acil durumlarda sınıf rehber öğretmeni ve okul idaresi tarafından kullanılmak üzere düzenlenmiştir.',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FixedColumnWidth(46),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(2.5),
            },
            headers: ['S.NO', 'OKUL NO', 'ADI VE SOYADI', 'VELİ TELEFONU', 'ÖZEL DURUM / SAĞLIK'],
            data: List.generate(sortedStudents.length, (index) {
              final s = sortedStudents[index];
              return [
                '${index + 1}',
                s.schoolNumber > 0 ? '${s.schoolNumber}' : '-',
                s.fullName.toUpperCase(),
                s.parentPhone?.isNotEmpty == true ? s.parentPhone! : '-',
                s.notes?.isNotEmpty == true ? s.notes! : '-',
              ];
            }),
          ),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  // ==========================================
  // DOĞRUDAN ÖNİZLEME YARDIMCILARI (PREVIEW HELPERS)
  // ==========================================

  static Future<void> generateStudentListPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await PdfPreviewScreen.open(
      context,
      title: 'Sınıf Öğrenci Listesi',
      subtitle: '${classModel.name} Resmî İmzalı Liste',
      fileName: 'Sinif_Listesi_${classModel.name}.pdf',
      documentBuilder: (format) => generateStudentListPdfBytes(
        classModel: classModel,
        students: students,
        teacherProfile: teacherProfile,
      ),
    );
  }

  static Future<void> generateDutySchedulePdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    final defaultAssignments = <String, List<String>>{};
    final days = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA'];
    for (int i = 0; i < days.length; i++) {
      final s1 = (i * 2) < students.length ? students[i * 2].fullName : '';
      final s2 = (i * 2 + 1) < students.length ? students[i * 2 + 1].fullName : '';
      defaultAssignments[days[i]] = [s1, s2].where((n) => n.isNotEmpty).toList();
    }

    await PdfPreviewScreen.open(
      context,
      title: 'Haftalık Nöbet Çizelgesi',
      subtitle: '${classModel.name} Nöbetçi Öğrenci Listesi',
      fileName: 'Nobet_Cizelgesi_${classModel.name}.pdf',
      documentBuilder: (format) => generateCustomDutySchedulePdfBytes(
        classModel: classModel,
        teacherProfile: teacherProfile,
        dailyDutyCount: 2,
        dayAssignments: defaultAssignments,
      ),
    );
  }

  static Future<void> generateClubDistributionPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await PdfPreviewScreen.open(
      context,
      title: 'Sosyal Kulüp Dağılımı',
      subtitle: '${classModel.name} Kulüp Tercih Listesi',
      fileName: 'Sosyal_Kulup_Listesi_${classModel.name}.pdf',
      documentBuilder: (format) => generateClubDistributionPdfBytes(
        classModel: classModel,
        students: students,
        teacherProfile: teacherProfile,
      ),
    );
  }

  static Future<void> generateEmergencyContactListPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await PdfPreviewScreen.open(
      context,
      title: 'Acil Durum & Veli İletişim',
      subtitle: '${classModel.name} İletişim ve Sağlık Listesi',
      fileName: 'Acil_Durum_Iletisim_${classModel.name}.pdf',
      documentBuilder: (format) => generateEmergencyContactListPdfBytes(
        classModel: classModel,
        students: students,
        teacherProfile: teacherProfile,
      ),
    );
  }

  static Future<void> generateParentMeetingMinutesPdf({
    required BuildContext context,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) async {
    await PdfPreviewScreen.open(
      context,
      title: 'Veli Toplantı Tutanağı',
      subtitle: '${classModel.name} Gündem & İmza Sirküsü',
      fileName: 'Veli_Toplanti_Tutanagi_${classModel.name}.pdf',
      documentBuilder: (format) => generateParentMeetingMinutesPdfBytes(
        classModel: classModel,
        students: students,
        teacherProfile: teacherProfile,
      ),
    );
  }

  // ==========================================
  // RESMÎ DEVLET BAŞLIK, ALT BİLGİ VE HÜCRE MOTORU
  // ==========================================

  static pw.Widget _buildOfficialHeader({
    required String schoolName,
    required String title,
    required String academicYear,
    String? documentCode,
  }) {
    final resolvedSchool = schoolName.isNotEmpty ? schoolName.toUpperCase() : '................................................... OKULU MÜDÜRLÜĞÜ';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(documentCode ?? '', style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
            pw.Text('T.C.', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.SizedBox(width: 40),
          ],
        ),
        pw.Text(
          'MİLLÎ EĞİTİM BAKANLIĞI',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
        pw.Text(
          resolvedSchool.endsWith('MÜDÜRLÜĞÜ') ? resolvedSchool : '$resolvedSchool MÜDÜRLÜĞÜ',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          academicYear,
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 0.8),
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
            ),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
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
    final resolvedTeacher = teacherName.isNotEmpty ? teacherName : '........................................';
    final resolvedPrincipal = principalName.isNotEmpty ? principalName : '........................................';

    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Sol: Sınıf Rehber Öğretmeni
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('..... / ..... / 202...', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
                pw.SizedBox(height: 2),
                pw.Text(resolvedTeacher, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.black)),
                pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
                pw.SizedBox(height: 12),
                pw.Text('İmza', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
              ],
            ),

            // Orta: Sayfa Numarası
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(pageNumber, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
            ),

            // Sağ: Okul Müdürü Onayı (UYGUNDUR)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('UYGUNDUR', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                pw.Text('..... / ..... / 202...', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
                pw.SizedBox(height: 2),
                pw.Text(resolvedPrincipal, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.black)),
                pw.Text('Okul Müdürü', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
                pw.SizedBox(height: 12),
                pw.Text('İmza - Mühür', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
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
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.6),
        color: PdfColors.grey200,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text('KIZ ÖĞRENCİ SAYISI: $girls', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.Text('ERKEK ÖĞRENCİ SAYISI: $boys', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.Text('TOPLAM ÖĞRENCİ SAYISI: $total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildSectionBox({
    required String title,
    required String content,
    double minHeight = 60,
  }) {
    return pw.Container(
      width: double.infinity,
      constraints: pw.BoxConstraints(minHeight: minHeight),
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.SizedBox(height: 2.5),
          pw.Text(content, style: const pw.TextStyle(fontSize: 7.8, color: PdfColors.black, height: 1.25)),
        ],
      ),
    );
  }
}
