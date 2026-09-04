import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/screens/pdf_preview_screen.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../data/models/club_model.dart';

/// Sosyal kulüp resmî evrakları.
///
/// ## Hangi üç belge
/// Sosyal Etkinlikler Yönetmeliği danışman öğretmenden yıl içinde şunları
/// ister:
///
/// 1. **Yıllık çalışma planı** — yıl başında hazırlanır, müdür onaylar
/// 2. **Üye listesi** — MADDE 8/4 her öğrencinin üyeliğini zorunlu kılar
/// 3. **Faaliyet raporu** — yıl sonunda kurula sunulur
///
/// ## İmza düzeni neden farklı
/// Sınıf evrakında imza "Sınıf Rehber Öğretmeni + Okul Müdürü" iken kulüp
/// evrakında üç imza vardır: Sosyal Etkinlikler Kurulu Başkanı, Danışman
/// Öğretmen ve Öğrenci Kulübü Temsilcisi; müdür ise OLUR verir. Bu yüzden
/// `ClassroomDocumentsPdfGenerator` içindeki hazır alt bilgi kullanılamadı.
///
/// ## Öğretim yılı
/// Künyeye [AppDateFormatter.academicYearLabel] ile basılır. Sınıf
/// belgelerinde yıl elle "2024-2025" yazılmıştı ve her yıl eskiyordu;
/// burada o hata tekrarlanmıyor.
class ClubPdfGenerator {
  ClubPdfGenerator._();

  static const _kenar = pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22);

  /// Tablo içeriğinin toplam uzunluğuna göre yazı puntosu.
  ///
  /// ## Neden gerekli
  /// On aylık tablo A4 yatay sayfaya sığmadığında imza bloğu ve müdür
  /// OLUR'u ikinci sayfaya kayıyordu — imza tek başına boş sayfada
  /// kalıyor, resmî evrak kullanılamaz hâle geliyordu. 52 kulübün
  /// faaliyet raporu tarandığında 10'unda bu yaşandı.
  ///
  /// Çözüm sayfa eklemek değil KÜÇÜLTMEK: öğretmen tek sayfalık,
  /// imzalanabilir bir belge istiyor. 6.4 punto alt sınır — altına
  /// inilirse okunmuyor.
  ///
  /// Eşikler ölçümle bulundu: paketteki en uzun faaliyet raporu
  /// ~5200 karakter, en kısası ~2100.
  static double _icerigeGorePunto(int karakter) {
    if (karakter <= 2300) return 7.6;
    if (karakter <= 2600) return 7.2;
    if (karakter <= 2900) return 6.9;
    if (karakter <= 3200) return 6.6;
    return 6.4;
  }

  /// Puntoya göre hücre dolgusu — küçük yazıda dolgu da küçülmeli.
  static pw.EdgeInsets _dolgu(double punto) => pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: punto >= 7.4 ? 4 : 2.5,
      );

  // ------------------------------------------------------------------
  // 1. YILLIK ÇALIŞMA PLANI
  // ------------------------------------------------------------------

  static Future<Uint8List> yillikPlanBytes({
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();
    yillikPlanSayfasi(
      pdf: pdf,
      kulup: kulup,
      plan: plan,
      teacherProfile: teacherProfile,
    );
    return PdfTrFonts.kaydet(pdf);
  }

  /// Yıllık planı VAR OLAN belgeye sayfa olarak ekler.
  ///
  /// Üç belgeyi tek PDF'te birleştirebilmek için üretim ile belge
  /// oluşturma ayrıldı; `ClubBundleExporter` bu üçünü arka arkaya
  /// çağırıyor.
  static void yillikPlanSayfasi({
    required pw.Document pdf,
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required TeacherProfileModel teacherProfile,
  }) {
    final yil = AppDateFormatter.academicYearLabel();

    // Uzun planlarda yazı küçülür ki imza bloğu aynı sayfada kalsın.
    final punto = _icerigeGorePunto(
      plan.fold(0, (t, s) => t + s.amac.length + s.etkinlik.length),
    );

    pdf.addPage(
      pw.MultiPage(
        // Yatay: üç sütunlu plan tablosu dikeyde sıkışıyor.
        pageFormat: PdfPageFormat.a4.landscape,
        margin: _kenar,
        header: (ctx) => _kunye(
          schoolName: teacherProfile.schoolName,
          baslik: 'ÖĞRENCİ KULÜBÜ SOSYAL ETKİNLİKLER YILLIK ÇALIŞMA PLANI',
          solAlan: 'Kulüp / Etkinlik Adı: ${kulup.ad}',
          sagAlan: 'Öğretim Yılı: $yil',
          ilkSayfaMi: ctx.pageNumber == 1,
        ),
        footer: (ctx) => _sayfaNo(ctx),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle:
                pw.TextStyle(fontSize: punto, color: PdfColors.black),
            cellPadding: _dolgu(punto),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.topLeft,
              2: pw.Alignment.topLeft,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(58),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(5),
            },
            headers: const ['TARİH', 'AMAÇ', 'YAPILACAK ETKİNLİKLER'],
            data: plan
                .map((s) => [s.ay, s.amac, s.etkinlik])
                .toList(growable: false),
          ),
          _imzaBlogu(teacherProfile),
        ],
      ),
    );
  }

  static Future<void> yillikPlanAc(
    BuildContext context, {
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required TeacherProfileModel teacherProfile,
  }) =>
      PdfPreviewScreen.open(
        context,
        title: 'Yıllık Çalışma Planı',
        subtitle: kulup.ad,
        fileName: 'Kulup_Yillik_Plan_${_dosyaAdi(kulup.ad)}.pdf',
        documentBuilder: (format) => yillikPlanBytes(
          kulup: kulup,
          plan: plan,
          teacherProfile: teacherProfile,
        ),
      );

  // ------------------------------------------------------------------
  // 2. ÜYE LİSTESİ
  // ------------------------------------------------------------------

  static Future<Uint8List> uyeListesiBytes({
    required ClubModel kulup,
    required List<ClubMember> uyeler,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();
    uyeListesiSayfasi(
      pdf: pdf,
      kulup: kulup,
      uyeler: uyeler,
      teacherProfile: teacherProfile,
    );
    return PdfTrFonts.kaydet(pdf);
  }

  /// Üye listesini var olan belgeye sayfa olarak ekler.
  static void uyeListesiSayfasi({
    required pw.Document pdf,
    required ClubModel kulup,
    required List<ClubMember> uyeler,
    required TeacherProfileModel teacherProfile,
  }) {
    final yil = AppDateFormatter.academicYearLabel();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _kenar,
        header: (ctx) => _kunye(
          schoolName: teacherProfile.schoolName,
          baslik: 'ÖĞRENCİ KULÜBÜ ÜYE LİSTESİ',
          solAlan: 'Kulüp / Etkinlik Adı: ${kulup.ad}',
          sagAlan: 'Öğretim Yılı: $yil',
          ilkSayfaMi: ctx.pageNumber == 1,
        ),
        footer: (ctx) => _sayfaNo(ctx),
        build: (ctx) => [
          if (uyeler.isEmpty)
            _bosUyeSablonu()
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle:
                  const pw.TextStyle(fontSize: 8.2, color: PdfColors.black),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.center,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(28),
                1: const pw.FixedColumnWidth(48),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FixedColumnWidth(52),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(1.6),
              },
              headers: const [
                'S.NO',
                'OKUL NO',
                'ADI VE SOYADI',
                'SINIFI',
                'GÖREVİ',
                'İMZA',
              ],
              data: [
                for (var i = 0; i < uyeler.length; i++)
                  [
                    '${i + 1}',
                    uyeler[i].okulNo > 0 ? '${uyeler[i].okulNo}' : '-',
                    uyeler[i].adSoyad.toUpperCase(),
                    uyeler[i].sinifAdi.isNotEmpty ? uyeler[i].sinifAdi : '-',
                    uyeler[i].gorev,
                    // İmza sütunu elle doldurulur.
                    '',
                  ],
              ],
            ),
          pw.SizedBox(height: 8),
          // Boş şablonda "Toplam üye sayısı: 0" yazmak yanıltıcı;
          // öğretmen listeyi elle dolduracak.
          if (uyeler.isNotEmpty)
            pw.Text(
              'Toplam üye sayısı: ${uyeler.length}',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            )
          else
            pw.Text(
              'Toplam üye sayısı: ..............',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          _imzaBlogu(teacherProfile),
        ],
      ),
    );
  }

  static Future<void> uyeListesiAc(
    BuildContext context, {
    required ClubModel kulup,
    required List<ClubMember> uyeler,
    required TeacherProfileModel teacherProfile,
  }) =>
      PdfPreviewScreen.open(
        context,
        title: 'Kulüp Üye Listesi',
        subtitle: kulup.ad,
        fileName: 'Kulup_Uye_Listesi_${_dosyaAdi(kulup.ad)}.pdf',
        documentBuilder: (format) => uyeListesiBytes(
          kulup: kulup,
          uyeler: uyeler,
          teacherProfile: teacherProfile,
        ),
      );

  // ------------------------------------------------------------------
  // 3. YIL SONU FAALİYET RAPORU
  // ------------------------------------------------------------------

  static Future<Uint8List> faaliyetRaporuBytes({
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required List<ClubActivityLog> faaliyetler,
    required int uyeSayisi,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();
    faaliyetRaporuSayfasi(
      pdf: pdf,
      kulup: kulup,
      plan: plan,
      faaliyetler: faaliyetler,
      uyeSayisi: uyeSayisi,
      teacherProfile: teacherProfile,
    );
    return PdfTrFonts.kaydet(pdf);
  }

  /// Faaliyet raporunu var olan belgeye sayfa olarak ekler.
  static void faaliyetRaporuSayfasi({
    required pw.Document pdf,
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required List<ClubActivityLog> faaliyetler,
    required int uyeSayisi,
    required TeacherProfileModel teacherProfile,
  }) {
    final yil = AppDateFormatter.academicYearLabel();

    // Ay adına göre eşle: plan ile rapor satırları yan yana bassın.
    final planAyMap = {for (final p in plan) p.ay: p};

    // Raporda İKİ metin sütunu var (planlanan + gerçekleşen); plandan
    // daha uzun, küçültme burada daha çok gerekiyor.
    final punto = _icerigeGorePunto(
      faaliyetler.fold<int>(
        0,
        (t, f) =>
            t + f.yapilanCalisma.length + (planAyMap[f.ay]?.amac.length ?? 0),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: _kenar,
        header: (ctx) => _kunye(
          schoolName: teacherProfile.schoolName,
          baslik: 'ÖĞRENCİ KULÜBÜ YIL SONU FAALİYET RAPORU',
          solAlan: 'Kulüp / Etkinlik Adı: ${kulup.ad}',
          sagAlan: 'Öğretim Yılı: $yil',
          ilkSayfaMi: ctx.pageNumber == 1,
        ),
        footer: (ctx) => _sayfaNo(ctx),
        build: (ctx) => [
          pw.Text(
            'Kulüp üye sayısı: $uyeSayisi',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle:
                pw.TextStyle(fontSize: punto, color: PdfColors.black),
            cellPadding: _dolgu(punto),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.topLeft,
              2: pw.Alignment.topLeft,
              3: pw.Alignment.center,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(58),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(4),
              3: const pw.FixedColumnWidth(58),
            },
            headers: const [
              'TARİH',
              'PLANLANAN ÇALIŞMA',
              'GERÇEKLEŞEN ÇALIŞMA',
              'KATILAN ÜYE',
            ],
            data: [
              for (final f in faaliyetler)
                [
                  f.ay,
                  planAyMap[f.ay]?.amac ?? '-',
                  // Doldurulmamış ay boş bırakılmaz; elle yazılabilsin
                  // diye çizgi basılır.
                  f.dolu ? f.yapilanCalisma : '—',
                  f.katilanSayisi > 0 ? '${f.katilanSayisi}' : '—',
                ],
            ],
          ),
          _imzaBlogu(teacherProfile),
        ],
      ),
    );
  }

  static Future<void> faaliyetRaporuAc(
    BuildContext context, {
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required List<ClubActivityLog> faaliyetler,
    required int uyeSayisi,
    required TeacherProfileModel teacherProfile,
  }) =>
      PdfPreviewScreen.open(
        context,
        title: 'Yıl Sonu Faaliyet Raporu',
        subtitle: kulup.ad,
        fileName: 'Kulup_Faaliyet_Raporu_${_dosyaAdi(kulup.ad)}.pdf',
        documentBuilder: (format) => faaliyetRaporuBytes(
          kulup: kulup,
          plan: plan,
          faaliyetler: faaliyetler,
          uyeSayisi: uyeSayisi,
          teacherProfile: teacherProfile,
        ),
      );

  // ------------------------------------------------------------------
  // Ortak parçalar
  // ------------------------------------------------------------------

  /// Resmî künye: T.C. + okul + belge adı + kulüp/yıl satırı.
  ///
  /// Kulüp adı ve öğretim yılı yalnızca ilk sayfaya basılır; devam
  /// sayfalarında yalnızca başlık tekrarlanır.
  static pw.Widget _kunye({
    required String schoolName,
    required String baslik,
    required String solAlan,
    required String sagAlan,
    required bool ilkSayfaMi,
  }) {
    final okul = schoolName.isNotEmpty
        ? schoolName.toUpperCase()
        : '................................................... OKULU MÜDÜRLÜĞÜ';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('T.C.',
            style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black)),
        pw.Text(okul,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black)),
        pw.SizedBox(height: 3),
        pw.Text(baslik,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black)),
        pw.SizedBox(height: 8),
        if (ilkSayfaMi) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(solAlan,
                    style: const pw.TextStyle(
                        fontSize: 8.5, color: PdfColors.black)),
              ),
              pw.Text(sagAlan,
                  style: const pw.TextStyle(
                      fontSize: 8.5, color: PdfColors.black)),
            ],
          ),
          pw.SizedBox(height: 6),
        ],
      ],
    );
  }

  static pw.Widget _sayfaNo(pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
        ),
      );

  /// İmza ve OLUR bloğu — TEK parça.
  ///
  /// ## Neden tek widget
  /// İmza ile OLUR ayrı widget'ken `MultiPage` ikisini sayfalama
  /// sırasında ayırabiliyordu; tablo birinci sayfayı doldurduğunda
  /// imza bloğu TEK BAŞINA ikinci sayfaya düşüyordu. 52 kulübün
  /// faaliyet raporu tarandığında 10'unda bu yaşandı.
  ///
  /// Tek `Column` içinde birleştirilince MultiPage bloğu bölmüyor:
  /// ya tamamı sığıyor ya tamamı birlikte taşıyor. Taşıdığında bile
  /// tablonun son satırlarıyla aynı sayfada kalıyor, çünkü blok
  /// tablodan hemen sonra geliyor.
  static pw.Widget _imzaBlogu(TeacherProfileModel teacherProfile) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 16),
        _ucluImza(teacherProfile),
        pw.SizedBox(height: 8),
        _olur(teacherProfile),
      ],
    );
  }

  /// Kurul başkanı — danışman öğretmen — kulüp temsilcisi.
  ///
  /// Danışman öğretmen adı profilden gelir; diğer ikisi kulüpten kulübe
  /// değiştiği için elle doldurulmak üzere boş bırakılır.
  static pw.Widget _ucluImza(TeacherProfileModel teacherProfile) {
    final ogretmen = teacherProfile.fullName.isNotEmpty
        ? teacherProfile.fullName
        : '..............................';

    pw.Widget sutun(String ad, String unvan) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(ad,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black)),
              pw.Text(unvan,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.black)),
              pw.SizedBox(height: 14),
              pw.Text('İmza',
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.black)),
            ],
          ),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        sutun('..............................',
            'Sosyal Etkinlikler Kurulu Başkanı'),
        sutun(ogretmen, 'Danışman Öğretmen'),
        sutun('..............................',
            'Öğrenci Kulübü Temsilcisi'),
      ],
    );
  }

  /// Müdür OLUR bloğu — sağ alt köşe.
  static pw.Widget _olur(TeacherProfileModel teacherProfile) {
    final mudur = teacherProfile.schoolPrincipalName.isNotEmpty
        ? teacherProfile.schoolPrincipalName
        : '..............................';

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('OLUR',
              style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black)),
          pw.Text('....... / ....... / 20.......',
              style:
                  const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
          pw.SizedBox(height: 2),
          pw.Text(mudur,
              style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black)),
          pw.Text('Okul Müdürü',
              style:
                  const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
        ],
      ),
    );
  }

  /// Üye girilmemişse elle doldurulacak boş çizelge basar.
  ///
  /// ## Neden boş satır
  /// Öğretmen kulübü yeni kurmuş olabilir ve listeyi henüz uygulamaya
  /// girmemiştir; ama evrak bugün lazımdır. "Üye eklenmemiş" yazan bir
  /// PDF hiçbir işe yaramaz — elle doldurulabilen resmî çizelge ise
  /// doğrudan kullanılır.
  ///
  /// Satır sayısı bir sınıf mevcudunu karşılayacak kadar: 25 satır tek
  /// sayfaya sığıyor, fazlası ikinci sayfaya taşıyor ve boş sayfa
  /// hissi veriyordu.
  static pw.Widget _bosUyeSablonu() {
    const satirSayisi = 25;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
          headerStyle: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: const pw.TextStyle(fontSize: 8.2, color: PdfColors.black),
          cellHeight: 17,
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.center,
            4: pw.Alignment.centerLeft,
            5: pw.Alignment.center,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FixedColumnWidth(48),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FixedColumnWidth(52),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(1.6),
          },
          headers: const [
            'S.NO',
            'OKUL NO',
            'ADI VE SOYADI',
            'SINIFI',
            'GÖREVİ',
            'İMZA',
          ],
          data: [
            for (var i = 1; i <= satirSayisi; i++)
              // Sıra numarası basılı gelir; kalanı elle doldurulur.
              ['$i', '', '', '', '', ''],
          ],
        ),
      ],
    );
  }

  /// Dosya adı için güvenli hâle getirir.
  ///
  /// Kulüp adında boşluk ve nokta var; Android'de dosya adına giren
  /// eğik çizgi ve iki nokta kaydı bozuyor.
  static String _dosyaAdi(String ad) => ad
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
}
