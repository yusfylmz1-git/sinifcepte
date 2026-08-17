import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_token_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/parent_token_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParentTokenModel & Repository Tests', () {
    late ParentTokenRepository repository;

    const testStudent = StudentModel(
      id: 101,
      classId: 5,
      schoolNumber: 142,
      firstName: 'Ali',
      lastName: 'Yılmaz',
    );

    const testClass = ClassModel(
      id: 5,
      name: '8-A',
      subject: 'Matematik',
      academicYear: '2025-2026',
    );

    const testTeacher = TeacherProfileModel(
      id: 'teacher_001',
      firstName: 'Ahmet',
      lastName: 'Öğretmen',
      branch: 'Matematik',
      schoolName: 'Nilüfer Atatürk Ortaokulu',
      schoolId: 'sch_16_01',
      city: 'Bursa',
      district: 'Nilüfer',
      schoolPrincipalName: 'Mehmet Müdür',
      email: 'ahmet@meb.k12.tr',
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = ParentTokenRepository();
    });

    test('generateTokenForStudent produces a valid 7-day token with SHA-256 hash', () async {
      final token = await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
        validityDays: 7,
      );

      expect(token.code.startsWith('SC-8A-'), isTrue);
      expect(token.studentNumber, equals(142));
      expect(token.isValid, isTrue);
      expect(token.remainingDays, equals(7));
      expect(token.status, equals('active'));

      // Check SHA-256 integrity
      final expectedCodeHash = ParentTokenModel.generateSha256(token.code);
      expect(token.codeHash, equals(expectedCodeHash));

      final expectedSecondFactorHash = ParentTokenModel.generateSha256('142');
      expect(token.secondFactorHash, equals(expectedSecondFactorHash));
    });

    test('verifyToken succeeds with correct code and student number', () async {
      final token = await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
      );

      final result = await repository.verifyToken(
        inputCode: token.code,
        inputStudentNumber: '142',
      );

      expect(result.isSuccess, isTrue);
      expect(result.token?.id, equals(token.id));
    });

    test('verifyToken fails with incorrect student number (2nd factor protection)', () async {
      final token = await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
      );

      final result = await repository.verifyToken(
        inputCode: token.code,
        inputStudentNumber: '999', // wrong school number
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('okul numarası eşleşmedi'));
    });

    test('multi-parent linking allows both Mom and Dad to connect with privacy isolation', () async {
      final token = await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
      );

      // 1. Anne bağlanır
      final momLink = await repository.linkParent(
        token: token,
        parentUserId: 'parent_mom_001',
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
      );
      expect(momLink, isNotNull);
      expect(momLink?.relation, equals('Anne'));

      // 2. Baba bağlanır
      final dadLink = await repository.linkParent(
        token: token,
        parentUserId: 'parent_dad_002',
        parentName: 'Mehmet Yılmaz',
        relation: 'Baba',
      );
      expect(dadLink, isNotNull);
      expect(dadLink?.relation, equals('Baba'));

      // 3. Öğretmen için bağlı veli listesini kontrol et
      final linkedParents = await repository.getLinkedParentsForStudent(testStudent.id!);
      expect(linkedParents.length, equals(2));
      expect(linkedParents.map((l) => l.relation), containsAll(['Anne', 'Baba']));
    });

    test('revokeToken marks code as revoked and blocks subsequent logins', () async {
      final token = await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
      );

      final revoked = await repository.revokeToken(token.id);
      expect(revoked, isTrue);

      final verifyResult = await repository.verifyToken(
        inputCode: token.code,
        inputStudentNumber: '142',
      );

      expect(verifyResult.isSuccess, isFalse);
      expect(verifyResult.errorMessage, contains('iptal edilmiş'));
    });
  });
}
