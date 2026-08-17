import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/cloud/cloud_ids.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_link_model.dart';

ParentLinkModel buildLink({
  String classCloudId = 'cls_uidAhmet_7',
  String studentCloudId = 'stu_uidAhmet_42',
  String teacherUid = 'uidAhmet',
}) {
  return ParentLinkModel(
    id: 'parentAyse_stu_uidAhmet_42',
    parentUserId: 'parentAyse',
    parentName: 'Ayşe Yılmaz',
    studentId: 42,
    studentName: 'Ali Yılmaz',
    studentNumber: 112,
    schoolId: 'meb_16_123',
    schoolName: 'Cumhuriyet Ortaokulu',
    classId: 7,
    className: '7-B',
    relation: 'Anne',
    linkedAt: DateTime(2026, 8, 18),
    linkedViaTokenCode: '',
    classCloudId: classCloudId,
    studentCloudId: studentCloudId,
    teacherUid: teacherUid,
  );
}

void main() {
  group('Veli bağının bulut kimlikleri', () {
    test('Bulut kimlikleri kayıpsız serileştirilir', () {
      final original = buildLink();
      final restored = ParentLinkModel.fromMap(original.toMap());

      expect(restored.classCloudId, 'cls_uidAhmet_7');
      expect(restored.studentCloudId, 'stu_uidAhmet_42');
      expect(restored.teacherUid, 'uidAhmet');
      expect(restored.hasCloudBinding, isTrue);
    });

    test('Faz 2 öncesi kayıtlar bozulmadan okunur (geriye uyumluluk)', () {
      // Eski kayıtta bulut alanları hiç yok.
      final legacyMap = <String, dynamic>{
        'id': 'link_42_1234',
        'parent_user_id': 'puser_eski',
        'parent_name': 'Eski Veli',
        'student_id': 42,
        'student_name': 'Ali Yılmaz',
        'student_number': 112,
        'school_id': 'meb_16_123',
        'school_name': 'Cumhuriyet Ortaokulu',
        'class_id': 7,
        'class_name': '7-B',
        'relation': 'Anne',
        'linked_at': '2026-01-01T00:00:00.000',
        'linked_via_token_code': 'SC-7B-1111',
        'status': 'active',
      };

      final restored = ParentLinkModel.fromMap(legacyMap);

      expect(restored.studentName, 'Ali Yılmaz');
      expect(restored.classCloudId, isEmpty);
      // Bulut akışları kapalı olmalı: hangi bulut sınıfına ait olduğu bilinmiyor.
      expect(restored.hasCloudBinding, isFalse);
    });

    test('Eksik bulut kimliği bulut akışlarını kapatır', () {
      expect(buildLink(classCloudId: '').hasCloudBinding, isFalse);
      expect(buildLink(studentCloudId: '').hasCloudBinding, isFalse);
    });

    test('Bağ kimliği kural desenine uyar', () {
      final link = buildLink();
      final expected = CloudIds.parentLinkId(
        parentUid: link.parentUserId,
        studentCloudId: link.studentCloudId,
      );

      expect(link.id, expected);
      // firestore.rules: id.matches(request.auth.uid + '_.*')
      expect(link.id.startsWith('${link.parentUserId}_'), isTrue);
    });

    test('Bulut kimliğinden sahibi öğretmen doğrulanabilir', () {
      final link = buildLink();

      expect(
        CloudIds.teacherOwnsClass(
          teacherUid: link.teacherUid,
          classCloudId: link.classCloudId,
        ),
        isTrue,
      );
      expect(CloudIds.ownerUidOfStudent(link.studentCloudId), link.teacherUid);
    });

    test('copyWith bulut alanlarını korur', () {
      final link = buildLink();
      final archived = link.copyWith(status: 'archived');

      expect(archived.classCloudId, link.classCloudId);
      expect(archived.studentCloudId, link.studentCloudId);
      expect(archived.teacherUid, link.teacherUid);
      expect(archived.status, 'archived');
    });

    test('Düz referans kodu bağ kaydında saklanmaz', () {
      // Köprü bağ kurduktan sonra kodu tutmaz: kullanılmış kodun
      // saklanması gereksiz bir sır ifşasıdır.
      final link = buildLink();
      expect(link.linkedViaTokenCode, isEmpty);
    });
  });
}
