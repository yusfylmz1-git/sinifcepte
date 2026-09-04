import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/storage/prefs_migrator.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/core/utils/student_name_formatter.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_token_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/parent_token_repository.dart';
import 'package:sinifcepte/core/cloud/cloud_ids.dart';

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
      PrefsService.resetCache();
      PrefsMigrator.resetForTest();
      repository = ParentTokenRepository();
    });

    test('generateTokenForStudent produces an open-ended token with SHA-256 hash', () async {
      // Kodun gün bazlı süresi kaldırıldı: öğrenci okulda olduğu sürece
      // geçerlidir ve olayla kapanır (mezuniyet, nakil, silme, iptal).
      final token = await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
      );

      expect(token.code.startsWith('SC-8A-'), isTrue);
      expect(token.studentNumber, equals(142));
      expect(token.isValid, isTrue);
      expect(token.isOpenEnded, isTrue);
      expect(token.isExpired, isFalse);
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
      // Bulut kimlikleri ZORUNLUDUR: boş kalırsa `hasCloudBinding`
      // false döner ve velinin duyuru/kadro/mesaj sorguları sessizce
      // boş liste verir.
      final classCloudId = CloudIds.classId(
        teacherUid: testTeacher.id,
        localClassId: testClass.id!,
      );
      final studentCloudId = CloudIds.studentId(
        teacherUid: testTeacher.id,
        localStudentId: testStudent.id!,
      );

      final momLink = await repository.linkParent(
        token: token,
        parentUserId: 'parent_mom_001',
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
        classCloudId: classCloudId,
        studentCloudId: studentCloudId,
        teacherUid: testTeacher.id,
      );
      expect(momLink, isNotNull);
      expect(momLink?.relation, equals('Anne'));
      expect(momLink?.hasCloudBinding, isTrue,
          reason: 'Bulut bağı kurulmazsa veli hiçbir şey göremez');

      // 2. Baba bağlanır
      final dadLink = await repository.linkParent(
        token: token,
        parentUserId: 'parent_dad_002',
        parentName: 'Mehmet Yılmaz',
        relation: 'Baba',
        classCloudId: classCloudId,
        studentCloudId: studentCloudId,
        teacherUid: testTeacher.id,
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

    test('normalizeCode correctly formats various user inputs', () {
      expect(ParentTokenModel.normalizeCode('SC-8A-9402'), equals('SC-8A-9402'));
      expect(ParentTokenModel.normalizeCode('sc-8a-9402'), equals('SC-8A-9402'));
      expect(ParentTokenModel.normalizeCode('sc 8a 9402'), equals('SC-8A-9402'));
      expect(ParentTokenModel.normalizeCode('SC8A9402'), equals('SC-8A-9402'));
      expect(ParentTokenModel.normalizeCode('8A-9402'), equals('SC-8A-9402'));
      expect(ParentTokenModel.normalizeCode('8a9402'), equals('SC-8A-9402'));
      expect(ParentTokenModel.normalizeCode('12B1234'), equals('SC-12B-1234'));
      expect(ParentTokenModel.normalizeCode(''), equals(''));
    });

    test('verifyToken succeeds with lowercase, unhyphenated or prefixless inputs', () async {
      final token = await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
      );

      // Kodu SC- olmadan veya küçük harfle girince de doğrulamalı
      final rawWithoutPrefix = token.code.replaceFirst('SC-', '').toLowerCase();
      final result1 = await repository.verifyToken(
        inputCode: rawWithoutPrefix,
        inputStudentNumber: '142',
      );
      expect(result1.isSuccess, isTrue);

      // Kodu tiresiz girince de doğrulamalı
      final rawWithoutDashes = token.code.replaceAll('-', '').toLowerCase();
      final result2 = await repository.verifyToken(
        inputCode: rawWithoutDashes,
        inputStudentNumber: '142',
      );
      expect(result2.isSuccess, isTrue);
    });

    test('getActiveTokensForClass retrieves all active tokens for a given class', () async {
      await repository.generateTokenForStudent(
        student: testStudent,
        classModel: testClass,
        teacher: testTeacher,
      );

      const testStudent2 = StudentModel(
        id: 102,
        classId: 5,
        schoolNumber: 143,
        firstName: 'Zeynep',
        lastName: 'Kaya',
      );

      await repository.generateTokenForStudent(
        student: testStudent2,
        classModel: testClass,
        teacher: testTeacher,
      );

      final classTokens = await repository.getActiveTokensForClass(5);
      expect(classTokens.length, equals(2));
      expect(classTokens.containsKey(101), isTrue);
      expect(classTokens.containsKey(102), isTrue);
      expect(classTokens[101]?.studentNumber, equals(142));
      expect(classTokens[102]?.studentNumber, equals(143));
    });

    test('generateTokensForStudentsBatch generates unique tokens for all students in one step', () async {
      const students = [
        StudentModel(id: 201, classId: 7, schoolNumber: 20, firstName: 'Mustafa', lastName: 'Demir'),
        StudentModel(id: 202, classId: 7, schoolNumber: 51, firstName: 'Ahmet', lastName: 'İnci'),
        StudentModel(id: 203, classId: 7, schoolNumber: 76, firstName: 'Elanur', lastName: 'Ak'),
      ];

      const classModel = ClassModel(id: 7, name: '7-A', subject: 'Türkçe', academicYear: '2025-2026');

      final generated = await repository.generateTokensForStudentsBatch(
        students: students,
        classModel: classModel,
        teacher: testTeacher,
      );

      expect(generated.length, equals(3));
      final codes = generated.map((t) => t.code).toSet();
      // Kodlar benzersiz olmalı (çakışmasız)
      expect(codes.length, equals(3));
      for (final t in generated) {
        expect(t.code.startsWith('SC-7A-'), isTrue);
        expect(t.isValid, isTrue);
      }

      final activeMap = await repository.getActiveTokensForClass(7);
      expect(activeMap.length, equals(3));
      expect(activeMap.containsKey(201), isTrue);
      expect(activeMap.containsKey(202), isTrue);
      expect(activeMap.containsKey(203), isTrue);
    });
  });

  group('StudentNameFormatter (KVKK & Liste Formatlayıcı) Tests', () {
    test('maskLastName correctly formats names to first name + last initial', () {
      expect(StudentNameFormatter.maskLastName('Ahmet Yılmaz'), equals('Ahmet Y.'));
      expect(StudentNameFormatter.maskLastName('Mehmet Ali Kaya'), equals('Mehmet Ali K.'));
      expect(StudentNameFormatter.maskLastName('Ayşe'), equals('Ayşe'));
      expect(StudentNameFormatter.maskLastName('Elif Nur Dağdelen'), equals('Elif Nur D.'));
      expect(StudentNameFormatter.maskLastName(''), equals(''));
    });

    test('formatRowWithCode formats correctly: 108 - Ahmet Y. - SC-8A-9402', () {
      final row = StudentNameFormatter.formatRowWithCode(
        number: 108,
        fullName: 'Ahmet Yılmaz',
        code: 'SC-8A-9402',
      );
      expect(row, equals('108 - Ahmet Y. - SC-8A-9402'));
    });

    test('formatPublicRowWithCode formats correctly without student number for 2FA security', () {
      final row = StudentNameFormatter.formatPublicRowWithCode(
        fullName: 'Ahmet Yılmaz',
        code: 'SC-8A-9402',
      );
      expect(row, equals('• Ahmet Y.  ➔  SC-8A-9402'));
      expect(row.contains('108'), isFalse);
    });
  });
}
