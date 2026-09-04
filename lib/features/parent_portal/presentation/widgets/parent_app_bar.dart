import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// Veli ekranlarının ortak üst barı.
///
/// Sağ üstte bildirim ve mesaj ikonları durur (kullanıcı isteği). Alt
/// barda da mesaj sekmesi var; buradaki kısayol özet ekranından tek
/// dokunuşla yazışmaya geçmeyi sağlar.
class ParentAppBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onOpenNotifications;

  /// Okunmamış bildirim sayısı (0 ise rozet gösterilmez).
  final int notificationCount;

  const ParentAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.onOpenMessages,
    this.onOpenNotifications,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.outfit(
                    fontSize: 12.5,
                    color:
                        isDark ? Colors.white60 : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: AppFonts.outfit(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onOpenNotifications != null)
            _BarIcon(
              icon: Icons.notifications_none_rounded,
              badge: notificationCount,
              isDark: isDark,
              tooltip: 'Bildirimler',
              onTap: onOpenNotifications!,
            ),
          if (onOpenMessages != null)
            _BarIcon(
              icon: Icons.forum_outlined,
              badge: 0,
              isDark: isDark,
              tooltip: 'Mesajlar',
              onTap: onOpenMessages!,
            ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final bool isDark;
  final String tooltip;
  final VoidCallback onTap;

  const _BarIcon({
    required this.icon,
    required this.badge,
    required this.isDark,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          icon: Icon(icon,
              size: 22,
              color: isDark ? Colors.white70 : AppColors.textPrimaryLight),
        ),
        if (badge > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
