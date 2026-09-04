import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/data/services/messaging_window.dart';

/// Mesajlasma saati kisiti testleri.
///
/// Kisit bilincli olarak yalnizca istemcide uygulanir: guvenlik kuralinda
/// saat kontrolu her mesaj basina +1 faturalanan okuma demekti.
void main() {
  // 2026-09-07 Pazartesi.
  DateTime pazartesi(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 7, hour, minute);
  DateTime sali(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 8, hour, minute);

  group('Gun adi', () {
    test('Turkce gun adlari dogru', () {
      expect(MessagingWindow.weekdayName(DateTime(2026, 9, 7)), 'Pazartesi');
      expect(MessagingWindow.weekdayName(DateTime(2026, 9, 8)), 'Salı');
      expect(MessagingWindow.weekdayName(DateTime(2026, 9, 13)), 'Pazar');
    });
  });

  group('Saat araligi ayristirma', () {
    test('Standart bicim okunur', () {
      expect(MessagingWindow.parseRange('13:30 - 14:15'), (810, 855));
    });

    test('Nokta ile yazim da okunur', () {
      expect(MessagingWindow.parseRange('09.00 - 10.00'), (540, 600));
    });

    test('Taninmayan bicim null doner', () {
      expect(MessagingWindow.parseRange(''), isNull);
      expect(MessagingWindow.parseRange('ogleden sonra'), isNull);
      expect(MessagingWindow.parseRange('13:30'), isNull);
    });

    test('Ters aralik reddedilir', () {
      expect(MessagingWindow.parseRange('14:15 - 13:30'), isNull);
    });
  });

  group('Sessiz saat', () {
    test('Sessiz saat basindan sonrasi kapali', () {
      // Sabit saat yazilmaz: sessiz saat 19:00 iken 22:00'ye cekildi
      // (ikili ogretimde ders aksam 19:00'da bitiyor). Test sabite
      // bagli olmali ki bir sonraki degisiklikte de dogru kalsin.
      expect(
        MessagingWindow.isQuietHour(
          pazartesi(MessagingWindow.quietHourStart),
        ),
        isTrue,
      );
      expect(MessagingWindow.isQuietHour(pazartesi(23, 30)), isTrue);
    });

    test('KRITIK: ikili ogretim cikisinda (19:00) mesaj gonderilebilir', () {
      // Aksam 19:00'da okulu biten veli, okul cikisinda ogretmene
      // yazabilmeli. Sessiz saat 19:00 iken bu mumkun degildi.
      expect(MessagingWindow.isQuietHour(pazartesi(19)), isFalse);
      expect(MessagingWindow.isQuietHour(pazartesi(21, 30)), isFalse);
    });

    test('Gece ve sabah 07:00 oncesi kapali', () {
      expect(MessagingWindow.isQuietHour(pazartesi(2)), isTrue);
      expect(MessagingWindow.isQuietHour(pazartesi(6, 59)), isTrue);
    });

    test('Gunduz acik', () {
      expect(MessagingWindow.isQuietHour(pazartesi(7)), isFalse);
      expect(MessagingWindow.isQuietHour(pazartesi(13)), isFalse);
      expect(MessagingWindow.isQuietHour(pazartesi(18, 59)), isFalse);
    });
  });

  group('Gorusme penceresi', () {
    test('KRITIK: dogru gun ve saatte acik', () {
      expect(
        MessagingWindow.isOpen(
          meetingDay: 'Pazartesi',
          meetingTime: '13:30 - 14:15',
          now: pazartesi(13, 45),
        ),
        isTrue,
      );
    });

    test('KRITIK: yanlis gunde kapali', () {
      expect(
        MessagingWindow.isOpen(
          meetingDay: 'Pazartesi',
          meetingTime: '13:30 - 14:15',
          now: sali(13, 45),
        ),
        isFalse,
      );
    });

    test('KRITIK: dogru gun ama saat disinda kapali', () {
      expect(
        MessagingWindow.isOpen(
          meetingDay: 'Pazartesi',
          meetingTime: '13:30 - 14:15',
          now: pazartesi(15),
        ),
        isFalse,
      );
    });

    test('Aralik bitis dakikasi disaridadir', () {
      expect(
        MessagingWindow.isOpen(
          meetingDay: 'Pazartesi',
          meetingTime: '13:30 - 14:15',
          now: pazartesi(14, 15),
        ),
        isFalse,
      );
    });

    test('KRITIK: gorusme saati tanimsizsa kisit yok', () {
      // Sinif ogretmeni saat belirlemediyse mesajlasma serbest olmali;
      // eksik veri yuzunden ogretmene ulasimi kapatmak yanlis olurdu.
      expect(
        MessagingWindow.isOpen(
          meetingDay: '',
          meetingTime: '',
          now: pazartesi(11),
        ),
        isTrue,
      );
    });

    test('Taninmayan saat bicimi kisitlamaz', () {
      expect(
        MessagingWindow.isOpen(
          meetingDay: 'Pazartesi',
          meetingTime: 'ogleden sonra',
          now: pazartesi(11),
        ),
        isTrue,
      );
    });

    test('KRITIK: sessiz saat gorusme gununu de kapatir', () {
      // Gorusme saati aksama denk gelse bile sessiz saat onceliklidir.
      expect(
        MessagingWindow.isOpen(
          meetingDay: 'Pazartesi',
          meetingTime: '22:30 - 23:15',
          now: pazartesi(22, 45),
        ),
        isFalse,
      );
    });

    test('Sessiz saat ogretmen tercihiyle kapatilabilir', () {
      expect(
        MessagingWindow.isOpen(
          meetingDay: 'Pazartesi',
          meetingTime: '22:30 - 23:15',
          now: pazartesi(22, 45),
          enforceQuietHours: false,
        ),
        isTrue,
      );
    });
  });

  group('Kapali aciklamasi', () {
    test('Sessiz saatte dinlenme mesaji verilir', () {
      final reason = MessagingWindow.closedReason(
        meetingDay: 'Pazartesi',
        meetingTime: '13:30 - 14:15',
        now: pazartesi(23),
      );
      expect(reason.toLowerCase(), contains('dinlenme'));
    });

    test('Gun ve saat aciklamada gecer', () {
      final reason = MessagingWindow.closedReason(
        meetingDay: 'Pazartesi',
        meetingTime: '13:30 - 14:15',
        now: sali(13),
      );
      expect(reason, contains('Pazartesi'));
      expect(reason, contains('13:30 - 14:15'));
    });
  });
}
