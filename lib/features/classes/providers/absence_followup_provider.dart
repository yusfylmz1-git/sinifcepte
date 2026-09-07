import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/absence_followup_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/repositories/absence_followup_repository.dart';
import '../../../data/repositories/student_repository.dart';
import 'student_provider.dart';

/// AbsenceFollowupRepository Provider
final absenceFollowupRepositoryProvider =
    Provider<AbsenceFollowupRepository>((ref) {
  return AbsenceFollowupRepository();
});

/// Takip listesinin baglandigi ders yili.
///
/// Sinifin KENDI kaydi tercih edilir (arsiv sinifin evraki dogru yili
/// gostersin); kayit bossa takvimden hesaplanir. Belge ureticisi de
/// ayni kurali uyguluyor.
String absenceAcademicYear(ClassModel classModel) {
  final yil = classModel.academicYear.trim();
  return yil.isNotEmpty ? yil : AppDateFormatter.academicYearLabel();
}

/// Devamsiz ogrenci takip listesi (sinif basina).
final absenceFollowupProvider = StateNotifierProvider.family<
    AbsenceFollowupNotifier,
    AsyncValue<List<AbsenceFollowupEntry>>,
    ClassModel>((ref, classModel) {
  return AbsenceFollowupNotifier(
    ref: ref,
    repository: ref.watch(absenceFollowupRepositoryProvider),
    studentRepository: ref.watch(studentRepositoryProvider),
    classModel: classModel,
  );
});

/// Bir sinifta devamsiz isaretli ogrenci kimlikleri.
///
/// Ogrenci listesi ekrani "bu ogrenci devamsiz mi" sorusunu her satirda
/// soruyor; tam kayit yerine yalnizca kimlik kumesi izlenirse liste
/// gereksiz yere bastan cizilmez.
final absentStudentIdsProvider =
    Provider.family<Set<int>, ClassModel>((ref, classModel) {
  final entries = ref.watch(absenceFollowupProvider(classModel)).valueOrNull;
  if (entries == null) return const <int>{};
  return entries.map((e) => e.followup.studentId).toSet();
});

class AbsenceFollowupNotifier
    extends StateNotifier<AsyncValue<List<AbsenceFollowupEntry>>> {
  final Ref _ref;
  final AbsenceFollowupRepository _repository;
  final StudentRepository _studentRepository;
  final ClassModel classModel;

  AbsenceFollowupNotifier({
    required Ref ref,
    required AbsenceFollowupRepository repository,
    required StudentRepository studentRepository,
    required this.classModel,
  })  : _ref = ref,
        _repository = repository,
        _studentRepository = studentRepository,
        super(const AsyncValue.loading()) {
    load();
  }

  int get _classId => classModel.id!;
  String get academicYear => absenceAcademicYear(classModel);

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final students = await _studentRepository.getStudentsByClassId(_classId);
      final entries = await _repository.getEntries(
        classId: _classId,
        academicYear: academicYear,
        students: students,
      );
      state = AsyncValue.data(entries);
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (AbsenceFollowup.load) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-------------------------------------------------------------------');
      state = AsyncValue.error(e, st);
    }
  }

  /// Ogrenciyi devamsiz olarak isaretle.
  Future<bool> mark(int studentId) async {
    try {
      await _repository.mark(
        studentId: studentId,
        classId: _classId,
        academicYear: academicYear,
      );
      await load();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (AbsenceFollowup.mark) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-------------------------------------------------------------------');
      return false;
    }
  }

  /// Toplu isaretleme (ogrenci listesindeki secim modu).
  Future<bool> markBatch(List<int> studentIds) async {
    try {
      await _repository.markBatch(
        studentIds: studentIds,
        classId: _classId,
        academicYear: academicYear,
      );
      await load();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (AbsenceFollowup.markBatch) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('------------------------------------------------------------------------');
      return false;
    }
  }

  /// Neden / not guncelle.
  Future<bool> updateDetails({
    required int studentId,
    required AbsenceReason reason,
    String? note,
  }) async {
    try {
      await _repository.updateDetails(
        studentId: studentId,
        academicYear: academicYear,
        reason: reason,
        note: note,
      );
      await load();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (AbsenceFollowup.updateDetails) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('----------------------------------------------------------------------------');
      return false;
    }
  }

  /// Takipten cikar. Ogrenci silinmez.
  Future<bool> unmark(int studentId) async {
    try {
      await _repository.unmark(
        studentId: studentId,
        academicYear: academicYear,
      );
      await load();
      return true;
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (AbsenceFollowup.unmark) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('---------------------------------------------------------------------');
      return false;
    }
  }

  /// Ogrenci listesi degistikten sonra (ekleme/silme/tasima) tazele.
  void refreshFromStudents() {
    _ref.invalidate(studentListProvider(_classId));
    load();
  }
}
