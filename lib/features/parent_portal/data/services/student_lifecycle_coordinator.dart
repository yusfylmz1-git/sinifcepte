import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../models/parent_link_model.dart';
import '../../providers/parent_token_provider.dart';
import '../repositories/cloud_token_repository.dart';
import '../repositories/parent_token_repository.dart';
import 'kvkk_consent_service.dart';
import 'parent_lifecycle_service.dart';
import 'student_lifecycle_policy.dart';

/// Bir yaşam döngüsü işleminin sonucu (öğretmene gösterilir).
class LifecycleOutcome {
  /// Erişimi kapatılan veli sayısı.
  final int affectedParents;

  /// Kapatılan referans kodu sayısı.
  final int revokedTokens;

  /// Bulut tarafı tamamlanabildi mi? (İnternet yoksa false.)
  final bool cloudSynced;

  const LifecycleOutcome({
    this.affectedParents = 0,
    this.revokedTokens = 0,
    this.cloudSynced = true,
  });

  bool get hadParents => affectedParents > 0;

  /// Öğretmene gösterilecek özet.
  String get summary {
    if (affectedParents == 0 && revokedTokens == 0) {
      return 'Bu öğrenciye bağlı veli erişimi yoktu.';
    }
    final parts = <String>[];
    if (affectedParents > 0) parts.add('$affectedParents veli erişimi');
    if (revokedTokens > 0) parts.add('$revokedTokens referans kodu');
    final what = parts.join(' ve ');
    if (!cloudSynced) {
      return '$what cihazda kapatıldı, ancak buluta ulaşılamadı. '
          'İnternet bağlantısı gelince tekrar deneyin.';
    }
    return '$what kapatıldı.';
  }
}

/// Öğrenci yaşam döngüsü olaylarını uçtan uca yürütür.
///
/// [StudentLifecyclePolicy] neyin yapılacağına karar verir; bu sınıf onu
/// hem cihazda hem bulutta uygular.
///
/// Bu katman yoktu: `ParentLifecycleService` yazılmıştı ama hiçbir
/// yerden çağrılmıyordu ve yalnızca cihazdaki veriye dokunuyordu. Sonuç
/// olarak okuldan ayrılmış bir öğrencinin velisi duyuruları görmeye ve
/// öğretmene yazmaya devam edebiliyordu — bağ ve sınıf erişimi bulutta
/// ayakta kaldığı için.
class StudentLifecycleCoordinator {
  final ParentTokenRepository _tokens;
  final CloudTokenRepository _cloud;

  StudentLifecycleCoordinator({
    ParentTokenRepository? tokens,
    CloudTokenRepository? cloud,
  })  : _tokens = tokens ?? ParentTokenRepository(),
        _cloud = cloud ?? CloudTokenRepository();

  /// Öğrenci okuldan ayrıldı: mezuniyet, başka okula nakil veya silme.
  ///
  /// Üç durumda da veli erişimi tamamen kapatılır. [teacherUid] bulut
  /// kimliklerini üretmek için gereklidir; boşsa yalnızca cihaz temizlenir
  /// (masaüstü yerel modda Google girişi yoktur).
  Future<LifecycleOutcome> handleDeparture({
    required int studentId,
    required DepartureReason reason,
    required String teacherUid,
    String note = '',
  }) async {
    final decision = StudentLifecyclePolicy.forDeparture(reason);

    final links = await _tokens.getLinkedParentsForStudent(studentId);
    var cloudOk = true;

    // 1. Buluttaki bağ ve sınıf erişimini kaldır.
    if (decision.endParentLinks && CloudIds.isValidUid(teacherUid)) {
      final studentCloudId = CloudIds.studentId(
        teacherUid: teacherUid,
        localStudentId: studentId,
      );

      for (final link in links) {
        final classCloudId = link.classCloudId.isNotEmpty
            ? link.classCloudId
            : CloudIds.classId(
                teacherUid: teacherUid,
                localClassId: link.classId,
              );

        final ok = await _cloud.unlinkParent(
          parentUid: link.parentUserId,
          studentCloudId: link.studentCloudId.isNotEmpty
              ? link.studentCloudId
              : studentCloudId,
          classCloudId: classCloudId,
        );
        if (!ok) cloudOk = false;
      }
    }

    // 2. Kodları buluttan düşür (veli artık kod giremesin).
    final activeTokens = await _tokens.getTokensForStudent(studentId);
    if (decision.revokeTokens) {
      for (final token in activeTokens) {
        final ok = await _cloud.revokeToken(token.codeHash);
        if (!ok) cloudOk = false;
      }
    }

    // 3. Cihazdaki kayıtları güncelle.
    final revoked = await _tokens.closeTokensForStudent(
      studentId: studentId,
      newStatus: decision.tokenStatus,
    );
    await _tokens.closeLinksForStudent(
      studentId: studentId,
      newStatus: decision.tokenStatus,
    );

    // 4. Silme, KVKK unutulma hakkı gereği cihazdan da tamamen kaldırır.
    if (decision.purgeLocalData) {
      await ParentLifecycleService.cascadeDeleteStudentParentData(
        studentId: studentId,
        actorId: teacherUid,
      );
    } else {
      await KvkkConsentService.logAudit(
        actorId: teacherUid,
        actorRole: 'teacher',
        action: 'student_${decision.tokenStatus}',
        targetId: 'student_$studentId',
        details: note.isEmpty
            ? 'Veli erişimleri kapatıldı.'
            : 'Veli erişimleri kapatıldı. Not: $note',
      );
    }

    return LifecycleOutcome(
      affectedParents: links.length,
      revokedTokens: revoked,
      cloudSynced: cloudOk,
    );
  }

  /// Öğrenci aynı okulda başka bir şubeye geçti.
  ///
  /// Bağ korunur; yalnızca sınıf erişimi taşınır. Böylece veli yeniden
  /// kod almak zorunda kalmaz.
  Future<LifecycleOutcome> handleClassChange({
    required int studentId,
    required int oldClassId,
    required int newClassId,
    required String newClassName,
    required String teacherUid,
  }) async {
    final decision = StudentLifecyclePolicy.forClassChange(
      oldClassId: oldClassId,
      newClassId: newClassId,
    );
    if (decision.isNoOp) return const LifecycleOutcome();

    final links = await _tokens.getLinkedParentsForStudent(studentId);
    var cloudOk = true;

    if (CloudIds.isValidUid(teacherUid)) {
      final studentCloudId = CloudIds.studentId(
        teacherUid: teacherUid,
        localStudentId: studentId,
      );
      final oldClassCloudId = CloudIds.classId(
        teacherUid: teacherUid,
        localClassId: oldClassId,
      );
      final newClassCloudId = CloudIds.classId(
        teacherUid: teacherUid,
        localClassId: newClassId,
      );

      for (final link in links) {
        final ok = await _cloud.moveClassAccess(
          parentUid: link.parentUserId,
          studentCloudId: link.studentCloudId.isNotEmpty
              ? link.studentCloudId
              : studentCloudId,
          oldClassCloudId: link.classCloudId.isNotEmpty
              ? link.classCloudId
              : oldClassCloudId,
          newClassCloudId: newClassCloudId,
          newClassName: newClassName,
        );
        if (!ok) cloudOk = false;
      }
    }

    // Cihazdaki bağ ve kod kayıtlarını yeni şubeye taşı.
    await _tokens.moveStudentTokensAndLinks(
      studentId: studentId,
      newClassId: newClassId,
      newClassName: newClassName,
    );

    if (links.isNotEmpty) {
      await KvkkConsentService.logAudit(
        actorId: teacherUid,
        actorRole: 'teacher',
        action: 'student_class_changed',
        targetId: 'student_$studentId',
        details: 'Şube değişikliği: $oldClassId → $newClassId '
            '(veli bağları korundu, sınıf erişimi güncellendi).',
      );
    }

    return LifecycleOutcome(
      affectedParents: links.length,
      cloudSynced: cloudOk,
    );
  }

  /// Öğrencinin bağlı velilerini getirir (silme onayında gösterilir).
  Future<List<ParentLinkModel>> linkedParents(int studentId) =>
      _tokens.getLinkedParentsForStudent(studentId);
}

final studentLifecycleCoordinatorProvider =
    Provider<StudentLifecycleCoordinator>((ref) {
  return StudentLifecycleCoordinator(
    tokens: ref.read(parentTokenRepositoryProvider),
  );
});
