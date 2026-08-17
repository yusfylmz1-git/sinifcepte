import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../data/models/student_model.dart';

/// SınıfCepte - Layout-Aware (Koordinat Bazlı) Gelişmiş PDF Ayıklayıcı
/// `pdf-inspector` mantığıyla tablo hücrelerini görsel Y koordinatına göre gruplar.
class PdfStudentParser {
  /// PDF dosyasından sınıf adı ve öğrenci listesini çekme
  static Future<PdfParseResult> pickAndParsePdf(int targetClassId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return const PdfParseResult(success: false, errorMessage: 'PDF dosyası seçilmedi');
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      // Syncfusion PDF Document Aç
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      
      // Düz metin (Sınıf adını bulmak için)
      final String rawText = extractor.extractText();
      String detectedClassName = _detectClassName(rawText);

      // KOORDİNAT BAZLI (Layout-Aware) Satır Satır Çıkarma
      final List<TextLine> textLines = extractor.extractTextLines();
      document.dispose();

      if (textLines.isEmpty && rawText.trim().isEmpty) {
        return const PdfParseResult(
          success: false,
          errorMessage: 'PDF metni okunamadı veya dosya boş (Görüntü tabanlı PDF olabilir).',
        );
      }

      // 1. TextLine nesnelerini Y (top) koordinatlarına göre grupla
      List<List<TextLine>> groupedRows = [];
      const double yTolerance = 5.0; // Aynı satırda sayılabilmeleri için esneklik payı

      for (var line in textLines) {
        bool added = false;
        for (var row in groupedRows) {
          if ((row.first.bounds.top - line.bounds.top).abs() <= yTolerance) {
            row.add(line);
            added = true;
            break;
          }
        }
        if (!added) {
          groupedRows.add([line]);
        }
      }

      // 2. Satırları Y eksenine göre yukarıdan aşağıya sırala
      groupedRows.sort((a, b) => a.first.bounds.top.compareTo(b.first.bounds.top));

      // 3. Her satırın kendi içindeki kelimelerini X eksenine göre soldan sağa sırala
      for (var row in groupedRows) {
        row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      }

      // 4. Tablo satırlarını metne dönüştür
      List<String> structuredLines = groupedRows.map((row) {
        return row.map((cell) => cell.text.trim()).join('   ');
      }).toList();

      // 5. Öğrencileri Çıkar
      final List<StudentModel> studentList = _extractStudentsFromStructuredLines(structuredLines, targetClassId);

      if (studentList.isEmpty) {
        final debugLines = structuredLines.where((l) => l.trim().isNotEmpty).take(15).join('\n');
        debugPrint('PDF Debug Lines:\n$debugLines');
        return PdfParseResult(
          success: false,
          errorMessage: 'PDF okundu ancak öğrenci formatı algılanamadı. Gelen ilk satırlar:\n$debugLines',
        );
      }

      return PdfParseResult(
        success: true,
        detectedClassName: detectedClassName,
        students: studentList,
      );
    } catch (e, st) {
      debugPrint('PDF Parse Error: $e\n$st');
      return PdfParseResult(
        success: false,
        errorMessage: 'PDF okunurken bir hata oluştu: ${e.toString()}',
      );
    }
  }

  /// PDF İçerisindeki Metinden Sınıf Adını Bulur
  static String _detectClassName(String text) {
    final classRegex = RegExp(
      r'(?:Sınıfı?|Şubesi?|Sınıf/Şube)?\s*[:|-]?\s*([1-9]|1[0-2])\s*[\/\-\s]\s*([A-Za-dğüşöçıİĞÜŞÖÇ])\b',
      caseSensitive: false,
    );

    final match = classRegex.firstMatch(text);
    if (match != null) {
      final grade = match.group(1);
      final branch = match.group(2)?.toUpperCase();
      if (grade != null && branch != null) {
        return InputSanitizer.cleanClassName('$grade-$branch');
      }
    }
    return '';
  }

  /// Formatlı satırlardan öğrenci listesini çıkarır
  static List<StudentModel> _extractStudentsFromStructuredLines(List<String> lines, int targetClassId) {
    final List<StudentModel> students = [];
    final Set<int> seenSchoolNumbers = {};

    for (var line in lines) {
      // 1. Gereksiz karakterleri temizle ve token'lara ayır
      String cleaned = line.replaceAll(RegExp(r'[\r\n\t]+'), ' ');

      // Sayı ile harf bitişikse ayır (Örn: 1039AHMET -> 1039 AHMET)
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'(\d)([a-zA-ZÇĞİÖŞÜçğıöşü])'),
        (m) => '${m[1]} ${m[2]}',
      );
      // Harf ile sayı bitişikse ayır
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'([a-zA-ZÇĞİÖŞÜçğıöşü])(\d)'),
        (m) => '${m[1]} ${m[2]}',
      );
      // Küçük harf - Büyük harf birleşimini ayır
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'([a-zçğıöşü])([A-ZÇĞİÖŞÜ])'),
        (m) => '${m[1]} ${m[2]}',
      );
      // Noktaları boşlukla ayır (örn "5.Sınıf" -> "5. Sınıf")
      cleaned = cleaned.replaceAll('.', ' . ');

      final List<String> allTokens = cleaned
          .split(RegExp(r'\s+'))
          .where((k) => k.isNotEmpty) // length > 1 kısıtlamasını kaldırdık, "D Şubesi"ndeki "D" veya "1" S.No'su için.
          .toList();

      List<String> currentChunk = [];

      for (int i = 0; i < allTokens.length; i++) {
        final token = allTokens[i];
        currentChunk.add(token);

        // Eğer Cinsiyet kelimesi bulduysak, bu chunk bir öğrenci kaydıdır!
        if (_isGenderToken(token)) {
          final student = _processChunk(currentChunk, targetClassId);
          if (student != null && !seenSchoolNumbers.contains(student.schoolNumber)) {
            seenSchoolNumbers.add(student.schoolNumber);
            students.add(student);
          }
          currentChunk.clear();
        }
      }
    }

    return students;
  }

  /// Bir cinsiyet kelimesiyle biten token listesinden öğrenci çıkarır (Yenilmez Algoritma)
  static StudentModel? _processChunk(List<String> chunk, int targetClassId) {
    if (chunk.length < 3) return null; // En az Ad, OkulNo, Cinsiyet olmalı

    final genderStr = chunk.last;
    final gender = genderStr.toLowerCase().startsWith('k') ? 'Kız' : 'Erkek';

    // 1. Okul Numarasını Bul (En son geçen 10'dan büyük sayı)
    int? schoolNo;
    int schoolNoIndex = -1;
    for (int i = chunk.length - 2; i >= 0; i--) {
      if (_isSchoolNumber(chunk[i])) {
        schoolNo = int.parse(chunk[i]);
        schoolNoIndex = i;
        break;
      }
    }

    if (schoolNo == null) return null; // Okul numarası yoksa öğrenci olamaz

    // 2. İsmi Bul
    // Sütunların sırası e-Okul PDF'sine göre değişebilir.
    // Durum 1: İsim okul numarasından SONRA geliyorsa (Örn: 1 1039 AHMET YILMAZ Erkek)
    List<String> nameTokensAfter = [];
    for (int i = schoolNoIndex + 1; i < chunk.length - 1; i++) {
      if (_isValidNamePart(chunk[i]) && !_isForbiddenToken(chunk[i])) {
        nameTokensAfter.add(chunk[i]);
      }
    }

    List<String> nameTokens = [];

    if (nameTokensAfter.isNotEmpty) {
      nameTokens = nameTokensAfter;
    } else {
      // Durum 2: İsim okul numarasından ve S.No'dan ÖNCE geliyorsa (Taşımalı Listesi: ABDURRAHMAN BAKSAL 1 5.Sınıf 1039 Erkek)
      // Chunk'ın başından başlayıp İLK sayıya kadar olan kelimeleri al.
      int firstNumIndex = -1;
      for (int i = 0; i < chunk.length; i++) {
        if (RegExp(r'^\d+$').hasMatch(chunk[i])) {
          firstNumIndex = i;
          break;
        }
      }

      if (firstNumIndex > 0) {
        for (int i = 0; i < firstNumIndex; i++) {
          if (_isValidNamePart(chunk[i]) && !_isForbiddenToken(chunk[i])) {
            nameTokens.add(chunk[i]);
          }
        }
      }
    }

    if (nameTokens.length >= 2) { // En az 2 parça isim olmalı
      final lastName = _titleCase(nameTokens.last);
      final firstName = _titleCase(nameTokens.sublist(0, nameTokens.length - 1).join(' '));

      return StudentModel(
        classId: targetClassId,
        schoolNumber: schoolNo,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
      );
    }

    return null;
  }

  static bool _isSchoolNumber(String s) {
    if (!RegExp(r'^\d+$').hasMatch(s)) return false;
    final val = int.tryParse(s);
    return val != null && val > 10 && val < 99999;
  }

  static bool _isGenderToken(String s) {
    return RegExp(r'^(Erkek|Kız|Kiz|E|K)$', caseSensitive: false).hasMatch(s);
  }

  static bool _isForbiddenToken(String s) {
    final lower = s.toLowerCase();
    const forbidden = [
      'sınıf',
      'sinif',
      'şube',
      'sube',
      'no',
      'listesi',
      'merkez',
      'müdürlüğü',
      'valilik',
      'okulu',
      'tarih',
      't', // T.C'deki
      'c',
      'milli',
      'eğitim',
      'bakanlığı',
      'sayfa',
    ];
    return forbidden.any((f) => lower == f); // Tam eşleşme daha güvenli
  }

  static bool _isValidNamePart(String s) {
    // Harflerden oluşmalı, noktalama işareti barındırmamalı
    if (!RegExp(r'^[a-zA-ZÇĞİÖŞÜçğıöşü]+$').hasMatch(s)) return false;
    if (s.length < 2) return false; // "A" gibi tek harfler isim değildir
    return true;
  }

  static String _titleCase(String text) {
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          if (word.length == 1) return word.toUpperCase();
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}

class PdfParseResult {
  final bool success;
  final String detectedClassName;
  final List<StudentModel> students;
  final String? errorMessage;

  const PdfParseResult({
    required this.success,
    this.detectedClassName = '',
    this.students = const [],
    this.errorMessage,
  });
}
