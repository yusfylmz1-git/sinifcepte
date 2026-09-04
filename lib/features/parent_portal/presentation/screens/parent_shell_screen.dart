import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../auth/screens/welcome_screen.dart';
import '../../data/models/parent_link_model.dart';
import '../../providers/parent_token_provider.dart';
import '../../providers/unread_messages_provider.dart';
import '../parent_shell_tab.dart';
import '../views/parent_calendar_view.dart';
import '../views/parent_messages_view.dart';
import '../views/parent_profile_view.dart';
import '../views/parent_summary_view.dart';
import 'parent_student_connect_screen.dart';
import '../../data/models/parent_token_model.dart';
import '../../providers/cloud_communication_provider.dart';
import 'parent_onboarding_screen.dart';

/// Velinin ana ekranı: alt bar + dört sekme.
///
/// Önceki tasarım tek bir 2275 satırlık ekrandı; çocuk seçimi üstteki
/// sekmelerdeydi ve mesajlaşmaya ulaşmak modül ızgarasından geçiyordu.
/// Yeni yapıda her sekme kendi dosyasında durur ve mesajlaşma tek
/// dokunuş uzaktadır.
class ParentShellScreen extends ConsumerStatefulWidget {
  const ParentShellScreen({super.key});

  @override
  ConsumerState<ParentShellScreen> createState() => _ParentShellScreenState();
}

class _ParentShellScreenState extends ConsumerState<ParentShellScreen> {
  ParentShellTab _tab = ParentShellTab.summary;
  DateTime? _lastBackPress;
  bool _repairAttempted = false;

  @override
  void initState() {
    super.initState();
    _repairCloudBindings();
    _showOnboardingIfNeeded();
  }

  /// İlk açılışta kısa tanıtımı gösterir.
  ///
  /// Veli daha önce hiçbir yönlendirme almadan uygulamaya giriyordu;
  /// çalışan özellikler (randevu talebi gibi) görünmez kalıyordu.
  ///
  /// İlk kareden sonra açılır: `initState` içinde doğrudan gezinmek
  /// ekran henüz kurulmadığı için hata verir.
  Future<void> _showOnboardingIfNeeded() async {
    if (!await ParentOnboardingScreen.shouldShow()) return;
    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ParentOnboardingScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Bulut kimlikleri eksik bağları onarır.
  ///
  /// `classCloudId` / `studentCloudId` alanları sonradan eklendiği için
  /// daha önce kurulmuş bağlarda boştur. Boş oldukları sürece velinin
  /// duyuru, kadro ve mesaj sorguları sunucuya hiç gitmez ve ekranda
  /// "öğretmen eklenmemiş" yazar.
  ///
  /// Öğretmen kimliği buluttaki token kaydından okunur; oturum başına
  /// bir kez denenir.
  Future<void> _repairCloudBindings() async {
    if (_repairAttempted) return;
    _repairAttempted = true;

    try {
      final repo = ref.read(parentTokenRepositoryProvider);
      final cloud = ref.read(cloudTokenRepositoryProvider);

      final repaired = await repo.repairMissingCloudIds(
        teacherUidResolver: (link) async {
          if (link.linkedViaTokenCode.isEmpty) return '';
          final lookup = await cloud.lookupByCodeHash(
            ParentTokenModel.generateSha256(link.linkedViaTokenCode),
          );
          return lookup.teacherUid ?? '';
        },
      );

      if (repaired > 0 && mounted) {
        ref.invalidate(myConnectedChildrenProvider);
      }

      // Bulut erişim kayıtlarını garanti et.
      //
      // Kural motoru duyuru ve mesaj okumasını `parent_links` +
      // `parent_class_access` dokümanlarının VARLIĞINA bağlar. Bağ yerel
      // yoldan kurulduğunda bu kayıtlar hiç yazılmıyor ve her sorgu
      // PERMISSION_DENIED ile düşüyordu — ekran sessizce boş kalıyor,
      // hata yalnızca logda görünüyordu.
      final children = await ref.read(myConnectedChildrenProvider.future);
      for (final child in children) {
        if (!child.hasCloudBinding) continue;
        await cloud.ensureParentAccess(
          parentUid: child.parentUserId,
          parentName: child.parentName,
          relation: child.relation,
          studentCloudId: child.studentCloudId,
          classCloudId: child.classCloudId,
          studentName: child.studentName,
          studentNumber: child.studentNumber,
          className: child.className,
          schoolId: child.schoolId,
          schoolName: child.schoolName,
          teacherUid: child.teacherUid,
          // Bağın dayandığı referans kodunun hash'i. Kural motoru
          // kodun gerçekten var olduğunu bununla doğrular.
          codeHash: ParentTokenModel.generateSha256(child.linkedViaTokenCode),
        );
      }

      if (mounted && children.isNotEmpty) {
        // Erişim açıldıktan sonra sorgular yeniden denensin.
        for (final child in children) {
          ref.invalidate(cloudAnnouncementsProvider(child));
          ref.invalidate(cloudClassStaffProvider(child));
        }
      }
    } catch (e, stackTrace) {
      // Onarım başarısız olursa akış bozulmaz; veli yeniden bağlanabilir.
      debugPrint('Bağ onarımı hatası: $e\n$stackTrace');
    }
  }

  void _goTo(ParentShellTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final childrenAsync = ref.watch(myConnectedChildrenProvider);
    final children = childrenAsync.valueOrNull ?? const <ParentLinkModel>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // Özet dışındaki sekmelerde geri tuşu önce Özet'e döner.
        if (_tab != ParentShellTab.summary) {
          _goTo(ParentShellTab.summary);
          return;
        }

        if (children.isEmpty) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
          return;
        }

        // Çift dokunuşla çıkış: tek dokunuşta kapanmak, yanlışlıkla
        // basıldığında uygulamayı kapatıyordu.
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(
              content: Text('Çıkmak için tekrar geri tuşuna basın'),
              duration: Duration(seconds: 2),
            ));
          return;
        }
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
        body: SafeArea(
          bottom: false,
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(message: '$e'),
            data: (list) => list.isEmpty
                ? _EmptyChildrenState(isDark: isDark)
                : _buildTab(list, isDark),
          ),
        ),
        bottomNavigationBar: children.isEmpty
            ? null
            : _ParentBottomBar(
                current: _tab,
                onSelect: _goTo,
                // Sayac ek Firestore okumasi yapmaz: mesajlar zaten
                // cekiliyor, son goruntuleme zamani cihazda tutuluyor.
                unreadMessages: ref
                        .watch(unreadMessagesTotalProvider(children))
                        .valueOrNull ??
                    0,
                isDark: isDark,
              ),
      ),
    );
  }

  Widget _buildTab(List<ParentLinkModel> children, bool isDark) {
    switch (_tab) {
      case ParentShellTab.summary:
        return ParentSummaryView(
          children: children,
          onOpenMessages: () => _goTo(ParentShellTab.messages),
          onOpenCalendar: () => _goTo(ParentShellTab.calendar),
        );
      case ParentShellTab.messages:
        return ParentMessagesView(children: children);
      case ParentShellTab.calendar:
        return ParentCalendarView(children: children);
      case ParentShellTab.profile:
        return ParentProfileView(children: children);
    }
  }
}

/// Alt gezinme çubuğu.
class _ParentBottomBar extends StatelessWidget {
  final ParentShellTab current;
  final ValueChanged<ParentShellTab> onSelect;
  final int unreadMessages;
  final bool isDark;

  const _ParentBottomBar({
    required this.current,
    required this.onSelect,
    required this.unreadMessages,
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
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final tab in ParentShellTab.values)
                Expanded(
                  child: _BarItem(
                    tab: tab,
                    selected: tab == current,
                    badge: tab == ParentShellTab.messages
                        ? ParentShellTab.badgeText(unreadMessages)
                        : null,
                    isDark: isDark,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final ParentShellTab tab;
  final bool selected;
  final String? badge;
  final bool isDark;
  final VoidCallback onTap;

  const _BarItem({
    required this.tab,
    required this.selected,
    required this.badge,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : (isDark ? Colors.white54 : const Color(0xFF94A3B8));

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(selected ? tab.activeIcon : tab.icon, size: 23, color: color),
              if (badge != null)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            tab.label,
            style: AppFonts.outfit(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hiç çocuk bağlı değilken gösterilen ekran.
///
/// Kullanıcı kararı: öğrenci yoksa doğrudan referans kodu ekranına
/// yönlendir — boş bir panel göstermek anlamsızdır.
class _EmptyChildrenState extends ConsumerWidget {
  final bool isDark;

  const _EmptyChildrenState({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.family_restroom_rounded,
                  size: 46, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text(
              'Çocuğunuzu Bağlayın',
              style: AppFonts.outfit(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sınıf öğretmeninizin verdiği referans kodunu girerek '
              'çocuğunuzun duyurularını, sınav tarihlerini ve '
              'öğretmenleriyle yazışmayı tek yerden takip edin.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 13.5,
                height: 1.55,
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ParentStudentConnectScreen(),
                    ),
                  );
                  ref.invalidate(myConnectedChildrenProvider);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Referans Kodu Gir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.orange),
            const SizedBox(height: 14),
            Text(
              'Bilgiler yüklenemedi. İnternet bağlantınızı kontrol edin.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
