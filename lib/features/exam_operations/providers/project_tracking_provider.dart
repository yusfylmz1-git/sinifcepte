import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../data/models/project_tracking_model.dart';
import 'quiz_tracking_provider.dart';

/// Proje Takibi İçin Seçili Sınıf
final selectedProjectClassProvider = StateProvider<ClassModel?>((ref) => null);

/// Proje Takibi İçin Seçili Ders
final selectedProjectSubjectProvider = StateProvider<String>((ref) => 'Fen Bilimleri');

class ProjectTrackingState {
  final List<ProjectTakipModel> projects;
  final List<ProjectKriterModel> criteria;
  final Map<int, int> activeScores; // kriterId -> puan (Aktif değerlendirilen öğrenci için)
  final bool isLoading;
  final String? errorMessage;

  const ProjectTrackingState({
    this.projects = const [],
    this.criteria = const [],
    this.activeScores = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  ProjectTrackingState copyWith({
    List<ProjectTakipModel>? projects,
    List<ProjectKriterModel>? criteria,
    Map<int, int>? activeScores,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProjectTrackingState(
      projects: projects ?? this.projects,
      criteria: criteria ?? this.criteria,
      activeScores: activeScores ?? this.activeScores,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Teslim edilme oranı (% 0 - 100)
  double get submissionRate {
    if (projects.isEmpty) return 0.0;
    final submittedCount = projects.where((p) => p.isSubmitted).length;
    return (submittedCount / projects.length) * 100;
  }

  /// Değerlendirilen projelerin sınıf ortalaması
  double? get averageScore {
    final evaluated = projects.where((p) => p.isEvaluated && p.totalScore != null).toList();
    if (evaluated.isEmpty) return null;
    final sum = evaluated.fold(0, (acc, p) => acc + p.totalScore!);
    return sum / evaluated.length;
  }
}

final projectTrackingProvider = StateNotifierProvider<ProjectTrackingNotifier, ProjectTrackingState>((ref) {
  final repo = ref.watch(examOperationsRepositoryProvider);
  return ProjectTrackingNotifier(repo);
});

class ProjectTrackingNotifier extends StateNotifier<ProjectTrackingState> {
  final dynamic _repository;

  ProjectTrackingNotifier(this._repository) : super(const ProjectTrackingState());

  Future<void> loadProjects({
    required String className,
    required String subject,
    required List<StudentModel> students,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final criteria = await _repository.getProjectKriterleri();
      await _repository.initProjectTakipForClass(className, subject, students);
      final projects = await _repository.getProjectTakipList(className, subject);

      state = state.copyWith(
        projects: projects,
        criteria: criteria,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      debugPrint('ProjectTrackingNotifier.loadProjects error: $e\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Projeler yüklenirken hata: $e',
      );
    }
  }

  Future<void> toggleSubmission(int projectId, bool isSubmitted) async {
    try {
      final updatedList = state.projects.map((p) {
        if (p.id == projectId) {
          return p.copyWith(isSubmitted: isSubmitted);
        }
        return p;
      }).toList();

      state = state.copyWith(projects: updatedList);
      await _repository.toggleProjectSubmission(projectId, isSubmitted);
    } catch (e, stackTrace) {
      debugPrint('ProjectTrackingNotifier.toggleSubmission error: $e\n$stackTrace');
    }
  }

  Future<void> updateTopic(int projectId, String newTopic) async {
    try {
      final updatedList = state.projects.map((p) {
        if (p.id == projectId) {
          return p.copyWith(homeworkTopic: newTopic);
        }
        return p;
      }).toList();

      state = state.copyWith(projects: updatedList);
      await _repository.updateProjectTopic(projectId, newTopic);
    } catch (e, stackTrace) {
      debugPrint('ProjectTrackingNotifier.updateTopic error: $e\n$stackTrace');
    }
  }

  Future<Map<int, int>> loadProjectScores(int projectId) async {
    try {
      final scores = await _repository.getProjectPuanlari(projectId);
      state = state.copyWith(activeScores: scores);
      return scores;
    } catch (e, stackTrace) {
      debugPrint('ProjectTrackingNotifier.loadProjectScores error: $e\n$stackTrace');
      return {};
    }
  }

  Future<bool> saveEvaluation({
    required int projectId,
    required Map<int, int> criteriaScores,
    required int totalScore,
  }) async {
    try {
      await _repository.saveProjectRubricEvaluation(
        projectId,
        criteriaScores,
        totalScore,
      );

      final updatedList = state.projects.map((p) {
        if (p.id == projectId) {
          return p.copyWith(
            totalScore: totalScore,
            isEvaluated: true,
            isSubmitted: true,
          );
        }
        return p;
      }).toList();

      state = state.copyWith(projects: updatedList, activeScores: criteriaScores);
      return true;
    } catch (e, stackTrace) {
      debugPrint('ProjectTrackingNotifier.saveEvaluation error: $e\n$stackTrace');
      return false;
    }
  }
}
