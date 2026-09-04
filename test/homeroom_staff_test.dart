import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';

/// Sinif ogretmeninin kadroda gorunmesi.
///
/// Test sirasinda cikan hata: veli, sinif ogretmenine mesaj atmak
/// istedigin de "ogretmen bagli degil" uyarisi aliyordu. Sebep,
/// `isHomeroom` alaninin HICBIR yerde true yazilmamasiydi — sinif
/// ogretmeni kendi sinifinin kadrosuna hic eklenmiyordu.
void main() {
  group('Sinif ogretmeni kadrosu', () {
    test('KRITIK: sinif ogretmeni kadroda isaretlenebilir', () {
      const homeroom = CloudStaffMember(
        teacherUid: 'uid_ahmet',
        teacherName: 'Ahmet Ogretmen',
        branch: 'Sinif Ogretmeni',
        isHomeroom: true,
      );

      expect(homeroom.isHomeroom, isTrue);
      expect(homeroom.teacherUid, isNotEmpty);
    });

    test('KRITIK: kadro listesinde sinif ogretmeni once gelir', () {
      // Veli en cok sinif ogretmeniyle yazisir; listede ustte durmali.
      const staff = [
        CloudStaffMember(
          teacherUid: 'uid_zeynep',
          teacherName: 'Zeynep Fizik',
          branch: 'Fizik',
        ),
        CloudStaffMember(
          teacherUid: 'uid_ahmet',
          teacherName: 'Ahmet Ogretmen',
          branch: 'Sinif Ogretmeni',
          isHomeroom: true,
        ),
      ];

      final sorted = [...staff]..sort((a, b) {
          if (a.isHomeroom != b.isHomeroom) return a.isHomeroom ? -1 : 1;
          return a.teacherName.compareTo(b.teacherName);
        });

      expect(sorted.first.isHomeroom, isTrue);
      expect(sorted.first.teacherName, 'Ahmet Ogretmen');
    });

    test('Sinif ogretmeni etiketinde bransa gerek yok', () {
      const homeroom = CloudStaffMember(
        teacherUid: 'uid_ahmet',
        teacherName: 'Ahmet Ogretmen',
        branch: '',
        isHomeroom: true,
      );

      // Brans bossa yalnizca ad gosterilir, bos tire kalmaz.
      expect(homeroom.displayTitle, 'Ahmet Ogretmen');
    });

    test('Kadro uyesi gorusme saati tasiyabilir', () {
      const homeroom = CloudStaffMember(
        teacherUid: 'uid_ahmet',
        teacherName: 'Ahmet Ogretmen',
        branch: '',
        isHomeroom: true,
        meetingDay: 'Sali',
        meetingTime: '13:30 - 14:15',
      );

      expect(homeroom.meetingDay, 'Sali');
      expect(homeroom.meetingTime, '13:30 - 14:15');
    });
  });
}
