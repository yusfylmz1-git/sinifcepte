import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../data/models/parent_link_model.dart';
import '../../data/repositories/cloud_communication_repository.dart';
import '../../data/services/messaging_window.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_token_provider.dart';
import '../../providers/unread_messages_provider.dart';
import '../widgets/parent_app_bar.dart';
import '../widgets/parent_teacher_chat_modal.dart';

/// Mesajlar sekmesi.
///
/// Kullanıcı isteği: "WhatsApp gibi — solda bağlı öğretmenler, sağda
/// mesajlaşma ekranı". Telefonda yan yana iki panel dar kalacağı için
/// geniş ekranda (tablet/yatay) gerçekten iki panel, dar ekranda ise
/// liste + tam ekran sohbet olarak davranır.
class ParentMessagesView extends ConsumerStatefulWidget {
  final List<ParentLinkModel> children;

  const ParentMessagesView({super.key, required this.children});

  @override
  ConsumerState<ParentMessagesView> createState() => _ParentMessagesViewState();
}

class _ParentMessagesViewState extends ConsumerState<ParentMessagesView> {
  late ParentLinkModel _child = widget.children.first;
  CloudStaffMember? _selected;

  @override
  void initState() {
    super.initState();
    _markSeen();
  }

  /// Mesajlar sekmesi acildiginda rozet sifirlanir.
  Future<void> _markSeen() async {
    for (final c in widget.children) {
      await UnreadMessageTracker.markSeen(c.studentCloudId);
    }
    if (mounted) {
      ref.invalidate(unreadMessagesTotalProvider(widget.children));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffAsync = ref.watch(cloudClassStaffProvider(_child));

    return Column(
      children: [
        ParentAppBar(
          title: 'Mesajlar',
          subtitle: _child.studentName,
        ),
        if (widget.children.length > 1)
          _ChildSwitcher(
            children: widget.children,
            selected: _child,
            isDark: isDark,
            onChanged: (c) => setState(() {
              _child = c;
              _selected = null;
            }),
          ),
        Expanded(
          child: staffAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              icon: Icons.cloud_off_rounded,
              text: 'Öğretmen listesi yüklenemedi.\nİnternet bağlantınızı '
                  'kontrol edin.',
            ),
            data: (staff) {
              if (staff.isEmpty) {
                // Boş durumda da aşağı çekilebilmeli: öğretmen kadroya
                // yeni eklendiğinde veli listeyi tazeleyebilsin.
                // Kaydırılabilir bir gövde olmadan RefreshIndicator
                // çalışmaz, bu yüzden ListView içine alınır.
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myConnectedChildrenProvider);
                    ref.invalidate(cloudClassStaffProvider(_child));
                  },
                  child: ListView(
                    children: const [
                      SizedBox(height: 110),
                      _Message(
                        icon: Icons.school_outlined,
                        text: 'Sınıf öğretmeniniz henüz ders öğretmenlerini '
                            'eklememiş.\nEklendiğinde burada görünecekler.',
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  // Geniş ekranda iki panel; dar ekranda tek liste.
                  final wide = constraints.maxWidth >= 720;
                  if (!wide) {
                    return _TeacherList(
                      staff: staff,
                      child: _child,
                      isDark: isDark,
                      selected: null,
                      onTap: (t) => _openChat(t, fullScreen: true),
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: _TeacherList(
                          staff: staff,
                          child: _child,
                          isDark: isDark,
                          selected: _selected,
                          onTap: (t) => setState(() => _selected = t),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: _selected == null
                            ? _Message(
                                icon: Icons.forum_outlined,
                                text: 'Yazışmak istediğiniz öğretmeni '
                                    'soldan seçin.',
                              )
                            : _InlineChat(
                                key: ValueKey(_selected!.teacherUid),
                                child: _child,
                                teacher: _selected!,
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openChat(CloudStaffMember teacher, {bool fullScreen = false}) {
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
      classCloudId: _child.classCloudId,
      studentCloudId: _child.studentCloudId,
      studentName: _child.studentName,
      parentUserId: identity.uid,
      selfName: _child.parentName,
      selfUid: identity.uid,
      asTeacher: false,
      counterpartName: teacher.displayTitle,
      teacherUid: teacher.teacherUid,
      meetingDay: teacher.meetingDay,
      meetingTime: teacher.meetingTime,
    );
  }
}

/// Sol panel: çocuğun dersine giren öğretmenler.
class _TeacherList extends StatelessWidget {
  final List<CloudStaffMember> staff;
  final ParentLinkModel child;
  final bool isDark;
  final CloudStaffMember? selected;
  final ValueChanged<CloudStaffMember> onTap;

  const _TeacherList({
    required this.staff,
    required this.child,
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sınıf öğretmeni en üstte: veli en çok onunla yazışır.
    final sorted = [...staff]..sort((a, b) {
        if (a.isHomeroom != b.isHomeroom) return a.isHomeroom ? -1 : 1;
        return a.teacherName.compareTo(b.teacherName);
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 70,
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      ),
      itemBuilder: (context, i) {
        final t = sorted[i];
        final open = MessagingWindow.isOpen(
          meetingDay: t.meetingDay,
          meetingTime: t.meetingTime,
          now: DateTime.now(),
        );

        return Material(
          color: selected?.teacherUid == t.teacherUid
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          child: ListTile(
            onTap: () => onTap(t),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: t.isHomeroom
                  ? AppColors.primary
                  : const Color(0xFF3B82F6),
              child: Text(
                _initials(t.teacherName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    t.teacherName,
                    style: AppFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (t.isHomeroom) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Sınıf Öğr.',
                      style: AppFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              open
                  ? (t.branch.isEmpty ? 'Yazışmaya açık' : t.branch)
                  : MessagingWindow.closedReason(
                      meetingDay: t.meetingDay,
                      meetingTime: t.meetingTime,
                      now: DateTime.now(),
                    ),
              style: AppFonts.outfit(
                fontSize: 11.5,
                color: open
                    ? (isDark ? Colors.white54 : AppColors.textSecondaryLight)
                    : Colors.orange,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              open ? Icons.chat_bubble_outline_rounded : Icons.schedule_rounded,
              size: 18,
              color: open ? AppColors.primary : Colors.orange,
            ),
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Geniş ekranda sağ panelde gömülü sohbet.
class _InlineChat extends ConsumerWidget {
  final ParentLinkModel child;
  final CloudStaffMember teacher;

  const _InlineChat({super.key, required this.child, required this.teacher});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(parentAuthServiceProvider).currentIdentity;
    if (identity == null) {
      return _Message(
        icon: Icons.login_rounded,
        text: 'Mesajlaşmak için Google ile giriş yapmalısınız.',
      );
    }

    return ParentTeacherChatPanel(
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

/// Birden fazla çocuk varsa üstte çocuk değiştirici.
class _ChildSwitcher extends StatelessWidget {
  final List<ParentLinkModel> children;
  final ParentLinkModel selected;
  final bool isDark;
  final ValueChanged<ParentLinkModel> onChanged;

  const _ChildSwitcher({
    required this.children,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = children[i];
          final active = c.studentCloudId == selected.studentCloudId;
          return ChoiceChip(
            selected: active,
            onSelected: (_) => onChanged(c),
            label: Text(c.studentName),
            labelStyle: AppFonts.outfit(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active
                  ? Colors.white
                  : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
            ),
            selectedColor: AppColors.primary,
            backgroundColor:
                isDark ? AppColors.darkCardBackground : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: active
                    ? AppColors.primary
                    : (isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: isDark ? Colors.white24 : Colors.black26),
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
