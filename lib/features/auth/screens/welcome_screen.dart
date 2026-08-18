import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth_profile/data/services/teacher_auth_service.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../auth_profile/providers/user_role_provider.dart';
import '../../auth_profile/presentation/views/school_bind_gate.dart';
import '../../parent_portal/data/services/parent_auth_service.dart';
import '../../parent_portal/presentation/screens/parent_dashboard_screen.dart';
import '../../parent_portal/providers/parent_token_provider.dart';

/// SınıfCepte - Rol Seçim & Giriş Ekranı (Öğretmen / Veli)
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _hasCheckedSavedRole = false;
  bool _teacherSigningIn = false;
  bool _parentSigningIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoLogin();
    });
  }

  /// Eğer önceden rol seçildiyse doğrudan ilgili panele geçiş yap.
  ///
  /// Firebase oturumunun varlığı **rolü belirlemez**: hem öğretmen hem veli
  /// aynı Google sağlayıcısıyla giriş yapar. Rol, kullanıcının daha önce
  /// kaydettiği tercihten okunur; tercih yoksa karşılama ekranında kalınır.
  Future<void> _checkAutoLogin() async {
    if (_hasCheckedSavedRole) return;
    _hasCheckedSavedRole = true;

    // Kaydedilmiş rol tercihi henüz yüklenmemiş olabilir.
    await ref.read(userRoleProvider.notifier).loadRole();
    if (!mounted) return;

    final roleState = ref.read(userRoleProvider);
    if (!roleState.hasSelectedRole) return;

    await FirebaseBootstrap.ensureInitialized();
    if (!mounted) return;

    final signedIn =
        FirebaseBootstrap.ready && FirebaseAuth.instance.currentUser != null;

    if (roleState.isTeacher) {
      if (signedIn) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await DatabaseHelper.instance.openForUid(uid);
        await ref.read(teacherProfileProvider.notifier).ensureLoaded();
        // Yönetici yetkisi yalnızca sunucudaki claim'den okunur.
        await ref.read(userRoleProvider.notifier).refreshClaims();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SchoolBindGate()),
      );
      return;
    }

    if (roleState.isParent) {
      // Veli oturumu düşmüşse karşılama ekranında kalıp yeniden giriş ister:
      // bulut bağlantısı olmadan çocuk verisi getirilemez.
      if (!signedIn) return;

      final repo = ref.read(parentTokenRepositoryProvider);
      final children = await repo.getMyConnectedChildren();
      if (!mounted) return;

      if (children.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
        );
      }
    }
  }

  /// Öğretmen Olarak Giriş Yap
  Future<void> _handleTeacherLogin(BuildContext context) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Öğretmen Google girişi Android / iOS uygulamasında yapılır.'),
        ),
      );
      return;
    }

    setState(() => _teacherSigningIn = true);
    try {
      await FirebaseBootstrap.ensureInitialized();
      var switchedAccount = false;
      if (FirebaseBootstrap.ready) {
        final result = await TeacherAuthService().signInWithGoogle(
          profileNotifier: ref.read(teacherProfileProvider.notifier),
          current: ref.read(teacherProfileProvider),
        );
        switchedAccount = result.switchedAccount;
      }
      await ref.read(userRoleProvider.notifier).selectTeacherRole();
      // Okul yöneticisi yetkisi varsa claim'den okunur (opsiyonel rol).
      await ref.read(userRoleProvider.notifier).refreshClaims(forceRefresh: true);
      // Hesap değiştiyse kullanıcıyı bilgilendir: her hesabın verisi
      // ayrıdır ve bu bilinçli bir tasarımdır. Sessizce boş sınıf listesi
      // göstermek "verilerim silindi" endişesi yaratıyordu.
      if (switchedAccount && context.mounted) {
        await _showAccountSwitchNotice(context);
      }

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SchoolBindGate()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Öğretmen Google girişi hatası: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('TeacherAuthException: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _teacherSigningIn = false);
    }
  }

  /// Hesap değişikliğini açıklayan bilgilendirme.
  ///
  /// Öğrenci ve sınıf verileri gizlilik gereği buluta gönderilmez; her
  /// Google hesabı kendi çalışma alanına sahiptir (Karar: Seçenek A).
  /// Kullanıcı bunu bilmezse verilerinin kaybolduğunu sanar.
  Future<void> _showAccountSwitchNotice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.switch_account_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Farklı hesapla giriş yaptınız',
                style: AppFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sınıf ve öğrenci bilgileriniz gizlilik gereği internete '
              'gönderilmez; yalnızca bu cihazda ve giriş yaptığınız hesapta '
              'saklanır.',
              style: AppFonts.outfit(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Bu nedenle her hesabın kendi sınıf listesi vardır. '
                'Önceki hesabınızdaki sınıflar silinmedi — o hesapla giriş '
                'yaptığınızda yerinde duruyor olacak.',
                style: AppFonts.outfit(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  /// Veli Olarak Giriş Yap.
  ///
  /// Veli de öğretmen gibi Google ile giriş yapar: çocuk bağlantısı bulutta
  /// `parent_links/{uid}_{studentCloudId}` olarak tutulduğu için kalıcı bir
  /// Firebase UID gereklidir. Bu olmadan veli cihaz değiştirdiğinde
  /// bağlantısını kaybederdi.
  Future<void> _handleParentLogin(BuildContext context) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veli girişi Android / iOS uygulamasında yapılır.'),
        ),
      );
      return;
    }

    setState(() => _parentSigningIn = true);
    try {
      await ParentAuthService().signInWithGoogle();
      await ref.read(userRoleProvider.notifier).selectParentRole();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Veli Google girişi hatası: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ParentAuthException: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _parentSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1E38),
              Color(0xFF0F172A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),

                          // Proje Dairesel Logosu
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Başlık & Alt Başlık
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SınıfCepte',
                              style: theme.textTheme.displayLarge?.copyWith(
                                letterSpacing: 1.2,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Öğretmen ve Veliler İçin Dijital Eğitim Köprüsü',
                            textAlign: TextAlign.center,
                            style: AppFonts.outfit(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const Spacer(),
                          const SizedBox(height: 16),

                          // 1. KART: ÖĞRETMEN GİRİŞİ
                          _buildRoleCard(
                            context,
                            title: _teacherSigningIn ? '👨‍🏫 Google ile bağlanılıyor...' : '👨‍🏫 Öğretmen Girişi',
                            subtitle: 'Google ile giriş, ardından okulunuzu seçin. Sınıf ve katılım cihazınızda kalır.',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                            icon: Icons.school_rounded,
                            onTap: _teacherSigningIn ? () {} : () => _handleTeacherLogin(context),
                          ),

                          const SizedBox(height: 12),

                          // 2. KART: VELİ GİRİŞİ
                          _buildRoleCard(
                            context,
                            title: _parentSigningIn ? '👨‍👩‍👧 Google ile bağlanılıyor...' : '👨‍👩‍👧 Veli Girişi',
                            subtitle: 'Google ile giriş yapın, ardından referans kodu ile öğrencinizi bağlayın.',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                            ),
                            icon: Icons.family_restroom_rounded,
                            onTap: _parentSigningIn ? () {} : () => _handleParentLogin(context),
                          ),

                          const SizedBox(height: 18),

                          // Bilgilendirme Rozeti (Offline-First)
                          GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    color: AppColors.accent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'İnternet paketi gerektirmez! %100 yerel ve güvenli mimariyle çalışır.',
                                    style: AppFonts.outfit(
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppFonts.outfit(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
