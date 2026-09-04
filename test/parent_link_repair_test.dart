import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinifcepte/core/cloud/cloud_ids.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_link_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/parent_token_repository.dart';

/// Bulut kimlikleri eksik baglarin onarimi.
///
/// Kullanicinin cihazindan okunan gercek kayit:
///   class_cloud_id: "", student_cloud_id: "", teacher_uid: ""
///
/// Bu alanlar bos oldugu surece `hasCloudBinding` false doner ve velinin
/// duyuru/kadro/mesaj sorgulari sunucuya HIC GITMEDEN bos liste verir.
/// Veli ekraninda "ogretmen eklenmemis" yazmasinin sebebi buydu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'KplpM8ibNdhVJENzWz8tvJ0vsLR2';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
  });

  ParentLinkModel bozukBag() => ParentLinkModel(
        id: 'link_12_1788085876822',
        parentUserId: 'OqGdTBnSScTryzzx0f6vccyzEyu2',
        parentName: 'Busra',
        studentId: 12,
        studentName: 'Ahmet Veysel İlhan',
        studentNumber: 51,
        schoolId: 'meb_775214',
        schoolName: 'Mimar Sinan Ortaokulu',
        classId: 2,
        className: '5-A',
        relation: 'Anne',
        linkedAt: DateTime(2026, 8, 30),
        linkedViaTokenCode: 'SC-5A-7053',
        status: 'active',
      );

  group('Bag onarimi', () {
    test('KRITIK: eksik bulut kimlikleri tamamlanir', () async {
      final repo = ParentTokenRepository();
      await repo.cacheParentLinkLocally(bozukBag());

      final onarilan = await repo.repairMissingCloudIds(
        teacherUidResolver: (_) async => uid,
      );

      expect(onarilan, 1);

      final baglar = await repo.getMyConnectedChildren(
        parentUid: 'OqGdTBnSScTryzzx0f6vccyzEyu2',
      );
      expect(baglar.single.hasCloudBinding, isTrue);
      expect(baglar.single.classCloudId, CloudIds.classId(
        teacherUid: uid,
        localClassId: 2,
      ));
    });

    test('KRITIK: ogretmen kimligi cozulemezse bag bozulmaz', () async {
      // Bulut erisimi yoksa bag oldugu gibi kalir; yanlis kimlikle
      // doldurmak veliyi BASKA bir sinifin odasina baglardi.
      final repo = ParentTokenRepository();
      await repo.cacheParentLinkLocally(bozukBag());

      final onarilan = await repo.repairMissingCloudIds(
        teacherUidResolver: (_) async => '',
      );

      expect(onarilan, 0);
      final baglar = await repo.getMyConnectedChildren(
        parentUid: 'OqGdTBnSScTryzzx0f6vccyzEyu2',
      );
      expect(baglar.single.hasCloudBinding, isFalse);
    });

    test('Zaten saglam bag tekrar onarilmaz', () async {
      final repo = ParentTokenRepository();
      await repo.cacheParentLinkLocally(bozukBag().copyWith(
        teacherUid: uid,
        classCloudId: CloudIds.classId(teacherUid: uid, localClassId: 2),
        studentCloudId: CloudIds.studentId(teacherUid: uid, localStudentId: 12),
      ));

      final onarilan = await repo.repairMissingCloudIds(
        teacherUidResolver: (_) async => 'baskaUid123',
      );

      expect(onarilan, 0, reason: 'Saglam bag degistirilmemeli');
    });
  });
}
