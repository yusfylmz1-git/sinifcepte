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
      expect(linkResult['message'], contains('Ali YILMAZ'));

      // 2. Bağlanan çocuk veli listesinde görünmeli
      final children = await tokenRepo.getMyConnectedChildren();
      expect(children.length, equals(1));
      expect(children.first.studentName, equals('Ali YILMAZ'));
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
