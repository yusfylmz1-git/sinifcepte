import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database_helper.dart';
import '../models/curriculum_outcome_model.dart';

/// SınıfCepte - Müfredat ve Kazanım Veri Deposu (Yüksek Performanslı In-Memory Caching)
class CurriculumOutcomeRepository {
  final DatabaseHelper _dbHelper;

  CurriculumOutcomeRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const String _favoritePrefKey = 'sinifcepte_favorite_subjects';

  // Hız ve sıfır gecikme için RAM önbelleği
  bool _isSeeded = false;
  final Map<int, List<Map<String, dynamic>>> _subjectsCache = {};
  final Map<String, List<CurriculumOutcomeModel>> _outcomesCache = {};

  /// Veritabanının tohumlandığından emin olur (%100 Çevrimdışı Çalışma)
  Future<void> ensureSeeded({bool force = false}) async {
    if (_isSeeded && !force) return;
    await _dbHelper.seedCurriculumOutcomesFromAssets(force: force);
    _isSeeded = true;
  }

  /// Tüm 1-12. sınıf seviyelerini anında getirir
  Future<List<int>> getAvailableGrades() async {
    await ensureSeeded();
    // 1-12 tüm sınıfların eksiksiz listesi
    return const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  }

  /// Seçilen sınıftaki tüm dersleri ve yayınevi bilgilerini getirir (Önbellekten 0 ms)
  Future<List<Map<String, dynamic>>> getAvailableSubjects(int gradeLevel) async {
    if (_subjectsCache.containsKey(gradeLevel)) {
      return _subjectsCache[gradeLevel]!;
    }

    await ensureSeeded();
    final list = await _dbHelper.mevcutDersleriGetir(gradeLevel);
    _subjectsCache[gradeLevel] = list;
    return list;
  }

  /// Seçilen sınıf, branş ve yayınevine göre 39+1 haftalık kazanım akışını getirir
  Future<List<CurriculumOutcomeModel>> getOutcomes({
    required int gradeLevel,
    required String subjectCode,
    String? publisher,
    String? searchQuery,
  }) async {
    final cacheKey = '${gradeLevel}_${subjectCode}_${publisher ?? 'ALL'}_${searchQuery ?? ''}';
    if (_outcomesCache.containsKey(cacheKey)) {
      return _outcomesCache[cacheKey]!;
    }

    await ensureSeeded();
    final rawList = await _dbHelper.kazanimlariGetir(
      gradeLevel: gradeLevel,
      subjectCode: subjectCode,
      publisher: publisher,
      searchQuery: searchQuery,
    );

    final list = rawList.map((m) => CurriculumOutcomeModel.fromMap(m)).toList();

    // 40. Hafta: Resmî Yaz Tatili ve Dinlenme Dönemi Bilgilendirme Kartı
    if (searchQuery == null || searchQuery.isEmpty || searchQuery.toLowerCase().contains('tatil') || searchQuery.toLowerCase().contains('yaz')) {
      final subjectName = list.isNotEmpty ? list.first.subjectName : 'Ders';
      list.add(CurriculumOutcomeModel(
        docId: 'plan_${gradeLevel}_${subjectCode}_summer_40',
        gradeLevel: gradeLevel,
        subjectCode: subjectCode,
        subjectName: subjectName,
        publisher: publisher ?? 'MEB Yayınları',
        fullTitle: '$gradeLevel. Sınıf - $subjectName - Yaz Tatili',
        weekNumber: 40,
        unitTitle: '🏖️ Yaz Tatili & Dinlenme Dönemi',
        topicTitle: 'Yaz Tatili',
        outcomeDescription:
            '39 haftalık resmî eğitim ve öğretim maratonu başarıyla tamamlanmıştır! Tüm öğretmen ve öğrencilerimize sağlık, mutluluk ve huzur dolu bir yaz tatili dileriz. 🌴☀️🎈',
        isHolidayWeek: true,
        holidayNote: 'Yaz Tatili',
      ));
    }

    _outcomesCache[cacheKey] = list;
    return list;
  }

  /// Önbelleği temizle (yeni veri yüklendiğinde)
  void clearCache() {
    _subjectsCache.clear();
    _outcomesCache.clear();
  }

  /// Tüm kazanımlarda global arama yapar
  Future<List<CurriculumOutcomeModel>> searchOutcomes(
    String query, {
    int? gradeLevel,
  }) async {
    await ensureSeeded();
    final rawList = await _dbHelper.kazanimlariGetir(
      gradeLevel: gradeLevel,
      searchQuery: query,
    );
    return rawList.map((m) => CurriculumOutcomeModel.fromMap(m)).toList();
  }

  // --- FAVORİ DERS YÖNETİMİ (SharedPreferences) ---

  String _buildFavoriteKey(int gradeLevel, String subjectCode, String publisher) {
    return '${gradeLevel}_${subjectCode}_$publisher';
  }

  Future<Set<String>> getFavoriteSubjectKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favoritePrefKey) ?? [];
      return list.toSet();
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (CurriculumOutcomeRepository.getFavoriteSubjectKeys) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('--------------------------------------------------------------------------------------------------');
      return {};
    }
  }

  Future<bool> toggleFavoriteSubject(int gradeLevel, String subjectCode, String publisher) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = await getFavoriteSubjectKeys();
      final key = _buildFavoriteKey(gradeLevel, subjectCode, publisher);

      final isNowFavorite = !set.contains(key);
      if (isNowFavorite) {
        set.add(key);
      } else {
        set.remove(key);
      }

      await prefs.setStringList(_favoritePrefKey, set.toList());
      return isNowFavorite;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (CurriculumOutcomeRepository.toggleFavoriteSubject) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('------------------------------------------------------------------------------------------------');
      return false;
    }
  }

  Future<bool> isFavorite(int gradeLevel, String subjectCode, String publisher) async {
    final set = await getFavoriteSubjectKeys();
    return set.contains(_buildFavoriteKey(gradeLevel, subjectCode, publisher));
  }
}
