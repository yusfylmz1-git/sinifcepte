import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/models/parent_link_model.dart';
import '../../data/repositories/cloud_communication_repository.dart';
import '../../providers/cloud_communication_provider.dart';
import '../widgets/parent_app_bar.dart';

/// Takvim sekmesi: sınavlar, etkinlikler ve randevular tek listede.
///
/// Sınav takvimi için ayrı bir bulut koleksiyonu açılmadı (kullanıcı
/// kararı): öğretmen sınavı duyuru olarak yayımlar, burada yalnızca
/// görünümü farklıdır. Böylece ek okuma/yazma maliyeti doğmaz.
class ParentCalendarView extends ConsumerWidget {
  final List<ParentLinkModel> children;

  const ParentCalendarView({super.key, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tüm çocukların tarihli duyurularını birleştir.
    final items = <_CalendarItem>[];
    for (final child in children) {
      final anns =
          ref.watch(cloudAnnouncementsProvider(child)).valueOrNull ?? const [];
      for (final a in anns.where((a) => a.hasDate)) {
        items.add(_CalendarItem.fromAnnouncement(a, child));
      }

      final apps =
          ref.watch(cloudAppointmentsProvider(child)).valueOrNull ?? const [];
      for (final ap in apps) {
        items.add(_CalendarItem.fromAppointment(ap, child));
      }
    }

    items.sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();
    final upcoming = items.where((i) => !i.date.isBefore(now)).toList();
    final past = items.where((i) => i.date.isBefore(now)).toList().reversed
        .toList();

    return Column(
      children: [
        const ParentAppBar(title: 'Takvim', subtitle: 'Sınav ve Etkinlikler'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              for (final c in children) {
                ref.invalidate(cloudAnnouncementsProvider(c));
                ref.invalidate(cloudAppointmentsProvider(c));
              }
            },
            child: items.isEmpty
                ? _EmptyCalendar(isDark: isDark)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _SectionTitle(
                            text: 'Yaklaşanlar (${upcoming.length})',
                            isDark: isDark),
                        for (final item in upcoming)
                          _CalendarTile(
                            item: item,
                            isDark: isDark,
                            showChild: children.length > 1,
                          ),
                      ],
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _SectionTitle(text: 'Geçmiş', isDark: isDark),
                        for (final item in past.take(20))
                          Opacity(
                            opacity: 0.55,
                            child: _CalendarTile(
                              item: item,
                              isDark: isDark,
                              showChild: children.length > 1,
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Takvimde gösterilen tek bir öge (duyuru ya da randevu).
class _CalendarItem {
  final String title;
  final String subtitle;
  final DateTime date;
  final String childName;
  final IconData icon;
  final Color color;
  final String? badge;

  const _CalendarItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.childName,
    required this.icon,
    required this.color,
    this.badge,
  });

  factory _CalendarItem.fromAnnouncement(
    CloudAnnouncement a,
    ParentLinkModel child,
  ) {
    return _CalendarItem(
      title: a.title,
      subtitle: a.content,
      date: a.eventAt!,
      childName: child.studentName,
      icon: a.priorityIcon,
      color: a.priorityColor,
      badge: a.isExam ? 'Sınav' : (a.isEvent ? 'Etkinlik' : null),
    );
  }

  factory _CalendarItem.fromAppointment(
    CloudAppointment ap,
    ParentLinkModel child,
  ) {
    return _CalendarItem(
      title: '${ap.teacherName} ile görüşme',
      subtitle: ap.topic,
      date: ap.appointmentDate,
      childName: child.studentName,
      icon: Icons.event_available_rounded,
      color: const Color(0xFF10B981),
      badge: _appointmentLabel(ap.status),
    );
  }

  static String _appointmentLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'cancelled':
        return 'İptal';
      case 'completed':
        return 'Tamamlandı';
      default:
        return 'Bekliyor';
    }
  }
}

class _CalendarTile extends StatelessWidget {
  final _CalendarItem item;
  final bool isDark;
  final bool showChild;

  const _CalendarTile({
    required this.item,
    required this.isDark,
    required this.showChild,
  });

  String get _relative {
    final now = DateTime.now();
    final target = DateTime(item.date.year, item.date.month, item.date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    if (diff > 1) return '$diff gün sonra';
    if (diff == -1) return 'Dün';
    return '${-diff} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border(
          left: BorderSide(color: item.color, width: 3.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: item.color),
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
                        item.title,
                        style: AppFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          item.badge!,
                          style: AppFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: item.color,
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: AppFonts.outfit(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark
                          ? Colors.white60
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 12,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      '${AppDateFormatter.formatTurkishDate(item.date)} · $_relative',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.color,
                      ),
                    ),
                    if (showChild) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '· ${item.childName}',
                          style: AppFonts.outfit(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionTitle({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Text(
        text,
        style: AppFonts.outfit(
          fontSize: 14.5,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
        ),
      ),
    );
  }
}

class _EmptyCalendar extends StatelessWidget {
  final bool isDark;

  const _EmptyCalendar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 90),
        Icon(Icons.event_note_outlined,
            size: 46, color: isDark ? Colors.white24 : Colors.black26),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Henüz takvimde bir şey yok.\nÖğretmen sınav veya etkinlik '
            'duyurusu yaptığında burada görünecek.',
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
