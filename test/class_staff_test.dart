import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';

void main() {
  group('Ders öğretmeni kadrosu (mesajlaşma yetki ekseni)', () {
    test('Kadro üyesi gerçek Firebase UID taşır', () {
      // Katılım kodlu 'pending_' yolu kaldırıldı: uygulamaya hiç girmemiş
      // öğretmen zaten mesajlaşamıyordu, kadroda görünmesi veliye
      // tutulamayan bir söz veriyordu. Artık kadroya yalnızca okul
      // dizininde kayıtlı (yani uygulamaya girmiş) öğretmen eklenir.
      const member = CloudStaffMember(
        teacherUid: 'firebaseUid123',
        teacherName: 'Selin Demir',
        branch: 'Fizik',
      );

      expect(member.teacherUid, isNotEmpty);
      expect(member.teacherUid.startsWith('pending_'), isFalse);
    });

    test('Veliye gösterilen etiket ad ve branşı birleştirir', () {
      const withBranch = CloudStaffMember(
        teacherUid: 'uid1',
        teacherName: 'Selin Demir',
        branch: 'Fizik',
      );
      const withoutBranch = CloudStaffMember(
        teacherUid: 'uid2',
        teacherName: 'Ahmet Yılmaz',
        branch: '',
      );

      expect(withBranch.displayTitle, 'Selin Demir — Fizik');
      // Branş boşsa yalnızca ad gösterilir, boş tire kalmaz.
      expect(withoutBranch.displayTitle, 'Ahmet Yılmaz');
    });

    test('Sınıf rehber öğretmeni işaretlenebilir', () {
      const homeroom = CloudStaffMember(
        teacherUid: 'uid1',
        teacherName: 'Ayşe Demir',
        branch: 'Türkçe',
        isHomeroom: true,
      );

      expect(homeroom.isHomeroom, isTrue);
    });

    test('Görüşme günü ve saati taşınır', () {
      const member = CloudStaffMember(
        teacherUid: 'uid1',
        teacherName: 'Selin Demir',
        branch: 'Fizik',
        meetingDay: 'Salı',
        meetingTime: '13:30',
      );

      expect(member.meetingDay, 'Salı');
      expect(member.meetingTime, '13:30');
    });
  });

  group('Bulut duyurusu görsel sözleşmesi', () {
    CloudAnnouncement build(String priority) => CloudAnnouncement(
          id: 'a1',
          title: 'Başlık',
          content: 'İçerik',
          priority: priority,
          createdAt: DateTime(2026, 8, 18),
          updatedAt: DateTime(2026, 8, 18),
        );

    test('Öncelik bayrakları doğru çözümlenir', () {
      expect(build('urgent').isUrgent, isTrue);
      expect(build('event').isEvent, isTrue);
      expect(build('normal').isUrgent, isFalse);
      expect(build('normal').isEvent, isFalse);
    });

    test('Her öncelik için ikon ve renk tanımlıdır', () {
      for (final p in ['normal', 'urgent', 'event', 'bilinmeyen']) {
        expect(build(p).priorityIcon, isNotNull);
        expect(build(p).priorityColor, isNotNull);
      }
    });

    test('copyWith okundu durumunu değiştirir, diğer alanları korur', () {
      final original = build('urgent');
      final read = original.copyWith(readByMe: true, readCount: 5);

      expect(read.readByMe, isTrue);
      expect(read.readCount, 5);
      expect(read.title, original.title);
      expect(read.priority, original.priority);
      expect(read.createdAt, original.createdAt);
    });
  });

  group('Bulut mesajı', () {
    test('Yazar rolü öğretmen/veli ayrımı yapar', () {
      final fromTeacher = CloudMessage(
        id: 'm1',
        studentCloudId: 'stu_uid_1',
        parentUserId: 'parentAyse',
        authorRole: 'teacher',
        authorName: 'Selin Demir',
        body: 'Merhaba',
        createdAt: DateTime(2026, 8, 18),
      );
      final fromParent = CloudMessage(
        id: 'm2',
        studentCloudId: 'stu_uid_1',
        parentUserId: 'parentAyse',
        authorRole: 'parent',
        authorName: 'Ayşe Yılmaz',
        body: 'Teşekkürler',
        createdAt: DateTime(2026, 8, 18),
      );

      expect(fromTeacher.isFromTeacher, isTrue);
      expect(fromParent.isFromTeacher, isFalse);
    });

    test('KRİTİK: mesaj hangi öğretmene ait olduğunu taşır', () {
      // Bu alan yoktu: mesajlar yalnızca studentCloudId ile
      // filtrelendiği için velinin TÜM öğretmenlerle yazışması tek
      // sohbette birikiyordu. Veli matematik öğretmenine yazdığını
      // beden eğitimi öğretmeni de görüyordu.
      final toMath = CloudMessage(
        id: 'm1',
        studentCloudId: 'stu_uid_1',
        parentUserId: 'parentAyse',
        authorRole: 'parent',
        authorName: 'Ayşe Yılmaz',
        teacherUid: 'uid_matematik',
        body: 'Özel bir konu',
        createdAt: DateTime(2026, 8, 18),
      );
      final toPe = CloudMessage(
        id: 'm2',
        studentCloudId: 'stu_uid_1',
        parentUserId: 'parentAyse',
        authorRole: 'parent',
        authorName: 'Ayşe Yılmaz',
        teacherUid: 'uid_beden',
        body: 'Başka bir konu',
        createdAt: DateTime(2026, 8, 18),
      );

      expect(toMath.teacherUid, isNot(toPe.teacherUid),
          reason: 'Sohbetler ayrışmıyor: aynı öğrenci için iki farklı '
              'öğretmene yazılan mesaj aynı sohbete düşer');

      // Matematik sohbetini süzdüğümüzde beden mesajı gelmemeli.
      final mathThread = [toMath, toPe]
          .where((m) => m.teacherUid == 'uid_matematik')
          .toList();
      expect(mathThread.length, 1);
      expect(mathThread.single.body, 'Özel bir konu');
    });
  });
}
