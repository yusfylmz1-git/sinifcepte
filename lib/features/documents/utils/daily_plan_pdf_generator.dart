import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';

/// SınıfCepte - MEB Türkiye Yüzyılı Maarif Modeli (TYMM) Günlük Ders Planı PDF Üreticisi
class DailyPlanPdfGenerator {
  DailyPlanPdfGenerator._();

  /// Tek bir haftaya ait TYMM Günlük Ders Planı PDF belgesini üretir.
  static Future<Uint8List> generate({
    required Map<String, dynamic> planData,
    required TeacherProfileModel teacher,
    String? academicYear,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = await PdfTrFonts.document();

    _haftaSayfasiniEkle(
      pdf: pdf,
      planData: planData,
      teacher: teacher,
      academicYear: academicYear,
      format: format,
    );

    return PdfTrFonts.kaydet(pdf);
  }

  /// 1'den 36'ya kadar tüm haftaları içeren toplu yıllık ders işleniş planı kitapçığı üretir.
  static Future<Uint8List> generateFullYearPdf({
    required List<Map<String, dynamic>> allWeeksPlanData,
    required TeacherProfileModel teacher,
    required String ders,
    required String sinif,
    String? academicYear,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = await PdfTrFonts.document();

    final okulAdi = teacher.schoolName.trim().isNotEmpty
        ? teacher.schoolName.trim().toUpperCase()
        : 'T.C. MİLLÎ EĞİTİM BAKANLIĞI';
    final ogretmenAdi = teacher.fullName.trim().isNotEmpty
        ? teacher.fullName.trim()
        : 'Ders Öğretmeni';
    final mudurAdi = teacher.schoolPrincipalName.trim().isNotEmpty
        ? teacher.schoolPrincipalName.trim()
        : 'Okul Müdürü';
    final yil = (academicYear != null && academicYear.trim().isNotEmpty)
        ? academicYear.trim()
        : '2024-2025';

    // 1. Resmî Kapak Sayfası
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => _resmiKapakSayfasi(
          okulAdi: okulAdi,
          ders: ders,
          sinif: sinif,
          ogretmenAdi: ogretmenAdi,
          mudurAdi: mudurAdi,
          academicYear: yil,
        ),
      ),
    );

    // 2. Her bir hafta için ders planı sayfalarını ekle
    for (final planData in allWeeksPlanData) {
      _haftaSayfasiniEkle(
        pdf: pdf,
        planData: planData,
        teacher: teacher,
        academicYear: yil,
        format: format,
      );
    }

    return PdfTrFonts.kaydet(pdf);
  }

  static void _haftaSayfasiniEkle({
    required pw.Document pdf,
    required Map<String, dynamic> planData,
    required TeacherProfileModel teacher,
    String? academicYear,
    PdfPageFormat format = PdfPageFormat.a4,
  }) {
    final meta = planData['meta'] as Map<String, dynamic>? ?? {};
    final kazanimlarVeSurec = planData['kazanimlar_ve_surec'] as Map<String, dynamic>? ?? {};
    final ozelAlanlar = planData['ozel_alanlar'] as Map<String, dynamic>? ?? {};
    final ogretimSureci = planData['ogretim_sureci'] as Map<String, dynamic>? ?? {};
    final farklilastirma = ogretimSureci['farklilastirma'] as Map<String, dynamic>? ?? {};

    final ders = meta['ders']?.toString() ?? 'Ders';
    final sinif = meta['sinif']?.toString() ?? '';
    final hafta = meta['hafta']?.toString() ?? '1. Hafta';
    final tarihAraligi = meta['tarih_araligi']?.toString() ?? '';
    final dersSaati = meta['ders_saati']?.toString() ?? '2';
    final temaUnite = meta['tema_unite']?.toString() ?? '';

    final ciktilar = (kazanimlarVeSurec['ogrenme_ciktilari'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final surecAdimlari = (kazanimlarVeSurec['surec_bilesenleri'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final belirliGun = ozelAlanlar['belirli_gun_ve_haftalar']?.toString() ?? '';
    final alanBecerileri = ozelAlanlar['alan_becerileri']?.toString() ?? '';
    final kavramsalBeceriler = ozelAlanlar['kavramsal_beceriler']?.toString() ?? '';
    final sdb = ozelAlanlar['sosyal_duygusal_ogrenme_becerileri']?.toString() ?? '';
    final ob = ozelAlanlar['okuryazarlik_becerileri']?.toString() ?? '';
    final degerler = ozelAlanlar['degerler']?.toString() ?? '';
    final disiplinlerArasi = ozelAlanlar['disiplinler_arasi_iliskiler']?.toString() ?? '';

    final uygulamalar = ogretimSureci['ogrenme_ogretme_uygulamalari']?.toString() ?? '';

    final dikkatCekme = ogretimSureci['dikkat_cekme']?.toString() ?? '';
    final guduleme = ogretimSureci['guduleme']?.toString() ?? '';
    final derseGecis = ogretimSureci['derse_gecis']?.toString() ?? '';
    final List<String> etkinlikler = (ogretimSureci['etkinlikler'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    if (etkinlikler.isEmpty && uygulamalar.isNotEmpty) {
      etkinlikler.addAll(uygulamalar.split('\n').where((s) => s.trim().isNotEmpty));
    }

    final bireyselEtkinlikler = ogretimSureci['bireysel_etkinlikler']?.toString() ?? '';
    final gruplaEtkinlikler = ogretimSureci['grupla_etkinlikler']?.toString() ?? '';
    final ozet = ogretimSureci['ozet']?.toString() ?? '';

    final zenginlestirme = farklilastirma['zenginlestirme']?.toString() ?? '';
    final destekleme = farklilastirma['destekleme']?.toString() ?? '';
    final genelFarklilastirma = farklilastirma['genel_aciklama']?.toString() ?? '';

    final okulAdi = teacher.schoolName.trim().isNotEmpty
        ? teacher.schoolName.trim().toUpperCase()
        : 'T.C. MİLLÎ EĞİTİM BAKANLIĞI';
    final ogretmenAdi = teacher.fullName.trim().isNotEmpty
        ? teacher.fullName.trim()
        : 'Ders Öğretmeni';
    final mudurAdi = teacher.schoolPrincipalName.trim().isNotEmpty
        ? teacher.schoolPrincipalName.trim()
        : 'Okul Müdürü';
    final yil = (academicYear != null && academicYear.trim().isNotEmpty)
        ? academicYear.trim()
        : '2024-2025';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _ustBilgi(
          okulAdi: okulAdi,
          ders: ders,
          sinif: sinif,
          hafta: hafta,
          academicYear: yil,
        ),
        footer: (context) => _altBilgi(context),
        build: (context) => [
          pw.SizedBox(height: 8),

          // TABLO 1: DERS VE HAFTA GENEL BİLGİLERİ
          _bilgiTablosu(
            ders: ders,
            sinif: sinif,
            hafta: hafta,
            tarih: tarihAraligi,
            sure: '$dersSaati Ders Saati',
            tema: temaUnite,
            belirliGun: belirliGun,
            academicYear: yil,
          ),
          pw.SizedBox(height: 10),

          // BÖLÜM 1: ÖĞRENME ÇIKTILARI VE SÜREÇ BİLEŞENLERİ
          _bolumBasligi('1. ÖĞRENME ÇIKTILARI VE SÜREÇ BİLEŞENLERİ'),
          pw.SizedBox(height: 4),
          _maddeKutusu(
            baslik: 'Öğrenme Çıktıları (Kazanımlar):',
            maddeler: ciktilar.isNotEmpty ? ciktilar : ['İlgili haftanın öğrenme çıktısı'],
          ),
          if (surecAdimlari.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _maddeKutusu(
              baslik: 'Süreç Bileşenleri (Alt Basamaklar):',
              maddeler: surecAdimlari,
            ),
          ],
          pw.SizedBox(height: 10),

          // BÖLÜM 2: BECERİLER, DEĞERLER VE İLİŞKİLER
          _bolumBasligi('2. BECERİLER, EĞİLİMLER VE DEĞERLER ÇERÇEVESİ'),
          pw.SizedBox(height: 4),
          _becerilerTablosu(
            alanBecerileri: alanBecerileri,
            kavramsalBeceriler: kavramsalBeceriler,
            sdb: sdb,
            ob: ob,
            degerler: degerler,
            disiplinlerArasi: disiplinlerArasi,
          ),
          pw.SizedBox(height: 10),

          // BÖLÜM 3: ÖĞRETİM SÜRECİ (ÖĞRENME-ÖĞRETME YAŞANTILARI VE ETKİNLİKLERİ)
          _bolumBasligi('3. ÖĞRETİM SÜRECİ (ÖĞRENME-ÖĞRETME YAŞANTILARI)'),
          pw.SizedBox(height: 4),
          _ogretmeOgrenmeEtkinlikleriTablosu(
            dikkatCekme: dikkatCekme,
            guduleme: guduleme,
            derseGecis: derseGecis,
            etkinlikler: etkinlikler,
            bireyselEtkinlikler: bireyselEtkinlikler,
            gruplaEtkinlikler: gruplaEtkinlikler,
            ozet: ozet,
          ),
          pw.SizedBox(height: 10),

          // BÖLÜM 4: FARKLILAŞTIRMA VE DEĞERLENDİRME
          _bolumBasligi('4. FARKLILAŞTIRMA (ZENGİNLEŞTİRME & DESTEKLEME)'),
          pw.SizedBox(height: 4),
          _farklilastirmaTablosu(
            genel: genelFarklilastirma,
            zenginlestirme: zenginlestirme,
            destekleme: destekleme,
          ),
          pw.SizedBox(height: 18),

          // İMZA ALANI
          _imzaAlani(
            ogretmenAdi: ogretmenAdi,
            mudurAdi: mudurAdi,
          ),
        ],
      ),
    );
  }

  static pw.Widget _resmiKapakSayfasi({
    required String okulAdi,
    required String ders,
    required String sinif,
    required String ogretmenAdi,
    required String mudurAdi,
    required String academicYear,
  }) {
    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            children: [
              pw.SizedBox(height: 10),
              pw.Text(
                'T.C.',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'MİLLÎ EĞİTİM BAKANLIĞI',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                okulAdi,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                height: 1.5,
                width: 240,
                color: PdfColors.blueGrey800,
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                'TÜRKİYE YÜZYILI MAARİF MODELİ',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'GÜNLÜK DERS İŞLENİŞ PLANLARI',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                '(1 - 36. HAFTALAR DOSYASI)',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              // Ders işlenişi alanlarının bir bölümü şablondur; belge
              // zümre onayından geçmeden resmî plan yerine geçmez.
              pw.Text(
                'TASLAK — Zümre öğretmenler kurulunca gözden geçirilmesi gerekir.',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('DERS: ${ders.toUpperCase()}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('SINIF: $sinif', style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.Text('ÖĞRETİM YILI: $academicYear', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          _imzaAlani(
            ogretmenAdi: ogretmenAdi,
            mudurAdi: mudurAdi,
          ),
        ],
      ),
    );
  }

  static pw.Widget _ustBilgi({
    required String okulAdi,
    required String ders,
    required String sinif,
    required String hafta,
    String? academicYear,
  }) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'T.C.',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Center(
          child: pw.Text(
            'MİLLÎ EĞİTİM BAKANLIĞI',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Center(
          child: pw.Text(
            okulAdi,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            '${academicYear != null && academicYear.isNotEmpty ? '$academicYear ' : ''}TÜRKİYE YÜZYILI MAARİF MODELİ (TYMM) DERS İŞLENİŞ PLANI',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Divider(thickness: 0.8, color: PdfColors.grey700),
      ],
    );
  }

  static pw.Widget _altBilgi(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Text(
        'Sayfa ${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _bolumBasligi(String baslik) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Text(
        baslik,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
      ),
    );
  }

  static pw.Widget _bilgiTablosu({
    required String ders,
    required String sinif,
    required String hafta,
    required String tarih,
    required String sure,
    required String tema,
    required String belirliGun,
    String? academicYear,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(2.0),
      },
      children: [
        pw.TableRow(
          children: [
            _hucre('Ders / Sınıf', bold: true, gri: true),
            _hucre('$ders - $sinif'),
            _hucre('Öğretim Yılı', bold: true, gri: true),
            _hucre(academicYear ?? '2024-2025'),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Hafta / Tarih', bold: true, gri: true),
            _hucre('$hafta (${tarih.isNotEmpty ? tarih : "-"})'),
            _hucre('Ders Saati', bold: true, gri: true),
            _hucre(sure),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Tema / Ünite', bold: true, gri: true),
            _hucre(tema.isNotEmpty ? tema : 'Tema', colSpan: 3),
            pw.Container(),
            pw.Container(),
          ],
        ),
        if (belirliGun.isNotEmpty)
          pw.TableRow(
            children: [
              _hucre('Belirli Gün/Hafta', bold: true, gri: true),
              _hucre(belirliGun, colSpan: 3),
              pw.Container(),
              pw.Container(),
            ],
          ),
      ],
    );
  }

  static pw.Widget _maddeKutusu({
    required String baslik,
    required List<String> maddeler,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            baslik,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 2),
          for (final m in maddeler)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6, top: 1),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: const pw.TextStyle(fontSize: 8)),
                  pw.Expanded(
                    child: pw.Text(
                      m,
                      style: const pw.TextStyle(fontSize: 7.8, height: 1.15),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _becerilerTablosu({
    required String alanBecerileri,
    required String kavramsalBeceriler,
    required String sdb,
    required String ob,
    required String degerler,
    required String disiplinlerArasi,
  }) {
    final effectiveAlan = alanBecerileri.isNotEmpty ? alanBecerileri : 'Alan Becerileri ve Bilimsel Sorgulama';
    final effectiveKavramsal = kavramsalBeceriler.isNotEmpty ? kavramsalBeceriler : 'Kavramsal Çözümleme ve Bilgi Toplama';
    final effectiveSdb = sdb.isNotEmpty
        ? sdb
        : 'SDB1.1. Kendini Tanıma (Öz Farkındalık), SDB1.2. Kendini Düzenleme, SDB2.1. İletişim, SDB2.2. İş Birliği';
    final effectiveOb = ob.isNotEmpty
        ? ob
        : 'OB1. Bilgi Okuryazarlığı, OB2. Dijital Okuryazarlık, OB4. Görsel Okuryazarlık';
    final effectiveDegerler = degerler.isNotEmpty
        ? degerler
        : 'D3. Çalışkanlık, D4. Dostluk, D6. Dürüstlük, D8. Mahremiyet, D14. Saygı, D16. Sorumluluk, D17. Tasarruf';
    final effectiveDisiplinler = disiplinlerArasi.isNotEmpty
        ? disiplinlerArasi
        : 'Türkçe (anlama-ifade), Matematik (mantıksal akıl yürütme), Fen Bilimleri (bilimsel sorgulama)';

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(3.2),
      },
      children: [
        pw.TableRow(
          children: [
            _hucre('Alan Becerileri (AB)', bold: true, gri: true),
            _hucre(effectiveAlan),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Kavramsal Beceriler (KB)', bold: true, gri: true),
            _hucre(effectiveKavramsal),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Sosyal-Duygusal (SDB)', bold: true, gri: true),
            _hucre(effectiveSdb),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Okuryazarlık (OB)', bold: true, gri: true),
            _hucre(effectiveOb),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Erdem-Değer-Eylem', bold: true, gri: true),
            _hucre(effectiveDegerler),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Disiplinler Arası İlişki', bold: true, gri: true),
            _hucre(effectiveDisiplinler),
          ],
        ),
      ],
    );
  }

  static pw.Widget _ogretmeOgrenmeEtkinlikleriTablosu({
    required String dikkatCekme,
    required String guduleme,
    required String derseGecis,
    required List<String> etkinlikler,
    required String bireyselEtkinlikler,
    required String gruplaEtkinlikler,
    required String ozet,
  }) {
    final effectiveDikkat = dikkatCekme.isNotEmpty
        ? dikkatCekme
        : 'Konuyla ilgili merak uyandırıcı soru ve günlük yaşam örnekleriyle derse başlanır.';
    final effectiveGuduleme = guduleme.isNotEmpty
        ? guduleme
        : 'Bu derste hedeflenen öğrenme çıktıları ve süreç bileşenleri açıklanır.';
    final effectiveDerseGecis = derseGecis.isNotEmpty
        ? derseGecis
        : 'Öğrencilerin dikkati çekildikten ve hazırbulunuşlukları yoklandıktan sonra konunun işlenişine geçilir.';
    final effectiveEtkinlikler = etkinlikler.isNotEmpty
        ? etkinlikler
        : [
            'Öğretmen rehberliğinde ders içeriği tanıtılır ve temel kavramlar açıklanır.',
            'Etkileşimli tahta ve çoklu ortam sunuları yardımıyla soru-cevap yürütülür.',
            'Öğrencilerin günlük yaşam deneyimlerinden örnekler vermesi sağlanır.',
            'Kazanım pekiştirme çalışmaları ve çalışma yaprakları tamamlanır.',
          ];
    final effectiveBireysel = bireyselEtkinlikler.isNotEmpty
        ? bireyselEtkinlikler
        : 'Açık uçlu sorular, doğru-yanlış, boşluk doldurma, eşleştirme alıştırmaları, çalışma yaprakları.';
    final effectiveGrupla = gruplaEtkinlikler.isNotEmpty
        ? gruplaEtkinlikler
        : 'İşbirlikli grup çalışması, beyin fırtınası, istasyon tekniği ve akran öğrenmesi.';
    final effectiveOzet = ozet.isNotEmpty
        ? ozet
        : 'Öğrencilerin bireysel farklılıkları göz ardı edilmemelidir. Öğrenilen kavramların günlük hayat deneyimleriyle pekiştirilmesi ve ders sonu değerlendirmesi yapılır.';

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1),
        1: const pw.FlexColumnWidth(3.8),
      },
      children: [
        pw.TableRow(
          children: [
            _solBaslikHucre('ÖĞRETME-ÖĞRENME\nETKİNLİKLERİ'),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(3.1),
              },
              children: [
                pw.TableRow(
                  children: [
                    _hucre('Dikkat Çekme', bold: true, gri: true),
                    _hucre(effectiveDikkat),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _hucre('Güdüleme', bold: true, gri: true),
                    _hucre(effectiveGuduleme),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _hucre('Derse Geçiş', bold: true, gri: true),
                    _hucre(effectiveDerseGecis),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _hucre('Etkinlikler', bold: true, gri: true),
                    _maddelerHucresi(effectiveEtkinlikler),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _hucre('Bireysel Öğrenme Etkinlikleri\n(Ödev, deney)', bold: true, gri: true),
                    _hucre(effectiveBireysel),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _hucre('Grupla Öğrenme Etkinlikleri', bold: true, gri: true),
                    _hucre(effectiveGrupla),
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.TableRow(
          children: [
            _solBaslikHucre('ÖZET VE\nDEĞERLENDİRME'),
            _hucre(effectiveOzet),
          ],
        ),
      ],
    );
  }

  static pw.Widget _solBaslikHucre(String baslik) {
    return pw.Container(
      color: PdfColor.fromHex('#EAF2EA'),
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Center(
        child: pw.Text(
          baslik,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#1B3B1A'),
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _maddelerHucresi(List<String> maddeler) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      color: PdfColors.white,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final m in maddeler)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Expanded(
                    child: pw.Text(
                      m,
                      style: const pw.TextStyle(fontSize: 7.5, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _farklilastirmaTablosu({
    required String genel,
    required String zenginlestirme,
    required String destekleme,
  }) {
    final effectiveGenel = genel.isNotEmpty
        ? genel
        : 'Öğrencilerin ilgi, ihtiyaç, hazırbulunuşluk düzeyleri ve öğrenme profillerine göre içerik, süreç ve ürün boyutlarında esnek öğretim uyarlamaları uygulanır.';
    final effectiveZenginlestirme = zenginlestirme.isNotEmpty
        ? zenginlestirme
        : 'İleri düzeydeki ve hızlı öğrenen öğrenciler için: Konuyu derinleştirici araştırma projeleri, üst düzey problem çözme senaryoları, dijital ürün geliştirme ve akran rehberliği görevleri planlanır.';
    final effectiveDestekleme = destekleme.isNotEmpty
        ? destekleme
        : 'Öğrenme sürecinde ek desteğe ve zamana ihtiyacı olan öğrenciler için: Somut materyaller, görsel şemalar, basamaklandırılmış çalışma yaprakları, yönlendirici ipuçları ve birebir tekrar çalışmaları yürütülür.';

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(3.2),
      },
      children: [
        pw.TableRow(
          children: [
            _hucre('Farklılaştırma İlkesi', bold: true, gri: true),
            _hucre(effectiveGenel),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Zenginleştirme (İleri)', bold: true, gri: true),
            _hucre(effectiveZenginlestirme),
          ],
        ),
        pw.TableRow(
          children: [
            _hucre('Destekleme (Pekiştirme)', bold: true, gri: true),
            _hucre(effectiveDestekleme),
          ],
        ),
      ],
    );
  }

  static pw.Widget _imzaAlani({
    required String ogretmenAdi,
    required String mudurAdi,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Ders Öğretmeni', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(ogretmenAdi, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 20),
            pw.Text('İmza', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('UYGUNDUR', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(mudurAdi, style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Okul Müdürü', style: const pw.TextStyle(fontSize: 7.5)),
            pw.SizedBox(height: 12),
            pw.Text('Mühür / İmza', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _hucre(
    String metin, {
    bool bold = false,
    bool gri = false,
    int colSpan = 1,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      color: gri ? PdfColors.grey100 : PdfColors.white,
      child: pw.Text(
        metin,
        style: pw.TextStyle(
          fontSize: 7.8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          height: 1.15,
        ),
      ),
    );
  }
}
