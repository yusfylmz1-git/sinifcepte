import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../classes/providers/class_provider.dart';
import '../models/lesson_model.dart';
import '../models/schedule_settings.dart';
import '../providers/schedule_provider.dart';
import '../widgets/add_lesson_dialog.dart';
import '../widgets/schedule_settings_dialog.dart';
import 'schedule_table_preview_screen.dart';

/// SınıfCepte - Kompakt, Akıllı ve Modern Ders Programı Ekranı (UI-UX-MAX)
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _selectedDayIndex = 0;

  static const List<String> _weekDays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  @override
  void initState() {
    super.initState();
    _initCurrentDay();
  }

  void _initCurrentDay() {
    final now = DateTime.now();
    // 1 = Monday, 7 = Sunday
    final weekday = now.weekday;
    if (weekday >= 1 && weekday <= 5) {
      _selectedDayIndex = weekday - 1;
    } else {
      _selectedDayIndex = 0; // Hafta sonu ise Pazartesi ile başla
    }
  }

  void _openSettingsDialog(ScheduleSettings currentSettings) {
    ScheduleSettingsDialog.show(
      context: context,
      initialSettings: currentSettings,
      onSaved: (newSettings) {
        // Günlük ders sayısı azaltılırsa sınır dışında kalan dersler
        // veritabanında kalır ama tabloda çizilmez.
        //
        // Önceden hiçbir uyarı yoktu: öğretmen için ders "kayboluyor",
        // sayıyı geri artırınca aniden geri geliyordu. Silmek de yanlış
        // olurdu (veri kaybı); doğru davranış haber vermek.
        final hidden = ref
            .read(scheduleProvider)
            .where((l) => l.lessonHourIndex >= newSettings.dailyLessonCount)
            .length;

        ref.read(scheduleSettingsProvider.notifier).updateSettings(newSettings);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hidden > 0
                  ? 'Ayarlar güncellendi. $hidden ders, günlük ders '
                      'saatinin dışında kaldığı için tabloda görünmüyor '
                      '(silinmedi). Saat sayısını artırırsanız geri gelir.'
                  : 'Ders programı saat ayarları güncellendi ⏱️',
            ),
            duration: Duration(seconds: hidden > 0 ? 7 : 2),
            backgroundColor: hidden > 0 ? Colors.orange : null,
          ),
        );
      },
    );
  }

  void _openAddOrEditLessonDialog({
    required List<LessonModel> allLessons,
    required ScheduleSettings settings,
    required String day,
    required int hourIndex,
    LessonModel? lessonToEdit,
  }) {
    final availableClasses = ref.read(classListProvider).valueOrNull ?? [];

    AddLessonDialog.show(
      context: context,
      availableClasses: availableClasses,
      existingLessons: allLessons,
      settings: settings,
      initialDay: day,
      initialLessonIndex: hourIndex,
      lessonToEdit: lessonToEdit,
      onSaved: (lesson) async {
        bool success;
        if (lessonToEdit != null) {
          success = await ref.read(scheduleProvider.notifier).updateLesson(lesson);
        } else {
          success = await ref.read(scheduleProvider.notifier).addLesson(lesson);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? (lessonToEdit != null ? 'Ders güncellendi ✅' : 'Ders programa eklendi 🚀')
                    : 'İşlem sırasında bir hata oluştu.',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  void _confirmDeleteLesson(LessonModel lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dersi Sil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '${lesson.day} ${lesson.lessonHourIndex + 1}. Ders saatindeki "${lesson.className} - ${lesson.lessonName}" dersini silmek istediğinize emin misiniz?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (lesson.id != null) {
                await ref.read(scheduleProvider.notifier).deleteLesson(lesson.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ders programdan silindi 🗑️')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allLessons = ref.watch(scheduleProvider);
    final settings = ref.watch(scheduleSettingsProvider);

    final selectedDay = _weekDays[_selectedDayIndex];
    final dayLessons = allLessons.where((l) => l.day == selectedDay).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. ÜST AKSİYON VE ARAÇ ÇUBUĞU
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haftalık Ders Akışı',
                          style: AppFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '$selectedDay • ${dayLessons.length} Ders Kayıtlı',
                          style: AppFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 📊 Haftalık Tablo & PDF Butonu
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduleTablePreviewScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.table_chart_rounded, size: 15),
                    label: Text(
                      'Tablo & PDF',
                      style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ⚙️ Ayarlar Butonu
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 19),
                      tooltip: 'Program Ayarları (Saat & Teneffüs)',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openSettingsDialog(settings),
                    ),
                  ),
                ],
              ),
            ),

            // 2. GÜN SEÇİCİ TAB BAR (Pzt - Cuma)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: 5, // Pazartesi - Cuma
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedDayIndex;
                  final day = _weekDays[index];
                  final count = allLessons.where((l) => l.day == day).length;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day.substring(0, 3), // Pzt, Sal, Çar...
                            style: AppFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 3. DERS LİSTESİ (1. Ders'ten Son Derse Kadar)
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  await ref.read(scheduleProvider.notifier).loadLessons();
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 95),
                  itemCount: settings.dailyLessonCount + (settings.hasLunchBreak ? 1 : 0),
                  itemBuilder: (context, visualIndex) {
                    // Öğle Arası Konumunu Kontrol Et
                    if (settings.hasLunchBreak && visualIndex == settings.lunchBreakAfterLesson) {
                      return _buildLunchBreakCard(settings, isDark);
                    }

                    // Gerçek ders saati index'i
                    final lessonIndex = settings.hasLunchBreak && visualIndex > settings.lunchBreakAfterLesson
                        ? visualIndex - 1
                        : visualIndex;

                    final lesson = dayLessons.where((l) => l.lessonHourIndex == lessonIndex).firstOrNull;
                    final timeRange = settings.calculateTimeRange(lessonIndex);

                    if (lesson != null) {
                      return _buildLessonCard(
                        lesson: lesson,
                        timeRange: timeRange,
                        isDark: isDark,
                        onTapEdit: () => _openAddOrEditLessonDialog(
                          allLessons: allLessons,
                          settings: settings,
                          day: selectedDay,
                          hourIndex: lessonIndex,
                          lessonToEdit: lesson,
                        ),
                        onTapDelete: () => _confirmDeleteLesson(lesson),
                      );
                    } else {
                      return _buildEmptySlotCard(
                        lessonIndex: lessonIndex,
                        timeRange: timeRange,
                        isDark: isDark,
                        onTapAdd: () => _openAddOrEditLessonDialog(
                          allLessons: allLessons,
                          settings: settings,
                          day: selectedDay,
                          hourIndex: lessonIndex,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dolu Ders Kartı
  Widget _buildLessonCard({
    required LessonModel lesson,
    required String timeRange,
    required bool isDark,
    required VoidCallback onTapEdit,
    required VoidCallback onTapDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTapEdit,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Sol Renkli Şerit
            Container(
              width: 5,
              height: 62,
              decoration: BoxDecoration(
                color: lesson.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Ders Sırası Rozeti
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: lesson.color.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${lesson.lessonHourIndex + 1}. Ders',
                style: AppFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: lesson.color,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Sınıf ve Ders Bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    lesson.className,
                    style: AppFonts.outfit(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    lesson.lessonName,
                    style: AppFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Saat Aralığı Rozeti
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                timeRange,
                style: AppFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),

            // İşlem Menüsü
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSelected: (val) {
                if (val == 'edit') onTapEdit();
                if (val == 'delete') onTapDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Düzenle')]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete_rounded, color: Colors.redAccent, size: 16), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.redAccent))]),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  /// Boş Ders Saati Kartı
  Widget _buildEmptySlotCard({
    required int lessonIndex,
    required String timeRange,
    required bool isDark,
    required VoidCallback onTapAdd,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 52,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.4)
            : const Color(0xFFF1F5F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: onTapAdd,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text(
                '${lessonIndex + 1}. Ders',
                style: AppFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($timeRange)',
                style: AppFonts.outfit(
                  fontSize: 11,
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Ders Ekle',
                    style: AppFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Öğle Arası Ayraç Kartı
  Widget _buildLunchBreakCard(ScheduleSettings settings, bool isDark) {
    final lunchTime = settings.calculateLunchTimeRange();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Text(
            'ÖĞLE ARASI ($lunchTime • ${settings.lunchBreakDuration} dk)',
            style: AppFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD97706),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
