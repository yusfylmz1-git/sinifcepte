import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../academic_calendar/data/models/academic_calendar_event_model.dart';
import '../../academic_calendar/providers/academic_calendar_provider.dart';
import '../../academic_calendar/screens/academic_calendar_screen.dart';
import '../../analytics/presentation/views/analytics_dashboard_view.dart';
import '../../attendance/presentation/views/classroom_participation_view.dart';
import '../../attendance/providers/classroom_participation_provider.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../classes/screens/my_class_hub_screen.dart';
import '../../documents/presentation/views/documents_hub_view.dart';
import '../../exam_operations/data/models/exam_model.dart';
import '../../exam_operations/presentation/views/exam_operations_menu_view.dart';
import '../../exam_operations/presentation/views/exam_tracking_view.dart';
import '../../exam_operations/providers/exam_tracking_provider.dart';
import '../../outcomes/presentation/views/weekly_outcomes_view.dart';
import '../../outcomes/providers/outcomes_provider.dart';
import '../../schedule/models/lesson_model.dart';
import '../../schedule/models/schedule_settings.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../../../core/utils/date_formatter.dart';

/// SınıfCepte - Ultra Modern Öğretmen Paneli & Bento Dashboard (UI-UX-MAX)
class DashboardScreen extends ConsumerWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allLessons = ref.watch(scheduleProvider);
    final scheduleSettings = ref.watch(scheduleSettingsProvider);
    final profile = ref.watch(teacherProfileProvider);

    final now = DateTime.now();
    final todayName = _weekDays[(now.weekday - 1).clamp(0, 6)];
    final todayLessons = allLessons.where((l) => l.day == todayName).toList()
      ..sort((a, b) => a.lessonHourIndex.compareTo(b.lessonHourIndex));

    final currentAcademicWeek = AppDateFormatter.getCurrentAcademicWeek(targetDate: now);
    final isSummerHoliday = currentAcademicWeek >= 40;
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final todayCalendarEvent = ref.watch(todayCalendarEventProvider);
    final isOfficialHoliday = todayCalendarEvent != null &&
        (todayCalendarEvent.isOfficialHoliday ||
            todayCalendarEvent.category == CalendarEventCategory.officialHoliday ||
            todayCalendarEvent.category == CalendarEventCategory.breakHoliday);

    final examState = ref.watch(examTrackingProvider);
    final todayExam = examState.exams.where((e) => e.isToday).firstOrNull;

    final activeLesson = ref.watch(activeTimetableLessonProvider).valueOrNull;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            try {
              await ref.read(classListProvider.notifier).loadClasses();
              await ref.read(scheduleProvider.notifier).loadLessons();
              await ref.read(examTrackingProvider.notifier).loadExams();
            } catch (e, stackTrace) {
              debugPrint('---------------- HATA DETAYI (Dashboard.refresh) ----------------');
              debugPrint('Hata Mesajı : $e');
              debugPrint('Kod Satırı   : $stackTrace');
              debugPrint('----------------------------------------------------------------');
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. DİNAMİK KARŞILAMA VE GÜN BİLGİSİ HERO ALANI
                _buildModernGreetingHero(
                  context: context,
                  isDark: isDark,
                  profileName: profile.fullName,
                  todayLessonCount: todayLessons.length,
                  now: now,
                  todayName: todayName,
                  isSummerHoliday: isSummerHoliday,
                  isOfficialHoliday: isOfficialHoliday,
                  isWeekend: isWeekend,
                  todayCalendarEvent: todayCalendarEvent,
                  todayExam: todayExam,
                ),

                // 1.1 CANLI / SIRADAKİ DERS KATILIM HATIRLATICI KARTI
                if (activeLesson != null && activeLesson['class_id'] != null) ...[
                  const SizedBox(height: 12),
                  _buildLiveLessonParticipationCard(
                    context: context,
                    ref: ref,
                    isDark: isDark,
                    activeLesson: activeLesson,
                  ),
                ],
                const SizedBox(height: 14),

                // 2. ÖĞRETMEN HIZLI MODÜLLERİ (Bento Grid)
                _buildTeacherBentoGrid(context, isDark),
                const SizedBox(height: 14),

                // 3. YAKLAŞAN SINAVLAR & GERİ SAYIM
                _buildUpcomingExamsSection(
                  context: context,
                  ref: ref,
                  isDark: isDark,
                  upcomingExams: examState.upcomingExams,
                ),
                const SizedBox(height: 16),

                // 4. GÜNÜN DERS PROGRAMI & AKILLI TATİL AKIŞI
                _buildTodayScheduleTimeline(
                  context: context,
                  ref: ref,
                  isDark: isDark,
                  todayLessons: todayLessons,
                  settings: scheduleSettings,
                  todayName: todayName,
                  isSummerHoliday: isSummerHoliday,
                  isOfficialHoliday: isOfficialHoliday,
                  isWeekend: isWeekend,
                  todayCalendarEvent: todayCalendarEvent,
                ),
                const SizedBox(height: 95), // Floating Bottom Nav için güvenli boşluk
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Kompakt Karşılama ve Tarih Alanı (Zarif Tek Satır - Yer Tasarruflu)
  Widget _buildModernGreetingHero({
    required BuildContext context,
    required bool isDark,
    required String profileName,
    required int todayLessonCount,
    required DateTime now,
    required String todayName,
    required bool isSummerHoliday,
    required bool isOfficialHoliday,
    required bool isWeekend,
    AcademicCalendarEventModel? todayCalendarEvent,
    ExamModel? todayExam,
  }) {
    final displayName = profileName.isNotEmpty ? profileName : 'Öğretmenim';

    final monthNames = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    final monthStr = monthNames[now.month - 1];
    final dayStr = '${now.day} $monthStr';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sol: Zarif Karşılama & Öğretmen Adı
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'İyi çalışmalar, ',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 13)),
                  ],
                ),
                if (todayExam != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '🚨 Bugün Sınav: ${todayExam.title}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Sağ: MEB Takvimine Giden Zarif Tarih Çipi
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$dayStr, $todayName',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Canlı / Sıradaki Ders Katılım Değerlendirme Hatırlatıcı Kartı
  Widget _buildLiveLessonParticipationCard({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required Map<String, dynamic> activeLesson,
  }) {
    final className = activeLesson['class_name'] as String? ?? 'Sınıf';
    final subjectName = activeLesson['subject_name'] as String? ?? 'Ders';
    final lessonHour = activeLesson['lesson_hour'] as int? ?? 1;
    final classId = activeLesson['class_id'] as int;
    final isLive = activeLesson['is_live'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLive ? Icons.bolt_rounded : Icons.schedule_rounded,
                      size: 13,
                      color: isLive ? const Color(0xFF10B981) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLive ? 'ŞU AN DERSTESİNİZ' : 'SIRADAKİ DERS',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isLive ? const Color(0xFF10B981) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$lessonHour. Ders Saati',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$className • $subjectName',
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ders içi katılımı hızlıca değerlendirin veya tek tıkla tam puan verin.',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 1. Hızlı Buton: Tek Tıkla Tüm Sınıfa Tam Puan Ver
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final success = await ref
                        .read(currentParticipationSessionProvider.notifier)
                        .fillAndSaveLiveLesson(
                          classId: classId,
                          lessonHour: lessonHour,
                          subjectName: subjectName,
                          className: className,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? '⚡ $className sınıfına 3 Yıldız ve tam katılım puanı verildi!'
                                : 'Kayıt sırasında bir hata oluştu.',
                          ),
                          backgroundColor: success ? const Color(0xFF059669) : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFD97706)),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tümüne Tam Puan (3 ⭐)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Buton: Değerlendir (Sayfaya Git)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassroomParticipationView(initialClassId: classId),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                label: Text(
                  'Değerlendir',
                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Öğretmen Bento Grid Modül Kartları (6 Adet - Kompakt & Ultra Modern Tasarım)
  Widget _buildTeacherBentoGrid(BuildContext context, bool isDark) {
    final modules = [
      {
        'title': 'Kazanımlar',
        'subtitle': 'Konu & Müfredat',
        'icon': Icons.track_changes_rounded,
        'gradient': [const Color(0xFF2563EB), const Color(0xFF4F46E5)],
        'accent': const Color(0xFF3B82F6),
        'tabIndex': 2,
        'target': const WeeklyOutcomesView(),
      },
      {
        'title': 'Ders İçi Katılım',
        'subtitle': 'Etkinlik & Puan',
        'icon': Icons.stars_rounded,
        'gradient': [const Color(0xFF059669), const Color(0xFF10B981)],
        'accent': const Color(0xFF10B981),
        'target': const ClassroomParticipationView(),
      },
      {
        'title': 'Evraklarım',
        'subtitle': 'Plan & Resmî Evrak',
        'icon': Icons.folder_shared_rounded,
        'gradient': [const Color(0xFF0284C7), const Color(0xFF06B6D4)],
        'accent': const Color(0xFF0EA5E9),
        'target': const DocumentsHubView(),
      },
      {
        'title': 'Sınav İşlemleri',
        'subtitle': 'Not & Değerlendirme',
        'icon': Icons.assignment_rounded,
        'gradient': [const Color(0xFFD97706), const Color(0xFFF59E0B)],
        'accent': const Color(0xFFF59E0B),
        'target': const ExamOperationsMenuView(),
      },
      {
        'title': 'Rehberlik',
        'subtitle': 'Öğrenci & Veli Takibi',
        'icon': Icons.psychology_rounded,
        'gradient': [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
        'accent': const Color(0xFF8B5CF6),
        'target': const MyClassHubScreen(),
      },
      {
        'title': 'Analiz & Rapor',
        'subtitle': 'Başarı Grafikleri',
        'icon': Icons.insights_rounded,
        'gradient': [const Color(0xFFDB2777), const Color(0xFFF43F5E)],
        'accent': const Color(0xFFEC4899),
        'target': const AnalyticsDashboardView(),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'Hızlı İşlemler',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.15,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final item = modules[index];
            final gradient = item['gradient'] as List<Color>;
            final accent = item['accent'] as Color;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E293B),
                          Color.alphaBlend(accent.withValues(alpha: 0.08), const Color(0xFF1E293B)),
                        ]
                      : [
                          Colors.white,
                          Color.alphaBlend(accent.withValues(alpha: 0.04), Colors.white),
                        ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isDark
                      ? accent.withValues(alpha: 0.22)
                      : accent.withValues(alpha: 0.16),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : accent.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  children: [
                    // Arka Plan Hafif 3D Filigran İkonu
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Icon(
                        item['icon'] as IconData,
                        size: 52,
                        color: accent.withValues(alpha: isDark ? 0.04 : 0.035),
                      ),
                    ),

                    // Tıklanabilir İçerik
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          try {
                            if (item['tabIndex'] != null && onNavigateTab != null) {
                              onNavigateTab!(item['tabIndex'] as int);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => item['target'] as Widget),
                              );
                            }
                          } catch (e, stackTrace) {
                            debugPrint('---------------- HATA DETAYI (Dashboard.moduleTap) ----------------');
                            debugPrint('Hata Mesajı : $e');
                            debugPrint('Kod Satırı   : $stackTrace');
                            debugPrint('----------------------------------------------------------------');
                          }
                        },
                        splashColor: accent.withValues(alpha: 0.12),
                        highlightColor: accent.withValues(alpha: 0.06),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Sol: Gradyan İkon Rozeti
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: gradient[0].withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    item['icon'] as IconData,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Orta: Başlık & Alt Başlık
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      item['subtitle'] as String,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Sağ: Minik Ok İkonu
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: isDark ? Colors.white30 : accent.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 3. Yaklaşan Sınavlar & Geri Sayım Bölümü
  Widget _buildUpcomingExamsSection({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required List<ExamModel> upcomingExams,
  }) {
    final hasExams = upcomingExams.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bölüm Başlığı & "Tümünü Gör >" Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Yaklaşan Sınavlar',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasExams) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${upcomingExams.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExamTrackingView()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tümünü Gör',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFFD97706)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // İçerik: Sınav Listesi mi, Yoksa Sevimli Boş Durum mu?
          if (hasExams)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcomingExams.take(3).length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final exam = upcomingExams[idx];
                return _buildUpcomingExamCard(context, isDark, exam);
              },
            )
          else
            _buildEmptyExamsCard(context, isDark),
        ],
      ),
    );
  }

  Widget _buildUpcomingExamCard(BuildContext context, bool isDark, ExamModel exam) {
    // Kurum rengi ve rozeti
    Color instColor;
    String instLabel;

    switch (exam.institution.toUpperCase()) {
      case 'MEB':
        instColor = const Color(0xFF2563EB);
        instLabel = '🏛️ MEB';
        break;
      case 'ÖSYM':
      case 'OSYM':
        instColor = const Color(0xFF9333EA);
        instLabel = '📝 ÖSYM';
        break;
      case 'MSÜ':
      case 'MSU':
        instColor = const Color(0xFFD97706);
        instLabel = '🎖️ MSÜ';
        break;
      case 'BİLSEM':
      case 'BILSEM':
        instColor = const Color(0xFF0D9488);
        instLabel = '✨ BİLSEM';
        break;
      default:
        instColor = const Color(0xFF059669);
        instLabel = exam.isSchoolExam ? '📌 Okulum' : '📌 ${exam.institution}';
    }

    // Tarih Formatı
    final monthNames = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final dateStr = '${exam.examDate.day} ${monthNames[exam.examDate.month - 1]} ${exam.examDate.year}';

    // Geri Sayım Çipi
    final days = exam.daysRemaining;
    String badgeText;
    Color badgeColor;
    Color badgeBg;

    if (days == 0) {
      badgeText = '🚨 Bugün!';
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.18);
    } else if (days <= 7) {
      badgeText = '⚡ $days Gün';
      badgeColor = const Color(0xFFEA580C);
      badgeBg = const Color(0xFFEA580C).withValues(alpha: 0.15);
    } else {
      badgeText = '⏳ $days Gün';
      badgeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      badgeBg = (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)).withValues(alpha: 0.12);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExamTrackingView()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              // Kurum Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: instColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  instLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: instColor,
                  ),
                ),
              ),
              const SizedBox(width: 9),

              // Sınav Adı ve Tarihi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exam.title,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      '📅 $dateStr',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Geri Sayım Çipi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyExamsCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('✨', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yakın Tarihte Sınav Yok',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Önümüzdeki günlerde planlanmış bir MEB veya ÖSYM sınavı bulunmuyor.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExamTrackingView()),
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
              label: Text(
                'Sınav Takvimini İncele & Ekle',
                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6),
                side: BorderSide(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                ),
                foregroundColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Günün Ders Programı & Akıllı Tatil Akışı
  Widget _buildTodayScheduleTimeline({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required List<LessonModel> todayLessons,
    required ScheduleSettings settings,
    required String todayName,
    required bool isSummerHoliday,
    required bool isOfficialHoliday,
    required bool isWeekend,
    AcademicCalendarEventModel? todayCalendarEvent,
  }) {
    String timelineTitle;
    IconData timelineIcon;
    Color timelineAccent;

    if (isSummerHoliday) {
      timelineTitle = 'Günün Akışı (Yaz Tatili)';
      timelineIcon = Icons.beach_access_rounded;
      timelineAccent = const Color(0xFFD97706);
    } else if (isOfficialHoliday && todayCalendarEvent != null) {
      timelineTitle = 'Günün Akışı (${todayCalendarEvent.title})';
      timelineIcon = Icons.celebration_rounded;
      timelineAccent = const Color(0xFFDC2626);
    } else if (isWeekend) {
      timelineTitle = 'Günün Akışı ($todayName)';
      timelineIcon = Icons.coffee_rounded;
      timelineAccent = const Color(0xFF8B5CF6);
    } else {
      timelineTitle = 'Günün Ders Özeti ($todayName)';
      timelineIcon = Icons.schedule_rounded;
      timelineAccent = AppColors.accent;
    }

    String buttonText;
    VoidCallback onButtonTap;

    if (isSummerHoliday) {
      buttonText = 'Kazanımlar';
      onButtonTap = () => onNavigateTab?.call(2);
    } else if (isOfficialHoliday && todayCalendarEvent != null) {
      buttonText = 'MEB Takvimi';
      onButtonTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
        );
      };
    } else {
      buttonText = 'Tümünü Gör';
      onButtonTap = () => onNavigateTab?.call(3);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Dinamik Yönlendirme Butonu (Taşma Korumalı)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: timelineAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        timelineIcon,
                        color: timelineAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        timelineTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onButtonTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      buttonText,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: timelineAccent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: timelineAccent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // İçerik: Tatil mi, Hafta Sonu mu, Boş Gün mü yoksa Ders Listesi mi?
          if (isSummerHoliday)
            _buildSummerHolidayCard(context, isDark)
          else if (isOfficialHoliday && todayCalendarEvent != null)
            _buildOfficialHolidayCard(context, isDark, todayCalendarEvent)
          else if (isWeekend)
            _buildWeekendCard(context, isDark, todayName)
          else if (todayLessons.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 6),
                  Text(
                    'Bugün için kayıtlı dersiniz bulunmuyor.',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => onNavigateTab?.call(3),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Ders Programına Git & Ekle', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayLessons.take(4).length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final lesson = todayLessons[idx];
                final timeRange = settings.calculateTimeRange(lesson.lessonHourIndex);

                return _buildTimelineItem(
                  context: context,
                  ref: ref,
                  lesson: lesson,
                  lessonNo: '${lesson.lessonHourIndex + 1}. Ders',
                  time: timeRange,
                  subject: lesson.lessonName,
                  className: lesson.className,
                  color: lesson.color,
                  isActive: idx == 0,
                  isDark: isDark,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummerHolidayCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFFD97706).withValues(alpha: 0.18),
                  const Color(0xFFB45309).withValues(alpha: 0.08),
                ]
              : [
                  const Color(0xFFFFFBEB),
                  const Color(0xFFFEF3C7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.beach_access_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YAZ TATİLİ & DİNLENME DÖNEMİ',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'İyi Tatiller Öğretmenim! ☀️🏖️',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF78350F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '2025-2026 Eğitim Öğretim Yılı tamamlandı. Yeni eğitim dönemi Eylül ayında başlayacaktır. Keyifli dinlenmeler dileriz!',
            style: GoogleFonts.outfit(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.amber.shade100.withValues(alpha: 0.85) : const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onNavigateTab?.call(2),
              icon: const Icon(Icons.auto_stories_rounded, size: 16),
              label: const Text(
                'Yeni Dönem Müfredatı & Kazanımları',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialHolidayCard(
    BuildContext context,
    bool isDark,
    AcademicCalendarEventModel holiday,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFFDC2626).withValues(alpha: 0.18),
                  const Color(0xFF991B1B).withValues(alpha: 0.08),
                ]
              : [
                  const Color(0xFFFEF2F2),
                  const Color(0xFFFEE2E2),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFFDC2626),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESMÎ TATİL / DİNLENME GÜNÜ',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDC2626),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${holiday.title} 🇹🇷',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF7F1D1D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            holiday.description ??
                'Bugün MEB resmî çalışma takviminde tatil olarak belirlenmiştir. Ders yapılmamaktadır.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.red.shade100.withValues(alpha: 0.85) : const Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
                );
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
              label: const Text(
                'MEB Resmî Çalışma Takvimi',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendCard(BuildContext context, bool isDark, String todayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                  const Color(0xFF6D28D9).withValues(alpha: 0.08),
                ]
              : [
                  const Color(0xFFF5F3FF),
                  const Color(0xFFEDE9FE),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.coffee_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HAFTA SONU DİNLENME VAKTİ',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8B5CF6),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'İyi Hafta Sonları! ☕✨',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF4C1D95),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Bugün $todayName. Haftanın tüm yoğunluğunu geride bırakma ve sevdiklerinizle dinlenme zamanı.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.purple.shade100.withValues(alpha: 0.85) : const Color(0xFF5B21B6),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onNavigateTab?.call(3),
              icon: const Icon(Icons.calendar_view_week_rounded, size: 16),
              label: const Text(
                'Haftalık Ders Programını İncele',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _openOutcomeForLesson(BuildContext context, WidgetRef ref, LessonModel lesson) {
    try {
      final match = RegExp(r'^(\d+)').firstMatch(lesson.className);
      final grade = match != null ? int.tryParse(match.group(1)!) : null;

      if (grade != null) {
        ref.read(selectedGradeProvider.notifier).state = grade;
        ref.read(selectedSubjectProvider.notifier).state = {
          'subject_code': lesson.lessonName,
          'subject_name': lesson.lessonName,
          'publisher': 'MEB Yayınları',
        };
        ref.read(isFavoritesModeProvider.notifier).state = false;
        onNavigateTab?.call(2); // Kazanımlar Sekmesine (Tab 2) Geçiş Yap
      } else {
        onNavigateTab?.call(2);
      }
    } catch (e, stackTrace) {
      debugPrint('DashboardScreen._openOutcomeForLesson error: $e\n$stackTrace');
      onNavigateTab?.call(2);
    }
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required WidgetRef ref,
    required LessonModel lesson,
    required String lessonNo,
    required String time,
    required String subject,
    required String className,
    required Color color,
    required bool isActive,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openOutcomeForLesson(context, ref, lesson),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEEF2FF))
                : (isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Sol Ders Sırası Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lessonNo,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Ders ve Sınıf Bilgisi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subject,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Sağ Saat Rozeti & Kazanım Oku
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.auto_stories_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

