import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/models/curriculum_outcome_model.dart';
import '../data/repositories/curriculum_outcome_repository.dart';

/// Repository Provider
final curriculumRepositoryProvider = Provider<CurriculumOutcomeRepository>((ref) {
  return CurriculumOutcomeRepository();
});

/// Mevcut Sınıf Seviyeleri (1..12)
final availableGradesProvider = FutureProvider<List<int>>((ref) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return await repo.getAvailableGrades();
});

/// Seçili Sınıf (null ise Sınıf Seçim Ekranı gösterilir)
final selectedGradeProvider = StateProvider<int?>((ref) => null);

/// Seçili Sınıfa ait Dersler
final availableSubjectsForGradeProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, grade) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return await repo.getAvailableSubjects(grade);
});

/// Seçili Ders (null ise Branş Seçim Ekranı gösterilir)
final selectedSubjectProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Favori Modu Açık mı?
final isFavoritesModeProvider = StateProvider<bool>((ref) => false);

/// Görünüm Türü: true = Yatay Carousel (PageView), false = Dikey Liste
final isCarouselViewProvider = StateProvider<bool>((ref) => true);

/// Arama Sorgusu
final outcomeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Aktif Takvim Haftası (1..39)
final activeAcademicWeekProvider = StateProvider<int>((ref) {
  return AppDateFormatter.getCurrentAcademicWeek();
});

/// Favori Dersler State Notifier
final favoriteSubjectsProvider =
    StateNotifierProvider<FavoriteSubjectsNotifier, Set<String>>((ref) {
  final repo = ref.watch(curriculumRepositoryProvider);
  return FavoriteSubjectsNotifier(repo);
});

class FavoriteSubjectsNotifier extends StateNotifier<Set<String>> {
  final CurriculumOutcomeRepository _repo;

  FavoriteSubjectsNotifier(this._repo) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await _repo.getFavoriteSubjectKeys();
    state = favs;
  }

  Future<void> toggleFavorite(int gradeLevel, String subjectCode, String publisher) async {
    await _repo.toggleFavoriteSubject(gradeLevel, subjectCode, publisher);
    final favs = await _repo.getFavoriteSubjectKeys();
    state = favs;
  }

  bool isFav(int gradeLevel, String subjectCode, String publisher) {
    return state.contains('${gradeLevel}_${subjectCode}_$publisher');
  }
}

/// Seçili Sınıf ve Branşa göre 39 Haftalık Kazanım Listesi
final currentCurriculumOutcomesProvider =
    FutureProvider.autoDispose<List<CurriculumOutcomeModel>>((ref) async {
  final grade = ref.watch(selectedGradeProvider);
  final subject = ref.watch(selectedSubjectProvider);
  final searchQuery = ref.watch(outcomeSearchQueryProvider);

  if (grade == null || subject == null) {
    return [];
  }

  final repo = ref.watch(curriculumRepositoryProvider);
  final subjectCode = subject['subject_code'] as String? ?? 'GENEL';
  final publisher = subject['publisher'] as String?;

  return await repo.getOutcomes(
    gradeLevel: grade,
    subjectCode: subjectCode,
    publisher: publisher,
    searchQuery: searchQuery,
  );
});
