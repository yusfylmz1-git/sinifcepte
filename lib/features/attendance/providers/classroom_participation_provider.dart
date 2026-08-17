import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/classroom_participation_model.dart';
import '../data/repositories/classroom_participation_repository.dart';

enum ParticipationViewMode {
  compactList, // 📋 Hızlı Kompakt Liste
  seatingGrid, // 🪑 Oturma Planı Düzeni
}

final classroomParticipationRepoProvider = Provider<ClassroomParticipationRepository>((ref) {
  return ClassroomParticipationRepository();
});

/// Ders programından o anki aktif dersi algılayan provider
final activeTimetableLessonProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(classroomParticipationRepoProvider);
  return await repo.detectActiveLessonFromTimetable();
});

/// Seçili Sınıf ID
final selectedParticipationClassIdProvider = StateProvider<int?>((ref) => null);

/// Seçili Tarih (YYYY-MM-DD)
final selectedParticipationDateProvider = StateProvider<String>((ref) {
  return DateTime.now().toIso8601String().substring(0, 10);
});

/// Seçili Ders Saati (1..8)
final selectedParticipationLessonHourProvider = StateProvider<int>((ref) => 1);

/// Arayüz Görünüm Modu (Oturma Planı / Kompakt Liste)
final participationViewModeProvider = StateProvider<ParticipationViewMode>((ref) {
  return ParticipationViewMode.compactList;
});

/// Aktif Değerlendirme Oturumu StateNotifier
final currentParticipationSessionProvider = StateNotifierProvider<
    ClassroomParticipationNotifier, AsyncValue<ClassroomParticipationSession?>>((ref) {
  final repo = ref.watch(classroomParticipationRepoProvider);
  return ClassroomParticipationNotifier(repo);
});

/// Tek bir öğrencinin geçmiş son ders katılım ve ödev kayıtlarını getiren FutureProvider
final studentRecentHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, studentId) async {
  final repo = ref.watch(classroomParticipationRepoProvider);
  return await repo.getStudentRecentHistory(studentId, limit: 4);
});

class ClassroomParticipationNotifier
    extends StateNotifier<AsyncValue<ClassroomParticipationSession?>> {
  final ClassroomParticipationRepository _repo;

  ClassroomParticipationNotifier(this._repo) : super(const AsyncValue.data(null));

  /// Belirtilen oturumu veritabanından yükler veya yeni oluşturur
  Future<void> loadSession({
    required int classId,
    required String date,
    required int lessonHour,
    String? subjectName,
    String? className,
  }) async {
    state = const AsyncValue.loading();
    try {
      final session = await _repo.getOrCreateSession(
        classId: classId,
        date: date,
        lessonHour: lessonHour,
        subjectName: subjectName,
        className: className,
      );
      state = AsyncValue.data(session);
    } catch (e, stackTrace) {
      debugPrint('ClassroomParticipationNotifier.loadSession hatası: $e\n$stackTrace');
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Tüm sınıfın ödev durumunu tek tıkla toplu günceller
  void markAllHomework(HomeworkStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      return e.copyWith(homeworkStatus: status);
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Tüm sınıfın araç-gereç durumunu tek tıkla toplu günceller
  void markAllMaterials(MaterialsStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      return e.copyWith(materialsStatus: status);
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Tüm sınıfa toplu katılım yıldızı verir (Örn: 3 Yıldız - Çok İyi)
  void markAllStars(int count) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      return e.copyWith(starsCount: count.clamp(0, 3));
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Tüm sınıfın derse geliş durumunu toplu günceller (Zamanında / Geç)
  void markAllArrival(ArrivalStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      return e.copyWith(arrivalStatus: status);
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Tüm Sınıfı Tek Tıkla Doldur (Ödev: Yaptı, Materyal: Getirdi, Geliş: Zamanında, Katılım: 3 Yıldız Çok İyi)
  void fillAllFullEvaluation() {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      return e.copyWith(
        homeworkStatus: HomeworkStatus.done,
        materialsStatus: MaterialsStatus.ready,
        arrivalStatus: ArrivalStatus.onTime,
        starsCount: 3,
      );
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrencinin ödev durumunu doğrudan ayarlar
  void setHomework(int studentId, HomeworkStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        return e.copyWith(homeworkStatus: status);
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrencinin araç-gereç durumunu doğrudan ayarlar
  void setMaterials(int studentId, MaterialsStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        return e.copyWith(materialsStatus: status);
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrencinin katılım yıldızını doğrudan ayarlar (3: Çok İyi, 2: İyi, 1: Geliştirilmeli, 0: Nötr)
  void setStars(int studentId, int count) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        return e.copyWith(starsCount: count.clamp(0, 3));
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrencinin ödev durumunu döngüsel değiştirir (Yaptı ➔ Eksik ➔ Yapmadı ➔ Yaptı)
  void cycleHomework(int studentId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        HomeworkStatus nextStatus;
        switch (e.homeworkStatus) {
          case HomeworkStatus.done:
            nextStatus = HomeworkStatus.partial;
            break;
          case HomeworkStatus.partial:
            nextStatus = HomeworkStatus.none;
            break;
          case HomeworkStatus.none:
            nextStatus = HomeworkStatus.done;
            break;
          case HomeworkStatus.notGiven:
            nextStatus = HomeworkStatus.done;
            break;
        }
        return e.copyWith(homeworkStatus: nextStatus);
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrencinin araç-gereç durumunu tersine çevirir (Tam ⮂ Eksik)
  void toggleMaterial(int studentId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        final nextStatus = e.materialsStatus == MaterialsStatus.ready
            ? MaterialsStatus.missing
            : MaterialsStatus.ready;
        return e.copyWith(materialsStatus: nextStatus);
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrenciye yıldız ekler (+1)
  void addStar(int studentId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        return e.copyWith(starsCount: (e.starsCount + 1).clamp(0, 3));
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrenciden yıldız siler (-1)
  void removeStar(int studentId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId && e.starsCount > 0) {
        return e.copyWith(starsCount: (e.starsCount - 1).clamp(0, 3));
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrencinin derse geliş durumunu ayarlar
  void setArrival(int studentId, ArrivalStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        return e.copyWith(arrivalStatus: status);
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrenciye özel etiket ekler/çıkarır
  void toggleTag(int studentId, String tag) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        final tags = List<String>.from(e.customTags);
        if (tags.contains(tag)) {
          tags.remove(tag);
        } else {
          tags.add(tag);
        }
        return e.copyWith(customTags: tags);
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Öğrenciye özel gözlem notu ekler
  void setStudentNote(int studentId, String? note) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedEvals = current.evaluations.map((e) {
      if (e.studentId == studentId) {
        return e.copyWith(note: note);
      }
      return e;
    }).toList();

    state = AsyncValue.data(current.copyWith(evaluations: updatedEvals));
  }

  /// Mevcut oturumu ve değerlendirmeleri veritabanına kaydeder
  Future<bool> saveCurrentSession() async {
    final current = state.valueOrNull;
    if (current == null) return false;

    try {
      final newId = await _repo.saveSession(current);
      state = AsyncValue.data(current.copyWith(id: newId));
      return true;
    } catch (e, stackTrace) {
      debugPrint('saveCurrentSession hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Canlı/sıradaki ders için tüm sınıfa tek tıkla tam puan verip kaydeder
  Future<bool> fillAndSaveLiveLesson({
    required int classId,
    required int lessonHour,
    required String subjectName,
    required String className,
    String? date,
  }) async {
    try {
      final dateStr = date ?? DateTime.now().toIso8601String().substring(0, 10);
      final session = await _repo.getOrCreateSession(
        classId: classId,
        date: dateStr,
        lessonHour: lessonHour,
        subjectName: subjectName,
        className: className,
      );

      final fullEvals = session.evaluations.map((e) {
        return e.copyWith(
          homeworkStatus: HomeworkStatus.done,
          materialsStatus: MaterialsStatus.ready,
          arrivalStatus: ArrivalStatus.onTime,
          starsCount: 3,
        );
      }).toList();

      final fullSession = session.copyWith(evaluations: fullEvals);
      await _repo.saveSession(fullSession);
      return true;
    } catch (e, stackTrace) {
      debugPrint('fillAndSaveLiveLesson hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Akademik yıl boyunca henüz girilmemiş tüm dersleri tam puanla ön doldurur
  Future<int> autoFillAcademicYearBaseline({DateTime? startDate, DateTime? endDate}) async {
    try {
      return await _repo.autoFillAcademicYearBaseline(startDate: startDate, endDate: endDate);
    } catch (e, stackTrace) {
      debugPrint('autoFillAcademicYearBaseline hatası: $e\n$stackTrace');
      return 0;
    }
  }
}

