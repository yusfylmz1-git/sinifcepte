import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../data/models/exam_model.dart';
import '../data/repositories/exam_operations_repository.dart';
import '../data/services/exam_sync_service.dart';
import 'quiz_tracking_provider.dart';

/// 0: Tümü (MEB/ÖSYM), 1: Favorilerim, 2: Okulum (Kişisel)
final examFilterTabProvider = StateProvider<int>((ref) => 0);

class ExamTrackingState {
  final List<ExamModel> exams;
  final bool isLoading;
  final String? errorMessage;

  const ExamTrackingState({
    this.exams = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ExamTrackingState copyWith({
    List<ExamModel>? exams,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ExamTrackingState(
      exams: exams ?? this.exams,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  List<ExamModel> get officialExams => exams.where((e) => !e.isSchoolExam).toList();
  List<ExamModel> get favoriteExams => exams.where((e) => e.isFavorite).toList();
  List<ExamModel> get schoolExams => exams.where((e) => e.isSchoolExam).toList();

  /// En yakın yaklaşan sınavlar
  List<ExamModel> get upcomingExams {
    final list = exams.where((e) => !e.isPast).toList();
    list.sort((a, b) => a.examDate.compareTo(b.examDate));
    return list;
  }
}

final examTrackingProvider = StateNotifierProvider<ExamTrackingNotifier, ExamTrackingState>((ref) {
  final repo = ref.watch(examOperationsRepositoryProvider);
  final syncService = ref.watch(examSyncServiceProvider);
  return ExamTrackingNotifier(repo, syncService);
});

class ExamTrackingNotifier extends StateNotifier<ExamTrackingState> {
  final ExamOperationsRepository _repository;
  final ExamSyncService _syncService;

  ExamTrackingNotifier(this._repository, this._syncService) : super(const ExamTrackingState()) {
    loadExams();
  }

  Future<void> loadExams() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      var exams = await _repository.getAllExams();

      // Veritabanı boşsa ilk defa asset'ten doldur
      if (exams.isEmpty) {
        await _syncService.syncFromLocalAsset();
        exams = await _repository.getAllExams();
      }

      state = state.copyWith(exams: exams, isLoading: false);

      // Favori sınavların bildirimlerini arka planda senkronize et
      final favExams = exams.where((ExamModel e) => e.isFavorite).toList();
      NotificationService.instance.syncAllFavoriteExamReminders(favExams);
    } catch (e, stackTrace) {
      debugPrint('ExamTrackingNotifier.loadExams error: $e\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sınavlar yüklenirken hata: $e',
      );
    }
  }

  /// Uzaktan veya Yerel Asset'ten Resmî Sınavları Senkronize Et
  Future<void> syncOfficialExams({String? customJson}) async {
    try {
      if (customJson != null && customJson.isNotEmpty) {
        await _syncService.syncFromJsonString(customJson);
      } else {
        await _syncService.syncFromLocalAsset();
      }
      await loadExams();
    } catch (e, stackTrace) {
      debugPrint('ExamTrackingNotifier.syncOfficialExams error: $e\n$stackTrace');
    }
  }

  Future<void> toggleFavorite(String docId) async {
    try {
      ExamModel? targetExam;
      final updatedList = state.exams.map((e) {
        if (e.id == docId) {
          final newFav = !e.isFavorite;
          targetExam = e.copyWith(isFavorite: newFav);
          return targetExam!;
        }
        return e;
      }).toList();

      state = state.copyWith(exams: updatedList);
      await _repository.toggleFavoriteExam(docId);

      // Bildirim Planlama / İptal (Son 24 saat kala)
      if (targetExam != null) {
        if (targetExam!.isFavorite) {
          await NotificationService.instance.scheduleExamReminder24h(targetExam!);
        } else {
          await NotificationService.instance.cancelExamReminder(targetExam!);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('ExamTrackingNotifier.toggleFavorite error: $e\n$stackTrace');
    }
  }


  Future<bool> addSchoolExam({
    required String title,
    required DateTime examDate,
    DateTime? applicationDeadline,
    String? className,
  }) async {
    try {
      final exam = ExamModel(
        id: 'okul_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        institution: 'OKUL',
        examDate: examDate,
        applicationDeadline: applicationDeadline,
        category: 'OKUL',
        isSchoolExam: true,
        className: className,
      );

      final id = await _repository.addSchoolExam(exam);
      if (id > 0) {
        await loadExams();
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('ExamTrackingNotifier.addSchoolExam error: $e\n$stackTrace');
      return false;
    }
  }

  Future<bool> deleteSchoolExam(int id) async {
    try {
      await _repository.deleteSchoolExam(id);
      await loadExams();
      return true;
    } catch (e, stackTrace) {
      debugPrint('ExamTrackingNotifier.deleteSchoolExam error: $e\n$stackTrace');
      return false;
    }
  }
}

