import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/absence_followup_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/repositories/absence_followup_repository.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/repositories/student_repository.dart';
import 'class_provider.dart';
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
///
/// Aile anahtari `int classId` — projedeki diger family provider'lar
/// (studentListProvider, seatingPlanProvider) da oyle.
///
/// ONEMLI: anahtar `ClassModel` OLAMAZ. O sinifin `==` operatoru yok,
/// yani `classListProvider` her yenilendiginde DB'den gelen taze
/// ornek FARKLI bir aile anahtari sayilirdi: provider her seferinde
/// sifirdan kurulur, iki DB sorgusu bosuna atilir ve eski ornekler
/// bellekte birikirdi.
final absenceFollowupProvider = StateNotifierProvider.family<
    AbsenceFollowupNotifier,
    AsyncValue<List<AbsenceFollowupEntry>>,
    int>((ref, classId) {
  return AbsenceFollowupNotifier(
    repository: ref.watch(absenceFollowupRepositoryProvider),
    studentRepository: ref.watch(studentRepositoryProvider),
    classRepository: ref.watch(classRepositoryProvider),
    classId: classId,
  );
});

/// Bir sinifta devamsiz isaretli ogrenci kimlikleri.
///
/// Ogrenci listesi ekrani "bu ogrenci devamsiz mi" sorusunu her satirda
/// soruyor; tam kayit yerine yalnizca kimlik kumesi izlenirse liste
/// gereksiz yere bastan cizilmez.
final absentStudentIdsProvider =
    Provider.family<Set<int>, int>((ref, classId) {
  final entries = ref.watch(absenceFollowupProvider(classId)).valueOrNull;
  if (entries == null) return const <int>{};
  return entries.map((e) => e.followup.studentId).toSet();
});

class AbsenceFollowupNotifier
    extends StateNotifier<AsyncValue<List<AbsenceFollowupEntry>>> {
  final AbsenceFollowupRepository _repository;
  final StudentRepository _studentRepository;
  final ClassRepository _classRepository;
  final int classId;

  /// Yuklemede sinif kaydindan okunan ders yili.
  ///
  /// Ekrandan gelen `ClassModel`'e guvenilmiyor: cagiran ekran eski
  /// bir kopya tutuyor olabilir ve yil yanlis okunursa kayit BASKA
  /// bir yila yazilir, liste bos gorunurdu.
  String? _academicYear;

  AbsenceFollowupNotifier({
    required AbsenceFollowupRepository repository,
    required StudentRepository studentRepository,
    required ClassRepository classRepository,
    required this.classId,
  })  : _repository = repository,
        _studentRepository = studentRepository,
        _classRepository = classRepository,
        super(const AsyncValue.loading()) {
    load();
  }

  /// Sinif kaydindan ders yili. Bir kez okunur, sonra onbellekten.
  Future<String> _resolveAcademicYear() async {
    final onbellek = _academicYear;
    if (onbellek != null) return onbellek;

    final classModel = await _classRepository.getClassById(classId);
    final yil = classModel != null
        ? absenceAcademicYear(classModel)
        : AppDateFormatter.academicYearLabel();
    _academicYear = yil;
    return yil;
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final yil = await _resolveAcademicYear();
      final students = await _studentRepository.getStudentsByClassId(classId);
      final entries = await _repository.getEntries(
        classId: classId,
        academicYear: yil,
        students: students,
      );
      if (!mounted) return;
      state = AsyncValue.data(entries);
    } catch (e, st) {
      debugPrint('---------------- HATA DETAYI (AbsenceFollowup.load) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint('-------------------------------------------------------------------');
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Ogrenciyi devamsiz olarak isaretle.
  Future<bool> mark(int studentId) async {
    try {
      await _repository.mark(
        studentId: studentId,
        classId: classId,
        academicYear: await _resolveAcademicYear(),
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
        classId: classId,
        academicYear: await _resolveAcademicYear(),
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
        classId: classId,
        academicYear: await _resolveAcademicYear(),
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
        classId: classId,
        academicYear: await _resolveAcademicYear(),
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
}
