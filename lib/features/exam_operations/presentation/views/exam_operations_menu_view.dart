import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../analytics/presentation/views/exam_analysis_list_view.dart';
import '../../../analytics/presentation/widgets/class_report_card_comments_modal.dart';
import 'exam_tracking_view.dart';
import 'project_tracking_view.dart';
import 'quiz_list_view.dart';

/// SınıfCepte - Sınav İşlemleri Modülü Ana Menüsü (Şirin & Kompakt Tasarım)
class ExamOperationsMenuView extends ConsumerWidget {
  const ExamOperationsMenuView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subModules = [
      {
        'title': 'Quiz & Sözlü Not Çizelgesi',
        'subtitle': 'Sabit öğrenci listesi, dinamik sınav kolonları & canlı ortalama',
        'emoji': '📊',
        'color': AppColors.secondary,
        'badge': 'Dinamik Çizelge',
        'target': const QuizListView(),
      },
      {
        'title': 'Proje & Performans Takibi',
        'subtitle': 'MEB uyumlu 100 puanlık Rubric ölçeği, hızlı puanlama & teslim',
        'emoji': '📋',
        'color': AppColors.info,
        'badge': '10 Kriterli Rubric',
        'target': const ProjectTrackingView(),
      },
      {
        'title': 'MEB / ÖSYM & Okul Sınav Takibi',
        'subtitle': 'Resmî sınav geri sayımı & "📌 Okulum" yazılı sınav takvimi',
        'emoji': '⏳',
        'color': AppColors.primary,
        'badge': 'Geri Sayım',
        'target': const ExamTrackingView(),
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      appBar: const CustomAppBar(
        title: 'Sınav İşlemleri',
        showBackButton: true,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // Üst Bilgilendirme Banner'ı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.primary.withValues(alpha: 0.2),
                          const Color(0xFF1E293B),
                        ]
                      : [
                          AppColors.primary.withValues(alpha: 0.08),
                          Colors.white,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('🎯', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Öğrenci Değerlendirme & Takip',
                          style: AppFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Quiz, sözlü, proje ve sınav tarihlerini tek merkezden yönetin.',
                          style: AppFonts.outfit(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3 Ana Modül Kartları
            ...subModules.map((item) {
              final color = item['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EEF5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => item['target'] as Widget),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(item['emoji'] as String, style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['title'] as String,
                                          style: AppFonts.outfit(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item['badge'] as String,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item['subtitle'] as String,
                                    style: AppFonts.outfit(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // Raporlar kendi işinin yanında: soru analizi ve karne görüşü
            // notla ilgili, burada durur. Eskiden ikisi de ayrıca üç
            // çizgili menüdeki "Raporlar & İstatistikler" ekranından
            // açılıyordu; karne görüşünün başka evi yoktu (17 Ekim 2026).
            _raporSatiri(
              isDark: isDark,
              emoji: '💡',
              baslik: 'Soru Bazlı Sınav Analizi & MEB Raporları',
              aciklama:
                  'Soru zorluk grafikleri ve resmî MEB PDF analiz raporlarına ulaşmak için dokunun.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ExamAnalysisListView()),
                );
              },
            ),
            const SizedBox(height: 10),
            _raporSatiri(
              isDark: isDark,
              emoji: '📝',
              baslik: 'e-Okul Karne Görüşü',
              aciklama:
                  'Ders içi katılım kayıtlarından öğrenci başına karne görüşü ve katılım puanı; e-Okul\'a seri kopyalama.',
              onTap: () => ClassReportCardCommentsModal.show(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Rapor satırı (soru analizi, karne görüşü): tıklanabilir bilgi kartı.
  Widget _raporSatiri({
    required bool isDark,
    required String emoji,
    required String baslik,
    required String aciklama,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.amber.shade300,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baslik,
                        style: AppFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        aciklama,
                        style: AppFonts.outfit(
                          fontSize: 11,
                          color: isDark ? Colors.amber.shade100.withValues(alpha: 0.8) : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

