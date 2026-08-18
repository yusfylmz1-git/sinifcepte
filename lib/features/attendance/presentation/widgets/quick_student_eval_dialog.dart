import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/classroom_participation_provider.dart';
import '../../utils/participation_whatsapp_helper.dart';

/// SınıfCepte - Öğrenciye Özel Hızlı Değerlendirme, Ödev, Materyal & Katılım Yıldızı Dialogu (High-Contrast UI-UX-MAX)
class QuickStudentEvalDialog extends ConsumerStatefulWidget {
  final StudentParticipationEvaluation evaluation;
  final String subjectName;
  final String date;

  const QuickStudentEvalDialog({
    super.key,
    required this.evaluation,
    required this.subjectName,
    required this.date,
  });

  static Future<void> show({
    required BuildContext context,
    required StudentParticipationEvaluation evaluation,
    required String subjectName,
    required String date,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickStudentEvalDialog(
        evaluation: evaluation,
        subjectName: subjectName,
        date: date,
      ),
    );
  }

  @override
  ConsumerState<QuickStudentEvalDialog> createState() => _QuickStudentEvalDialogState();
}

class _QuickStudentEvalDialogState extends ConsumerState<QuickStudentEvalDialog> {
  late TextEditingController _noteController;

  static const List<String> availableTags = [
    '👏 Örnek Davranış',
    '💡 Soru Çözdü',
    '🎯 Aktif Katılım',
    '🌟 Ödev Çok Başarılı',
    '🤝 Arkadaşına Yardım Etti',
    '⚠️ Odaklanamadı',
    '🗣️ Dersi Böldü',
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.evaluation.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionAsync = ref.watch(currentParticipationSessionProvider);
    final currentSession = sessionAsync.valueOrNull;

    final currentEval = currentSession?.evaluations.firstWhere(
          (e) => e.studentId == widget.evaluation.studentId,
          orElse: () => widget.evaluation,
        ) ??
        widget.evaluation;

    final teacherProfile = ref.watch(teacherProfileProvider);
    final teacherName = teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName : 'Ders Öğretmeni';

    final isFemale = currentEval.isFemale;
    final Color themeAccent = isFemale ? const Color(0xFFE11D48) : AppColors.primary;
    final Color themeBg = isFemale
        ? (isDark ? const Color(0xFF2D1222) : const Color(0xFFFFEEF2))
        : (isDark ? const Color(0xFF132038) : const Color(0xFFEFF6FF));

    final Color headerTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color sectionHeaderColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Tutamaç Çubuğu
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 1. Öğrenci Başlık Kartı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: themeBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: themeAccent.withValues(alpha: isDark ? 0.4 : 0.35),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: themeAccent.withValues(alpha: 0.2),
                    child: Text(
                      isFemale ? '👧' : '👦',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: themeAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'No: ${currentEval.studentNumber}',
                                style: AppFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentEval.studentName,
                                style: AppFonts.outfit(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: headerTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.subjectName} • ${widget.date}',
                          style: AppFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Veliye Özel WhatsApp Mesajı
                  IconButton.filled(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final msg = ParticipationWhatsAppHelper.generateIndividualStudentMessage(
                        eval: currentEval,
                        subjectName: widget.subjectName,
                        date: widget.date,
                        teacherName: teacherName,
                      );
                      ParticipationWhatsAppHelper.showWhatsAppModal(
                        context: context,
                        messageText: msg,
                        title: '${currentEval.studentName} Veli Bildirimi',
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.share_rounded, size: 20),
                    tooltip: 'Veliye Özel WhatsApp Raporu',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 1.1 SON DERSLER GEÇMİŞ TRENDİ (Mini Pill Çipler)
            _buildRecentHistorySection(context, ref, isDark, currentEval.studentId),
            const SizedBox(height: 14),

            // 2. ÖDEV DURUMU SEÇİCİ
            Text(
              '📝 Ödev Durumu',
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: sectionHeaderColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSegmentButton(
                  label: '✓ Yaptı',
                  isSelected: currentEval.homeworkStatus == HomeworkStatus.done,
                  activeColor: const Color(0xFF059669),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).setHomework(currentEval.studentId, HomeworkStatus.done);
                  },
                ),
                const SizedBox(width: 6),
                _buildSegmentButton(
                  label: '± Eksik',
                  isSelected: currentEval.homeworkStatus == HomeworkStatus.partial,
                  activeColor: const Color(0xFFD97706),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).setHomework(currentEval.studentId, HomeworkStatus.partial);
                  },
                ),
                const SizedBox(width: 6),
                _buildSegmentButton(
                  label: '✗ Yapmadı',
                  isSelected: currentEval.homeworkStatus == HomeworkStatus.none,
                  activeColor: const Color(0xFFDC2626),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).setHomework(currentEval.studentId, HomeworkStatus.none);
                  },
                ),
                const SizedBox(width: 6),
                _buildSegmentButton(
                  label: '- Yoktu',
                  isSelected: currentEval.homeworkStatus == HomeworkStatus.notGiven,
                  activeColor: const Color(0xFF64748B),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).setHomework(currentEval.studentId, HomeworkStatus.notGiven);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. DEFTER/KİTAP VE ZAMANINDA GELME SATIRI
            Row(
              children: [
                // Defter / Kitap
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📚 Defter / Kitap',
                        style: AppFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: sectionHeaderColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceChipButton(
                              label: 'Tam 📚',
                              isSelected: currentEval.materialsStatus == MaterialsStatus.ready,
                              activeColor: const Color(0xFF059669),
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(currentParticipationSessionProvider.notifier).setMaterials(currentEval.studentId, MaterialsStatus.ready);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildChoiceChipButton(
                              label: 'Eksik ❌',
                              isSelected: currentEval.materialsStatus == MaterialsStatus.missing,
                              activeColor: const Color(0xFFDC2626),
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(currentParticipationSessionProvider.notifier).setMaterials(currentEval.studentId, MaterialsStatus.missing);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Zamanında Gelme
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⏰ Derse Geliş',
                        style: AppFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: sectionHeaderColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceChipButton(
                              label: 'Vaktinde ⏰',
                              isSelected: currentEval.arrivalStatus == ArrivalStatus.onTime,
                              activeColor: const Color(0xFF059669),
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(currentParticipationSessionProvider.notifier).setArrival(currentEval.studentId, ArrivalStatus.onTime);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildChoiceChipButton(
                              label: 'Geç ⌛',
                              isSelected: currentEval.arrivalStatus == ArrivalStatus.late,
                              activeColor: const Color(0xFFD97706),
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(currentParticipationSessionProvider.notifier).setArrival(currentEval.studentId, ArrivalStatus.late);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. DERSE KATILIM DERECESİ (NET 3 YILDIZ SİSTEMİ)
            Text(
              '⭐ Derse Katılım Derecesi',
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: sectionHeaderColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStarLevelCard(
                    stars: 3,
                    title: '⭐⭐⭐',
                    subtitle: 'Çok İyi',
                    isSelected: currentEval.starsCount == 3,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newStars = currentEval.starsCount == 3 ? 0 : 3;
                      ref.read(currentParticipationSessionProvider.notifier).setStars(currentEval.studentId, newStars);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStarLevelCard(
                    stars: 2,
                    title: '⭐⭐',
                    subtitle: 'İyi',
                    isSelected: currentEval.starsCount == 2,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newStars = currentEval.starsCount == 2 ? 0 : 2;
                      ref.read(currentParticipationSessionProvider.notifier).setStars(currentEval.studentId, newStars);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStarLevelCard(
                    stars: 1,
                    title: '⭐',
                    subtitle: 'Geliştirilmeli',
                    isSelected: currentEval.starsCount == 1,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newStars = currentEval.starsCount == 1 ? 0 : 1;
                      ref.read(currentParticipationSessionProvider.notifier).setStars(currentEval.studentId, newStars);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 5. HIZLI DAVRANIŞ VE GÖZLEM ETİKETLERİ (Yüksek Kontrastlı Pill Butonlar)
            Text(
              '🏷️ Hızlı Davranış & Gözlem',
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: sectionHeaderColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableTags.map((tag) {
                final isSelected = currentEval.customTags.contains(tag);
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).toggleTag(currentEval.studentId, tag);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        width: isSelected ? 1.5 : 1.2,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: AppFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 6. ÖZEL GÖZLEM NOTU
            Text(
              '📝 Özel Öğretmen Notu',
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: sectionHeaderColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: AppFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Öğrenci hakkında özel not veya gözlem ekleyin...',
                hintStyle: AppFonts.outfit(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.8,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              maxLines: 2,
              onChanged: (val) {
                ref.read(currentParticipationSessionProvider.notifier).setStudentNote(currentEval.studentId, val.trim());
              },
            ),
            const SizedBox(height: 20),

            // Kapat / Tamam Butonu
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Tamam',
                  style: AppFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Son Dersler Geçmiş Eğilimi Bölümü
  Widget _buildRecentHistorySection(BuildContext context, WidgetRef ref, bool isDark, int studentId) {
    final historyAsync = ref.watch(studentRecentHistoryProvider(studentId));

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Son Ders Eğilimi (Dokununca Detay)',
                    style: AppFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: history.map((h) {
                    final date = h['date'] as String? ?? '';
                    final hw = h['homework_status'] as String? ?? 'yapti';
                    final stars = (h['stars_count'] as int?) ?? 3;

                    Color badgeColor = const Color(0xFF10B981);
                    String icon = '🟢';
                    if (hw == 'yapmadi' || stars <= 1) {
                      badgeColor = const Color(0xFFEF4444);
                      icon = '🔴';
                    } else if (hw == 'eksik' || stars == 2) {
                      badgeColor = const Color(0xFFF59E0B);
                      icon = '🟠';
                    }

                    String shortDate = date;
                    final parsedDate = DateTime.tryParse(date);
                    if (parsedDate != null) {
                      const monthNames = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
                      shortDate = '${parsedDate.day} ${monthNames[parsedDate.month]}';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showHistoryDetailModal(
                            context: context,
                            isDark: isDark,
                            historyItem: h,
                            shortDate: shortDate,
                            parsedDate: parsedDate,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeColor.withValues(alpha: isDark ? 0.5 : 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(icon, style: const TextStyle(fontSize: 10)),
                              const SizedBox(width: 4),
                              Text(
                                shortDate,
                                style: AppFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Geçmiş Ders Haftalık / Günlük Detay Popover Penceresi
  void _showHistoryDetailModal({
    required BuildContext context,
    required bool isDark,
    required Map<String, dynamic> historyItem,
    required String shortDate,
    required DateTime? parsedDate,
  }) {
    final hw = historyItem['homework_status'] as String? ?? 'yapti';
    final mat = historyItem['materials_status'] as String? ?? 'tam';
    final stars = (historyItem['stars_count'] as int?) ?? 3;
    final lessonHour = (historyItem['lesson_hour'] as int?) ?? 1;
    final subject = historyItem['subject_name'] as String? ?? 'Ders';
    final note = historyItem['note'] as String?;
    final badge = historyItem['badge_name'] as String?;

    String weekStr = '';
    String fullDateStr = shortDate;
    if (parsedDate != null) {
      weekStr = '${AppDateFormatter.getCurrentAcademicWeek(targetDate: parsedDate)}. Hafta';
      fullDateStr = AppDateFormatter.formatTurkishDate(parsedDate);
    }

    String hwText = 'Ödevini Yaptı ✓';
    if (hw == 'eksik') hwText = 'Ödevi Eksik ±';
    if (hw == 'yapmadi') hwText = 'Ödev Yapmadı ✗';
    if (hw == 'yoktu') hwText = 'Ödev Yoktu / Verilmedi';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_note_rounded, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$subject • $lessonHour. Ders',
                          style: AppFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '$fullDateStr ${weekStr.isNotEmpty ? "($weekStr)" : ""}',
                          style: AppFonts.outfit(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildDetailRow('📝 Ödev:', hwText, isDark),
              const SizedBox(height: 6),
              _buildDetailRow('📚 Materyal:', mat == 'tam' ? 'Getirdi ✓' : 'Eksik ✗', isDark),
              const SizedBox(height: 6),
              _buildDetailRow('⭐ Derse Katılım:', '$stars Yıldız', isDark),
              if (badge != null && badge.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildDetailRow('🏷️ Davranış:', badge, isDark),
              ],
              if (note != null && note.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildDetailRow('💬 Öğretmen Notu:', note.trim(), isDark),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: isSelected ? 1.5 : 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChipButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppFonts.outfit(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStarLevelCard({
    required int stars,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    const goldColor = Color(0xFFD97706);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF3B2706) : const Color(0xFFFEF3C7))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? goldColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                    : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
