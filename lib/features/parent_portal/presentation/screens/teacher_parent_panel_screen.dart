import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/parent_link_model.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_token_provider.dart';
import '../widgets/parent_teacher_chat_modal.dart';
import '../widgets/class_parent_communication_modal.dart';
import '../../data/models/app_notification.dart';
import '../../providers/notification_provider.dart';
import 'notification_center_screen.dart';

/// Öğretmenin veli yönetim paneli.
///
/// Önceden her şey tek bir alt sayfanın (modal) içinde beş sekmedeydi:
/// öğretmen neyin nerede olduğunu göremiyordu. Bu ekran tam sayfadır ve
/// alt barla gezinir; Özet sekmesi "ne olup bitiyor" sorusunu tek bakışta
/// cevaplar.
class TeacherParentPanelScreen extends ConsumerStatefulWidget {
  final ClassModel classModel;

  /// Açılışta gösterilecek sekme (üst bardaki mesaj kısayolu için).
  final TeacherPanelTab initialTab;

  const TeacherParentPanelScreen({
    super.key,
    required this.classModel,
    this.initialTab = TeacherPanelTab.summary,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassModel classModel,
    TeacherPanelTab initialTab = TeacherPanelTab.summary,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherParentPanelScreen(
          classModel: classModel,
          initialTab: initialTab,
        ),
      ),
    );
  }

  @override
  ConsumerState<TeacherParentPanelScreen> createState() =>
      _TeacherParentPanelScreenState();
}

/// Panelin alt bar sekmeleri.
enum TeacherPanelTab {
  summary(label: 'Özet', icon: Icons.dashboard_rounded),
  messages(label: 'Mesajlar', icon: Icons.forum_rounded),
  announcements(label: 'Duyurular', icon: Icons.campaign_rounded),
  parents(label: 'Veliler', icon: Icons.family_restroom_rounded),
  staff(label: 'Kadro', icon: Icons.groups_rounded);

  const TeacherPanelTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _TeacherParentPanelScreenState
    extends ConsumerState<TeacherParentPanelScreen> {
  late TeacherPanelTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              '${widget.classModel.name} Veli Yönetimi',
              style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _tab.label,
              style: AppFonts.outfit(
                fontSize: 11.5,
                color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [_buildNotificationButton(isDark)],
      ),
      body: SafeArea(child: _buildBody(isDark)),
      bottomNavigationBar: _PanelBottomBar(
        current: _tab,
        onSelect: (t) => setState(() => _tab = t),
        isDark: isDark,
      ),
    );
  }

  /// Panel sekmesini gömülü ekranın sekme sırasına çevirir.
  ///
  /// Gömülü ekranın sırası: 0=Duyurular, 1=Mesajlar, 2=Bildirimler,
  /// 3=Randevular, 4=Kadro.
  int _embeddedTabIndex(TeacherPanelTab tab) {
    switch (tab) {
      case TeacherPanelTab.announcements:
        return 0;
      case TeacherPanelTab.parents:
        // "Veliler" sekmesi veli bildirimlerini gösterir.
        return 2;
      case TeacherPanelTab.staff:
        return 4;
      case TeacherPanelTab.summary:
      case TeacherPanelTab.messages:
        return 0;
    }
  }

  /// Bildirim çanı (rozetli).
  Widget _buildNotificationButton(bool isDark) {
    final count = ref
            .watch(teacherUnreadNotificationsProvider(widget.classModel))
            .valueOrNull ??
        0;
    final badge = AppNotification.badgeText(count);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Bildirimler',
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
          onPressed: () async {
            final list = await ref.read(
                teacherNotificationsProvider(widget.classModel).future);
            if (!mounted) return;
            await NotificationCenterScreen.show(
              context,
              notifications: list,
              onRefresh: () async {
                ref.invalidate(
                    teacherNotificationsProvider(widget.classModel));
              },
            );
          },
        ),
        if (badge != null)
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
                badge,
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

  Widget _buildBody(bool isDark) {
    switch (_tab) {
      case TeacherPanelTab.summary:
        return _SummaryTab(
          classModel: widget.classModel,
          onGoTo: (t) => setState(() => _tab = t),
        );
      case TeacherPanelTab.messages:
        return _MessagesTab(classModel: widget.classModel);
      case TeacherPanelTab.announcements:
      case TeacherPanelTab.parents:
      case TeacherPanelTab.staff:
        // Bu üç bölüm mevcut ekranın içinde ÇALIŞIYOR. Kodunu panele
        // kopyalamak yerine gömülü kipte gösteriyoruz: tek kaynak
        // kalır, iki yerde ayrı ayrı bakım yapılmaz.
        //
        // ValueKey sekme değişince TabController'ın yeniden kurulmasını
        // sağlar; aksi hâlde panel sekmesi değişse de içerideki sekme
        // eski konumunda kalırdı.
        return ClassParentCommunicationModal(
          key: ValueKey('embedded_${_tab.name}'),
          classModel: widget.classModel,
          initialTab: _embeddedTabIndex(_tab),
          embedded: true,
        );
    }
  }
}

/// Özet: "ne olup bitiyor" tek bakışta.
class _SummaryTab extends ConsumerWidget {
  final ClassModel classModel;
  final ValueChanged<TeacherPanelTab> onGoTo;

  const _SummaryTab({required this.classModel, required this.onGoTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = ref.watch(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);

    if (!CloudIds.isValidUid(uid)) {
      return const _Info(
        icon: Icons.login_rounded,
        text: 'Veli yönetimi için Google ile giriş yapmanız gerekiyor.',
      );
    }

    final classCloudId = CloudIds.classId(
      teacherUid: uid,
      localClassId: classModel.id ?? 0,
    );
    final parents =
        ref.watch(classLinkedParentsProvider(classModel)).valueOrNull ??
            const <ParentLinkModel>[];
    final reports =
        ref.watch(classStatusReportsCloudProvider(classCloudId)).valueOrNull ??
            const [];
    final appointments =
        ref.watch(classAppointmentsCloudProvider(classCloudId)).valueOrNull ??
            const [];

    final pendingReports =
        reports.where((r) => r.status != 'acknowledged').length;
    final pendingAppointments =
        appointments.where((a) => a.status == 'pending').length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(classLinkedParentsProvider(classModel));
        ref.invalidate(classStatusReportsCloudProvider(classCloudId));
        ref.invalidate(classAppointmentsCloudProvider(classCloudId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Durum',
            style: AppFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.family_restroom_rounded,
                  value: '${parents.length}',
                  label: 'Bağlı Veli',
                  color: AppColors.primary,
                  isDark: isDark,
                  onTap: () => onGoTo(TeacherPanelTab.messages),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.notes_rounded,
                  value: '$pendingReports',
                  label: 'Bekleyen Bildirim',
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  onTap: () => onGoTo(TeacherPanelTab.parents),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.event_available_rounded,
                  value: '$pendingAppointments',
                  label: 'Randevu Talebi',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () => onGoTo(TeacherPanelTab.parents),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.forum_rounded,
                  value: '${parents.length}',
                  label: 'Yazışma',
                  color: const Color(0xFF0EA5E9),
                  isDark: isDark,
                  onTap: () => onGoTo(TeacherPanelTab.messages),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (pendingReports > 0 || pendingAppointments > 0)
            _ActionNeeded(
              reports: pendingReports,
              appointments: pendingAppointments,
              isDark: isDark,
              onTap: () => onGoTo(TeacherPanelTab.parents),
            ),
        ],
      ),
    );
  }
}

/// Öğretmenin mesaj kutusu.
class _MessagesTab extends ConsumerWidget {
  final ClassModel classModel;

  const _MessagesTab({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = ref.watch(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);

    if (!CloudIds.isValidUid(uid)) {
      return const _Info(
        icon: Icons.login_rounded,
        text: 'Mesajlaşma için Google ile giriş yapmanız gerekiyor.',
      );
    }

    final async = ref.watch(classLinkedParentsProvider(classModel));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _Info(
        icon: Icons.cloud_off_rounded,
        text: 'Veli listesi yüklenemedi.',
      ),
      data: (parents) {
        if (parents.isEmpty) {
          return const _Info(
            icon: Icons.forum_outlined,
            text: 'Henüz bağlı veli yok.\nReferans kodlarını dağıttıktan '
                'sonra veliler burada görünecek.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(classLinkedParentsProvider(classModel)),
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: parents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ParentRow(
              link: parents[i],
              uid: uid,
              teacherName: teacher.fullName,
              classModel: classModel,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class _ParentRow extends StatelessWidget {
  final ParentLinkModel link;
  final String uid;
  final String teacherName;
  final ClassModel classModel;
  final bool isDark;

  const _ParentRow({
    required this.link,
    required this.uid,
    required this.teacherName,
    required this.classModel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => ParentTeacherChatModal.show(
          context,
          classCloudId: link.classCloudId.isNotEmpty
              ? link.classCloudId
              : CloudIds.classId(
                  teacherUid: uid,
                  localClassId: classModel.id ?? 0,
                ),
          studentCloudId: link.studentCloudId.isNotEmpty
              ? link.studentCloudId
              : CloudIds.studentId(
                  teacherUid: uid,
                  localStudentId: link.studentId,
                ),
          studentName: link.studentName,
          parentUserId: link.parentUserId,
          selfName: teacherName,
          selfUid: uid,
          asTeacher: true,
          counterpartName: '${link.relation}: ${link.parentName}',
          teacherUid: uid,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  link.studentName.isNotEmpty
                      ? link.studentName.characters.first.toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.studentName,
                      style: AppFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${link.relation}: ${link.parentName}',
                      style: AppFonts.outfit(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 19, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: AppFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                label,
                style: AppFonts.outfit(
                  fontSize: 11.5,
                  color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Şunlar seni bekliyor" şeridi.
class _ActionNeeded extends StatelessWidget {
  final int reports;
  final int appointments;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionNeeded({
    required this.reports,
    required this.appointments,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (reports > 0) parts.add('$reports veli bildirimi');
    if (appointments > 0) parts.add('$appointments randevu talebi');

    return Material(
      color: Colors.orange.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.pending_actions_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  '${parts.join(' ve ')} yanıtınızı bekliyor',
                  style: AppFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.orange.shade700),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelBottomBar extends StatelessWidget {
  final TeacherPanelTab current;
  final ValueChanged<TeacherPanelTab> onSelect;
  final bool isDark;

  const _PanelBottomBar({
    required this.current,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (final tab in TeacherPanelTab.values)
                Expanded(
                  child: InkWell(
                    onTap: () => onSelect(tab),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 21,
                          color: tab == current
                              ? AppColors.primary
                              : (isDark ? Colors.white54 : Colors.black38),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: AppFonts.outfit(
                            fontSize: 10,
                            fontWeight: tab == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: tab == current
                                ? AppColors.primary
                                : (isDark ? Colors.white54 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Info({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 42, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
