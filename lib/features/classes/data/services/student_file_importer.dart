import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../../data/models/student_model.dart';
import 'excel_student_parser.dart';
import 'pdf_student_parser.dart';

/// SınıfCepte - Öğrenci listesi içe aktarma çerçevesi (PDF + Excel).
///
/// Tek dosya seçici, iki biçim: öğretmen e-Okul'dan PDF de indirse
/// Excel de indirse aynı düğmeyi kullanır. Uzantıya göre doğru
/// ayrıştırıcıya yönlendirilir.
///
/// Öncesinde iki ayrı ayrıştırıcı vardı ve ekran yalnızca PDF'i
/// çağırıyordu; `ExcelStudentParser` yazılmış ama hiçbir yerden
/// kullanılmıyordu (ölü kod). Sonuç tipleri de birebir aynı olduğu hâlde
/// ayrı sınıflardı, bu yüzden ortak bir akış kurulamıyordu.
class StudentFileImporter {
  const StudentFileImporter._();

  /// Seçicide gösterilen uzantılar.
  static const List<String> supportedExtensions = ['pdf', 'xlsx', 'xls'];

  /// Kullanıcıya gösterilen biçim etiketi.
  static const String supportedLabel = 'PDF veya Excel';

  /// Dosya seçtirir ve uzantısına göre ayrıştırır.
  ///
  /// [targetClassId] içe aktarılan öğrencilerin bağlanacağı sınıf.
  static Future<StudentImportResult> pickAndParse(int targetClassId) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sınıf listesi dosyasını seçin (PDF veya Excel)',
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        withData: false,
      );

      if (picked == null ||
          picked.files.isEmpty ||
          picked.files.single.path == null) {
        return const StudentImportResult(
          success: false,
          errorMessage: 'Dosya seçilmedi',
        );
      }

      final path = picked.files.single.path!;
      final file = File(path);
      if (!await file.exists()) {
        return const StudentImportResult(
          success: false,
          errorMessage: 'Seçilen dosya bulunamadı.',
        );
      }

      final format = detectFormat(path);
      if (format == null) {
        return StudentImportResult(
          success: false,
          errorMessage:
              'Desteklenmeyen dosya türü. $supportedLabel dosyası seçin.',
        );
      }

      final bytes = await file.readAsBytes();
      return parseBytes(bytes, targetClassId, format);
    } catch (e, stackTrace) {
      debugPrint('Öğrenci dosyası içe aktarma hatası: $e\n$stackTrace');
      return StudentImportResult(
        success: false,
        errorMessage: 'Dosya okunurken bir hata oluştu: $e',
      );
    }
  }

  /// Dosya adından biçimi belirler; tanınmazsa null.
  static StudentFileFormat? detectFormat(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return StudentFileFormat.pdf;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return StudentFileFormat.excel;
    }
    return null;
  }

  /// Baytları verilen biçime göre ayrıştırır (test ve arka plan için).
  static StudentImportResult parseBytes(
    Uint8List bytes,
    int targetClassId,
    StudentFileFormat format,
  ) {
    switch (format) {
      case StudentFileFormat.pdf:
        return StudentImportResult.fromPdf(
          PdfStudentParser.parseBytes(bytes, targetClassId),
        );
      case StudentFileFormat.excel:
        return StudentImportResult.fromExcel(
          ExcelStudentParser.parseBytes(bytes, targetClassId),
        );
    }
  }
}

/// Desteklenen dosya biçimleri.
enum StudentFileFormat {
  pdf,
  excel;

  String get label => this == StudentFileFormat.pdf ? 'PDF' : 'Excel';
}

/// PDF ve Excel için ortak içe aktarma sonucu.
///
/// İki ayrıştırıcı da aynı alanları döndürüyordu ama ayrı sınıflardı;
/// bu tip ikisini tek akışta birleştirir.
class StudentImportResult {
  final bool success;
  final String detectedClassName;
  final List<ParsedStudentItem> parsedStudents;
  final List<StudentModel> students;
  final String? errorMessage;
  final bool isMultiClass;
  final List<String> distinctClasses;

  /// Hangi biçimden geldiği (hata mesajlarında kullanılır).
  final StudentFileFormat? format;

  const StudentImportResult({
    required this.success,
    this.detectedClassName = '',
    this.parsedStudents = const [],
    this.students = const [],
    this.errorMessage,
    this.isMultiClass = false,
    this.distinctClasses = const [],
    this.format,
  });

  factory StudentImportResult.fromPdf(PdfParseResult result) {
    return StudentImportResult(
      success: result.success,
      detectedClassName: result.detectedClassName,
      parsedStudents: result.parsedStudents,
      students: result.students,
      errorMessage: result.errorMessage,
      isMultiClass: result.isMultiClass,
      distinctClasses: result.distinctClasses,
      format: StudentFileFormat.pdf,
    );
  }

  factory StudentImportResult.fromExcel(ExcelParseResult result) {
    return StudentImportResult(
      success: result.success,
      detectedClassName: result.detectedClassName,
      parsedStudents: result.parsedStudents,
      students: result.students,
      errorMessage: result.errorMessage,
      isMultiClass: result.isMultiClass,
      distinctClasses: result.distinctClasses,
      format: StudentFileFormat.excel,
    );
  }

  /// Kullanıcı dosya seçmeden vazgeçti mi? (Hata olarak gösterilmez.)
  bool get isCancelled {
    final message = errorMessage ?? '';
    return !success &&
        (message.contains('seçilmedi') || message.contains('iptal'));
  }
}
