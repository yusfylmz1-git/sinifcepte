import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/exam_analysis_model.dart';
import '../data/repositories/exam_analysis_repository.dart';

/// ExamAnalysisRepository Provider
final examAnalysisRepositoryProvider = Provider<ExamAnalysisRepository>((ref) {
  return ExamAnalysisRepository();
});

/// Tüm Sınav Analizlerinin Listesini Yöneten StateNotifier
final examAnalysisListProvider =
    StateNotifierProvider<ExamAnalysisListNotifier, AsyncValue<List<ExamAnalysisModel>>>((ref) {
  final repo = ref.watch(examAnalysisRepositoryProvider);
  return ExamAnalysisListNotifier(repo);
});

class ExamAnalysisListNotifier extends StateNotifier<AsyncValue<List<ExamAnalysisModel>>> {
  final ExamAnalysisRepository _repository;

  ExamAnalysisListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadExams();
  }

  /// Tüm sınav analizlerini veritabanından yükler
  Future<void> loadExams() async {
    try {
      state = const AsyncValue.loading();
      final exams = await _repository.getAllExams();
      state = AsyncValue.data(exams);
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisList.loadExams) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('--------------------------------------------------------------------------');
      state = AsyncValue.error(e, st);
    }
  }

  /// Yeni sınav analizi ekler veya günceller
  Future<int?> saveExam(ExamAnalysisModel exam) async {
    try {
      final savedId = await _repository.saveExam(exam);
      await loadExams();
      return savedId;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisList.saveExam) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-------------------------------------------------------------------------');
      return null;
    }
  }

  /// Sınav analizini siler
  Future<bool> deleteExam(int id) async {
    try {
      final success = await _repository.deleteExam(id);
      if (success) {
        await loadExams();
      }
      return success;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisList.deleteExam) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('---------------------------------------------------------------------------');
      return false;
    }
  }
}

/// Tek bir sınav analizinin detayını getiren FutureProvider
final examAnalysisDetailProvider =
    FutureProvider.family<ExamAnalysisModel?, int>((ref, examId) async {
  final repo = ref.watch(examAnalysisRepositoryProvider);
  return await repo.getExamById(examId);
});
