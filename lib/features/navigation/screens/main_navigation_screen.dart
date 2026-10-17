import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/share/incoming_share_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../classes/presentation/views/student_import_preview_view.dart';
import '../../classes/screens/class_list_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../documents/presentation/views/evraklar_sekmesi.dart';
import '../../outcomes/presentation/views/weekly_outcomes_view.dart';
import '../../profile/screens/profile_screen.dart';
import '../providers/navigation_provider.dart';

/// SınıfCepte - Ana Navigasyon Ekranı (5 sekme, çift geri çıkış koruması).
///
/// Sekmeler: Bugün · Sınıflar · Kazanımlar · Evraklarım · Ben ([AnaSekme]).
/// Üç çizgili menü yok (17 Ekim 2026): içindeki her şeyin bir sekmede evi
/// var; ana sayfa ve Cepte araması yalnız kısayol verir.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    final shares = IncomingShareService.instance;
    unawaited(shares.attach());
    shares.onNeedOpenPreview = _openSharedImport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      shares.consumePendingIfUnhandled();
    });
  }

  @override
  void dispose() {
    IncomingShareService.instance.onNeedOpenPreview = null;
    super.dispose();
  }

  void _openSharedImport(String path) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentImportPreviewView(initialFilePath: path),
      ),
    );
  }

  static const List<Map<String, String>> _tabTitles = [
    {'title': 'SınıfCepte', 'subtitle': 'Bugün'},
    {'title': 'Sınıflarım', 'subtitle': 'Sınıflar, öğrenciler ve ders programı'},
    {'title': 'Müfredat & Kazanımlar', 'subtitle': 'MEB Maarif Yıllık Planları'},
    {'title': 'Evraklarım', 'subtitle': 'Dosya, plan, sınav ve rehberlik evrakları'},
    {'title': 'Profilim', 'subtitle': 'Profil, yedek, ayarlar ve yardım'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final activeHeader = _tabTitles[currentIndex.clamp(0, _tabTitles.length - 1)];

    // 5 Temel Sekme Listesi (State Koruma İçin IndexedStack), [AnaSekme] sırasıyla.
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
      const EvraklarSekmesi(),
      const ProfileScreen(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. Eğer yan sekmelerdeyse (Sınıflar, Kazanımlar, Evraklar, Ben), önce Bugün'e dön
        if (currentIndex != AnaSekme.bugun) {
          try {
            ref.read(navigationIndexProvider.notifier).state = AnaSekme.bugun;
          } catch (e, stackTrace) {
            debugPrint('PopScope tab geri dönüş hatası: $e\n$stackTrace');
          }
          return;
        }

        // 2. Bugün sekmesindeyse: Çift tıklama kontrolü (WhatsApp stili)
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
        // Kazanımlar sekmesi kendi dinamik CustomAppBar'ını (arama, hafta butonu, filtre vb.) yönetir
        appBar: currentIndex == AnaSekme.kazanimlar
            ? null
            : CustomAppBar(
                title: activeHeader['title']!,
                subtitle: activeHeader['subtitle'],
                showBackButton: currentIndex != AnaSekme.bugun,
                onBackPressed: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = AnaSekme.bugun;
                  } catch (e, stackTrace) {
                    debugPrint('Geri navigasyon hatası: $e\n$stackTrace');
                  }
                },
                showProfileAvatar: currentIndex == AnaSekme.bugun,
                onProfileTap: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = AnaSekme.ben;
                  } catch (e, stackTrace) {
                    debugPrint('Profil avatar navigasyon hatası: $e\n$stackTrace');
                  }
                },
                onLogoTap: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = AnaSekme.bugun;
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
