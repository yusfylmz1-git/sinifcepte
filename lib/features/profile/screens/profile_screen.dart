import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import 'about_screen.dart';
import '../../auth_profile/presentation/views/teacher_profile_setup_view.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../auth_profile/presentation/views/school_admin_panel_view.dart';
import '../../auth_profile/presentation/views/school_admin_request_view.dart';
import '../../auth_profile/providers/user_role_provider.dart';
import '../../settings/screens/settings_screen.dart';
import '../../parent_portal/presentation/widgets/help_support_modal.dart';

/// SınıfCepte - Profil Sekmesi Ekranı
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final teacherProfile = ref.watch(teacherProfileProvider);
    // Yönetici yetkisi custom claim'den gelir; yerel tercihten değil.
    final roleState = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Text(
                'Profilim',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 20),

              // Öğretmen Bilgi Kartı (Tıklanınca Düzenleme Ekranı Açılır)
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherProfileSetupView(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          teacherProfile.gender == 'Kadın'
                              ? Icons.face_3_rounded
                              : Icons.person_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    teacherProfile.fullName.isNotEmpty
                                        ? teacherProfile.fullName
                                        : 'Öğretmen Profili',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Okul idaresince doğrulanmış öğretmen rozeti.
                                // Bir KAPI değil, ROZET: doğrulanmamış
                                // öğretmen de tüm özellikleri kullanır.
                                if (teacherProfile.isVerifiedBySchoolAdmin) ...[
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message: 'Okul idaresince doğrulandı',
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 17,
                                      color: Colors.blue.shade400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${teacherProfile.branch} • ${teacherProfile.fullSchoolTitle.isNotEmpty ? teacherProfile.fullSchoolTitle : teacherProfile.schoolName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Düzenlemek İçin Dokunun ✏️',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.edit_rounded,
                        color: isDark ? Colors.white54 : Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tercihler ve Ayarlar Başlığı
              Text(
                'Uygulama Tercihleri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              // Profil Bilgilerini Düzenle Kartı
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherProfileSetupView(),
                      ),
                    );
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    'Profil ve Mesleki Bilgiler',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Ad, soyad, okul, branş ve müdür ismi',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tema Değiştirme Kartı
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                  title: Text(
                    'Karanlık Mod',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    themeMode == ThemeMode.dark ? 'Koyu Tema' : 'Açık Tema',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: Switch(
                    value: themeMode == ThemeMode.dark,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) {
                      try {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                      } catch (e, stackTrace) {
                        debugPrint('Tema değiştirme hatası: $e\n$stackTrace');
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Genel Ayarlar Kartı
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () {
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    } catch (e, stackTrace) {
                      debugPrint('Ayarlar ekranı açma hatası: $e\n$stackTrace');
                    }
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  title: Text(
                    'Uygulama Ayarları',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Veritabanı yedekleme, dışa aktarma',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Okul Yöneticiliği Kartı
              //
              // Yönetici rolü opsiyoneldir: yöneticisi olmayan okullarda
              // uygulamanın tamamı normal çalışır. Kart, kullanıcının
              // durumuna göre başvuru veya panel açar.
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () {
                    if (roleState.isSchoolAdmin) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SchoolAdminPanelView(),
                        ),
                      );
                    } else {
                      SchoolAdminRequestView.show(context);
                    }
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (roleState.isSchoolAdmin
                              ? const Color(0xFF10B981)
                              : AppColors.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: roleState.isSchoolAdmin
                          ? const Color(0xFF10B981)
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    roleState.isSchoolAdmin
                        ? 'Okul Yönetim Paneli'
                        : 'Okul Yöneticiliği Başvurusu',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    roleState.isSchoolAdmin
                        ? 'Öğretmen onayı ve veli şikâyetleri'
                        : 'İsteğe bağlı — onay olmadan da tüm özellikler açık',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Yardım ve Destek
              //
              // `HelpSupportModal` yazılmıştı ama hiçbir yerden
              // açılmıyordu: kullanıcı takıldığında gidecek yeri yoktu.
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => HelpSupportModal.show(
                    context,
                    userId: teacherProfile.id,
                    userRole: 'teacher',
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  title: Text(
                    'Yardım ve Destek',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Sık sorulanlar ve bizimle iletişim',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Hakkında
              //
              // Kullanım Koşulları ve Gizlilik Politikası uygulamanın
              // hiçbir yerinde görünmüyordu. Play Store gizlilik
              // politikasını zorunlu tutuyor; KVKK ise kullanıcının
              // verisinin ne olduğunu okuyabilmesini gerektiriyor.
              //
              // Menüyü şişirmemek için tek başlık altında toplandılar.
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    'Hakkında',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Kullanım koşulları, gizlilik politikası ve SSS',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bilgi ve Destek Kartı
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'SınıfCepte v1.0.0',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tüm verileriniz tamamen yerel cihazınızda SQLite veritabanında güvenle depolanır. İnternet bağlantısı gerektirmez.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
