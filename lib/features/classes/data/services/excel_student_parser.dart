import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../../../../data/models/student_model.dart';
import 'pdf_student_parser.dart';

/// SınıfCepte - Excel Dosyalarından Akıllı Öğrenci Ayıklayıcı (Parser)
class ExcelStudentParser {
  /// Doğrudan baytlardan ayrıştırma (dosya seçimi olmadan).
  ///
  /// Dosya seçme ile ayrıştırma iç içeydi; bu yüzden ne test edilebiliyor
  /// ne de ortak içe aktarma akışından çağrılabiliyordu.
  static ExcelParseResult parseBytes(Uint8List bytes, int targetClassId) {
    try {
      final excel = Excel.decodeBytes(bytes);

      final List<StudentModel> studentList = [];
      final List<ParsedStudentItem> parsedStudentList = [];

      for (final tableKey in excel.tables.keys) {
        final rows = excel.tables[tableKey]!.rows;
        if (rows.length < 2) continue;

        // Header (Başlık) Satırını bul (İlk satır olmak zorunda değil, tarayarak bul)
        List<Data?>? headerRow;
        int headerIndex = 0;
        
        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          final rowString = row.map((c) => c?.value?.toString().toLowerCase() ?? '').join(' ');
          if (rowString.contains('ad') || rowString.contains('isim') || rowString.contains('no') || rowString.contains('cinsiyet')) {
            headerRow = row;
            headerIndex = i;
            break;
          }
        }

        if (headerRow == null) continue; // Başlık bulunamadıysa bu sayfayı atla
        int? colNo, colFirstName, colLastName, colFullName, colGender, colClassName;

        for (int i = 0; i < headerRow.length; i++) {
          var cellValue = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
          cellValue = _normalizeText(cellValue);

          if ((cellValue.contains('no') || cellValue.contains('numara')) &&
              !cellValue.contains('sira')) {
            colNo = i;
          } else if (cellValue == 'ad' || cellValue == 'isim' || cellValue == 'adi') {
            colFirstName = i;
          } else if (cellValue == 'soyad' || cellValue == 'soyisim') {
            colLastName = i;
          } else if (cellValue.contains('ad soyad') || cellValue.contains('adsoyad') || cellValue.contains('isim soyisim')) {
            colFullName = i;
          } else if (cellValue.contains('cinsiyet') || cellValue.contains('gender')) {
            colGender = i;
          } else if (cellValue.contains('sinif') || cellValue.contains('sube')) {
            colClassName = i;
          }
        }

        // Eğer başlık bulunamadıysa varsayılan 0: No, 1: Ad, 2: Soyad / Ad Soyad tara
        colNo ??= 0;
        if (colFirstName == null && colLastName == null && colFullName == null) {
          colFullName = 1;
        }

        // Öğrenci satırlarını oku
        for (final row in rows.skip(headerIndex + 1)) {
          if (row.isEmpty) continue;

          String rawNo = colNo < row.length ? row[colNo]?.value?.toString().trim() ?? '' : '';
          // Sadece rakamları al
          rawNo = rawNo.replaceAll(RegExp(r'[^\d]'), '');
          final schoolNo = int.tryParse(rawNo);
          if (schoolNo == null) continue;

          String firstName = '';
          String lastName = '';

          if (colFullName != null && colFullName < row.length) {
            final fullNameRaw = row[colFullName]?.value?.toString().trim() ?? '';
            final parts = fullNameRaw.split(RegExp(r'\s+'));
            if (parts.length > 1) {
              lastName = parts.last;
              firstName = parts.sublist(0, parts.length - 1).join(' ');
            } else {
              firstName = fullNameRaw;
            }
          } else {
            firstName = colFirstName != null && colFirstName < row.length
                ? row[colFirstName]?.value?.toString().trim() ?? ''
                : '';
            lastName = colLastName != null && colLastName < row.length
                ? row[colLastName]?.value?.toString().trim() ?? ''
                : '';
          }

          if (firstName.isEmpty) continue;

          // Cinsiyet ayıkla
          String gender = 'Erkek';
          if (colGender != null && colGender < row.length) {
            final rawGender = row[colGender]?.value?.toString().trim().toLowerCase() ?? '';
            if (rawGender.contains('kız') || rawGender.contains('kiz') || rawGender == 'k' || rawGender == 'f') {
              gender = 'Kız';
            }
          }

          // Sınıf ayıkla (varsa)
          String? rowClass;
          if (colClassName != null && colClassName < row.length) {
            final rawClass = row[colClassName]?.value?.toString().trim() ?? '';
            rowClass = _extractClassFromText(rawClass);
          }

          studentList.add(
            StudentModel(
              classId: targetClassId,
              schoolNumber: schoolNo,
              firstName: firstName,
              lastName: lastName,
              gender: gender,
            ),
          );

          parsedStudentList.add(
            ParsedStudentItem(
              schoolNumber: schoolNo,
              firstName: firstName,
              lastName: lastName,
              gender: gender,
              className: rowClass,
            ),
          );
        }
      }

      String detectedClassName = _detectClassName(excel);

      // Hiç öğrenci çıkmadıysa bu bir başarı değildir. Eskiden boş liste
      // ile 'success: true' dönüyordu; ekran "içe aktarıldı" deyip boş
      // önizleme gösteriyor, öğretmen neyin yanlış gittiğini anlamıyordu.
      // (PDF ayrıştırıcıda bu kontrol vardı, Excel'de yoktu.)
      if (parsedStudentList.isEmpty) {
        return const ExcelParseResult(
          success: false,
          errorMessage:
              'Excel okundu ancak öğrenci listesi algılanamadı. '
              'Dosyada "Okul No", "Adı", "Soyadı" gibi başlık satırı '
              'bulunduğundan emin olun.',
        );
      }

      final distinctClasses = parsedStudentList
          .map((s) => s.className)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final bool isMultiClass = distinctClasses.length > 1;
      if (detectedClassName.isEmpty && distinctClasses.length == 1) {
        detectedClassName = distinctClasses.first;
      }

      return ExcelParseResult(
        success: true,
        detectedClassName: detectedClassName,
        parsedStudents: parsedStudentList,
        students: studentList,
        isMultiClass: isMultiClass,
        distinctClasses: distinctClasses,
      );
    } catch (e, st) {
      debugPrint('Excel Parse Error: $e\n$st');
      return ExcelParseResult(
        success: false,
        errorMessage: 'Excel okunurken bir hata oluştu: ${e.toString()}',
      );
    }
  }

  static String? _extractClassFromText(String text) {
    final mebPattern = RegExp(
      r'([1-9]|1[0-2])\s*\.?\s*(?:Sınıfı?|Sinifi?)?\s*[\/\-\s]\s*([A-Za-zğüşöçıİĞÜŞÖÇ])\s*(?:Şubesi|Subesi|Şube|Sube)?\b',
      caseSensitive: false,
    );
    final match = mebPattern.firstMatch(text);
    if (match != null) {
      final grade = match.group(1);
      final branch = match.group(2)?.toUpperCase();
      if (grade != null && branch != null) {
        return '$grade-$branch';
      }
    }
    return null;
  }

  static String _detectClassName(Excel excel) {
    // 1. Sayfa isimlerini kontrol et (Örn: "5-A", "5/A", "7B")
    for (final sheetName in excel.tables.keys) {
      final match = RegExp(r'([1-9]|1[0-2])\s*[\/\-\s]?\s*([A-Za-zğüşöçıİĞÜŞÖÇ])\b').firstMatch(sheetName);
      if (match != null) {
        final grade = match.group(1);
        final branch = match.group(2)?.toUpperCase();
        if (grade != null && branch != null) {
          return '$grade-$branch';
        }
      }
    }

    // 2. İlk 5 satırdaki metinleri kontrol et
    for (final tableKey in excel.tables.keys) {
      final rows = excel.tables[tableKey]!.rows;
      for (int i = 0; i < rows.length && i < 5; i++) {
        final rowStr = rows[i].map((c) => c?.value?.toString() ?? '').join(' ');
        final match = RegExp(r'(?:Sınıfı?|Şubesi?)?\s*[:|-]?\s*([1-9]|1[0-2])\s*[\/\-\s]\s*([A-Za-zğüşöçıİĞÜŞÖÇ])\b', caseSensitive: false).firstMatch(rowStr);
        if (match != null) {
          final grade = match.group(1);
          final branch = match.group(2)?.toUpperCase();
          if (grade != null && branch != null) {
            return '$grade-$branch';
          }
        }
      }
    }
    return '';
  }

  static String _normalizeText(String input) {
    return input
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }
}

class ExcelParseResult {
  final bool success;
  final String detectedClassName;
  final List<ParsedStudentItem> parsedStudents;
  final List<StudentModel> students;
  final String? errorMessage;
  final bool isMultiClass;
  final List<String> distinctClasses;

  const ExcelParseResult({
    required this.success,
    this.detectedClassName = '',
    this.parsedStudents = const [],
    this.students = const [],
    this.errorMessage,
    this.isMultiClass = false,
    this.distinctClasses = const [],
  });
}

