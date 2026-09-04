import 'package:flutter/foundation.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/name_formatter.dart';
import '../data/special_days_repository.dart';
import 'pano_layout_builder.dart';
import 'pano_layouts.dart';

/// Belirli gün ve haftalar için üç belge.
///
/// * [etkinlikPlani] — tören senaryosu: sunucu cümleleri, konuşma, şiir.
///   Kürsüde bu kâğıda bakılarak program yürür. Sınıf etkinliği ve
///   pano sloganı bu belgede yoktur.
/// * [kutlamaRaporu] — öğretmenin doldurup müdüre verdiği çalışma özeti
/// * [panoCalismasi] — panoya asılacak başlık ve öğrenci alanı
class SpecialDayPdfGenerator {
  SpecialDayPdfGenerator._();

  static const _baslikDolgu = PdfColor.fromInt(0xFFD9D9D9);
  static const _altDolgu = PdfColor.fromInt(0xFFF2F2F2);

  // ------------------------------------------------------------ plan

  /// Kürsüde okunan tören senaryosu.
  ///
  /// Öğrenci ve sunucu bu kâğıda bakarak programı yürütür. Sınıf
  /// etkinliği ve pano sloganı buraya konmaz; onlar ekranda ve pano
  /// PDF’indedir.
  static Future<Uint8List> etkinlikPlani({
    required SpecialDay gun,
    required PanoContent? icerik,
    required String schoolName,
    required String className,
    required String teacherName,
    required String academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();

    if (icerik != null && icerik.program.isNotEmpty) {
      _programIlani(
        pdf,
        gun: gun,
        icerik: icerik,
        schoolName: schoolName,
        className: className,
        teacherName: teacherName,
        academicYear: academicYear,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 64, 50, 42),
        header: (_) => _ustBilgi(
          schoolName: schoolName,
          academicYear: academicYear,
          baslik: '${trUpper(gun.ad)} ETKİNLİK PLANI',
        ),
        footer: _altBilgi,
        build: (_) => [
          _kunye({
            'Sınıf/Şube': className,
            'Uygulama Tarihi': gun.tarihMetni,
            'Hazırlayan': teacherName,
          }),
          pw.SizedBox(height: 8),
          pw.Text(
            'Taslak programdır. Boş adlar uygulama öncesi doldurulur; sıra '
            'okuluna göre değiştirilir. MEB resmî evrakı değildir.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          if (icerik != null && icerik.ozet.trim().isNotEmpty) ...[
            _bolumBasligi('GÜNÜN ANLAM VE ÖNEMİ'),
            pw.Paragraph(
              text: icerik.ozet,
              style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.8),
            ),
            pw.SizedBox(height: 4),
          ],
          _bolumBasligi('PROGRAM AKIŞI'),
          ..._senaryo(gun, icerik),
          pw.SizedBox(height: 12),
          _imzaSatiri(teacherName, 'Sınıf Öğretmeni'),
        ],
      ),
    );
    return PdfTrFonts.kaydet(pdf);
  }

  /// Sunucu cümleleri + konuşma/şiir metinleri, program sırasıyla.
  static List<pw.Widget> _senaryo(SpecialDay gun, PanoContent? icerik) {
    final cikti = <pw.Widget>[
      _sunucu(
        'Sayın müdürüm, değerli öğretmenlerim, sevgili arkadaşlar. '
        '${gun.ad} nedeniyle düzenlenen programımıza hoş geldiniz.',
      ),
    ];

    final program = icerik?.program ?? const <String>[];
    if (program.isEmpty) {
      cikti.addAll([
        _madde(1, 'Saygı duruşu ve İstiklâl Marşı'),
        _sunucu(
          'Şimdi sizleri bir dakikalık saygı duruşuna ve İstiklâl '
          'Marşı’nı okumaya davet ediyorum.',
        ),
        _madde(2, 'Günün anlamını belirten konuşma'),
        _sunucu(
          'Konuşmasını yapmak üzere ………………’yi kürsüye davet ediyorum.',
        ),
        _madde(3, 'Şiir / dinleti'),
        _sunucu('……………… adlı şiiri okumak üzere ………………’yi davet ediyorum.'),
        _madde(4, 'Kapanış'),
        _sunucu('Programımız sona ermiştir. Katıldığınız için teşekkür ederiz.'),
      ]);
      return cikti;
    }

    var mudurYazildi = false;
    var konusmaYazildi = false;
    var siirYazildi = false;
    final oyunlar = icerik?.oyunlar ?? const <PanoGame>[];

    PanoGame? oyunuBul(String madde) {
      final t = madde.toLowerCase();
      for (final o in oyunlar) {
        if (o.ad.trim().isEmpty) continue;
        if (t == o.ad.toLowerCase() || t.contains(o.ad.toLowerCase())) {
          return o;
        }
      }
      return null;
    }

    for (var i = 0; i < program.length; i++) {
      final madde = program[i];
      final t = madde.toLowerCase();
      cikti.add(_madde(i + 1, madde));

      final oyun = oyunuBul(madde);
      if (oyun != null) {
        if (oyun.sunucu.trim().isNotEmpty) {
          cikti.add(_sunucu(oyun.sunucu));
        }
        if (oyun.malzeme.trim().isNotEmpty) {
          cikti.add(pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
            child: pw.Text(
              'Malzeme: ${oyun.malzeme}',
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
            ),
          ));
        }
        if (oyun.yonerge.trim().isNotEmpty) {
          cikti.add(_metinBlok('Oynanış', oyun.yonerge));
        }
        continue;
      }

      if (t.contains('saygı') ||
          t.contains('marş') ||
          t.contains('istiklâl') ||
          t.contains('istiklal')) {
        cikti.add(_sunucu(
          'Şimdi sizleri bir dakikalık saygı duruşuna ve İstiklâl '
          'Marşı’nı okumaya davet ediyorum.',
        ));
        continue;
      }

      if (t.contains('müdür') &&
          icerik != null &&
          icerik.mudurKonusmasi.trim().isNotEmpty &&
          !mudurYazildi) {
        mudurYazildi = true;
        cikti.add(_sunucu(
          'Günün anlam ve önemini belirtmek üzere okul müdürümüzü '
          'kürsüye davet ediyorum.',
        ));
        // Ton havuzu varsa resmî ton plana girer; tören evrakı
        // resmî bir metin bekler. Diğer tonlar uygulamada seçilir.
        final resmi = icerik.mudurKonusmalari
            .where((k) => k.ton == 'resmî')
            .firstOrNull;
        cikti.add(_metinBlok(
          'Konuşma',
          resmi?.metin ?? icerik.mudurKonusmasi,
        ));
        if (icerik.mudurKonusmalari.length > 1) {
          cikti.add(_secenekNotu(
            icerik.mudurKonusmalari.length,
            'konuşma tonu',
          ));
        }
        continue;
      }

      if (t.contains('öğrenci') &&
          t.contains('konuş') &&
          icerik != null &&
          icerik.konusmalar.isNotEmpty &&
          !konusmaYazildi) {
        konusmaYazildi = true;
        cikti.add(_sunucu(
          'Öğrenci konuşmasını yapmak üzere ……………… sınıfından '
          '………………’yi kürsüye davet ediyorum.',
        ));
        // Havuzda birden çok düzey varsa (1-2 / 3-4 / 5-8) hepsi
        // basılmaz; plan bir senaryodur, seçenek listesi değil.
        // Ortadaki düzey varsayılan, yoksa ilk metin kullanılır.
        final secili = _duzeyeGore(icerik.konusmalar);
        cikti.add(_metinBlok(secili.baslik, secili.metin));
        if (icerik.konusmalar.length > 1) {
          cikti.add(_secenekNotu(
            icerik.konusmalar.length,
            'öğrenci konuşması',
          ));
        }
        continue;
      }

      if (t.contains('şiir') &&
          icerik != null &&
          icerik.siirler.isNotEmpty &&
          !siirYazildi) {
        siirYazildi = true;
        final siir = _duzeyeGoreSiir(icerik.siirler);
        final ad = siir.baslik.trim().isEmpty ? 'şiir' : siir.baslik;
        cikti.add(_sunucu(
          '$ad için ………………’yi kürsüye davet ediyorum.',
        ));
        cikti.add(_metinBlok(siir.baslik, siir.metin));
        if (icerik.siirler.length > 1) {
          cikti.add(_secenekNotu(icerik.siirler.length, 'şiir'));
        }
        continue;
      }

      if (t.contains('kapanış') || t.contains('kapanis')) {
        cikti.add(_sunucu(
          'Programımız sona ermiştir. Katıldığınız için teşekkür ederiz.',
        ));
        continue;
      }

      if (t.contains('meclis') || t.contains('başkan')) {
        cikti.add(_sunucu(
          'Sınıf meclisinin kararını okumak üzere ………………’yi '
          'kürsüye davet ediyorum.',
        ));
        continue;
      }

      if (t.contains('pano') ||
          t.contains('sözleşme') ||
          t.contains('tanıtım')) {
        cikti.add(_sunucu('Hazırlanan çalışma kısaca tanıtılır.'));
        continue;
      }

      cikti.add(_sunucu(
        'Bu maddeyi yürütmek üzere ………………’yi davet ediyorum.',
      ));
    }

    if (icerik != null &&
        icerik.mudurKonusmasi.trim().isNotEmpty &&
        !mudurYazildi) {
      cikti.add(_metinBlok('Müdür konuşması', icerik.mudurKonusmasi));
    }
    if (icerik != null && icerik.konusmalar.isNotEmpty && !konusmaYazildi) {
      for (final k in icerik.konusmalar) {
        cikti.add(_metinBlok(k.baslik, k.metin));
      }
    }
    if (icerik != null && icerik.siirler.isNotEmpty && !siirYazildi) {
      for (final s in icerik.siirler) {
        cikti.add(_metinBlok(s.baslik, s.metin));
      }
    }

    return cikti;
  }

  /// Havuzdan tören planına girecek öğrenci konuşması.
  ///
  /// Düzey etiketi taşıyanlar arasından ortadaki ('3-4') seçilir: plan
  /// çoğu okulda ilkokul-ortaokul karışık bir törende okunuyor, uçtaki
  /// düzeyler ya çok basit ya çok ağır kalıyordu. Etiket yoksa ilk
  /// metin kullanılır (eski kayıtlar böyle).
  static PanoSpeech _duzeyeGore(List<PanoSpeech> havuz) {
    for (final k in havuz) {
      if (k.duzey == '3-4') return k;
    }
    for (final k in havuz) {
      if (k.duzey == 'hepsi') return k;
    }
    return havuz.first;
  }

  /// Havuzdan tören planına girecek şiir — [_duzeyeGore] ile aynı ölçüt.
  static PanoPoem _duzeyeGoreSiir(List<PanoPoem> havuz) {
    for (final s in havuz) {
      if (s.duzey == '3-4') return s;
    }
    for (final s in havuz) {
      if (s.duzey == 'hepsi') return s;
    }
    return havuz.first;
  }

  /// "Havuzda başka seçenek var" notu.
  ///
  /// Plana tek metin basılıyor; öğretmen diğerlerinin var olduğunu
  /// bilmezse havuzu hiç açmaz.
  static pw.Widget _secenekNotu(int adet, String tur) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 10, bottom: 6),
      child: pw.Text(
        'Uygulamada ${adet - 1} farklı $tur seçeneği daha var; '
        'sınıf düzeyine uygun olanı uygulamadan seçebilirsiniz.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _madde(int no, String baslik) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 7, bottom: 2),
      child: pw.Text(
        '$no. $baslik',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _sunucu(String metin) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
      child: pw.Text(
        'Sunucu: $metin',
        style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.6),
      ),
    );
  }

  static pw.Widget _metinBlok(String baslik, String metin) {
    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(10, 2, 0, 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (baslik.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                baslik,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          pw.Text(
            metin,
            style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.8),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- rapor

  /// Yapılan çalışmanın müdür onaylı raporu.
  ///
  /// ## Neden boş satırlar var
  /// Rapor tören sonrası doldurulur; öğretmen katılımcı sayısını ve
  /// gözlemlerini elle yazar. Uygulamanın bilmediği bilgiyi uydurmak
  /// yerine imzalı belgede boş satır bırakılır.
  static Future<Uint8List> kutlamaRaporu({
    required SpecialDay gun,
    required PanoContent? icerik,
    required String schoolName,
    required String className,
    required String teacherName,
    required String academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 64, 50, 42),
        header: (_) => _ustBilgi(
          schoolName: schoolName,
          academicYear: academicYear,
          baslik: '${trUpper(gun.ad)} ÇALIŞMA RAPORU',
        ),
        footer: (ctx) => _imzaliAlt(ctx, _onayBloku(teacherName), yukseklik: 92),
        build: (_) => [
          _kunye({
            'Sınıf/Şube': className,
            'Tarih': gun.tarihMetni,
            'Raporu Düzenleyen': teacherName,
          }),
          pw.SizedBox(height: 8),
          pw.Text(
            'Uygulama sonrası doldurulur. Boş satırlara okuluna göre ekleme '
            'yapınız. MEB resmî evrakı değildir.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),

          _bolumBasligi('1. UYGULANAN PROGRAM'),
          _tablo(
            ['Sıra', 'Madde', 'Açıklama (elle doldurulur)'],
            [
              if (icerik != null && icerik.program.isNotEmpty)
                for (var i = 0; i < icerik.program.length; i++)
                  ['${i + 1}', icerik.program[i], '']
              else
                for (var i = 1; i <= 4; i++) ['$i', '', ''],
              ['', '', ''],
              ['', '', ''],
            ],
            const {
              0: pw.FlexColumnWidth(0.5),
              1: pw.FlexColumnWidth(2.4),
              2: pw.FlexColumnWidth(3.6),
            },
          ),

          pw.SizedBox(height: 8),
          _bolumBasligi('2. KATILIM'),
          _tablo(
            ['Öğrenci Sayısı', 'Katılan Öğrenci', 'Katılan Veli'],
            [
              ['', '', ''],
            ],
            const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
            },
          ),

          pw.SizedBox(height: 8),
          _bolumBasligi('3. DEĞERLENDİRME VE GÖZLEMLER'),
          _bosSatirlar(3),
        ],
      ),
    );
    return PdfTrFonts.kaydet(pdf);
  }

  /// Panoya ve kürsüye asılan tek sayfalık program ilanı.
  /// Saat ve görevli boş bırakılır; öğretmen doldurur.
  static void _programIlani(
    pw.Document pdf, {
    required SpecialDay gun,
    required PanoContent icerik,
    required String schoolName,
    required String className,
    required String teacherName,
    required String academicYear,
  }) {
    final satirlar = <List<String>>[
      for (var i = 0; i < icerik.program.length; i++)
        ['${i + 1}', '', icerik.program[i], ''],
    ];
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              schoolName.trim().isEmpty
                  ? '.................................. OKULU'
                  : trUpper(schoolName),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _lacivert,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '$academicYear EĞİTİM ÖĞRETİM YILI',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: _lacivert),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              color: _lacivert,
              padding: const pw.EdgeInsets.symmetric(vertical: 7),
              child: pw.Text(
                '${trUpper(gun.ad)}\nKUTLAMA PROGRAMI AKIŞI',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  lineSpacing: 2,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            _kunye({
              'Sınıf/Şube': className,
              'Tarih': gun.tarihMetni,
              'Saat': '',
              'Hazırlayan': teacherName,
            }),
            pw.SizedBox(height: 10),
            _tablo(
              ['Sıra', 'Saat', 'Etkinlik', 'Görevli'],
              satirlar,
              const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(1.1),
                2: pw.FlexColumnWidth(3.4),
                3: pw.FlexColumnWidth(1.8),
              },
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Saat ve görevli sütunları uygulama öncesi doldurulur. '
              'MEB resmî evrakı değildir.',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
            pw.Spacer(),
            _onayBloku(teacherName),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- pano

  static const _bayrakKirmizi = PdfColor.fromInt(0xFFDC2626);
  static const _bordo = PdfColor.fromInt(0xFF7F1D1D);
  static const _altin = PdfColor.fromInt(0xFFF59E0B);
  static const _lacivert = PdfColor.fromInt(0xFF1E3A5F);

  /// Seçilen kurguya göre pano üretir.
  ///
  /// Öğretmen [PanoKurgular.uygunOlanlar] listesinden bir kurgu seçer;
  /// bu metot yalnızca o kurgunun sayfalarını basar. Tek düzen dayatmak
  /// yerine seçenek sunmanın karşılığı budur.
  ///
  /// Kurgu belirtilmezse [panoCalismasi] çağrılır (eski davranış).
  static Future<Uint8List> panoKurgusu({
    required PanoKurgu kurgu,
    required SpecialDay gun,
    required PanoContent? icerik,
    required String schoolName,
    required String academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();
    PanoLayoutBuilder.ciz(
      pdf,
      kurgu: kurgu,
      gun: gun,
      icerik: icerik,
      schoolName: schoolName,
      academicYear: academicYear,
    );
    return PdfTrFonts.kaydet(pdf);
  }

  /// Pano: sade 3 sayfa veya (vecize + öğrenci görevi varsa) 4 sayfalık
  /// kes-yapıştır paket.
  static Future<Uint8List> panoCalismasi({
    required SpecialDay gun,
    required PanoContent? icerik,
    required String schoolName,
    required String className,
    required String teacherName,
    required String academicYear,
  }) async {
    final pdf = await PdfTrFonts.document();
    final baslik = (icerik?.panoBaslik.trim().isNotEmpty == true)
        ? icerik!.panoBaslik
        : gun.ad;
    final kartlar = _panoKartlar(gun, icerik);

    // Panoda okul adı durur, ŞUBE ve ÖĞRETMEN ADI durmaz.
    //
    // Etkinlik planı ve çalışma raporu resmî evraktır — şube ve hazırlayan
    // adı oraya girer. Pano ise koridorda duran görsel bir çalışmadır:
    // üzerinde "4-A Sınıfı" yazarsa o pano tek bir şubenin malı olur ve
    // aynı okuldaki başka öğretmen aynı çıktıyı asamaz. Okul adı ise
    // panoyu okula ait kılar, kimseyi dışarıda bırakmaz.
    //
    // Öğrenci adı yine de yazılır — basılı olarak değil, öğrencinin kendi
    // el yazısıyla doldurduğu boş satır olarak (bkz. _ogrenciAlani).
    final dip = [
      if (schoolName.trim().isNotEmpty) schoolName,
      academicYear,
    ].where((e) => e.trim().isNotEmpty).join('  ·  ');

    if (icerik != null && icerik.zenginPano) {
      _panoZengin(
        pdf,
        gun: gun,
        icerik: icerik,
        baslik: baslik,
        dip: dip,
      );
      return PdfTrFonts.kaydet(pdf);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          children: [
            pw.Expanded(
              child: pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    width: 3,
                    color: const PdfColor.fromInt(0xFF1E3A5F),
                  ),
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 18),
                      child: pw.Text(
                        trUpper(baslik),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          lineSpacing: 4,
                          color: const PdfColor.fromInt(0xFF1E3A5F),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      gun.tarihMetni,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (dip.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text(dip, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '1 / 3  ·  Panonun üst başlığı — kesip asınız.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(22),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'GÜNÜ ANLATAN KARELER  —  kesip panoya asınız',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.Column(
                children: [
                  for (var s = 0; s < 2; s++)
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          for (var c = 0; c < 2; c++)
                            pw.Expanded(
                              child: _kesilebilirKare(kartlar, s * 2 + c),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              // Pano duvara asılır; kaynak uyarısı ekranda gösterilir,
              // panonun üzerinde yer kaplamasının anlamı yok.
              '2 / 3  ·  Kesik çizgiden kesin.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(22),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              color: const PdfColor.fromInt(0xFF1E3A5F),
              child: pw.Text(
                'ÖĞRENCİ ÇALIŞMALARI',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${trUpper(baslik)}  ·  $dip',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Expanded(child: _ogrenciAlani('1')),
                  pw.SizedBox(height: 10),
                  pw.Expanded(child: _ogrenciAlani('2')),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '3 / 3  ·  Öğrenci ürünü bu karelerin içine yapıştırılır.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  /// Bayram panosu: yatay afiş, 2x2 kesme kartı, siyah-beyaz öğrenci formu.
  static void _panoZengin(
    pw.Document pdf, {
    required SpecialDay gun,
    required PanoContent icerik,
    required String baslik,
    required String dip,
  }) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        build: (_) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 2.4, color: _altin),
          ),
          padding: const pw.EdgeInsets.all(5),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.1, color: _altin),
            ),
            child: pw.Column(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(
                    width: double.infinity,
                    color: _bordo,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          // Afişin tepesinde yalnızca okul adı durur;
                          // öğretim yılı afişi tarihe kilitlemesin diye
                          // üst banda alınmaz.
                          dip.trim().isEmpty
                              ? 'OKUL PANOSU'
                              : trUpper(dip.split('  ·  ').first),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromInt(0xFFFDE68A),
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          trUpper(baslik),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            lineSpacing: 3,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          gun.tarihMetni,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    width: double.infinity,
                    color: _bayrakKirmizi,
                    padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 10),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(width: 1, color: _altin),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                icerik.vecize,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 11,
                                  lineSpacing: 2.5,
                                  color: PdfColors.white,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                icerik.vecizeKaynak.trim().isEmpty
                                    ? ''
                                    : '— ${icerik.vecizeKaynak}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _altin,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(
                    '1 / 3  ·  Yatay afiş — panonun üstüne asınız.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final paragraflar = icerik.panoParagraflar.isNotEmpty
        ? icerik.panoParagraflar
        : [icerik.ozet];
    final dortluk = List<PanoPoem>.from(icerik.panoDortlukler);
    if (dortluk.isEmpty) dortluk.addAll(icerik.siirler.take(2));
    final bilgi = icerik.biliyorMuydunuz.isNotEmpty
        ? icerik.biliyorMuydunuz
        : icerik.sloganlar.take(3).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Column(
          children: [
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: _panoIcerikKart(
                      'Günün tarihçesi ve önemi',
                      [
                        for (final p in paragraflar.take(2))
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text(
                              p,
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                lineSpacing: 1.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: _panoIcerikKart(
                      'Kronoloji',
                      [
                        for (final k in icerik.kronoloji.take(3))
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text(
                              '• ${k.baslik}: ${k.metin}',
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                lineSpacing: 1.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: _panoIcerikKart(
                      'Dörtlükler',
                      [
                        for (final s in dortluk.take(2)) ...[
                          pw.Text(
                            s.baslik,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _bayrakKirmizi,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            s.metin,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              lineSpacing: 1.6,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: _panoIcerikKart(
                      'Biliyor muydunuz?',
                      [
                        for (final b in bilgi.take(3))
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text(
                              '• $b',
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                lineSpacing: 1.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '2 / 3  ·  Kesikli çizgiden kesin, raptiyeleyin.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Column(
          children: [
            pw.Text(
              'ÖĞRENCİ KARTLARI  ·  fotokopiye uygun',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              icerik.ogrenciGoreviYonerge,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 6),
            pw.Expanded(
              child: pw.Column(
                children: [
                  for (var s = 0; s < 2; s++)
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          for (var c = 0; c < 2; c++)
                            pw.Expanded(child: _dilekKarti(icerik)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '3 / 3  ·  Siyah-beyaz çoğaltın, kestirin, doldurtun.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _panoIcerikKart(String baslik, List<pw.Widget> govde) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          width: 1.1,
          color: const PdfColor.fromInt(0xFF94A3B8),
          style: pw.BorderStyle.dashed,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: _bayrakKirmizi,
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    baslik,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.Text(
                  'KES',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: govde,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _dilekKarti(PanoContent icerik) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          width: 1,
          color: PdfColors.black,
          style: pw.BorderStyle.dashed,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  icerik.ogrenciGoreviBaslik,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text('KES',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('Düşüncem / dileğim:',
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
          for (var i = 0; i < 4; i++)
            pw.Container(
              height: 12,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    width: 0.5,
                    color: PdfColors.grey600,
                    style: pw.BorderStyle.dotted,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.7, color: PdfColors.black),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  'Burayı sen çiz',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Adı: ..............  Sınıf: ......  No: ......',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  static List<PanoCard> _panoKartlar(SpecialDay gun, PanoContent? icerik) {
    if (icerik != null && icerik.panoKartlar.isNotEmpty) {
      return icerik.panoKartlar;
    }
    final kartlar = <PanoCard>[
      PanoCard(
        baslik: 'Günün anlamı',
        metin: (icerik?.ozet.trim().isNotEmpty == true)
            ? icerik!.ozet
            : '${gun.ad} okulda anılır ve çalışılır.',
      ),
    ];
    for (final s in icerik?.sloganlar ?? const <String>[]) {
      if (kartlar.length >= 4) break;
      kartlar.add(PanoCard(baslik: 'Pano başlığı', metin: s));
    }
    while (kartlar.length < 4) {
      kartlar.add(const PanoCard(
        baslik: 'Sınıfta',
        metin: 'Bu kareye sınıfın kendi cümlesini yazabilirsiniz.',
      ));
    }
    return kartlar.take(4).toList();
  }

  static pw.Widget _kesilebilirKare(List<PanoCard> kartlar, int i) {
    final k = i < kartlar.length ? kartlar[i] : null;
    return pw.Container(
      margin: const pw.EdgeInsets.all(5),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          width: 0.8,
          color: PdfColors.blueGrey500,
          style: pw.BorderStyle.dashed,
        ),
      ),
      child: k == null
          ? pw.SizedBox()
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  k.baslik,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1E3A5F),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  k.metin,
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                ),
              ],
            ),
    );
  }

  /// Öğrenci ürününün yapıştırılacağı çerçeve.
  ///
  /// Alt kısımda ad-soyad ve sınıf için BOŞ satır bulunur: şube panoya
  /// basılmaz, öğrenci kendi el yazısıyla doldurur. Böylece aynı çıktıyı
  /// her şube kullanabilir.
  static pw.Widget _ogrenciAlani(String no) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1.2, color: PdfColors.blueGrey600),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              'Öğrenci çalışması $no',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(child: pw.SizedBox()),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 7),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 0.6, color: PdfColors.blueGrey300),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Adı Soyadı: ……………………………………………',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Sınıfı: ………………',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ ortak parça

  static pw.Widget _ustBilgi({
    required String schoolName,
    required String academicYear,
    required String baslik,
  }) {
    return pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      child: pw.Column(
        children: [
          pw.Text(
            schoolName.trim().isEmpty
                ? '.................................. OKULU'
                : trUpper(schoolName),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text('$academicYear EĞİTİM ÖĞRETİM YILI',
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 3),
          pw.Text(
            baslik,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
    );
  }

  static pw.Widget _altBilgi(pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      );

  /// İmza son sayfanın dip kısmında durur; boş bir sayfa açılmaz.
  static pw.Widget _imzaliAlt(
    pw.Context ctx,
    pw.Widget imza, {
    double yukseklik = 56,
  }) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          height: yukseklik,
          child: ctx.pageNumber == ctx.pagesCount ? imza : pw.SizedBox(),
        ),
        _altBilgi(ctx),
      ],
    );
  }

  static pw.Widget _kunye(Map<String, String> alanlar) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(3),
      },
      children: [
        for (final e in alanlar.entries)
          pw.TableRow(children: [
            _hucre(e.key, kalin: true, dolgu: _altDolgu),
            _hucre(e.value.trim().isEmpty ? '………………………' : e.value),
          ]),
      ],
    );
  }

  static pw.Widget _bolumBasligi(String metin) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 4, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        color: _baslikDolgu,
        child: pw.Text(metin,
            style:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _tablo(
    List<String> basliklar,
    List<List<String>> satirlar,
    Map<int, pw.TableColumnWidth> genislik,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
      columnWidths: genislik,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _baslikDolgu),
          children: [
            for (final b in basliklar) _hucre(b, kalin: true, ortala: true),
          ],
        ),
        for (final s in satirlar)
          pw.TableRow(
            children: [for (final h in s) _hucre(h)],
          ),
      ],
    );
  }

  /// Elle doldurulacak boş satırlar.
  static pw.Widget _bosSatirlar(int adet) {
    return pw.Column(
      children: [
        for (var i = 0; i < adet; i++)
          pw.Container(
            height: 20,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 0.4, color: PdfColors.grey600),
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _hucre(
    String metin, {
    bool kalin = false,
    bool ortala = false,
    PdfColor? dolgu,
    double? yukseklik,
  }) {
    return pw.Container(
      color: dolgu,
      height: yukseklik ?? (metin.trim().isEmpty ? 26 : null),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: ortala ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        metin,
        textAlign: ortala ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: kalin ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _imzaSatiri(String ad, String unvan) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(ad.trim().isEmpty ? '…………………………' : ad,
                style: const pw.TextStyle(fontSize: 8.5)),
            pw.Text(unvan,
                style: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 14),
            pw.Text('İmza', style: const pw.TextStyle(fontSize: 7.5)),
          ],
        ),
      ],
    );
  }

  /// Öğretmen imzası solda, müdür onayı sağda.
  ///
  /// Resmî yazışmada onay makamı ("Uygundur") hazırlayanın karşısında
  /// ve altında durur; öğretmen dosyasına konan rapor bu imzayla
  /// geçerli olur.
  static pw.Widget _onayBloku(String teacherName) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text('… / … / 20…',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 12),
              pw.Text(
                  teacherName.trim().isEmpty ? '…………………………' : teacherName,
                  style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('Sınıf Öğretmeni',
                  style: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('İmza', style: const pw.TextStyle(fontSize: 7.5)),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text('… / … / 20…',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Text('UYGUNDUR',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('…………………………',
                  style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('Okul Müdürü',
                  style: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('İmza', style: const pw.TextStyle(fontSize: 7.5)),
            ],
          ),
        ),
      ],
    );
  }
}
