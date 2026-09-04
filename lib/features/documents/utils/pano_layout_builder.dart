import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/name_formatter.dart';
import '../data/special_days_repository.dart';
import 'pano_layouts.dart';
import 'pano_motifler.dart';
import 'pano_palette.dart';

/// On pano kurgusunun A4 çizimi.
///
/// ## Ortak kurallar
///
/// * Kâğıt A4; kesilecek her parça kesik çizgiyle ve makas işaretiyle
///   belirtilir ([_kesikKutu]).
/// * Renk [PanoPalette] üzerinden gelir. Kurgu renge değil basamağa
///   güvenir: `koyu`/`orta` zeminde beyaz metin, `acik` zeminde siyah.
///   Öğretmenlerin çoğu siyah-beyaz bastığı için ölçüt budur.
/// * Panoya şube ve öğretmen adı basılmaz; okul adı basılır. Öğrenci
///   adı için boş satır bırakılır (bkz. PANO_ICERIK_KURALLARI.md).
class PanoLayoutBuilder {
  PanoLayoutBuilder._();

  static const _kesikGri = PdfColors.blueGrey400;

  /// Seçilen kurgunun sayfalarını [pdf] belgesine ekler.
  static void ciz(
    pw.Document pdf, {
    required PanoKurgu kurgu,
    required SpecialDay gun,
    required PanoContent? icerik,
    required String schoolName,
    required String academicYear,
  }) {
    final p = PanoPalette.of(gun.ad);
    final baslik = (icerik?.panoBaslik.trim().isNotEmpty == true)
        ? icerik!.panoBaslik
        : gun.ad;
    final dip = [
      if (schoolName.trim().isNotEmpty) schoolName,
      academicYear,
    ].where((e) => e.trim().isNotEmpty).join('  ·  ');

    switch (kurgu) {
      case PanoKurgu.devBaslik:
        _devBaslik(pdf, p, baslik, gun.ad);
      case PanoKurgu.tarihSeridi:
        _tarihSeridi(pdf, p, gun, icerik, baslik, dip);
      case PanoKurgu.onceSonra:
        _onceSonra(pdf, p, icerik, baslik, dip, gun.ad);
      case PanoKurgu.merkezVecize:
        _merkezVecize(pdf, p, gun, icerik, baslik, dip);
      case PanoKurgu.ogrenciAgaci:
        _ogrenciAgaci(pdf, p, icerik, baslik, dip, gun.ad);
      case PanoKurgu.soruCevap:
        _soruCevap(pdf, p, icerik, baslik, dip, gun.ad);
      case PanoKurgu.siirDuvari:
        _siirDuvari(pdf, p, icerik, baslik, dip, gun.ad);
      case PanoKurgu.biliyorMuydunuz:
        _biliyorMuydunuz(pdf, p, icerik, baslik, dip, gun.ad);
      case PanoKurgu.sozPanosu:
        _sozPanosu(pdf, p, icerik, baslik, dip, gun.ad);
      case PanoKurgu.kartDestesi:
        _kartDestesi(pdf, p, gun, icerik, baslik, dip);
      case PanoKurgu.kavramSozlugu:
        _kavramSozlugu(pdf, p, icerik, baslik, dip, gun.ad);
    }
  }

  // ================================================== 1. Dev Başlık

  /// Günün adı harf harf, her harf bir A4'e sığacak kadar büyük.
  ///
  /// Harfler İÇİ BOŞ basılır: öğrenciler kuru boya, sim veya el iziyle
  /// doldurur. Dolu basmak hem toneri bitirir hem çocuğa iş bırakmaz.
  static void _devBaslik(
    pw.Document pdf,
    PanoPalette p,
    String baslik,
    String gunAdi,
  ) {
    final harfler = trUpper(baslik)
        .split('')
        .where((h) => h.trim().isNotEmpty)
        .toList();

    // Sayfa başına 4 harf: A4 yatayda dörde bölününce her harf ~7 cm.
    const harfSayfada = 4;
    for (var i = 0; i < harfler.length; i += harfSayfada) {
      final dilim = harfler.skip(i).take(harfSayfada).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _kurguBasligi(
                p,
                'DEV BAŞLIK HARFLERİ',
                'Kesip panonun üst bandına yan yana dizin. '
                    'Harflerin içini öğrenciler boyar.',
                gunAdi: gunAdi,
              ),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    for (final h in dilim)
                      pw.Expanded(child: _devHarf(p, h)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              _sayfaAlt(
                '${i ~/ harfSayfada + 1}. harf sayfası  ·  '
                'toplam ${harfler.length} harf',
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Dev harfin puntosu — harfin genişliğine göre.
  ///
  /// A4 yatayda dört hücre var, her hücre ~180 punto. 260 punto çoğu
  /// harfte sığıyordu ama M ve W gibi geniş harfler hücreden taşıp
  /// sayfa kenarından kesiliyordu ("ZAFER BAYRAMI"nın M'si yarım
  /// basılıyordu). Geniş harfler küçültülür; boy farkı panoda yan yana
  /// asılınca göze batmıyor, kırpılma batıyordu.
  static double _harfPunto(String harf) {
    const genis = {'M', 'W', 'Ğ', 'Ö', 'Ü', 'Q'};
    const dar = {'I', 'İ', 'J', 'L', '1'};
    if (genis.contains(harf)) return 200;
    if (dar.contains(harf)) return 260;
    return 240;
  }

  static pw.Widget _devHarf(PanoPalette p, String harf) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          width: 1,
          color: _kesikGri,
          style: pw.BorderStyle.dashed,
        ),
      ),
      child: pw.Center(
        child: pw.Text(
          harf,
          style: pw.TextStyle(
            fontSize: _harfPunto(harf),
            fontWeight: pw.FontWeight.bold,
            color: p.koyu,
            // İÇİ BOŞ harf: yalnızca kontur basılır.
            //
            // Dolu basmak iki şeyi birden bozar: A4'ü baştan sona
            // mürekkeple kaplar (okul yazıcısı bunu kaldırmaz) ve
            // öğrenciye yapacak iş bırakmaz. Kurgunun amacı çocuğun
            // harfin içini boyaması.
            renderingMode: PdfTextRenderingMode.stroke,
          ),
        ),
      ),
    );
  }

  // ================================================== 2. Tarih Şeridi

  static void _tarihSeridi(
    pw.Document pdf,
    PanoPalette p,
    SpecialDay gun,
    PanoContent? icerik,
    String baslik,
    String dip,
  ) {
    final k = icerik?.kronoloji ?? const <PanoCard>[];
    _sayfaliKartlar(
      pdf,
      p,
      kurguAd: 'TARİH ŞERİDİ',
      yonerge: 'Kesip ipe mandallayın veya doğrudan panoya kronolojik '
          'sırayla asın.',
      baslik: baslik,
      dip: dip,
      // Kartlar içeriğe sarıldığı için A4'e beşi rahat sığar.
      kartSayfada: 5,
      kartlar: [
        for (var i = 0; i < k.length; i++)
          _seritKarti(p, i + 1, k[i].baslik, k[i].metin),
      ],
      gunAdi: gun.ad,
    );
  }

  static pw.Widget _seritKarti(
    PanoPalette p,
    int sira,
    String yil,
    String olay,
  ) {
    // Kart içeriğe sarılır; sıra bandı sabit yükseklikte durur.
    // Stretch kullanmak, dış Expanded kaldırıldığında sonsuz yükseklik
    // istiyordu.
    return _kesikKutu(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Sıra numarası bandı — koyu zemin, beyaz rakam.
          pw.Container(
            width: 52,
            height: 68,
            color: p.koyu,
            alignment: pw.Alignment.center,
            child: pw.Text(
              '$sira',
              style: pw.TextStyle(
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              color: p.acik,
              padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 13),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    trUpper(yil),
                    style: pw.TextStyle(
                      fontSize: 19,
                      fontWeight: pw.FontWeight.bold,
                      color: p.koyu,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    olay,
                    style: const pw.TextStyle(
                      fontSize: 13,
                      lineSpacing: 3.2,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================== 3. Önce ve Sonra

  static void _onceSonra(
    pw.Document pdf,
    PanoPalette p,
    PanoContent? icerik,
    String baslik,
    String dip,
    String gunAdi,
  ) {
    final c = icerik?.oncesiSonrasi ?? const <PanoCompare>[];

    // Sayfa başına 3 karşılaştırma: her biri yan yana iki kart.
    for (var i = 0; i < c.length; i += 3) {
      final dilim = c.skip(i).take(3).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _kurguBasligi(
                p,
                'ÖNCE VE SONRA',
                'Panoyu ortadan ikiye ayırın. Sol karta “önce”, sağ karta '
                    '“sonra” kartlarını asın.',
                gunAdi: gunAdi,
              ),
              pw.SizedBox(height: 10),
              for (final x in dilim) ...[
                _karsilastirmaSatiri(p, x),
                pw.SizedBox(height: 12),
              ],
              pw.Expanded(child: pw.SizedBox()),
              _sayfaAlt('$baslik  ·  $dip'),
            ],
          ),
        ),
      );
    }
  }

  static pw.Widget _karsilastirmaSatiri(PanoPalette p, PanoCompare c) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: p.orta,
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: pw.Text(
            trUpper(c.baslik),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          // Kartlar kendi içeriği kadar uzar; iki taraf farklı boyda
          // olabilir. Eşitlemek için sayfayı germek boşluk yaratıyordu.
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
              pw.Expanded(
                child: _karsilastirmaKarti(
                  p,
                  'ÖNCE',
                  c.oncesi,
                  // "Önce" nötr gri: renk değişimin kendisine ayrılır.
                  bant: PdfColors.blueGrey700,
                  zemin: PdfColors.grey100,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _karsilastirmaKarti(
                  p,
                  'SONRA',
                  c.sonrasi,
                  bant: p.koyu,
                  zemin: p.acik,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _karsilastirmaKarti(
    PanoPalette p,
    String etiket,
    String metin, {
    required PdfColor bant,
    required PdfColor zemin,
  }) {
    return _kesikKutu(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: bant,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              etiket,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            color: zemin,
            padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: pw.Text(
              metin,
              style: const pw.TextStyle(
                fontSize: 13,
                lineSpacing: 3.4,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================== 4. Merkez Vecize

  static void _merkezVecize(
    pw.Document pdf,
    PanoPalette p,
    SpecialDay gun,
    PanoContent? icerik,
    String baslik,
    String dip,
  ) {
    // 1. sayfa: yatay merkez afişi.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2.6, color: p.koyu),
                ),
                padding: const pw.EdgeInsets.all(5),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: p.orta),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: double.infinity,
                        color: p.koyu,
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        child: pw.Column(
                          children: [
                            if (dip.isNotEmpty)
                              pw.Text(
                                trUpper(dip.split('  ·  ').first),
                                style: const pw.TextStyle(
                                  fontSize: 9.5,
                                  color: PdfColors.white,
                                ),
                              ),
                            pw.SizedBox(height: 8),
                            // Uzun başlıklar 26 punto ile tek satıra
                            // sığmayıp kenardan taşıyordu ("...MİLLÎ
                            // BİRLİK GÜNÜ" kırpılıyordu). Punto başlık
                            // uzunluğuna göre düşer; kısa başlıklar
                            // eskisi gibi 26 puntoda kalır.
                            pw.Text(
                              trUpper(baslik),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: _basligaGorePunto(baslik),
                                fontWeight: pw.FontWeight.bold,
                                lineSpacing: 3,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              gun.tarihMetni,
                              style: const pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          width: double.infinity,
                          color: p.acik,
                          padding: const pw.EdgeInsets.all(20),
                          // Vecize afişin dikey ortasında dursun. Column'un
                          // kendi hizalaması yetmiyor; Center gerekiyor.
                          alignment: pw.Alignment.center,
                          child: pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              // Günün motifi vecizenin üstünde durur.
                              // Afişin ortası eskiden tamamen boştu;
                              // A3'e büyütülünce boşluk daha da göze
                              // batıyordu.
                              pw.SizedBox(
                                width: 150,
                                height: 150,
                                child: pw.SvgImage(
                                  svg: PanoMotifler.gunMotifi(gun.ad, p),
                                ),
                              ),
                              pw.SizedBox(height: 26),
                              // Afiş uzaktan okunur: vecize iri punto.
                              pw.Text(
                                icerik?.vecize ?? '',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 22,
                                  lineSpacing: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.SizedBox(height: 16),
                              pw.Text(
                                '— ${icerik?.vecizeKaynak ?? ''}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: p.koyu,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            _sayfaAlt('Merkez afişi — panonun ortasına asın.'),
          ],
        ),
      ),
    );

    // 2. sayfa: çevresine gidecek dört kart.
    _kartSayfasi(
      pdf,
      p,
      kurguAd: 'MERKEZ VECİZE — ÇEVRE KARTLARI',
      yonerge: 'Kesip merkez afişin dört yanına yerleştirin.',
      dip: '$baslik  ·  $dip',
      kartlar: _dortKart(gun, icerik),
      gunAdi: gun.ad,
    );
  }

  // ================================================== 5. Öğrenci Ağacı

  static void _ogrenciAgaci(
    pw.Document pdf,
    PanoPalette p,
    PanoContent? icerik,
    String baslik,
    String dip,
    String gunAdi,
  ) {
    final gorevBaslik = icerik?.ogrenciGoreviBaslik ?? '';
    final yonerge = icerik?.ogrenciGoreviYonerge ?? '';

    // Sayfa başına 6 yaprak — bir sınıfa 4-5 sayfa yeter.
    for (var sayfa = 0; sayfa < 2; sayfa++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _kurguBasligi(
                p,
                'ÖĞRENCİ AĞACI',
                sayfa == 0
                    ? 'Panoya bir ağaç gövdesi çizin. Öğrenciler '
                        'yaprakları doldurup dallara asar.'
                    : 'Sınıf mevcuduna göre bu sayfayı çoğaltın.',
                gunAdi: gunAdi,
              ),
              pw.SizedBox(height: 9),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    for (var s = 0; s < 3; s++)
                      pw.Expanded(
                        child: pw.Row(
                          children: [
                            for (var c = 0; c < 2; c++)
                              pw.Expanded(
                                child: _yaprak(p, gorevBaslik, yonerge),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              _sayfaAlt('$baslik  ·  $dip'),
            ],
          ),
        ),
      );
    }
  }

  static pw.Widget _yaprak(PanoPalette p, String gorevBaslik, String yonerge) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      child: _kesikKutu(
        child: pw.Container(
          color: p.acik,
          padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 7),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                trUpper(gorevBaslik),
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: p.koyu,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                yonerge,
                style: const pw.TextStyle(
                  fontSize: 8,
                  lineSpacing: 1.8,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),
              // Yazı satırları — öğrenci elle doldurur.
              for (var i = 0; i < 4; i++) ...[
                pw.Container(
                  height: 0.7,
                  color: PdfColors.grey500,
                ),
                pw.SizedBox(height: 11),
              ],
              pw.Expanded(child: pw.SizedBox()),
              _adSatiri(),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================== 6. Soru–Cevap

  static void _soruCevap(
    pw.Document pdf,
    PanoPalette p,
    PanoContent? icerik,
    String baslik,
    String dip,
    String gunAdi,
  ) {
    final qa = icerik?.soruCevap ?? const <PanoQA>[];

    // Kapakçıklar içerik yüksekliğinde durduğu için A4'e altısı sığar.
    for (var i = 0; i < qa.length; i += 6) {
      final dilim = qa.skip(i).take(6).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _kurguBasligi(
                p,
                'SORU – CEVAP KAPAKÇIĞI',
                'Kesin, orta çizgiden katlayın. Üstte soru görünür, '
                    'kapak kaldırılınca cevap çıkar.',
                gunAdi: gunAdi,
              ),
              pw.SizedBox(height: 9),
              // Kapakçıklar içerik yüksekliğinde kalır; sayfayı eşit
              // bölmek cevabın altında koca boşluk bırakıyordu.
              for (final x in dilim) _kapakcik(p, x),
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(height: 5),
              _sayfaAlt('$baslik  ·  $dip'),
            ],
          ),
        ),
      );
    }
  }

  static pw.Widget _kapakcik(PanoPalette p, PanoQA qa) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      child: _kesikKutu(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Kapak yüzü — soru.
            pw.Container(
              color: p.orta,
              padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: pw.Text(
                qa.soru,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            // Katlama çizgisi.
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              color: PdfColors.grey300,
              child: pw.Text(
                '- - - - - - - -  buradan katlayın  - - - - - - - -',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 6.5,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            // Kapağın altı — cevap.
            pw.Container(
              color: p.acik,
              padding: const pw.EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: pw.Text(
                qa.cevap,
                style: const pw.TextStyle(
                  fontSize: 12,
                  lineSpacing: 3,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================== 7. Şiir Duvarı

  static void _siirDuvari(
    pw.Document pdf,
    PanoPalette p,
    PanoContent? icerik,
    String baslik,
    String dip,
    String gunAdi,
  ) {
    final d = icerik?.panoDortlukler ?? const <PanoPoem>[];
    // Sayfaya iki sütun × iki satır = dört dörtlük sığıyor. Fazlası
    // eskiden atılıyordu; artık sonraki sayfaya taşar.
    for (var i = 0; i < d.length; i += 4) {
      final dilim = d.skip(i).take(4).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _kurguBasligi(
                p,
                'ŞİİR DUVARI',
                'Kesip panoya dağıtarak asın. Süsleme az, yazı öne çıkar.',
                gunAdi: gunAdi,
              ),
              pw.SizedBox(height: 12),
              // İki sütun: dörtlük dar kalırsa mısra ortadan kırılır.
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final x in dilim) _dortlukKarti(p, x),
                ],
              ),
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(height: 5),
              _sayfaAlt('$baslik  ·  $dip'),
            ],
          ),
        ),
      );
    }
  }

  static pw.Widget _dortlukKarti(PanoPalette p, PanoPoem siir) {
    return pw.Container(
      width: 262,
      child: _kesikKutu(
        child: pw.Container(
          color: p.acik,
          padding: const pw.EdgeInsets.fromLTRB(15, 12, 15, 15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                trUpper(siir.baslik),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: p.koyu,
                ),
              ),
              pw.SizedBox(height: 9),
              pw.Text(
                siir.metin,
                style: const pw.TextStyle(
                  fontSize: 12.5,
                  lineSpacing: 4,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================== 8. Biliyor muydunuz

  static void _biliyorMuydunuz(
    pw.Document pdf,
    PanoPalette p,
    PanoContent? icerik,
    String baslik,
    String dip,
    String gunAdi,
  ) {
    final b = icerik?.biliyorMuydunuz ?? const <String>[];
    // Sayfaya yedi kart sığıyor. Fazlası eskiden sessizce atılıyordu;
    // içerik zenginleşince yazılan olguların bir kısmı hiç basılmadan
    // kayboluyordu. Artık taşan kartlar ikinci sayfaya geçer.
    _sayfaliKartlar(
      pdf,
      p,
      kurguAd: 'BİLİYOR MUYDUNUZ?',
      yonerge: 'Kesip panoya dağıtın. En az hazırlık isteyen kurgu.',
      baslik: baslik,
      dip: dip,
      kartSayfada: 7,
      kartlar: [for (final x in b) _olguKarti(p, x)],
      gunAdi: gunAdi,
    );
  }

  /// Olgu kartı — panoya asılır, uzaktan okunur.
  ///
  /// Sayfa genişliğinin tamamını kaplar: iki sütuna sıkıştırmak yazıyı
  /// küçültüyor, panonun karşısındaki öğrenci okuyamıyordu.
  static pw.Widget _olguKarti(PanoPalette p, String metin) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 9),
      child: _kesikKutu(
        child: pw.Container(
          color: p.acik,
          padding: const pw.EdgeInsets.fromLTRB(14, 13, 14, 14),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 26,
                height: 26,
                decoration: pw.BoxDecoration(
                  color: p.koyu,
                  shape: pw.BoxShape.circle,
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  '?',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Text(
                  metin,
                  style: const pw.TextStyle(
                    fontSize: 13,
                    lineSpacing: 3,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================== 9. Söz Panosu

  static void _sozPanosu(
    pw.Document pdf,
    PanoPalette p,
    PanoContent? icerik,
    String baslik,
    String dip,
    String gunAdi,
  ) {
    final sozler = icerik?.sozler ?? const <String>[];
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _kurguBasligi(
              p,
              'SÖZ PANOSU',
              'Her öğrenci bir söz verir, adını yazar. Yıl sonunda '
                  'panodan indirip birlikte okuyun.',
              gunAdi: gunAdi,
            ),
            pw.SizedBox(height: 9),
            pw.Expanded(
              child: pw.Column(
                children: [
                  for (var i = 0; i < 4; i++)
                    pw.Expanded(
                      child: _sozKarti(
                        p,
                        sozler.isEmpty
                            ? 'Söz veriyorum:'
                            : sozler[i % sozler.length],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 5),
            _sayfaAlt('$baslik  ·  $dip  ·  sayfayı çoğaltın'),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sozKarti(PanoPalette p, String kalip) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      child: _kesikKutu(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: p.koyu,
              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 11),
              child: pw.Text(
                kalip,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                color: p.acik,
                padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 2; i++) ...[
                      pw.Container(height: 0.7, color: PdfColors.grey500),
                      pw.SizedBox(height: 13),
                    ],
                    pw.Expanded(child: pw.SizedBox()),
                    _adSatiri(imza: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================== 10. Kart Destesi

  static void _kartDestesi(
    pw.Document pdf,
    PanoPalette p,
    SpecialDay gun,
    PanoContent? icerik,
    String baslik,
    String dip,
  ) {
    _kartSayfasi(
      pdf,
      p,
      kurguAd: 'KART DESTESİ',
      yonerge: 'Kesip panoya dizin. Klasik dört kartlık düzen.',
      dip: '$baslik  ·  $dip',
      kartlar: _dortKart(gun, icerik),
      gunAdi: gun.ad,
    );
  }

  // ================================================== ortak parçalar

  /// Kurgu başlığı — hangi kurgu ve nasıl kullanılacağı.
  /// Merkez afiş başlığının puntosu.
  ///
  /// A4 yatay sayfada 26 puntoyla yaklaşık 34 karakter sığıyor. Daha
  /// uzun başlık kenardan taşıyor; punto kademeli düşürülür.
  static double _basligaGorePunto(String baslik) {
    final n = baslik.length;
    if (n <= 34) return 26;
    if (n <= 44) return 22;
    if (n <= 56) return 19;
    return 16;
  }

  static pw.Widget _kurguBasligi(
    PanoPalette p,
    String ad,
    String yonerge, {
    String? gunAdi,
  }) {
    // Günün motifi başlık bandının sağında durur. Beyaz çizilir —
    // bant koyu zeminli, paletin koyu tonuyla çizilse kaybolurdu.
    final motif = gunAdi == null ? null : PanoMotifler.gunMotifi(gunAdi, _beyazMotif);
    return pw.Container(
      width: double.infinity,
      color: p.koyu,
      padding: const pw.EdgeInsets.fromLTRB(13, 8, 13, 9),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$_makas  $ad',
                  style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  yonerge,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    lineSpacing: 1.6,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          if (motif != null) ...[
            pw.SizedBox(width: 10),
            pw.SizedBox(width: 34, height: 34, child: pw.SvgImage(svg: motif)),
          ],
        ],
      ),
    );
  }

  /// Koyu bant üzerine çizilecek motifin paleti.
  ///
  /// Üç basamak da beyaz/açık tutulur; motif zemine karışmasın diye.
  static const _beyazMotif = PanoPalette(
    koyu: PdfColors.white,
    orta: PdfColor.fromInt(0xFFD8D8D8),
    acik: PdfColor.fromInt(0xFF9A9A9A),
    tema: 'koyu bant üzeri',
  );

  /// Makas işareti — yazı tipinde ✂ yoksa boş kare çıkmasın diye metin.
  static const _makas = 'KES';

  /// Sayfa altı — okul adı, öğretim yılı ve kullanım notu.
  ///
  /// "MEB resmî evrakı değildir" uyarısı BURAYA konmaz: pano duvara
  /// asılır, öğrenci ve veli okur. Kaynak ayrımı öğretmeni ilgilendirir
  /// ve ekranda gösterilir; panonun üzerinde yer kaplamasının anlamı yok.
  /// Plan ve rapor idareye gittiği için o uyarı orada durur.
  static pw.Widget _sayfaAlt(String metin) {
    return pw.Text(
      metin,
      textAlign: pw.TextAlign.center,
      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
    );
  }

  /// Kesilecek her parçanın kenarlığı.
  static pw.Widget _kesikKutu({required pw.Widget child}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          width: 0.9,
          color: _kesikGri,
          style: pw.BorderStyle.dashed,
        ),
      ),
      child: child,
    );
  }

  /// Öğrenci ad satırı — şube BASILMAZ, öğrenci elle yazar.
  static pw.Widget _adSatiri({bool imza = false}) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            'Adı Soyadı: ………………………………',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            imza ? 'İmza: …………' : 'Sınıfı: …………',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }

  /// Dört bilgi kartı; içerik yoksa özetten türetilir.
  static List<PanoCard> _dortKart(SpecialDay gun, PanoContent? icerik) {
    final k = <PanoCard>[...?icerik?.panoKartlar];
    if (k.isEmpty) {
      k.add(PanoCard(
        baslik: 'Günün anlamı',
        metin: (icerik?.ozet.trim().isNotEmpty == true)
            ? icerik!.ozet
            : '${gun.ad} okulda anılır ve çalışılır.',
      ));
      for (final s in icerik?.sloganlar ?? const <String>[]) {
        if (k.length >= 4) break;
        k.add(PanoCard(baslik: 'Pano başlığı', metin: s));
      }
    }
    while (k.length < 4) {
      k.add(const PanoCard(
        baslik: 'Sınıfta',
        metin: 'Bu kareye sınıfın kendi cümlesini yazabilirsiniz.',
      ));
    }
    return k.take(4).toList();
  }

  /// 2x2 kart sayfası.
  static void _kartSayfasi(
    pw.Document pdf,
    PanoPalette p, {
    required String kurguAd,
    required String yonerge,
    required String dip,
    required List<PanoCard> kartlar,
    String? gunAdi,
  }) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _kurguBasligi(p, kurguAd, yonerge, gunAdi: gunAdi),
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
                              child: pw.Container(
                                margin: const pw.EdgeInsets.all(4),
                                child: _bilgiKarti(p, kartlar[s * 2 + c]),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 5),
            _sayfaAlt(dip),
          ],
        ),
      ),
    );
  }

  static pw.Widget _bilgiKarti(PanoPalette p, PanoCard k) {
    return _kesikKutu(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: p.orta,
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 11),
            child: pw.Text(
              trUpper(k.baslik),
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              color: p.acik,
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                k.metin,
                style: const pw.TextStyle(
                  fontSize: 11,
                  lineSpacing: 2.8,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartları sayfalara bölerek basar.
  // ================================================== 11. Kavram Sözlüğü

  /// Günün kavramları ve tanımları.
  ///
  /// Sınıfın ortak dili kurulmadan günün anlamı da kurulmuyor:
  /// "darbe", "erişilebilirlik", "erozyon" gibi sözcükler çocuğun
  /// bildiği sözcükler değil. Soru–Cevap kurgusundan ayrı tutuldu;
  /// orada muhakeme var, burada tanım.
  static void _kavramSozlugu(
    pw.Document pdf,
    PanoPalette p,
    PanoContent? icerik,
    String baslik,
    String dip,
    String gunAdi,
  ) {
    final k = icerik?.sozluk ?? const <PanoTerm>[];
    _sayfaliKartlar(
      pdf,
      p,
      kurguAd: 'KAVRAM SÖZLÜĞÜ',
      yonerge: 'Kesip panoya alt alta dizin. Ders başında birlikte '
          'okunması önerilir.',
      baslik: baslik,
      dip: dip,
      kartSayfada: 6,
      kartlar: [for (final t in k) _sozlukKarti(p, t)],
      gunAdi: gunAdi,
    );
  }

  /// Sözlük kartı — solda kavram bandı, sağda tanım.
  static pw.Widget _sozlukKarti(PanoPalette p, PanoTerm t) {
    // Satır içeriğe sarılır. `stretch` kullanmak, dış Expanded
    // olmadığında sonsuz yükseklik isteyip kartı hiç çizdirmiyordu
    // (bkz. _seritKarti'ndeki aynı not).
    return _kesikKutu(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Kavram bandı sabit genişlikte: tanımlar farklı uzunlukta
          // olduğu için kavramlar alt alta hizalı dursun.
          pw.Container(
            width: 132,
            height: 46,
            color: p.koyu,
            padding: const pw.EdgeInsets.fromLTRB(11, 12, 9, 12),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              t.kavram,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 46),
              color: p.acik,
              padding: const pw.EdgeInsets.fromLTRB(13, 12, 13, 12),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                t.tanim,
                style: const pw.TextStyle(
                  fontSize: 10.5,
                  lineSpacing: 2.2,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _sayfaliKartlar(
    pw.Document pdf,
    PanoPalette p, {
    required String kurguAd,
    required String yonerge,
    required String baslik,
    required String dip,
    required int kartSayfada,
    required List<pw.Widget> kartlar,
    String? gunAdi,
  }) {
    for (var i = 0; i < kartlar.length; i += kartSayfada) {
      final dilim = kartlar.skip(i).take(kartSayfada).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _kurguBasligi(p, kurguAd, yonerge, gunAdi: gunAdi),
              pw.SizedBox(height: 10),
              // Kartlar içerik yüksekliğinde durur. Sayfayı eşit bölmek
              // kısa metinli kartların altında boşluk bırakıyordu.
              for (final k in dilim)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: k,
                ),
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(height: 5),
              _sayfaAlt('$baslik  ·  $dip'),
            ],
          ),
        ),
      );
    }
  }
}
