import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_notification.dart';
import '../data/models/parent_link_model.dart';
import '../data/services/notification_builder.dart';
import 'cloud_communication_provider.dart';
import 'unread_messages_provider.dart';

/// Velinin bildirim listesi.
///
/// Kaynak veriler ekranlar için zaten çekiliyor; bu sağlayıcı yalnızca
/// onları bildirime dönüştürür — ek Firestore okuması yapmaz.
final parentNotificationsProvider =
    FutureProvider.family<List<AppNotification>, List<ParentLinkModel>>(
        (ref, children) async {
  final all = <AppNotification>[];

  for (final child in children) {
    if (!child.hasCloudBinding) continue;

    final announcements =
        await ref.watch(cloudAnnouncementsProvider(child).future);
    final messages = await ref.watch(cloudMessagesProvider(child).future);
    final appointments =
        await ref.watch(cloudAppointmentsProvider(child).future);
    final lastSeen =
        await UnreadMessageTracker.lastSeen(child.studentCloudId);

    all.addAll(NotificationBuilder.forParent(
      announcements: announcements,
      messages: messages,
      appointments: appointments,
      lastSeenMessages: lastSeen,
    ));
  }

  return AppNotification.sorted(all);
});

/// Velinin okunmamış bildirim sayısı (rozet).
final parentUnreadNotificationsProvider =
    FutureProvider.family<int, List<ParentLinkModel>>((ref, children) async {
  final list = await ref.watch(parentNotificationsProvider(children).future);
  return AppNotification.unreadCount(list);
});
