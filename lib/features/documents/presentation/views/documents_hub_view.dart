import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/student_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../data/council_minutes.dart';
import '../widgets/council_minutes_editor_modal.dart';

/// Evraklarım: kurul tutanak taslakları.
class DocumentsHubView extends ConsumerWidget {
  const DocumentsHubView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(teacherProfileProvider);
    final classes = ref.watch(classListProvider).valueOrNull ?? const [];
    final homeroom = classes.where((c) => c.isHomeroom).firstOrNull ??
        (classes.isEmpty ? null : classes.first);

    Future<void> openCouncil(CouncilKind kind) async {
      final selected = homeroom;
      // Tip acikca yazilmali: `const []` tek basina `List<dynamic>`
      // uretiyor ve modal `List<StudentModel>` bekliyor.
      final students = selected?.id == null
          ? const <StudentModel>[]
          : (ref.read(studentListProvider(selected!.id!)).valueOrNull ??
              const <StudentModel>[]);
      await CouncilMinutesEditorModal.show(
        context,
        kind: kind,
        classModel: selected,
        students: students,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: const CustomAppBar(
        title: 'Evraklarım',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                          profile.fullName.trim().isEmpty
                              ? 'Öğretmen'
                              : profile.fullName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            if (profile.branch.trim().isNotEmpty) profile.branch,
                            if (profile.schoolName.trim().isNotEmpty)
                              profile.schoolName,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Tutanaklar yönerge gündemli taslaktır. Kararlar e-Kurul ve '
                'Zümre Modülüne işlenir. Bu çıktı imza ve okul arşivi içindir; '
                'MEB resmî evrakı değildir.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Kurul tutanak taslakları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            _DocTile(
              isDark: isDark,
              icon: Icons.groups_rounded,
              title: 'Zümre öğretmenler kurulu',
              subtitle:
                  'Sene başı, 2. dönem ve yıl sonu gündemi hazır. Kararı düzenleyip yazdırın.',
              onTap: () => openCouncil(CouncilKind.zumre),
            ),
            const SizedBox(height: 10),
            _DocTile(
              isDark: isDark,
              icon: Icons.account_tree_outlined,
              title: 'Şube öğretmenler kurulu (ŞÖK)',
              subtitle:
                  'Şube kadrosu, imza sirküsü ve boş öğrenci değerlendirme ızgarası. İlkokulda açılmaz.',
              onTap: () => openCouncil(CouncilKind.sok),
            ),
            const SizedBox(height: 16),
            Text(
              'Diğer sınıf evrakları (liste, nöbet, veli toplantısı, BEP) '
              'Sınıfım ekranındadır.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocTile({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.info, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
