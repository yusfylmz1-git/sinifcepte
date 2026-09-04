import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/presentation/screens/teacher_parent_panel_screen.dart';

/// Ogretmenin veli yonetim paneli.
///
/// Kullanici bildirdi: "duzgun bi veli ve sinif yonetim panelimiz yok
/// ogretmen hic bir sey anlamaz boyle". Panel oncesinde her sey tek bir
/// alt sayfanin icinde bes sekmedeydi.
void main() {
  group('Panel sekmeleri', () {
    test('KRITIK: bes sekme tanimli', () {
      expect(TeacherPanelTab.values.length, 5);
    });

    test('Sekme sirasi: Ozet, Mesajlar, Duyurular, Veliler, Kadro', () {
      expect(
        TeacherPanelTab.values.map((t) => t.name).toList(),
        ['summary', 'messages', 'announcements', 'parents', 'staff'],
      );
    });

    test('KRITIK: Ozet ilk sirada', () {
      // Ogretmen paneli actiginda once "ne olup bitiyor" gormeli.
      expect(TeacherPanelTab.values.first, TeacherPanelTab.summary);
    });

    test('Her sekmenin etiketi ve ikonu var', () {
      for (final tab in TeacherPanelTab.values) {
        expect(tab.label, isNotEmpty);
        expect(tab.icon, isNotNull);
      }
    });

    test('KRITIK: etiketler alt barda tasmaz', () {
      for (final tab in TeacherPanelTab.values) {
        expect(tab.label.length, lessThanOrEqualTo(9),
            reason: '${tab.label} alt barda tasabilir');
      }
    });

    test('Etiketler benzersiz', () {
      final labels = TeacherPanelTab.values.map((t) => t.label).toSet();
      expect(labels.length, TeacherPanelTab.values.length);
    });
  });

  group('Ogretmen kadrosuna erisim', () {
    test('KRITIK: kadro yonetimi Sinifim sayfasindan acilabiliyor', () {
      // Bu ekrana ulasmak icin once Veli Paneli modalini acmak
      // gerekiyordu; ogretmen kadro yonetimini bulamiyordu.
      final kod = File(
        'lib/features/classes/screens/my_class_hub_screen.dart',
      ).readAsStringSync();

      expect(kod, contains('ClassStaffManagerModal.show'),
          reason: 'kadro karti Sinifim sayfasinda olmali');
      expect(kod, contains("'Öğretmen Kadrosu'"));
    });
  });

  group('Toplu duyuru', () {
    test('KRITIK: brans ogretmeni birden fazla sinifa duyuru yapabiliyor', () {
      final kod = File(
        'lib/features/parent_portal/presentation/screens/'
        'bulk_announcement_screen.dart',
      ).readAsStringSync();

      expect(kod, contains('publishAnnouncement'));
      expect(kod, contains('_selected'),
          reason: 'birden fazla sinif secilebilmeli');
      expect(kod, contains('ensureClassRoom'),
          reason: 'sinif odasi yoksa duyuru yazilacak yer olmaz');
    });

    test('KRITIK: kismi basarisizlik gizlenmiyor', () {
      final kod = File(
        'lib/features/parent_portal/presentation/screens/'
        'bulk_announcement_screen.dart',
      ).readAsStringSync();

      // "Gonderildi" deyip bir kisminin basarisiz olmasi, ogretmenin
      // duyurunun ulastigini sanmasina yol acardi.
      expect(kod, contains('basarisiz'));
      expect(kod, contains('gönderilemedi'),
          reason: 'basarisiz sinif sayisi ogretmene soylenmeli');
    });

    test('KRITIK: Sinifim sayfasindan erisilebiliyor', () {
      final kod = File(
        'lib/features/classes/screens/my_class_hub_screen.dart',
      ).readAsStringSync();
      expect(kod, contains('BulkAnnouncementScreen.show'));
    });
  });
}
