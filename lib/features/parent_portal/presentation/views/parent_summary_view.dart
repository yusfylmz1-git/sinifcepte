import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../data/models/parent_link_model.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_token_provider.dart';
import '../screens/parent_child_detail_screen.dart';
import '../screens/parent_student_connect_screen.dart';
import '../widgets/parent_app_bar.dart';
import '../../providers/notification_provider.dart';
import '../screens/notification_center_screen.dart';

/// Özet sekmesi: velinin bağlı çocukları kart olarak listelenir.
///
/// Karta dokununca o çocuğun detay ekranı açılır (mesajlar, duyurular,
/// sınavlar, öğretmenler). Tek çocuk varsa kart geniş ve zengin görünür;
/// birden fazlaysa liste hâlinde sıralanır.
class ParentSummaryView extends ConsumerWidget {
  final List<ParentLinkModel> children;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenCalendar;

  const ParentSummaryView({
    super.key,
    required this.children,
    required this.onOpenMessages,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final single = children.length == 1;

    return Column(
      children: [
        ParentAppBar(
          title: 'Merhaba',
          subtitle: children.first.parentName,
          onOpenMessages: onOpenMessages,
          notificationCount:
              ref.watch(parentUnreadNotificationsProvider(children))
                      .valueOrNull ??
                  0,
          onOpenNotifications: () async {
            final list =
                await ref.read(parentNotificationsProvider(children).future);
            if (!context.mounted) return;
            await NotificationCenterScreen.show(
              context,
              notifications: list,
              onRefresh: () async {
                for (final c in children) {
                  ref.invalidate(cloudAnnouncementsProvider(c));
                  ref.invalidate(cloudMessagesProvider(c));
                }
                ref.invalidate(parentNotificationsProvider(children));
              },
            );
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myConnectedChildrenProvider);
              for (final c in children) {
                ref.invalidate(cloudAnnouncementsProvider(c));
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  single ? 'Çocuğum' : 'Çocuklarım (${children.length})',
                  style: AppFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ChildCard(
                      child: child,
                      expanded: single,
                      isDark: isDark,
                    ),
                  ),
                const SizedBox(height: 4),
                _AddChildTile(isDark: isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tek bir çocuğun özet kartı.
class _ChildCard extends ConsumerWidget {
  final ParentLinkModel child;
  final bool expanded;
  final bool isDark;

  const _ChildCard({
    required this.child,
    required this.expanded,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annAsync = ref.watch(cloudAnnouncementsProvider(child));
    final announcements = annAsync.valueOrNull ?? const [];
    final unread = announcements.where((a) => !a.readByMe).length;
    final nextExam = announcements
        .where((a) => a.isUpcoming)
        .toList()
      ..sort((a, b) => a.eventAt!.compareTo(b.eventAt!));

    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParentChildDetailScreen(child: child),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(name: child.studentName, expanded: expanded),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.studentName,
                          style: AppFonts.outfit(
                            fontSize: expanded ? 17 : 15,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${child.className} · ${child.schoolName}',
                          style: AppFonts.outfit(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$unread yeni',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.black26),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.campaign_rounded,
                      label: 'Duyuru',
                      value: '${announcements.length}',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                    _MiniStat(
                      icon: Icons.assignment_rounded,
                      label: 'Yaklaşan',
                      value: '${nextExam.length}',
                      color: const Color(0xFF0EA5E9),
                      isDark: isDark,
                    ),
                    _MiniStat(
                      icon: Icons.mark_email_unread_rounded,
                      label: 'Okunmamış',
                      value: '$unread',
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
              if (nextExam.isNotEmpty) ...[
                const SizedBox(height: 12),
                _NextEventStrip(
                  title: nextExam.first.title,
                  daysUntil: nextExam.first.daysUntil ?? 0,
                  isExam: nextExam.first.isExam,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool expanded;

  const _Avatar({required this.name, required this.expanded});

  /// Ad ve soyadın baş harfleri; tek kelimeyse ilk harf.
  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = expanded ? 52.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: AppFonts.outfit(
          fontSize: expanded ? 18 : 15,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          Text(
            label,
            style: AppFonts.outfit(
              fontSize: 10.5,
              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// "3 gün sonra: Matematik Yazılı" şeridi.
class _NextEventStrip extends StatelessWidget {
  final String title;
  final int daysUntil;
  final bool isExam;

  const _NextEventStrip({
    required this.title,
    required this.daysUntil,
    required this.isExam,
  });

  String get _when {
    if (daysUntil <= 0) return 'Bugün';
    if (daysUntil == 1) return 'Yarın';
    return '$daysUntil gün sonra';
  }

  @override
  Widget build(BuildContext context) {
    final color =
        isExam ? const Color(0xFF0EA5E9) : const Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(isExam ? Icons.assignment_rounded : Icons.event_rounded,
              size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppFonts.outfit(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _when,
            style: AppFonts.outfit(
                fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// "Başka çocuk ekle" satırı.
class _AddChildTile extends ConsumerWidget {
  final bool isDark;

  const _AddChildTile({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ParentStudentConnectScreen(),
            ),
          );
          ref.invalidate(myConnectedChildrenProvider);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Başka bir çocuk ekle',
                style: AppFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
