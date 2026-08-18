import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../providers/classroom_participation_provider.dart';

/// SınıfCepte - Sıfır Taşma (Zero-Overflow) Minimal Tek Butonlu Hızlı Eylem Çubuğu
class ParticipationBatchToolbar extends ConsumerWidget {
  const ParticipationBatchToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionAsync = ref.watch(currentParticipationSessionProvider);
    final session = sessionAsync.valueOrNull;

    if (session == null || session.evaluations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol: Canlı Özet İstatistiği (Esnek & Taşma Korumalı)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ödev: %${session.homeworkCompletionRate.toStringAsFixed(0)} • ⭐ ${session.totalStarsAwarded}',
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sağ: Tek Düğme - Tüm Sınıfı Fulle (Esnek & Taşma Korumalı)
          Flexible(
            child: InkWell(
              onTap: () {
                ref.read(currentParticipationSessionProvider.notifier).fillAllFullEvaluation();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tüm sınıf: Ödev Tam, Kitap Tam, Zamanında ve 3 Yıldız (⭐⭐⭐) yapıldı! ⚡'),
                    duration: Duration(seconds: 1),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.5 : 0.35),
                    width: 1.2,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        'Tümünü Fulle (3 ⭐)',
                        style: AppFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
