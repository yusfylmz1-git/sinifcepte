import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/models/participation_badge_model.dart';
import '../../providers/participation_provider.dart';
import '../widgets/smart_whatsapp_preview_modal.dart';

/// SınıfCepte - Ders İçi Katılım & Davranış Modülü (Yoklama Değildir)
class QuickAttendanceView extends ConsumerWidget {
  const QuickAttendanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = ref.watch(participationListProvider);

    final starStudents = students
        .where((s) => s.status == ParticipationStatus.positive)
        .map((s) => s.studentName)
        .toList();

    final needsWorkStudents = students
        .where((s) => s.status == ParticipationStatus.needsImprovement)
        .map((s) => s.studentName)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: const CustomAppBar(
        title: 'Ders İçi Katılım & Davranış',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Üst Bilgi Barı & Eylem Butonları
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(participationListProvider.notifier).markAllPositive();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tüm sınıf derse aktif katılım sağladı! 🌟'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_rounded, size: 20),
                      label: const Text('Tüm Sınıf Katıldı'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () {
                      SmartWhatsAppPreviewModal.show(
                        context: context,
                        className: '10-A Sınıfı',
                        subjectName: 'Matematik',
                        totalStudents: students.length,
                        starStudentNames: starStudents,
                        needsWorkStudentNames: needsWorkStudents,
                      );
                    },
                    icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                    tooltip: 'Akıllı WhatsApp Özeti',
                  ),
                ],
              ),
            ),

            // Kullanım İpucu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '💡 1 Tık: Yıldız/Olumlu ⭐  |  2 Tık: Geliştirilmeli ✍️  |  Uzun Basma: Etiket Ekle',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            // Öğrenci Kartları Listesi
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];

                  Color badgeColor;
                  IconData badgeIcon;
                  String statusText;

                  switch (student.status) {
                    case ParticipationStatus.positive:
                      badgeColor = Colors.amber;
                      badgeIcon = Icons.star_rounded;
                      statusText = 'Aktif / Olumlu ⭐';
                      break;
                    case ParticipationStatus.needsImprovement:
                      badgeColor = Colors.orange;
                      badgeIcon = Icons.edit_note_rounded;
                      statusText = 'Geliştirilmeli ✍️';
                      break;
                    case ParticipationStatus.neutral:
                      badgeColor = Colors.grey;
                      badgeIcon = Icons.circle_outlined;
                      statusText = 'Nötr';
                      break;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        ref.read(participationListProvider.notifier).cycleStatus(student.studentId);
                      },
                      onLongPress: () {
                        _showBadgeDialog(context, ref, student);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: badgeColor.withValues(alpha: 0.2),
                              child: Icon(badgeIcon, color: badgeColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${student.studentNumber} - ${student.studentName}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: badgeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (student.customBadges.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      children: student.customBadges.map((b) {
                                        return Chip(
                                          label: Text(b, style: const TextStyle(fontSize: 10)),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDialog(BuildContext context, WidgetRef ref, ParticipationBadgeModel student) {
    const availableBadges = ['Ödev Eksik 📑', 'Defter Getirmedi 📓', 'Derse Hazırlıklı 🎯', 'Liderlik ⭐'];

    ResponsiveBottomSheet.show(
      context: context,
      title: '${student.studentName} - Özel Etiket Ekle',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: availableBadges.map((badge) {
          final isChecked = student.customBadges.contains(badge);
          return CheckboxListTile(
            title: Text(badge),
            value: isChecked,
            onChanged: (_) {
              ref.read(participationListProvider.notifier).toggleCustomBadge(student.studentId, badge);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
