import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/name_formatter.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../../bep/data/models/bep_models.dart';
import '../../classes/utils/classroom_documents_pdf_generator.dart';
import '../data/models/guidance_plan_model.dart';

/// Faaliyet raporunun kapsadığı süre.
enum FaaliyetDonemi {
  birinci('1. DÖNEM', '1. dönem'),
  yilSonu('YIL SONU', 'Yıl sonu (iki dönem)');

  const FaaliyetDonemi(this.baslik, this.sure);

  /// Belge başlığındaki biçim (büyük harf).
  final String baslik;

  /// "Kapsadığı Süre" satırı.
  final String sure;
}

/// Sınıf rehberlik dosyasının uygulamada daha önce olmayan belgeleri.
///
/// ## Neden (29 Ekim 2026)
/// Kullanıcı: "Rehberlik dosyasında ORGM'nin sitesindeki rehberlik
/// dosyasında olması gereken evraklar olmalı." Dosyanın bölümleri
/// (sınıf listesi, oturma planı, tanıma fişi, risk haritası, devamsızlık
/// çizelgesi…) çoğunlukla zaten üretiliyordu; eksik kalanlar bunlar:
/// özel eğitim ihtiyacı olan öğrenciler listesi, görüşme çizelgesi ve
/// dönem sonu / yıl sonu faaliyet raporu.
///
/// Uygulamanın tutmadığı bilgi (görüşme sayısı, yönlendirme, RAM raporu
/// tarihi) uydurulmaz; boş satır basılır, öğretmen kalemle doldurur.
class RehberlikDosyasiPdf {
  RehberlikDosyasiPdf._();

  static const _dolgu = PdfColor.fromInt(0xFFEDEDED);
  static final _kenarlik = pw.TableBorder.all(color: PdfColors.black, width: 0.5);

  // ---------------------------------------------------------------------
  // Özel eğitim ihtiyacı olan öğrenciler
  // ---------------------------------------------------------------------

  /// BEP'i olan öğrencilerin listesi; altında elle eklenecek boş satırlar.
  ///
  /// Tanı yazılmaz: sağlık bilgisi özel nitelikli kişisel veridir ve
  /// uygulama tanıyı zaten tutmuyor. Belge gizlidir.
  static Future<Uint8List> ozelEgitimListesi({
    required ClassModel classModel,
    required List<BepStudentSummary> ogrenciler,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();
    final liste = ogrenciler.where((o) => o.planCount > 0).toList()
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));
    const bos = 4;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
        header: (_) => _baslik(
          classModel: classModel,
          teacherProfile: teacherProfile,
          belge: 'ÖZEL EĞİTİM İHTİYACI OLAN ÖĞRENCİLER',
          gizli: true,
        ),
        footer: _sayfaNo,
        build: (_) => [
          pw.Table(
            border: _kenarlik,
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FixedColumnWidth(36),
              2: pw.FlexColumnWidth(2.4),
              3: pw.FlexColumnWidth(2.2),
              4: pw.FixedColumnWidth(58),
              5: pw.FixedColumnWidth(66),
              6: pw.FixedColumnWidth(78),
            },
            children: [
              _baslikSatiri(const [
                'S.No',
                'Okul No',
                'Adı Soyadı',
                'BEP Hazırlanan Dersler',
                'Kısa Dönemli Amaç (ulaşılan / toplam)',
                'RAM Raporu (Eğitsel Değ.) Tarihi',
                'Destek Eğitim Odası',
              ]),
              for (var i = 0; i < liste.length; i++)
                pw.TableRow(children: [
                  _hucre('${i + 1}', orta: true),
                  _hucre(liste[i].schoolNumber > 0 ? '${liste[i].schoolNumber}' : '-', orta: true),
                  _hucre(liste[i].studentName),
                  _hucre(liste[i].subjects.join(', ')),
                  _hucre('${liste[i].achievedCount} / ${liste[i].shortGoalCount}', orta: true),
                  _hucre(''),
                  _hucre('[  ] Var  [  ] Yok', orta: true),
                ]),
              for (var i = 0; i < bos; i++)
                pw.TableRow(children: [
                  _hucre('${liste.length + i + 1}', orta: true),
                  for (var k = 0; k < 5; k++) _hucre(''),
                  _hucre('[  ] Var  [  ] Yok', orta: true),
                ]),
            ],
          ),
          pw.SizedBox(height: 8),
          _not(
            'Liste, öğrencilerin bireyselleştirilmiş eğitim programı (BEP) kayıtlarından hazırlanmıştır. '
            'RAM raporu ve destek eğitim bilgisi elle doldurulur; BEP\'i henüz hazırlanmamış öğrenciler '
            'boş satırlara yazılır. Bu belge gizlidir.',
          ),
          pw.SizedBox(height: 16),
          _imza(teacherProfile),
        ],
      ),
    );
    return PdfTrFonts.kaydet(pdf);
  }

  // ---------------------------------------------------------------------
  // Görüşme çizelgesi
  // ---------------------------------------------------------------------

  /// Öğrenci ve veli görüşmelerinin boş çizelgesi (A4 yatay).
  ///
  /// Uygulama görüşme kaydı tutmuyor; çizelge dosyada kalemle doldurulur.
  /// Ayrıntılı görüşme için görüşme formları ayrıca var.
  static Future<Uint8List> gorusmeCizelgesi({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    int satir = 14,
  }) async {
    final pdf = await PdfTrFonts.document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        header: (_) => _baslik(
          classModel: classModel,
          teacherProfile: teacherProfile,
          belge: 'ÖĞRENCİ VE VELİ GÖRÜŞME ÇİZELGESİ',
          gizli: true,
        ),
        footer: _sayfaNo,
        build: (_) => [
          pw.Table(
            border: _kenarlik,
            columnWidths: const {
              0: pw.FixedColumnWidth(26),
              1: pw.FixedColumnWidth(58),
              2: pw.FixedColumnWidth(48),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(3),
              5: pw.FlexColumnWidth(3),
              6: pw.FixedColumnWidth(62),
            },
            children: [
              _baslikSatiri(const [
                'S.No',
                'Tarih',
                'Görüşülen (Ö / V)',
                'Öğrencinin Adı Soyadı',
                'Görüşme Konusu',
                'Sonuç / Yönlendirme (Rehberlik Servisi, RAM, Diğer)',
                'İmza',
              ]),
              for (var i = 0; i < satir; i++)
                pw.TableRow(children: [
                  pw.Container(
                    height: 25,
                    alignment: pw.Alignment.center,
                    child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  for (var k = 0; k < 6; k++) pw.SizedBox(),
                ]),
            ],
          ),
          pw.SizedBox(height: 6),
          _not(
            '"Görüşülen" sütununa öğrenci için Ö, veli için V yazılır. Yönlendirme yapıldıysa yeri '
            'belirtilir. Ayrıntılı görüşmeler öğrenci ve veli görüşme formlarına kaydedilir. '
            'Bu belge gizlidir.',
          ),
        ],
      ),
    );
    return PdfTrFonts.kaydet(pdf);
  }

  // ---------------------------------------------------------------------
  // Faaliyet raporu
  // ---------------------------------------------------------------------

  /// Raporun sayıları.
  ///
  /// Uygulanan her kazanım sayılır. Uygulanmayan yalnız [sonGecenHafta]'ya
  /// kadar olanlardan sayılır: içinde bulunulan hafta henüz bitmedi,
  /// sonraki haftalar gelmedi; ikisi de "uygulanamadı" değildir.
  /// [planlanan] = uygulanan + uygulanmayan.
  static ({
    List<GuidancePlanItem> kapsam,
    List<GuidancePlanItem> planlanan,
    List<GuidancePlanItem> uygulanan,
    List<GuidancePlanItem> uygulanmayan,
  }) faaliyetOzeti({
    required FaaliyetDonemi donem,
    required List<GuidancePlanItem> plan,
    required Map<int, GuidanceLogEntry> kayitlar,
    required int sonGecenHafta,
  }) {
    final kapsam = (donem == FaaliyetDonemi.birinci ? birinciDonemMaddeleri(plan) : plan)
        .where((m) => m.uygulanabilir)
        .toList();
    bool yapildi(GuidancePlanItem m) => kayitlar[m.siraNo]?.uygulandi == true;
    final planlanan = kapsam.where((m) => yapildi(m) || (m.hafta ?? 0) <= sonGecenHafta).toList();
    return (
      kapsam: kapsam,
      planlanan: planlanan,
      uygulanan: planlanan.where(yapildi).toList(),
      uygulanmayan: planlanan.where((m) => !yapildi(m)).toList(),
    );
  }

  /// Dönem sonu ya da yıl sonu sınıf rehberlik faaliyet raporu.
  ///
  /// Uygulanan ve uygulanamayan etkinlikler haftalık kayıtlardan gelir.
  /// Bitmemiş haftalar ([sonGecenHafta] sonrası) "uygulanamadı" sayılmaz:
  /// rapor dönem bitmeden açıldığında yapılmamış iş gibi görünürdü.
  static Future<Uint8List> faaliyetRaporu({
    required FaaliyetDonemi donem,
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
    required List<GuidancePlanItem> plan,
    required Map<int, GuidanceLogEntry> kayitlar,
    required int sonGecenHafta,
    required int bepliOgrenci,
    required int devamsizTakip,
    DateTime? tarih,
  }) async {
    final pdf = await PdfTrFonts.document();
    final gun = tarih ?? DateTime.now();

    final o = faaliyetOzeti(donem: donem, plan: plan, kayitlar: kayitlar, sonGecenHafta: sonGecenHafta);
    final kapsam = o.kapsam;
    final gelmis = o.planlanan;
    final gelmemis = kapsam.length - gelmis.length;
    final uygulanan = o.uygulanan;
    final uygulanmayan = o.uygulanmayan;

    final kiz = students.where((s) => s.gender == 'Kız').length;
    final erkek = students.where((s) => s.gender == 'Erkek').length;
    final haftalar = kapsam.isEmpty
        ? '-'
        : '${kapsam.first.hafta ?? 1}–${kapsam.last.hafta ?? '-'}. haftalar';

    // Yıl sonunda iki dönem ayrı da görünür.
    String? donemOzeti;
    if (donem == FaaliyetDonemi.yilSonu) {
      final birinci = birinciDonemMaddeleri(plan).where((m) => m.uygulanabilir).map((m) => m.siraNo).toSet();
      int sayi(bool Function(GuidancePlanItem) f) =>
          kapsam.where(f).where((m) => kayitlar[m.siraNo]?.uygulandi == true).length;
      final b1 = kapsam.where((m) => birinci.contains(m.siraNo)).length;
      final b2 = kapsam.length - b1;
      donemOzeti = '1. dönem: ${sayi((m) => birinci.contains(m.siraNo))} / $b1   ·   '
          '2. dönem: ${sayi((m) => !birinci.contains(m.siraNo))} / $b2';
    }

    final bilgi = <(String, String)>[
      ('Sınıf / Şube', trUpper(classModel.name)),
      ('Öğrenci Sayısı', '${students.length}  (Kız: $kiz, Erkek: $erkek)'),
      ('Sınıf Rehber Öğretmeni', teacherProfile.fullName.trim()),
      ('Kapsadığı Süre', '${donem.sure} · $haftalar'),
      ('Rapor Tarihi', _tarih(gun)),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 34, 44, 34),
        header: (ctx) => ctx.pageNumber == 1
            ? _baslik(
                classModel: classModel,
                teacherProfile: teacherProfile,
                belge: '${donem.baslik} SINIF REHBERLİK FAALİYET RAPORU',
              )
            : pw.SizedBox(),
        footer: _sayfaNo,
        build: (_) => [
          _bilgiTablosu(bilgi),
          pw.SizedBox(height: 8),
          pw.Table(
            border: _kenarlik,
            children: [
              _baslikSatiri(const ['Planlanan Etkinlik', 'Uygulanan', 'Uygulanamayan']),
              pw.TableRow(children: [
                _hucre('${gelmis.length}', orta: true, kalin: true),
                _hucre('${uygulanan.length}', orta: true, kalin: true),
                _hucre('${uygulanmayan.length}', orta: true, kalin: true),
              ]),
            ],
          ),
          if (donemOzeti != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(donemOzeti, style: const pw.TextStyle(fontSize: 8)),
          ],
          if (gelmemis > 0) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Henüz bitmemiş $gelmemis hafta rapora alınmadı.',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 10),
          _bolumBasligi('1. Uygulanan Etkinlikler'),
          if (uygulanan.isEmpty)
            _not('Bu dönemde uygulandı olarak işaretlenen etkinlik yok.')
          else
            pw.Table(
              border: _kenarlik,
              columnWidths: const {
                0: pw.FixedColumnWidth(34),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FixedColumnWidth(54),
              },
              children: [
                _baslikSatiri(const ['Hafta', 'Kazanım', 'Etkinlik', 'Tarih']),
                for (final m in uygulanan)
                  pw.TableRow(children: [
                    _hucre('${m.hafta ?? '-'}', orta: true),
                    _hucre(m.kazanim),
                    _hucre(m.etkinlikAdi ?? ''),
                    _hucre(
                      kayitlar[m.siraNo]?.uygulanmaTarihi == null ? '' : _tarih(kayitlar[m.siraNo]!.uygulanmaTarihi!),
                      orta: true,
                    ),
                  ]),
              ],
            ),
          pw.SizedBox(height: 10),
          _bolumBasligi('2. Uygulanamayan Etkinlikler ve Nedenleri'),
          if (uygulanmayan.isEmpty)
            _not('Planlanan etkinliklerin tamamı uygulandı.')
          else
            pw.Table(
              border: _kenarlik,
              columnWidths: const {
                0: pw.FixedColumnWidth(34),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2.4),
              },
              children: [
                _baslikSatiri(const ['Hafta', 'Kazanım', 'Nedeni']),
                for (final m in uygulanmayan)
                  pw.TableRow(children: [
                    _hucre('${m.hafta ?? '-'}', orta: true),
                    _hucre(m.kazanim),
                    _hucre(kayitlar[m.siraNo]?.not.trim() ?? ''),
                  ]),
              ],
            ),
          pw.SizedBox(height: 10),
          _bolumBasligi('3. Diğer Rehberlik Çalışmaları'),
          _bilgiTablosu([
            ('Bireysel öğrenci görüşmesi sayısı', ''),
            ('Veli görüşmesi sayısı', ''),
            ('Veli toplantısı tarih(ler)i', ''),
            ('Rehberlik servisine yönlendirilen öğrenci sayısı', ''),
            ('BEP\'i olan öğrenci sayısı', '$bepliOgrenci'),
            ('Devamsızlık takibindeki öğrenci sayısı', '$devamsizTakip'),
          ], etiketGenislik: 220),
          pw.SizedBox(height: 10),
          _bolumBasligi('4. Sınıfın Genel Durumu ve Değerlendirme'),
          ..._bosSatirlar(4),
          pw.SizedBox(height: 10),
          _bolumBasligi('5. Karşılaşılan Güçlükler ve Öneriler'),
          ..._bosSatirlar(4),
          pw.SizedBox(height: 18),
          _imza(teacherProfile),
        ],
      ),
    );
    return PdfTrFonts.kaydet(pdf);
  }

  // ---------------------------------------------------------------------
  // Ortak parçalar
  // ---------------------------------------------------------------------

  static String _tarih(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static pw.Widget _baslik({
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
    required String belge,
    bool gizli = false,
  }) {
    final okul = teacherProfile.schoolName.trim().isNotEmpty
        ? trUpper(teacherProfile.schoolName.trim())
        : '.................................. OKULU';
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        children: [
          if (gizli)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('GİZLİDİR', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
            ),
          pw.Text(okul, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(ClassroomDocumentsPdfGenerator.ogretimYili(classModel), style: const pw.TextStyle(fontSize: 8.5)),
          pw.SizedBox(height: 2),
          pw.Text(
            '${trUpper(classModel.name)} SINIFI $belge',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _sayfaNo(pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
        ),
      );

  static pw.TableRow _baslikSatiri(List<String> basliklar) => pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _dolgu),
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          for (final b in basliklar)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              child: pw.Text(
                b,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
        ],
      );

  static pw.Widget _hucre(String metin, {bool orta = false, bool kalin = false}) => pw.Container(
        alignment: orta ? pw.Alignment.center : pw.Alignment.centerLeft,
        constraints: const pw.BoxConstraints(minHeight: 18),
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(
          metin,
          style: pw.TextStyle(fontSize: 8, fontWeight: kalin ? pw.FontWeight.bold : null),
        ),
      );

  /// Etiket-değer tablosu. Değer boşsa satır kalemle doldurulmak üzere boş kalır.
  static pw.Widget _bilgiTablosu(List<(String, String)> satirlar, {double etiketGenislik = 130}) =>
      pw.Table(
        border: _kenarlik,
        columnWidths: {0: pw.FixedColumnWidth(etiketGenislik), 1: const pw.FlexColumnWidth()},
        children: [
          for (final (ad, deger) in satirlar)
            pw.TableRow(children: [
              pw.Container(
                color: _dolgu,
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: pw.Text(ad, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: pw.Text(deger, style: const pw.TextStyle(fontSize: 8.5)),
              ),
            ]),
        ],
      );

  static pw.Widget _bolumBasligi(String metin) => pw.Container(
        width: double.infinity,
        color: _dolgu,
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Text(metin, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  static List<pw.Widget> _bosSatirlar(int n) => [
        for (var i = 0; i < n; i++)
          pw.Container(
            height: 18,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.4)),
            ),
          ),
      ];

  static pw.Widget _not(String metin) => pw.Text(
        metin,
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800, lineSpacing: 1),
      );

  static pw.Widget _imza(TeacherProfileModel teacherProfile) {
    final ad = teacherProfile.fullName.trim();
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        children: [
          pw.Text(
            ad.isNotEmpty ? ad : '..............................',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Sınıf Rehber Öğretmeni', style: const pw.TextStyle(fontSize: 8.5)),
        ],
      ),
    );
  }
}
