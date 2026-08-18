import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/storage/prefs_migrator.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/parent_token_repository.dart';
import 'package:sinifcepte/features/parent_portal/data/services/kvkk_consent_service.dart';
import 'package:sinifcepte/features/parent_portal/data/services/parent_lifecycle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Parent Portal Extended Features & Security Tests', () {
    late ParentTokenRepository tokenRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PrefsService.resetCache();
      PrefsMigrator.resetForTest();
      tokenRepo = ParentTokenRepository();
    });

    test('ParentTokenRepository.verifyAndLinkParent connects parent in one step', () async {
      final teacher = const TeacherProfileModel(
        id: 't_1',
        firstName: 'Yusuf',
        lastName: 'Yılmaz',
        branch: 'Bilişim',
        schoolName: 'Cumhuriyet Ortaokulu',
        schoolPrincipalName: 'Müdür',
        email: 'yusuf@test.com',
      );

      final classModel = const ClassModel(id: 5, name: '8-A', subject: 'Bilişim', academicYear: '2024-2025');
      final student = const StudentModel(id: 101, classId: 5, schoolNumber: 142, firstName: 'Ali', lastName: 'Yılmaz');

      final token = await tokenRepo.generateTokenForStudent(
        teacher: teacher,
        classModel: classModel,
        student: student,
      );

      // 1. Veli tek adımda bağlanır
      final linkResult = await tokenRepo.verifyAndLinkParent(
        code: token.code,
        studentNumber: 142,
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
      );

      expect(linkResult['success'], isTrue);
      expect(linkResult['message'], contains('Ali Yılmaz'));

      // 2. Bağlanan çocuk veli listesinde görünmeli
      final children = await tokenRepo.getMyConnectedChildren();
      expect(children.length, equals(1));
      expect(children.first.studentName, equals('Ali Yılmaz'));
    });

    test('Teacher verification by admin grants blue badge and logs audit', () async {
      expect(await KvkkConsentService.isTeacherVerified('t_1'), isFalse);

      final verified = await KvkkConsentService.verifyTeacher(
        teacherId: 't_1',
        teacherName: 'Yusuf Yılmaz',
        adminId: 'admin_1',
        schoolName: 'Cumhuriyet Ortaokulu',
      );

      expect(verified, isTrue);
      expect(await KvkkConsentService.isTeacherVerified('t_1'), isTrue);

      final logs = await KvkkConsentService.getAuditLogs();
      expect(logs.any((l) => l.action == 'teacher_verified'), isTrue);
    });

    test('Content moderation: reporting content records report and audit trail', () async {
      final success = await KvkkConsentService.reportContent(
        reportedByUserId: 'parent_1',
        reportedRole: 'parent',
        contentId: 'ann_123',
        contentType: 'Duyuru',
        contentSnippet: 'Yarın toplantı var',
        reason: 'Yanlış saat bilgisi içeriyor',
      );

      expect(success, isTrue);

      final reports = await KvkkConsentService.getContentReports();
      expect(reports.length, equals(1));
      expect(reports.first.reason, contains('Yanlış saat'));
    });

    test('Self-Service KVKK: parent exports data and deletes account', () async {
      // 1. Veri İndirme (JSON Dışa Aktarma)
      final export = await ParentLifecycleService.exportParentDataAsJson('puser_test');
      expect(export.containsKey('kvkk_compliance'), isTrue);
      expect(export['parent_user_id'], equals('puser_test'));

      // 2. Hesabı Kalıcı Olarak Silme
      final deleted = await ParentLifecycleService.deleteParentSelfAccount('puser_test');
      expect(deleted, isTrue);

      final logs = await KvkkConsentService.getAuditLogs();
      expect(logs.any((l) => l.action == 'parent_account_deleted'), isTrue);
    });
  });
}
