import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../classes/providers/class_provider.dart';
import '../../data/models/exam_analysis_model.dart';
import '../../providers/exam_analysis_provider.dart';
import 'exam_analysis_detail_view.dart';

/// SınıfCepte - Sınav Analizi Oluşturma ve Düzenleme Ekranı (UI-UX-MAX)
class ExamAnalysisEditorView extends ConsumerStatefulWidget {
  final ExamAnalysisModel? existingExam;

  const ExamAnalysisEditorView({super.key, this.existingExam});

  @override
  ConsumerState<ExamAnalysisEditorView> createState() => _ExamAnalysisEditorViewState();
}

class _ExamAnalysisEditorViewState extends ConsumerState<ExamAnalysisEditorView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _dateController;
  late TextEditingController _questionScoresController;

  String _selectedClassName = '';
  String _examType = 'soru_bazli'; // 'soru_bazli' veya 'klasik'
  List<double> _parsedQuestionScores = [10, 10, 15, 15, 25, 25];
  List<StudentExamScore> _studentScores = [];
  bool _isLoadingStudents = false;

  // Her öğrenci için TextEditingController haritası
  final Map<int, TextEditingController> _studentScoreControllers = {};

  @override
  void initState() {
    super.initState();
    final exam = widget.existingExam;

    _titleController = TextEditingController(text: exam?.examTitle ?? '1. Dönem 1. Yazılı');
    _subjectController = TextEditingController(text: exam?.subjectName ?? '');
    _dateController = TextEditingController(
      text: exam?.examDate ?? DateTime.now().toString().substring(0, 10),
    );

    if (exam != null) {
      _selectedClassName = exam.className;
      _examType = exam.examType;
      _parsedQuestionScores = List<double>.from(exam.questionMaxScores);
      _questionScoresController = TextEditingController(
        text: _parsedQuestionScores.map((s) => s.toStringAsFixed(0)).join(' '),
      );
      _studentScores = List<StudentExamScore>.from(exam.studentScores);
      for (int i = 0; i < _studentScores.length; i++) {
        final s = _studentScores[i];
        final text = exam.isQuestionBased
            ? s.questionScores.map((q) => q.toStringAsFixed(0)).join(' ')
            : s.totalScore.toStringAsFixed(0);
        _studentScoreControllers[i] = TextEditingController(text: text);
      }
    } else {
      _questionScoresController = TextEditingController(text: '10 10 15 15 25 25');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _dateController.dispose();
    _questionScoresController.dispose();
    for (final c in _studentScoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudentsForClass(String className) async {
    if (className.isEmpty) return;
    setState(() => _isLoadingStudents = true);

    try {
      final repo = ref.read(examAnalysisRepositoryProvider);
      final rawStudents = await repo.getStudentsForClass(className);

      final List<StudentExamScore> loaded = [];
      _studentScoreControllers.clear();

      for (int i = 0; i < rawStudents.length; i++) {
        final r = rawStudents[i];
        final firstName = r['first_name'] as String? ?? '';
        final lastName = r['last_name'] as String? ?? '';
        final schoolNo = (r['school_number'] as int?) ?? (i + 1);

        loaded.add(StudentExamScore(
          studentId: r['id'] as int?,
          studentName: '$firstName $lastName'.trim(),
          studentNumber: schoolNo,
          questionScores: List.filled(_parsedQuestionScores.length, 0.0),
          totalScore: 0.0,
        ));

        _studentScoreControllers[i] = TextEditingController(text: '');
      }

      setState(() {
        _studentScores = loaded;
        _isLoadingStudents = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Öğrenci yükleme hatası: $e\n$stackTrace');
      setState(() => _isLoadingStudents = false);
    }
  }

  void _onQuestionScoresChanged(String val) {
    setState(() {
      _parsedQuestionScores = InputSanitizer.parseSpaceSeparatedScores(val);
      // Öğrencilerin soru puanlarını yeni soru sayısına uyarla
      for (int i = 0; i < _studentScores.length; i++) {
        final old = _studentScores[i];
        final newScores = List<double>.generate(_parsedQuestionScores.length, (idx) {
          if (idx < old.questionScores.length) return old.questionScores[idx];
          return 0.0;
        });
        _studentScores[i] = old.copyWith(
          questionScores: newScores,
          totalScore: newScores.fold<double>(0.0, (double a, double b) => a + b),
        );
      }
    });
  }

  void _onStudentScoreInputChanged(int index, String rawInput) {
    if (index >= _studentScores.length) return;

    if (_examType == 'soru_bazli') {
      final scores = InputSanitizer.parseSpaceSeparatedScores(rawInput);
      final paddedScores = List<double>.generate(_parsedQuestionScores.length, (i) {
        if (i < scores.length) {
          final maxAllowed = _parsedQuestionScores[i];
          return scores[i].clamp(0.0, maxAllowed);
        }
        return 0.0;
      });
      final total = paddedScores.fold(0.0, (a, b) => a + b);

      setState(() {
        _studentScores[index] = _studentScores[index].copyWith(
          questionScores: paddedScores,
          totalScore: total,
        );
      });
    } else {
      final parsed = double.tryParse(rawInput.replaceAll(',', '.')) ?? 0.0;
      final total = parsed.clamp(0.0, 100.0);
      setState(() {
        _studentScores[index] = _studentScores[index].copyWith(
          questionScores: [total],
          totalScore: total,
        );
      });
    }
  }

  /// Öğretmen için hızlı rastgele gerçekçi puan doldurma (Test/Demo Asistanı)
  void _fillSampleScores() {
    for (int i = 0; i < _studentScores.length; i++) {
      final List<double> randomScores = [];
      for (final maxP in _parsedQuestionScores) {
        final earned = (maxP * (0.4 + (i % 6) * 0.12)).clamp(0.0, maxP);
        randomScores.add((earned / 2).round() * 2.0); // Çift sayılara yuvarla
      }
      final total = randomScores.fold(0.0, (a, b) => a + b);
      _studentScores[i] = _studentScores[i].copyWith(
        questionScores: randomScores,
        totalScore: total,
      );
      _studentScoreControllers[i]?.text = randomScores.map((s) => s.toStringAsFixed(0)).join(' ');
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tüm öğrencilere örnek puanlar otomatik dağıtıldı! ⚡')),
    );
  }

  Future<void> _saveExam() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir sınıf seçiniz!')),
      );
      return;
    }

    if (_examType == 'soru_bazli' && !InputSanitizer.validateTotalHundred(_parsedQuestionScores)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Soru puanları toplamı 100 olmalıdır! (Şu an: ${_parsedQuestionScores.fold(0.0, (a, b) => a + b).toStringAsFixed(0)})',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (_studentScores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sınav analizi için sınıfta en az 1 öğrenci bulunmalıdır!')),
      );
      return;
    }

    final examToSave = ExamAnalysisModel(
      id: widget.existingExam?.id,
      examTitle: _titleController.text.trim(),
      className: _selectedClassName,
      subjectName: _subjectController.text.trim().isNotEmpty
          ? _subjectController.text.trim()
          : 'Ders',
      examDate: _dateController.text.trim(),
      examType: _examType,
      questionMaxScores: _parsedQuestionScores,
      studentScores: _studentScores,
    );

    final savedId = await ref.read(examAnalysisListProvider.notifier).saveExam(examToSave);

    if (savedId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sınav Analizi başarıyla kaydedildi! 🚀'),
          backgroundColor: AppColors.success,
        ),
      );

      final savedExam = examToSave.copyWith(id: savedId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExamAnalysisDetailView(exam: savedExam),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classListAsync = ref.watch(classListProvider);

    final totalQuestionPoints = _parsedQuestionScores.fold(0.0, (a, b) => a + b);
    final isHundred = (totalQuestionPoints - 100.0).abs() < 0.001;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      appBar: CustomAppBar(
        title: widget.existingExam != null ? 'Sınav Analizini Düzenle' : 'Yeni Sınav Analizi',
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. SINAV ÜST BİLGİLERİ KARTI
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sınav & Sınıf Bilgileri',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Sınıf Seçimi
                    classListAsync.when(
                      data: (classes) {
                        if (classes.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: const Text('⚠️ Henüz eklenmiş bir sınıfınız bulunmuyor. Önce sınıflar sekmesinden sınıf ekleyin.'),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedClassName.isNotEmpty ? _selectedClassName : null,
                          hint: const Text('Sınıf Seçiniz'),
                          decoration: InputDecoration(
                            labelText: 'Sınıf *',
                            prefixIcon: const Icon(Icons.class_rounded, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: classes.map((c) {
                            return DropdownMenuItem(
                              value: c.name,
                              child: Text('${c.name} - ${c.subject}'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedClassName = val;
                                final matched = classes.firstWhere((c) => c.name == val);
                                if (_subjectController.text.isEmpty || _subjectController.text == 'Ders') {
                                  _subjectController.text = matched.subject;
                                }
                              });
                              _loadStudentsForClass(val);
                            }
                          },
                          validator: (val) => val == null ? 'Lütfen bir sınıf seçin' : null,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Sınıflar yüklenemedi: $err'),
                    ),
                    const SizedBox(height: 12),

                    // Sınav Başlığı & Ders Adı
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Sınav Başlığı *',
                              hintText: '1. Dönem 1. Yazılı',
                              prefixIcon: const Icon(Icons.assignment_rounded, size: 20),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Sınav başlığı giriniz' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _subjectController,
                            decoration: InputDecoration(
                              labelText: 'Ders Adı',
                              hintText: 'Matematik',
                              prefixIcon: const Icon(Icons.book_rounded, size: 20),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tarih Seçici
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Sınav Tarihi',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          _dateController.text = picked.toString().substring(0, 10);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. SORU PUAN DAĞILIMI KARTI (Space Duyarlı)
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.format_list_numbered_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Soru Puan Dağılımı',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isHundred ? Colors.green : Colors.red).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (isHundred ? Colors.green : Colors.red).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Toplam: ${totalQuestionPoints.toStringAsFixed(0)} / 100',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isHundred ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Soru puanlarını aralarında BOŞLUK veya VİRGÜL bırakarak yazın (Örn: 10 10 15 15 25 25 veya 10,10,15,15,25,25)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _questionScoresController,
                      keyboardType: TextInputType.text,
                      onChanged: _onQuestionScoresChanged,
                      decoration: InputDecoration(
                        hintText: '10 10 15 15 25 25',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        prefixIcon: const Icon(Icons.flash_on_rounded, color: Colors.amber),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hızlı Soru Puanı Şablonları
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickPresetChip('10x10p', '10 10 10 10 10 10 10 10 10 10'),
                        _buildQuickPresetChip('5x20p', '20 20 20 20 20'),
                        _buildQuickPresetChip('4x25p', '25 25 25 25'),
                        _buildQuickPresetChip('6 Soru', '10 10 15 15 25 25'),
                        _buildQuickPresetChip('8 Soru', '10 10 10 10 15 15 15 15'),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ayrıştırılan Soruların Rozetleri
                    if (_parsedQuestionScores.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _parsedQuestionScores.asMap().entries.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              'S${e.key + 1}: ${e.value.toStringAsFixed(0)}p',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. ÖĞRENCİ PUAN GİRİŞİ KARTI
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Öğrenci Not Girişi (${_studentScores.length})',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_studentScores.isNotEmpty)
                          TextButton.icon(
                            onPressed: _fillSampleScores,
                            icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.amber),
                            label: Text(
                              'Örnek Not',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_isLoadingStudents)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_studentScores.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _selectedClassName.isEmpty
                              ? 'Yukarıdan bir sınıf seçtiğinizde öğrenciler otomatik listelenecektir.'
                              : 'Bu sınıfta kayıtlı öğrenci bulunamadı.',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _studentScores.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final s = _studentScores[index];
                          final controller = _studentScoreControllers[index] ?? TextEditingController();

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        s.studentNumber > 0 ? s.studentNumber.toString() : '${index + 1}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        s.studentName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (s.totalScore >= 50 ? Colors.green : Colors.red).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Toplam: ${s.totalScore.toStringAsFixed(0)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: s.totalScore >= 50 ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: controller,
                                  keyboardType: TextInputType.text,
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    hintText: 'Soru puanları (Örn: 8 10 12 15 20 20 veya 8,10,12...)',
                                    hintStyle: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    suffixIcon: InkWell(
                                      onTap: () {
                                        final currentText = controller.text;
                                        final newText = currentText.isEmpty || currentText.endsWith(' ')
                                            ? currentText
                                            : '$currentText ';
                                        controller.text = newText;
                                        controller.selection = TextSelection.collapsed(offset: newText.length);
                                        _onStudentScoreInputChanged(index, newText);
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '⎵ Boşluk',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                  onChanged: (val) => _onStudentScoreInputChanged(index, val),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // KAYDET VE ANALİZ ET BUTONU
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
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _saveExam,
                  icon: const Icon(Icons.analytics_rounded, color: Colors.white),
                  label: Text(
                    'Sınavı Kaydet & Analiz Grafiğini Gör',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPresetChip(String label, String preset) {
    return InkWell(
      onTap: () {
        _questionScoresController.text = preset;
        _onQuestionScoresChanged(preset);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
