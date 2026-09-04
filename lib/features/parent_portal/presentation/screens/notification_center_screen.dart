import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../data/models/app_notification.dart';

/// Bildirim merkezi.
///
/// Uygulama içi bildirimleri listeler. Gerçek push (FCM) yerine bu yol
/// seçildi: push Cloud Functions ve Blaze planı gerektirirdi. Buradaki
/// liste zaten çekilmiş verilerden üretilir — ek Firestore okuması yok.
class NotificationCenterScreen extends ConsumerWidget {
  final List<AppNotification> notifications;

  /// Bir bildirime dokunulduğunda çağrılır (ilgili ekrana götürmek için).
  final void Function(AppNotification notification)? onTap;

  /// Aşağı çekince yenileme.
  final Future<void> Function()? onRefresh;

  const NotificationCenterScreen({
    super.key,
    required this.notifications,
    this.onTap,
    this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required List<AppNotification> notifications,
    void Function(AppNotification notification)? onTap,
    Future<void> Function()? onRefresh,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          notifications: notifications,
          onTap: onTap,
          onRefresh: onRefresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = AppNotification.unreadCount(notifications);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bildirimler',
              style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              unread > 0 ? '$unread okunmamış' : 'Tümü okundu',
              style: AppFonts.outfit(
                fontSize: 11.5,
                color: unread > 0
                    ? AppColors.primary
                    : (isDark ? Colors.white54 : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
      body: notifications.isEmpty
          ? _buildEmpty(isDark)
          : RefreshIndicator(
              onRefresh: onRefresh ?? () async {},
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _NotificationRow(
                  notification: notifications[i],
                  now: now,
                  isDark: isDark,
                  onTap: onTap,
                ),
              ),
            ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return ListView(
      children: [
        const SizedBox(height: 110),
        Icon(Icons.notifications_none_rounded,
            size: 48, color: isDark ? Colors.white24 : Colors.black26),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Henüz bildirim yok.\nYeni mesaj, duyuru veya randevu '
            'geldiğinde burada görünecek.',
            textAlign: TextAlign.center,
            style: AppFonts.outfit(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final DateTime now;
  final bool isDark;
  final void Function(AppNotification)? onTap;

  const _NotificationRow({
    required this.notification,
    required this.now,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;

    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null ? null : () => onTap!(n),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // Okunmamışlar kenarlıkla ayrılır: renk körlüğünde de
            // ayırt edilebilsin diye yalnızca noktaya güvenilmez.
            border: n.isRead
                ? null
                : Border.all(color: n.color.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: n.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(n.icon, size: 18, color: n.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: AppFonts.outfit(
                              fontSize: 14,
                              fontWeight:
                                  n.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: n.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      style: AppFonts.outfit(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: n.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            n.kind.label,
                            style: AppFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: n.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          n.relativeTime(now),
                          style: AppFonts.outfit(
                            fontSize: 10.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
