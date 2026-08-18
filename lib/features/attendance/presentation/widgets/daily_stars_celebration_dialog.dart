import 'package:flutter/material.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../utils/participation_whatsapp_helper.dart';

/// SınıfCepte - Ders Sonu "Günün Yıldızları" Tebrik ve Motivasyon Modalı
class DailyStarsCelebrationDialog extends StatelessWidget {
  final ClassroomParticipationSession session;
  final String teacherName;
  final String? schoolName;

  const DailyStarsCelebrationDialog({
    super.key,
    required this.session,
    required this.teacherName,
    this.schoolName,
  });

  static Future<void> show({
    required BuildContext context,
    required ClassroomParticipationSession session,
    required String teacherName,
    String? schoolName,
  }) async {
    // Sadece 3 yıldız alan veya özel rozet alan öğrenciler varsa göster
    final starStudents = session.evaluations
        .where((e) => e.starsCount == 3 || e.customTags.isNotEmpty)
        .toList();

    if (starStudents.isEmpty) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => DailyStarsCelebrationDialog(
        session: session,
        teacherName: teacherName,
        schoolName: schoolName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final starStudents = session.evaluations
        .where((e) => e.starsCount == 3 || e.customTags.isNotEmpty)
        .toList();

    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst Başlık & İkon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 36, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 10),
            Text(
              '${session.className} Kaydedildi! 🎉',
              style: AppFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '✨ Günün Yıldız Öğrencileri',
              style: AppFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD97706),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            // Yıldız Öğrenciler Yatay/Dikey Listesi (Max 5 Öğrenci)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: starStudents.length.clamp(0, 5),
                separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final s = starStudents[index];
                  final isFemale = s.isFemale;
                  final avatarBg = isFemale ? const Color(0xFFEC4899) : const Color(0xFF3B82F6);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: avatarBg,
                          child: Text(
                            '${s.studentNumber}',
                            style: AppFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.studentName,
                            style: AppFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '${s.starsCount} ⭐',
                              style: AppFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
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
            const SizedBox(height: 18),

            // Veli WhatsApp Grubuna Tebrik Gönderme Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final msg = ParticipationWhatsAppHelper.generateDailyClassSummary(
                    session: session,
                    teacherName: teacherName,
                    schoolName: schoolName,
                  );
                  ParticipationWhatsAppHelper.showWhatsAppModal(
                    context: context,
                    messageText: msg,
                    title: '${session.className} Veli Grubu Tebrik Mesajı',
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Veli Grubuna Tebrik Mesajı Gönder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Kapat Butonu
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Kapat',
                  style: AppFonts.outfit(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
