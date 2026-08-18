import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/parent_portal/data/models/class_announcement_model.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_appointment_model.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_status_report_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/parent_portal_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParentPortalRepository Tests', () {
    late ParentPortalRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PrefsService.resetCache();
      repository = ParentPortalRepository();
    });

    test('Status Report creation and teacher acknowledgement workflow', () async {
      final report = ParentStatusReportModel(
        id: 'rep_001',
        studentId: 101,
        studentName: 'Ali Yılmaz',
        studentNumber: 142,
        classId: 5,
        className: '8-A',
        parentUserId: 'puser_1',
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
        type: 'medication',
        title: 'İlaç Kullanımı',
        details: 'Öğle saatinde içmesi gereken şurup var.',
        createdAt: DateTime.now(),
      );

      // 1. Veli bildirimi oluşturur
      await repository.createStatusReport(report);

      final studentReports = await repository.getStatusReportsForStudent(101);
      expect(studentReports.length, equals(1));
      expect(studentReports.first.isAcknowledged, isFalse);

      // 2. Öğretmen bildirimi görür ve onaylar
      final ackSuccess = await repository.acknowledgeStatusReport(
        'rep_001',
        teacherNote: 'Tamamdır, öğle arasında ilacını içirdiğinden emin olacağım.',
      );
      expect(ackSuccess, isTrue);

      final updatedReports = await repository.getStatusReportsForStudent(101);
      expect(updatedReports.first.isAcknowledged, isTrue);
      expect(updatedReports.first.teacherNote, contains('ilacını içirdiğinden emin olacağım'));
    });

    test('Class Announcements and read receipts tracking', () async {
      final announcement = ClassAnnouncementModel(
        id: 'ann_001',
        classId: 5,
        className: '8-A',
        authorTeacherId: 'teacher_1',
        authorTeacherName: 'Ahmet Öğretmen',
        title: 'Genel Veli Toplantısı',
        content: 'Cumartesi günü saat 11:00\'de okulumuzda toplanılacaktır.',
        priority: 'event',
        createdAt: DateTime.now(),
      );

      await repository.createAnnouncement(announcement);

      // 1. İlk başta okunma sayısı 0 olmalı
      var classAnnouncements = await repository.getAnnouncementsForClass(5);
      expect(classAnnouncements.length, equals(1));
      expect(classAnnouncements.first.readCount, equals(0));

      // 2. Birinci veli okundu olarak işaretler
      await repository.markAnnouncementAsRead('ann_001', 'puser_mom_1');
      classAnnouncements = await repository.getAnnouncementsForClass(5);
      expect(classAnnouncements.first.readCount, equals(1));
      expect(classAnnouncements.first.isReadBy('puser_mom_1'), isTrue);
      expect(classAnnouncements.first.isReadBy('puser_dad_2'), isFalse);

      // 3. İkinci veli de okur
      await repository.markAnnouncementAsRead('ann_001', 'puser_dad_2');
      classAnnouncements = await repository.getAnnouncementsForClass(5);
      expect(classAnnouncements.first.readCount, equals(2));
    });

    test('Teacher Contacts template generation for classroom', () async {
      final teachers = await repository.getTeacherContactsForClass(
        5,
        className: '8-A',
        homeroomTeacherName: 'Yusuf Öğretmen',
        homeroomBranch: 'Bilişim',
      );

      expect(teachers.length, 1);
      expect(teachers.first.isHomeroomTeacher, isTrue);
      expect(teachers.first.teacherName, 'Yusuf Öğretmen');
    });

    test('Appointment scheduling with time-slot conflict protection', () async {
      final appointmentDate = DateTime(2026, 9, 20);

      final app1 = ParentAppointmentModel(
        id: 'app_001',
        classId: 5,
        className: '8-A',
        studentId: 101,
        studentName: 'Ali Yılmaz',
        studentNumber: 142,
        parentUserId: 'puser_1',
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
        teacherName: 'Ahmet Yılmaz',
        branch: 'Matematik',
        appointmentDate: appointmentDate,
        timeSlot: '13:30 - 14:00',
        topic: 'Ders durumu değerlendirmesi',
        createdAt: DateTime.now(),
      );

      // 1. Birinci veli randevuyu talep eder ve onaylanır
      final res1 = await repository.requestAppointment(app1);
      expect(res1['success'], isTrue);
      await repository.updateAppointmentStatus('app_001', status: 'confirmed');

      // 2. İkinci veli aynı gün, aynı saat ve aynı öğretmene randevu almaya çalışır -> Çakışma engellenir!
      final app2 = ParentAppointmentModel(
        id: 'app_002',
        classId: 5,
        className: '8-A',
        studentId: 102,
        studentName: 'Mehmet Kaya',
        studentNumber: 143,
        parentUserId: 'puser_2',
        parentName: 'Fatma Kaya',
        relation: 'Anne',
        teacherName: 'Ahmet Yılmaz',
        branch: 'Matematik',
        appointmentDate: appointmentDate,
        timeSlot: '13:30 - 14:00',
        topic: 'Gelişim görüşmesi',
        createdAt: DateTime.now(),
      );

      final res2 = await repository.requestAppointment(app2);
      expect(res2['success'], isFalse);
      expect(res2['message'], contains('başka bir randevusu bulunmaktadır'));
    });
  });
}
