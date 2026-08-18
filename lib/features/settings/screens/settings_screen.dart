import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';

/// SınıfCepte - Ayarlar Ekranı (SettingsScreen)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: const CustomAppBar(
        title: 'Ayarlar',
        subtitle: 'Uygulama Teması ve Tercihler',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Kısım: Uygulama Teması Seçici
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.palette_rounded,
                          color: AppColors.primaryLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uygulama Teması',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Görünüm tercihinizi seçin',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.glassBorder, height: 1),
                  const SizedBox(height: 12),

                  // Koyu Tema Seçeneği
                  _buildThemeRadioTile(
                    context,
                    title: '🌙 Koyu Tema (Dark Mode)',
                    subtitle: 'Göz yormayan Slate Navy & Mor tonlar',
                    value: ThemeMode.dark,
                    groupValue: currentThemeMode,
                    onChanged: (val) => themeNotifier.setThemeMode(val),
                  ),

                  // Açık Tema Seçeneği
                  _buildThemeRadioTile(
                    context,
                    title: '☀️ Açık Tema (Light Mode)',
                    subtitle: 'Ferah Pure White tasarımı',
                    value: ThemeMode.light,
                    groupValue: currentThemeMode,
                    onChanged: (val) => themeNotifier.setThemeMode(val),
                  ),

                  // Sistem Teması Seçeneği
                  _buildThemeRadioTile(
                    context,
                    title: '📱 Sistem Temasını Takip Et',
                    subtitle: 'Telefonunuzun moduna otomatik uyum sağlar',
                    value: ThemeMode.system,
                    groupValue: currentThemeMode,
                    onChanged: (val) => themeNotifier.setThemeMode(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Kısım: Veri Güvenliği Bilgilendirme Kartı
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔒 Yerel Depolama Koruması',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tüm verileriniz yalnızca bu cihazda şifreli yerel SQLite veritabanında saklanır.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Kısım: Sürüm Bilgisi (Gizli Admin Erişim Noktası)
            GlassCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: isDark ? Colors.white60 : Colors.black45,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uygulama Sürümü',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SınıfCepte v$_appVersion',
                              style: AppFonts.firaCode(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white24 : Colors.black12,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeRadioTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required ThemeMode value,
    required ThemeMode groupValue,
    required ValueChanged<ThemeMode> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = value == groupValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: () => onChanged(value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
          color: isSelected ? AppColors.primaryLight : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      ),
    );
  }
}
