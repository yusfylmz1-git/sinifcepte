import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../data/models/student_model.dart';
import '../models/exam_model.dart';
import '../models/project_tracking_model.dart';
import '../models/quiz_tracking_model.dart';

/// SınıfCepte - Sınav İşlemleri Repository Katmanı
class ExamOperationsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ==========================================
  // --- 1. QUIZ & SÖZLÜ TABLOSU ---
  // ==========================================

  Future<QuizCizelgeModel> getOrCreateQuizCizelge(
    String className,
    String subject, {
    String category = 'quiz',
  }) async {
    try {
      final map = await _dbHelper.getOrCreateQuizCizelge(
        className,
        subject,
        category: category,
      );
      return QuizCizelgeModel.fromMap(map);
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.getOrCreateQuizCizelge error: $e\n$stackTrace');
      return QuizCizelgeModel(
        className: className,
        subject: subject,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<List<QuizKolonModel>> getQuizKolonlari(int cizelgeId) async {
    try {
      final list = await _dbHelper.getQuizKolonlari(cizelgeId);
      return list.map((m) => QuizKolonModel.fromMap(m)).toList();
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.getQuizKolonlari error: $e\n$stackTrace');
      return [];
    }
  }

  Future<int> addQuizKolon(QuizKolonModel kolon) async {
    try {
      return await _dbHelper.addQuizKolon(kolon.toMap());
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.addQuizKolon error: $e\n$stackTrace');
      return -1;
    }
  }

  Future<void> deleteQuizKolon(int kolonId) async {
    try {
      await _dbHelper.deleteQuizKolon(kolonId);
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.deleteQuizKolon error: $e\n$stackTrace');
    }
  }

  /// studentId -> (kolonId -> score) haritası döner
  Future<Map<int, Map<int, int>>> getQuizNotlariForCizelge(int cizelgeId) async {
    try {
      final list = await _dbHelper.getQuizNotlariForCizelge(cizelgeId);
      final map = <int, Map<int, int>>{};

      for (final row in list) {
        final studentId = row['ogrenci_id'] as int;
        final kolonId = row['kolon_id'] as int;
        final puan = row['puan'] as int?;

        if (puan != null) {
          map.putIfAbsent(studentId, () => {})[kolonId] = puan;
        }
      }
      return map;
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.getQuizNotlariForCizelge error: $e\n$stackTrace');
      return {};
    }
  }

  Future<void> saveQuizNot(int kolonId, int studentId, int? score) async {
    try {
      await _dbHelper.saveQuizNot(kolonId, studentId, score);
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.saveQuizNot error: $e\n$stackTrace');
    }
  }

  // ==========================================
  // --- 2. PROJE & ÖDEV RUBRIC ---
  // ==========================================

  Future<List<ProjectKriterModel>> getProjectKriterleri() async {
    try {
      final list = await _dbHelper.getProjectKriterleri();
      return list.map((m) => ProjectKriterModel.fromMap(m)).toList();
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.getProjectKriterleri error: $e\n$stackTrace');
      return [];
    }
  }

  Future<List<ProjectTakipModel>> getProjectTakipList(
    String className,
    String subject,
  ) async {
    try {
      final list = await _dbHelper.getProjectTakipList(className, subject);
      return list.map((m) => ProjectTakipModel.fromMap(m)).toList();
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.getProjectTakipList error: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> initProjectTakipForClass(
    String className,
    String subject,
    List<StudentModel> students, {
    String defaultTopic = 'Dönem Projesi / Ödevi',
  }) async {
    try {
      final studentMaps = students
          .map((s) => {
                'id': s.id,
                'first_name': s.firstName,
                'last_name': s.lastName,
              })
          .toList();

      await _dbHelper.initProjectTakipForClass(
        className,
        subject,
        studentMaps,
        defaultTopic: defaultTopic,
      );
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.initProjectTakipForClass error: $e\n$stackTrace');
    }
  }

  Future<void> toggleProjectSubmission(int projectId, bool isSubmitted) async {
    try {
      await _dbHelper.toggleProjectSubmission(projectId, isSubmitted);
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.toggleProjectSubmission error: $e\n$stackTrace');
    }
  }

  Future<void> updateProjectTopic(int projectId, String newTopic) async {
    try {
      await _dbHelper.updateProjectTopic(projectId, newTopic);
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.updateProjectTopic error: $e\n$stackTrace');
    }
  }

  Future<Map<int, int>> getProjectPuanlari(int projectId) async {
    try {
      final list = await _dbHelper.getProjectPuanlari(projectId);
      final map = <int, int>{};
      for (final r in list) {
        final kId = r['kriter_id'] as int?;
        final score = r['puan'] as int?;
        if (kId != null && score != null) {
          map[kId] = score;
        }
      }
      return map;
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.getProjectPuanlari error: $e\n$stackTrace');
      return {};
    }
  }

  Future<void> saveProjectRubricEvaluation(
    int projectId,
    Map<int, int> kriterPuanlari,
    int totalScore,
  ) async {
    try {
      await _dbHelper.saveProjectRubricEvaluation(
        projectId,
        kriterPuanlari,
        totalScore,
      );
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.saveProjectRubricEvaluation error: $e\n$stackTrace');
    }
  }

  // ==========================================
  // --- 3. MERKEZİ & OKUL SINAVLARI ---
  // ==========================================

  Future<List<ExamModel>> getAllExams() async {
    try {
      final generalMaps = await _dbHelper.getGenelSinavlar();
      final favIds = (await _dbHelper.getFavoriSinavDocIds()).toSet();
      final schoolMaps = await _dbHelper.getKisiselSinavlar();

      final generalExams = generalMaps.map((m) {
        final docId = m['doc_id'] as String? ?? '';
        return ExamModel.fromMap(m, isFav: favIds.contains(docId), isSchool: false);
      }).toList();

      final schoolExams = schoolMaps.map((m) {
        return ExamModel.fromMap(m, isFav: false, isSchool: true);
      }).toList();

      final all = [...generalExams, ...schoolExams];
      all.sort((a, b) => a.examDate.compareTo(b.examDate));
      return all;
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.getAllExams error: $e\n$stackTrace');
      return [];
    }
  }

  Future<bool> toggleFavoriteExam(String docId) async {
    try {
      return await _dbHelper.toggleFavoriSinav(docId);
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.toggleFavoriteExam error: $e\n$stackTrace');
      return false;
    }
  }

  Future<int> addSchoolExam(ExamModel exam) async {
    try {
      return await _dbHelper.addKisiselSinav({
        'doc_id': 'okul_${DateTime.now().millisecondsSinceEpoch}',
        'sinav_adi': exam.title,
        'kurum': 'OKUL',
        'sinav_tarihi': exam.examDate.toIso8601String(),
        'son_basvuru_tarihi': exam.applicationDeadline?.toIso8601String(),
        // Sinif adi eskiden `basvuru_linki` sutununa yaziliyordu. Model onu
        // `sinif` sutunundan okudugu icin secilen sinif geri gelmiyor, ustelik
        // ekran dolu bir link gorup "5-A"yi adres olarak acmaya calisiyordu.
        'sinif': exam.className,
      });
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.addSchoolExam error: $e\n$stackTrace');
      return -1;
    }
  }

  Future<void> deleteSchoolExam(int id) async {
    try {
      await _dbHelper.deleteKisiselSinav(id);
    } catch (e, stackTrace) {
      debugPrint('ExamOperationsRepository.deleteSchoolExam error: $e\n$stackTrace');
    }
  }
}
