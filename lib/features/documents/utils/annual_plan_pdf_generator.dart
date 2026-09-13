import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';

/// SınıfCepte - MEB Türkiye Yüzyılı Maarif Modeli (TYMM)
/// Ünitelendirilmiş Resmî Yıllık Ders Planı PDF Üreticisi
class AnnualPlanPdfGenerator {
  AnnualPlanPdfGenerator._();

  /// Türkçe karakter duyarlı büyük harf dönüşümü
  static String trUpper(String text) {
    return text
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ş', 'Ş')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase();
  }

  /// Tüm yıla ait A4 Yatay (Landscape) formatında MEB resmî yıllık plan PDF belgesini üretir.
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> allWeeksPlanData,
    required TeacherProfileModel teacher,
    required String ders,
    required String sinif,
    String? academicYear,
    String? weeklyLessonHours,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = await PdfTrFonts.document();

    final okulAdi = teacher.schoolName.trim().isNotEmpty
        ? trUpper(teacher.schoolName.trim())
        : 'T.C. MİLLÎ EĞİTİM BAKANLIĞI';
    final ogretmenAdi = teacher.fullName.trim().isNotEmpty
        ? teacher.fullName.trim()
        : 'Ders Öğretmeni';
    final brans = teacher.branch.trim().isNotEmpty
        ? teacher.branch.trim()
        : ders;
    final mudurAdi = teacher.schoolPrincipalName.trim().isNotEmpty
        ? teacher.schoolPrincipalName.trim()
        : 'Okul Müdürü';
    final yil = (academicYear != null && academicYear.trim().isNotEmpty)
        ? academicYear.trim()
        : '2026-2027';
    final saat = (weeklyLessonHours != null && weeklyLessonHours.trim().isNotEmpty)
        ? weeklyLessonHours.trim()
        : (allWeeksPlanData.isNotEmpty
            ? (allWeeksPlanData.first['meta']?['ders_saati']?.toString() ?? '2')
            : '2');

    // A4 Yatay (Landscape) Sayfa Formatı
    final landscapeFormat = format.landscape;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: landscapeFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        header: (context) => _tabloUstBasligi(
          context: context,
          okulAdi: okulAdi,
          ders: ders,
          sinif: sinif,
          ogretmenAdi: ogretmenAdi,
          brans: brans,
          yil: yil,
          saat: saat,
        ),
        footer: (context) => _sayfaAltBilgisi(context),
        build: (context) => [
          _yillikPlanTablosu(allWeeksPlanData, saat),
          pw.SizedBox(height: 16),
          _onayVeImzaBlogu(
            ogretmenAdi: ogretmenAdi,
            brans: brans,
            mudurAdi: mudurAdi,
            yil: yil,
          ),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  /// Sayfa Üst Bilgisi (Her sayfada veya ilk sayfada şık MEB formatı)
  static pw.Widget _tabloUstBasligi({
    required pw.Context context,
    required String okulAdi,
    required String ders,
    required String sinif,
    required String ogretmenAdi,
    required String brans,
    required String yil,
    required String saat,
  }) {
    // Yalnızca 1. sayfada tam başlık, sonraki sayfalarda kompakt şerit
    if (context.pageNumber == 1) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'T.C.',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'MİLLÎ EĞİTİM BAKANLIĞI',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            okulAdi,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '$yil EĞİTİM-ÖĞRETİM YILI ${trUpper(ders)} DERSİ $sinif ÜNİTELENDİRİLMİŞ YILLIK DERS PLANI',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                // Yöntem, araç-gereç ve ölçme sütunlarının bir bölümü
                // şablondur; belge zümre onayından geçmeden resmî değildir.
                pw.Text(
                  'TASLAK — Zümre öğretmenler kurulunca gözden geçirilmesi gerekir.',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Ders: $ders   •   Sınıf / Düzey: $sinif   •   Haftalık Ders Saati: $saat Saat',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Öğretmen: $ogretmenAdi ($brans)',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
        ],
      );
    } else {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 5),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$okulAdi — $yil ${trUpper(ders)} ($sinif) Ünitelendirilmiş Yıllık Planı',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
            pw.Text(
              'Öğretmen: $ogretmenAdi',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
          ],
        ),
      );
    }
  }

  /// 36 Haftalık MEB Resmî Tablosu
  static pw.Widget _yillikPlanTablosu(
    List<Map<String, dynamic>> haftalar,
    String varsayilanSaat,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.95), // Ay / Hafta / Tarih
        1: pw.FlexColumnWidth(0.35), // Saat
        2: pw.FlexColumnWidth(1.25), // Tema / Öğrenme Alanı
        3: pw.FlexColumnWidth(2.30), // Öğrenme Çıktıları (Kazanımlar)
        4: pw.FlexColumnWidth(2.10), // Süreç Bileşenleri / Konular
        5: pw.FlexColumnWidth(0.95), // Yöntem ve Teknikler
        6: pw.FlexColumnWidth(0.90), // Araç ve Gereçler
        7: pw.FlexColumnWidth(1.05), // Ölçme ve Değerlendirme
        8: pw.FlexColumnWidth(1.15), // Açıklamalar / Gün ve Haftalar
      },
      children: [
        // Tablo Başlık Satırı
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          repeat: true,
          children: [
            _tabloBaslikHucresi('AY / HAFTA\nTARİH'),
            _tabloBaslikHucresi('SAAT'),
            _tabloBaslikHucresi('TEMA / ALAN\nÜNİTE'),
            _tabloBaslikHucresi('ÖĞRENME ÇIKTILARI (KAZANIMLAR)'),
            _tabloBaslikHucresi('KONULAR VE ÖĞRENME SÜREÇLERİ'),
            _tabloBaslikHucresi('YÖNTEM VE\nTEKNİKLER'),
            _tabloBaslikHucresi('EĞİTİM TEK. VE\nMATERYALLER'),
            _tabloBaslikHucresi('ÖLÇME VE\nDEĞERLENDİRME'),
            _tabloBaslikHucresi('AÇIKLAMALAR VE\nBELİRLİ GÜN/HAFTA'),
          ],
        ),

        // Haftalık Plan Satırları
        for (int i = 0; i < haftalar.length; i++)
          _haftaTabloSatiri(haftalar[i], i + 1, varsayilanSaat),
      ],
    );
  }

  static pw.Widget _tabloBaslikHucresi(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6.8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.TableRow _haftaTabloSatiri(
    Map<String, dynamic> plan,
    int haftaNo,
    String varsayilanSaat,
  ) {
    final meta = plan['meta'] as Map<String, dynamic>? ?? {};
    final kazanimlarVeSurec = plan['kazanimlar_ve_surec'] as Map<String, dynamic>? ?? {};
    final ozelAlanlar = plan['ozel_alanlar'] as Map<String, dynamic>? ?? {};

    final temaUnite = meta['tema_unite']?.toString() ?? '$haftaNo. Hafta';
    final tarihAraligi = meta['tarih_araligi']?.toString() ?? '';
    final dersSaati = meta['ders_saati']?.toString() ?? varsayilanSaat;

    // Ay Tespiti
    final ayAdi = _tarihtenAyCikar(tarihAraligi, haftaNo);

    // Kazanımlar
    final ciktilar = (kazanimlarVeSurec['ogrenme_ciktilari'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final ciktilarMetni = ciktilar.isNotEmpty
        ? _hucreListesi(ciktilar)
        : 'Haftalık program kazanımları işlenir.';

    // Konular / Süreç Bileşenleri
    final surecler = (kazanimlarVeSurec['surec_bilesenleri'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final surecMetni = surecler.isNotEmpty
        ? _hucreListesi(surecler)
        : '$temaUnite işleniş ve pekiştirme adımları.';

    // Yöntem ve Teknikler
    const yontemler = 'Anlatım, Soru-Cevap, Beyin Fırtınası, Model Alma, Gösterip Yaptırma, Grup Çalışması, Akran Öğrenmesi';

    // Araç, Gereç ve Materyaller
    const aracGerec = 'MEB Ders Kitabı, EBA Platformu, Etkileşimli Tahta, Çalışma Yaprakları, Görsel ve Dijital İçerikler';

    // Ölçme ve Değerlendirme
    const olcme = 'Gözlem Formu, Kontrol Listesi, Performans Görevi, Açık Uçlu Değerlendirme, Soru-Cevap';

    // Açıklamalar / Belirli Gün ve Haftalar / Maarif Değer ve Becerileri
    final belirliGun = ozelAlanlar['belirli_gun_ve_haftalar']?.toString().trim() ?? '';
    final degerler = ozelAlanlar['degerler']?.toString().trim() ?? '';
    final StringBuffer aciklamaBuf = StringBuffer();
    // Emoji KULLANILMAZ: PDF yazı tipinde 📅 ve ⭐ karşılığı yok.
    // Üretim sırasında "Unable to find a font to draw" uyarısı çıkıyor
    // ve karakter teftişe giden evrakta boş kare olarak basılıyordu.
    // Aynı tuzak pano tarafında da yaşanmıştı (bkz. pano_layout_builder).
    if (belirliGun.isNotEmpty) {
      aciklamaBuf.writeln('Belirli Gün/Hafta: $belirliGun');
    }
    if (degerler.isNotEmpty) {
      aciklamaBuf.write('Değerler: $degerler');
    }
    final aciklamaMetni = aciklamaBuf.toString().trim().isNotEmpty
        ? aciklamaBuf.toString().trim()
        : 'Ders içi etkinlik ve pekiştirme';

    final isTatil = temaUnite.toLowerCase().contains('tatil') || ciktilarMetni.toLowerCase().contains('tatil');

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isTatil ? PdfColors.grey100 : (haftaNo.isEven ? const PdfColor(0.98, 0.98, 0.99) : PdfColors.white),
      ),
      children: [
        // 1. Ay / Hafta / Tarih
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                ayAdi,
                style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                '$haftaNo. Hafta',
                style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if (tarihAraligi.isNotEmpty)
                pw.Text(
                  tarihAraligi,
                  style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
            ],
          ),
        ),

        // 2. Saat
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Text(
            dersSaati,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),

        // 3. Tema / Alan / Ünite
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(
            temaUnite,
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
          ),
        ),

        // 4. Öğrenme Çıktıları
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(
            ciktilarMetni,
            style: const pw.TextStyle(fontSize: 6.2),
          ),
        ),

        // 5. Konular ve Öğrenme Süreçleri
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(
            surecMetni,
            style: const pw.TextStyle(fontSize: 6.0),
          ),
        ),

        // 6. Yöntem ve Teknikler
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: pw.Text(
            yontemler,
            style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.blueGrey900),
          ),
        ),

        // 7. Araç ve Gereçler
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: pw.Text(
            aracGerec,
            style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.blueGrey900),
          ),
        ),

        // 8. Ölçme ve Değerlendirme
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: pw.Text(
            olcme,
            style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.blueGrey900),
          ),
        ),

        // 9. Açıklamalar
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: pw.Text(
            aciklamaMetni,
            style: const pw.TextStyle(fontSize: 5.6, color: PdfColors.blueGrey800),
          ),
        ),
      ],
    );
  }

  /// Yıllık plan tablosunda bir hücreye sığacak madde listesi.
  ///
  /// ## Neden sınır var
  /// Yıllık plan A4 YATAY tabloda her haftayı TEK SATIRA basar. Kazanım
  /// listesi sınırsız yazılınca satır taşıyor ve sayfa okunmaz hâle
  /// geliyordu. Risk gerçek: müfredat paketinde 566 kayıtta 15'ten çok
  /// kazanım var; 6. sınıf Türkçe'de bir hafta 33 kazanım taşıyor
  /// (dört beceri alanı birden).
  ///
  /// Günlük planda böyle bir sınır YOKTUR ve olmamalıdır: orada her
  /// hafta ayrı sayfadır, kazanımların tamamı yazılır.
  ///
  /// Kesilen maddeler sayıyla bildirilir; öğretmen eksik olduğunu
  /// görsün, sessizce kaybolmasın.
  /// Test erişimi: sınırın davranışı PDF baytları üzerinden değil,
  /// doğrudan metin olarak doğrulanabilsin.
  ///
  /// (`@visibleForTesting` kullanılmıyor: `meta` bu projede doğrudan
  /// bağımlılık değil ve başka hiçbir dosya onu import etmiyor.)
  static String hucreListesiForTest(List<String> maddeler, {int sinir = 8}) =>
      _hucreListesi(maddeler, sinir: sinir);

  static String _hucreListesi(List<String> maddeler, {int sinir = 8}) {
    if (maddeler.length <= sinir) {
      return maddeler.map((m) => '• $m').join('\n');
    }
    final gosterilen = maddeler.take(sinir).map((m) => '• $m').join('\n');
    final kalan = maddeler.length - sinir;
    return '$gosterilen\n• (… ve $kalan kazanım daha — ayrıntı günlük planda)';
  }

  /// Belge Altı Resmî Onay ve İmza Bloğu
  static pw.Widget _onayVeImzaBlogu({
    required String ogretmenAdi,
    required String brans,
    required String mudurAdi,
    required String yil,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Zümre / Ders Öğretmeni
          pw.Container(
            width: 200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  ogretmenAdi,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '$brans Öğretmeni',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
                pw.SizedBox(height: 18),
                pw.Text('İmza', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ),

          // Zümre Başkanı
          pw.Container(
            width: 200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Zümre Başkanı',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '$brans Zümresi',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
                pw.SizedBox(height: 18),
                pw.Text('İmza', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ),

          // Okul Müdürü Onay Bloğu
          pw.Container(
            width: 220,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'UYGUNDUR',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  '... / 09 / ${yil.split('-').first}',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  mudurAdi,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Okul Müdürü',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sayfa Numarası Altlığı
  static pw.Widget _sayfaAltBilgisi(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Text(
        'Sayfa ${context.pageNumber} / ${context.pagesCount}  •  SınıfCepte Resmî Evrak Modülü',
        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
      ),
    );
  }

  static String _tarihtenAyCikar(String tarihAraligi, int haftaNo) {
    final t = tarihAraligi.toLowerCase();
    if (t.contains('eylül')) return 'EYLÜL';
    if (t.contains('ekim')) return 'EKİM';
    if (t.contains('kasım')) return 'KASIM';
    if (t.contains('aralık')) return 'ARALIK';
    if (t.contains('ocak')) return 'OCAK';
    if (t.contains('şubat')) return 'ŞUBAT';
    if (t.contains('mart')) return 'MART';
    if (t.contains('nisan')) return 'NİSAN';
    if (t.contains('mayıs')) return 'MAYIS';
    if (t.contains('haziran')) return 'HAZİRAN';

    // Hafta numarasına göre varsayılan takvim
    if (haftaNo <= 4) return 'EYLÜL';
    if (haftaNo <= 8) return 'EKİM';
    if (haftaNo <= 12) return 'KASIM';
    if (haftaNo <= 16) return 'ARALIK';
    if (haftaNo <= 19) return 'OCAK';
    if (haftaNo <= 23) return 'ŞUBAT';
    if (haftaNo <= 27) return 'MART';
    if (haftaNo <= 31) return 'NİSAN';
    if (haftaNo <= 35) return 'MAYIS';
    return 'HAZİRAN';
  }
}
