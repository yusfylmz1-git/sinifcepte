import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';

/// SınıfCepte - Evraklarım Modülü Ana Ekranı
class DocumentsHubView extends ConsumerWidget {
  const DocumentsHubView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(teacherProfileProvider);

    final templates = [
      {'title': 'Sene Başı Branş Zümre Tutanak Şablonu', 'category': 'Maarif Evrakları'},
      {'title': '1. Dönem Veli Toplantısı Tutanak Formu', 'category': 'Resmî Tutanaklar'},
      {'title': 'Bireyselleştirilmiş Eğitim Planı (BEP) Formu', 'category': 'Planlar'},
      {'title': 'Ders İçi Gelişim & Takip Raporu Şablonu', 'category': 'Planlar'},
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: const CustomAppBar(
        title: 'Evraklarım',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Otomatik Öğretmen Bilgi Kartı
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.badge_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Otomatik Bilgi Basımı Aktif ⚡',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${profile.fullName} • ${profile.branch}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${profile.schoolName} (Müdür: ${profile.schoolPrincipalName})',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Resmî Şablonlar & Tutanaklar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              ...templates.map((t) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.description_rounded, color: AppColors.info, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['title'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                t['category'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('5 Saniyede Yenilenmiş PDF Oluşturuldu! 📄'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.print_rounded, color: AppColors.primary),
                          tooltip: 'Hızlı PDF Çıktısı Al',
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
