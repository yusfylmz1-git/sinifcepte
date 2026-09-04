import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/models/parent_link_model.dart';
import '../../data/repositories/cloud_communication_repository.dart';
import '../../data/services/communication_ids.dart';
import '../../data/services/messaging_window.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_token_provider.dart';
import '../widgets/parent_teacher_chat_modal.dart';

/// Bir çocuğun detay ekranı.
///
/// Özet sekmesinde çocuk kartına dokununca açılır. Üç sekme: duyurular,
/// öğretmenler ve durum bildirimleri. Kullanıcı isteği: "üzerine basınca
/// ilgili öğrenci ile alakalı mesajlar, sınav tarihleri, duyurular ve
/// öğretmenleri görebileceği bir ekran".
class ParentChildDetailScreen extends ConsumerStatefulWidget {
  final ParentLinkModel child;

  const ParentChildDetailScreen({super.key, required this.child});

  @override
  ConsumerState<ParentChildDetailScreen> createState() =>
      _ParentChildDetailScreenState();
}

class _ParentChildDetailScreenState
    extends ConsumerState<ParentChildDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child = widget.child;

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
              child.studentName,
              style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${child.className} · ${child.schoolName}',
              style: AppFonts.outfit(
                fontSize: 11.5,
                color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              isDark ? Colors.white54 : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          labelStyle:
              AppFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Duyurular'),
            Tab(text: 'Öğretmenler'),
            Tab(text: 'Bildirimlerim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AnnouncementsTab(child: child),
          _TeachersTab(child: child),
          _ReportsTab(child: child),
        ],
      ),
    );
  }
}

/// Duyurular ve sınav tarihleri.
class _AnnouncementsTab extends ConsumerWidget {
  final ParentLinkModel child;

  const _AnnouncementsTab({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(cloudAnnouncementsProvider(child));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _Empty(
        icon: Icons.cloud_off_rounded,
        text: 'Duyurular yüklenemedi.\nİnternet bağlantınızı kontrol edin.',
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _Empty(
            icon: Icons.campaign_outlined,
            text: 'Henüz duyuru yok.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(cloudAnnouncementsProvider(child)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _AnnouncementCard(
              announcement: list[i],
              child: child,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final CloudAnnouncement announcement;
  final ParentLinkModel child;
  final bool isDark;

  const _AnnouncementCard({
    required this.announcement,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    final days = a.daysUntil;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: a.readByMe
            ? null
            : Border.all(color: a.priorityColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: a.priorityColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(a.priorityIcon, size: 16, color: a.priorityColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a.title,
                  style: AppFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              if (!a.readByMe)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: a.priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            a.content,
            style: AppFonts.outfit(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
            ),
          ),
          if (a.hasDate) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: a.priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 14, color: a.priorityColor),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      AppDateFormatter.formatTurkishDate(a.eventAt!),
                      style: AppFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: a.priorityColor,
                      ),
                    ),
                  ),
                  if (days != null && days >= 0)
                    Text(
                      days == 0
                          ? 'Bugün'
                          : (days == 1 ? 'Yarın' : '$days gün'),
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: a.priorityColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                AppDateFormatter.formatTurkishDate(a.createdAt),
                style: AppFonts.outfit(
                  fontSize: 10.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const Spacer(),
              if (!a.readByMe)
                TextButton(
                  onPressed: () async {
                    final mark = ref.read(markAnnouncementReadProvider);
                    await mark(link: child, announcementId: a.id);
                    ref.invalidate(cloudAnnouncementsProvider(child));
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Okundu',
                      style: AppFonts.outfit(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Çocuğun dersine giren öğretmenler.
class _TeachersTab extends ConsumerWidget {
  final ParentLinkModel child;

  const _TeachersTab({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(cloudClassStaffProvider(child));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _Empty(
        icon: Icons.cloud_off_rounded,
        text: 'Öğretmen listesi yüklenemedi.',
      ),
      data: (staff) {
        if (staff.isEmpty) {
          return const _Empty(
            icon: Icons.school_outlined,
            text: 'Sınıf öğretmeniniz henüz ders öğretmenlerini eklememiş.',
          );
        }

        final sorted = [...staff]..sort((a, b) {
            if (a.isHomeroom != b.isHomeroom) return a.isHomeroom ? -1 : 1;
            return a.teacherName.compareTo(b.teacherName);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final t = sorted[i];
            final open = MessagingWindow.isOpen(
              meetingDay: t.meetingDay,
              meetingTime: t.meetingTime,
              now: DateTime.now(),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardBackground : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: t.isHomeroom
                        ? AppColors.primary
                        : const Color(0xFF3B82F6),
                    child: Icon(
                      t.isHomeroom
                          ? Icons.star_rounded
                          : Icons.person_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.teacherName,
                          style: AppFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.isHomeroom
                              ? 'Sınıf Öğretmeni'
                              : (t.branch.isEmpty ? 'Branş' : t.branch),
                          style: AppFonts.outfit(
                            fontSize: 11.5,
                            color: isDark
                                ? Colors.white54
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        if (t.meetingDay.isNotEmpty ||
                            t.meetingTime.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Görüşme: ${t.meetingDay} ${t.meetingTime}'.trim(),
                            style: AppFonts.outfit(
                              fontSize: 10.5,
                              color: open ? const Color(0xFF10B981) : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _requestAppointment(context, ref, t),
                    icon: const Icon(Icons.event_available_rounded, size: 19),
                    color: const Color(0xFF10B981),
                    tooltip: 'Randevu İste',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => _openChat(context, ref, t),
                    icon: const Icon(Icons.forum_rounded, size: 20),
                    color: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    tooltip: open
                        ? 'Mesaj Gönder'
                        : MessagingWindow.closedReason(
                            meetingDay: t.meetingDay,
                            meetingTime: t.meetingTime,
                            now: DateTime.now(),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Öğretmenden randevu ister.
  ///
  /// Randevu buluta yazılır; öğretmen talebi ancak orada görür. Aynı
  /// öğretmen ve saat diliminde açık bir talep varsa veli önceden
  /// uyarılır — iki veli aynı saate yazılıp öğretmeni ikilemde bırakmasın.
  Future<void> _requestAppointment(
    BuildContext context,
    WidgetRef ref,
    CloudStaffMember teacher,
  ) async {
    final topicCtrl = TextEditingController(
      text: 'Ders gelişimi ve akademik değerlendirme',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${teacher.teacherName} · Randevu',
            style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (teacher.meetingDay.isNotEmpty ||
                teacher.meetingTime.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Görüşme saati: ${teacher.meetingDay} '
                  '${teacher.meetingTime}'.trim(),
                  style: AppFonts.outfit(fontSize: 12.5, color: Colors.grey),
                ),
              ),
            TextField(
              controller: topicCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Görüşme konusu',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Talep Gönder'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(cloudCommunicationRepositoryProvider);
    final appointmentDate = DateTime.now().add(const Duration(days: 2));

    final conflict = await repo.hasAppointmentConflict(
      classCloudId: child.classCloudId,
      teacherName: teacher.teacherName,
      appointmentDate: appointmentDate,
      timeSlot: teacher.meetingTime,
    );

    if (!context.mounted) return;

    if (conflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu saat için başka bir randevu talebi var. Öğretmeninize '
            'mesaj göndererek başka bir saat kararlaştırabilirsiniz.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }

    final ok = await repo.requestAppointment(
      classCloudId: child.classCloudId,
      appointmentId:
          CommunicationIds.appointment(authorUid: child.parentUserId),
      studentCloudId: child.studentCloudId,
      studentName: child.studentName,
      parentUserId: child.parentUserId,
      parentName: child.parentName,
      relation: child.relation,
      teacherName: teacher.teacherName,
      branch: teacher.branch,
      appointmentDate: appointmentDate,
      timeSlot: teacher.meetingTime,
      topic: topicCtrl.text.trim(),
    );

    if (!context.mounted) return;
    if (ok) ref.invalidate(cloudAppointmentsProvider(child));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Randevu talebiniz öğretmene iletildi. Takvim sekmesinden '
                'durumunu takip edebilirsiniz.'
            : 'Randevu talebi gönderilemedi. İnternet bağlantınızı '
                'kontrol edin.'),
        backgroundColor: ok ? const Color(0xFF10B981) : Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _openChat(
    BuildContext context,
    WidgetRef ref,
    CloudStaffMember teacher,
  ) {
    final identity = ref.read(parentAuthServiceProvider).currentIdentity;
    if (identity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj göndermek için Google ile giriş yapmalısınız.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ParentTeacherChatModal.show(
      context,
      classCloudId: child.classCloudId,
      studentCloudId: child.studentCloudId,
      studentName: child.studentName,
      parentUserId: identity.uid,
      selfName: child.parentName,
      selfUid: identity.uid,
      asTeacher: false,
      counterpartName: teacher.displayTitle,
      teacherUid: teacher.teacherUid,
      meetingDay: teacher.meetingDay,
      meetingTime: teacher.meetingTime,
    );
  }
}

/// Velinin öğretmene gönderdiği durum bildirimleri.
class _ReportsTab extends ConsumerWidget {
  final ParentLinkModel child;

  const _ReportsTab({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(cloudStatusReportsProvider(child));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _Empty(
        icon: Icons.cloud_off_rounded,
        text: 'Bildirimler yüklenemedi.',
      ),
      data: (list) {
        if (list.isEmpty) {
          return Column(
            children: [
              const Expanded(
                child: _Empty(
                  icon: Icons.notes_rounded,
                  text: 'Henüz bildirim göndermediniz.\n'
                      '"Bugün erken alınacak" gibi bilgileri buradan '
                      'öğretmene iletebilirsiniz.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _NewReportButton(child: child),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          // İlk sıra "yeni bildirim" düğmesidir.
          itemCount: list.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _NewReportButton(child: child),
              );
            }
            final r = list[i - 1];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardBackground : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.title,
                          style: AppFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (r.status == 'acknowledged'
                                  ? const Color(0xFF10B981)
                                  : Colors.orange)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          r.status == 'acknowledged' ? 'Görüldü' : 'Bekliyor',
                          style: AppFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: r.status == 'acknowledged'
                                ? const Color(0xFF10B981)
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (r.details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      r.details,
                      style: AppFonts.outfit(
                        fontSize: 12.5,
                        height: 1.45,
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Text(
                    AppDateFormatter.formatTurkishDate(r.createdAt),
                    style: AppFonts.outfit(
                      fontSize: 10.5,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Yeni durum bildirimi gönderme düğmesi ve akışı.
///
/// Veli "bugün erken alınacak" gibi geçici bilgileri öğretmene buradan
/// iletir. Bildirimler 30 gün sonra otomatik silinir (KVKK: sınırlı süre).
class _NewReportButton extends ConsumerWidget {
  final ParentLinkModel child;

  const _NewReportButton({required this.child});

  /// Hazır bildirim türleri.
  ///
  /// NOT: "İlaç kullanımı" türü KVKK'daki özel nitelikli veri yükü
  /// nedeniyle bilinçli olarak yoktur (karar: 18 Ağustos 2026).
  static const List<_ReportType> _types = [
    _ReportType('early_leave', 'Erken Alınacak',
        'Öğrencim bugün okuldan erken alınacaktır.',
        Icons.directions_walk_rounded),
    _ReportType('late', 'Geç Kalacak',
        'Öğrencim bugün derse geç kalacaktır.', Icons.schedule_rounded),
    _ReportType('absent', 'Gelemeyecek',
        'Öğrencim bugün okula gelemeyecektir.', Icons.event_busy_rounded),
    _ReportType('note', 'Özel Not', '', Icons.edit_note_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _pickType(context, ref),
        icon: const Icon(Icons.add_comment_rounded, size: 18),
        label: const Text('Öğretmene Bildirim Gönder'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Future<void> _pickType(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showModalBottomSheet<_ReportType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBackground : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ne bildirmek istiyorsunuz?',
                style: AppFonts.outfit(
                    fontSize: 15.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final t in _types)
              ListTile(
                leading: Icon(t.icon, color: const Color(0xFF10B981)),
                title: Text(t.title, style: AppFonts.outfit(fontSize: 14)),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );

    if (picked == null || !context.mounted) return;

    var details = picked.details;
    if (picked.type == 'note') {
      final typed = await _askDetails(context);
      if (typed == null || typed.trim().isEmpty || !context.mounted) return;
      details = typed.trim();
    }

    await _send(context, ref,
        type: picked.type, title: picked.title, details: details);
  }

  Future<String?> _askDetails(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Özel Not'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 300,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Öğretmene iletmek istediğiniz bilgi...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  Future<void> _send(
    BuildContext context,
    WidgetRef ref, {
    required String type,
    required String title,
    required String details,
  }) async {
    final ok = await ref
        .read(cloudCommunicationRepositoryProvider)
        .createStatusReport(
          classCloudId: child.classCloudId,
          reportId:
              CommunicationIds.statusReport(authorUid: child.parentUserId),
          studentCloudId: child.studentCloudId,
          studentName: child.studentName,
          parentUserId: child.parentUserId,
          parentName: child.parentName,
          relation: child.relation,
          type: type,
          title: title,
          details: details,
        );

    if (!context.mounted) return;
    if (ok) ref.invalidate(cloudStatusReportsProvider(child));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Bildiriminiz öğretmene iletildi.'
            : 'Bildirim gönderilemedi. İnternet bağlantınızı kontrol edin.'),
        backgroundColor: ok ? const Color(0xFF10B981) : Colors.orange,
      ),
    );
  }
}

/// Hazır bildirim türü tanımı.
class _ReportType {
  final String type;
  final String title;
  final String details;
  final IconData icon;

  const _ReportType(this.type, this.title, this.details, this.icon);
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

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
