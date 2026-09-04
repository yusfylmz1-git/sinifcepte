import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/student_model.dart';
import '../models/seating_plan_model.dart';
import '../data/services/seating_plan_service.dart';

final seatingPlanProvider = StateNotifierProvider.family<SeatingPlanNotifier, AsyncValue<SeatingPlanModel>, int>((ref, classId) {
  return SeatingPlanNotifier(ref.read(seatingPlanServiceProvider), classId);
});

class SeatingPlanNotifier extends StateNotifier<AsyncValue<SeatingPlanModel>> {
  final SeatingPlanService _service;
  final int _classId;

  SeatingPlanNotifier(this._service, this._classId) : super(const AsyncValue.loading()) {
    loadPlan();
  }

  Future<void> loadPlan() async {
    try {
      state = const AsyncValue.loading();
      final plan = await _service.getSeatingPlan(_classId);
      if (plan != null) {
        state = AsyncValue.data(plan);
      } else {
        state = AsyncValue.data(SeatingPlanModel(classId: _classId));
      }
    } catch (e, st) {
      debugPrint('Oturma planı yükleme hatası: $e\n$st');
      state = AsyncValue.error(e, st);
    }
  }

  /// Öğrenci sayısına göre otomatik sıra (satır) sayısını garanti eder
  Future<void> ensureCapacityForStudents(int studentCount) async {
    final currentPlan = state.value;
    if (currentPlan == null || studentCount <= 0) return;

    final blocks = currentPlan.columns; // Blok sayısı (2, 3, 4)
    final seatsPerRow = blocks * 2; // Her satırdaki koltuk sayısı
    final requiredRows = max(4, (studentCount / seatsPerRow).ceil());

    if (currentPlan.rows < requiredRows) {
      final updatedPlan = currentPlan.copyWith(rows: requiredRows);
      state = AsyncValue.data(updatedPlan);
      await _service.saveSeatingPlan(updatedPlan);
    }
  }

  /// Sinifta artik bulunmayan ogrencilerin koltuk atamalarini siler.
  ///
  /// Atamalar JSON metni icinde tutuldugu icin ogrenci satiri silindiginde
  /// SQLite'in ON DELETE CASCADE kurali bunlari temizleyemiyor. Sonucta
  /// koltuk ekranda bos gorunuyor ama dolu sayiliyor, "23/30 yerlesti"
  /// sayaci sisiyor ve o koltuk bir daha kullanilamiyordu.
  Future<void> pruneMissingStudents(Iterable<int> liveStudentIds) async {
    final currentPlan = state.value;
    if (currentPlan == null || currentPlan.assignments.isEmpty) return;

    final liveIds = liveStudentIds.toSet();
    final pruned = Map<int, String>.from(currentPlan.assignments)
      ..removeWhere((studentId, _) => !liveIds.contains(studentId));

    if (pruned.length == currentPlan.assignments.length) return;

    final updatedPlan = currentPlan.copyWith(assignments: pruned);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// Blok düzenini değiştirir (2 Blok, 3 Blok, 4 Blok) ve satırları öğrenci sayısına göre ayarlar
  Future<void> updateBlocksLayout(int blockCount, int studentCount) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final seatsPerRow = blockCount * 2;
    final requiredRows = max(4, (studentCount / seatsPerRow).ceil());

    // Yeni blok sayısına sığmayan eski atamaları güvenle temizle veya koru
    final newAssignments = Map<int, String>.from(currentPlan.assignments);
    newAssignments.removeWhere((key, value) {
      final parts = value.split(',');
      if (parts.length >= 3) {
        final b = int.tryParse(parts[0]) ?? 0;
        final r = int.tryParse(parts[1]) ?? 0;
        return b >= blockCount || r >= requiredRows;
      }
      return false;
    });

    final updatedPlan = currentPlan.copyWith(
      columns: blockCount,
      rows: requiredRows,
      assignments: newAssignments,
    );
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// Manuel sıra (satır) ekle
  Future<void> addRow() async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final updatedPlan = currentPlan.copyWith(rows: currentPlan.rows + 1);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// Manuel sıra (satır) kaldır (en az 3 sıra kalacak şekilde)
  Future<void> removeRow() async {
    final currentPlan = state.value;
    if (currentPlan == null || currentPlan.rows <= 3) return;

    final targetRow = currentPlan.rows - 1;
    final newAssignments = Map<int, String>.from(currentPlan.assignments);

    // Silinen satırdaki öğrencileri havuza gönder
    newAssignments.removeWhere((key, value) {
      final parts = value.split(',');
      if (parts.length >= 2) {
        final r = int.tryParse(parts[1]) ?? 0;
        return r == targetRow;
      }
      return false;
    });

    final updatedPlan = currentPlan.copyWith(
      rows: currentPlan.rows - 1,
      assignments: newAssignments,
    );
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  Future<void> updateGridSize(int rows, int columns) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final updatedPlan = currentPlan.copyWith(rows: rows, columns: columns);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// Belirli bir koltuğa öğrenci ata
  Future<void> assignSeat(int studentId, int block, int row, int seat) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final targetPos = '$block,$row,$seat';
    final newAssignments = Map<int, String>.from(currentPlan.assignments);

    // Eğer o koltukta oturan başka öğrenci varsa onu kaldır
    newAssignments.removeWhere((key, value) => value == targetPos);

    // Öğrenci zaten başka koltuktaysa eski yerinden kaldır
    newAssignments[studentId] = targetPos;

    final updatedPlan = currentPlan.copyWith(assignments: newAssignments);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// Öğrenciyi koltuktan kaldır
  Future<void> removeStudent(int studentId) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final newAssignments = Map<int, String>.from(currentPlan.assignments);
    newAssignments.remove(studentId);

    final updatedPlan = currentPlan.copyWith(assignments: newAssignments);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// İki öğrencinin yerini takas et (Swap)
  Future<void> swapStudents(int studentId1, int studentId2) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final newAssignments = Map<int, String>.from(currentPlan.assignments);
    final pos1 = newAssignments[studentId1];
    final pos2 = newAssignments[studentId2];

    if (pos1 != null && pos2 != null) {
      newAssignments[studentId1] = pos2;
      newAssignments[studentId2] = pos1;
    } else if (pos1 != null && pos2 == null) {
      newAssignments.remove(studentId1);
      newAssignments[studentId2] = pos1;
    } else if (pos1 == null && pos2 != null) {
      newAssignments.remove(studentId2);
      newAssignments[studentId1] = pos2;
    }

    final updatedPlan = currentPlan.copyWith(assignments: newAssignments);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// Tüm atamaları temizle
  Future<void> clearAllAssignments() async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final updatedPlan = currentPlan.copyWith(assignments: {});
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// Tüm boş koltukların koordinat listesini üretir
  List<String> _getAllSeatPositions(int blocks, int rows) {
    final positions = <String>[];
    for (int r = 0; r < rows; r++) {
      for (int b = 0; b < blocks; b++) {
        for (int s = 0; s < 2; s++) {
          positions.add('$b,$r,$s');
        }
      }
    }
    return positions;
  }

  /// 1. SİHİRLİ DAĞITIM: Rastgele Dağıt
  Future<void> autoAssignRandom(List<StudentModel> students) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    // Önce kapasitenin yeterli olduğundan emin ol
    final blocks = currentPlan.columns;
    final seatsPerRow = blocks * 2;
    final requiredRows = max(currentPlan.rows, (students.length / seatsPerRow).ceil());

    final positions = _getAllSeatPositions(blocks, requiredRows);
    final shuffled = List<StudentModel>.from(students)..shuffle(Random());

    final Map<int, String> newAssignments = {};
    for (int i = 0; i < shuffled.length && i < positions.length; i++) {
      newAssignments[shuffled[i].id!] = positions[i];
    }

    final updatedPlan = currentPlan.copyWith(rows: requiredRows, assignments: newAssignments);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// 2. SİHİRLİ DAĞITIM: Kız - Erkek Dengeli (Yan Yana) Dağıt
  Future<void> autoAssignGenderBalanced(List<StudentModel> students) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final blocks = currentPlan.columns;
    final seatsPerRow = blocks * 2;
    final requiredRows = max(currentPlan.rows, (students.length / seatsPerRow).ceil());

    // Cinsiyeti 'Kiz'/'Erkek' olarak yazmayan ogrenciler (e-Okul listesinde
    // bu sutun bos gelebiliyor) her iki kumeye de girmedigi icin dagitim
    // disinda kaliyor, ekranda kayboluyordu. Artik erkek kumesine
    // eklenerek mutlaka bir koltuk aliyorlar.
    final girls = students
        .where((s) => s.gender.toLowerCase().contains('kız'))
        .toList()
      ..shuffle(Random());
    final boys = students
        .where((s) => !s.gender.toLowerCase().contains('kız'))
        .toList()
      ..shuffle(Random());

    final Map<int, String> newAssignments = {};
    int girlIndex = 0;
    int boyIndex = 0;

    for (int r = 0; r < requiredRows; r++) {
      for (int b = 0; b < blocks; b++) {
        // Sol Koltuk (Seat 0)
        final pos0 = '$b,$r,0';
        if (girlIndex < girls.length) {
          newAssignments[girls[girlIndex].id!] = pos0;
          girlIndex++;
        } else if (boyIndex < boys.length) {
          newAssignments[boys[boyIndex].id!] = pos0;
          boyIndex++;
        }

        // Sağ Koltuk (Seat 1)
        final pos1 = '$b,$r,1';
        if (boyIndex < boys.length) {
          newAssignments[boys[boyIndex].id!] = pos1;
          boyIndex++;
        } else if (girlIndex < girls.length) {
          newAssignments[girls[girlIndex].id!] = pos1;
          girlIndex++;
        }
      }
    }

    final updatedPlan = currentPlan.copyWith(rows: requiredRows, assignments: newAssignments);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// 3. SİHİRLİ DAĞITIM: Okul Numarasına Göre Sıralı Dağıt
  Future<void> autoAssignByNumber(List<StudentModel> students) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final blocks = currentPlan.columns;
    final seatsPerRow = blocks * 2;
    final requiredRows = max(currentPlan.rows, (students.length / seatsPerRow).ceil());

    final positions = _getAllSeatPositions(blocks, requiredRows);
    final sorted = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    final Map<int, String> newAssignments = {};
    for (int i = 0; i < sorted.length && i < positions.length; i++) {
      newAssignments[sorted[i].id!] = positions[i];
    }

    final updatedPlan = currentPlan.copyWith(rows: requiredRows, assignments: newAssignments);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }

  /// 4. SİHİRLİ DAĞITIM: Alfabetik Sıralı Dağıt
  Future<void> autoAssignAlphabetical(List<StudentModel> students) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final blocks = currentPlan.columns;
    final seatsPerRow = blocks * 2;
    final requiredRows = max(currentPlan.rows, (students.length / seatsPerRow).ceil());

    final positions = _getAllSeatPositions(blocks, requiredRows);
    final sorted = List<StudentModel>.from(students)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    final Map<int, String> newAssignments = {};
    for (int i = 0; i < sorted.length && i < positions.length; i++) {
      newAssignments[sorted[i].id!] = positions[i];
    }

    final updatedPlan = currentPlan.copyWith(rows: requiredRows, assignments: newAssignments);
    state = AsyncValue.data(updatedPlan);
    await _service.saveSeatingPlan(updatedPlan);
  }
}
