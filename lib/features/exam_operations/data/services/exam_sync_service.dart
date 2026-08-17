import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../models/exam_model.dart';

final examSyncServiceProvider = Provider<ExamSyncService>((ref) {
  return ExamSyncService();
});

/// SınıfCepte - Resmî Sınav Takvimi Bulut & Varlık Senkronizasyon Servisi
class ExamSyncService {
  final DatabaseHelper _dbHelper;

  ExamSyncService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 1. Yerel Asset JSON Dosyasından Senkronize Et (`assets/data/official_exams.json`)
  Future<int> syncFromLocalAsset({String assetPath = 'assets/data/official_exams.json'}) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      return await syncFromJsonString(jsonString);
    } catch (e, stackTrace) {
      debugPrint('ExamSyncService.syncFromLocalAsset error: $e\n$stackTrace');
      return 0;
    }
  }

  /// 2. JSON Dizgisinden Senkronize Et (REST API, Firebase Firestore veya Remote Config)
  Future<int> syncFromJsonString(String jsonString) async {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        debugPrint('ExamSyncService: Beklenen format List ama ${decoded.runtimeType} geldi.');
        return 0;
      }

      final List<Map<String, dynamic>> examMaps = [];

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final docId = item['doc_id'] as String? ?? '';
          final title = item['title'] as String? ?? item['sinav_adi'] as String? ?? '';
          final institution = item['institution'] as String? ?? item['kurum'] as String? ?? 'MEB';
          final examDate = item['examDate'] as String? ?? item['sinav_tarihi'] as String? ?? '';
          final deadline = item['applicationDeadline'] as String? ?? item['son_basvuru_tarihi'] as String?;
          final url = item['applicationUrl'] as String? ?? item['basvuru_linki'] as String? ?? '';

          if (docId.isNotEmpty && title.isNotEmpty && examDate.isNotEmpty) {
            examMaps.add({
              'doc_id': docId,
              'sinav_adi': title,
              'kurum': institution,
              'sinav_tarihi': examDate,
              'son_basvuru_tarihi': deadline,
              'basvuru_linki': url,
            });
          }
        }
      }

      if (examMaps.isNotEmpty) {
        final count = await _dbHelper.bulkUpsertGenelSinavlar(examMaps);
        debugPrint('ExamSyncService: $count resmî sınav başarıyla yerel veritabanına senkronize edildi.');
        return count;
      }
      return 0;
    } catch (e, stackTrace) {
      debugPrint('ExamSyncService.syncFromJsonString error: $e\n$stackTrace');
      return 0;
    }
  }

  /// 3. Model Listesini Doğrudan Senkronize Et
  Future<int> syncExamModels(List<ExamModel> exams) async {
    try {
      final examMaps = exams.map((e) => e.toMap()).toList();
      return await _dbHelper.bulkUpsertGenelSinavlar(examMaps);
    } catch (e, stackTrace) {
      debugPrint('ExamSyncService.syncExamModels error: $e\n$stackTrace');
      return 0;
    }
  }
}
