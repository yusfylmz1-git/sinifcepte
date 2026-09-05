import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/date_formatter.dart';
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
    // Ogretmenin girdigi tarih varsa o basilir; yoksa ogretim yili ve
    // baslangic ayindan hesaplanir (eski davranis).
    final dates = planDates(plan);
    // Ayni kazanim kodu mufredatta birden cok hafta tekrar ediyor ve
    // MEB surec bilesenlerini her tekrarda yazmamis. Onceden ilk
    // gorulen kayit aliniyordu; o kayit bilesensizse sutun bos
    // kaliyordu. Olcum: 398 kodda veri baska haftanin satirinda VAR.
    // Bu yuzden bilesen TASIYAN kayit oncelikli secilir.
    final hitsByCode = <String, UniqueOutcomeHit>{};
    for (final h in bank) {
      if (h.code.isEmpty) continue;
      final mevcut = hitsByCode[h.code];
      if (mevcut == null || (mevcut.steps.isEmpty && h.steps.isNotEmpty)) {
        hitsByCode[h.code] = h;
      }
    }

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
            // Dip not kaldirildi.
            //
            // "Taslak BEP ... yerine gecmez" ibaresi belgeyi okul
            // idaresinin gozunde gecersiz gosteriyordu; ogretmen
            // dosyaya koyacagi evrakta boyle bir cekince istemiyor.
            // Sayfa numarasi kaliyor, o resmi evrakta gerekli.
            pw.SizedBox(),
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
            defaultCriterion: plan.defaultCriterion,
          ),
          pw.SizedBox(height: 4),
          _environmentRow(plan),
          pw.SizedBox(height: 16),
          _signatures(),
        ],
      ),
    );

    return PdfTrFonts.kaydet(pdf);
  }

  /// "Surec Bilesenleri" hucresi.
  ///
  /// Kaynakta bu alan kazanimlarin yaklasik yarisinda bos: MEB
  /// bilesenleri her kazanim icin yazmamis (olcum: 1992 kodun
  /// 1047'sinde hicbir haftada yok). Bos hucre resmi evrakta eksik
  /// doldurulmus gibi duruyordu.
  ///
  /// Sirayla denenir: kazanimin kendi bilesenleri -> ogretmenin
  /// yazdigi davranis -> kazanim metni. Hicbiri yoksa cizgi basilir,
  /// boylece "doldurulmadi" ile "veri yok" ayirt edilir.
  static String _surecBilesenleri(UniqueOutcomeHit? hit, BepShortGoal s) {
    final bilesen = (hit?.steps ?? const <String>[])
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList();
    if (bilesen.isNotEmpty) return bilesen.join('\n');

    // Yedek, YAN SUTUNU TEKRAR ETMEMELI.
    //
    // "Ogrenme Ciktisi" sutunu kazanim metnini basiyor. Yedek olarak
    // ayni metni koyunca iki sutun ayni seyi yaziyor ve hucre dolu
    // gorunse de ogretmene bir sey soylemiyordu. Amac cumlesi
    // (kosul + davranis + olcut) kazanimdan farklidir: uygulama
    // kosulunu tasir.
    final cikti = s.outcomeDescription?.trim() ?? '';
    final amac = s.composed.trim();
    if (amac.isNotEmpty && amac != cikti) return amac;

    final davranis = s.behavior.trim();
    if (davranis.isNotEmpty && davranis != cikti) return davranis;

    // Tekrar etmektense bos oldugunu soyle.
    return '—';
  }

  static pw.Widget _planTable({
    required List<BepLongGoal> goals,
    required List<BepShortGoal> shorts,
    required Map<String, UniqueOutcomeHit> hitsByCode,
    required String dates,
    required String defaultCriterion,
  }) {
    // Ogretmenin plan genelinde belirledigi olcut. Girmemisse eski
    // sabit kullanilir.
    final varsayilanOlcut =
        defaultCriterion.trim().isNotEmpty ? defaultCriterion.trim() : '4/5 (%80)';
    // Donem sonu degerlendirmesi yapilmis mi?
    //
    // Ogretmen amaclari "Yeterli / Devam / Gelistir" diye
    // isaretliyordu ama sonuc PDF'e hic basilmiyordu; isaretlemenin
    // belgede karsiligi yoktu. Sutun ancak en az bir amac
    // degerlendirilmisse aciliyor — hic yoksa bos sutun sayfayi
    // gereksiz daraltir.
    final degerlendirmeVar = shorts.any((e) => e.latestStatus != null);

    final headers = [
      // "Ogrenme Alani" degil: bu sutun UZUN DONEMLI AMACI tasiyor.
      // Eski basligi okuyan ogretmen sutunun ne oldugunu
      // anlamiyordu.
      'Uzun Dönemli Amaç',
      'Öğrenme Çıktısı',
      'Süreç Bileşenleri',
      'Yöntem ve Teknik',
      'Kullanılacak Materyaller',
      'Eğilimler',
      'Başlangıç-Bitiş Tarihi',
      'Ölçüt',
      'Ölçme-Değerlendirme',
      // "Olcme-Degerlendirme" ARACI soyler (Gozlem Formu); bu sutun
      // SONUCU soyler. Ayri tutuluyorlar.
      if (degerlendirmeVar) 'Sonuç',
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
      if (degerlendirmeVar) 9: const pw.FlexColumnWidth(0.6),
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
        varsayilanOlcut,
        '',
        if (degerlendirmeVar) '',
      ]);
    } else {
      for (final long in goals) {
        // Uzun amac adi grubun YALNIZCA ILK satirinda basilir.
        //
        // Once her kisa amac satirinda tekrar ediliyordu; iki kisa
        // amacli bir uzun amac belgede iki kez yaziliyor, ogretmen
        // bir amacin nerede bitip otekinin nerede basladigini
        // goremiyordu.
        var ilk = true;
        // Devam satirlari YALNIZCA ok tasir.
        //
        // Uc yol olculdu:
        //   * Bos birakmak: 12 kisa amacli grup sayfayi asinca ikinci
        //     sayfadaki satirlarin hangi amaca ait oldugu belgeden
        //     anlasilmiyordu.
        //   * Tam basligi her satira yazmak: kullanicinin asil
        //     sikayeti buydu, sutun tekrarla doluyordu.
        //   * n satirda bir isaret: sayfaya 10-11 satir siginca
        //     isaret sayfa sonunda kaliyor, sayfa BASINDAKI satir yine
        //     adsiz oluyordu. Satir yuksekligi icerige gore degistigi
        //     icin sabit bir sayi guvenilir degil.
        //
        // Isaret hicbir satiri adsiz birakmiyor ("ustteki amaca
        // ait" demek) ve sutunu tekrar eden metinle doldurmuyor.
        // Sayfa nerede bolunurse bolunsun dogru kalir.
        //
        // Karakter secimi olcumle yapildi: ilk denemede ok (U+21B3)
        // kullanildi ve PDF'te KUTU cikti — gomulu NotoSans'ta o glif
        // yok. Fontun cmap'i okundu, U+2192 de yok; U+00BB var.
        // Numara her uzun amac icinde bastan baslar (1., 2., ...);
        // resmi formda numaralandirma boyledir.
        var i = 0;
        for (final s in long.shorts) {
          i++;
          final hit = hitsByCode[s.outcomeCode ?? ''];
          final steps = _surecBilesenleri(hit, s);
          data.add([
            ilk ? long.title : '»',
            '$i. ${s.outcomeDescription?.trim().isNotEmpty == true ? s.outcomeDescription! : s.behavior}',
            steps,
            s.method.trim().isNotEmpty ? s.method : _defaultMethods,
            s.materials.trim().isNotEmpty ? s.materials : _defaultMaterials,
            hit?.values ?? '',
            dates,
            s.criterion.trim().isNotEmpty ? s.criterion : varsayilanOlcut,
            s.assessment.trim().isNotEmpty ? s.assessment : _defaultAssess,
            if (degerlendirmeVar) s.latestStatus?.compactLabel ?? '',
          ]);
          ilk = false;
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
    // Bos kutu resmi belgede kotu duruyor; ogretmen girmediyse
    // yaygin varsayilan yazilir.
    String ya(String girilen, String yedek) =>
        girilen.trim().isNotEmpty ? girilen.trim() : yedek;

    pw.Widget hucre(String title, String body) => pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style:
                    pw.TextStyle(fontSize: 6.6, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(body, style: const pw.TextStyle(fontSize: 6.3)),
            ],
          ),
        );

    // Row DEGIL Table.
    //
    // Row her kutuyu kendi icerigi kadar uzatiyordu: birinde dort
    // secim, otekinde bir secim varsa cerceveler farkli boyda cikiyor,
    // "kareler oturmuyor" goruntusu olusuyordu. Tablo satirinin
    // hucreleri en uzun hucreye hizalanir — istenen davranis bu.
    // pdf paketinde IntrinsicHeight yok, bu yuzden Row duzeltilemezdi.
    //
    // Kenarlik ve renk ust taraftaki plan tablosuyla ayni; alt blok
    // onunla hizali duruyor.
    return pw.Table(
      border: pw.TableBorder.all(width: 0.45, color: PdfColors.blueGrey700),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            hucre(
              'Fiziksel Ortam Düzenlemeleri',
              ya(plan.physicalArrangements,
                  'Öğretmene yakın oturtma, dikkat dağıtıcı uyaranların '
                  'azaltılması'),
            ),
            hucre(
              'Sosyal Etkileşim Ortamı',
              ya(plan.socialArrangements,
                  'Akran desteği eşleştirmesi, olumlu davranış pekiştirme'),
            ),
            hucre(
              'Dijital Destekler',
              ya(plan.digitalSupports,
                  'Etkileşimli tahta uygulamaları, video destekli anlatım'),
            ),
          ],
        ),
      ],
    );
  }

  /// Imza blogu — SADECE GOREV ADI, kimsenin ismi yazilmaz.
  ///
  /// Once ogretmen adi, mudur adi ve kuruldaki isimler basiliyordu.
  /// Resmi BEP formunda bu satirlar elle imzalanir; onceden basilmis
  /// bir ad, kurul uyesi degistiginde belgeyi yanlis kilar ve
  /// ogretmen PDF'i bastiktan sonra duzeltemez.
  static pw.Widget _signatures() {
    const slots = [
      'Öğrenci Velisi',
      'Sınıf Rehber Öğretmeni',
      'Branş Öğretmeni',
      'Rehber Öğretmen',
      'Birim Başkanı',
    ];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final gorev in slots)
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  gorev,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.2),
                ),
                // Elle imzalanacak bos alan, sonra cizgi.
                pw.SizedBox(height: 22),
                pw.Container(
                  height: 0.5,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                  color: PdfColors.blueGrey700,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Adı Soyadı / İmza',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.4),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Tabloya basilacak tarih araligi.
  ///
  /// Ogretmen [BepPlan.startDate] / [BepPlan.endDate] girdiyse onlar
  /// kullanilir. Once tarih SADECE hesaplaniyordu ve bitis her zaman
  /// 31 Mayis'ti; RAM karari donem ortasinda biten bir plan
  /// ongoruyorsa belgeye yazilamiyordu.
  static String planDates(BepPlan plan) {
    final b = plan.startDate.trim();
    final t = plan.endDate.trim();
    if (b.isNotEmpty && t.isNotEmpty) return '$b - $t';
    // Tek tarafi girilmisse otekini hesaptan tamamla.
    final hesap = planDateRange(plan.academicYear, plan.startMonth);
    if (b.isEmpty && t.isEmpty) return hesap;
    final parcalar = hesap.split(' - ');
    final hb = parcalar.isNotEmpty ? parcalar.first : '';
    final ht = parcalar.length > 1 ? parcalar[1] : '';
    return '${b.isNotEmpty ? b : hb} - ${t.isNotEmpty ? t : ht}';
  }

  /// Ogretim yilindan hesaplanan plan tarihi araligi.
  ///
  /// Once kaba bir sabitti: her yil '01.09' - '31.05'. Gercek okul ne
  /// 1 Eylul'de acilir ne 31 Mayis'ta kapanir; belgeye yanlis tarih
  /// giriyordu.
  ///
  /// Artik projede zaten duran MEB hesabi kullaniliyor:
  /// [AppDateFormatter.getAcademicYearStartDate] Eylul'un ikinci
  /// pazartesisini verir, ogretim yili 39 haftadir.
  ///
  /// Plan Eylul disinda bir ayda basliyorsa (donem ortasinda acilan
  /// BEP) o ayin ilk is gunu alinir; bitis yine yilin sonudur.
  static String planDateRange(String academicYear, String startMonth) {
    final parcalar = academicYear.split('-');
    final y1 = int.tryParse(parcalar.isNotEmpty ? parcalar.first : '') ??
        DateTime.now().year;

    // Yilin acilisi ve kapanisi.
    final acilis = AppDateFormatter.getAcademicYearStartDate(
      DateTime(y1, 9, 20),
    );
    // 39. haftanin cumasi: ilk gun pazartesi, +39 hafta -3 gun.
    final kapanis = acilis.add(const Duration(days: 39 * 7 - 3));

    const aylar = {
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
    final ay = aylar[startMonth] ?? 9;

    DateTime baslangic;
    if (ay == 9) {
      baslangic = acilis;
    } else {
      // Eylul disi: o ayin ilk is gunu. Ocak-Mayis ikinci takvim
      // yilina duser.
      final yil = ay >= 9 ? y1 : y1 + 1;
      var g = DateTime(yil, ay, 1);
      while (g.weekday == DateTime.saturday || g.weekday == DateTime.sunday) {
        g = g.add(const Duration(days: 1));
      }
      baslangic = g;
    }

    String iki(int n) => n.toString().padLeft(2, '0');
    String yaz(DateTime t) => '${iki(t.day)}.${iki(t.month)}.${t.year}';
    return '${yaz(baslangic)} - ${yaz(kapanis)}';
  }
}
