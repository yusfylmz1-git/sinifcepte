import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/services/whatsapp_share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../attendance/providers/classroom_participation_provider.dart';
import '../../providers/smart_comment_generator_provider.dart';
import '../../../../core/utils/search_debouncer.dart';
import '../../../../core/utils/turkish_text.dart';

enum CommentFilterStatus { all, excellent, good, needsSupport }

/// SınıfCepte - Sınıf Bazlı Gerçek Verili Otomatik e-Okul Karne Görüşü ve Seri Kopyalama Modülü
class ClassReportCardCommentsModal extends ConsumerStatefulWidget {
  final int? initialClassId;

  const ClassReportCardCommentsModal({super.key, this.initialClassId});

  static Future<void> show(BuildContext context, {int? initialClassId}) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassReportCardCommentsModal(initialClassId: initialClassId),
    );
  }

  @override
  ConsumerState<ClassReportCardCommentsModal> createState() =>
      _ClassReportCardCommentsModalState();
}

class _ClassReportCardCommentsModalState
    extends ConsumerState<ClassReportCardCommentsModal> {
  int? _selectedClassId;
  bool _isLoading = false;
  Map<String, dynamic>? _classReportData;
  CommentFilterStatus _filterStatus = CommentFilterStatus.all;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  /// 974 satirlik modalin her tusta bastan cizilmesini onler.
  final SearchDebouncer _searchDebouncer = SearchDebouncer();

  // Öğrenci bazlı seçilen varyasyon indexi (studentId -> variationIndex)
  final Map<int, int> _studentVariationMap = {};
  // Kopyalanan öğrencilerin seti (studentId -> kopyalandı işareti)
  final Set<int> _copiedStudentIds = {};
  // Öğretmenin manuel belirlediği/ayarladığı özel notlar (studentId -> customGrade)
  final Map<int, double> _customStudentGrades = {};

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classes = ref.read(classListProvider).valueOrNull ?? [];
      if (classes.isNotEmpty) {
        _selectedClassId ??= classes.first.id;
        if (_selectedClassId != null) {
          _loadClassData();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClassData() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(classroomParticipationRepoProvider);
      final data = await repo.getClassCumulativeReportData(_selectedClassId!);
      if (mounted) {
        setState(() {
          _classReportData = data;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('ClassReportCardCommentsModal load error: $e\n$stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Öğrencinin notunu manuel seçebileceği ve sadece notu kopyalayabileceği alt modal
  void _showGradePickerModal({
    required BuildContext context,
    required int studentId,
    required String studentName,
    required String studentNumber,
    required double currentGrade,
    required bool isDark,
  }) {
    double tempGrade = currentGrade;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tutamaç
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: Color(0xFF3B82F6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$studentName (#$studentNumber)',
                              style: AppFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Katılım puanını belirleyin veya doğrudan panoya kopyalayın',
                              style: AppFonts.outfit(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Puan Göstergesi & Kaydırıcı
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ders İçi Katılım Notu:',
                              style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${tempGrade.toStringAsFixed(0)} Puan',
                                style: AppFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF3B82F6),
                            thumbColor: const Color(0xFF3B82F6),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: tempGrade,
                            min: 40,
                            max: 100,
                            divisions: 60,
                            onChanged: (val) {
                              setModalState(() => tempGrade = val);
                            },
                          ),
                        ),
                        // Hızlı Puan Butonları
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [100, 95, 90, 85, 75, 60, 50].map((preset) {
                            final isCur = tempGrade.round() == preset;
                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => tempGrade = preset.toDouble());
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isCur
                                      ? const Color(0xFF3B82F6)
                                      : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCur
                                        ? const Color(0xFF3B82F6)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                child: Text(
                                  '$preset',
                                  style: AppFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isCur
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2 Aksiyon Butonu (Sadece Notu Kopyala & Uygula)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final messenger = ScaffoldMessenger.of(context);
                            await WhatsAppShareService.copyToClipboard(tempGrade.toStringAsFixed(0));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('$studentName için "${tempGrade.toStringAsFixed(0)}" notu kopyalandı! 📋'),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: Text(
                            'Notu Kopyala (${tempGrade.toStringAsFixed(0)})',
                            style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B82F6),
                            side: const BorderSide(color: Color(0xFF3B82F6)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _customStudentGrades[studentId] = tempGrade;
                              _copiedStudentIds.remove(studentId);
                            });
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: Text(
                            'Görüşü Güncelle',
                            style: AppFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Tüm sınıfın görüşlerini tek bir toplu metin olarak kopyalar
  Future<void> _copyAllComments(List<Map<String, dynamic>> students) async {
    final commentGenerator = ref.read(smartCommentGeneratorProvider);
    final className = _classReportData?['className'] ?? 'Sınıf';
    final subjectName = _classReportData?['subjectName'] ?? 'Ders';

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('📋 $className - $subjectName e-Okul Karne Görüşleri');
    buffer.writeln('========================================\n');

    for (var s in students) {
      final sId = s['studentId'] as int;
      final sNum = s['studentNumber']?.toString() ?? '-';
      final sName = s['studentName']?.toString() ?? 'Öğrenci';

      final totalSessions = s['totalEvaluatedSessions'] as int? ?? 0;
      final hwDone = s['homeworkDone'] as int? ?? 0;
      final hwPart = s['homeworkPartial'] as int? ?? 0;
      final matReady = s['materialsReady'] as int? ?? 0;
      final avgStars = (s['averageStars'] as num?)?.toDouble() ?? 3.0;
      final tags = (s['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      final baseGrade = SmartCommentGenerator.calculateParticipationGrade(
        totalSessions: totalSessions,
        homeworkDone: hwDone,
        homeworkPartial: hwPart,
        materialsReady: matReady,
        averageStars: avgStars,
      );

      final calculatedGrade = _customStudentGrades[sId] ?? baseGrade;

      final int seed = int.tryParse(sNum) ?? (sId * 7);
      final varIdx = _studentVariationMap[sId] ?? 0;
      final comment = commentGenerator.generateEOkulComment(
        calculatedGrade: calculatedGrade,
        homeworkRate: (s['homeworkRate'] as num?)?.toDouble(),
        avgStars: avgStars,
        tags: tags,
        seed: seed,
        variationIndex: varIdx,
      );

      buffer.writeln('$sNum - $sName (Katılım Puanı: ${calculatedGrade.toStringAsFixed(0)}/100):');
      buffer.writeln('"$comment"\n');
    }

    await WhatsAppShareService.copyToClipboard(buffer.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm sınıfın görüşleri liste olarak kopyalandı! (Word / Not Defteri için) 📋'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classListProvider).valueOrNull ?? [];
    final commentGenerator = ref.watch(smartCommentGeneratorProvider);

    final rawStudents = _classReportData?['students'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> students =
        rawStudents.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Filtreleme ve Arama
    final filteredStudents = students.where((s) {
      final sId = s['studentId'] as int;
      final totalSessions = s['totalEvaluatedSessions'] as int? ?? 0;
      final hwDone = s['homeworkDone'] as int? ?? 0;
      final hwPart = s['homeworkPartial'] as int? ?? 0;
      final matReady = s['materialsReady'] as int? ?? 0;
      final avgStars = (s['averageStars'] as num?)?.toDouble() ?? 3.0;

      final baseGrade = SmartCommentGenerator.calculateParticipationGrade(
        totalSessions: totalSessions,
        homeworkDone: hwDone,
        homeworkPartial: hwPart,
        materialsReady: matReady,
        averageStars: avgStars,
      );

      final grade = _customStudentGrades[sId] ?? baseGrade;

      if (_filterStatus == CommentFilterStatus.excellent && grade < 85) return false;
      if (_filterStatus == CommentFilterStatus.good && (grade < 70 || grade >= 85)) return false;
      if (_filterStatus == CommentFilterStatus.needsSupport && grade >= 70) return false;

      if (_searchQuery.isEmpty) return true;
      // `toLowerCase` Turkce'de yaniltiyordu: ogretmen "Isil" yazinca
      // "Isil" ogrencisi bulunamiyordu.
      final name = s['studentName']?.toString() ?? '';
      final numStr = s['studentNumber']?.toString() ?? '';
      return trContains(name, _searchQuery) || numStr.contains(_searchQuery);
    }).toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tutamaç
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Başlık & Kapat Butonu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akıllı e-Okul Karne Görüşü & Puanlama',
                      style: AppFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Ders içi verilere göre otomatik puanlama ve seri kopyalama',
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, size: 22, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sınıf Seçimi Dropdown & Toplu Kopyala Butonu
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school_rounded, size: 18, color: Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedClassId,
                            isExpanded: true,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                            items: classes.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(
                                  '${c.name} (${c.subject})',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedClassId = val;
                                  _copiedStudentIds.clear();
                                  _studentVariationMap.clear();
                                  _customStudentGrades.clear();
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                                _loadClassData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: students.isNotEmpty ? () => _copyAllComments(students) : null,
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: Text(
                  'Toplu Liste Al',
                  style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Arama Çubuğu & Filtre Çipleri
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: AppFonts.outfit(
                fontSize: 12.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Öğrenci adı veya okul no ile filtrele...',
                hintStyle: AppFonts.outfit(
                  fontSize: 11.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFE11D48)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) => _searchDebouncer.run(() {
                if (!mounted) return;
                setState(() => _searchQuery = val.trim());
              }),
            ),
          ),
          const SizedBox(height: 8),

          // Filtre Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tümü (${students.length})', CommentFilterStatus.all, const Color(0xFF3B82F6), isDark),
                const SizedBox(width: 6),
                _buildFilterChip('🟢 85+ (Üstün)', CommentFilterStatus.excellent, const Color(0xFF10B981), isDark),
                const SizedBox(width: 6),
                _buildFilterChip('🟡 70-84 (İyi)', CommentFilterStatus.good, const Color(0xFFF59E0B), isDark),
                const SizedBox(width: 6),
                _buildFilterChip('🔴 < 70 (Destek)', CommentFilterStatus.needsSupport, const Color(0xFFEF4444), isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ÖĞRENCİ LİSTESİ (SERİ KOPYALAMA ALANI)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
                : filteredStudents.isEmpty
                    ? Center(
                        child: Text(
                          'Kriterlere uygun öğrenci bulunamadı.',
                          style: AppFonts.outfit(fontSize: 12.5, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final s = filteredStudents[index];
                          final sId = s['studentId'] as int;
                          final sNum = s['studentNumber']?.toString() ?? '-';
                          final sName = s['studentName']?.toString() ?? 'Öğrenci';

                          final totalSessions = s['totalEvaluatedSessions'] as int? ?? 0;
                          final hwDone = s['homeworkDone'] as int? ?? 0;
                          final hwPart = s['homeworkPartial'] as int? ?? 0;
                          final matReady = s['materialsReady'] as int? ?? 0;
                          final avgStars = (s['averageStars'] as num?)?.toDouble() ?? 3.0;
                          final tags = (s['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                          // 100 üzerinden gerçek puan hesabı (Manuel ayarlanmışsa o baz alınır)
                          final baseCalculatedGrade = SmartCommentGenerator.calculateParticipationGrade(
                            totalSessions: totalSessions,
                            homeworkDone: hwDone,
                            homeworkPartial: hwPart,
                            materialsReady: matReady,
                            averageStars: avgStars,
                          );
                          final calculatedGrade = _customStudentGrades[sId] ?? baseCalculatedGrade;
                          final isCustomGrade = _customStudentGrades.containsKey(sId);

                          // Öğrencinin aktif varyasyonundaki görüşü
                          final int seed = int.tryParse(sNum) ?? (sId * 7 + index);
                          final varIdx = _studentVariationMap[sId] ?? 0;
                          final comment = commentGenerator.generateEOkulComment(
                            calculatedGrade: calculatedGrade,
                            homeworkRate: (s['homeworkRate'] as num?)?.toDouble(),
                            avgStars: avgStars,
                            tags: tags,
                            seed: seed,
                            variationIndex: varIdx,
                          );

                          final isCopied = _copiedStudentIds.contains(sId);

                          // Puan Renk Rozeti
                          Color gradeColor = const Color(0xFF10B981);
                          if (calculatedGrade < 60) {
                            gradeColor = const Color(0xFFEF4444);
                          } else if (calculatedGrade < 75) {
                            gradeColor = const Color(0xFFF59E0B);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCopied
                                    ? const Color(0xFF10B981)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isCopied ? 1.4 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Satır: Numara, İsim ve Tıklanabilir Puan Rozeti
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: gradeColor,
                                      child: Text(
                                        sNum,
                                        style: AppFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sName,
                                        style: AppFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _showGradePickerModal(
                                          context: context,
                                          studentId: sId,
                                          studentName: sName,
                                          studentNumber: sNum,
                                          currentGrade: calculatedGrade,
                                          isDark: isDark,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: gradeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${isCustomGrade ? "Özel: " : "Katılım: "}${calculatedGrade.toStringAsFixed(0)} / 100',
                                              style: AppFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: gradeColor,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Icon(Icons.edit_note_rounded, size: 14, color: gradeColor),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // 2. Satır: Üretilen Pedagojik e-Okul Cümlesi
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Text(
                                    comment,
                                    style: AppFonts.outfit(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // 3. Satır: Seri Kopyalama, Puan Ayarla ve Farklı Görüş Butonları
                                Row(
                                  children: [
                                    // KOPYALA BUTONU
                                    Expanded(
                                      flex: 3,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          HapticFeedback.lightImpact();
                                          await WhatsAppShareService.copyToClipboard(comment);
                                          setState(() {
                                            _copiedStudentIds.add(sId);
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('$sName için görüş kopyalandı! e-Okul\'a yapıştırabilirsiniz. 📋'),
                                                duration: const Duration(seconds: 1),
                                                backgroundColor: AppColors.success,
                                              ),
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          isCopied ? 'Kopyalandı ✓' : 'Kopyala',
                                          style: AppFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isCopied ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // ORTALAMA / PUAN AYARLA BUTONU
                                    Expanded(
                                      flex: 2,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          _showGradePickerModal(
                                            context: context,
                                            studentId: sId,
                                            studentName: sName,
                                            studentNumber: sNum,
                                            currentGrade: calculatedGrade,
                                            isDark: isDark,
                                          );
                                        },
                                        icon: const Icon(Icons.tune_rounded, size: 14),
                                        label: Text(
                                          '${calculatedGrade.toStringAsFixed(0)} Not',
                                          style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF3B82F6),
                                          side: const BorderSide(color: Color(0xFF3B82F6)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // FARKLI GÖRÜŞ BUTONU
                                    Expanded(
                                      flex: 2,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            _studentVariationMap[sId] = varIdx + 1;
                                            _copiedStudentIds.remove(sId);
                                          });
                                        },
                                        icon: const Icon(Icons.refresh_rounded, size: 14),
                                        label: Text(
                                          'Değiştir',
                                          style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                                          side: BorderSide(
                                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, CommentFilterStatus status, Color color, bool isDark) {
    final isSelected = _filterStatus == status;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _filterStatus = status);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.3 : 0.15)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? (isDark ? Colors.white : color) : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
