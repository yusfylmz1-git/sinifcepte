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
/// WhatsApp'tan gelen belgeler Android seçicisinde sık görünmez ve
/// görünseler bile `path` boş gelir (content URI). Bu yüzden bayt
/// okunur; uzantı yoksa dosya imzasından biçim anlaşılır.
class StudentFileImporter {
  const StudentFileImporter._();

  /// Seçicide gösterilen uzantılar.
  static const List<String> supportedExtensions = ['pdf', 'xlsx', 'xls'];

  /// Kullanıcıya gösterilen biçim etiketi.
  static const String supportedLabel = 'PDF veya Excel';

  /// WhatsApp/SAF dosyası okunamadığında gösterilen yol tarifi.
  static const String shareFallbackHint =
      'Dosya okunamadı. WhatsApp\'taki PDF\'ye basıp Paylaş → SınıfCepte deneyin.';

  /// Dosya seçtirir ve uzantısına göre ayrıştırır.
  ///
  /// [targetClassId] içe aktarılan öğrencilerin bağlanacağı sınıf.
  static Future<StudentImportResult> pickAndParse(int targetClassId) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sınıf listesi dosyasını seçin (PDF veya Excel)',
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        // WhatsApp / Google Drive content URI'lerinde path null olur;
        // bayt yoksa "Dosya seçilmedi" sanılıyordu.
        withData: true,
      );

      if (picked == null || picked.files.isEmpty) {
        return const StudentImportResult(
          success: false,
          errorMessage: 'Dosya seçilmedi',
        );
      }

      final file = picked.files.single;
      Uint8List? bytes = file.bytes;
      final path = file.path;
      if ((bytes == null || bytes.isEmpty) && path != null && path.isNotEmpty) {
        final onDisk = File(path);
        if (await onDisk.exists()) {
          bytes = await onDisk.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        return const StudentImportResult(
          success: false,
          errorMessage: shareFallbackHint,
        );
      }

      return parseNamedBytes(
        bytes: bytes,
        targetClassId: targetClassId,
        name: file.name,
        path: path,
      );
    } catch (e, stackTrace) {
      debugPrint('Öğrenci dosyası içe aktarma hatası: $e\n$stackTrace');
      return StudentImportResult(
        success: false,
        errorMessage: 'Dosya okunurken bir hata oluştu: $e',
      );
    }
  }

  /// WhatsApp paylaşımı veya kayıtlı yol: dosyayı okuyup ayrıştırır.
  static Future<StudentImportResult> parseFromPath(
    String path,
    int targetClassId,
  ) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return const StudentImportResult(
          success: false,
          errorMessage: 'Paylaşılan dosya bulunamadı.',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return const StudentImportResult(
          success: false,
          errorMessage: shareFallbackHint,
        );
      }
      return parseNamedBytes(
        bytes: bytes,
        targetClassId: targetClassId,
        name: path,
        path: path,
      );
    } catch (e, stackTrace) {
      debugPrint('Paylaşılan öğrenci dosyası okunamadı: $e\n$stackTrace');
      return StudentImportResult(
        success: false,
        errorMessage: 'Paylaşılan dosya okunamadı: $e',
      );
    }
  }

  /// Ad, yol veya dosya imzasından biçimi bulup ayrıştırır.
  ///
  /// WhatsApp content URI'lerinde uzantı olmaz; imza bakılır.
  static StudentImportResult parseNamedBytes({
    required Uint8List bytes,
    required int targetClassId,
    String name = '',
    String? path,
  }) {
    final format = detectFormat(name) ??
        (path != null && path.isNotEmpty ? detectFormat(path) : null) ??
        detectFormatFromBytes(bytes);
    if (format == null) {
      return StudentImportResult(
        success: false,
        errorMessage:
            'Desteklenmeyen dosya türü. $supportedLabel dosyası seçin.',
      );
    }
    return parseBytes(bytes, targetClassId, format);
  }

  /// Dosya adından veya yoldan biçimi belirler; tanınmazsa null.
  static StudentFileFormat? detectFormat(String path) {
    var lower = path.toLowerCase().trim();
    if (lower.isEmpty) return null;
    lower = lower.split('?').first.split('#').first;
    if (lower.endsWith('.pdf')) return StudentFileFormat.pdf;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return StudentFileFormat.excel;
    }
    return null;
  }

  /// Uzantısız (WhatsApp / content URI) dosyalarda imzaya bakar.
  static StudentFileFormat? detectFormatFromBytes(Uint8List bytes) {
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return StudentFileFormat.pdf; // %PDF
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      return StudentFileFormat.excel; // OLE Compound (.xls)
    }
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return StudentFileFormat.excel; // ZIP (.xlsx)
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
