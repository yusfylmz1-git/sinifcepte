import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/classroom_participation_provider.dart';
import '../../utils/participation_pdf_generator.dart';
import '../widgets/compact_student_participation_grid.dart';
import '../widgets/participation_batch_toolbar.dart';
import '../widgets/random_student_picker_modal.dart';

/// SınıfCepte - Ultra Sade & Hızlı Ders İçi Katılım Hub
class ClassroomParticipationView extends ConsumerStatefulWidget {
  final int? initialClassId;

  const ClassroomParticipationView({super.key, this.initialClassId});

  @override
  ConsumerState<ClassroomParticipationView> createState() => _ClassroomParticipationViewState();
}

class _ClassroomParticipationViewState extends ConsumerState<ClassroomParticipationView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isInitialized = false;
  String? _liveLessonBanner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultClassAndSession();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initDefaultClassAndSession() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final classesAsync = ref.read(classListProvider);
      final classes = classesAsync.valueOrNull ?? [];

      int? targetClassId = widget.initialClassId;
      int lessonHour = ref.read(selectedParticipationLessonHourProvider);
      final date = ref.read(selectedParticipationDateProvider);

      // 1. Haftalık ders programından o anki aktif dersi algıla
      if (targetClassId == null) {
        final Map<String, dynamic>? activeLesson = await ref.read(activeTimetableLessonProvider.future);
        if (activeLesson != null && activeLesson['class_id'] != null) {
          targetClassId = activeLesson['class_id'] as int;
          if (activeLesson['lesson_hour'] != null) {
            lessonHour = activeLesson['lesson_hour'] as int;
            ref.read(selectedParticipationLessonHourProvider.notifier).state = lessonHour;
          }
          final isLive = activeLesson['is_live'] == true;
          if (mounted) {
            setState(() {
              _liveLessonBanner = isLive
                  ? '⚡ Canlı Ders: ${activeLesson['class_name']} • ${activeLesson['subject_name']} ($lessonHour. Ders)'
                  : '🕒 Sonraki Ders: ${activeLesson['class_name']} • ${activeLesson['subject_name']} ($lessonHour. Ders)';
            });
          }
        }
      }

      // 2. Hala sınıf seçilemediyse ilk sınıfı seç
      if (targetClassId == null && classes.isNotEmpty) {
        targetClassId = classes.first.id;
      }

      if (targetClassId != null) {
        ref.read(selectedParticipationClassIdProvider.notifier).state = targetClassId;
        await _loadCurrentSession(targetClassId, date, lessonHour);
      }
    } catch (e, stackTrace) {
      debugPrint('ClassroomParticipationView._initDefaultClassAndSession Error: $e\n$stackTrace');
    }
  }

  Future<void> _loadCurrentSession(int classId, String date, int lessonHour) async {
    try {
      final classes = ref.read(classListProvider).valueOrNull ?? [];
      final selectedClass = classes.where((c) => c.id == classId).firstOrNull;

      await ref.read(currentParticipationSessionProvider.notifier).loadSession(
            classId: classId,
            date: date,
            lessonHour: lessonHour,
            subjectName: selectedClass?.subject,
            className: selectedClass?.name,
          );
    } catch (e, stackTrace) {
      debugPrint('ClassroomParticipationView._loadCurrentSession Error: $e\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classesAsync = ref.watch(classListProvider);
    final classes = classesAsync.valueOrNull ?? [];

    final selectedClassId = ref.watch(selectedParticipationClassIdProvider);
    final selectedDate = ref.watch(selectedParticipationDateProvider);
    final selectedLessonHour = ref.watch(selectedParticipationLessonHourProvider);

    final sessionAsync = ref.watch(currentParticipationSessionProvider);
    final session = sessionAsync.valueOrNull;

    final teacherProfile = ref.watch(teacherProfileProvider);
    final teacherName = teacherProfile.fullName.isNotEmpty ? teacherProfile.fullName : 'Ders Öğretmeni';
    final schoolName = teacherProfile.schoolName;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'Ders İçi Katılım',
        showProfileAvatar: false,
        showBackButton: true,
        showDrawerButton: false,
        actions: [
          // Tek Buton: Resmî PDF Raporunu WhatsApp ve Sistem ile Paylaş
          if (session != null && session.evaluations.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.primary),
              tooltip: 'Ders Raporu PDF Paylaş',
              onPressed: () async {
                try {
                  await ParticipationPdfGenerator.shareOrPrintClassPdf(
                    session: session,
                    teacherName: teacherName,
                    schoolName: schoolName,
                  );
                } catch (e, stackTrace) {
                  debugPrint('PDF Paylaşım Hatası: $e\n$stackTrace');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDF oluşturulurken bir hata oluştu.')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Canlı Ders Algılama Rozeti (Varsa)
            if (_liveLessonBanner != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _liveLessonBanner!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _liveLessonBanner = null);
                      },
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),

            // 1. ÜST KONTROL PANELİ: Sınıf Seçimi | Tarih | Ders Saati & Arama Çubuğu
            _buildControlHeader(
              context,
              isDark,
              classes,
              selectedClassId,
              selectedDate,
              selectedLessonHour,
            ),

            // 2. TOPLU HIZLI EYLEM ARAÇ ÇUBUĞU (Zero-Friction Toolbar)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 4),
              child: ParticipationBatchToolbar(),
            ),

            // 3. ANA DEĞERLENDİRME ALANI (Tek Ekrana Sığan Sıralı Mini Kart Izgarası + Canlı Arama)
            Expanded(
              child: sessionAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) {
                  debugPrint('ClassroomParticipationView Error: $err\n$stack');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined, size: 48, color: Colors.amber.shade700),
                          const SizedBox(height: 12),
                          Text(
                            'Ders katılım oturumu yüklenemedi',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lütfen yukarıdan sınıfı tekrar seçiniz veya yenileyiniz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(currentParticipationSessionProvider);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (sessionData) {
                  if (sessionData == null) {
                    return const Center(child: Text('Lütfen bir sınıf seçiniz.'));
                  }

                  return CompactStudentParticipationGrid(
                    session: sessionData,
                    searchQuery: _searchQuery,
                  );
                },
              ),
            ),

            // 4. ALT KAYDETME VE BİTİRME EYLEM ÇUBUĞU
            if (session != null && session.evaluations.isNotEmpty)
              _buildBottomSaveBar(context, isDark, session),
          ],
        ),
      ),
    );
  }

  /// Üst Kontrol Paneli: [ Sınıf Dropdown | Tarih Butonu | Ders Saati ] + Arama Kutusu
  Widget _buildControlHeader(
    BuildContext context,
    bool isDark,
    List<dynamic> classes,
    int? selectedClassId,
    String selectedDate,
    int selectedLessonHour,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        children: [
          // Satır 1: Sınıf Dropdown | Tarih Butonu | Ders Saati
          Row(
            children: [
              // 1. Sınıf Seçimi Dropdown
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: classes.isEmpty
                      ? Text(
                          'Sınıf Yok',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedClassId,
                            isExpanded: true,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                            items: classes.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(
                                  '${c.name} (${c.subject})',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(selectedParticipationClassIdProvider.notifier).state = val;
                                _loadCurrentSession(val, selectedDate, selectedLessonHour);
                              }
                            },
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. Tarih Seçici
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final initial = DateTime.tryParse(selectedDate) ?? DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(2025, 1, 1),
                      lastDate: DateTime(2027, 1, 1),
                    );
                    if (picked != null) {
                      final newDateStr = picked.toIso8601String().substring(0, 10);
                      ref.read(selectedParticipationDateProvider.notifier).state = newDateStr;
                      if (selectedClassId != null) {
                        _loadCurrentSession(selectedClassId, newDateStr, selectedLessonHour);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            selectedDate,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. Ders Saati Dropdown (1..8)
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedLessonHour,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                      items: List.generate(8, (i) => i + 1).map((h) {
                        return DropdownMenuItem<int>(
                          value: h,
                          child: Text(
                            '$h. Saat',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(selectedParticipationLessonHourProvider.notifier).state = val;
                          if (selectedClassId != null) {
                            _loadCurrentSession(selectedClassId, selectedDate, val);
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Satır 2: Şık Arama & Filtreleme Kutusu + 🎲 Kura Çek Butonu
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Öğrenci adı veya okul no ile filtrele...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        InkWell(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.close_rounded, size: 15, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 🎲 Kura Butonu
              InkWell(
                onTap: () {
                  final session = ref.read(currentParticipationSessionProvider).valueOrNull;
                  if (session != null && session.evaluations.isNotEmpty) {
                    RandomStudentPickerModal.show(context, session);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.5 : 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.casino_rounded, size: 15, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 4),
                      Text(
                        'Kura',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF7C3AED),
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
    );
  }

  Widget _buildBottomSaveBar(
    BuildContext context,
    bool isDark,
    ClassroomParticipationSession session,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final success = await ref.read(currentParticipationSessionProvider.notifier).saveCurrentSession();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '✅ ${session.className} ders içi değerlendirmesi kaydedildi!'
                            : 'Kayıt sırasında bir hata oluştu.',
                      ),
                      backgroundColor: success ? const Color(0xFF059669) : Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Değerlendirmeyi Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
