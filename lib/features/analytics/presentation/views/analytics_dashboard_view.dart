import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../providers/exam_analysis_provider.dart';
import 'exam_analysis_list_view.dart';
import '../widgets/class_report_card_comments_modal.dart';
import '../../../attendance/presentation/widgets/participation_cumulative_reports_modal.dart';

enum ReportCategory { all, exam, participation, smartTools }

class ReportItemModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String badgeText;
  final Color badgeColor;
  final ReportCategory category;
  final VoidCallback onTap;

  const ReportItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.badgeText,
    required this.badgeColor,
    required this.category,
    required this.onTap,
  });
}

/// SınıfCepte - Minimalist, Modüler ve Akıllı Filtreli Analiz & Rapor Merkezi (UI-UX-MAX)
class AnalyticsDashboardView extends ConsumerStatefulWidget {
  const AnalyticsDashboardView({super.key});

  @override
  ConsumerState<AnalyticsDashboardView> createState() => _AnalyticsDashboardViewState();
}

class _AnalyticsDashboardViewState extends ConsumerState<AnalyticsDashboardView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ReportCategory _selectedCategory = ReportCategory.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examsAsync = ref.watch(examAnalysisListProvider);
    final exams = examsAsync.valueOrNull ?? [];
    final totalExams = exams.length;

    // Tüm Raporların Modüler Listesi
    final List<ReportItemModel> allReports = [
      // 1. SINAV ANALİZİ
      ReportItemModel(
        id: 'exam_analysis',
        title: 'Soru Bazlı Sınav Analizi & Dağılımı',
        description: 'Soru başarı yüzdeleri, zorluk dereceleri, not dağılım grafikleri ve MEB resmî sınav analiz çıktısı.',
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF2563EB),
        badgeText: totalExams > 0 ? '$totalExams Kayıtlı Sınav' : 'MEB Uyumlu',
        badgeColor: const Color(0xFF2563EB),
        category: ReportCategory.exam,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExamAnalysisListView()),
          );
        },
      ),

      // 2. DERS İÇİ KATILIM & VELİ TOPLANTISI
      ReportItemModel(
        id: 'participation_parent_meeting',
        title: 'Ders İçi Katılım & Veli Toplantısı Raporları',
        description: 'Dönem/Yıl sonu resmî idare çizelgeleri, veli toplantısı başarı kılavuzu ve bireysel öğrenci gelişim özetleri.',
        icon: Icons.groups_rounded,
        color: const Color(0xFFD97706),
        badgeText: 'Toplantı & İdare',
        badgeColor: const Color(0xFFD97706),
        category: ReportCategory.participation,
        onTap: () {
          HapticFeedback.lightImpact();
          ParticipationCumulativeReportsModal.show(context);
        },
      ),

      // 3. AKILLI E-OKUL KARNE GÖRÜŞÜ
      ReportItemModel(
        id: 'smart_report_comment',
        title: 'Akıllı e-Okul Karne Görüşü & Puanlama',
        description: 'Ders içi verilere göre 100 üzerinden katılım puanı, isimsiz pedagojik görüşler ve seri kopyalama.',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFFE11D48),
        badgeText: 'Seri e-Okul Modu',
        badgeColor: const Color(0xFFE11D48),
        category: ReportCategory.smartTools,
        onTap: () {
          HapticFeedback.lightImpact();
          ClassReportCardCommentsModal.show(context);
        },
      ),
    ];

    // Akıllı Filtreleme Mantığı (Kategori + Canlı Arama)
    final filteredReports = allReports.where((r) {
      if (_selectedCategory != ReportCategory.all && r.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.title.toLowerCase().contains(q) || r.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      extendBody: true,
      appBar: const CustomAppBar(
        title: 'Analiz & Raporlar',
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(examAnalysisListProvider.notifier).loadExams();
          },
          child: ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 95),
            children: [
              // 1. Minimal Başlık
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapor & Analiz Merkezi',
                    style: GoogleFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'MEB uyumlu resmî evraklar ve akıllı analizler',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Akıllı Arama Çubuğu
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rapor veya evrak adı ara... (Örn: Sınav, Veli, Karne)',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 3. Kategori Filtre Çipleri
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(
                      label: 'Tümü (${allReports.length})',
                      category: ReportCategory.all,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCategoryChip(
                      label: '📝 Sınavlar',
                      category: ReportCategory.exam,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCategoryChip(
                      label: '👥 Katılım & Veli',
                      category: ReportCategory.participation,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCategoryChip(
                      label: '✨ Akıllı Araçlar',
                      category: ReportCategory.smartTools,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Minimalist Rapor Listesi
              if (filteredReports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 36, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Arama kriterine uygun rapor bulunamadı.',
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...filteredReports.map((report) {
                  return _buildMinimalReportCard(report, isDark);
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: ref.watch(navigationIndexProvider),
        onTap: (index) {
          try {
            ref.read(navigationIndexProvider.notifier).state = index;
            Navigator.of(context).popUntil((route) => route.isFirst);
          } catch (e, stackTrace) {
            debugPrint('AnalyticsDashboardView bottom nav tap error: $e\n$stackTrace');
          }
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required ReportCategory category,
    required bool isDark,
  }) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedCategory = category);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  /// Minimalist, Net ve Ferah Rapor Satır Kartı
  Widget _buildMinimalReportCard(ReportItemModel item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol Renkli İkon Rozeti
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.color.withValues(alpha: isDark ? 0.35 : 0.25),
                    ),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 12),

                // Orta Metin Alanı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.badgeText,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: item.badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Sağ Ok İkonu
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
