import 'dart:typed_data';
import 'dart:ui';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/features/classes/data/services/student_file_importer.dart';

/// Ortak öğrenci içe aktarma çerçevesi testleri.
///
/// Öğretmen e-Okul'dan listeyi PDF olarak da Excel olarak da indirebiliyor.
/// Önceden ekran yalnızca PDF açıyordu; `ExcelStudentParser` yazılmış ama
/// hiçbir yerden çağrılmıyordu (ölü kod). Artık tek seçici iki biçimi de
/// kabul ediyor ve biçim uzantıdan anlaşılıyor.
void main() {
  /// e-Okul benzeri PDF üretir (standart font Türkçe 'ı/ğ/İ' yazamadığı
  /// için ASCII güvenli metin kullanılır).
  Uint8List buildPdf(List<String> lines) {
    final document = PdfDocument();
    final page = document.pages.add();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    double y = 10;
    for (final line in lines) {
      page.graphics
          .drawString(line, font, bounds: Rect.fromLTWH(10, y, 500, 18));
      y += 18;
    }
    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  /// e-Okul benzeri Excel üretir.
  Uint8List buildExcel(List<List<String>> rows) {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    for (final row in rows) {
      sheet.appendRow(row.map<CellValue?>(TextCellValue.new).toList());
    }
    return Uint8List.fromList(excel.save()!);
  }

  group('Biçim tespiti', () {
    test('Uzantıdan doğru biçim seçilir', () {
      expect(StudentFileImporter.detectFormat('/tmp/liste.pdf'),
          StudentFileFormat.pdf);
      expect(StudentFileImporter.detectFormat('/tmp/liste.xlsx'),
          StudentFileFormat.excel);
      expect(StudentFileImporter.detectFormat('/tmp/liste.xls'),
          StudentFileFormat.excel);
    });

    test('Büyük harfli uzantılar da tanınır', () {
      expect(StudentFileImporter.detectFormat('C:/Liste.PDF'),
          StudentFileFormat.pdf);
      expect(StudentFileImporter.detectFormat('C:/Liste.XLSX'),
          StudentFileFormat.excel);
    });

    test('Desteklenmeyen uzantı null döner', () {
      expect(StudentFileImporter.detectFormat('/tmp/liste.docx'), isNull);
      expect(StudentFileImporter.detectFormat('/tmp/liste.txt'), isNull);
      expect(StudentFileImporter.detectFormat('/tmp/liste'), isNull);
    });

    test('Seçicide her iki biçim de sunulur', () {
      expect(StudentFileImporter.supportedExtensions,
          containsAll(<String>['pdf', 'xlsx', 'xls']));
    });
  });

  group('PDF içe aktarma', () {
    test('PDF listesi ortak sonuç tipine dönüşür', () {
      final bytes = buildPdf([
        '1   101   AHMET YILMAZ   Erkek',
        '2   102   AYSE DEMIR   Kiz',
      ]);

      final result = StudentFileImporter.parseBytes(
          bytes, 1, StudentFileFormat.pdf);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.parsedStudents.length, 2);
      expect(result.format, StudentFileFormat.pdf);
    });
  });

  group('Excel içe aktarma', () {
    test('KRİTİK: Excel listesi okunur (önceden hiç çağrılmıyordu)', () {
      final bytes = buildExcel([
        ['Okul No', 'Adı', 'Soyadı', 'Cinsiyet'],
        ['101', 'AHMET', 'YILMAZ', 'Erkek'],
        ['102', 'AYŞE', 'DEMİR', 'Kız'],
        ['103', 'MEHMET', 'KAYA', 'Erkek'],
      ]);

      final result = StudentFileImporter.parseBytes(
          bytes, 1, StudentFileFormat.excel);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.parsedStudents.length, 3);
      expect(result.format, StudentFileFormat.excel);
      expect(result.parsedStudents.map((s) => s.schoolNumber),
          containsAll(<int>[101, 102, 103]));
    });

    test('Excel Türkçe karakterleri korur', () {
      final bytes = buildExcel([
        ['Okul No', 'Adı', 'Soyadı', 'Cinsiyet'],
        ['201', 'ÇAĞLA', 'ÖZTÜRK', 'Kız'],
        ['202', 'İBRAHİM', 'ŞAHİN', 'Erkek'],
      ]);

      final result = StudentFileImporter.parseBytes(
          bytes, 1, StudentFileFormat.excel);

      expect(result.success, isTrue, reason: result.errorMessage);
      final names =
          result.parsedStudents.map((s) => '${s.firstName} ${s.lastName}').join(' ');
      expect(names.contains('?'), isFalse, reason: 'Bozuk karakter: $names');
      expect(names.toLowerCase(), contains('çağla'));
    });

    test('Tek sütunda "Adı Soyadı" biçimi de okunur', () {
      final bytes = buildExcel([
        ['No', 'Adı Soyadı', 'Cinsiyet'],
        ['301', 'ALİ VELİ', 'Erkek'],
        ['302', 'ZEYNEP AK', 'Kız'],
      ]);

      final result = StudentFileImporter.parseBytes(
          bytes, 1, StudentFileFormat.excel);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.parsedStudents.length, 2);
    });

    test('Öğrenci içermeyen Excel anlaşılır hata döndürür', () {
      final bytes = buildExcel([
        ['Ders Programı'],
        ['Pazartesi', 'Salı'],
      ]);

      final result = StudentFileImporter.parseBytes(
          bytes, 1, StudentFileFormat.excel);

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotEmpty);
    });
  });

  group('Ortak davranış', () {
    test('İki biçim de aynı sonuç tipini üretir', () {
      final pdf = StudentFileImporter.parseBytes(
        buildPdf(['1   101   AHMET YILMAZ   Erkek']),
        1,
        StudentFileFormat.pdf,
      );
      final excel = StudentFileImporter.parseBytes(
        buildExcel([
          ['Okul No', 'Adı', 'Soyadı', 'Cinsiyet'],
          ['101', 'AHMET', 'YILMAZ', 'Erkek'],
        ]),
        1,
        StudentFileFormat.excel,
      );

      expect(pdf.success, isTrue, reason: pdf.errorMessage);
      expect(excel.success, isTrue, reason: excel.errorMessage);
      expect(pdf.parsedStudents.first.schoolNumber,
          excel.parsedStudents.first.schoolNumber);
    });

    test('İptal, hata olarak gösterilmez', () {
      const cancelled = StudentImportResult(
        success: false,
        errorMessage: 'Dosya seçilmedi',
      );
      expect(cancelled.isCancelled, isTrue);

      const failure = StudentImportResult(
        success: false,
        errorMessage: 'PDF okunamadı (görüntü tabanlı olabilir).',
      );
      expect(failure.isCancelled, isFalse);
    });

    test('Bozuk dosya çökme yerine hata döndürür', () {
      final bytes = Uint8List.fromList('bozuk icerik'.codeUnits);
      for (final format in StudentFileFormat.values) {
        final result = StudentFileImporter.parseBytes(bytes, 1, format);
        expect(result.success, isFalse,
            reason: '${format.label} bozuk dosyada basarili dondu');
        expect(result.errorMessage, isNotEmpty);
      }
    });
  });
}
