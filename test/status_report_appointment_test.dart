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
    title: 'Erken çıkış',
    details: 'Bugün saat 14:00 alınacak',
    timeInfo: '14:00',
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
      // Not: 'medication' türü kaldırıldı (Karar: 18 Ağustos 2026) —
      // sağlık verisi KVKK'da özel nitelikli sayılır. Ayrıntı için
      // test/retention_policy_test.dart.
      expect(report(type: 'late').isLate, isTrue);
      expect(report(type: 'early_leave').isEarlyLeave, isTrue);
      expect(report(type: 'note').isLate, isFalse);
      expect(report(type: 'note').isEarlyLeave, isFalse);
    });

    test('Onay durumu pending dışındaki değerlerde true döner', () {
      expect(report(status: 'pending').isAcknowledged, isFalse);
      expect(report(status: 'acknowledged').isAcknowledged, isTrue);
      expect(report(status: 'completed').isAcknowledged, isTrue);
    });

    test('Her tür için ikon ve renk tanımlıdır', () {
      for (final t in ['early_leave', 'late', 'note', 'bilinmeyen']) {
        expect(report(type: t).typeIcon, isNotNull);
        expect(report(type: t).typeColor, isNotNull);
      }
    });

    test('Erken çıkış bildirimi nottan görsel olarak ayrışır', () {
      expect(
        report(type: 'early_leave').typeColor,
        isNot(report(type: 'note').typeColor),
      );
    });

    test('Bildirim içeriği ve zaman bilgisi taşınır', () {
      final r = report(type: 'early_leave');
      expect(r.title, 'Erken çıkış');
      expect(r.details, 'Bugün saat 14:00 alınacak');
      expect(r.timeInfo, '14:00');
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
