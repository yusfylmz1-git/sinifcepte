import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/classroom_participation_provider.dart';

/// SınıfCepte - Rastgele Öğrenci Seçici / Adaletli Kura Çekme Modalı
class RandomStudentPickerModal extends ConsumerStatefulWidget {
  final ClassroomParticipationSession session;

  const RandomStudentPickerModal({super.key, required this.session});

  static Future<void> show(BuildContext context, ClassroomParticipationSession session) async {
    HapticFeedback.mediumImpact();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => RandomStudentPickerModal(session: session),
    );
  }

  @override
  ConsumerState<RandomStudentPickerModal> createState() => _RandomStudentPickerModalState();
}

class _RandomStudentPickerModalState extends ConsumerState<RandomStudentPickerModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  StudentParticipationEvaluation? _selectedStudent;
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _pickRandomStudent();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _pickRandomStudent() {
    final list = widget.session.evaluations;
    if (list.isEmpty) return;

    HapticFeedback.mediumImpact();
    _animController.reset();

    setState(() {
      _selectedStudent = list[_rnd.nextInt(list.length)];
    });

    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSession = ref.watch(currentParticipationSessionProvider).valueOrNull ?? widget.session;

    // Seçili öğrencinin güncel oturumdaki referansını bul
    final currentStudent = _selectedStudent == null
        ? null
        : currentSession.evaluations.where((e) => e.studentId == _selectedStudent!.studentId).firstOrNull ??
            _selectedStudent;

    if (currentStudent == null) {
      return const SizedBox.shrink();
    }

    final isFemale = currentStudent.isFemale;
    final Color avatarBg = isFemale ? const Color(0xFFEC4899) : const Color(0xFF3B82F6);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.casino_rounded, size: 16, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Text(
                        'Rastgele Öğrenci Seçimi',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Seçilen Öğrenci Animasyonlu Kartı
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: avatarBg.withValues(alpha: 0.2),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: avatarBg,
                      child: Text(
                        '${currentStudent.studentNumber}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentStudent.studentName,
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No: ${currentStudent.studentNumber} • ${currentStudent.gender}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hızlı Puanlama (3 Yıldız Butonları)
            Text(
              'Derse Katılımı Değerlendir',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStarChip(
                  label: '⭐ Geliştirilmeli',
                  stars: 1,
                  isSelected: currentStudent.starsCount == 1,
                  color: const Color(0xFFEF4444),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).setStars(currentStudent.studentId, 1);
                  },
                ),
                const SizedBox(width: 6),
                _buildStarChip(
                  label: '⭐⭐ İyi',
                  stars: 2,
                  isSelected: currentStudent.starsCount == 2,
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).setStars(currentStudent.studentId, 2);
                  },
                ),
                const SizedBox(width: 6),
                _buildStarChip(
                  label: '⭐⭐⭐ Çok İyi',
                  stars: 3,
                  isSelected: currentStudent.starsCount == 3,
                  color: const Color(0xFF10B981),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(currentParticipationSessionProvider.notifier).setStars(currentStudent.studentId, 3);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hızlı Davranış Rozetleri
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildTagChip('👏 Örnek Davranış', currentStudent),
                _buildTagChip('💡 Soru Çözdü', currentStudent),
                _buildTagChip('🎯 Aktif Katılım', currentStudent),
              ],
            ),
            const SizedBox(height: 20),

            // Alt Butonlar: [ 🎲 Başka Öğrenci Seç ] ve [ Kapat ]
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRandomStudent,
                    icon: const Icon(Icons.casino_rounded, size: 17, color: Color(0xFF8B5CF6)),
                    label: Text(
                      'Başka Öğrenci',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Tamam',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarChip({
    required String label,
    required int stars,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, StudentParticipationEvaluation student) {
    final hasTag = student.customTags.contains(tag);
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(currentParticipationSessionProvider.notifier).toggleTag(student.studentId, tag);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasTag ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasTag ? Colors.transparent : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          tag,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: hasTag ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
