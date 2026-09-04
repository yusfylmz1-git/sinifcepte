import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/auth_profile/data/services/teacher_branches.dart';

/// Ogretmen bransi.
///
/// Kullanici tespit etti: ilk kayitta okul ZORUNLU ama brans hic
/// sorulmuyordu. Sonuc: Firestore'da `branch: ""` — sinif kadrosuna
/// ogretmen eklerken "kim hangi derse giriyor" bilinemiyordu.
///
/// Karar (30 Agustos 2026): kayit sirasi Ad-Soyad -> Okul -> Brans;
/// brans listesi okul turune gore gelir, listede yoksa 'Diger' ile
/// elle yazilir.
void main() {
  group('Okul turune gore brans listesi', () {
    test('KRITIK: ortaokul ve lise farkli branslar sunar', () {
      final orta = TeacherBranches.forSchoolType('Ortaokul');
      final lise = TeacherBranches.forSchoolType('Anadolu Lisesi');

      expect(orta, isNot(lise));
      // Fizik/Kimya/Biyoloji lisede ayri branstir; ortaokulda 'Fen
      // Bilimleri' tek derstir.
      expect(lise, contains('Fizik'));
      expect(orta, contains('Fen Bilimleri'));
      expect(orta.contains('Fizik'), isFalse);
    });

    test('KRITIK: ilkokulda Sinif Ogretmeni ilk sirada', () {
      final ilk = TeacherBranches.forSchoolType('İlkokul');

      expect(ilk.first, 'Sınıf Öğretmeni');
    });

    test('KRITIK: ortaokul ve lisede Sinif Ogretmeni YOK', () {
      // Oralarda sinif ogretmenligi bir brans degil, bir gorevdir.
      expect(
        TeacherBranches.forSchoolType('Ortaokul').contains('Sınıf Öğretmeni'),
        isFalse,
      );
      expect(
        TeacherBranches.forSchoolType('Fen Lisesi')
            .contains('Sınıf Öğretmeni'),
        isFalse,
      );
    });

    test('Imam hatip okullarinda meslek dersleri bulunur', () {
      final ihl = TeacherBranches.forSchoolType('Anadolu İmam Hatip Lisesi');
      expect(ihl, contains('Meslek Dersleri (İHL)'));
    });

    test('KRITIK: her listede Diger secenegi bulunur', () {
      // MEB branslari degisiyor; kati liste ogretmeni kilitler.
      for (final tur in const [
        'İlkokul',
        'Ortaokul',
        'Anadolu Lisesi',
        'Bilinmeyen Tur',
        '',
      ]) {
        expect(TeacherBranches.forSchoolType(tur).last, TeacherBranches.other,
            reason: '$tur icin Diger secenegi yok');
      }
    });

    test('Taninmayan tur genel listeye duser', () {
      final bilinmeyen = TeacherBranches.forSchoolType('Diğer');
      expect(bilinmeyen, isNotEmpty);
      expect(bilinmeyen, contains('Rehberlik'));
    });

    test('Turkce buyuk-kucuk harf tuzagina dusmez', () {
      // 'İlkokul' -> toLowerCase() Turkce'de bozulur; eslestirme
      // buna ragmen calismali.
      final a = TeacherBranches.forSchoolType('İlkokul');
      final b = TeacherBranches.forSchoolType('ilkokul');
      final c = TeacherBranches.forSchoolType('İLKOKUL');

      expect(a, b);
      expect(a, c);
    });

    test('Liste tekrar icermez', () {
      for (final tur in const ['İlkokul', 'Ortaokul', 'Anadolu Lisesi']) {
        final liste = TeacherBranches.forSchoolType(tur);
        expect(liste.toSet().length, liste.length, reason: '$tur tekrarli');
      }
    });
  });

  group('Brans dogrulama', () {
    test('KRITIK: bos brans kabul edilmez', () {
      expect(TeacherBranches.isValid(''), isFalse);
      expect(TeacherBranches.isValid('   '), isFalse);
    });

    test('Diger secili birakilmis olamaz', () {
      // 'Diger' bir brans degil, elle giris tetikleyicisidir.
      expect(TeacherBranches.isValid(TeacherBranches.other), isFalse);
    });

    test('Gecerli brans kabul edilir', () {
      expect(TeacherBranches.isValid('Matematik'), isTrue);
      expect(TeacherBranches.isValid('Harezmî Atölyesi'), isTrue);
    });
  });
}
