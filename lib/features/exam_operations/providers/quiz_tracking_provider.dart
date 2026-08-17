import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../data/models/quiz_tracking_model.dart';
import '../data/repositories/exam_operations_repository.dart';

final examOperationsRepositoryProvider = Provider<ExamOperationsRepository>((ref) {
  return ExamOperationsRepository();
});

/// Quiz Takibi İçin Seçili Sınıf
final selectedQuizClassProvider = StateProvider<ClassModel?>((ref) => null);

/// Quiz Takibi İçin Seçili Ders
final selectedQuizSubjectProvider = StateProvider<String>((ref) => 'Matematik');

class QuizTableState {
  final QuizCizelgeModel? cizelge;
  final List<QuizKolonModel> columns;
  final Map<int, Map<int, int>> studentScores; // studentId -> {kolonId: score}
  final List<StudentModel> students;
  final bool isLoading;
  final String? errorMessage;

  const QuizTableState({
    this.cizelge,
    this.columns = const [],
    this.studentScores = const {},
    this.students = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  QuizTableState copyWith({
    QuizCizelgeModel? cizelge,
    List<QuizKolonModel>? columns,
    Map<int, Map<int, int>>? studentScores,
    List<StudentModel>? students,
    bool? isLoading,
    String? errorMessage,
  }) {
    return QuizTableState(
      cizelge: cizelge ?? this.cizelge,
      columns: columns ?? this.columns,
      studentScores: studentScores ?? this.studentScores,
      students: students ?? this.students,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Öğrencinin girilen notlarının ortalaması
  double? calculateStudentAverage(int studentId) {
    final scoresMap = studentScores[studentId];
    if (scoresMap == null || scoresMap.isEmpty) return null;

    final scores = scoresMap.values.toList();
    if (scores.isEmpty) return null;

    final sum = scores.fold(0, (acc, s) => acc + s);
    return sum / scores.length;
  }

  /// Belirli bir kolonun sınıf ortalaması
  double? calculateColumnAverage(int kolonId) {
    final scores = <int>[];
    for (final sMap in studentScores.values) {
      if (sMap.containsKey(kolonId)) {
        scores.add(sMap[kolonId]!);
      }
    }
    if (scores.isEmpty) return null;
    final sum = scores.fold(0, (acc, s) => acc + s);
    return sum / scores.length;
  }

  /// Sınıfın tüm sınavlar genel ortalaması
  double? calculateOverallClassAverage() {
    final allAverages = <double>[];
    for (final student in students) {
      if (student.id != null) {
        final avg = calculateStudentAverage(student.id!);
        if (avg != null) {
          allAverages.add(avg);
        }
      }
    }
    if (allAverages.isEmpty) return null;
    final sum = allAverages.fold(0.0, (acc, a) => acc + a);
    return sum / allAverages.length;
  }
}

final quizTableProvider = StateNotifierProvider<QuizTableNotifier, QuizTableState>((ref) {
  final repo = ref.watch(examOperationsRepositoryProvider);
  return QuizTableNotifier(repo);
});

class QuizTableNotifier extends StateNotifier<QuizTableState> {
  final ExamOperationsRepository _repository;

  QuizTableNotifier(this._repository) : super(const QuizTableState());

  Future<void> loadTable({
    required String className,
    required String subject,
    required List<StudentModel> students,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final cizelge = await _repository.getOrCreateQuizCizelge(className, subject);
      if (cizelge.id == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Çizelge oluşturulamadı');
        return;
      }

      final columns = await _repository.getQuizKolonlari(cizelge.id!);
      final scores = await _repository.getQuizNotlariForCizelge(cizelge.id!);

      state = state.copyWith(
        cizelge: cizelge,
        columns: columns,
        studentScores: scores,
        students: students,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      debugPrint('QuizTableNotifier.loadTable error: $e\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Veriler yüklenirken hata oluştu: $e',
      );
    }
  }

  Future<bool> addColumn({
    required String title,
    String type = 'quiz',
    DateTime? date,
  }) async {
    if (state.cizelge?.id == null) return false;

    try {
      final order = state.columns.length;
      final newKolon = QuizKolonModel(
        cizelgeId: state.cizelge!.id!,
        title: title,
        tip: type,
        orderIndex: order,
        date: date ?? DateTime.now(),
      );

      final id = await _repository.addQuizKolon(newKolon);
      if (id > 0) {
        final columns = await _repository.getQuizKolonlari(state.cizelge!.id!);
        state = state.copyWith(columns: columns);
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('QuizTableNotifier.addColumn error: $e\n$stackTrace');
      return false;
    }
  }

  Future<bool> deleteColumn(int columnId) async {
    if (state.cizelge?.id == null) return false;

    try {
      await _repository.deleteQuizKolon(columnId);
      final columns = await _repository.getQuizKolonlari(state.cizelge!.id!);
      final scores = await _repository.getQuizNotlariForCizelge(state.cizelge!.id!);
      state = state.copyWith(columns: columns, studentScores: scores);
      return true;
    } catch (e, stackTrace) {
      debugPrint('QuizTableNotifier.deleteColumn error: $e\n$stackTrace');
      return false;
    }
  }

  Future<void> updateScore({
    required int columnId,
    required int studentId,
    required int? score,
  }) async {
    try {
      // Optimistic update
      final updatedScores = Map<int, Map<int, int>>.from(state.studentScores);
      final studentMap = Map<int, int>.from(updatedScores[studentId] ?? {});

      if (score == null) {
        studentMap.remove(columnId);
      } else {
        studentMap[columnId] = score.clamp(0, 100);
      }

      updatedScores[studentId] = studentMap;
      state = state.copyWith(studentScores: updatedScores);

      // Veritabanına kaydet
      await _repository.saveQuizNot(columnId, studentId, score?.clamp(0, 100));
    } catch (e, stackTrace) {
      debugPrint('QuizTableNotifier.updateScore error: $e\n$stackTrace');
    }
  }
}
