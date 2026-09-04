import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/parent_link_model.dart';
import 'cloud_communication_provider.dart';

/// Velinin okunmamış mesaj sayısı (alt bar rozeti).
///
/// ## Maliyet
/// Bu sayaç Firestore'a EK OKUMA YAPMAZ. Sohbet başına "okundu" dokümanı
/// tutmak (duyurulardaki gibi) her öğretmen için ayrı bir okuma demekti;
/// rozet gibi ikincil bir bilgi için bu takas yanlış olurdu.
///
/// Bunun yerine: son görüntüleme zamanı cihazda saklanır ve mesaj
/// listesi zaten çekilmişken o zamandan sonra gelen, öğretmenden gelmiş
/// mesajlar sayılır. Sayaç cihaza özeldir (aynı veli iki telefonda
/// kullanırsa her cihaz kendi rozetini gösterir) — rozet için kabul
/// edilebilir bir sınır.
class UnreadMessageTracker {
  const UnreadMessageTracker._();

  static const String _prefix = 'msg_seen_';

  static String _key(String studentCloudId) => '$_prefix$studentCloudId';

  /// Bu çocuğun mesajlarının en son ne zaman görüntülendiği.
  static Future<DateTime?> lastSeen(String studentCloudId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(studentCloudId));
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Sohbet açıldığında çağrılır: rozet sıfırlanır.
  static Future<void> markSeen(String studentCloudId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(studentCloudId),
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Rozet ikincil bilgidir; yazılamaması akışı bozmaz.
    }
  }
}

/// Tek bir çocuk için okunmamış mesaj sayısı.
final unreadMessagesForChildProvider =
    FutureProvider.family<int, ParentLinkModel>((ref, link) async {
  if (!link.hasCloudBinding) return 0;

  // Mesajlar zaten bu provider ile çekiliyor; ek istek yapılmaz.
  final messages = await ref.watch(cloudMessagesProvider(link).future);
  if (messages.isEmpty) return 0;

  final seen = await UnreadMessageTracker.lastSeen(link.studentCloudId);

  return messages.where((m) {
    // Velinin kendi gönderdiği mesaj okunmamış sayılmaz.
    if (!m.isFromTeacher) return false;
    if (seen == null) return true;
    return m.createdAt.isAfter(seen);
  }).length;
});

/// Tüm çocuklar için toplam okunmamış mesaj sayısı (alt bar rozeti).
final unreadMessagesTotalProvider =
    FutureProvider.family<int, List<ParentLinkModel>>((ref, children) async {
  var total = 0;
  for (final child in children) {
    total += await ref.watch(unreadMessagesForChildProvider(child).future);
  }
  return total;
});
