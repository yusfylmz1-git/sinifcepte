import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';

CloudStatusReport report({
  String type = 'note',
  String status = 'pending',
}) {
  return CloudStatusReport(
    id: 'rep_1',
    studentCloudId: 'stu_teacherAhmet_42',
    studentName: 'Ali Yılmaz',
    parentUserId: 'parentAyse',
    parentName: 'Ayşe Yılmaz',
    relation: 'Anne',
    type: type,
    title: 'Alerji ilacı',
    details: 'Öğle arası verilmeli',
    timeInfo: '12:30',
    createdAt: DateTime(2026, 8, 18, 8),
    status: status,
  );
}

CloudAppointment appointment({String status = 'pending'}) {
  return CloudAppointment(
    id: 'apt_1',
    studentCloudId: 'stu_teacherAhmet_42',
    studentName: 'Ali Yılmaz',
    parentUserId: 'parentAyse',
    parentName: 'Ayşe Yılmaz',
    relation: 'Anne',
    teacherName: 'Selin Demir',
    branch: 'Fizik',
    appointmentDate: DateTime(2026, 8, 20),
    timeSlot: '13:30',
    topic: 'Ders gelişimi',
    status: status,
    createdAt: DateTime(2026, 8, 18),
  );
}

void main() {
  group('Durum bildirimi (veli → öğretmen)', () {
    test('Bildirim türleri doğru ayırt edilir', () {
      expect(report(type: 'medication').isMedication, isTrue);
      expect(report(type: 'early_leave').isEarlyLeave, isTrue);
      expect(report(type: 'note').isMedication, isFalse);
      expect(report(type: 'note').isEarlyLeave, isFalse);
    });

    test('Onay durumu pending dışındaki değerlerde true döner', () {
      expect(report(status: 'pending').isAcknowledged, isFalse);
      expect(report(status: 'acknowledged').isAcknowledged, isTrue);
      expect(report(status: 'completed').isAcknowledged, isTrue);
    });

    test('Her tür için ikon ve renk tanımlıdır', () {
      for (final t in ['medication', 'early_leave', 'note', 'bilinmeyen']) {
        expect(report(type: t).typeIcon, isNotNull);
        expect(report(type: t).typeColor, isNotNull);
      }
    });

    test('İlaç bildirimi görsel olarak en dikkat çekici renkte', () {
      // Sağlıkla ilgili bildirim, nottan ayırt edilebilmeli.
      expect(
        report(type: 'medication').typeColor,
        isNot(report(type: 'note').typeColor),
      );
    });

    test('Bildirim içeriği ve zaman bilgisi taşınır', () {
      final r = report(type: 'medication');
      expect(r.title, 'Alerji ilacı');
      expect(r.details, 'Öğle arası verilmeli');
      expect(r.timeInfo, '12:30');
      expect(r.relation, 'Anne');
    });
  });

  group('Randevu (veli → öğretmen)', () {
    test('Durum bayrakları doğru çözümlenir', () {
      expect(appointment(status: 'pending').isPending, isTrue);
      expect(appointment(status: 'confirmed').isConfirmed, isTrue);
      expect(appointment(status: 'rejected').isRejected, isTrue);
      expect(appointment(status: 'confirmed').isPending, isFalse);
    });

    test('Türkçe durum metinleri tüm durumlar için tanımlı', () {
      expect(appointment(status: 'pending').statusTitleTr, 'Onay bekliyor');
      expect(appointment(status: 'confirmed').statusTitleTr, 'Onaylandı');
      expect(appointment(status: 'rejected').statusTitleTr, 'Reddedildi');
      expect(appointment(status: 'cancelled').statusTitleTr, 'İptal edildi');
      expect(appointment(status: 'completed').statusTitleTr, 'Tamamlandı');
      // Bilinmeyen durum güvenli varsayılana düşer.
      expect(appointment(status: 'garip').statusTitleTr, 'Onay bekliyor');
    });

    test('Onaylanan ve reddedilen randevu farklı renkte gösterilir', () {
      expect(
        appointment(status: 'confirmed').statusColor,
        isNot(appointment(status: 'rejected').statusColor),
      );
    });

    test('Randevu bilgileri taşınır', () {
      final a = appointment();
      expect(a.teacherName, 'Selin Demir');
      expect(a.branch, 'Fizik');
      expect(a.timeSlot, '13:30');
      expect(a.topic, 'Ders gelişimi');
      expect(a.appointmentDate, DateTime(2026, 8, 20));
    });

    test('Veli kimliği randevuya bağlıdır (izolasyon için gerekli)', () {
      // Kural motoru parentUserId üzerinden yetki denetler.
      expect(appointment().parentUserId, 'parentAyse');
      expect(appointment().studentCloudId, 'stu_teacherAhmet_42');
    });
  });
}
