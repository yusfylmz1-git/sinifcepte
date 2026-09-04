import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/models/curriculum_outcome_model.dart';
import '../../providers/outcome_notes_provider.dart';

/// SınıfCepte - 39+1 Haftalık Resmî Müfredat Ders Kartı (Öğretmen Özel Notlu)
class OutcomeCarouselCard extends ConsumerWidget {
  final CurriculumOutcomeModel outcome;
  final bool isCurrentWeek;
  final bool isCarousel;
  final VoidCallback? onToggleFavorite;

  const OutcomeCarouselCard({
    super.key,
    required this.outcome,
    this.isCurrentWeek = false,
    this.isCarousel = true,
    this.onToggleFavorite,
  });

  void _showNoteDialog(BuildContext context, WidgetRef ref, String initialText) {
    final textController = TextEditingController(text: initialText);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık Satırı
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sticky_note_2_rounded,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${outcome.weekNumber}. Hafta Öğretmen Notu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            outcome.unitTitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Not Metin Alanı
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Örn: Laboratuvarda deney yapılacak, slayt 3\'ten devam edilecek, ödev kontrolü...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Kaydet Butonu
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final text = textController.text.trim();
                      await ref.read(outcomeNotesProvider.notifier).saveNote(
                            grade: outcome.gradeLevel,
                            subjectCode: outcome.subjectCode,
                            publisher: outcome.publisher,
                            weekNumber: outcome.weekNumber,
                            noteText: text,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  text.isEmpty
                                      ? 'Not silindi'
                                      : '${outcome.weekNumber}. Hafta notunuz kaydedildi 📝',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Notu Kaydet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteNote(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Notu Sil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text(
            'Bu haftaya ait kişisel ders notunuz silinecektir. Onaylıyor musunuz?',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(outcomeNotesProvider.notifier).deleteNote(
                      grade: outcome.gradeLevel,
                      subjectCode: outcome.subjectCode,
                      publisher: outcome.publisher,
                      weekNumber: outcome.weekNumber,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateRangeText = AppDateFormatter.getWeekDateRangeText(outcome.weekNumber);
    final notes = ref.watch(outcomeNotesProvider);
    final teacherNote = notes[outcome.weekNumber];

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: isCurrentWeek
              ? Border.all(color: const Color(0xFF10B981), width: 2.5)
              : Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Başlık Şeridi (2 Katmanlı Güvenli Düzen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: isCurrentWeek
                    ? const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                            : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Satır 1: Hafta + (Varsa) Ders Numarası + (Varsa) BU HAFTA Rozeti
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '${outcome.weekNumber}. Hafta',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (outcome.teachingWeekNumber != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${outcome.teachingWeekNumber}. Ders',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Öğretmen Not Butonu (Kompakt / Zarif İkon)
                      InkWell(
                        onTap: () => _showNoteDialog(context, ref, teacherNote ?? ''),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: (teacherNote != null && teacherNote.isNotEmpty)
                                ? Colors.amber.shade400
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (teacherNote != null && teacherNote.isNotEmpty)
                                    ? Icons.sticky_note_2_rounded
                                    : Icons.edit_note_rounded,
                                size: 13,
                                color: (teacherNote != null && teacherNote.isNotEmpty)
                                    ? const Color(0xFF78350F)
                                    : Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                (teacherNote != null && teacherNote.isNotEmpty) ? 'Notum' : 'Not Ekle',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: (teacherNote != null && teacherNote.isNotEmpty)
                                      ? const Color(0xFF78350F)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isCurrentWeek)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 14),
                              SizedBox(width: 2),
                              Text(
                                'BU HAFTA',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Satır 2: Tarih Aralığı
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateRangeText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Okul Temelli Planlama (OTP) Rozeti
                  if (outcome.isOtpWeek) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.center_focus_strong_rounded, size: 13, color: Color(0xFF78350F)),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '🎯 Okul Temelli Planlama (OTP)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF78350F),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (outcome.isSocialEventWeek) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.theater_comedy_rounded, size: 13, color: Color(0xFF831843)),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '🎭 MEB Sosyal Etkinlikler Haftası',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF831843),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // İçerik Gövdesi
            //
            // TAMAMI kaydırılabilir olmalı: eskiden yalnızca kazanım metni
            // kaydırılıyordu, Maarif özeti / MEB ders işlenişi kutuları
            // sabit alanda kalıyordu. İçerik büyüyünce kart taşıyordu
            // ("BOTTOM OVERFLOWED BY 191 PIXELS").
            if (isCarousel)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ünite ve Konu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.layers_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ÜNİTE / KONU',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  outcome.unitTitle,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Kazanım Kodu ve Başlığı
                      if (outcome.outcomeCode != null && outcome.outcomeCode != 'TATIL') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Kazanım Kodu: ${outcome.outcomeCode}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    letterSpacing: 0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Kazanım Açıklaması
                      // (dış SingleChildScrollView tarafından kaydırılır;
                      //  iç içe kaydırma alanı kullanılmaz)
                      _EstimatedScheduleNote(
                        show: outcome.isEstimatedSchedule,
                        isDark: isDark,
                      ),
                      _SpanBadge(
                        index: outcome.spanIndex,
                        total: outcome.spanTotal,
                        isDark: isDark,
                      ),
                      _OutcomeDescription(
                        text: outcome.outcomeDescription,
                        parts: outcome.outcomeParts,
                        isDark: isDark,
                        fontSize: 13,
                      ),
                      const SizedBox(height: 8),

                      // MAARİF MODELİ DERS ÖZETİ & PEDAGOJİK İPUÇLARI (Maarif Insight Box)
                      if (outcome.maarifSummary != null && outcome.maarifSummary!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                  : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFF10B981).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 11),
                                        SizedBox(width: 3),
                                        Text(
                                          'MAARİF DERS ÖZETİ',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                outcome.maarifSummary!,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                                ),
                              ),
                              // Değerler ve beceriler tam listeyle gösterilir.
                              // Önceden yalnızca ilk değer alınıp ('D4. Dostl…')
                              // kırpılıyordu; beceriler hiç görünmüyordu.
                              _OfficialActivity(
                                text: outcome.officialActivity,
                                isDark: isDark,
                              ),
                              _SuggestedActivities(
                                items: outcome.suggestedActivities,
                                isDark: isDark,
                              ),
                              _MaarifChipRow(
                                icon: '💎',
                                label: 'Değerler',
                                value: outcome.maarifValues,
                                isDark: isDark,
                                color: const Color(0xFF047857),
                                darkColor: const Color(0xFF34D399),
                              ),
                              _MaarifChipRow(
                                icon: '🧠',
                                label: 'Beceriler',
                                value: outcome.maarifSkills,
                                isDark: isDark,
                                color: const Color(0xFF4F46E5),
                                darkColor: const Color(0xFFA5B4FC),
                              ),
                              if (outcome.differentiation != null &&
                                  outcome.differentiation!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '🎯 ${outcome.differentiation!.trim()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    height: 1.3,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.62)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // ÖĞRETMEN ÖZEL NOTU (Varsa Sarı Post-it Kartı)
                      if (teacherNote != null && teacherNote.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.sticky_note_2_rounded, color: Color(0xFFD97706), size: 13),
                                      SizedBox(width: 4),
                                      Text(
                                        'ÖĞRETMEN NOTUM',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFD97706),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _showNoteDialog(context, ref, teacherNote),
                                        borderRadius: BorderRadius.circular(4),
                                        child: const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _confirmDeleteNote(context, ref),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                teacherNote,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.amber.shade100 : const Color(0xFF78350F),
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ünite ve Konu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ÜNİTE / KONU',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                outcome.unitTitle,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Kazanım Kodu ve Başlığı
                    if (outcome.outcomeCode != null && outcome.outcomeCode != 'TATIL') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Kazanım Kodu: ${outcome.outcomeCode}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Kazanım Açıklaması (Dikey modda doğal akış)
                    _EstimatedScheduleNote(
                      show: outcome.isEstimatedSchedule,
                      isDark: isDark,
                    ),
                    _SpanBadge(
                      index: outcome.spanIndex,
                      total: outcome.spanTotal,
                      isDark: isDark,
                    ),
                    _OutcomeDescription(
                      text: outcome.outcomeDescription,
                      parts: outcome.outcomeParts,
                      isDark: isDark,
                      fontSize: 13,
                    ),
                    const SizedBox(height: 10),

                    // MAARİF MODELİ DERS ÖZETİ & PEDAGOJİK İPUÇLARI (Maarif Insight Box)
                    if (outcome.maarifSummary != null && outcome.maarifSummary!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 11),
                                      SizedBox(width: 3),
                                      Text(
                                        'MAARİF DERS ÖZETİ',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              outcome.maarifSummary!,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                              ),
                            ),
                            _OfficialActivity(
                              text: outcome.officialActivity,
                              isDark: isDark,
                            ),
                            _SuggestedActivities(
                              items: outcome.suggestedActivities,
                              isDark: isDark,
                            ),
                            _MaarifChipRow(
                              icon: '💎',
                              label: 'Değerler',
                              value: outcome.maarifValues,
                              isDark: isDark,
                              color: const Color(0xFF047857),
                              darkColor: const Color(0xFF34D399),
                            ),
                            _MaarifChipRow(
                              icon: '🧠',
                              label: 'Beceriler',
                              value: outcome.maarifSkills,
                              isDark: isDark,
                              color: const Color(0xFF4F46E5),
                              darkColor: const Color(0xFFA5B4FC),
                            ),
                            if (outcome.differentiation != null &&
                                outcome.differentiation!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '🎯 ${outcome.differentiation!.trim()}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.3,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.62)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ÖĞRETMEN ÖZEL NOTU (Varsa Sarı Post-it Kartı)
                    if (teacherNote != null && teacherNote.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.sticky_note_2_rounded, color: Color(0xFFD97706), size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'ÖĞRETMEN NOTUM',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFD97706),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _showNoteDialog(context, ref, teacherNote),
                                      borderRadius: BorderRadius.circular(4),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _confirmDeleteNote(context, ref),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              teacherNote,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.amber.shade100 : const Color(0xFF78350F),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kazanım metnini okunabilir bloklara ayırır.
///
/// Kaynak planlarda bir hafta birden fazla kazanım taşıyabiliyor ve bunlar
/// tek hücrede '|' ile ayrılmış geliyor:
///
///   "Dijital Vatandaşlık / Yapay Zekâ | BTY.5.1.3. ... BTY.5.1.4. ... | a) ..."
///
/// Hepsi tek paragraf olarak basılınca kazanım kodu cümlenin ortasında
/// kayboluyordu. Burada parçalar ayrı satırlara açılır ve baştaki konu
/// etiketi ayrı bir üst başlık olarak gösterilir.
class _OutcomeDescription extends StatelessWidget {
  const _OutcomeDescription({
    required this.text,
    required this.isDark,
    required this.fontSize,
    this.parts = const [],
  });

  final String text;
  final List<OutcomePart> parts;
  final bool isDark;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bodyColor =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF334155);

    // Boru hattı kazanımları koda göre ayrıştırdıysa onu kullan: MEB
    // planlarında bir haftaya birden fazla kazanım düşebiliyor
    // (ör. MAT.5.1.2 ve MAT.5.1.3) ve düz metinde hangi "a) b)"
    // maddesinin hangi kazanıma ait olduğu anlaşılmıyordu.
    final usable = parts.where((p) => !p.isEmpty).toList();
    if (usable.isNotEmpty) {
      return _buildParts(usable, bodyColor);
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.4,
        color: bodyColor,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildParts(List<OutcomePart> usable, Color bodyColor) {
    final accent = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    final lead = usable.first.lead;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lead != null && lead.trim().isNotEmpty) ...[
          Text(
            lead.trim(),
            style: TextStyle(
              fontSize: fontSize - 1,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < usable.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _OutcomeBlock(
            part: usable[i],
            isDark: isDark,
            fontSize: fontSize,
            bodyColor: bodyColor,
            // Tek kazanım varsa numara göstermeye gerek yok.
            index: usable.length > 1 ? i + 1 : null,
          ),
        ],
      ],
    );
  }
}

/// Tek bir kazanım bloğu: kod rozeti, açıklama ve süreç bileşenleri.
class _OutcomeBlock extends StatelessWidget {
  const _OutcomeBlock({
    required this.part,
    required this.isDark,
    required this.fontSize,
    required this.bodyColor,
    this.index,
  });

  final OutcomePart part;
  final bool isDark;
  final double fontSize;
  final Color bodyColor;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    final code = part.code;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (code != null && code.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              index != null ? '$index. $code' : code,
              style: TextStyle(
                fontSize: fontSize - 2.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: accent,
              ),
            ),
          ),
        if (part.text.trim().isNotEmpty)
          Text(
            part.text.trim(),
            style: TextStyle(
              fontSize: fontSize,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: bodyColor,
            ),
          ),
        for (final step in part.steps) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              step,
              style: TextStyle(
                fontSize: fontSize - 1,
                height: 1.38,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.70)
                    : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MaarifChipRow extends StatelessWidget {
  const _MaarifChipRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.color,
    required this.darkColor,
  });

  final String icon;
  final String label;
  final String? value;
  final bool isDark;
  final Color color;
  final Color darkColor;

  @override
  Widget build(BuildContext context) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return const SizedBox.shrink();

    final items = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final tint = isDark ? darkColor : color;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon $label',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: tint,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tint.withValues(alpha: 0.28)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}


/// OTP / sosyal etkinlik haftaları için örnek etkinlik önerileri.
///
/// MEB bu haftalarda içerik belirlemez; karar zümrenindir. Bu yüzden
/// liste "öneri" olduğu açıkça yazılarak gösterilir ve resmî kazanım
/// görünümünden (mavi kod rozeti) kasıtlı olarak ayrışır.
class _SuggestedActivities extends StatelessWidget {
  const _SuggestedActivities({
    required this.items,
    required this.isDark,
  });

  final List<String> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final accent = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 14, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'ÖRNEK ETKİNLİK ÖNERİLERİ',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Bu hafta için içerik zümre tarafından belirlenir. Aşağıdakiler yalnızca fikir vermek içindir.',
            style: TextStyle(
              fontSize: 9.5,
              height: 1.3,
              fontStyle: FontStyle.italic,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 7),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.82)
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// "3 haftalık kazanımın 2. haftası" rozeti.
///
/// MEB planlarında bir kazanım birkaç hafta sürebiliyor ve o haftaların
/// metni birebir aynı oluyor. Rozet olmadan öğretmen bunu veri hatası
/// sanıyordu; bu etiket tekrarın plan gereği olduğunu söyler.
class _SpanBadge extends StatelessWidget {
  const _SpanBadge({
    required this.index,
    required this.total,
    required this.isDark,
  });

  final int? index;
  final int? total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final span = total;
    final position = index;
    if (span == null || position == null || span < 2) {
      return const SizedBox.shrink();
    }

    final accent = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_rounded, size: 12, color: accent),
            const SizedBox(width: 5),
            Text(
              '$span haftalık kazanımın $position. haftası',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// MEB öğretim programındaki resmî ders anlatımı.
///
/// Kaynağı tymm.meb.gov.tr öğretim programı PDF'idir ve kazanım koduyla
/// eşleştirilmiştir. Bizim ürettiğimiz Maarif özetinden ayrışması için
/// ayrı renkte ve "MEB Öğretim Programı" etiketiyle gösterilir.
/// MEB öğretim programındaki resmî ders anlatımı.
///
/// Kaynağı tymm.meb.gov.tr öğretim programı PDF'idir ve kazanım koduyla
/// eşleştirilmiştir. Bizim ürettiğimiz Maarif özetinden ayrışması için
/// ayrı renkte ve "MEB Öğretim Programı" etiketiyle gösterilir.
///
/// Metinler ortalama ~530 karakter olduğu için kartta kısaltılır;
/// dokununca tamamı açılır.
class _OfficialActivity extends StatefulWidget {
  const _OfficialActivity({required this.text, required this.isDark});

  final String? text;
  final bool isDark;

  @override
  State<_OfficialActivity> createState() => _OfficialActivityState();
}

class _OfficialActivityState extends State<_OfficialActivity> {
  /// Kısaltmadan gösterilecek üst sınır.
  static const int _collapsedLimit = 190;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final body = widget.text?.trim() ?? '';
    if (body.isEmpty) return const SizedBox.shrink();

    final isDark = widget.isDark;
    final accent = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
    final needsTrim = body.length > _collapsedLimit;
    final shown = (!needsTrim || _expanded)
        ? body
        : '${body.substring(0, _collapsedLimit).trimRight()}…';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 14, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'MEB ÖĞRETİM PROGRAMI · DERS İŞLENİŞİ',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            shown,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.42,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.86)
                  : const Color(0xFF1E293B),
            ),
          ),
          if (needsTrim)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  _expanded ? 'Daha az göster' : 'Devamını oku',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// "Haftalık dağılım tahminîdir" uyarısı.
///
/// Seçmeli derslerde MEB taslak yıllık plan yayımlamıyor. Kazanımlar
/// resmî öğretim programından alınıp haftalara eşit dağıtılıyor.
/// Öğretmenin bunu MEB'in kararı sanmaması için açıkça yazılır.
class _EstimatedScheduleNote extends StatelessWidget {
  const _EstimatedScheduleNote({required this.show, required this.isDark});

  final bool show;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    final accent = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 13, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Kazanımlar resmîdir, haftalık dağılım tahminîdir. '
                'MEB bu ders için yıllık plan yayımlamadı; zümrenizin '
                'planına göre değişebilir.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.32,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
