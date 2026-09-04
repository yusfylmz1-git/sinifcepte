import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_ids.dart';
import '../../../data/models/class_model.dart';
import '../../auth_profile/data/services/teacher_identity.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../data/models/app_notification.dart';
import '../data/models/parent_link_model.dart';
import '../data/repositories/cloud_communication_repository.dart';
import '../data/services/notification_builder.dart';
import 'cloud_communication_provider.dart';
import 'parent_token_provider.dart';
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

/// Öğretmenin bildirim listesi (tek sınıf için).
final teacherNotificationsProvider =
    FutureProvider.family<List<AppNotification>, ClassModel>(
        (ref, classModel) async {
  final teacher = ref.watch(teacherProfileProvider);
  final uid = TeacherIdentity.resolve(teacher);
  if (!CloudIds.isValidUid(uid)) return const [];

  final classCloudId = CloudIds.classId(
    teacherUid: uid,
    localClassId: classModel.id ?? 0,
  );

  final reports =
      await ref.watch(classStatusReportsCloudProvider(classCloudId).future);
  final appointments =
      await ref.watch(classAppointmentsCloudProvider(classCloudId).future);

  // Mesajlar öğrenci başına çekilir; bağlı veli listesinden gidilir.
  final links = await ref.watch(classLinkedParentsProvider(classModel).future);
  final messages = <CloudMessage>[];
  for (final link in links) {
    if (!link.hasCloudBinding) continue;
    messages.addAll(await ref.watch(cloudMessagesProvider(link).future));
  }

  return NotificationBuilder.forTeacher(
    messages: messages,
    reports: reports,
    appointments: appointments,
    lastSeenMessages: null,
  );
});

/// Velinin okunmamış bildirim sayısı (rozet).
final parentUnreadNotificationsProvider =
    FutureProvider.family<int, List<ParentLinkModel>>((ref, children) async {
  final list = await ref.watch(parentNotificationsProvider(children).future);
  return AppNotification.unreadCount(list);
});

/// Öğretmenin okunmamış bildirim sayısı (rozet).
final teacherUnreadNotificationsProvider =
    FutureProvider.family<int, ClassModel>((ref, classModel) async {
  final list = await ref.watch(teacherNotificationsProvider(classModel).future);
  return AppNotification.unreadCount(list);
});
