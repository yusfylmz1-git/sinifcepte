import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';
import 'package:sinifcepte/features/parent_portal/presentation/parent_shell_tab.dart';

/// Veli arayuzu testleri.
///
/// Kullanici karari (30 Agustos 2026):
///  - Sinav takvimi AYRI bir koleksiyon degildir; ogretmen duyuru olarak
///    yayimlar, yalnizca gorunumu farklidir ('exam' onceligi).
///  - Alt bar: Ozet / Mesajlar / Takvim / Profil.
void main() {
  CloudAnnouncement ann({
    String priority = 'normal',
    DateTime? eventAt,
    String title = 'Baslik',
  }) {
    return CloudAnnouncement(
      id: 'a1',
      title: title,
      content: 'Icerik',
      priority: priority,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      eventAt: eventAt,
    );
  }

  group('Sinav duyurusu', () {
    test('KRITIK: sinav duyurusu ayirt edilir', () {
      // Ayri bir "exams" koleksiyonu acmak yerine duyuru altyapisi
      // kullanilir: sifir ek yazma/okuma maliyeti.
      final sinav = ann(priority: 'exam');
      expect(sinav.isExam, isTrue);
      expect(ann().isExam, isFalse);
    });

    test('Sinav duyurusunun kendi ikonu ve rengi vardir', () {
      final sinav = ann(priority: 'exam');
      expect(sinav.priorityIcon, isNotNull);
      expect(sinav.priorityColor, isNot(ann().priorityColor));
    });

    test('KRITIK: sinav tarihi tasinir', () {
      final tarih = DateTime(2026, 10, 15, 9, 30);
      final sinav = ann(priority: 'exam', eventAt: tarih);
      expect(sinav.eventAt, tarih);
    });

    test('Tarihsiz duyuruda eventAt bostur', () {
      expect(ann().eventAt, isNull);
    });

    test('Gecmis ve gelecek sinav ayirt edilir', () {
      final gecmis = ann(
        priority: 'exam',
        eventAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      final gelecek = ann(
        priority: 'exam',
        eventAt: DateTime.now().add(const Duration(days: 5)),
      );

      expect(gecmis.isUpcoming, isFalse);
      expect(gelecek.isUpcoming, isTrue);
    });

    test('Tarihsiz duyuru "yaklasan" sayilmaz', () {
      expect(ann().isUpcoming, isFalse);
    });

    test('Takvim ogesi olan duyurular suzulebilir', () {
      final liste = [
        ann(priority: 'normal'),
        ann(priority: 'exam', eventAt: DateTime(2026, 10, 15)),
        ann(priority: 'event', eventAt: DateTime(2026, 11, 1)),
      ];

      final takvim = liste.where((a) => a.eventAt != null).toList();
      expect(takvim.length, 2);
    });
  });

  group('Alt bar sekmeleri', () {
    test('KRITIK: dort sekme tanimlidir', () {
      expect(ParentShellTab.values.length, 4);
    });

    test('Sekme sirasi: Ozet, Mesajlar, Takvim, Profil', () {
      expect(ParentShellTab.values.map((t) => t.name).toList(),
          ['summary', 'messages', 'calendar', 'profile']);
    });

    test('Her sekmenin etiketi ve ikonu vardir', () {
      for (final tab in ParentShellTab.values) {
        expect(tab.label, isNotEmpty);
        expect(tab.icon, isNotNull);
        expect(tab.activeIcon, isNotNull);
      }
    });

    test('Etiketler Turkce ve kisadir', () {
      // Alt barda tasmamasi icin kisa tutulur.
      for (final tab in ParentShellTab.values) {
        expect(tab.label.length, lessThanOrEqualTo(9),
            reason: '${tab.label} alt barda tasabilir');
      }
    });
  });

  group('Rozet sayilari', () {
    test('Okunmamis sayisi rozette gosterilir', () {
      expect(ParentShellTab.badgeText(0), isNull);
      expect(ParentShellTab.badgeText(3), '3');
    });

    test('KRITIK: buyuk sayilar rozeti tasirmaz', () {
      expect(ParentShellTab.badgeText(150), '99+');
      expect(ParentShellTab.badgeText(99), '99');
    });
  });
}
