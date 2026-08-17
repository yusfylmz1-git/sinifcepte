import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/student_repository.dart';

/// StudentRepository Provider
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository();
});

/// Öğrenci Listesi Family State Notifier Provider
final studentListProvider = StateNotifierProvider.family<StudentListNotifier, AsyncValue<List<StudentModel>>, int>((ref, classId) {
  final repository = ref.watch(studentRepositoryProvider);
  return StudentListNotifier(repository, classId);
});

class StudentListNotifier extends StateNotifier<AsyncValue<List<StudentModel>>> {
  final StudentRepository _repository;
  final int classId;

  StudentListNotifier(this._repository, this.classId) : super(const AsyncValue.loading()) {
    loadStudents();
  }

  /// Sınıfa ait tüm öğrencileri veritabanından yükle
  Future<void> loadStudents() async {
    try {
      state = const AsyncValue.loading();
      final students = await _repository.getStudentsByClassId(classId);
      state = AsyncValue.data(students);
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (StudentList.loadStudents) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-----------------------------------------------------------------------');
      state = AsyncValue.error(e, st);
    }
  }

  /// Yeni öğrenci ekle
  Future<bool> addStudent({
    required int schoolNumber,
    required String firstName,
    required String lastName,
    String gender = 'Erkek',
    String? parentName,
    String? parentPhone,
    String? notes,
  }) async {
    try {
      final student = StudentModel(
        classId: classId,
        schoolNumber: schoolNumber,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        parentName: parentName,
        parentPhone: parentPhone,
        notes: notes,
      );

      await _repository.insertStudent(student);
      await loadStudents();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (StudentList.addStudent) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('---------------------------------------------------------------------');
      return false;
    }
  }

  /// Öğrenci bilgilerini güncelle
  Future<bool> updateStudent({
    required int id,
    required int schoolNumber,
    required String firstName,
    required String lastName,
    String gender = 'Erkek',
    String? parentName,
    String? parentPhone,
    String? notes,
  }) async {
    try {
      final updatedStudent = StudentModel(
        id: id,
        classId: classId,
        schoolNumber: schoolNumber,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        parentName: parentName,
        parentPhone: parentPhone,
        notes: notes,
      );

      await _repository.updateStudent(updatedStudent);
      await loadStudents();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (StudentList.updateStudent) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-----------------------------------------------------------------------');
      return false;
    }
  }

  /// Veli iletişim bilgilerini hızlıca güncelle
  Future<bool> updateParentContact({
    required int studentId,
    String? parentName,
    String? parentPhone,
    String? notes,
  }) async {
    try {
      final currentStudents = state.value;
      if (currentStudents == null) return false;

      final student = currentStudents.firstWhere((s) => s.id == studentId);
      final updatedStudent = student.copyWith(
        parentName: parentName,
        parentPhone: parentPhone,
        notes: notes,
      );

      await _repository.updateStudent(updatedStudent);
      await loadStudents();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (StudentList.updateParentContact) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-----------------------------------------------------------------------------');
      return false;
    }
  }

  /// Öğrenci sil
  Future<bool> deleteStudent(int id) async {
    try {
      await _repository.deleteStudent(id);
      await loadStudents();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (StudentList.deleteStudent) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('------------------------------------------------------------------------');
      return false;
    }
  }

  /// Öğrencileri toplu sil
  Future<bool> deleteStudentsBatch(List<int> ids) async {
    try {
      await _repository.deleteStudentsBatch(ids);
      await loadStudents();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (StudentList.deleteStudentsBatch) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('------------------------------------------------------------------------');
      return false;
    }
  }

  /// Öğrencileri başka sınıfa toplu taşı
  Future<bool> moveStudentsBatch(List<int> ids, int newClassId) async {
    try {
      await _repository.moveStudentsBatch(ids, newClassId);
      await loadStudents();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (StudentList.moveStudentsBatch) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('------------------------------------------------------------------------');
      return false;
    }
  }
}
