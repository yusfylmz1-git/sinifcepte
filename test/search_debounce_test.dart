import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/utils/search_debouncer.dart';

/// Arama gecikmesi (Faz 3.2).
///
/// Arama alanlari her tus vurusunda `setState` cagiriyordu; 1000+ satirlik
/// ekranlar saniyede onlarca kez bastan ciziliyordu. Kullanici
/// "WhatsApp'ta akici, bende yavas" diye bildirdi.
///
/// `SearchDebouncer` yazilmisti ama HICBIR YERE BAGLANMAMISTI.
void main() {
  group('Gecikme davranisi', () {
    test('KRITIK: art arda tuslar tek cagri uretir', () async {
      final d = SearchDebouncer(delay: const Duration(milliseconds: 40));
      var cagri = 0;

      // Ogretmen "Ayse" yaziyor: 4 tus
      for (var i = 0; i < 4; i++) {
        d.run(() => cagri++);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(cagri, 0, reason: 'yazma bitmeden cizim olmamali');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cagri, 1, reason: '4 tus icin tek yeniden cizim');
      d.dispose();
    });

    test('yazma bitince tetiklenir', () async {
      final d = SearchDebouncer(delay: const Duration(milliseconds: 30));
      var tetiklendi = false;
      d.run(() => tetiklendi = true);

      expect(tetiklendi, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(tetiklendi, isTrue);
      d.dispose();
    });

    test('KRITIK: dispose sonrasi tetiklenmez', () async {
      final d = SearchDebouncer(delay: const Duration(milliseconds: 30));
      var tetiklendi = false;
      d.run(() => tetiklendi = true);
      d.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(tetiklendi, isFalse,
          reason: 'ekran kapandiktan sonra setState cagrilirsa hata duser');
    });

    test('cancel bekleyen cagriyi iptal eder', () async {
      final d = SearchDebouncer(delay: const Duration(milliseconds: 30));
      var tetiklendi = false;
      d.run(() => tetiklendi = true);
      expect(d.isPending, isTrue);
      d.cancel();
      expect(d.isPending, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(tetiklendi, isFalse);
      d.dispose();
    });
  });

  group('Buyuk ekranlara gercekten baglandi mi', () {
    /// Dosya hem debouncer kuruyor hem de dispose ediyor mu?
    void baglanmis(String path, String ad) {
      final s = File(path).readAsStringSync();
      expect(s.contains('SearchDebouncer('), isTrue,
          reason: '$ad: debouncer kurulmamis');
      expect(s.contains('_searchDebouncer.run('), isTrue,
          reason: '$ad: onChanged debouncer kullanmiyor');
      expect(s.contains('_searchDebouncer.dispose()'), isTrue,
          reason: '$ad: dispose edilmemis — kapanan ekranda setState hatasi');
    }

    test('KRITIK: ogrenci listesi (1114 satir)', () {
      baglanmis('lib/features/classes/screens/student_list_screen.dart',
          'ogrenci listesi');
    });

    test('KRITIK: veli rehberi (1173 satir)', () {
      baglanmis('lib/features/classes/screens/parent_contacts_screen.dart',
          'veli rehberi');
    });

    test('KRITIK: referans kodlari modali (1111 satir)', () {
      baglanmis(
        'lib/features/parent_portal/presentation/widgets/class_reference_codes_modal.dart',
        'referans kodlari',
      );
    });

    test('KRITIK: karne yorumlari modali (974 satir)', () {
      baglanmis(
        'lib/features/analytics/presentation/widgets/class_report_card_comments_modal.dart',
        'karne yorumlari',
      );
    });
  });
}
