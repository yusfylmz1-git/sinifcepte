import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/cloud/cloud_ids.dart';

/// Ogretmen bulut kimliginin tek kaynaktan cozulmesi.
///
/// Kullanici testte fark etti: veli, sinif rehber ogretmenini hic
/// goremiyordu. Sebep, kimligin IKI FARKLI sekilde cozulmesiydi:
///  - Referans kodu uretimi: FirebaseAuth.currentUser.uid
///  - Kadro ekrani: teacherProfile.id
///
/// Ikisi farkli oldugunda sinifin bulut kimligi (cls_{uid}_{id}) de
/// farkli cikiyor; kadro satiri velinin baktigindan BASKA bir sinif
/// odasina yaziliyordu.
void main() {
  group('Sinif bulut kimligi', () {
    test('KRITIK: farkli kimlik farkli sinif odasi uretir', () {
      // Hatanin ozu: ayni yerel sinif, iki kimlikle iki ayri odaya duser.
      final a = CloudIds.classId(teacherUid: 'firebaseUid123', localClassId: 7);
      final b = CloudIds.classId(teacherUid: 'local_teacher', localClassId: 7);

      expect(a, isNot(b),
          reason: 'Kimlik ayrismasi sessizce iki oda uretiyor');
    });

    test('Ayni kimlik her zaman ayni odayi verir', () {
      final a = CloudIds.classId(teacherUid: 'firebaseUidAhmet', localClassId: 7);
      final b = CloudIds.classId(teacherUid: 'firebaseUidAhmet', localClassId: 7);

      expect(a, b);
    });

    test('Kadro yolu sinif odasinin altindadir', () {
      final classId = CloudIds.classId(teacherUid: 'firebaseUidAhmet', localClassId: 7);
      final staffPath = 'class_rooms/$classId/staff/firebaseUidAhmet';

      expect(staffPath, contains(classId));
      expect(staffPath.endsWith('/staff/firebaseUidAhmet'), isTrue);
    });

    test('KRITIK: kural motoru deseniyle uyumlu', () {
      // firestore.rules: ownsClassRoom -> classCloudId.matches('cls_' + uid + '_.*')
      const uid = 'firebaseUidAhmet';
      final classId = CloudIds.classId(teacherUid: uid, localClassId: 7);

      expect(classId.startsWith('cls_${uid}_'), isTrue,
          reason: 'Kimlik deseni bozulursa yazma reddedilir');
    });

    test('Yer tutucu kimlik gecersiz sayilir', () {
      // 'local_teacher' bir Firebase UID degildir; bulut islemleri
      // atlanmalidir (masaustu yerel modu).
      expect(CloudIds.isValidUid('local_teacher'), isFalse);
      expect(CloudIds.isValidUid('firebaseUid123'), isTrue);
      expect(CloudIds.isValidUid(''), isFalse);
    });
  });
}
