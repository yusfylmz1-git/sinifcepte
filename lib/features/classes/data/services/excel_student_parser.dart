import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../../data/models/student_model.dart';

/// SınıfCepte - Excel Dosyalarından Akıllı Öğrenci Ayıklayıcı (Parser)
class ExcelStudentParser {
  /// Excel dosyası seçme ve öğrencileri ayıklama
  static Future<ExcelParseResult> pickAndParseExcel(int targetClassId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return const ExcelParseResult(success: false, errorMessage: 'Dosya seçilmedi');
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final List<StudentModel> studentList = [];

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
        int? colNo, colFirstName, colLastName, colFullName, colGender;

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

          studentList.add(
            StudentModel(
              classId: targetClassId,
              schoolNumber: schoolNo,
              firstName: firstName,
              lastName: lastName,
              gender: gender,
            ),
          );
        }
      }

      return ExcelParseResult(
        success: true,
        students: studentList,
      );
    } catch (e, st) {
      debugPrint('Excel Parse Error: $e\n$st');
      return ExcelParseResult(
        success: false,
        errorMessage: 'Excel okunurken bir hata oluştu: ${e.toString()}',
      );
    }
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
  final List<StudentModel> students;
  final String? errorMessage;

  const ExcelParseResult({
    required this.success,
    this.students = const [],
    this.errorMessage,
  });
}
