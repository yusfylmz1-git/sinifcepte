import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/auth_profile/data/repositories/school_directory_repository.dart';

void main() {
  group('Okul öğretmen dizini kimliği', () {
    test('Doküman kimliği okul ve öğretmeni birleştirir', () {
      final id = SchoolDirectoryRepository.docId(
        schoolId: 'meb_16_123',
        teacherUid: 'uidAhmet',
      );

      expect(id, 'meb_16_123_uidAhmet');
    });

    test('Kural deseni ile uyumlu: schoolId + "_" + uid', () {
      const schoolId = 'meb_16_123';
      const uid = 'uidAhmet';
      final id = SchoolDirectoryRepository.docId(
        schoolId: schoolId,
        teacherUid: uid,
      );

      // firestore.rules: id == schoolId + '_' + request.auth.uid
      expect(id, '${schoolId}_$uid');
    });

    test('Farklı okullardaki aynı öğretmen ayrı kayıt olur', () {
      final a = SchoolDirectoryRepository.docId(
        schoolId: 'meb_16_111',
        teacherUid: 'uidAhmet',
      );
      final b = SchoolDirectoryRepository.docId(
        schoolId: 'meb_34_222',
        teacherUid: 'uidAhmet',
      );

      expect(a, isNot(b));
    });
  });

  group('Meslektaş görünümü', () {
    test('Ad ve branş tek satırda birleşir', () {
      const withBranch = SchoolTeacher(
        uid: 'uid1',
        fullName: 'Selin Demir',
        branch: 'Fizik',
      );
      expect(withBranch.displayTitle, 'Selin Demir — Fizik');
    });

    test('Branş boşsa yalnızca ad gösterilir', () {
      const noBranch = SchoolTeacher(uid: 'uid2', fullName: 'Ahmet Yılmaz');
      // Boş tire kalmamalı.
      expect(noBranch.displayTitle, 'Ahmet Yılmaz');
    });
  });

  group('Kayıt ön koşulları', () {
    test('Boş UID veya okul kimliğiyle kayıt yapılmaz', () async {
      final repo = SchoolDirectoryRepository();

      // Firebase hazır olmasa da bu kontroller ağa çıkmadan çalışır.
      expect(
        await repo.registerTeacher(
          teacherUid: '',
          schoolId: 'meb_16_123',
          fullName: 'X',
          branch: 'Y',
          email: '',
        ),
        isFalse,
      );

      expect(
        await repo.registerTeacher(
          teacherUid: 'uid1',
          schoolId: '',
          fullName: 'X',
          branch: 'Y',
          email: '',
        ),
        isFalse,
      );
    });

    test('Boş okul kimliğiyle listeleme boş döner', () async {
      final repo = SchoolDirectoryRepository();
      expect(await repo.teachersOfSchool(''), isEmpty);
    });
  });
}
