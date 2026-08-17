import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../classes/screens/class_list_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../outcomes/presentation/views/weekly_outcomes_view.dart';
import '../../profile/screens/profile_screen.dart';
import '../../schedule/screens/schedule_screen.dart';
import '../providers/navigation_provider.dart';

/// SınıfCepte - Ana Navigasyon Ekranı (5 Sekmeli, Kesintisiz Alt Menü & Çift Geri Çıkış Koruması)
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  DateTime? _lastBackPressTime;

  static const List<Map<String, String>> _tabTitles = [
    {'title': 'SınıfCepte', 'subtitle': 'Genel Özet & İstatistik Paneli'},
    {'title': 'Sınıflarım', 'subtitle': 'Sınıf & Öğrenci Yönetimi'},
    {'title': 'Müfredat & Kazanımlar', 'subtitle': 'MEB Maarif Yıllık Planları'},
    {'title': 'Ders Programı', 'subtitle': 'Haftalık & Günlük Ders Akışı'},
    {'title': 'Profilim', 'subtitle': 'Öğretmen Tercihleri & Ayarlar'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final activeHeader = _tabTitles[currentIndex.clamp(0, _tabTitles.length - 1)];

    // 5 Temel Sekme Listesi (State Koruma İçin IndexedStack)
    final List<Widget> screens = [
      DashboardScreen(
        onNavigateTab: (index) {
          try {
            ref.read(navigationIndexProvider.notifier).state = index;
          } catch (e, stackTrace) {
            debugPrint('Tab navigasyon hatası: $e\n$stackTrace');
          }
        },
      ),
      const ClassListScreen(),
      const WeeklyOutcomesView(),
      const ScheduleScreen(),
      const ProfileScreen(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. Eğer yan sekmelerdeyse (Sınıflar, Kazanımlar, Program, Profil), önce Özet'e dön
        if (currentIndex != 0) {
          try {
            ref.read(navigationIndexProvider.notifier).state = 0;
          } catch (e, stackTrace) {
            debugPrint('PopScope tab geri dönüş hatası: $e\n$stackTrace');
          }
          return;
        }

        // 2. Özet sekmesindeyse (Index 0): Çift tıklama kontrolü (WhatsApp stili)
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Çıkmak için tekrar geri basın',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 85),
            ),
          );
        } else {
          // 2 saniye içinde tekrar basıldı: Uygulamadan güvenle çık
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        extendBody: true,
        drawer: const AppDrawer(),
        // Kazanımlar sekmesi (Index 2) kendi dinamik CustomAppBar'ını (arama, hafta butonu, filtre vb.) yönetir
        appBar: currentIndex == 2
            ? null
            : CustomAppBar(
                title: activeHeader['title']!,
                subtitle: activeHeader['subtitle'],
                showDrawerButton: currentIndex == 0,
                showBackButton: currentIndex != 0,
                onBackPressed: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = 0; // Ana Sayfaya / Özet sekmesine dön
                  } catch (e, stackTrace) {
                    debugPrint('Geri navigasyon hatası: $e\n$stackTrace');
                  }
                },
                showProfileAvatar: currentIndex == 0,
                onProfileTap: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = 4; // Profil sekmesine git
                  } catch (e, stackTrace) {
                    debugPrint('Profil avatar navigasyon hatası: $e\n$stackTrace');
                  }
                },
                onLogoTap: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = 0; // Özet / Ana Sayfaya dön
                  } catch (e, stackTrace) {
                    debugPrint('Logo navigasyon hatası: $e\n$stackTrace');
                  }
                },
              ),
        body: IndexedStack(
          index: currentIndex,
          children: screens,
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: currentIndex,
          onTap: (index) {
            try {
              ref.read(navigationIndexProvider.notifier).state = index;
            } catch (e, stackTrace) {
              debugPrint('Alt Bar sekme değişimi hatası: $e\n$stackTrace');
            }
          },
        ),
      ),
    );
  }
}
