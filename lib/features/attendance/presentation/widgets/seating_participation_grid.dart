import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../classes/providers/seating_plan_provider.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/classroom_participation_provider.dart';
import 'quick_student_eval_dialog.dart';

/// SınıfCepte - Kuşbakışı Oturma Planı Üzerinden Hızlı Değerlendirme Grid'i
class SeatingParticipationGrid extends ConsumerWidget {
  final ClassroomParticipationSession session;

  const SeatingParticipationGrid({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planAsync = ref.watch(seatingPlanProvider(session.classId));
    final plan = planAsync.valueOrNull;

    final evaluations = session.evaluations;
    final Map<int, StudentParticipationEvaluation> evalMapByStudentId = {
      for (var e in evaluations) e.studentId: e,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 1. ÖĞRETMEN MASASI VE TAHTA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                    : [const Color(0xFF0F172A), const Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.co_present_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'TAHTA & ÖĞRETMEN KÜRSÜSÜ',
                    style: AppFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // İpucu Barı
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '💡 1 Dokunuş: ⭐ +1 Yıldız  |  Çift Dokunuş: Ödev Değiştir (+/-)  |  Uzun Basış: Detay/Not',
              style: AppFonts.outfit(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // 2. OTURMA SIRALARI (Grid)
          if (plan != null && plan.assignments.isNotEmpty)
            _buildPlanBasedLayout(context, ref, plan, evalMapByStudentId, isDark)
          else
            _buildAutoGridLayout(context, ref, evaluations, isDark),
        ],
      ),
    );
  }

  /// Kayıtlı oturma planı düzenine göre sıraları render eder
  Widget _buildPlanBasedLayout(
    BuildContext context,
    WidgetRef ref,
    dynamic plan,
    Map<int, StudentParticipationEvaluation> evalMap,
    bool isDark,
  ) {
    final int rows = plan.rows;
    final int cols = plan.columns; // Blok sayısı (Örn: 3 blok)

    return Column(
      children: List.generate(rows, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: List.generate(cols, (colIndex) {
              // Her blokta 2 sıra (Sol ve Sağ)
              final leftSeatKey = '${rowIndex}_${colIndex * 2}';
              final rightSeatKey = '${rowIndex}_${colIndex * 2 + 1}';

              final leftStudentId = plan.assignments[leftSeatKey];
              final rightStudentId = plan.assignments[rightSeatKey];

              final leftEval = leftStudentId != null ? evalMap[leftStudentId] : null;
              final rightEval = rightStudentId != null ? evalMap[rightStudentId] : null;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: colIndex < cols - 1 ? 8 : 0),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildDeskCell(context, ref, leftEval, isDark)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildDeskCell(context, ref, rightEval, isDark)),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  /// Oturma planı henüz çizilmemişse otomatik 2 sütunlu düzen render eder
  Widget _buildAutoGridLayout(
    BuildContext context,
    WidgetRef ref,
    List<StudentParticipationEvaluation> evaluations,
    bool isDark,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: evaluations.length,
      itemBuilder: (context, index) {
        final eval = evaluations[index];
        return _buildDeskCell(context, ref, eval, isDark);
      },
    );
  }

  Widget _buildDeskCell(
    BuildContext context,
    WidgetRef ref,
    StudentParticipationEvaluation? eval,
    bool isDark,
  ) {
    if (eval == null) {
      return Container(
        height: 62,
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)).withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Text('Boş', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ),
      );
    }
    return _buildStudentDeskCard(context, ref, eval, isDark);
  }

  Widget _buildStudentDeskCard(
    BuildContext context,
    WidgetRef ref,
    StudentParticipationEvaluation eval,
    bool isDark,
  ) {
    Color hwColor;
    switch (eval.homeworkStatus) {
      case HomeworkStatus.done:
        hwColor = const Color(0xFF10B981);
        break;
      case HomeworkStatus.partial:
        hwColor = const Color(0xFFF59E0B);
        break;
      case HomeworkStatus.none:
        hwColor = const Color(0xFFEF4444);
        break;
      case HomeworkStatus.notGiven:
        hwColor = Colors.grey;
        break;
    }

    final isFemale = eval.isFemale;
    final cardBg = isFemale
        ? (isDark ? const Color(0xFF2A1522) : const Color(0xFFFFF1F4))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final cardBorder = isFemale
        ? (isDark ? const Color(0xFF88254A) : const Color(0xFFFECDD3))
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    final hasStars = eval.starsCount > 0;

    return InkWell(
      onTap: () {
        ref.read(currentParticipationSessionProvider.notifier).addStar(eval.studentId);
      },
      onDoubleTap: () {
        ref.read(currentParticipationSessionProvider.notifier).cycleHomework(eval.studentId);
      },
      onLongPress: () {
        QuickStudentEvalDialog.show(
          context: context,
          evaluation: eval,
          subjectName: session.subjectName,
          date: session.date,
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Üst Satır: Numara & Rozetler
            Row(
              children: [
                Text(
                  'No: ${eval.studentNumber}',
                  style: AppFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isFemale
                        ? const Color(0xFFE11D48)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const Spacer(),
                // Ödev İkonu
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hwColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    eval.homeworkStatus == HomeworkStatus.done
                        ? '✓'
                        : eval.homeworkStatus == HomeworkStatus.partial
                            ? '±'
                            : '✗',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: hwColor,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                // Araç Gereç İkonu
                Text(
                  eval.materialsStatus == MaterialsStatus.ready ? '📚' : '❌',
                  style: const TextStyle(fontSize: 8.5),
                ),
              ],
            ),

            // Orta: Öğrenci Adı (Zero-overflow)
            Text(
              eval.shortName,
              style: AppFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Alt Satır: Yıldızlar
            Row(
              children: [
                if (hasStars) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      eval.starsCount,
                      (_) => const Icon(Icons.star_rounded, size: 10, color: Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '(${eval.starLabel})',
                    style: AppFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ] else
                  Text(
                    'Puan ver...',
                    style: AppFonts.outfit(fontSize: 8.5, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
