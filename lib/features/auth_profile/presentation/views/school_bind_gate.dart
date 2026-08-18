import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/screens/welcome_screen.dart';
import '../../../navigation/screens/main_navigation_screen.dart';
import '../../../schools/data/models/school_model.dart';
import '../../../schools/presentation/widgets/school_selection_modal.dart';
import '../../data/repositories/school_directory_repository.dart';
import '../../data/services/teacher_auth_service.dart';
import '../../providers/teacher_profile_provider.dart';
import '../../providers/user_role_provider.dart';

/// Öğretmen kromuna tek giriş: kanonik okul bağı yoksa MainNavigation açılmaz.
class SchoolBindGate extends ConsumerStatefulWidget {
  const SchoolBindGate({super.key});

  @override
  ConsumerState<SchoolBindGate> createState() => _SchoolBindGateState();
}

class _SchoolBindGateState extends ConsumerState<SchoolBindGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      await ref.read(teacherProfileProvider.notifier).ensureLoaded();
    } catch (e, stackTrace) {
      debugPrint('SchoolBindGate hydrate hatası: $e\n$stackTrace');
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _bindSchool(SchoolModel school) async {
    final current = ref.read(teacherProfileProvider);
    final updated = current.copyWith(
      schoolName: school.name,
      schoolId: school.id,
      city: school.city,
      district: school.district,
      schoolType: school.type,
    );
    await ref.read(teacherProfileProvider.notifier).saveProfile(updated);

    // Okul bağını buluta da yaz: böylece aynı okuldaki öğretmenler
    // birbirini kadro listesinde görebilir ve sınıf kadrosu kod
    // alışverişi olmadan kurulabilir.
    unawaited(
      SchoolDirectoryRepository().registerTeacher(
        teacherUid: updated.id,
        schoolId: school.id,
        fullName: updated.fullName,
        branch: updated.branch,
        email: updated.email,
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = ref.watch(teacherProfileProvider);
    if (profile.isSchoolBound) {
      return const MainNavigationScreen();
    }

    return _ForcedSchoolBindScreen(onSchoolSelected: _bindSchool);
  }
}

class _ForcedSchoolBindScreen extends ConsumerWidget {
  final Future<void> Function(SchoolModel school) onSchoolSelected;

  const _ForcedSchoolBindScreen({required this.onSchoolSelected});

  Future<void> _handleSignOutAndReturn(BuildContext context, WidgetRef ref) async {
    try {
      await TeacherAuthService().signOut();
      await ref.read(userRoleProvider.notifier).resetRole();
    } catch (e, stackTrace) {
      debugPrint('Öğretmen okul seçiminden çıkış yapma hatası: $e\n$stackTrace');
    } finally {
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(teacherProfileProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSignOutAndReturn(context, ref);
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              size: 20,
            ),
            tooltip: 'Giriş Ekranına Dön',
            onPressed: () => _handleSignOutAndReturn(context, ref),
          ),
          title: Text(
            'Okul Seçimi',
            style: AppFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 24,
              ),
              tooltip: 'Vazgeç ve Çıkış Yap',
              onPressed: () => _handleSignOutAndReturn(context, ref),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Giriş Yapılan Hesap Bilgi Kartı
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.fullName.trim().isNotEmpty
                                          ? profile.fullName
                                          : (profile.email.isNotEmpty ? profile.email : 'Öğretmen Hesabı'),
                                      style: AppFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      profile.email.isNotEmpty
                                          ? profile.email
                                          : 'Google ile giriş yapıldı',
                                      style: AppFonts.outfit(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Öğretmen',
                                  style: AppFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // 2. İkon ve Başlık
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.apartment_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Okulunuzu Belirleyin',
                          textAlign: TextAlign.center,
                          style: AppFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'SınıfCepte\'de sınıf, BEP, evrak ve veli ekosistemini kullanabilmek için görev yaptığınız okulu eşlemeniz gerekmektedir.',
                            textAlign: TextAlign.center,
                            style: AppFonts.outfit(
                              fontSize: 13.5,
                              height: 1.45,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),

                        const Spacer(),

                        const SizedBox(height: 24),

                        // 3. Okul Seç Butonu
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picked = await SchoolSelectionModal.show(
                              context,
                              dismissible: true,
                            );
                            if (picked != null) {
                              await onSchoolSelected(picked);
                            }
                          },
                          icon: const Icon(Icons.search_rounded, size: 20),
                          label: Text(
                            'MEB Okul Dizininden Seç',
                            style: AppFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 4. Çıkış / Farklı Hesapla Giriş Butonu
                        OutlinedButton.icon(
                          onPressed: () => _handleSignOutAndReturn(context, ref),
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          label: Text(
                            'Farklı Hesapla Giriş Yap / Çıkış',
                            style: AppFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.15),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
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
}
