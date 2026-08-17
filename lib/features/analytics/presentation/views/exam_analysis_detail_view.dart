import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/exam_analysis_model.dart';
import '../../providers/exam_analysis_provider.dart';
import '../../utils/exam_analysis_pdf_generator.dart';
import 'exam_analysis_editor_view.dart';

/// SınıfCepte - Sınav Analizi Detaylı İstatistik ve Grafik Ekranı (UI-UX-MAX)
class ExamAnalysisDetailView extends ConsumerStatefulWidget {
  final ExamAnalysisModel exam;

  const ExamAnalysisDetailView({super.key, required this.exam});

  @override
  ConsumerState<ExamAnalysisDetailView> createState() => _ExamAnalysisDetailViewState();
}

class _ExamAnalysisDetailViewState extends ConsumerState<ExamAnalysisDetailView> {
  late ExamAnalysisModel _currentExam;
  bool _sortByScoreDescending = true;

  @override
  void initState() {
    super.initState();
    _currentExam = widget.exam;
  }

  void _toggleSort() {
    setState(() {
      _sortByScoreDescending = !_sortByScoreDescending;
    });
  }

  Future<void> _deleteExam() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Sınav Analizini Sil',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Bu sınav analizini ve tüm öğrenci soru puanlarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Evet, Sil', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentExam.id != null) {
      final success = await ref.read(examAnalysisListProvider.notifier).deleteExam(_currentExam.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sınav analizi başarıyla silindi.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacherProfile = ref.watch(teacherProfileProvider);

    final avg = _currentExam.classAverage;
    final passRate = _currentExam.passRate;
    final highest = _currentExam.highestScore;
    final lowest = _currentExam.lowestScore;
    final median = _currentExam.medianScore;
    final stdDev = _currentExam.standardDeviation;
    final qRates = _currentExam.questionSuccessRates;
    final qAvgs = _currentExam.questionAverages;
    final dist = _currentExam.gradeDistribution;

    final sortedStudents = List<StudentExamScore>.from(_currentExam.studentScores);
    if (_sortByScoreDescending) {
      sortedStudents.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    } else {
      sortedStudents.sort((a, b) => a.studentNumber.compareTo(b.studentNumber));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      appBar: CustomAppBar(
        title: '${_currentExam.className} - ${_currentExam.examTitle}',
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // 1. ÜST ÖZET KARTI & MEB PDF BUTONU
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_currentExam.className} • ${_currentExam.subjectName}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentExam.examTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Aksiyon Butonları (Düzenle & Sil)
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExamAnalysisEditorView(existingExam: _currentExam),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                            tooltip: 'Düzenle',
                          ),
                          IconButton(
                            onPressed: _deleteExam,
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            tooltip: 'Sil',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Resmî MEB PDF Raporu İndir Butonu
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => ExamAnalysisPdfGenerator.generateAndShare(
                        context: context,
                        exam: _currentExam,
                        teacherProfile: teacherProfile,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'Resmî MEB Sınav Analiz Raporunu İndir (PDF)',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. TEMEL KPI METRİKLERİ (4'lü Bento Kartı)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Sınıf Ortalaması',
                    value: avg.toStringAsFixed(1),
                    color: avg >= 70 ? Colors.green : avg >= 50 ? Colors.amber : Colors.red,
                    icon: Icons.speed_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Başarı Oranı (>=50)',
                    value: '%${passRate.toStringAsFixed(0)}',
                    color: passRate >= 70 ? Colors.blue : Colors.orange,
                    icon: Icons.verified_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'En Yüksek / En Düşük',
                    value: '${highest.toStringAsFixed(0)} / ${lowest.toStringAsFixed(0)}',
                    color: Colors.purple,
                    icon: Icons.stacked_line_chart_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Medyan / Sapma',
                    value: '${median.toStringAsFixed(0)} (±${stdDev.toStringAsFixed(1)})',
                    color: Colors.teal,
                    icon: Icons.query_stats_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. SORU BAZINDA BAŞARI ORANLARI GRAFİĞİ
            if (_currentExam.isQuestionBased && qRates.isNotEmpty) ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Soru Bazlı Başarı & Zorluk Analizi',
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...qRates.entries.map((e) {
                      final qIdx = e.key;
                      final rate = e.value;
                      final maxP = _currentExam.questionMaxScores[qIdx];
                      final avgP = qAvgs[qIdx] ?? 0.0;

                      final color = rate >= 70
                          ? const Color(0xFF10B981)
                          : rate >= 50
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444);

                      final difficultyTag = rate >= 70
                          ? 'Kolay'
                          : rate >= 50
                              ? 'Orta'
                              : 'Zor';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'S${qIdx + 1} (${maxP.toStringAsFixed(0)}p)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        difficultyTag,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Ort: ${avgP.toStringAsFixed(1)}p  (%${rate.toStringAsFixed(0)})',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (rate / 100.0).clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. NOT DAĞILIMI HİSTOGRAMI
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF8B5CF6), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Not Dağılım Aralıkları',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: dist.entries.map((e) {
                      final isGreen = e.key.contains('Pekiyi');
                      final isBlue = e.key.contains('İyi');
                      final isAmber = e.key.contains('Orta');
                      final color = isGreen
                          ? const Color(0xFF10B981)
                          : isBlue
                              ? const Color(0xFF3B82F6)
                              : isAmber
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444);

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${e.value}',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.key.split(' ').first,
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. ÖĞRENCİ PUAN LİSTESİ TABLOSU
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.list_alt_rounded, color: Colors.orange, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Öğrenci Not Listesi (${sortedStudents.length})',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _toggleSort,
                        icon: Icon(
                          _sortByScoreDescending ? Icons.arrow_downward_rounded : Icons.sort_by_alpha_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          _sortByScoreDescending ? 'Puana Göre' : 'Numaraya Göre',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedStudents.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = sortedStudents[index];
                      final isPassed = s.totalScore >= 50.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (isPassed ? Colors.green : Colors.red).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                s.studentNumber > 0 ? s.studentNumber.toString() : '${index + 1}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPassed ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.studentName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_currentExam.isQuestionBased && s.questionScores.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      s.questionScores.asMap().entries.map((e) => 'S${e.key + 1}:${e.value.toStringAsFixed(0)}').join('  '),
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isPassed ? Colors.green : Colors.red).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${s.totalScore.toStringAsFixed(0)} Puan',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isPassed ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
