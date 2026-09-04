import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/data/models/app_notification.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';
import 'package:sinifcepte/features/parent_portal/data/services/notification_builder.dart';

/// Bildirim merkezi beslemesi.
///
/// Bildirimler ZATEN CEKILMIS verilerden uretilir (duyurular, mesajlar,
/// randevular) — ek Firestore okumasi yoktur. Push (FCM) yerine bu yol
/// secildi: push icin Cloud Functions ve Blaze plani gerekirdi.
void main() {
  final simdi = DateTime(2026, 8, 30, 15, 0);

  CloudAnnouncement duyuru({
    String id = 'a1',
    bool okundu = false,
    String priority = 'normal',
    DateTime? at,
  }) {
    return CloudAnnouncement(
      id: id,
      title: 'Veli Toplantisi',
      content: 'Persembe gunu',
      priority: priority,
      createdAt: at ?? simdi,
      updatedAt: at ?? simdi,
      readByMe: okundu,
    );
  }

  CloudMessage mesaj({
    String id = 'm1',
    String authorRole = 'teacher',
    DateTime? at,
  }) {
    return CloudMessage(
      id: id,
      studentCloudId: 'stu_x_1',
      parentUserId: 'parentAyse',
      authorRole: authorRole,
      authorName: 'Selin Ogretmen',
      teacherUid: 'uid_selin',
      body: 'Merhaba',
      createdAt: at ?? simdi,
    );
  }

  CloudAppointment randevu({
    String id = 'r1',
    String status = 'confirmed',
    DateTime? at,
  }) {
    return CloudAppointment(
      id: id,
      studentCloudId: 'stu_x_1',
      studentName: 'Ali',
      parentUserId: 'parentAyse',
      parentName: 'Ayse',
      relation: 'Anne',
      teacherName: 'Selin Ogretmen',
      branch: 'Fizik',
      appointmentDate: at ?? simdi,
      timeSlot: '13:30 - 14:15',
      topic: 'Gelisim',
      status: status,
      createdAt: at ?? simdi,
    );
  }

  group('Veli beslemesi', () {
    test('KRITIK: okunmamis duyuru bildirime donusur', () {
      final liste = NotificationBuilder.forParent(
        announcements: [duyuru(okundu: false)],
        messages: const [],
        appointments: const [],
        lastSeenMessages: null,
      );

      expect(liste.length, 1);
      expect(liste.single.kind, NotificationKind.announcement);
      expect(liste.single.isRead, isFalse);
    });

    test('Okunmus duyuru da listede ama okunmus isaretli', () {
      final liste = NotificationBuilder.forParent(
        announcements: [duyuru(okundu: true)],
        messages: const [],
        appointments: const [],
        lastSeenMessages: null,
      );

      expect(liste.single.isRead, isTrue);
    });

    test('KRITIK: sinav duyurusu ayri tur olarak gorunur', () {
      final liste = NotificationBuilder.forParent(
        announcements: [duyuru(priority: 'exam')],
        messages: const [],
        appointments: const [],
        lastSeenMessages: null,
      );

      expect(liste.single.kind, NotificationKind.exam);
    });

    test('KRITIK: velinin kendi mesaji bildirim uretmez', () {
      // Aksi halde veli her mesaj gonderdiginde kendine bildirim gelirdi.
      final liste = NotificationBuilder.forParent(
        announcements: const [],
        messages: [mesaj(authorRole: 'parent')],
        appointments: const [],
        lastSeenMessages: null,
      );

      expect(liste, isEmpty);
    });

    test('KRITIK: son goruntulemeden sonraki mesaj okunmamis sayilir', () {
      final gorulme = simdi.subtract(const Duration(hours: 1));
      final liste = NotificationBuilder.forParent(
        announcements: const [],
        messages: [mesaj(at: simdi)],
        appointments: const [],
        lastSeenMessages: gorulme,
      );

      expect(liste.single.isRead, isFalse);
    });

    test('Son goruntulemeden onceki mesaj okunmus sayilir', () {
      final gorulme = simdi;
      final liste = NotificationBuilder.forParent(
        announcements: const [],
        messages: [mesaj(at: simdi.subtract(const Duration(hours: 2)))],
        appointments: const [],
        lastSeenMessages: gorulme,
      );

      expect(liste.single.isRead, isTrue);
    });

    test('KRITIK: bekleyen randevu bildirim uretmez, karara varilan urettir', () {
      // Veli talebi kendi gonderdi; onaylandiginda haber almali.
      final bekleyen = NotificationBuilder.forParent(
        announcements: const [],
        messages: const [],
        appointments: [randevu(status: 'pending')],
        lastSeenMessages: null,
      );
      final onayli = NotificationBuilder.forParent(
        announcements: const [],
        messages: const [],
        appointments: [randevu(status: 'confirmed')],
        lastSeenMessages: null,
      );

      expect(bekleyen, isEmpty);
      expect(onayli.length, 1);
      expect(onayli.single.kind, NotificationKind.appointment);
    });
  });

  group('Ogretmen beslemesi', () {
    test('KRITIK: veli mesaji bildirim uretir', () {
      final liste = NotificationBuilder.forTeacher(
        messages: [mesaj(authorRole: 'parent')],
        reports: const [],
        appointments: const [],
        lastSeenMessages: null,
      );

      expect(liste.length, 1);
      expect(liste.single.kind, NotificationKind.message);
    });

    test('KRITIK: ogretmenin kendi mesaji bildirim uretmez', () {
      final liste = NotificationBuilder.forTeacher(
        messages: [mesaj(authorRole: 'teacher')],
        reports: const [],
        appointments: const [],
        lastSeenMessages: null,
      );

      expect(liste, isEmpty);
    });

    test('KRITIK: bekleyen randevu talebi ogretmene bildirilir', () {
      final liste = NotificationBuilder.forTeacher(
        messages: const [],
        reports: const [],
        appointments: [randevu(status: 'pending')],
        lastSeenMessages: null,
      );

      expect(liste.length, 1);
      expect(liste.single.isRead, isFalse);
    });

    test('Karara baglanmis randevu tekrar bildirilmez', () {
      final liste = NotificationBuilder.forTeacher(
        messages: const [],
        reports: const [],
        appointments: [randevu(status: 'confirmed')],
        lastSeenMessages: null,
      );

      expect(liste, isEmpty);
    });
  });

  group('Siralama ve sayim', () {
    test('KRITIK: okunmamislar ustte, sonra en yeni', () {
      final liste = NotificationBuilder.forParent(
        announcements: [
          duyuru(id: 'eski_okunmamis', okundu: false, at: DateTime(2026, 8, 20)),
          duyuru(id: 'yeni_okunmus', okundu: true, at: DateTime(2026, 8, 29)),
        ],
        messages: const [],
        appointments: const [],
        lastSeenMessages: null,
      );

      expect(liste.first.isRead, isFalse);
      expect(AppNotification.unreadCount(liste), 1);
    });
  });
}
