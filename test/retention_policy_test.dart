import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';

/// Saklama süresi ve sağlık verisi kaldırma kararları.
///
/// ## Bağlam (Karar: 18 Ağustos 2026)
/// KVKK'da sağlık verisi **özel nitelikli** sayılır; toplanması açık rıza
/// ister ve ihlali daha ağır yaptırıma tabidir. "İlaç Kullanımı" bildirim
/// türü, sağladığı değerin bu riski karşılamaması nedeniyle kaldırıldı.
///
/// Ayrıca KVKK'nın "sınırlı süre" ilkesi gereği bildirimler süresiz
/// saklanmaz.
void main() {
  CloudStatusReport report(String type) => CloudStatusReport(
        id: 'r1',
        studentCloudId: 'stu_uid_1',
        studentName: 'Ali',
        parentUserId: 'p1',
        parentName: 'Ayşe',
        type: type,
        title: 'Başlık',
        details: 'Detay',
        createdAt: DateTime(2026, 8, 18),
      );

  group('Sağlık verisi toplanmıyor', () {
    test('KRİTİK: medication türü artık tanınmıyor', () {
      // Eski kayıtlar bozulmadan okunur ama özel bir anlamı kalmaz:
      // varsayılan (not) görünümüne düşer.
      final legacy = report('medication');

      expect(legacy.isLate, isFalse);
      expect(legacy.isEarlyLeave, isFalse);
      // İkon ve renk varsayılana düşer, çökmez.
      expect(legacy.typeIcon, isNotNull);
      expect(legacy.typeColor, isNotNull);
    });

    test('Desteklenen türler: erken çıkış, geç kalma, not', () {
      expect(report('early_leave').isEarlyLeave, isTrue);
      expect(report('late').isLate, isTrue);
      expect(report('note').isEarlyLeave, isFalse);
      expect(report('note').isLate, isFalse);
    });

    test('Her tür için ikon ve renk tanımlı', () {
      for (final t in ['early_leave', 'late', 'note', 'bilinmeyen']) {
        expect(report(t).typeIcon, isNotNull);
        expect(report(t).typeColor, isNotNull);
      }
    });

    test('Erken çıkış ve geç kalma görsel olarak ayrışır', () {
      expect(
        report('early_leave').typeColor,
        isNot(report('late').typeColor),
      );
    });
  });

  group('Saklama süresi (KVKK: sınırlı süre ilkesi)', () {
    test('Durum bildirimleri 30 gün saklanır', () {
      expect(
        CloudCommunicationRepository.statusReportRetention,
        const Duration(days: 30),
      );
    });

    test('Randevular daha uzun saklanır (90 gün)', () {
      // Randevu geçmişi öğretmen için referans değeri taşır.
      expect(
        CloudCommunicationRepository.appointmentRetention,
        const Duration(days: 90),
      );
      expect(
        CloudCommunicationRepository.appointmentRetention,
        greaterThan(CloudCommunicationRepository.statusReportRetention),
      );
    });

    test('Süreler sonsuz değil (süresiz saklama yok)', () {
      // "Ne kadar saklıyorsunuz?" sorusuna net yanıt verilebilmeli.
      expect(
        CloudCommunicationRepository.statusReportRetention.inDays,
        lessThanOrEqualTo(365),
      );
      expect(
        CloudCommunicationRepository.appointmentRetention.inDays,
        lessThanOrEqualTo(365),
      );
    });
  });
}
