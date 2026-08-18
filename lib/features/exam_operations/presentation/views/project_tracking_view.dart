import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/class_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../data/models/project_tracking_model.dart';
import '../../providers/project_tracking_provider.dart';

/// SınıfCepte - 2/3: Proje & Performans Takibi (Şirin & Kompakt Tasarım)
class ProjectTrackingView extends ConsumerStatefulWidget {
  const ProjectTrackingView({super.key});

  @override
  ConsumerState<ProjectTrackingView> createState() => _ProjectTrackingViewState();
}

class _ProjectTrackingViewState extends ConsumerState<ProjectTrackingView> {
  final List<String> _subjects = const [
    'Fen Bilimleri',
    'Matematik',
    'Türkçe',
    'Sosyal Bilgiler',
    'İngilizce',
    'Din Kültürü',
    'Bilişim Teknolojileri',
    'Görsel Sanatlar',
    'Müzik',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'Genel',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProjectsIfNeeded();
    });
  }

  void _initProjectsIfNeeded() {
    final classesAsync = ref.read(classListProvider);
    classesAsync.whenData((classes) {
      if (classes.isNotEmpty) {
        final currentClass = ref.read(selectedProjectClassProvider);
        final selectedClass = currentClass ?? classes.first;
        if (currentClass == null) {
          ref.read(selectedProjectClassProvider.notifier).state = selectedClass;
        }

        final subject = ref.read(selectedProjectSubjectProvider);
        _loadProjectsForClass(selectedClass, subject);
      }
    });
  }

  void _loadProjectsForClass(ClassModel selectedClass, String subject) async {
    if (selectedClass.id == null) return;
    final students = await ref.read(studentRepositoryProvider).getStudentsByClassId(selectedClass.id!);
    ref.read(projectTrackingProvider.notifier).loadProjects(
          className: selectedClass.name,
          subject: subject,
          students: students,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classesAsync = ref.watch(classListProvider);
    final selectedClass = ref.watch(selectedProjectClassProvider);
    final selectedSubject = ref.watch(selectedProjectSubjectProvider);
    final state = ref.watch(projectTrackingProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      extendBody: true,
      appBar: const CustomAppBar(
        title: 'Proje & Ödev Değerlendirme',
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: classesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Hata: $err')),
          data: (classes) {
            if (classes.isEmpty) {
              return _buildEmptyClassState(context, isDark);
            }

            return Column(
              children: [
                // 1. Şirin Sınıf & Ders Seçim Kapsülleri
                _buildCuteFilterBar(context, isDark, classes, selectedClass, selectedSubject),

                // 2. Kompakt 4'lü İstatistik Şeridi
                if (state.projects.isNotEmpty)
                  _buildCuteStatsBanner(context, isDark, state),

                // 3. Şirin Öğrenci & Proje Kartları
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildCuteProjectList(context, isDark, state),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: ref.watch(navigationIndexProvider),
        onTap: (index) {
          try {
            ref.read(navigationIndexProvider.notifier).state = index;
            Navigator.of(context).popUntil((route) => route.isFirst);
          } catch (e, stackTrace) {
            debugPrint('ProjectTrackingView bottom nav tap error: $e\n$stackTrace');
          }
        },
      ),
    );
  }

  Widget _buildCuteFilterBar(
    BuildContext context,
    bool isDark,
    List<ClassModel> classes,
    ClassModel? selectedClass,
    String selectedSubject,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ClassModel>(
                  value: selectedClass ?? (classes.isNotEmpty ? classes.first : null),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  items: classes.map((c) {
                    return DropdownMenuItem<ClassModel>(
                      value: c,
                      child: Row(
                        children: [
                          const Text('🏫 ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Text(
                              c.name,
                              style: AppFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newClass) {
                    if (newClass != null) {
                      ref.read(selectedProjectClassProvider.notifier).state = newClass;
                      _loadProjectsForClass(newClass, selectedSubject);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            flex: 5,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _subjects.contains(selectedSubject) ? selectedSubject : _subjects.first,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  items: _subjects.map((sub) {
                    return DropdownMenuItem<String>(
                      value: sub,
                      child: Row(
                        children: [
                          const Text('📚 ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Text(
                              sub,
                              style: AppFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newSub) {
                    if (newSub != null && selectedClass != null) {
                      ref.read(selectedProjectSubjectProvider.notifier).state = newSub;
                      _loadProjectsForClass(selectedClass, newSub);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuteStatsBanner(
    BuildContext context,
    bool isDark,
    ProjectTrackingState state,
  ) {
    final submittedCount = state.projects.where((p) => p.isSubmitted).length;
    final evaluatedCount = state.projects.where((p) => p.isEvaluated).length;
    final avg = state.averageScore;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EEF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('Öğrenci', '${state.projects.length}', '👥', AppColors.primary, isDark),
          _buildMiniStat('Teslim', '$submittedCount/${state.projects.length}', '📥', Colors.teal, isDark),
          _buildMiniStat('Puanlı', '$evaluatedCount', '✍️', Colors.indigo, isDark),
          _buildMiniStat('Ortalama', avg != null ? avg.toStringAsFixed(1) : '-', '⭐', Colors.amber.shade800, isDark),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, String emoji, Color color, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(
              value,
              style: AppFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppFonts.outfit(
            fontSize: 10,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCuteProjectList(
    BuildContext context,
    bool isDark,
    ProjectTrackingState state,
  ) {
    if (state.projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              'Bu sınıfta henüz öğrenci bulunmuyor.',
              style: AppFonts.outfit(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
      itemCount: state.projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final project = state.projects[index];
        final isEvaluated = project.isEvaluated && project.totalScore != null;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EEF5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isEvaluated
                          ? Colors.teal.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        project.studentName.isNotEmpty ? project.studentName[0] : 'Ö',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isEvaluated ? Colors.teal : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        project.studentName,
                        style: AppFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isEvaluated)
                      InkWell(
                        onTap: () => _openRubricModal(context, isDark, project, state.criteria),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: _getScoreBgColor(project.totalScore!, isDark),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getScoreTextColor(project.totalScore!).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '⭐ ${project.totalScore}/100',
                                style: AppFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _getScoreTextColor(project.totalScore!),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit_rounded, size: 11, color: _getScoreTextColor(project.totalScore!)),
                            ],
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => _openRubricModal(context, isDark, project, state.criteria),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fact_check_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Değerlendir',
                                style: AppFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _editTopicDialog(context, isDark, project),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('📌 ', style: TextStyle(fontSize: 10.5)),
                        Expanded(
                          child: Text(
                            project.homeworkTopic.isNotEmpty
                                ? project.homeworkTopic
                                : 'Ödev/Proje konusu girilmedi (Dokunun)',
                            style: AppFonts.outfit(
                              fontSize: 11,
                              fontStyle: project.homeworkTopic.isEmpty ? FontStyle.italic : FontStyle.normal,
                              color: project.homeworkTopic.isNotEmpty
                                  ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.edit_note_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        if (project.id != null) {
                          ref.read(projectTrackingProvider.notifier).toggleSubmission(project.id!, !project.isSubmitted);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              project.isSubmitted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: project.isSubmitted ? Colors.teal : Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              project.isSubmitted ? 'Ödev Teslim Edildi' : 'Teslim Bekleniyor',
                              style: AppFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: project.isSubmitted ? Colors.teal : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getScoreTextColor(int score) {
    if (score >= 85) return const Color(0xFF16A34A);
    if (score >= 70) return const Color(0xFF2563EB);
    if (score >= 50) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  Color _getScoreBgColor(int score, bool isDark) {
    final color = _getScoreTextColor(score);
    return color.withValues(alpha: isDark ? 0.2 : 0.1);
  }

  void _editTopicDialog(BuildContext context, bool isDark, ProjectTakipModel project) {
    final controller = TextEditingController(text: project.homeworkTopic);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Ödev / Proje Konusu',
                style: AppFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppFonts.outfit(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ödev veya proje başlığı girin...',
              hintStyle: AppFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal', style: AppFonts.outfit(fontSize: 12.5)),
            ),
            ElevatedButton(
              onPressed: () {
                final topic = controller.text.trim();
                if (topic.isNotEmpty && project.id != null) {
                  ref.read(projectTrackingProvider.notifier).updateTopic(project.id!, topic);
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Kaydet', style: AppFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _openRubricModal(
    BuildContext context,
    bool isDark,
    ProjectTakipModel project,
    List<ProjectKriterModel> criteria,
  ) async {
    if (project.id == null) return;

    final initialScores = await ref.read(projectTrackingProvider.notifier).loadProjectScores(project.id!);
    final Map<int, int> currentScores = Map.from(initialScores);

    if (currentScores.isEmpty) {
      for (final c in criteria) {
        if (c.id != null) {
          currentScores[c.id!] = 10;
        }
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            int calculateTotal() {
              return currentScores.values.fold(0, (acc, s) => acc + s);
            }

            final total = calculateTotal();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: const Center(
                          child: Icon(Icons.fact_check_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.studentName,
                              style: AppFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'MEB 100 Puanlık Rubric Ölçeği',
                              style: AppFonts.outfit(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getScoreBgColor(total, isDark),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getScoreTextColor(total).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$total / 100',
                          style: AppFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _getScoreTextColor(total),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            for (final c in criteria) {
                              if (c.id != null) {
                                currentScores[c.id!] = c.maxScore;
                              }
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⚡ ', style: TextStyle(fontSize: 11)),
                              Text(
                                'Tam Puan Ver (100)',
                                style: AppFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: criteria.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (cCtx, cIdx) {
                        final criterion = criteria[cIdx];
                        final criterionId = criterion.id ?? 0;
                        final currentVal = currentScores[criterionId] ?? criterion.maxScore;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${cIdx + 1}. ${criterion.title}',
                                      style: AppFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$currentVal/10',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [10, 8, 5, 0].map((scoreOption) {
                                  final isSelected = currentVal == scoreOption;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          currentScores[criterionId] = scoreOption;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$scoreOption p.',
                                          style: AppFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        await ref.read(projectTrackingProvider.notifier).saveEvaluation(
                              projectId: project.id!,
                              criteriaScores: currentScores,
                              totalScore: total,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.task_alt_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Değerlendirmeyi Kaydet ($total Puan)',
                            style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyClassState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏫', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Henüz Kayıtlı Sınıfınız Yok',
            style: AppFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Proje takibi için önce bir sınıf oluşturmalısınız.',
            style: AppFonts.outfit(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
