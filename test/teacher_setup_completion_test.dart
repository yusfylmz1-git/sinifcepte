import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/auth_profile/data/services/teacher_branches.dart';

/// Kurulum tamamlanma kontrolu.
///
/// Kullanici bildirdi: "yine acilista okul soruyor". Cihazdaki kayit
/// incelendiginde okul DOLU, brans BOSTU — `isSetupComplete` ucunu
/// birden istedigi icin kurulum ekrani aciliyordu.
///
/// Ekran ayrica kayitli okulu geri yuklemiyordu; ogretmen yalnizca brans
/// eksikken okulunu da yeniden secmek zorunda kaliyordu.
void main() {
  TeacherProfileModel profil({
    String firstName = 'Yusuf',
    String lastName = 'Yilmaz',
    String branch = 'Matematik',
    String? schoolId = 'meb_775214',
  }) {
    return TeacherProfileModel(
      id: 'KplpM8ibNdhVJENzWz8tvJ0vsLR2',
      firstName: firstName,
      lastName: lastName,
      gender: 'Erkek',
      branch: branch,
      schoolName: 'Mimar Sinan Ortaokulu',
      schoolId: schoolId,
      schoolType: 'Ortaokul',
      schoolPrincipalName: '',
      email: 'y@x.com',
    );
  }

  group('Kurulum tamamlanma', () {
    test('KRITIK: brans eksikse kurulum tamamlanmamis sayilir', () {
      // Kullanicinin cihazindaki gercek durum buydu.
      expect(profil(branch: '').isSetupComplete, isFalse);
      expect(profil(branch: '   ').isSetupComplete, isFalse);
    });

    test('Okul eksikse tamamlanmamis sayilir', () {
      expect(profil(schoolId: null).isSetupComplete, isFalse);
      expect(profil(schoolId: '').isSetupComplete, isFalse);
    });

    test('Ad veya soyad eksikse tamamlanmamis sayilir', () {
      expect(profil(firstName: '').isSetupComplete, isFalse);
      expect(profil(lastName: '').isSetupComplete, isFalse);
    });

    test('KRITIK: ucu de doluysa tamamlanmis sayilir', () {
      expect(profil().isSetupComplete, isTrue);
    });

    test('Okul bagli ama kurulum eksik olabilir', () {
      // Bu ayrim onemli: ekran okulu ZATEN VAR diye biliyor ve yeniden
      // sormamali, yalnizca eksik alani istemeli.
      final p = profil(branch: '');
      expect(p.isSchoolBound, isTrue);
      expect(p.isSetupComplete, isFalse);
    });
  });

  group('Kayitli bransin geri yuklenmesi', () {
    test('KRITIK: listede olan brans secili gelir', () {
      final options = TeacherBranches.forSchoolType('Ortaokul');
      expect(options.contains('Matematik'), isTrue);
    });

    test('KRITIK: listede olmayan brans Diger olarak yuklenir', () {
      final options = TeacherBranches.forSchoolType('Ortaokul');
      const kayitli = 'Denizcilik';

      expect(options.contains(kayitli), isFalse);
      // Bu durumda ekran 'Diger' secip metni elle giris alanina koyar.
      expect(TeacherBranches.isValid(kayitli), isTrue);
    });
  });
}
