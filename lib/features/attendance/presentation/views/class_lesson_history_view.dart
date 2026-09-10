import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/classroom_participation_provider.dart';
import '../../utils/participation_pdf_generator.dart';

/// İşlenen Dersler (Sınıf Katılım Geçmişi).
///
/// ## Neden bu ekran var
/// Uygulamanın öğretmene verdiği söz: **"artı-eksi listesi tutmana
/// gerek yok, istediğin izlemeyi burada yapabilirsin."** O sözün
/// karşılığı, öğretmenin geçmişe dönüp *"hangi dersleri işledim, o
/// derste ne oldu"* diye bakabilmesidir.
///
/// Bu ekrandan önce geçmiş yalnızca iki dar yerden görünüyordu:
/// öğrenci kartındaki son dersler şeridi (tek öğrenci) ve dönem sonu
/// kümülatif raporu (tek sayı). Sınıfın ders ders geçmişi hiçbir
/// yerde yoktu; `getClassRecentSessions` bunun için yazılmış ama
/// hiçbir ekran çağırmıyordu.
class ClassLessonHistoryView extends ConsumerStatefulWidget {
  final int classId;
  final String className;

  /// Doluysa yalnızca bu dersin oturumları listelenir.
  ///
  /// Öğretmen aynı sınıfa birden fazla derse girebiliyor; matematik
  /// dersindeyken fen kayıtlarını görmek "geçen ders neydi" sorusunu
  /// cevapsız bırakıyordu.
  final String? subjectName;

  const ClassLessonHistoryView({
    super.key,
    required this.classId,
    required this.className,
    this.subjectName,
  });

  static Future<void> open(
    BuildContext context, {
    required int classId,
    required String className,
    String? subjectName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassLessonHistoryView(
          classId: classId,
          className: className,
          subjectName: subjectName,
        ),
      ),
    );
  }

  @override
  ConsumerState<ClassLessonHistoryView> createState() =>
      _ClassLessonHistoryViewState();
}

class _ClassLessonHistoryViewState
    extends ConsumerState<ClassLessonHistoryView> {
  /// Ders süzgeci. `null` = bu sınıfta işlenen tüm dersler.
  String? _subjectFilter;

  @override
  void initState() {
    super.initState();
    _subjectFilter = widget.subjectName?.trim().isNotEmpty == true
        ? widget.subjectName!.trim()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionsAsync =
        ref.watch(classRecentSessionsProvider(widget.classId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF7F8FC),
      appBar: CustomAppBar(
        title: 'İşlenen Dersler',
        subtitle: widget.className,
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(isDark, e),
          data: (sessions) {
            if (sessions.isEmpty) return _buildEmptyState(isDark);

            final dersler = _dersAdlari(sessions);
            final filtered = _applyFilter(sessions);

            return Column(
              children: [
                _buildSummary(filtered, isDark),
                if (dersler.length > 1) _buildSubjectChips(dersler, isDark),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Bu derste kayıt yok.',
                            style: AppFonts.outfit(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _buildSessionCard(filtered[i], isDark),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<String> _dersAdlari(List<ClassroomParticipationSession> sessions) {
    final set = <String>{};
    for (final s in sessions) {
      final ad = s.subjectName.trim();
      if (ad.isNotEmpty) set.add(ad);
    }
    final liste = set.toList()..sort();
    return liste;
  }

  List<ClassroomParticipationSession> _applyFilter(
    List<ClassroomParticipationSession> sessions,
  ) {
    final f = _subjectFilter;
    if (f == null) return sessions;
    return sessions.where((s) => s.subjectName.trim() == f).toList();
  }

  // ==========================================
  // ÜST ÖZET
  // ==========================================

  Widget _buildSummary(
    List<ClassroomParticipationSession> sessions,
    bool isDark,
  ) {
    final dersSayisi = sessions.length;
    final toplamSoz = sessions.fold<int>(
      0,
      (sum, s) => sum + s.totalSpeakingTurns,
    );

    // Kaç derste hiç işaretleme yapılmamış?
    //
    // Öğretmen "izlemeyi burada yapıyorum" diyorsa, boş geçtiği
    // dersleri de görmeli; yoksa rapor eksik veriye dayanır.
    final bosDers = sessions
        .where((s) => s.evaluations.every((e) => !e.hasAnyMark))
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6366F1)
              .withValues(alpha: isDark ? 0.24 : 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dersSayisi ders işlendi',
                  style: AppFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '$toplamSoz söz hakkı',
                    if (bosDers > 0) '$bosDers derste işaretleme yok',
                  ].join(' · '),
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChips(List<String> dersler, bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildChip(null, 'Tüm Dersler', isDark),
          for (final d in dersler) _buildChip(d, d, isDark),
        ],
      ),
    );
  }

  Widget _buildChip(String? value, String label, bool isDark) {
    final selected = _subjectFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _subjectFilter = value),
        labelStyle: AppFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        selectedColor: const Color(0xFF6366F1),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  // ==========================================
  // DERS KARTI
  // ==========================================

  Widget _buildSessionCard(
    ClassroomParticipationSession session,
    bool isDark,
  ) {
    final parsed = DateTime.tryParse(session.date);
    final gun = parsed != null
        ? AppDateFormatter.formatTurkishDate(parsed)
        : session.date;

    final isaretliVar = session.evaluations.any((e) => e.hasAnyMark);
    final odevOrani = session.homeworkCompletionRate;
    final odevSayisi = session.homeworkEvaluatedCount;
    final sessiz = session.silentStudentCount;
    final konu = session.topicName?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE8ECF3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // Bir derse dokununca o ders açılır: öğretmen geçmişte
          // gördüğü eksiği oracıkta düzeltebilmeli, yoksa ekran
          // yalnızca "bakılan" bir yer olur.
          onTap: () => _openLesson(session),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1)
                            .withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${session.lessonHour}. ders',
                        style: AppFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gun,
                            style: AppFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            session.subjectName,
                            style: AppFonts.outfit(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                      color: AppColors.primary,
                      tooltip: 'Bu dersin raporu',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _sharePdf(session),
                    ),
                  ],
                ),
                if (konu.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Konu: $konu',
                    style: AppFonts.outfit(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),

                // İşaretleme yapılmamış ders "%0 ödev" gibi görünmemeli:
                // veri yokluğu başarısızlık değildir.
                if (!isaretliVar)
                  Text(
                    'Bu derste işaretleme yapılmadı',
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (odevSayisi > 0)
                        _buildMetric(
                          'Ödev %${odevOrani.toStringAsFixed(0)}',
                          '($odevSayisi öğrenci)',
                          const Color(0xFF10B981),
                          isDark,
                        ),
                      _buildMetric(
                        '${session.totalSpeakingTurns} söz',
                        null,
                        const Color(0xFFD97706),
                        isDark,
                      ),
                      if (sessiz > 0)
                        _buildMetric(
                          '$sessiz sessiz',
                          null,
                          const Color(0xFF64748B),
                          isDark,
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

  Widget _buildMetric(
    String label,
    String? sub,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        sub == null ? label : '$label $sub',
        style: AppFonts.outfit(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ==========================================
  // DURUM EKRANLARI
  // ==========================================

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 14),
            Text(
              'Henüz işlenen ders yok',
              style: AppFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bir ders işleyip kaydettiğinizde burada listelenir; '
              'geriye dönüp hangi derste ne olduğunu görebilirsiniz.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              'Geçmiş yüklenemedi.\n$error',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(classRecentSessionsProvider(widget.classId)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EYLEMLER
  // ==========================================

  /// Seçilen dersi katılım ekranında açar.
  ///
  /// Katılım ekranı kaydedilmemiş değerlendirmeyi `PopScope` ile
  /// koruyor; buradan oturum değiştirmek o korumayı ATLAR. Öğretmen
  /// 30 öğrenciyi işaretleyip kaydetmeden geçmişe girip başka derse
  /// atlasa hepsi sessizce kaybolurdu — modülün en pahalı hatası
  /// tam olarak buydu. Bu yüzden geçiş öncesi burada soruluyor.
  Future<void> _openLesson(ClassroomParticipationSession session) async {
    final notifier = ref.read(currentParticipationSessionProvider.notifier);

    if (notifier.hasUnsavedChanges) {
      final devam = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Expanded(child: Text('Kaydedilmemiş Değerlendirme')),
            ],
          ),
          content: const Text(
            'Açık olan derste yaptığınız değerlendirmeler henüz '
            'kaydedilmedi. Başka bir derse geçerseniz tümü kaybolur.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Sayfada Kal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydetmeden Çık'),
            ),
          ],
        ),
      );
      if (devam != true) return;
    }

    if (!mounted) return;

    ref.read(selectedParticipationClassIdProvider.notifier).state =
        widget.classId;
    ref.read(selectedParticipationDateProvider.notifier).state = session.date;
    ref.read(selectedParticipationLessonHourProvider.notifier).state =
        session.lessonHour;

    notifier.loadSession(
      classId: widget.classId,
      date: session.date,
      lessonHour: session.lessonHour,
      subjectName: session.subjectName,
      className: widget.className,
    );

    Navigator.of(context).pop();
  }

  Future<void> _sharePdf(ClassroomParticipationSession session) async {
    final profile = ref.read(teacherProfileProvider);
    try {
      await ParticipationPdfGenerator.shareOrPrintClassPdf(
        session: session,
        teacherName: profile.fullName,
        schoolName: profile.schoolName,
        principalName: profile.schoolPrincipalName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF oluşturulurken bir hata oluştu.')),
      );
    }
  }
}
