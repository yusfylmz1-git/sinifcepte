import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/name_formatter.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../data/teacher_file_model.dart';
import '../data/teacher_file_texts.dart';

/// Öğretmen ders yılı dosyası — teftişte sunulan resmî klasör.
///
/// ## Ne işe yarar
/// Öğretmenin yıl boyunca dosyasında bulundurması gereken evraklar
/// tek yerden üretilir. Teftişte ilk bakılanlar: kapak, Atatürk
/// köşesi, İstiklâl Marşı, Gençliğe Hitabe ve özlük künyesi.
///
/// ## Tasarım kararları
/// **Atatürk portresi vektörel çizilir.** İnternetten indirilen bir
/// fotoğrafın telif durumu belirsiz; uygulamaya gömülürse 30.000
/// öğretmene dağıtılmış olur. Vektörel silüet + imza bu riski
/// tamamen kaldırır ve dosya boyutunu da büyütmez.
///
/// **Metinler [TeacherFileTexts] içinde.** İstiklâl Marşı'nın tek
/// harfi yanlış basılırsa belge kusurlu sayılır; düzen değişikliği
/// yaparken metne dokunmamak için ayrıldı.
///
/// **Tek belge de üretilir, hepsi birlikte de.** [tekBelge] bir
/// sayfa basar; [tumDosya] hepsini sırayla tek PDF yapar — öğretmen
/// bir kere basıp klasöre koyar.
class TeacherFilePdfGenerator {
  TeacherFilePdfGenerator._();

  /// Tek bir belgeyi üretir.
  static Future<Uint8List> tekBelge({
    required TeacherFileDoc belge,
    required TeacherProfileModel teacher,
    required TeacherFileInfo bilgi,
    required List<TeacherFileLesson> dersler,
    required List<TeacherFileClass> siniflar,
    String? academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();
    final yil = _yil(academicYear);

    _sayfaEkle(
      pdf: pdf,
      belge: belge,
      teacher: teacher,
      bilgi: bilgi,
      dersler: dersler,
      siniflar: siniflar,
      yil: yil,
    );

    return PdfTrFonts.kaydet(pdf);
  }

  /// Seçili belgelerin tamamını tek PDF olarak üretir.
  ///
  /// [secili] boşsa bütün belgeler basılır.
  static Future<Uint8List> tumDosya({
    required TeacherProfileModel teacher,
    required TeacherFileInfo bilgi,
    required List<TeacherFileLesson> dersler,
    required List<TeacherFileClass> siniflar,
    Set<TeacherFileDoc>? secili,
    String? academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();
    final yil = _yil(academicYear);

    final liste = TeacherFileDoc.values
        .where((b) => secili == null || secili.isEmpty || secili.contains(b))
        .toList();

    for (final belge in liste) {
      _sayfaEkle(
        pdf: pdf,
        belge: belge,
        teacher: teacher,
        bilgi: bilgi,
        dersler: dersler,
        siniflar: siniflar,
        yil: yil,
      );
    }

    return PdfTrFonts.kaydet(pdf);
  }

  /// Öğretim yılı satırı. Verilmezse takvimden hesaplanır.
  ///
  /// Sınıf evraklarında yıl 13 yerde ELLE yazılıydı ve her yıl
  /// eskiyordu; aynı hataya düşmemek için tek yerden geliyor.
  static String _yil(String? verilen) {
    final y = (verilen ?? '').trim();
    return y.isNotEmpty ? y : AppDateFormatter.academicYearLabel();
  }

  static void _sayfaEkle({
    required pw.Document pdf,
    required TeacherFileDoc belge,
    required TeacherProfileModel teacher,
    required TeacherFileInfo bilgi,
    required List<TeacherFileLesson> dersler,
    required List<TeacherFileClass> siniflar,
    required String yil,
  }) {
    switch (belge) {
      case TeacherFileDoc.kapak:
        pdf.addPage(_kapak(teacher, bilgi, yil));
      case TeacherFileDoc.ataturk:
        pdf.addPage(_ataturkKosesi());
      case TeacherFileDoc.istiklalMarsi:
        pdf.addPage(_istiklalMarsi());
      case TeacherFileDoc.gencligeHitabe:
        pdf.addPage(_gencligeHitabe());
      case TeacherFileDoc.kisiselBilgiler:
        pdf.addPage(_kisiselBilgiler(teacher, bilgi, yil));
      case TeacherFileDoc.dersProgrami:
        pdf.addPage(_dersProgrami(teacher, dersler, yil));
      case TeacherFileDoc.sinifListeleri:
        pdf.addPage(_sinifListeleri(teacher, siniflar, yil));
      case TeacherFileDoc.nobetCizelgesi:
        pdf.addPage(_nobetCizelgesi(teacher, yil));
      case TeacherFileDoc.zumreTutanagi:
        pdf.addPage(_zumreTutanagi(teacher, yil));
      case TeacherFileDoc.veliGorusme:
        pdf.addPage(_veliGorusme(teacher, yil));
      case TeacherFileDoc.yillikPlanKapagi:
        pdf.addPage(_yillikPlanKapagi(teacher, yil));
      case TeacherFileDoc.kanaatFormu:
        pdf.addPage(_kanaatFormu(teacher, yil));
      case TeacherFileDoc.odevTakip:
        pdf.addPage(_odevTakip(teacher, yil));
    }
  }

  // ==========================================================
  // ORTAK PARÇALAR
  // ==========================================================

  static const _kenar = pw.EdgeInsets.fromLTRB(32, 28, 32, 26);

  /// Sayfa genisliginde ortalanmis sutun.
  ///
  /// `pw.Column`a `crossAxisAlignment: center` vermek YETMIYOR:
  /// Column yalnizca en genis cocugu kadar yer kaplar, sayfa
  /// genisligine yayilmaz. Kapak ve Ataturk sayfasi bu yuzden sola
  /// yasli cikiyordu — uretilip bakilinca gorüldü.
  static pw.Widget _ortalanmis(List<pw.Widget> cocuklar) => pw.SizedBox(
        width: double.infinity,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: cocuklar,
        ),
      );

  /// Resmî künye — sınıf evraklarındaki düzenin aynısı.
  static pw.Widget _kunye({
    required String okul,
    required String baslik,
    required String yil,
    String? belgeKodu,
  }) {
    final o = okul.trim().isNotEmpty
        ? trUpper(okul.trim())
        : '................................................... OKULU MÜDÜRLÜĞÜ';

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(belgeKodu ?? '',
                style: const pw.TextStyle(fontSize: 7)),
            pw.Text('T.C.',
                style: pw.TextStyle(
                    fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 40),
          ],
        ),
        pw.Text('MİLLÎ EĞİTİM BAKANLIĞI',
            style:
                pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(
          o.endsWith('MÜDÜRLÜĞÜ') ? o : '$o MÜDÜRLÜĞÜ',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text('$yil EĞİTİM-ÖĞRETİM YILI',
            style: const pw.TextStyle(fontSize: 8.5)),
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
            baslik,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// İmza bloğu — İSİM BASILMAZ.
  ///
  /// BEP ve KDF'de aynı karar verilmişti: önceden basılmış bir ad,
  /// imzalayan değiştiğinde belgeyi yanlış kılıyor ve öğretmen
  /// PDF'i bastıktan sonra düzeltemiyor.
  static pw.Widget _imzalar(List<String> gorevler) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final g in gorevler)
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(g,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 26),
                pw.Container(
                  height: 0.5,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                  color: PdfColors.black,
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

  /// Etiket-değer satırı. Değer boşsa noktalı satır basılır ki
  /// öğretmen kalemle doldurabilsin.
  static pw.TableRow _satir(String etiket, String deger) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(etiket,
            style:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          deger.trim().isEmpty
              ? '..............................................'
              : deger.trim(),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
    ]);
  }

  /// Boş çizelge — verisi olmayan formlar için satır üretir.
  static pw.Widget _bosCizelge({
    required List<String> basliklar,
    required List<double> genislikler,
    required int satirSayisi,
    List<List<String>> dolu = const [],
  }) {
    assert(basliklar.length == genislikler.length);

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        for (var i = 0; i < genislikler.length; i++)
          i: pw.FlexColumnWidth(genislikler[i]),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            for (final b in basliklar)
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: pw.Text(b,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
          ],
        ),
        for (final satir in dolu)
          pw.TableRow(
            children: [
              for (final h in satir)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 5),
                  child: pw.Text(h,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
            ],
          ),
        for (var i = 0; i < satirSayisi; i++)
          pw.TableRow(
            children: [
              for (var j = 0; j < basliklar.length; j++)
                pw.Container(height: 19),
            ],
          ),
      ],
    );
  }

  // ==========================================================
  // 1. KAPAK
  // ==========================================================

  static pw.Page _kapak(
    TeacherProfileModel t,
    TeacherFileInfo bilgi,
    String yil,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => _ortalanmis([
          pw.SizedBox(height: 30),
          pw.Text('T.C.',
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text('MİLLÎ EĞİTİM BAKANLIĞI',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
            t.schoolName.trim().isEmpty
                ? '................................................'
                : trUpper(t.schoolName.trim()),
            textAlign: pw.TextAlign.center,
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 34),
          // Bayrak şeridi — kapağa resmî bir kimlik verir.
          pw.Container(
            width: 210,
            height: 3,
            color: const PdfColor.fromInt(0xFFE30A17),
          ),
          pw.SizedBox(height: 26),
          pw.Text(
            'ÖĞRETMEN DERS YILI DOSYASI',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 19,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('$yil EĞİTİM-ÖĞRETİM YILI',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 330,
            padding: const pw.EdgeInsets.symmetric(vertical: 14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  t.fullName.trim().isEmpty
                      ? '............................'
                      : trUpper(t.fullName),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  bilgi.title.trim().isNotEmpty
                      ? bilgi.title.trim()
                      : (t.branch.trim().isEmpty
                          ? 'Öğretmen'
                          : '${t.branch.trim()} Öğretmeni'),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          pw.Spacer(),
          // Kapak sözü.
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 0.5),
                bottom: pw.BorderSide(width: 0.5),
              ),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '"${TeacherFileTexts.ogretmenlereHitap}"',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 11, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  TeacherFileTexts.ogretmenlereHitapKunye,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  // ==========================================================
  // 2. ATATÜRK KÖŞESİ
  // ==========================================================

  static pw.Page _ataturkKosesi() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => _ortalanmis([
          pw.SizedBox(height: 16),
          // Çerçeveli portre alanı.
          pw.Container(
            width: 250,
            height: 320,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.4),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: _portreAlani(),
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text('GAZİ MUSTAFA KEMAL ATATÜRK',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 2),
          pw.Text('Türkiye Cumhuriyeti\'nin Kurucusu',
              style: const pw.TextStyle(fontSize: 9.5)),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
            child: pw.Column(
              children: [
                pw.Text(
                  '"${TeacherFileTexts.ogretmenlereHitap}"',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 12.5, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 7),
                pw.Text(TeacherFileTexts.ogretmenlereHitapKunye,
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
      ]),
    );
  }

  /// Portre alanı — öğretmenin fotoğrafı yapıştıracağı çerçeve.
  ///
  /// ## Neden çizim yok
  /// Önce vektörel bir silüet çizilmişti. Üretilip bakıldığında
  /// Atatürk'e hiç benzemiyordu; jenerik bir avatar gibi duruyordu.
  /// Resmî bir belgeye, hele Atatürk köşesine, benzemeyen bir çizim
  /// konamaz.
  ///
  /// Gerçek fotoğraf da gömülmedi: internetten indirilen bir
  /// fotoğrafın telif durumu belirsizdir ve uygulamaya gömülürse
  /// 30.000 öğretmene dağıtılmış olur.
  ///
  /// Kalan doğru seçenek bu: standart 10x15 oranında, köşeleri
  /// işaretli bir çerçeve. Öğretmen okulda zaten bulunan resmî
  /// portreyi bastırıp yapıştırır — okullarda yapılan da budur.
  static pw.Widget _portreAlani() {
    // Köşe işareti: fotoğrafın nereye hizalanacağını gösterir.
    pw.Widget kose({required bool sol, required bool ust}) => pw.Container(
          width: 16,
          height: 16,
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: ust
                  ? const pw.BorderSide(width: 0.8)
                  : pw.BorderSide.none,
              bottom: !ust
                  ? const pw.BorderSide(width: 0.8)
                  : pw.BorderSide.none,
              left: sol
                  ? const pw.BorderSide(width: 0.8)
                  : pw.BorderSide.none,
              right: !sol
                  ? const pw.BorderSide(width: 0.8)
                  : pw.BorderSide.none,
            ),
          ),
        );

    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Stack(
        children: [
          pw.Positioned(top: 0, left: 0, child: kose(sol: true, ust: true)),
          pw.Positioned(top: 0, right: 0, child: kose(sol: false, ust: true)),
          pw.Positioned(
              bottom: 0, left: 0, child: kose(sol: true, ust: false)),
          pw.Positioned(
              bottom: 0, right: 0, child: kose(sol: false, ust: false)),
          pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'ATATÜRK RESMİ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                    letterSpacing: 1.4,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  '10 x 15 cm',
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.grey500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 3. İSTİKLÂL MARŞI
  // ==========================================================

  static pw.Page _istiklalMarsi() {
    // On kıta tek sayfaya sığmalı: iki sütun, 7 punto.
    const kitalar = TeacherFileTexts.istiklalMarsi;
    final sol = kitalar.take(5).toList();
    final sag = kitalar.skip(5).toList();

    pw.Widget sutun(List<String> k, int baslangic) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < k.length; i++) ...[
              pw.Text(
                k[i],
                style: const pw.TextStyle(fontSize: 9.2, height: 1.5),
              ),
              if (i < k.length - 1) pw.SizedBox(height: 13),
            ],
          ],
        );

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          pw.Text('İSTİKLÂL MARŞI',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 4),
          pw.Container(width: 150, height: 1.2, color: PdfColors.black),
          pw.SizedBox(height: 14),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: sutun(sol, 1)),
                pw.SizedBox(width: 18),
                pw.Expanded(child: sutun(sag, 6)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.5)),
            ),
            child: pw.Text(
              TeacherFileTexts.istiklalMarsiKunye,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 4. GENÇLİĞE HİTABE
  // ==========================================================

  static pw.Page _gencligeHitabe() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          pw.Text('ATATÜRK\'ÜN GENÇLİĞE HİTABESİ',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8)),
          pw.SizedBox(height: 4),
          pw.Container(width: 190, height: 1.2, color: PdfColors.black),
          pw.SizedBox(height: 18),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final p in TeacherFileTexts.gencligeHitabe) ...[
                  pw.Text(
                    p,
                    textAlign: pw.TextAlign.justify,
                    style: const pw.TextStyle(fontSize: 11.5, height: 1.7),
                  ),
                  pw.SizedBox(height: 12),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.5)),
            ),
            child: pw.Text(
              TeacherFileTexts.gencligeHitabeKunye,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 9,
                  height: 1.4,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 5. KİŞİSEL BİLGİLER FORMU
  // ==========================================================

  static pw.Page _kisiselBilgiler(
    TeacherProfileModel t,
    TeacherFileInfo b,
    String yil,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'ÖĞRETMEN KİŞİSEL BİLGİ FORMU',
            yil: yil,
            belgeKodu: TeacherFileDoc.kisiselBilgiler.belgeKodu,
          ),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1.6),
            },
            children: [
              _satir('Adı ve Soyadı', t.fullName),
              _satir('T.C. Kimlik Numarası', b.nationalId),
              _satir('Sicil Numarası', b.registryNo),
              _satir('Branşı', t.branch),
              _satir('Unvanı / Görevi', b.title),
              _satir('Kadro Durumu', b.employmentType),
              _satir('Mezun Olduğu Okul / Bölüm', b.graduation),
              _satir('Göreve Başlama Tarihi', b.startedDutyAt),
              _satir('Bu Okulda Göreve Başlama', b.startedSchoolAt),
              _satir('Görev Yaptığı Okul', t.schoolName),
              _satir('Telefon', b.phone),
              _satir('E-posta', t.email),
              _satir('Kan Grubu', b.bloodType),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('AÇIKLAMALAR',
                    style: pw.TextStyle(
                        fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                for (var i = 0; i < 4; i++) ...[
                  pw.Container(height: 0.4, color: PdfColors.grey600),
                  pw.SizedBox(height: 13),
                ],
              ],
            ),
          ),
          pw.Spacer(),
          _imzalar(const ['Öğretmen', 'Okul Müdürü']),
        ],
      ),
    );
  }

  // ==========================================================
  // 6. HAFTALIK DERS PROGRAMI
  // ==========================================================

  static pw.Page _dersProgrami(
    TeacherProfileModel t,
    List<TeacherFileLesson> dersler,
    String yil,
  ) {
    const gunler = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
    ];

    // En geç ders saatine göre satır sayısı; hiç ders yoksa 8 satır
    // boş çizelge basılır ki öğretmen elle doldurabilsin.
    final enGec = dersler.isEmpty
        ? 0
        : dersler.map((d) => d.saat).reduce((a, b) => a > b ? a : b);
    final satirSayisi = enGec < 8 ? 8 : enGec + 1;

    String hucre(String gun, int saat) {
      final bulunan = dersler.where(
        (d) => _gunEsit(d.gun, gun) && d.saat == saat,
      );
      if (bulunan.isEmpty) return '';
      final d = bulunan.first;
      return d.sinif.trim().isEmpty
          ? d.ders
          : '${d.sinif}\n${d.ders}';
    }

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'HAFTALIK DERS PROGRAMI',
            yil: yil,
            belgeKodu: TeacherFileDoc.dersProgrami.belgeKodu,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Öğretmen: ${t.fullName}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                  t.branch.trim().isEmpty ? '' : 'Branş: ${t.branch}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(34),
              for (var i = 1; i <= gunler.length; i++)
                i: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text('SAAT',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  for (final g in gunler)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5),
                      child: pw.Text(trUpper(g),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                ],
              ),
              for (var saat = 0; saat < satirSayisi; saat++)
                pw.TableRow(
                  children: [
                    pw.Container(
                      height: 34,
                      alignment: pw.Alignment.center,
                      child: pw.Text('${saat + 1}',
                          style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                    for (final g in gunler)
                      pw.Container(
                        height: 34,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                        child: pw.Text(
                          hucre(g, saat),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7, height: 1.25),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 6),
          if (dersler.isEmpty)
            pw.Text(
              'Ders programı ekranından programınızı girdiğinizde bu '
              'çizelge dolu üretilir.',
              style: const pw.TextStyle(
                  fontSize: 7.5, color: PdfColors.grey700),
            ),
          pw.Spacer(),
          _imzalar(const ['Öğretmen', 'Okul Müdürü']),
        ],
      ),
    );
  }

  /// Gün adları eşleşmesi.
  ///
  /// Ders programı ekranı "Pazartesi" yazıyor ama eski kayıtlarda
  /// "PAZARTESİ" de olabilir. Türkçe büyük harf tuzağı yüzünden
  /// `toUpperCase` güvenilir değil (i → I), bu yüzden küçük harfe
  /// indirip karşılaştırılıyor.
  static bool _gunEsit(String a, String b) {
    String d(String s) => s
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase();
    return d(a) == d(b);
  }

  // ==========================================================
  // 7. SINIF LİSTELERİ
  // ==========================================================

  static pw.Page _sinifListeleri(
    TeacherProfileModel t,
    List<TeacherFileClass> siniflar,
    String yil,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'DERSE GİRİLEN SINIFLAR ÇİZELGESİ',
            yil: yil,
            belgeKodu: TeacherFileDoc.sinifListeleri.belgeKodu,
          ),
          _bosCizelge(
            basliklar: const [
              'S.NO',
              'SINIFI',
              'DERSİ',
              'ÖĞRENCİ SAYISI',
              'AÇIKLAMA',
            ],
            genislikler: const [0.5, 1, 1.8, 0.9, 1.4],
            dolu: [
              for (var i = 0; i < siniflar.length; i++)
                [
                  '${i + 1}',
                  siniflar[i].ad,
                  siniflar[i].ders,
                  siniflar[i].ogrenciSayisi > 0
                      ? '${siniflar[i].ogrenciSayisi}'
                      : '',
                  '',
                ],
            ],
            satirSayisi: siniflar.length >= 14 ? 2 : 14 - siniflar.length,
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Toplam: ${siniflar.length} sınıf · '
                '${siniflar.fold<int>(0, (a, s) => a + s.ogrenciSayisi)} öğrenci',
                style: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Spacer(),
          _imzalar(const ['Öğretmen', 'Okul Müdürü']),
        ],
      ),
    );
  }

  // ==========================================================
  // 8. NÖBET ÇİZELGESİ
  // ==========================================================

  static pw.Page _nobetCizelgesi(TeacherProfileModel t, String yil) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'ÖĞRETMEN NÖBET ÇİZELGESİ',
            yil: yil,
            belgeKodu: TeacherFileDoc.nobetCizelgesi.belgeKodu,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Nöbetçi Öğretmen: ${t.fullName}',
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ),
          _bosCizelge(
            basliklar: const [
              'GÜN',
              'NÖBET YERİ',
              'BAŞLAMA SAATİ',
              'BİTİŞ SAATİ',
              'İMZA',
            ],
            genislikler: const [1, 1.6, 1, 1, 1],
            dolu: const [
              ['Pazartesi', '', '', '', ''],
              ['Salı', '', '', '', ''],
              ['Çarşamba', '', '', '', ''],
              ['Perşembe', '', '', '', ''],
              ['Cuma', '', '', '', ''],
            ],
            satirSayisi: 0,
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('NÖBET GÖREVİNE İLİŞKİN NOTLAR',
                    style: pw.TextStyle(
                        fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                for (var i = 0; i < 5; i++) ...[
                  pw.Container(height: 0.4, color: PdfColors.grey600),
                  pw.SizedBox(height: 13),
                ],
              ],
            ),
          ),
          pw.Spacer(),
          _imzalar(const ['Nöbetçi Öğretmen', 'Müdür Yardımcısı', 'Okul Müdürü']),
        ],
      ),
    );
  }

  // ==========================================================
  // 9. ZÜMRE TOPLANTI TUTANAĞI
  // ==========================================================

  static pw.Page _zumreTutanagi(TeacherProfileModel t, String yil) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'ZÜMRE ÖĞRETMENLER KURULU TOPLANTI TUTANAĞI',
            yil: yil,
            belgeKodu: TeacherFileDoc.zumreTutanagi.belgeKodu,
          ),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1.6),
            },
            children: [
              _satir('Toplantı No', ''),
              _satir('Toplantı Tarihi', ''),
              _satir('Toplantı Saati', ''),
              _satir('Toplantı Yeri', ''),
              _satir('Zümre / Branş', t.branch),
              _satir('Katılan Öğretmenler', ''),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('GÜNDEM MADDELERİ',
                style: pw.TextStyle(
                    fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 6),
          // Yönetmelikte sayılan olağan gündem maddeleri; öğretmen
          // silmek yerine üzerine yazar.
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final m in const [
                  'Açılış ve yoklama',
                  'Bir önceki toplantı kararlarının değerlendirilmesi',
                  'Mevzuatın ve öğretim programlarının incelenmesi',
                  'Yıllık planların görüşülmesi',
                  'Ölçme ve değerlendirme esaslarının belirlenmesi',
                  'Öğrenci başarısının artırılmasına yönelik tedbirler',
                  'Ders araç gereçlerinin kullanımı',
                  'Dilek ve temenniler',
                ])
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text('•  $m',
                        style: const pw.TextStyle(fontSize: 8.5)),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('ALINAN KARARLAR',
                style: pw.TextStyle(
                    fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 5),
          pw.Expanded(
            child: pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                children: [
                  for (var i = 0; i < 9; i++) ...[
                    pw.Container(height: 0.4, color: PdfColors.grey600),
                    pw.SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          _imzalar(const ['Zümre Başkanı', 'Üye', 'Okul Müdürü']),
        ],
      ),
    );
  }

  // ==========================================================
  // 10. VELİ GÖRÜŞME KAYIT FORMU
  // ==========================================================

  static pw.Page _veliGorusme(TeacherProfileModel t, String yil) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'VELİ GÖRÜŞME KAYIT FORMU',
            yil: yil,
            belgeKodu: TeacherFileDoc.veliGorusme.belgeKodu,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Öğretmen: ${t.fullName}',
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ),
          _bosCizelge(
            basliklar: const [
              'S.NO',
              'TARİH',
              'ÖĞRENCİ',
              'VELİ ADI',
              'GÖRÜŞME KONUSU',
              'SONUÇ / KARAR',
              'İMZA',
            ],
            genislikler: const [0.45, 0.8, 1.1, 1.1, 1.7, 1.7, 0.7],
            dolu: [
              for (var i = 0; i < 16; i++) ['${i + 1}', '', '', '', '', '', ''],
            ],
            satirSayisi: 0,
          ),
          pw.Spacer(),
          _imzalar(const ['Öğretmen', 'Okul Müdürü']),
        ],
      ),
    );
  }

  // ==========================================================
  // 11. YILLIK PLAN KAPAĞI
  // ==========================================================

  static pw.Page _yillikPlanKapagi(TeacherProfileModel t, String yil) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => _ortalanmis([
          pw.SizedBox(height: 24),
          pw.Text('T.C.',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text('MİLLÎ EĞİTİM BAKANLIĞI',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(
            t.schoolName.trim().isEmpty
                ? '................................................'
                : trUpper(t.schoolName.trim()),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 40),
          pw.Text(
            'ÜNİTELENDİRİLMİŞ YILLIK DERS PLANI',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('$yil EĞİTİM-ÖĞRETİM YILI',
              style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 360,
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1.4),
              },
              children: [
                _satir('Dersin Adı', ''),
                _satir('Sınıf / Şube', ''),
                _satir('Haftalık Ders Saati', ''),
                _satir('Öğretmenin Adı Soyadı', t.fullName),
                _satir('Branşı', t.branch),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: pw.Column(
              children: [
                pw.Text('UYGUNDUR',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text('..... / ..... / 20.....',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 20),
                pw.Text('Okul Müdürü',
                    style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 18),
                pw.Container(width: 130, height: 0.5, color: PdfColors.black),
                pw.SizedBox(height: 2),
                pw.Text('Adı Soyadı / İmza',
                    style: const pw.TextStyle(fontSize: 6.6)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
      ]),
    );
  }

  // ==========================================================
  // 12. ÖĞRENCİ GELİŞİM VE KANAAT FORMU
  // ==========================================================

  static pw.Page _kanaatFormu(TeacherProfileModel t, String yil) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(26, 22, 26, 22),
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'ÖĞRENCİ GELİŞİM VE KANAAT FORMU',
            yil: yil,
            belgeKodu: TeacherFileDoc.kanaatFormu.belgeKodu,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Sınıf: ......................',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Ders: ......................',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Dönem: ......................',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          _bosCizelge(
            basliklar: const [
              'S.NO',
              'OKUL NO',
              'ADI SOYADI',
              'DERSE HAZIRLIK',
              'KATILIM',
              'ÖDEV',
              'DAVRANIŞ',
              'KANAAT VE ÖNERİLER',
            ],
            genislikler: const [0.4, 0.6, 1.7, 0.9, 0.7, 0.6, 0.8, 2.4],
            dolu: [
              for (var i = 0; i < 18; i++)
                ['${i + 1}', '', '', '', '', '', '', ''],
            ],
            satirSayisi: 0,
          ),
          pw.Spacer(),
          _imzalar(const ['Ders Öğretmeni', 'Okul Müdürü']),
        ],
      ),
    );
  }

  // ==========================================================
  // 13. ÖDEV TAKİP ÇİZELGESİ
  // ==========================================================

  static pw.Page _odevTakip(TeacherProfileModel t, String yil) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _kenar,
      build: (ctx) => pw.Column(
        children: [
          _kunye(
            okul: t.schoolName,
            baslik: 'ÖDEV TAKİP ÇİZELGESİ',
            yil: yil,
            belgeKodu: TeacherFileDoc.odevTakip.belgeKodu,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Öğretmen: ${t.fullName}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Sınıf: ......................',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          _bosCizelge(
            basliklar: const [
              'S.NO',
              'VERİLİŞ TARİHİ',
              'ÖDEVİN KONUSU',
              'TESLİM TARİHİ',
              'TESLİM EDEN',
              'DEĞERLENDİRME',
            ],
            genislikler: const [0.45, 1, 2.2, 1, 0.9, 1.2],
            dolu: [
              for (var i = 0; i < 16; i++) ['${i + 1}', '', '', '', '', ''],
            ],
            satirSayisi: 0,
          ),
          pw.Spacer(),
          _imzalar(const ['Öğretmen', 'Okul Müdürü']),
        ],
      ),
    );
  }
}

/// Ders programı satırı — PDF üreticisine geçen sade veri.
///
/// `LessonModel` Flutter `Color` taşıyor; PDF katmanının ona
/// ihtiyacı yok ve test yazarken Flutter bağımlılığı getiriyordu.
class TeacherFileLesson {
  final String ders;
  final String sinif;
  final String gun;

  /// Kaçıncı ders saati — sıfırdan başlar.
  final int saat;

  const TeacherFileLesson({
    required this.ders,
    required this.sinif,
    required this.gun,
    required this.saat,
  });
}

/// Sınıf listesi satırı.
class TeacherFileClass {
  final String ad;
  final String ders;
  final int ogrenciSayisi;

  const TeacherFileClass({
    required this.ad,
    required this.ders,
    this.ogrenciSayisi = 0,
  });
}
