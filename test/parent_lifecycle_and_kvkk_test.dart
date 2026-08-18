import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/storage/prefs_migrator.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_link_model.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_token_model.dart';
import 'package:sinifcepte/features/parent_portal/data/services/kvkk_consent_service.dart';
import 'package:sinifcepte/features/parent_portal/data/services/parent_lifecycle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KVKK Consent & Lifecycle Services Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PrefsService.resetCache();
      PrefsMigrator.resetForTest();
    });

    test('KvkkConsentService records consent and checks valid consent version', () async {
      const userId = 'parent_123';

      expect(await KvkkConsentService.hasValidConsent(userId), isFalse);

      // 1. Veli rıza verir
      final consent = await KvkkConsentService.recordConsent(userId: userId);
      expect(consent.userId, equals(userId));
      expect(consent.consentVersion, equals(KvkkConsentService.currentConsentVersion));

      // 2. Artık geçerli rızaya sahip olmalı
      expect(await KvkkConsentService.hasValidConsent(userId), isTrue);
    });

    test('KvkkConsentService logs audit trail and retrieves logs in reverse order', () async {
      await KvkkConsentService.logAudit(
        actorId: 'teacher_1',
        actorRole: 'teacher',
        action: 'token_generated',
        targetId: 'student_101',
        details: 'Veli bağlantı kartı üretildi.',
      );

      await KvkkConsentService.logAudit(
        actorId: 'parent_1',
        actorRole: 'parent',
        action: 'parent_link_created',
        targetId: 'student_101',
        details: 'Anne hesabı bağlandı.',
      );

      final logs = await KvkkConsentService.getAuditLogs();
      expect(logs.length, equals(2));
      expect(logs.first.action, equals('parent_link_created')); // En son log başta
      expect(logs.last.action, equals('token_generated'));
    });

    test('ParentLifecycleService promotes students to next class without re-entering tokens', () async {
      final prefs = await SharedPreferences.getInstance();

      final link1 = ParentLinkModel(
        id: 'link_1',
        studentId: 101,
        studentName: 'Ali Yılmaz',
        studentNumber: 142,
        schoolId: 'meb_734513',
        schoolName: 'Cumhuriyet Ortaokulu',
        classId: 5,
        className: '7-A',
        parentUserId: 'puser_1',
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
        linkedViaTokenCode: 'SC-7A-1234',
        linkedAt: DateTime.now(),
        status: 'active',
      );

      await prefs.setStringList('sinifcepte_parent_links_v1', [jsonEncode(link1.toMap())]);

      // Yıl sonu sınıf atlatma: 7-A (ID: 5) -> 8-A (ID: 6)
      final count = await ParentLifecycleService.promoteStudentsToNextClass(
        oldClassId: 5,
        newClassId: 6,
        newClassName: '8-A',
        actorId: 'teacher_1',
      );

      expect(count, equals(1));

      final rawLinks = prefs.getStringList('sinifcepte_parent_links_v1')!;
      final updatedLink = ParentLinkModel.fromMap(jsonDecode(rawLinks.first));
      expect(updatedLink.classId, equals(6));
      expect(updatedLink.className, equals('8-A'));
      expect(updatedLink.status, equals('active'));
    });

    test('ParentLifecycleService graduates student and marks parent links as graduated', () async {
      final prefs = await SharedPreferences.getInstance();

      final link1 = ParentLinkModel(
        id: 'link_1',
        studentId: 101,
        studentName: 'Ali Yılmaz',
        studentNumber: 142,
        schoolId: 'meb_734513',
        schoolName: 'Cumhuriyet Ortaokulu',
        classId: 6,
        className: '8-A',
        parentUserId: 'puser_1',
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
        linkedViaTokenCode: 'SC-8A-9402',
        linkedAt: DateTime.now(),
        status: 'active',
      );

      await prefs.setStringList('sinifcepte_parent_links_v1', [jsonEncode(link1.toMap())]);

      final success = await ParentLifecycleService.graduateStudent(
        studentId: 101,
        actorId: 'teacher_1',
      );

      expect(success, isTrue);

      final rawLinks = prefs.getStringList('sinifcepte_parent_links_v1')!;
      final updatedLink = ParentLinkModel.fromMap(jsonDecode(rawLinks.first));
      expect(updatedLink.status, equals('graduated'));
    });

    test('ParentLifecycleService cascades delete on student deletion (Right to be forgotten)', () async {
      final prefs = await SharedPreferences.getInstance();

      final token = ParentTokenModel(
        id: 'tok_1',
        studentId: 101,
        studentName: 'Ali Yılmaz',
        studentNumber: 142,
        classId: 6,
        className: '8-A',
        schoolId: 'meb_734513',
        schoolName: 'Cumhuriyet Ortaokulu',
        code: 'SC-8A-9402',
        codeHash: 'hash',
        secondFactorHash: 'sfhash',
        qrPayload: 'sinifcepte://parent/link?token=SC-8A-9402',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      final link = ParentLinkModel(
        id: 'link_1',
        studentId: 101,
        studentName: 'Ali Yılmaz',
        studentNumber: 142,
        schoolId: 'meb_734513',
        schoolName: 'Cumhuriyet Ortaokulu',
        classId: 6,
        className: '8-A',
        parentUserId: 'puser_1',
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
        linkedViaTokenCode: 'SC-8A-9402',
        linkedAt: DateTime.now(),
      );

      await prefs.setStringList('sinifcepte_student_parent_tokens', [jsonEncode(token.toMap())]);
      await prefs.setStringList('sinifcepte_parent_links_v1', [jsonEncode(link.toMap())]);

      // Cascade Silme
      await ParentLifecycleService.cascadeDeleteStudentParentData(
        studentId: 101,
        actorId: 'teacher_1',
      );

      expect(prefs.getStringList('sinifcepte_student_parent_tokens')!.isEmpty, isTrue);
      expect(prefs.getStringList('sinifcepte_parent_links_v1')!.isEmpty, isTrue);

      final auditLogs = await KvkkConsentService.getAuditLogs();
      expect(auditLogs.any((l) => l.action == 'student_cascade_deleted'), isTrue);
    });
  });
}
