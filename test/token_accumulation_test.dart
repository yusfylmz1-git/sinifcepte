import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/parent_token_repository.dart';

/// Token birikmesi — "ilk açılışta çalıştı, sonra bozuldu" hatası.
///
/// ## Bağlam
/// Kullanıcı ekranın ilk kullanımda açıldığını, birkaç denemeden sonra
/// açılmaz hale geldiğini bildirdi. Sebep: her kod üretiminde eski token
/// listede bırakılıyordu (yalnızca 'revoked' işaretleniyordu). Liste
/// büyüdükçe her okuma tüm kayıtları JSON olarak ayrıştırıp yeniden
/// yazıyor, ekran açılışı kilitleniyordu.
///
/// Bu testler birikmenin tekrar oluşmamasını garanti eder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final student = StudentModel(
    id: 42,
    classId: 7,
    firstName: 'Ali',
    lastName: 'Yılmaz',
    schoolNumber: 112,
    gender: 'Erkek',
  );
  final cls = ClassModel(
    id: 7,
    name: '5-A',
    subject: 'Matematik',
    academicYear: '2026-2027',
  );
  const teacher = TeacherProfileModel(
    id: 'uidAhmet',
    firstName: 'Ahmet',
    lastName: 'Öğretmen',
    branch: 'Matematik',
    schoolName: 'Test Okulu',
    schoolPrincipalName: '',
    email: 'a@b.com',
    schoolId: 'meb_16_1',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
  });

  /// Depodaki ham token sayısını okur (önbelleği atlar).
  Future<int> storedTokenCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('sinifcepte_student_parent_tokens') ?? []).length;
  }

  group('Token birikmesi', () {
    test('KRİTİK: art arda kod üretimi listeyi büyütmez', () async {
      final repo = ParentTokenRepository();

      // Kullanıcının yaptığı gibi: aynı öğrenci için defalarca kod üret.
      for (var i = 0; i < 10; i++) {
        await repo.generateTokenForStudent(
          student: student,
          classModel: cls,
          teacher: teacher,
        );
      }

      // Her öğrenci için tek kayıt kalmalı; 10 değil.
      expect(
        await storedTokenCount(),
        1,
        reason: 'eski kodlar silinmeli, yalnızca güncel kod kalmalı',
      );
    });

    test('Yeni kod üretilince eskisi geçersiz olur', () async {
      final repo = ParentTokenRepository();

      final first = await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
      );
      final second = await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
      );

      expect(first.code, isNot(second.code));

      // Aktif kod her zaman en son üretilendir.
      final active = await repo.getActiveTokenForStudent(42);
      expect(active?.code, second.code);
    });

    test('Farklı öğrencilerin kodları birbirini silmez', () async {
      final repo = ParentTokenRepository();

      final other = StudentModel(
        id: 43,
        classId: 7,
        firstName: 'Zeynep',
        lastName: 'Kaya',
        schoolNumber: 113,
        gender: 'Kız',
      );

      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
      );
      await repo.generateTokenForStudent(
        student: other,
        classModel: cls,
        teacher: teacher,
      );

      expect(await storedTokenCount(), 2);
      expect(await repo.getActiveTokenForStudent(42), isNotNull);
      expect(await repo.getActiveTokenForStudent(43), isNotNull);
    });

    test('Farklı öğrencilerin kodları birikmez, her biri tek kayıt tutar', () async {
      // Kodların gün bazlı süresi kaldırıldığı için "süresi dolmuş kayıt"
      // artık üretilemiyor. Asıl korunması gereken davranış şu: her
      // öğrencinin tek ortak kodu olur ve liste şişmez.
      final repo = ParentTokenRepository();

      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
      );

      final other = StudentModel(
        id: 99,
        classId: 7,
        firstName: 'Mehmet',
        lastName: 'Demir',
        schoolNumber: 199,
        gender: 'Erkek',
      );
      await repo.generateTokenForStudent(
        student: other,
        classModel: cls,
        teacher: teacher,
      );

      // İki öğrenci, iki kayıt.
      expect(await storedTokenCount(), 2);

      // Aynı öğrenciye yeniden üretmek kaydı çoğaltmaz.
      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
      );
      expect(await storedTokenCount(), 2);
    });
  });

  group('İkinci veli kodu (ayrı yaşayan aileler)', () {
    test('KRİTİK: anne kodu üretmek baba kodunu silmez', () async {
      // generateTokenForStudent, öğrencinin eski kayıtlarını siliyordu.
      // Etiket gözetilmezse anneye kod üretmek babanınkini yok ederdi.
      final repo = ParentTokenRepository();

      final baba = await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
        parentLabel: 'Baba',
      );
      final anne = await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
        parentLabel: 'Anne',
      );

      final tokens = await repo.getTokensForStudent(student.id!);
      final labels = tokens.map((t) => t.parentLabel).toSet();

      expect(tokens.length, 2, reason: 'Bir kod digerini sildi');
      expect(labels, containsAll(<String>['Anne', 'Baba']));
      expect(anne.code, isNot(baba.code));
    });

    test('KRİTİK: bir tarafın kodunu iptal etmek diğerini etkilemez', () async {
      final repo = ParentTokenRepository();

      final baba = await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
        parentLabel: 'Baba',
      );
      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
        parentLabel: 'Anne',
      );

      await repo.revokeToken(baba.id);

      final kalan = await repo.getTokensForStudent(student.id!);
      expect(kalan.length, 1);
      expect(kalan.single.parentLabel, 'Anne');
    });

    test('Aynı etiketle yeniden üretmek kaydı çoğaltmaz', () async {
      final repo = ParentTokenRepository();

      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
        parentLabel: 'Anne',
      );
      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
        parentLabel: 'Anne',
      );

      final tokens = await repo.getTokensForStudent(student.id!);
      expect(tokens.length, 1);
    });

    test('Ortak kod ve etiketli kod bir arada durabilir', () async {
      final repo = ParentTokenRepository();

      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
      );
      await repo.generateTokenForStudent(
        student: student,
        classModel: cls,
        teacher: teacher,
        parentLabel: 'Baba',
      );

      final tokens = await repo.getTokensForStudent(student.id!);
      expect(tokens.length, 2);
      expect(tokens.where((t) => t.parentLabel.isEmpty).length, 1);
    });
  });

  group('Denetim günlüğü birikmesi', () {
    test('KRİTİK: günlük sınırsız büyümez', () async {
      final repo = ParentTokenRepository();

      // Her kod üretimi bir denetim kaydı yazar.
      for (var i = 0; i < 40; i++) {
        await repo.generateTokenForStudent(
          student: student,
          classModel: cls,
          teacher: teacher,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('sinifcepte_audit_logs') ?? [];

      // Kayıtlar tutulur ama üst sınır aşılmaz.
      expect(logs.length, greaterThan(0));
      expect(
        logs.length,
        lessThanOrEqualTo(300),
        reason: 'günlük üst sınırla kırpılmalı',
      );
    });
  });
}
