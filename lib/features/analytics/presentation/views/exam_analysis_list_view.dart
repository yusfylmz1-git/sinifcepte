import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/exam_analysis_model.dart';
import '../../providers/exam_analysis_provider.dart';
import '../../utils/exam_analysis_pdf_generator.dart';
import 'exam_analysis_detail_view.dart';
import 'exam_analysis_editor_view.dart';

/// SınıfCepte - Kayıtlı Sınav Analizleri Listesi (UI-UX-MAX)
class ExamAnalysisListView extends ConsumerStatefulWidget {
  const ExamAnalysisListView({super.key});

  @override
  ConsumerState<ExamAnalysisListView> createState() => _ExamAnalysisListViewState();
}

class _ExamAnalysisListViewState extends ConsumerState<ExamAnalysisListView> {
  String _selectedClassFilter = 'Tümü';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examsAsync = ref.watch(examAnalysisListProvider);
    final teacherProfile = ref.watch(teacherProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      extendBody: true,
      appBar: const CustomAppBar(
        title: 'Sınav Analizleri',
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: examsAsync.when(
          data: (exams) {
            // Sınıf Listesi Filtresi
            final classes = {'Tümü', ...exams.map((e) => e.className).where((c) => c.isNotEmpty)};

            // Filtrelenmiş liste
            final filteredExams = exams.where((e) {
              final matchesClass = _selectedClassFilter == 'Tümü' || e.className == _selectedClassFilter;
              final matchesSearch = _searchQuery.isEmpty ||
                  e.examTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  e.subjectName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  e.className.toLowerCase().contains(_searchQuery.toLowerCase());
              return matchesClass && matchesSearch;
            }).toList();

            return Column(
              children: [
                // Arama ve Sınıf Filtresi Barı
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    children: [
                      // Arama Alanı
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: AppFonts.outfit(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Sınav adı veya ders ara...',
                          hintStyle: AppFonts.outfit(fontSize: 13, color: Colors.grey),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Sınıf Filtre Butonları
                      if (classes.length > 2)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: classes.map((c) {
                              final isSelected = _selectedClassFilter == c;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedClassFilter = c);
                                    }
                                  },
                                  selectedColor: AppColors.primary,
                                  labelStyle: AppFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),

                // Liste Alanı
                Expanded(
                  child: filteredExams.isEmpty
                      ? _buildEmptyState(context, isDark, exams.isEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 95),
                          itemCount: filteredExams.length,
                          itemBuilder: (context, index) {
                            final exam = filteredExams[index];
                            return _buildExamCard(context, exam, isDark, teacherProfile);
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('Sınavlar yüklenirken bir hata oluştu: $err'),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamAnalysisEditorView()),
            );
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
          label: Text(
            'Yeni Sınav Analizi',
            style: AppFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: ref.watch(navigationIndexProvider),
        onTap: (index) {
          try {
            ref.read(navigationIndexProvider.notifier).state = index;
            Navigator.of(context).popUntil((route) => route.isFirst);
          } catch (e, stackTrace) {
            debugPrint('ExamAnalysisListView bottom nav tap error: $e\n$stackTrace');
          }
        },
      ),
    );
  }

  Widget _buildExamCard(
    BuildContext context,
    ExamAnalysisModel exam,
    bool isDark,
    dynamic teacherProfile,
  ) {
    final avg = exam.classAverage;
    final passRate = exam.passRate;
    final avgColor = avg >= 70 ? Colors.green : avg >= 50 ? Colors.amber : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ExamAnalysisDetailView(exam: exam)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, const Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  exam.className,
                                  style: AppFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  exam.subjectName,
                                  style: AppFonts.outfit(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            exam.examTitle,
                            style: AppFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => ExamAnalysisPdfGenerator.generateAndShare(
                        context: context,
                        exam: exam,
                        teacherProfile: teacherProfile,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                      tooltip: 'MEB PDF Raporu Al',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Alt İstatistik Rozetleri
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatChip(
                      label: 'Ortalama',
                      value: avg.toStringAsFixed(1),
                      color: avgColor,
                      isDark: isDark,
                    ),
                    _buildStatChip(
                      label: 'Başarı',
                      value: '%${passRate.toStringAsFixed(0)}',
                      color: passRate >= 70 ? Colors.blue : Colors.orange,
                      isDark: isDark,
                    ),
                    _buildStatChip(
                      label: 'Öğrenci',
                      value: '${exam.studentCount}',
                      color: Colors.purple,
                      isDark: isDark,
                    ),
                    _buildStatChip(
                      label: 'Soru',
                      value: exam.isQuestionBased ? '${exam.questionCount} Soru' : 'Klasik',
                      color: Colors.teal,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppFonts.outfit(
              fontSize: 9.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: AppFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, bool noExamsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics_outlined, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              noExamsAtAll ? 'Henüz Sınav Analizi Eklenmedi' : 'Filtreye Uygun Sınav Bulunamadı',
              style: AppFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              noExamsAtAll
                  ? 'Soru bazlı sınav analizi oluşturarak başarı grafiklerini inceleyebilir ve resmi MEB PDF raporları alabilirsiniz.'
                  : 'Farklı bir arama terimi veya sınıf filtresi deneyebilirsiniz.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (noExamsAtAll)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExamAnalysisEditorView()),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('İlk Sınav Analizini Oluştur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
