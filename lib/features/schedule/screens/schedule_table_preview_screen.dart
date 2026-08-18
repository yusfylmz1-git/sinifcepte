import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../models/lesson_model.dart';
import '../models/schedule_settings.dart';
import '../providers/schedule_provider.dart';
import '../utils/schedule_pdf_generator.dart';

/// SınıfCepte - Haftalık Ders Programı Matris Tablosu & Canlı Önizleme Ekranı
/// Dikey, Yatay ve Tablet ekranlarında %100 responsive çalışır.
class ScheduleTablePreviewScreen extends ConsumerStatefulWidget {
  const ScheduleTablePreviewScreen({super.key});

  @override
  ConsumerState<ScheduleTablePreviewScreen> createState() =>
      _ScheduleTablePreviewScreenState();
}

class _ScheduleTablePreviewScreenState
    extends ConsumerState<ScheduleTablePreviewScreen> {
  bool _showTimeRanges = true;
  bool _showLunchBreak = true;

  // MEB Resmî Tablo Rengi
  static const Color _mebHeaderColor = Color(0xFF1E293B);

  static const List<String> _weekDays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allLessons = ref.watch(scheduleProvider);
    final settings = ref.watch(scheduleSettingsProvider);
    final profile = ref.watch(teacherProfileProvider);

    final totalLessonCount = allLessons.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Haftalık Ders Dağıtım Tablosu',
          style: AppFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // A4 PDF Çıktısı Al Butonu
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _printPdf(allLessons, settings, profile),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text(
                'PDF / Yazdır',
                style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. ÖĞRETMEN & OKUL CANLI KART
            _buildHeaderCard(profile, totalLessonCount, isDark),

            // 2. TAM EKRAN GENİŞLİĞİNE OTOMATİK SIĞAN 3'LÜ KONTROL BUTONLARI
            _buildResponsiveControlBar(isDark),

            // 3. RESPONSIVE HAFTALIK MATRİS TABLOSU
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth >= 720;
                  final tableWidth = isWideScreen ? constraints.maxWidth - 32 : 680.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: isWideScreen
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Matris Tablosu
                              _buildMatrixTable(allLessons, settings, isDark),
                              const SizedBox(height: 16),

                              // MEB Resmî İmza & Onay Alanı
                              _buildOfficialSignatureBlock(profile, isDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
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
              child: OutlinedButton.icon(
                onPressed: () => _printPdf(allLessons, settings, profile),
                icon: const Icon(Icons.share_rounded, size: 17),
                label: Text(
                  'WhatsApp / Paylaş',
                  style: AppFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _printPdf(allLessons, settings, profile),
                icon: const Icon(Icons.print_rounded, size: 17),
                label: Text(
                  'A4 PDF Çıktısı Al',
                  style: AppFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Üst Bilgi Kartı
  Widget _buildHeaderCard(
    TeacherProfileModel profile,
    int totalLessonCount,
    bool isDark,
  ) {
    final school = profile.schoolName.isNotEmpty ? profile.schoolName : 'Okul Adı Girilmedi';
    final teacher = profile.fullName.isNotEmpty ? profile.fullName : 'Öğretmen';
    final branch = profile.branch.isNotEmpty ? profile.branch : 'Branş Belirtilmedi';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school.toUpperCase(),
                  style: AppFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$teacher • $branch',
                  style: AppFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Haftalık',
                  style: AppFonts.outfit(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                Text(
                  '$totalLessonCount Saat',
                  style: AppFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Ekran Genişliğine Otomatik Eşit Sığan 3'lü Kontrol Butonları
  Widget _buildResponsiveControlBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // 1. BUTON: SAATLERİ GÖSTER
          Expanded(
            child: _buildControlButton(
              icon: _showTimeRanges
                  ? Icons.access_time_filled_rounded
                  : Icons.access_time_rounded,
              title: 'Saatleri Göster',
              isActive: _showTimeRanges,
              activeColor: AppColors.primary,
              isDark: isDark,
              onTap: () => setState(() => _showTimeRanges = !_showTimeRanges),
            ),
          ),
          const SizedBox(width: 8),

          // 2. BUTON: ÖĞLE ARASI
          Expanded(
            child: _buildControlButton(
              icon: Icons.restaurant_rounded,
              title: 'Öğle Arası',
              isActive: _showLunchBreak,
              activeColor: const Color(0xFFD97706),
              isDark: isDark,
              onTap: () => setState(() => _showLunchBreak = !_showLunchBreak),
            ),
          ),
          const SizedBox(width: 8),

          // 3. BUTON: RESMÎ MEB
          Expanded(
            child: _buildControlButton(
              icon: Icons.account_balance_rounded,
              title: 'Resmî MEB',
              isActive: true, // Her zaman aktif MEB formatı
              activeColor: const Color(0xFF1E293B),
              isDark: isDark,
              onTap: () {}, // Sabit MEB Formatı
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String title,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3. Haftalık Matris Tablosu
  Widget _buildMatrixTable(
    List<LessonModel> lessons,
    ScheduleSettings settings,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // BAŞLIK SATIRI (Ders/Saat, Pzt, Sal, Çar, Per, Cum)
            _buildTableHeader(isDark),

            // DERS SATIRLARI + ÖĞLE ARASI
            ...List.generate(
              settings.dailyLessonCount + (_showLunchBreak && settings.hasLunchBreak ? 1 : 0),
              (visualIndex) {
                // Öğle Arası Satırı
                if (_showLunchBreak &&
                    settings.hasLunchBreak &&
                    visualIndex == settings.lunchBreakAfterLesson) {
                  return _buildLunchBreakRow(settings, isDark);
                }

                final lessonIndex = (_showLunchBreak &&
                        settings.hasLunchBreak &&
                        visualIndex > settings.lunchBreakAfterLesson)
                    ? visualIndex - 1
                    : visualIndex;

                final timeRange = settings.calculateTimeRange(lessonIndex);

                return _buildTableRow(
                  lessonIndex: lessonIndex,
                  timeRange: timeRange,
                  lessons: lessons,
                  isDark: isDark,
                  isEvenRow: lessonIndex % 2 == 0,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Tablo Başlık Satırı (Resmî MEB)
  Widget _buildTableHeader(bool isDark) {
    return Container(
      color: _mebHeaderColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Saat Başlığı Sütunu
          SizedBox(
            width: 80,
            child: Text(
              'DERS / SAAT',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.white24),

          // Günler
          ..._weekDays.map((day) {
            return Expanded(
              child: Text(
                day.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Tablo Ders Satırı
  Widget _buildTableRow({
    required int lessonIndex,
    required String timeRange,
    required List<LessonModel> lessons,
    required bool isDark,
    required bool isEvenRow,
  }) {
    final rowBg = isEvenRow
        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
        : (isDark ? const Color(0xFF192231) : const Color(0xFFF8FAFC));

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sol Ders & Saat Bilgisi Sütunu
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : _mebHeaderColor.withValues(alpha: 0.04),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${lessonIndex + 1}. Ders',
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (_showTimeRanges) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeRange,
                      style: AppFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),

            // 5 Günün Ders Hücreleri
            ..._weekDays.map((day) {
              final lesson = lessons
                  .where((l) => l.day == day && l.lessonHourIndex == lessonIndex)
                  .firstOrNull;

              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: lesson != null
                      ? _buildLessonCell(lesson, isDark)
                      : Center(
                          child: Text(
                            '-',
                            style: TextStyle(
                              color: isDark ? Colors.white24 : Colors.grey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Ders Hücresi İçeriği (Renkli Rozet)
  Widget _buildLessonCell(LessonModel lesson, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: lesson.color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: lesson.color.withValues(alpha: isDark ? 0.5 : 0.35),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sınıf Adı
          Text(
            lesson.className,
            style: AppFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Ders Adı
          Text(
            lesson.lessonName,
            style: AppFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: lesson.color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Öğle Arası Şerit Satırı
  Widget _buildLunchBreakRow(ScheduleSettings settings, bool isDark) {
    final lunchTime = settings.calculateLunchTimeRange();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_rounded, size: 14, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text(
            'ÖĞLE ARASI ${lunchTime.isNotEmpty ? '($lunchTime • ${settings.lunchBreakDuration} dk)' : ''}',
            style: AppFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD97706),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. MEB Resmî İmza & Mühür Bloğu
  Widget _buildOfficialSignatureBlock(
    TeacherProfileModel profile,
    bool isDark,
  ) {
    final teacher = profile.fullName.isNotEmpty ? profile.fullName : 'Öğretmen';
    final principal = profile.schoolPrincipalName.isNotEmpty ? profile.schoolPrincipalName : 'Okul Müdürü';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Yukarıdaki haftalık ders dağıtım çizelgesi 2025-2026 Eğitim Öğretim Yılı için düzenlenmiştir.',
            style: AppFonts.outfit(
              fontSize: 10.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Öğretmen İmza Alanı
              Column(
                children: [
                  Text(
                    teacher,
                    style: AppFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Ders Öğretmeni',
                    style: AppFonts.outfit(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),
                  Text('İmza: ...................', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),

              // Okul Müdürü Onay Alanı
              Column(
                children: [
                  Text(
                    principal,
                    style: AppFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Okul Müdürü',
                    style: AppFonts.outfit(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),
                  Text('Mühür / İmza: ...................', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _printPdf(
    List<LessonModel> lessons,
    ScheduleSettings settings,
    TeacherProfileModel profile,
  ) {
    SchedulePdfGenerator.printOrShareWeeklySchedule(
      context: context,
      lessons: lessons,
      settings: settings,
      profile: profile,
    );
  }
}
