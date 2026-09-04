import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/cloud/cloud_ids.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_link_model.dart';

/// Veli baginda bulut kimlikleri.
///
/// Kullanici bildirdi: veli kod ile bagland i ama "sinif ogretmeniniz
/// henuz ders ogretmenlerini eklememis" yaziyordu — oysa ogretmen
/// tarafinda kadro doluydu.
///
/// Sebep: yerel `linkParent` bagi kurarken classCloudId ve
/// studentCloudId alanlarini HIC doldurmuyordu. `hasCloudBinding` false
/// dondugu icin velinin butun bulut sorgulari sessizce bos liste
/// veriyordu.
void main() {
  ParentLinkModel link({
    String classCloudId = '',
    String studentCloudId = '',
  }) {
    return ParentLinkModel(
      id: 'link_1',
      parentUserId: 'parentAyse',
      parentName: 'Ayse Yilmaz',
      studentId: 42,
      studentName: 'Ahmet Veysel Ilhan',
      studentNumber: 101,
      schoolId: 'meb_775214',
      schoolName: 'Mimar Sinan Ortaokulu',
      classId: 7,
      className: '5-B',
      relation: 'Anne',
      linkedAt: DateTime(2026, 8, 30),
      linkedViaTokenCode: 'SC-5B-1234',
      status: 'active',
      classCloudId: classCloudId,
      studentCloudId: studentCloudId,
    );
  }

  group('Bulut bagi', () {
    test('KRITIK: bos bulut kimlikleri velinin her seyini gizler', () {
      // Hatanin ozu: bu false oldugunda duyurular, kadro ve mesajlar
      // sorgulanmadan bos doner.
      expect(link().hasCloudBinding, isFalse);
    });

    test('KRITIK: dolu kimliklerle bulut sorgulari acilir', () {
      const uid = 'firebaseUidAhmet';
      final dolu = link(
        classCloudId: CloudIds.classId(teacherUid: uid, localClassId: 7),
        studentCloudId: CloudIds.studentId(teacherUid: uid, localStudentId: 42),
      );

      expect(dolu.hasCloudBinding, isTrue);
    });

    test('KRITIK: tek alan bile bossa bag kurulmus sayilmaz', () {
      const uid = 'firebaseUidAhmet';

      expect(
        link(classCloudId: CloudIds.classId(teacherUid: uid, localClassId: 7))
            .hasCloudBinding,
        isFalse,
      );
      expect(
        link(studentCloudId:
                CloudIds.studentId(teacherUid: uid, localStudentId: 42))
            .hasCloudBinding,
        isFalse,
      );
    });

    test('Kimlikler ogretmenin odasiyla ayni deseni tasir', () {
      // Veli bu kimlikle ogretmenin yazdigi odaya bakar; desen
      // uyusmazsa iki taraf farkli odaya bakar.
      const uid = 'firebaseUidAhmet';
      final classCloudId =
          CloudIds.classId(teacherUid: uid, localClassId: 7);

      expect(classCloudId, 'cls_${uid}_7');
      expect(link(classCloudId: classCloudId).classCloudId, classCloudId);
    });

    test('Kaydedilip geri okununca kimlikler korunur', () {
      const uid = 'firebaseUidAhmet';
      final orijinal = link(
        classCloudId: CloudIds.classId(teacherUid: uid, localClassId: 7),
        studentCloudId: CloudIds.studentId(teacherUid: uid, localStudentId: 42),
      );

      final geri = ParentLinkModel.fromMap(orijinal.toMap());

      expect(geri.classCloudId, orijinal.classCloudId);
      expect(geri.studentCloudId, orijinal.studentCloudId);
      expect(geri.hasCloudBinding, isTrue);
    });
  });
}
