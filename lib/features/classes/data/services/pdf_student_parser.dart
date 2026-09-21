import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../core/utils/name_formatter.dart';
import '../../../../data/models/student_model.dart';

/// SınıfCepte - Layout-Aware (Koordinat Bazlı) Gelişmiş PDF Ayıklayıcı
/// `pdf-inspector` mantığıyla tablo hücrelerini görsel Y koordinatına göre gruplar.
class PdfStudentParser {
  /// Doğrudan byte dizisinden ayrıştırma (Testler ve arka plan isolate için)
  static PdfParseResult parseBytes(Uint8List bytes, int targetClassId) {
    try {
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

      // 1. TextLine nesnelerini Y (top) koordinatlarına göre sırala (O(N log N))
      textLines.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

      // 2. Y eksenine göre satırları doğrusal grupla (O(N))
      final List<List<TextLine>> groupedRows = [];
      const double yTolerance = 5.0; // Aynı satırda sayılabilmeleri için esneklik payı

      for (final line in textLines) {
        if (groupedRows.isEmpty) {
          groupedRows.add([line]);
        } else {
          final lastRow = groupedRows.last;
          if ((lastRow.first.bounds.top - line.bounds.top).abs() <= yTolerance) {
            lastRow.add(line);
          } else {
            groupedRows.add([line]);
          }
        }
      }

      // 3. Her satırın kendi içindeki kelimelerini X eksenine göre soldan sağa sırala
      for (var row in groupedRows) {
        row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      }

      // 4. Tablo satırlarını metne dönüştür
      List<String> structuredLines = groupedRows.map((row) {
        return row.map((cell) => cell.text.trim()).join('   ');
      }).toList();

      // 5. Öğrencileri Çıkar
      final List<ParsedStudentItem> parsedList = _extractStudentsFromStructuredLines(structuredLines, targetClassId);

      if (parsedList.isEmpty) {
        final debugLines = structuredLines.where((l) => l.trim().isNotEmpty).take(15).join('\n');
        debugPrint('PDF Debug Lines:\n$debugLines');
        return PdfParseResult(
          success: false,
          errorMessage: 'PDF okundu ancak öğrenci formatı algılanamadı. Gelen ilk satırlar:\n$debugLines',
        );
      }

      final distinctClasses = parsedList
          .map((s) => s.className)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final bool isMultiClass = distinctClasses.length > 1;
      if (detectedClassName.isEmpty && distinctClasses.length == 1) {
        detectedClassName = distinctClasses.first;
      }

      final legacyStudentList = parsedList.map((p) => p.toStudentModel(targetClassId)).toList();

      return PdfParseResult(
        success: true,
        detectedClassName: detectedClassName,
        parsedStudents: parsedList,
        students: legacyStudentList,
        isMultiClass: isMultiClass,
        distinctClasses: distinctClasses,
      );
    } catch (e, st) {
      debugPrint('PDF Parse Error: $e\n$st');
      return PdfParseResult(
        success: false,
        errorMessage: 'PDF ayrıştırılırken bir hata oluştu: ${e.toString()}',
      );
    }
  }

  /// PDF İçerisindeki Metinden Sınıf Adını Bulur.
  ///
  /// Aynı desene bağlı: ikisi ayrı yazılıydı ve biri düzeltilip
  /// diğeri kaldığında dosya başlığından doğru şubeyi okurken
  /// öğrenci satırlarından uydurmaya devam ediyordu. İki yerde
  /// aynı kuralı tutmak bu depoda tekrar eden hata sınıfı.
  static String _detectClassName(String text) {
    return _extractClassFromLineOrChunk(text) ?? '';
  }

  /// Satır veya chunk içindeki sınıf adını ayıklar.
  ///
  /// `5. Sınıf / D Şubesi` -> `5-D`, `6/A` -> `6-A`
  ///
  /// ## Boşluk ARTIK tek başına ayırıcı değil
  ///
  /// Eski desen sayı ile harf arasında boşluğu da kabul ediyordu
  /// (`[\/\-\s]`). Sonuç: ÖĞRENCİ SATIRLARINDAN uydurma şube
  /// türetiyordu.
  ///
  /// Ölçüldü (21 Eylül 2026, gerçek e-Okul çıktısı, 26 öğrencilik
  /// 5/A listesi): 26 satırın 6'sı yanlış eşleşti.
  ///
  ///     2  86  ÖMER  DEMİR  Erkek        -> 6-Ö
  ///     17  297  HÜSEYİN EFE  AKBAY      -> 7-H
  ///     25  358  İKRA ALEYNA  NERGİS     -> 8-İ
  ///
  /// Kullanıcının ekranında "Çoklu Sınıf Dağıtımı (25 Şube)"
  /// görünmesinin sebebi tam buydu: her öğrenci kendi uydurma
  /// şubesine dağıtılıyordu.
  ///
  /// Artık boşluk yalnızca "Sınıf" kelimesi varsa ayırıcı sayılıyor:
  /// `5. Sınıf A Şubesi` geçiyor, `86 ÖMER` geçmiyor.
  static String? _extractClassFromLineOrChunk(String text) {
    // İki kol:
    //   a) "Sınıf" kelimesi VAR  -> ayırıcı serbest (/, -, boşluk)
    //   b) "Sınıf" kelimesi YOK  -> ayırıcı / veya - OLMALI
    //
    // Şube harfi iki ayrı grupta çıkıyor (2 ve 3); hangisi doldu ise
    // o alınıyor.
    final mebPattern = RegExp(
      r'([1-9]|1[0-2])\s*\.?\s*(?:'
      r'(?:Sınıfı?|Sinifi?)\s*[\/\-\s]\s*([A-Za-zğüşöçıİĞÜŞÖÇ])'
      r'\s*(?:Şubesi|Subesi|Şube|Sube)?'
      r'|'
      r'[\/\-]\s*([A-Za-zğüşöçıİĞÜŞÖÇ])'
      r'\s*(?:Şubesi|Subesi|Şube|Sube)?'
      r')\b',
      caseSensitive: false,
    );
    final match = mebPattern.firstMatch(text);
    if (match != null) {
      final grade = match.group(1);
      final branch = (match.group(2) ?? match.group(3))?.toUpperCase();
      if (grade != null && branch != null) {
        return InputSanitizer.cleanClassName('$grade-$branch');
      }
    }

    return null;
  }

  /// Formatlı satırlardan öğrenci listesini çıkarır.
  ///
  /// Test edilebilir olması için açıktır: PDF üretmeden, doğrudan satır
  /// listesi verilerek ayrıştırma mantığı sınanabilir. (Test ortamında
  /// standart PDF fontları Türkçe 'ı/ğ/İ' harflerini yazamadığı için
  /// uçtan uca PDF üreterek test etmek yanıltıcı sonuç veriyor.)
  @visibleForTesting
  static List<ParsedStudentItem> extractStudentsFromLines(
    List<String> lines,
    int targetClassId,
  ) =>
      _extractStudentsFromStructuredLines(lines, targetClassId);

  /// Metinden sınıf adı tespiti (test edilebilir).
  @visibleForTesting
  static String detectClassNameFrom(String text) => _detectClassName(text);

  static List<ParsedStudentItem> _extractStudentsFromStructuredLines(List<String> lines, int targetClassId) {
    final List<ParsedStudentItem> studentList = [];
    final Set<int> seenSchoolNumbers = {};

    for (var line in lines) {
      final lineClass = _extractClassFromLineOrChunk(line);

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
          .where((k) => k.isNotEmpty)
          .toList();

      List<String> currentChunk = [];

      for (int i = 0; i < allTokens.length; i++) {
        final token = allTokens[i];
        currentChunk.add(token);

        // Eğer Cinsiyet kelimesi bulduysak, bu chunk bir öğrenci kaydıdır!
        if (_isGenderToken(token)) {
          final chunkClass = lineClass ?? _extractClassFromLineOrChunk(currentChunk.join(' '));
          final student = _processChunk(currentChunk, targetClassId, assignedClass: chunkClass);
          if (student != null && !seenSchoolNumbers.contains(student.schoolNumber)) {
            seenSchoolNumbers.add(student.schoolNumber);
            studentList.add(student);
          }
          currentChunk.clear();
        }
      }
    }

    return studentList;
  }

  /// Bir cinsiyet kelimesiyle biten token listesinden öğrenci çıkarır
  static ParsedStudentItem? _processChunk(
    List<String> chunk,
    int targetClassId, {
    String? assignedClass,
  }) {
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

    if (nameTokens.length >= 2) {
      final lastName = _titleCase(nameTokens.last);
      final firstName = _titleCase(nameTokens.sublist(0, nameTokens.length - 1).join(' '));

      return ParsedStudentItem(
        schoolNumber: schoolNo,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        className: assignedClass,
      );
    }

    return null;
  }

  static bool _isSchoolNumber(String s) {
    if (!RegExp(r'^\d+$').hasMatch(s)) return false;
    final val = int.tryParse(s);
    return val != null && val > 0 && val < 99999;
  }

  static bool _isGenderToken(String s) {
    return RegExp(r'^(Erkek|Kız|Kiz|E|K)$', caseSensitive: false).hasMatch(s);
  }

  static bool _isForbiddenToken(String s) {
    final lower = s.toLowerCase();
    const forbidden = [
      'sınıf',
      'sinif',
      'sınıfı',
      'sinifi',
      'şube',
      'sube',
      'şubesi',
      'subesi',
      'no',
      's.no',
      'sno',
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
      // ALT TOPLAM satırı sahte öğrenci üretiyordu.
      //
      // `Kız Öğrenci Sayısı : 13 Erkek Öğrenci Sayısı : 13` satırı
      // "13 / Öğrenci / Sayısı / ... / Erkek" olarak okunup bir
      // öğrenci kaydına dönüşüyordu: no=13, ad="Öğrenci",
      // soyad="Sayısı". Her listede bir uydurma öğrenci eklenmiş
      // oluyordu (21 Eylül 2026, gerçek e-Okul çıktısıyla ölçüldü).
      'öğrenci',
      'ogrenci',
      'sayısı',
      'sayisi',
      'toplam',
      'kız',
      'kiz',
      'erkek',
      'cinsiyeti',
      'cinsiyet',
      'adı',
      'adi',
      'soyadı',
      'soyadi',
      'öğretmeni',
      'ogretmeni',
      'başkanı',
      'baskani',
      'yrd',
      'müdür',
      'mudur',
    ];
    return forbidden.any((f) => lower == f);
  }

  static bool _isValidNamePart(String s) {
    // Harflerden oluşmalı, noktalama işareti barındırmamalı
    if (!RegExp(r'^[a-zA-ZÇĞİÖŞÜçğıöşü]+$').hasMatch(s)) return false;
    if (s.length < 2) return false; // "A" gibi tek harfler isim değildir
    return true;
  }

  /// Ad-soyad biçimlendirir — TÜRKÇE uyumlu.
  ///
  /// Eski sürüm `toLowerCase()` kullanıyordu ve Türkçe büyük harfleri
  /// bozuyordu:
  ///
  ///     DİLDİRİM -> Dildirim   (İ kaybolmuş)
  ///     AYDIN    -> Aydin      (I yanlış)
  ///     ŞAVLİ    -> Şavli
  ///
  /// e-Okul listelerinin TAMAMI büyük harf, yani bu her isimde
  /// oluyordu. Öğrenci adı yanlış kaydedilince veli eşleştirmesi ve
  /// belgeler de yanlış çıkıyor.
  ///
  /// `NameFormatter` bu iş için zaten vardı ve Türkçe kurallarını
  /// uyguluyor; ayrı bir kopya tutmak hafızadaki İ tuzağının tekrarı
  /// olurdu (21 Eylül 2026).
  static String _titleCase(String text) {
    return NameFormatter.formatFirstName(text);
  }
}

class ParsedStudentItem {
  final int schoolNumber;
  final String firstName;
  final String lastName;
  final String gender;
  final String? className; // Örn: "5-D", "6-A", vb.

  const ParsedStudentItem({
    required this.schoolNumber,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.className,
  });

  StudentModel toStudentModel(int classId) {
    return StudentModel(
      classId: classId,
      schoolNumber: schoolNumber,
      firstName: firstName,
      lastName: lastName,
      gender: gender,
    );
  }
}

class PdfParseResult {
  final bool success;
  final String detectedClassName;
  final List<ParsedStudentItem> parsedStudents;
  final List<StudentModel> students;
  final String? errorMessage;
  final bool isMultiClass;
  final List<String> distinctClasses;

  const PdfParseResult({
    required this.success,
    this.detectedClassName = '',
    this.parsedStudents = const [],
    this.students = const [],
    this.errorMessage,
    this.isMultiClass = false,
    this.distinctClasses = const [],
  });
}


