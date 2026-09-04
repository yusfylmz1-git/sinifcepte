import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/data/models/app_notification.dart';

/// Uygulama ici bildirim merkezi.
///
/// Karar (30 Agustos 2026): gercek push (FCM) yerine uygulama ici merkez.
/// Push icin Cloud Functions ve Blaze plani gerekirdi; bu merkez ise
/// ZATEN CEKILMIS verilerden hesaplanir — ek Firestore okumasi yoktur.
void main() {
  final simdi = DateTime(2026, 8, 30, 15, 0);

  AppNotification bildirim({
    NotificationKind kind = NotificationKind.message,
    bool read = false,
    DateTime? at,
  }) {
    return AppNotification(
      id: 'n1',
      kind: kind,
      title: 'Baslik',
      body: 'Icerik',
      createdAt: at ?? simdi,
      isRead: read,
    );
  }

  group('Rozet sayimi', () {
    test('KRITIK: yalnizca okunmamislar sayilir', () {
      final liste = [
        bildirim(read: false),
        bildirim(read: false),
        bildirim(read: true),
      ];

      expect(AppNotification.unreadCount(liste), 2);
    });

    test('Bos listede rozet gorunmez', () {
      expect(AppNotification.unreadCount(const []), 0);
    });

    test('KRITIK: buyuk sayilar rozeti tasirmaz', () {
      expect(AppNotification.badgeText(0), isNull);
      expect(AppNotification.badgeText(5), '5');
      expect(AppNotification.badgeText(120), '99+');
    });
  });

  group('Siralama', () {
    test('KRITIK: en yeni bildirim ustte', () {
      final liste = [
        bildirim(at: DateTime(2026, 8, 28)),
        bildirim(at: DateTime(2026, 8, 30)),
        bildirim(at: DateTime(2026, 8, 29)),
      ];

      final sirali = AppNotification.sorted(liste);
      expect(sirali.first.createdAt, DateTime(2026, 8, 30));
      expect(sirali.last.createdAt, DateTime(2026, 8, 28));
    });

    test('Okunmamislar okunmuslardan once gelir', () {
      final liste = [
        bildirim(read: true, at: DateTime(2026, 8, 30)),
        bildirim(read: false, at: DateTime(2026, 8, 28)),
      ];

      final sirali = AppNotification.sorted(liste);
      expect(sirali.first.isRead, isFalse,
          reason: 'Okunmamis bildirim eski olsa da once gorunmeli');
    });
  });

  group('Bildirim turleri', () {
    test('Her turun ikonu ve rengi vardir', () {
      for (final kind in NotificationKind.values) {
        final n = bildirim(kind: kind);
        expect(n.icon, isNotNull);
        expect(n.color, isNotNull);
        expect(kind.label, isNotEmpty);
      }
    });

    test('Turler ayirt edilir', () {
      expect(bildirim(kind: NotificationKind.message).kind,
          isNot(bildirim(kind: NotificationKind.announcement).kind));
    });
  });

  group('Goreceli zaman', () {
    test('Dakika, saat ve gun dogru yazilir', () {
      expect(
        bildirim(at: simdi.subtract(const Duration(minutes: 5)))
            .relativeTime(simdi),
        '5 dk önce',
      );
      expect(
        bildirim(at: simdi.subtract(const Duration(hours: 3)))
            .relativeTime(simdi),
        '3 saat önce',
      );
      expect(
        bildirim(at: simdi.subtract(const Duration(days: 2)))
            .relativeTime(simdi),
        '2 gün önce',
      );
    });

    test('Cok yeni bildirim "az önce" der', () {
      expect(
        bildirim(at: simdi.subtract(const Duration(seconds: 20)))
            .relativeTime(simdi),
        'az önce',
      );
    });
  });
}
