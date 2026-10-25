import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/share/incoming_share_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../classes/presentation/views/student_import_preview_view.dart';
import '../../classes/screens/sinifim_sekmesi.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../parent_portal/presentation/screens/gelen_kutusu_ekrani.dart';
import '../../parent_portal/providers/gelen_kutusu_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../schedule/screens/schedule_screen.dart';
import '../providers/navigation_provider.dart';

/// SınıfCepte - Ana Navigasyon Ekranı (4 sekme, çift geri çıkış koruması).
///
/// Sekmeler: Özet · Ders Programı · Sınıfım · Profil ([AnaSekme]).
/// Kullanıcı kararı (26 Ekim 2026): Kazanımlar, Ders İçi Katılım,
/// Rehberlik, Sınıflar, Sınav İşlemleri ve Evraklar Özet'teki düğmelerden
/// açılır. Üç çizgili menü yok.
///
/// Veli gelen kutusu üst çubukta, zilin yanında (okunmamış rozetli).
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

  /// [AnaSekme] sırasıyla. Sınıfım'ın başlığını sınıf sayfası kendisi
  /// verir (sınıf adı, öğrenci ekle, ⋮ menüsü).
  static const List<Map<String, String>> _tabTitles = [
    {'title': 'SınıfCepte', 'subtitle': 'Özet'},
    {'title': 'Ders Programı', 'subtitle': 'Haftalık program, ders saatleri ve PDF'},
    {'title': 'Sınıfım', 'subtitle': 'Rehberlik sınıfım'},
    {'title': 'Profilim', 'subtitle': 'Profil, yedek, ayarlar ve yardım'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final activeHeader = _tabTitles[currentIndex.clamp(0, _tabTitles.length - 1)];

    // Gelen kutusu yalnız bulut varken (Google girişi) görünür; masaüstü
    // yerel kipte simge hiç çıkmaz.
    final gelenKutusu = ref.watch(gelenKutusuProvider).valueOrNull;

    // 4 Temel Sekme Listesi (State Koruma İçin IndexedStack), [AnaSekme] sırasıyla.
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
      const ScheduleScreen(),
      const SinifimSekmesi(),
      const ProfileScreen(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. Eğer yan sekmelerdeyse (Ders Programı, Sınıfım, Profil), önce Özet'e dön
        if (currentIndex != AnaSekme.ozet) {
          try {
            ref.read(navigationIndexProvider.notifier).state = AnaSekme.ozet;
          } catch (e, stackTrace) {
            debugPrint('PopScope tab geri dönüş hatası: $e\n$stackTrace');
          }
          return;
        }

        // 2. Özet sekmesindeyse: Çift tıklama kontrolü (WhatsApp stili)
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
        // Sınıfım sekmesi kendi üst çubuğunu (sınıf adı, öğrenci ekle, ⋮)
        // yönetir.
        appBar: currentIndex == AnaSekme.sinifim
            ? null
            : CustomAppBar(
                title: activeHeader['title']!,
                subtitle: activeHeader['subtitle'],
                showBackButton: currentIndex != AnaSekme.ozet,
                onBackPressed: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = AnaSekme.ozet;
                  } catch (e, stackTrace) {
                    debugPrint('Geri navigasyon hatası: $e\n$stackTrace');
                  }
                },
                showProfileAvatar: currentIndex == AnaSekme.ozet,
                onProfileTap: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = AnaSekme.profil;
                  } catch (e, stackTrace) {
                    debugPrint('Profil avatar navigasyon hatası: $e\n$stackTrace');
                  }
                },
                onLogoTap: () {
                  try {
                    ref.read(navigationIndexProvider.notifier).state = AnaSekme.ozet;
                  } catch (e, stackTrace) {
                    debugPrint('Logo navigasyon hatası: $e\n$stackTrace');
                  }
                },
                onMessageTap: gelenKutusu == null || !gelenKutusu.bulutVar
                    ? null
                    : () => GelenKutusuEkrani.ac(context),
                mesajRozeti: gelenKutusu?.rozet ?? 0,
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
