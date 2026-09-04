import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/class_model.dart';
import '../../../data/repositories/class_repository.dart';

/// ClassRepository Provider
final classRepositoryProvider = Provider<ClassRepository>((ref) {
  return ClassRepository();
});

/// Sınıf Listesi State Notifier Provider
final classListProvider =
    StateNotifierProvider<ClassListNotifier, AsyncValue<List<ClassModel>>>((ref) {
  final repository = ref.watch(classRepositoryProvider);
  return ClassListNotifier(repository);
});

/// Öğretmenin Aktif Rehberlik Sınıfı Provider'ı (Yoksa null döner)
final homeroomClassProvider = Provider<ClassModel?>((ref) {
  final classListAsync = ref.watch(classListProvider);
  return classListAsync.valueOrNull?.where((c) => c.isHomeroom).firstOrNull;
});

class ClassListNotifier extends StateNotifier<AsyncValue<List<ClassModel>>> {
  final ClassRepository _repository;

  ClassListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadClasses();
  }

  /// Tüm sınıfları veritabanından yükle
  Future<void> loadClasses() async {
    try {
      state = const AsyncValue.loading();
      final classes = await _repository.getAllClasses();
      state = AsyncValue.data(classes);
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ClassList.loadClasses) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('--------------------------------------------------------------------');
      state = AsyncValue.error(e, st);
    }
  }

  /// Yeni sınıf ekle
  Future<bool> addClass({
    required String name,
    required String subject,
    required String academicYear,
    String? description,
    bool isHomeroom = false,
  }) async {
    try {
      final newClass = ClassModel(
        name: name,
        subject: subject,
        academicYear: academicYear,
        description: description,
        isHomeroom: isHomeroom,
      );

      await _repository.insertClass(newClass);
      await loadClasses(); // Listeyi yenile
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ClassList.addClass) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('------------------------------------------------------------------');
      return false;
    }
  }

  /// Sınıf güncelle
  Future<bool> updateClass({
    required int id,
    required String name,
    required String subject,
    required String academicYear,
    String? description,
    bool isHomeroom = false,
  }) async {
    try {
      final updatedClass = ClassModel(
        id: id,
        name: name,
        subject: subject,
        academicYear: academicYear,
        description: description,
        isHomeroom: isHomeroom,
      );

      await _repository.updateClass(updatedClass);
      await loadClasses();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ClassList.updateClass) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('---------------------------------------------------------------------');
      return false;
    }
  }

  /// Bir sınıfı Rehberlik Sınıfı olarak ata
  Future<bool> setHomeroomClass(int classId) async {
    try {
      await _repository.setHomeroomClass(classId);
      await loadClasses();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ClassList.setHomeroomClass) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-------------------------------------------------------------------------');
      return false;
    }
  }

  /// Rehberlik sınıfı unvanını kaldır
  Future<bool> clearHomeroomClass(int classId) async {
    try {
      await _repository.clearHomeroomClass(classId);
      await loadClasses();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ClassList.clearHomeroomClass) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('---------------------------------------------------------------------------');
      return false;
    }
  }

  /// Sınıf sil
  Future<bool> deleteClass(int id) async {
    try {
      await _repository.deleteClass(id);
      await loadClasses();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ClassList.deleteClass) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('--------------------------------------------------------------------');
      return false;
    }
  }

  /// Yıl Sonu Sınıfları Atlat (Örn: 5-A -> 6-A)
  Future<bool> upgradeAllClasses() async {
    try {
      final currentClasses = state.valueOrNull ?? [];
      if (currentClasses.isEmpty) return true;

      for (var c in currentClasses) {
        // İlk sayıyı bul ve 1 artır
        final updatedName = c.name.replaceFirstMapped(RegExp(r'\d+'), (match) {
          final int num = int.parse(match.group(0)!);
          return (num + 1).toString();
        });

        // Eğer isminde bir sayı varsa ve arttıysa veritabanını güncelle
        if (updatedName != c.name) {
          final updatedClass = ClassModel(
            id: c.id,
            name: updatedName,
            subject: c.subject,
            academicYear: c.academicYear,
            description: c.description,
            isHomeroom: c.isHomeroom,
          );
          await _repository.updateClass(updatedClass);
        }
      }

      await loadClasses(); // Tüm işlemler bitince listeyi yenile
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (ClassList.upgradeAllClasses) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-------------------------------------------------------------------------');
      return false;
    }
  }
}
