import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../features/academic_calendar/screens/academic_calendar_screen.dart';
import '../../features/analytics/presentation/views/analytics_dashboard_view.dart';
import '../../features/attendance/presentation/views/classroom_participation_view.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/classes/screens/my_class_hub_screen.dart';
import '../../features/navigation/providers/navigation_provider.dart';
import 'glass_card.dart';
import '../../core/backup/backup_service.dart';

/// SınıfCepte - Gezinme Çekmecesi (AppDrawer)
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E1E38),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Katmanı (Öğretmen Profili & Güvenlik Rozeti)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Öğretmen Profili',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SınıfCepte Kullanıcısı',
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: isDark ? AppColors.glassBorder : Colors.grey.shade300, height: 1),
                      const SizedBox(height: 10),

                      // Güvenlik & KVKK Rozeti
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Verileriniz yalnızca bu cihazda saklanır (KVKK Uyumlu)',
                              style: TextStyle(
                                color: isDark ? AppColors.accent : const Color(0xFF059669),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Menü Öğeleri
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.dashboard_customize_rounded,
                      title: 'Sınıfım',
                      subtitle: 'Sınıf yönetimi, oturma planı ve evraklar',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyClassHubScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.class_rounded,
                      title: 'Sınıflarım',
                      subtitle: 'Sınıf listesi ve öğrenciler',
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(navigationIndexProvider.notifier).state = 1;
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.stars_rounded,
                      title: 'Ders İçi Katılım & Performans',
                      subtitle: 'Hızlı ödev, kitap ve yıldız değerlendirmesi',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ClassroomParticipationView()),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.auto_stories_rounded,
                      title: 'Müfredat & Kazanımlar',
                      subtitle: 'MEB Maarif Modeli 39+1 haftalık kazanım akışı',
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(navigationIndexProvider.notifier).state = 2;
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.calendar_month_rounded,
                      title: 'MEB Çalışma Takvimi',
                      subtitle: '2025-2026 Resmî tatil ve dönem tarihleri',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.bar_chart_rounded,
                      title: 'Raporlar & İstatistikler',
                      subtitle: 'Soru bazlı analizler ve karne görüşleri',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AnalyticsDashboardView()),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.sd_storage_rounded,
                      title: 'Veri Yedekleme & Aktarma',
                      subtitle: 'Ücretsiz yerel dosya yedekleme',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showBackupDialog(context);
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.gavel_rounded,
                      title: 'Veri Gizliliği & KVKK',
                      subtitle: 'Yasal uyum ve gizlilik politikası',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showKvkkDialog(context);
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildMenuItem(
                      context,
                      icon: Icons.settings_rounded,
                      title: 'Ayarlar',
                      subtitle: 'Tema ve uygulama tercihleri',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Footer Katmanı (Versiyon Bilgisi)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Divider(color: isDark ? AppColors.glassBorder : Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      'SınıfCepte v1.0.0',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white38 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Öğretmenler İçin Dijital Asistan',
                      style: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.glassBorder.withValues(alpha: 0.5) : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 11,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDark ? Colors.white38 : Colors.black38,
          size: 18,
        ),
      ),
    );
  }


  void _showBackupDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        title: Row(
          children: [
            Icon(Icons.sd_storage_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'Yerel Veri Yedekleme',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tüm sınıf ve öğrenci verileriniz internet kotası harcanmadan doğrudan bu cihaza yedeklenebilir.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Sıfır İnternet / Maliyet\n• %100 Gizlilik ve Güvenlik',
              style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Kapat',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            // Bu dugme de yalnizca "hazirlandi" mesaji gosteriyordu;
            // hicbir dosya yazilmiyordu. Ayni yalanin ikinci kopyasiydi
            // (digeri profil ekranindaydi). Artik gercek yedek aliyor.
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Yedek hazırlanıyor...'),
                  duration: Duration(seconds: 2),
                ),
              );

              final yol = await BackupService.instance.exportDatabase();
              if (yol == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Yedek alınamadı. Lütfen tekrar deneyin.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final paylasildi =
                  await BackupService.instance.shareBackup(yol);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    paylasildi
                        ? 'Yedek dosyası paylaşıldı. Güvenli bir yerde saklayın.'
                        : 'Yedek hazırlandı ancak paylaşılmadı.',
                  ),
                  backgroundColor:
                      paylasildi ? AppColors.success : Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
            label: const Text('Yedek Al', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showKvkkDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        title: Row(
          children: [
            const Icon(Icons.gavel_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(
              'KVKK & Veri Gizliliği',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KVKK & GDPR Yasal Aydınlatma Metni',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. SınıfCepte uygulaması öğrenci ve veli kişisel verilerini kesinlikle 3. taraf sunuculara veya reklam ağlarına aktarmaz.\n\n'
                '2. Tüm veriler yalnızca cihazınızın şifrelenmiş yerel SQLite veritabanında saklanır.\n\n'
                '3. Cihazınızdan uygulama silindiğinde tüm veriler kalıcı olarak temizlenir.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anladım', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
