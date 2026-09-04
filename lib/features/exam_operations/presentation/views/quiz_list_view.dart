import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/class_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../data/models/quiz_tracking_model.dart';
import '../../data/services/score_input.dart';
import '../../providers/quiz_tracking_provider.dart';

/// SınıfCepte - 1/3: Quiz & Sözlü Takip Dinamik Çizelgesi (Şirin & Kompakt Tasarım)
class QuizListView extends ConsumerStatefulWidget {
  const QuizListView({super.key});

  @override
  ConsumerState<QuizListView> createState() => _QuizListViewState();
}

class _QuizListViewState extends ConsumerState<QuizListView> {
  final List<String> _subjects = const [
    'Matematik',
    'Türkçe',
    'Fen Bilimleri',
    'Sosyal Bilgiler',
    'İngilizce',
    'Din Kültürü',
    'Bilişim Teknolojileri',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Tarih',
    'Coğrafya',
    'Edebiyat',
    'Genel',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTableIfNeeded();
    });
  }

  void _initTableIfNeeded() {
    final classesAsync = ref.read(classListProvider);
    classesAsync.whenData((classes) {
      if (classes.isNotEmpty) {
        final currentClass = ref.read(selectedQuizClassProvider);
        final selectedClass = currentClass ?? classes.first;
        if (currentClass == null) {
          ref.read(selectedQuizClassProvider.notifier).state = selectedClass;
        }

        final subject = ref.read(selectedQuizSubjectProvider);
        _loadTableForClass(selectedClass, subject);
      }
    });
  }

  void _loadTableForClass(ClassModel selectedClass, String subject) async {
    if (selectedClass.id == null) return;
    final students = await ref.read(studentRepositoryProvider).getStudentsByClassId(selectedClass.id!);
    ref.read(quizTableProvider.notifier).loadTable(
          className: selectedClass.name,
          subject: subject,
          students: students,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classesAsync = ref.watch(classListProvider);
    final selectedClass = ref.watch(selectedQuizClassProvider);
    final selectedSubject = ref.watch(selectedQuizSubjectProvider);
    final tableState = ref.watch(quizTableProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      extendBody: true,
      appBar: const CustomAppBar(
        title: 'Quiz & Sözlü Not Çizelgesi',
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
                // 1. Şirin Sınıf & Ders Seçici Kapsüller
                _buildCuteFilterBar(context, isDark, classes, selectedClass, selectedSubject),

                // 2. Dinamik Kompakt Not Tablosu
                Expanded(
                  child: tableState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildCuteTableContent(context, isDark, tableState),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.38),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAddColumnModal(context, isDark),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_chart_rounded, color: Colors.white, size: 19),
                  const SizedBox(width: 6),
                  Text(
                    'Kolon Ekle',
                    style: AppFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
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
            debugPrint('QuizListView bottom nav tap error: $e\n$stackTrace');
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
          // Sınıf Seçimi
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
                      ref.read(selectedQuizClassProvider.notifier).state = newClass;
                      _loadTableForClass(newClass, selectedSubject);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Ders Seçimi
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
                      ref.read(selectedQuizSubjectProvider.notifier).state = newSub;
                      _loadTableForClass(selectedClass, newSub);
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

  Widget _buildCuteTableContent(
    BuildContext context,
    bool isDark,
    QuizTableState tableState,
  ) {
    if (tableState.students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              'Bu sınıfta henüz kayıtlı öğrenci bulunmuyor.',
              style: AppFonts.outfit(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final overallAvg = tableState.calculateOverallClassAverage();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 85),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EEF5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              ),
              headingRowHeight: 42,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              horizontalMargin: 12,
              columnSpacing: 12,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EEF5),
                  width: 0.8,
                ),
              ),
              columns: [
                // Sabit Öğrenci Sütunu
                DataColumn(
                  label: Text(
                    '👤 Öğrenci',
                    style: AppFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),

                // Dinamik Kolonlar
                ...tableState.columns.map((kolon) {
                  return DataColumn(
                    label: InkWell(
                      onLongPress: () => _confirmDeleteColumn(context, kolon),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getKolonEmoji(kolon.tip),
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              kolon.title,
                              style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Ortalama Sütunu
                DataColumn(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⭐ Ort.',
                      style: AppFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ),
              ],
              rows: [
                // Öğrenci Not Satırları (Zebra Efektli)
                ...tableState.students.asMap().entries.map((entry) {
                  final index = entry.key;
                  final student = entry.value;
                  final studentId = student.id ?? 0;
                  final avg = tableState.calculateStudentAverage(studentId);
                  final isEven = index.isEven;

                  return DataRow(
                    color: WidgetStatePropertyAll(
                      isEven
                          ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                          : (isDark ? const Color(0xFF172033) : const Color(0xFFF8FAFC)),
                    ),
                    cells: [
                      // Öğrenci Adı & No
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                student.schoolNumber > 0 ? '${student.schoolNumber}' : '-',
                                style: AppFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${student.firstName} ${student.lastName}',
                              style: AppFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Dinamik Not Hücreleri (Dokunulabilir Sevimli Kapsüller)
                      ...tableState.columns.map((kolon) {
                        final score = tableState.studentScores[studentId]?[kolon.id];

                        return DataCell(
                          Center(
                            child: InkWell(
                              onTap: () => _editScoreDialog(context, isDark, kolon, student, score),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 44,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: score != null
                                      ? _getScoreBgColor(score, isDark)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: score != null
                                        ? _getScoreTextColor(score).withValues(alpha: 0.4)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: score != null ? 1 : 0.8,
                                  ),
                                ),
                                child: Text(
                                  score != null ? '$score' : '—',
                                  style: AppFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: score != null ? FontWeight.w800 : FontWeight.normal,
                                    color: score != null
                                        ? _getScoreTextColor(score)
                                        : (isDark ? Colors.white30 : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Öğrenci Canlı Ortalaması
                      DataCell(
                        Center(
                          child: Container(
                            width: 44,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: avg != null
                                  ? _getScoreBgColor(avg.toInt(), isDark)
                                  : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              avg != null ? avg.toStringAsFixed(1) : '—',
                              style: AppFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                color: avg != null
                                    ? _getScoreTextColor(avg.toInt())
                                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                // Alt Toplam Satırı (Sınıf Genel Ortalaması)
                DataRow(
                  color: WidgetStatePropertyAll(
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  ),
                  cells: [
                    DataCell(
                      Text(
                        '⭐ Sınıf Ortalaması',
                        style: AppFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    ...tableState.columns.map((kolon) {
                      final colAvg = tableState.calculateColumnAverage(kolon.id ?? 0);
                      return DataCell(
                        Center(
                          child: Container(
                            width: 44,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              colAvg != null ? colAvg.toStringAsFixed(1) : '—',
                              style: AppFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    DataCell(
                      Center(
                        child: Container(
                          width: 48,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            overallAvg != null ? overallAvg.toStringAsFixed(1) : '—',
                            style: AppFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ),
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


  String _getKolonEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return '📝';
      case 'sozlu':
        return '🗣️';
      case 'dinleme':
        return '🎧';
      case 'odev':
        return '📚';
      default:
        return '📊';
    }
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

  /// Modern Not Düzenleme / Puan Giriş Modalı
  void _editScoreDialog(
    BuildContext context,
    bool isDark,
    QuizKolonModel kolon,
    dynamic student,
    int? currentScore,
  ) {
    final controller = TextEditingController(text: currentScore != null ? '$currentScore' : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  student.firstName.isNotEmpty ? student.firstName[0] : 'Ö',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.lastName}',
                      style: AppFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${kolon.title} (${student.schoolNumber > 0 ? "No: ${student.schoolNumber}" : "Öğrenci"})',
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                // Klavye tipi tek basina yetmiyor: Android'de bircok klavye
                // sayi modunda bile "-" ve "," tuslarini gosteriyor.
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                autofocus: true,
                textAlign: TextAlign.center,
                style: AppFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  hintText: '0 - 100',
                  hintStyle: AppFonts.outfit(fontSize: 18, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Hızlı Puan Butonları
              Text(
                'HIZLI PUAN SEÇİMİ',
                style: AppFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [100, 95, 90, 85, 75, 60, 50, 0].map((quick) {
                  return InkWell(
                    onTap: () => controller.text = '$quick',
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: quick >= 85
                            ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                            : (quick >= 50
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: quick >= 85
                              ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                              : (quick >= 50
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : Colors.red.withValues(alpha: 0.25)),
                        ),
                      ),
                      child: Text(
                        '$quick',
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: quick >= 85
                              ? const Color(0xFF16A34A)
                              : (quick >= 50 ? AppColors.primary : Colors.red),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            if (currentScore != null)
              TextButton(
                onPressed: () {
                  ref.read(quizTableProvider.notifier).updateScore(
                        columnId: kolon.id!,
                        studentId: student.id!,
                        score: null,
                      );
                  Navigator.pop(ctx);
                },
                child: Text('Notu Sil', style: AppFonts.outfit(color: Colors.red.shade400, fontSize: 12.5)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal', style: AppFonts.outfit(fontSize: 12.5)),
            ),
            ElevatedButton(
              onPressed: () {
                // Eskiden dogrudan int.tryParse okunuyordu. "abc" yazilinca
                // null donuyor ve mevcut not SESSIZCE siliniyordu; 955
                // yazilinca da haber vermeden 100'e kirpiliyordu.
                final parsed = parseScoreInput(controller.text);

                if (!parsed.canSave) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(parsed.errorMessage!),
                      backgroundColor: Colors.red.shade600,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return; // Diyalog acik kalir, ogretmen duzeltebilir.
                }

                ref.read(quizTableProvider.notifier).updateScore(
                      columnId: kolon.id!,
                      studentId: student.id!,
                      score: parsed.score,
                    );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Kaydet', style: AppFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Modern ve Tasarım Bütünlüğü Olan "Yeni Değerlendirme Kolonu Ekle" Modal BottomSheet
  void _showAddColumnModal(BuildContext context, bool isDark) {
    final titleController = TextEditingController(text: '1. Quiz');
    String selectedType = 'quiz';

    final presets = [
      {'title': '1. Quiz', 'type': 'quiz'},
      {'title': '2. Quiz', 'type': 'quiz'},
      {'title': '1. Sözlü', 'type': 'sozlu'},
      {'title': '2. Sözlü', 'type': 'sozlu'},
      {'title': 'Dinleme 1', 'type': 'dinleme'},
      {'title': '1. Ödev', 'type': 'odev'},
      {'title': 'Deneme 1', 'type': 'quiz'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tutamaç Barı
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Başlık Satırı
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF2563EB),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.view_column_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Yeni Değerlendirme Kolonu',
                                style: AppFonts.outfit(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Quiz, sözlü, dinleme veya ödev çizelgesi oluşturun',
                                style: AppFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Kolon Başlığı
                    Text(
                      'KOLON BAŞLIĞI',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      maxLength: 40,
                      style: AppFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Örn: 2. Quiz, 1. Sözlü, Dinleme',
                        hintStyle: AppFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.primary),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hızlı Başlık Şablonları
                    Text(
                      'HAZIR ŞABLONLAR',
                      style: AppFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presets.map((p) {
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              titleController.text = p['title']!;
                              selectedType = p['type']!;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              p['title']!,
                              style: AppFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 2. Değerlendirme Türü
                    Text(
                      'DEĞERLENDİRME TÜRÜ',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTypeOption('quiz', '📝 Quiz', selectedType, isDark, (t) => setModalState(() => selectedType = t)),
                        const SizedBox(width: 6),
                        _buildTypeOption('sozlu', '🗣️ Sözlü', selectedType, isDark, (t) => setModalState(() => selectedType = t)),
                        const SizedBox(width: 6),
                        _buildTypeOption('dinleme', '🎧 Dinleme', selectedType, isDark, (t) => setModalState(() => selectedType = t)),
                        const SizedBox(width: 6),
                        _buildTypeOption('odev', '📚 Ödev', selectedType, isDark, (t) => setModalState(() => selectedType = t)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3. Ekle Butonu
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
                          final title = titleController.text.trim();
                          if (title.isNotEmpty) {
                            await ref.read(quizTableProvider.notifier).addColumn(
                                  title: title,
                                  type: selectedType,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
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
                            const Icon(Icons.add_chart_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Kolonu Tabloya Ekle',
                              style: AppFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeOption(
    String type,
    String label,
    String currentSelected,
    bool isDark,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = type == currentSelected;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(type),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            style: AppFonts.outfit(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _confirmDeleteColumn(BuildContext context, QuizKolonModel kolon) {
    // Kac notun gidecegini onceden goster. "tum notlar" ifadesi tek basina
    // ogretmene 3 not mu 30 not mu kaybedecegini soylemiyordu.
    final notSayisi = ref
        .read(quizTableProvider)
        .studentScores
        .values
        .where((kolonlar) => kolonlar.containsKey(kolon.id))
        .length;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Kolonu Sil', style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text(
            notSayisi > 0
                ? '"${kolon.title}" kolonu ve bu kolona girilmiş '
                    '$notSayisi öğrenci notu kalıcı olarak silinecek. '
                    'Bu işlem geri alınamaz.'
                : '"${kolon.title}" kolonunu silmek istediğinizden emin misiniz? '
                    'Bu kolona henüz not girilmemiş.',
            style: AppFonts.outfit(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (kolon.id != null) {
                  ref.read(quizTableProvider.notifier).deleteColumn(kolon.id!);
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Sil'),
            ),
          ],
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
            'Quiz ve sözlü notu girmek için önce bir sınıf oluşturmalısınız.',
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
