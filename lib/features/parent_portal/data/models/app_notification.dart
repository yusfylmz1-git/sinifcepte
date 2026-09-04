import 'package:flutter/material.dart';

/// Bildirim türü.
enum NotificationKind {
  message(label: 'Mesaj'),
  announcement(label: 'Duyuru'),
  appointment(label: 'Randevu'),
  statusReport(label: 'Bildirim'),
  exam(label: 'Sınav');

  const NotificationKind({required this.label});

  final String label;
}

/// Uygulama içi bildirim.
///
/// ## Neden push değil
/// Gerçek push bildirimi (FCM) Cloud Functions ve Blaze planı gerektirir;
/// projede ikisi de yok. Bu merkez ZATEN ÇEKİLMİŞ verilerden hesaplanır
/// (duyurular, mesajlar, randevular) — ek Firestore okuması doğurmaz.
///
/// Sınırı açıkça bilinsin: telefon kapalıyken bildirim gelmez, kullanıcı
/// uygulamayı açtığında görür.
class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Dokununca gidilecek yer için bağlam (öğrenci, sınıf, öğretmen).
  final String? targetId;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.targetId,
  });

  IconData get icon {
    switch (kind) {
      case NotificationKind.message:
        return Icons.forum_rounded;
      case NotificationKind.announcement:
        return Icons.campaign_rounded;
      case NotificationKind.appointment:
        return Icons.event_available_rounded;
      case NotificationKind.statusReport:
        return Icons.notes_rounded;
      case NotificationKind.exam:
        return Icons.assignment_rounded;
    }
  }

  Color get color {
    switch (kind) {
      case NotificationKind.message:
        return const Color(0xFF6366F1);
      case NotificationKind.announcement:
        return const Color(0xFFF59E0B);
      case NotificationKind.appointment:
        return const Color(0xFF10B981);
      case NotificationKind.statusReport:
        return const Color(0xFF8B5CF6);
      case NotificationKind.exam:
        return const Color(0xFF0EA5E9);
    }
  }

  /// "az önce", "5 dk önce", "3 saat önce", "2 gün önce"
  String relativeTime(DateTime now) {
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inDays < 1) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${(diff.inDays / 7).floor()} hafta önce';
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      targetId: targetId,
    );
  }

  /// Okunmamış bildirim sayısı.
  static int unreadCount(List<AppNotification> list) =>
      list.where((n) => !n.isRead).length;

  /// Rozette gösterilecek metin; sayı yoksa null.
  static String? badgeText(int count) {
    if (count <= 0) return null;
    return count > 99 ? '99+' : '$count';
  }

  /// Okunmamışlar önce, sonra en yeniden eskiye.
  ///
  /// Okunmamışın önceliği bilinçli: kullanıcı listeyi açtığında görmesi
  /// gereken şey en yeni değil, henüz görmediğidir.
  static List<AppNotification> sorted(List<AppNotification> list) {
    final copy = [...list];
    copy.sort((a, b) {
      if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }
}
