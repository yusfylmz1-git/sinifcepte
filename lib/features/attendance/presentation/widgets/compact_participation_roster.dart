import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/classroom_participation_provider.dart';
import 'quick_student_eval_dialog.dart';

/// SınıfCepte - Kompakt Hızlı Değerlendirme Listesi (Tüm Sınıf Tek Ekranda)
class CompactParticipationRoster extends ConsumerWidget {
  final ClassroomParticipationSession session;

  const CompactParticipationRoster({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final evaluations = session.evaluations;

    if (evaluations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Bu sınıfta kayıtlı öğrenci bulunamadı.',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: evaluations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final student = evaluations[index];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              // 1. Numara & İsim (Expanded korumalı - sıfır taşma)
              SizedBox(
                width: 32,
                child: Text(
                  '${student.studentNumber}',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student.studentName,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (student.customTags.isNotEmpty || student.note != null)
                      Text(
                        student.customTags.isNotEmpty
                            ? student.customTags.first
                            : student.note!,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // 2. Ödev 3'lü Butonu (+ / ± / -)
              _buildHomeworkSelector(context, ref, student, isDark),
              const SizedBox(width: 4),

              // 3. Araç-Gereç Butonu (📚)
              _buildMaterialToggle(ref, student, isDark),
              const SizedBox(width: 4),

              // 4. Yıldız Sayacı Butonu (⭐)
              _buildStarButton(ref, student),
              const SizedBox(width: 2),

              // 5. Detay / Etiket Butonu (🏷️)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  student.customTags.isNotEmpty || student.note != null
                      ? Icons.label_rounded
                      : Icons.more_vert_rounded,
                  size: 18,
                  color: student.customTags.isNotEmpty ? AppColors.primary : Colors.grey,
                ),
                onPressed: () {
                  QuickStudentEvalDialog.show(
                    context: context,
                    evaluation: student,
                    subjectName: session.subjectName,
                    date: session.date,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeworkSelector(
    BuildContext context,
    WidgetRef ref,
    StudentParticipationEvaluation student,
    bool isDark,
  ) {
    Color bg;
    String text;

    switch (student.homeworkStatus) {
      case HomeworkStatus.done:
        bg = const Color(0xFF059669);
        text = 'Yaptı (+)';
        break;
      case HomeworkStatus.partial:
        bg = Colors.amber.shade700;
        text = 'Eksik (±)';
        break;
      case HomeworkStatus.none:
        bg = Colors.red.shade700;
        text = 'Yok (-)';
        break;
      case HomeworkStatus.notGiven:
        bg = Colors.grey.shade600;
        text = '-';
        break;
    }

    return InkWell(
      onTap: () {
        ref.read(currentParticipationSessionProvider.notifier).cycleHomework(student.studentId);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bg.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              student.homeworkStatus == HomeworkStatus.done
                  ? Icons.check_rounded
                  : student.homeworkStatus == HomeworkStatus.partial
                      ? Icons.remove_rounded
                      : Icons.close_rounded,
              size: 13,
              color: bg,
            ),
            const SizedBox(width: 3),
            Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: bg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialToggle(
    WidgetRef ref,
    StudentParticipationEvaluation student,
    bool isDark,
  ) {
    final isReady = student.materialsStatus == MaterialsStatus.ready;

    return InkWell(
      onTap: () {
        ref.read(currentParticipationSessionProvider.notifier).toggleMaterial(student.studentId);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: (isReady ? Colors.blue : Colors.grey).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (isReady ? Colors.blue : Colors.grey).withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          isReady ? Icons.menu_book_rounded : Icons.menu_book_outlined,
          size: 15,
          color: isReady ? Colors.blue.shade600 : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildStarButton(
    WidgetRef ref,
    StudentParticipationEvaluation student,
  ) {
    final hasStars = student.starsCount > 0;

    return InkWell(
      onTap: () {
        ref.read(currentParticipationSessionProvider.notifier).addStar(student.studentId);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: (hasStars ? Colors.amber : Colors.grey).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (hasStars ? Colors.amber : Colors.grey).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 14,
              color: hasStars ? Colors.amber.shade700 : Colors.grey,
            ),
            if (hasStars) ...[
              const SizedBox(width: 2),
              Text(
                '${student.starsCount}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
