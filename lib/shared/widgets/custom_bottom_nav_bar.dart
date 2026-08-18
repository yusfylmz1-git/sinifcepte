import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_fonts.dart';
import '../../../core/theme/app_colors.dart';

/// Navigation Item Model
class NavigationTabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavigationTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// SınıfCepte - Ultra Modern Floating Glassmorphism & Responsive Alt Bar Menü (5 Sekmeli)
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<NavigationTabItem> _tabs = [
    NavigationTabItem(
      label: 'Özet',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    NavigationTabItem(
      label: 'Sınıf',
      icon: Icons.school_outlined,
      activeIcon: Icons.school_rounded,
    ),
    NavigationTabItem(
      label: 'Kazanım',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
    ),
    NavigationTabItem(
      label: 'Ders Prog.',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_month_rounded,
    ),
    NavigationTabItem(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      try {
                        HapticFeedback.lightImpact();
                        onTap(index);
                      } catch (e, stackTrace) {
                        debugPrint('BottomNavBar onTap Hata: $e\n$stackTrace');
                      }
                    },
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animasyonlu İkon ve Arka Plan Pill Indicator
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 12 : 6,
                              vertical: isSelected ? 3.5 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isSelected ? tab.activeIcon : tab.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              size: 21,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Sekme Metni (Taşma Korumalı)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: AppFonts.outfit(
                                fontSize: isSelected ? 10.5 : 10.0,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                letterSpacing: 0.1,
                              ),
                              child: Text(
                                tab.label,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
