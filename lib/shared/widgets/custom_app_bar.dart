import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../features/exam_operations/presentation/views/exam_tracking_view.dart';
import '../../features/exam_operations/providers/exam_tracking_provider.dart';

/// SınıfCepte - Standart Üst Bar (Distinct Top AppBar) Widget'ı
/// Sol üstte: 3 Çizgi Menü + (Özet'te Profil Fotosu / Diğerlerinde Proje Logosu)
/// En sağda: Mesaj Kutusu İkonu + Bildirim İkonu
class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showDrawerButton;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;
  final bool showProfileAvatar; // true ise Profil Fotosu (👤), false ise Proje Logosu (🎓)
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMessageTap;
  final double height;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showDrawerButton = true,
    this.showBackButton,
    this.onBackPressed,
    this.showProfileAvatar = false,
    this.onProfileTap,
    this.onLogoTap,
    this.onNotificationTap,
    this.onMessageTap,
    this.height = kToolbarHeight + 14,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    final bool shouldShowBack = showBackButton ?? canPop;
    final bool shouldShowDrawer = !shouldShowBack && showDrawerButton;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // 1. SOL ALAN (Geri Butonu veya Menü + Avatar)
              leading ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shouldShowBack) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () {
                            if (onBackPressed != null) {
                              onBackPressed!();
                            } else if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.maybePop(context);
                            }
                          },
                          tooltip: 'Geri Dön',
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                      ] else if (shouldShowDrawer) ...[
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            tooltip: 'Menüyü Aç',
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      // Avatar veya Logo
                      InkWell(
                        onTap: showProfileAvatar ? onProfileTap : (onLogoTap ?? (shouldShowBack ? () => Navigator.maybePop(context) : null)),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: showProfileAvatar
                              ? const Text(
                                  '👤',
                                  style: TextStyle(fontSize: 18),
                                )
                              : const Text(
                                  '🎓',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                    ],
                  ),

              const SizedBox(width: 12),

              // 2. ORTA ALAN (Sayfa Başlığı ve Alt Başlık)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 3. SAĞ ALAN (Özel Actions veya Standart Mesaj & Bildirim)
              if (actions != null)
                ...actions!
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mesajlaşma İkonu (💬)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 19),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        tooltip: 'Mesajlar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          try {
                            if (onMessageTap != null) {
                              onMessageTap!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Mesaj Kutusu (Yakında)')),
                              );
                            }
                          } catch (e, stackTrace) {
                            debugPrint('Mesaj ikonu tıklama hatası: $e\n$stackTrace');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bildirim İkonu (🔔)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 19),
                            Positioned(
                              right: 1,
                              top: 1,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        tooltip: 'Bildirimler',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          try {
                            if (onNotificationTap != null) {
                              onNotificationTap!();
                            } else {
                              _showInAppNotificationsModal(context, ref);
                            }
                          } catch (e, stackTrace) {
                            debugPrint('Bildirim ikonu tıklama hatası: $e\n$stackTrace');
                          }
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Uygulama İçi Bildirim Merkezi BottomSheet Modalı
  void _showInAppNotificationsModal(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examState = ref.read(examTrackingProvider);

    // Favori Sınavlar ve Son 24 Saat / Yaklaşan Sınav Bildirimleri
    final notifications = <Map<String, dynamic>>[];

    final now = DateTime.now();

    for (final exam in examState.exams) {
      if (exam.isFavorite && !exam.isPast) {
        // 1. Son Başvuruya 24 Saat Kaldı Uyarısı
        if (exam.applicationDeadline != null &&
            exam.applicationDeadline!.isAfter(now) &&
            exam.applicationDeadline!.difference(now).inHours <= 24) {
          notifications.add({
            'type': 'exam_deadline_24h',
            'title': '⚠️ Son Başvuruya 24 Saat!',
            'subtitle': '📝 "${exam.title}" başvuruları yarın sona eriyor. Başvurunuzu tamamlayınız!',
            'exam': exam,
            'isUrgent': true,
          });
        }

        // 2. Sınav Gününe 24 Saat Kaldı Uyarısı
        if (exam.daysRemaining <= 1) {
          notifications.add({
            'type': 'exam_24h',
            'title': '⏳ Sınava Son 24 Saat!',
            'subtitle': '⭐ "${exam.title}" sınavına 24 saatten az bir süre kaldı.',
            'exam': exam,
            'isUrgent': true,
          });
        } else if (exam.daysRemaining <= 7) {
          notifications.add({
            'type': 'exam_fav',
            'title': '⭐ Favori Sınav Hatırlatması',
            'subtitle': '"${exam.title}" için son ${exam.daysRemaining} gün kaldı.',
            'exam': exam,
            'isUrgent': false,
          });
        }
      }
    }

    // Sistem Duyurusu Örneği
    notifications.add({
      'type': 'system',
      'title': '📢 MEB Resmî Çalışma Takvimi',
      'subtitle': '2026-2027 Eğitim Öğretim Yılı takvimi ve Maarif Modeli kazanımları yayındadır.',
      'isUrgent': false,
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutamaç
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Başlık
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🔔', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'Bildirim Merkezi',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bildirim Kartları
                if (notifications.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 8),
                        Text(
                          'Yeni bildiriminiz bulunmuyor.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = notifications[idx];
                      final isUrgent = item['isUrgent'] == true;
                      final isExam = item['type'].toString().startsWith('exam');

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            if (isExam) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ExamTrackingView()),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? (isDark
                                      ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                                      : const Color(0xFFFEF2F2))
                                  : (isDark
                                      ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                                      : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isUrgent
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: isUrgent
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                                        : AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isUrgent
                                        ? Icons.timer_outlined
                                        : (isExam ? Icons.star_rounded : Icons.info_outline_rounded),
                                    color: isUrgent ? const Color(0xFFDC2626) : AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isUrgent
                                              ? const Color(0xFFDC2626)
                                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['subtitle'] as String,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isExam) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
