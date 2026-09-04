import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/models/curriculum_outcome_model.dart';

/// SınıfCepte - 39+1 Haftalık Müfredat Akışı Tatil Kartı (Ultra Responsive & Sıfır Taşma)
class HolidayCard extends StatelessWidget {
  final CurriculumOutcomeModel outcome;
  final bool isCurrentWeek;
  final bool isCarousel;

  const HolidayCard({
    super.key,
    required this.outcome,
    this.isCurrentWeek = false,
    this.isCarousel = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateRangeText = AppDateFormatter.getWeekDateRangeText(outcome.weekNumber);

    final isSummer = outcome.weekNumber >= 40 ||
        outcome.unitTitle.toLowerCase().contains('yaz');
    final isWinter = outcome.unitTitle.toLowerCase().contains('yarıyıl') ||
        outcome.unitTitle.toLowerCase().contains('sömestr');
    final isSpring = outcome.unitTitle.toLowerCase().contains('2. dönem ara tatil');

    final gradientColors = isSummer
        ? [const Color(0xFFF59E0B), const Color(0xFFEA580C)]
        : isWinter
            ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
            : isSpring
                ? [const Color(0xFF10B981), const Color(0xFF059669)]
                : [const Color(0xFFD97706), const Color(0xFFB45309)];

    final holidayIcon = isSummer
        ? Icons.wb_sunny_rounded
        : isWinter
            ? Icons.ac_unit_rounded
            : isSpring
                ? Icons.park_rounded
                : Icons.beach_access_rounded;

    final holidayEmoji = isSummer ? '🌴' : isWinter ? '⛄' : isSpring ? '🌿' : '🏖️';
    final holidayBadgeTitle = isSummer ? 'YAZ TATİLİ' : 'RESMÎ TATİL';

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: isCurrentWeek
              ? Border.all(color: gradientColors[0], width: 2.5)
              : Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: isCarousel ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Üst Başlık Şeridi (2 Katmanlı Güvenli Düzen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Satır 1: Hafta Başlığı + Tatil Rozeti
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${outcome.weekNumber}. Hafta',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(holidayEmoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              holidayBadgeTitle,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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
                ],
              ),
            ),

            // İçerik Gövdesi (Kaydırma Korumalı / Esnek)
            if (isCarousel)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: gradientColors[0].withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              holidayIcon,
                              size: 40,
                              color: gradientColors[0],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            outcome.unitTitle.isNotEmpty
                                ? outcome.unitTitle
                                : 'Tatil Haftası 🎉',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            outcome.outcomeDescription.isNotEmpty
                                ? outcome.outcomeDescription
                                : 'Bu hafta eğitim ve öğretime ara verilmiştir. İyi tatiller ve dinlenmeler!',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.spa_rounded, size: 14, color: gradientColors[0]),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'İyi Dinlenmeler! 🎈',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: gradientColors[0].withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        holidayIcon,
                        size: 32,
                        color: gradientColors[0],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      outcome.unitTitle.isNotEmpty
                          ? outcome.unitTitle
                          : 'Tatil Haftası 🎉',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      outcome.outcomeDescription.isNotEmpty
                          ? outcome.outcomeDescription
                          : 'Bu hafta eğitim ve öğretime ara verilmiştir. İyi tatiller ve dinlenmeler!',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.spa_rounded, size: 13, color: gradientColors[0]),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'İyi Dinlenmeler! 🎈',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
