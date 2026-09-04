import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/features/classes/data/services/pdf_student_parser.dart';

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
}
