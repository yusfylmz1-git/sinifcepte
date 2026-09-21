import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/features/classes/data/services/pdf_student_parser.dart';
import 'package:sinifcepte/features/classes/data/services/student_file_importer.dart';

/// Öğrenci listesi PDF içe aktarma testleri.
///
/// Bu akış e-Okul'dan indirilen sınıf listesi PDF'ini okuyup öğrencileri
/// çıkarır. Hiç testi yoktu; bozulduğunda öğretmen "liste boş geldi"
/// diyene kadar fark edilmiyordu.
///
/// İki katman ayrı ayrı test edilir:
///   1. PDF okuma (gerçek PDF baytları üretilip `parseBytes` çağrılır)
///   2. Satır ayrıştırma (`extractStudentsFromLines` doğrudan çağrılır)
///
/// Türkçe karakter testleri 2. katmanda yapılır: PDF'in standart
/// Helvetica fontu 'ı', 'ğ', 'İ' harflerini yazamıyor ve sessizce
/// düşürüyor ("Kız" -> "Kz"). Gerçek e-Okul PDF'i gömülü font
/// kullandığı için bu sınırlama yalnızca test kurgusunu ilgilendirir.
void main() {
  /// e-Okul çıktısına benzer bir PDF üretir (yalnızca ASCII güvenli).
  Uint8List buildPdf(List<String> lines, {String? header}) {
    final document = PdfDocument();
    final page = document.pages.add();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final graphics = page.graphics;

    double y = 10;
    if (header != null) {
      graphics.drawString(header, font, bounds: Rect.fromLTWH(10, y, 500, 18));
      y += 26;
    }
    for (final line in lines) {
      graphics.drawString(line, font, bounds: Rect.fromLTWH(10, y, 500, 18));
      y += 18;
    }

    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  group('PDF okuma (uçtan uca)', () {
    test('Standart e-Okul listesi okunur', () {
      final bytes = buildPdf(
        [
          'Sira No   Okul No   Adi Soyadi   Cinsiyet',
          '1   101   AHMET YILMAZ   Erkek',
          '2   102   AYSE DEMIR   Kiz',
          '3   103   MEHMET KAYA   Erkek',
        ],
        header: 'T.C. MILLI EGITIM BAKANLIGI  5/A Sinifi Ogrenci Listesi',
      );

      final result = PdfStudentParser.parseBytes(bytes, 1);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.parsedStudents.length, 3);
      expect(result.parsedStudents.map((s) => s.schoolNumber),
          containsAll(<int>[101, 102, 103]));
    });

    test('Sınıf adı başlıktan çıkarılır', () {
      final bytes = buildPdf(
        ['1   201   ZEYNEP AK   Kiz'],
        header: 'Sinif/Sube: 7/B',
      );

      final result = PdfStudentParser.parseBytes(bytes, 1);
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.detectedClassName, '7-B');
    });

    test('Aynı okul numarası iki kez eklenmez', () {
      final bytes = buildPdf([
        '1   501   AHMET YILMAZ   Erkek',
        '2   501   AHMET YILMAZ   Erkek',
        '3   502   AYSE DEMIR   Kiz',
      ]);

      final result = PdfStudentParser.parseBytes(bytes, 1);
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.parsedStudents.length, 2);
    });
  });

  group('Satır ayrıştırma', () {
    test('Standart satır biçimi okunur', () {
      final students = PdfStudentParser.extractStudentsFromLines([
        '1   101   AHMET YILMAZ   Erkek',
        '2   102   AYŞE DEMİR   Kız',
      ], 1);

      expect(students.length, 2);
      expect(students.first.schoolNumber, 101);
      expect(students.first.gender, 'Erkek');
      expect(students.last.gender, 'Kız');
    });

    test('Türkçe karakterli isimler bozulmaz', () {
      final students = PdfStudentParser.extractStudentsFromLines([
        '1   701   ÇAĞLA ÖZTÜRK   Kız',
        '2   702   İBRAHİM ŞAHİN   Erkek',
        '3   703   GÜLŞAH YILDIZ   Kız',
      ], 1);

      expect(students.length, 3);
      final names =
          students.map((s) => '${s.firstName} ${s.lastName}').join(' ');
      expect(names.contains('?'), isFalse, reason: 'Bozuk karakter: $names');
      expect(names.toLowerCase(), contains('çağla'));
    });

    test('Cinsiyet kısaltmaları (E / K) desteklenir', () {
      final students = PdfStudentParser.extractStudentsFromLines([
        '1   401   HASAN AK   E',
        '2   402   FATMA GUL   K',
      ], 1);

      expect(students.length, 2);
      expect(students.first.gender, 'Erkek');
      expect(students.last.gender, 'Kız');
    });

    test('Çok sınıflı listede her satırın sınıfı ayrılır', () {
      final students = PdfStudentParser.extractStudentsFromLines([
        '5/A   1   601   ALI VELI   Erkek',
        '5/A   2   602   VELI ALI   Erkek',
        '5/B   1   603   AYSE CAN   Kız',
      ], 1);

      expect(students.length, 3);
      expect(students.map((s) => s.className).toSet(), {'5-A', '5-B'});
    });

    test('Başlık satırı öğrenci sayılmaz', () {
      final students = PdfStudentParser.extractStudentsFromLines([
        'Sıra No   Okul No   Adı Soyadı   Cinsiyet',
        '1   101   AHMET YILMAZ   Erkek',
      ], 1);

      expect(students.length, 1);
      expect(students.first.schoolNumber, 101);
    });

    test('Okul numarası olmayan satır atlanır', () {
      final students = PdfStudentParser.extractStudentsFromLines([
        'AHMET YILMAZ   Erkek',
        '1   101   MEHMET KAYA   Erkek',
      ], 1);

      expect(students.map((s) => s.schoolNumber), [101]);
    });

    test('Öğrenci içermeyen metinden liste çıkmaz', () {
      final students = PdfStudentParser.extractStudentsFromLines([
        'Bu bir ders programı belgesidir.',
        'Pazartesi Salı Çarşamba',
      ], 1);

      expect(students, isEmpty);
    });
  });

  group('Sınıf adı tespiti', () {
    test('Yaygın biçimler tanınır', () {
      expect(PdfStudentParser.detectClassNameFrom('Sınıf/Şube: 7/B'), '7-B');
      expect(PdfStudentParser.detectClassNameFrom('5. Sınıf / D Şubesi'), '5-D');
      expect(PdfStudentParser.detectClassNameFrom('12/A Listesi'), '12-A');
    });

    test('KRİTİK: D harfinden sonraki şubeler de tanınır', () {
      // Şube harfi aralığı dar tutulursa E, F, G... şubeler sessizce
      // tanınmaz ve sınıf adı boş kalır.
      for (final branch in ['E', 'F', 'G', 'H', 'K']) {
        expect(PdfStudentParser.detectClassNameFrom('Sınıf/Şube: 6/$branch'),
            '6-$branch',
            reason: '$branch şubesi tanınmadı');
      }
    });

    test('Sınıf bilgisi yoksa boş döner', () {
      expect(PdfStudentParser.detectClassNameFrom('Ders Programı'), '');
    });
  });

  group('Hata durumları', () {
    test('Boş PDF anlaşılır hata döndürür, çökmez', () {
      final result = PdfStudentParser.parseBytes(buildPdf([]), 1);
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotEmpty);
    });

    test('Öğrenci içermeyen PDF anlaşılır hata döndürür', () {
      final bytes = buildPdf(['Bu bir ders programi belgesidir.']);
      final result = PdfStudentParser.parseBytes(bytes, 1);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('algılanamadı'));
    });

    test('Bozuk dosya çökme yerine hata döndürür', () {
      final bytes = Uint8List.fromList('bu bir pdf degil'.codeUnits);
      final result = PdfStudentParser.parseBytes(bytes, 1);
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotEmpty);
    });
  });

  group('UYDURMA ŞUBE — gerçek e-Okul çıktısı', () {
    // Sahada bulundu (21 Eylül 2026). Kullanıcı Mimar Sinan Ortaokulu
    // 5/A listesini içe aktardı ve ekranda şunu gördü:
    //
    //   "Çoklu Sınıf Dağıtımı (25 Şube)"
    //   7-H, 2-G, 3-V, 6-B, 1-İ, 4-F, 4-N, 8-T, 6-F, 2-Ş, ...
    //
    // PDF'te TEK şube var: "5. Sınıf / A Şubesi".
    //
    // Sebep: desen sayı ile harf arasında BOŞLUĞU da ayırıcı sayıyordu
    // (`[\/\-\s]`). Öğrenci satırlarından şube türetiyordu:
    //
    //   `2  86  ÖMER  DEMİR  Erkek`     -> 6-Ö
    //   `17  297  HÜSEYİN EFE  AKBAY`   -> 7-H
    //   `25  358  İKRA ALEYNA  NERGİS`  -> 8-İ
    //
    // Ölçüldü: 26 öğrencinin 6'sı yanlış eşleşiyordu.
    //
    // Mevcut testler bunu kaçırmıştı çünkü ne çoklu şube tespitini ne
    // de gerçek öğrenci adlarını deniyorlardı.

    /// Ekran görüntüsündeki listenin birebir kopyası.
    const gercekSatirlar = [
      'T.C.',
      'SİİRT VALİLİĞİ',
      'Merkez / Mimar Sinan Ortaokulu Müdürlüğü',
      '5. Sınıf / A Şubesi Sınıf Listesi',
      'Sınıf Öğretmeni: SELMAN KEZER',
      'Sınıf Müdür Yrd: MEHMET KIZILTOPRAK',
      'S.No Öğrenci No Adı Soyadı Cinsiyeti',
      '1 23 ABDULLATİF EYMEN DİLDİRİM Erkek',
      '2 86 ÖMER DEMİR Erkek',
      '3 121 ŞİRİN ŞAVLİ Kız',
      '4 133 AİŞE HÜMA EVİZ Kız',
      '5 172 BÜŞRA NAZ SARI Kız',
      '6 215 ASMİN ZELAL YILDIRIM Kız',
      '7 242 ECRİN OKTAY Kız',
      '8 248 BEHİYE KAPLAN Kız',
      '9 249 NUBİHAR AŞKARA Kız',
      '10 257 MUHAMMED AMMAR AYDIN Erkek',
      '11 263 MUHAMMED HÜSEYİN EYMEN ARSLAN Erkek',
      '12 267 HAYDAR ÇELİK Erkek',
      '13 269 MAHMUT MİRHAN AYDIN Erkek',
      '14 274 ELİF SÜTÇÜ Kız',
      '15 288 MAHİR RONİ ÖZER Erkek',
      '16 295 EYMEN AZİZ IRMAK Erkek',
      '17 297 HÜSEYİN EFE AKBAY Erkek',
      '18 309 YAĞMUR İLBAŞ Kız',
      '19 315 POYRAZ ADIGÜZEL Erkek',
      '20 327 ALİ EYMEN ULAŞ Erkek',
      '21 330 YUSUF EMRE AKBAY Erkek',
      '22 331 ZELAL KAYRAN Kız',
      '23 355 ROJİN TAŞ Kız',
      '24 356 SÜMEYRA MARANGOZ Kız',
      '25 358 İKRA ALEYNA NERGİS Kız',
      '26 359 MUHAMMED SALİH KALKAN Erkek',
      'Kız Öğrenci Sayısı : 13 Erkek Öğrenci Sayısı : 13 Toplam Öğrenci Sayısı : 26',
    ];

    test('KRİTİK: öğrenci satırından şube UYDURULMUYOR', () {
      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        gercekSatirlar,
        1,
      );

      // Hepsi BAŞLIKTAKİ şubeye ait olmalı: 5-A.
      //
      // Bu beklenti 22 Eylül'de değişti. Önce "hiç şube atanmamalı"
      // yazılıydı çünkü uydurma şubeler engellenmişti; ama o zaman
      // çok şubeli dosyada B/C şubeleri de ayırt edilemiyordu
      // (kullanıcı bildirdi: "sadece 5/A algılandı"). Artık son
      // görülen BAŞLIK sonraki öğrencilere uygulanıyor.
      final atananSubeler = ogrenciler
          .map((o) => o.className)
          .where((c) => c != null && c.isNotEmpty)
          .toSet();

      expect(
        atananSubeler,
        {'5-A'},
        reason: 'başlıktaki şube öğrencilere uygulanmalı, '
            'satırlardan UYDURULMAMALI',
      );
    });

    test('KRİTİK: 26 öğrencinin hepsi okunuyor', () {
      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        gercekSatirlar,
        1,
      );
      expect(ogrenciler, hasLength(26));
    });

    test('KRİTİK: başlıktan doğru şube okunuyor', () {
      // Tek şube: 5-A. "25 şube" değil.
      expect(
        PdfStudentParser.detectClassNameFrom(gercekSatirlar.join('\n')),
        '5-A',
      );
    });

    test('öğrenci adları ve numaraları doğru', () {
      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        gercekSatirlar,
        1,
      );

      final ilk = ogrenciler.first;
      expect(ilk.schoolNumber, 23);

      // Ad "Abdullatif Eymen" olarak saklanıyor, "ABDULLATİF" değil.
      //
      // e-Okul listeleri TAMAMEN büyük harf; biçimlendirici bunu
      // normal yazıma çeviriyor. Türkçe'de `İ`'nin küçüğü `i`
      // olduğu için `ABDULLATİF` -> `Abdullatif` DOĞRU sonuçtur;
      // büyük harf bilgisi geri getirilemez ve getirilmesi de
      // gerekmiyor.
      //
      // `AYDIN` -> `Aydın` (noktasız ı) aynı kuralın sonucu ve o da
      // doğru: `I`'nın küçüğü `ı`.
      expect(ilk.firstName, 'Abdullatif Eymen');
      expect(ilk.lastName, 'Dildirim');

      final son = ogrenciler.last;
      expect(son.schoolNumber, 359);
      expect(son.lastName, 'Kalkan');
    });

    test('cinsiyet dağılımı PDF alt toplamıyla uyuşuyor', () {
      // PDF'in kendi alt toplamı: 13 kız, 13 erkek. Ayrıştırma bunu
      // tutmuyorsa satırlar kaymış demektir.
      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        gercekSatirlar,
        1,
      );

      final kiz = ogrenciler.where((o) => o.gender == 'Kız').length;
      final erkek = ogrenciler.where((o) => o.gender == 'Erkek').length;

      expect(kiz, 13);
      expect(erkek, 13);
    });
  });

  group('Şube deseni — sayı+harf tuzağı', () {
    test('KRİTİK: öğrenci numarası + isim şube sayılmıyor', () {
      // Bunların HİÇBİRİ şube değil.
      for (final satir in [
        '2 86 ÖMER DEMİR Erkek',
        '17 297 HÜSEYİN EFE AKBAY Erkek',
        '25 358 İKRA ALEYNA NERGİS Kız',
        '4 133 AİŞE HÜMA EVİZ Kız',
        '5 172 BÜŞRA NAZ SARI Kız',
        '24 356 SÜMEYRA MARANGOZ Kız',
      ]) {
        expect(
          PdfStudentParser.detectClassNameFrom(satir),
          isEmpty,
          reason: 'şube uydurdu: $satir',
        );
      }
    });

    test('gerçek başlık biçimleri okunuyor', () {
      final beklenen = {
        '5. Sınıf / A Şubesi Sınıf Listesi': '5-A',
        '6 . Sınıf / A Şubesi': '6-A',
        '6.Sınıf/C Subesi': '6-C',
        '5. Sınıf D Şubesi': '5-D',
        '7. Sınıf / B Şubesi': '7-B',
        '10. Sınıf / K Şubesi': '10-K',
        '5/A': '5-A',
        '8-C': '8-C',
        '12/F': '12-F',
      };

      beklenen.forEach((girdi, cikti) {
        expect(
          PdfStudentParser.detectClassNameFrom(girdi),
          cikti,
          reason: girdi,
        );
      });
    });

    test('Türkçe şube harfleri okunuyor', () {
      // Ş, Ç, Ğ, Ü, Ö, İ şubeleri var olan okullar mevcut.
      for (final harf in ['Ş', 'Ç', 'Ğ', 'Ü', 'Ö', 'İ']) {
        expect(
          PdfStudentParser.detectClassNameFrom('7. Sınıf / $harf Şubesi'),
          '7-$harf',
        );
      }
    });
  });

  group('Eski .xls — anlaşılır yönlendirme', () {
    // Sahada yaşandı (21 Eylül 2026): öğretmen e-Okul'dan indirdiği
    // Excel'i seçti ve şunu gördü:
    //
    //   Unsupported operation: Excel format unsupported.
    //   Only .xlsx files are supported
    //
    // Mesaj paketten geliyordu, İngilizceydi ve ne yapılacağını
    // söylemiyordu. `excel` paketi Excel 97-2003'ü okuyamıyor; bu bir
    // paket sınırı, kodda çözülemez. Ama YÖNLENDİRME verilebilir.

    /// OLE Compound imzası — Excel 97-2003 dosyalarının başı.
    Uint8List eskiXlsBaytlari() {
      final b = Uint8List(512);
      b[0] = 0xD0;
      b[1] = 0xCF;
      b[2] = 0x11;
      b[3] = 0xE0;
      b[4] = 0xA1;
      b[5] = 0xB1;
      b[6] = 0x1A;
      b[7] = 0xE1;
      return b;
    }

    test('KRİTİK: eski .xls ayrı biçim olarak tanınıyor', () {
      expect(
        StudentFileImporter.detectFormatFromBytes(eskiXlsBaytlari()),
        StudentFileFormat.eskiExcel,
        reason: 'excel olarak işaretlenirse pakete gider ve '
            'anlaşılmaz hata döner',
      );
    });

    test('KRİTİK: .xlsx hâlâ normal Excel sayılıyor', () {
      // ZIP imzası (PK).
      final xlsx = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);
      expect(
        StudentFileImporter.detectFormatFromBytes(xlsx),
        StudentFileFormat.excel,
      );
    });

    test('KRİTİK: mesaj NE YAPILACAĞINI söylüyor', () {
      final sonuc = StudentFileImporter.parseBytes(
        eskiXlsBaytlari(),
        1,
        StudentFileFormat.eskiExcel,
      );

      expect(sonuc.success, isFalse);
      final mesaj = sonuc.errorMessage ?? '';

      // İki çözüm yolu da yazılı olmalı; "desteklenmiyor" demek
      // öğretmene yol göstermiyordu.
      expect(mesaj, contains('PDF'));
      expect(mesaj, contains('.xlsx'));
      // İngilizce paket mesajı görünmemeli.
      expect(mesaj, isNot(contains('Unsupported')));
    });

    test('eski .xls çökmüyor', () {
      // Pakete hiç gitmediği için istisna atmamalı.
      expect(
        () => StudentFileImporter.parseBytes(
          eskiXlsBaytlari(),
          1,
          StudentFileFormat.eskiExcel,
        ),
        returnsNormally,
      );
    });
  });

  group('COK SUBELI dosya — her sayfa kendi subesi', () {
    // Kullanici bildirdi (22 Eylul 2026): "pdf sinif icin yuklerken
    // sadece 5/A sinifi algilandi, digerlerini almadi."
    //
    // e-Okul cok subeli dosyada her sayfaya kendi basligini basiyor.
    // Sube YALNIZCA baslikta geciyor; ogrenci satirlarinda yok. Eski
    // surum her satiri kendi basina okuyordu, yani baslik bilgisi
    // sonraki ogrencilere tasinmiyordu.

    const cokSubeli = [
      '5. Sınıf / A Şubesi Sınıf Listesi',
      'S.No Öğrenci No Adı Soyadı Cinsiyeti',
      '1 23 ABDULLATİF EYMEN DİLDİRİM Erkek',
      '2 86 ÖMER DEMİR Erkek',
      '3 121 ŞİRİN ŞAVLİ Kız',
      'Kız Öğrenci Sayısı : 1 Erkek Öğrenci Sayısı : 2',
      '5. Sınıf / B Şubesi Sınıf Listesi',
      'S.No Öğrenci No Adı Soyadı Cinsiyeti',
      '1 24 ELİF EREKİNCİ Kız',
      '2 111 ABDULLAH GÖNCÜ Erkek',
      '3 169 BERFİN BİŞKİN Kız',
      '5. Sınıf / C Şubesi Sınıf Listesi',
      '1 300 ARAS ARGEŞ TİLKİ Erkek',
    ];

    test('KRITIK: UC sube ayri ayri taniniyor', () {
      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        cokSubeli,
        1,
      );

      final subeler = ogrenciler.map((o) => o.className).toSet();
      expect(subeler, {'5-A', '5-B', '5-C'});
    });

    test('KRITIK: her ogrenci DOGRU subeye atanmis', () {
      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        cokSubeli,
        1,
      );

      String? subeOf(int no) => ogrenciler
          .firstWhere((o) => o.schoolNumber == no)
          .className;

      // A subesi
      expect(subeOf(23), '5-A');
      expect(subeOf(86), '5-A');
      expect(subeOf(121), '5-A');
      // B subesi — baslik degisti
      expect(subeOf(24), '5-B');
      expect(subeOf(111), '5-B');
      expect(subeOf(169), '5-B');
      // C subesi
      expect(subeOf(300), '5-C');
    });

    test('ogrenci sayisi dogru (alt toplam satiri haric)', () {
      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        cokSubeli,
        1,
      );
      expect(ogrenciler, hasLength(7));
    });
  });

  group('TUM DUZEYLER — ilkokul, ortaokul, lise, hazirlik, anasinifi', () {
    // Kullanici bildirdi (22 Eylul 2026): "sadece 5/A 5/B degil tum
    // okulun subeleri var 5-8 arasi. bu lisede Hazirlik 9-12 olabilir."
    // ve "okul oncesi de olabilir anasinifta olabilir".
    //
    // Olculdu: 1-12 calisiyordu ama HAZIRLIK ve ANASINIFI hic
    // taninmiyordu — desen `[1-9]|1[0-2]` bekliyordu. O sayfanin
    // ogrencileri subesiz kaliyor ve cok subeli dosyada onceki
    // subeye yaziliyordu.

    test('KRITIK: ilkokul + ortaokul (1-8)', () {
      for (var s = 1; s <= 8; s++) {
        expect(
          PdfStudentParser.detectClassNameFrom('$s. Sınıf / A Şubesi'),
          '$s-A',
        );
      }
    });

    test('KRITIK: lise (9-12)', () {
      for (var s = 9; s <= 12; s++) {
        expect(
          PdfStudentParser.detectClassNameFrom('$s. Sınıf / B Şubesi'),
          '$s-B',
        );
      }
    });

    test('KRITIK: HAZIRLIK sinifi (lisede 9-12 oncesi)', () {
      const beklenen = {
        'Hazırlık Sınıfı / A Şubesi': 'HZ-A',
        'Hazırlık / B Şubesi': 'HZ-B',
        'HAZIRLIK SINIFI C ŞUBESİ': 'HZ-C',
        'Hazirlik Sinifi / D Subesi': 'HZ-D',
      };
      beklenen.forEach((girdi, cikti) {
        expect(
          PdfStudentParser.detectClassNameFrom(girdi),
          cikti,
          reason: girdi,
        );
      });
    });

    test('KRITIK: ANASINIFI / OKUL ONCESI', () {
      // e-Okul bazi okullarda "Okul Oncesi", bazisinda "Anasinifi"
      // basiyor; ikisi ayni duzey.
      const beklenen = {
        'Anasınıfı / A Şubesi': 'AN-A',
        'Ana Sınıf / B Şubesi': 'AN-B',
        'Okul Öncesi / C Şubesi': 'AN-C',
        'Okul Öncesi D Şubesi': 'AN-D',
      };
      beklenen.forEach((girdi, cikti) {
        expect(
          PdfStudentParser.detectClassNameFrom(girdi),
          cikti,
          reason: girdi,
        );
      });
    });

    test('KRITIK: ogrenci satiri hala temiz', () {
      // Yeni desenler uydurma sube uretmeye baslamamali.
      for (final satir in [
        '1 23 ABDULLATİF EYMEN DİLDİRİM Erkek',
        '2 86 ÖMER DEMİR Erkek',
        '17 297 HÜSEYİN EFE AKBAY Erkek',
      ]) {
        expect(
          PdfStudentParser.detectClassNameFrom(satir),
          isEmpty,
          reason: satir,
        );
      }
    });

    test('ortaokul cok subeli dosya: 5-8 arasi hepsi ayri', () {
      // Sekiz sube (5-A .. 8-B), her birinde bir ogrenci.
      const satirlar = [
        '5. Sınıf / A Şubesi Sınıf Listesi',
        '1 501 AHMET YILMAZ Erkek',
        '5. Sınıf / B Şubesi Sınıf Listesi',
        '1 502 AYSE DEMIR Kız',
        '6. Sınıf / A Şubesi Sınıf Listesi',
        '1 601 MEHMET KAYA Erkek',
        '6. Sınıf / B Şubesi Sınıf Listesi',
        '1 602 FATMA SAHIN Kız',
        '7. Sınıf / A Şubesi Sınıf Listesi',
        '1 701 ALI CELIK Erkek',
        '7. Sınıf / B Şubesi Sınıf Listesi',
        '1 702 ZEYNEP ARSLAN Kız',
        '8. Sınıf / A Şubesi Sınıf Listesi',
        '1 801 MUSTAFA AYDIN Erkek',
        '8. Sınıf / B Şubesi Sınıf Listesi',
        '1 802 ELIF OZER Kız',
      ];

      final ogrenciler = PdfStudentParser.extractStudentsFromLines(
        satirlar,
        1,
      );

      expect(ogrenciler, hasLength(8));

      final subeler = ogrenciler.map((o) => o.className).toSet();
      expect(subeler, hasLength(8), reason: 'sube: $subeler');
      expect(subeler, contains('5-A'));
      expect(subeler, contains('8-B'));

      // Her ogrenci DOGRU subede.
      String? subeOf(int no) =>
          ogrenciler.firstWhere((o) => o.schoolNumber == no).className;
      expect(subeOf(501), '5-A');
      expect(subeOf(802), '8-B');
  });
  });
}
