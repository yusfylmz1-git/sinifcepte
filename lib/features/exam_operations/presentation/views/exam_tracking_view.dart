import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../data/models/exam_model.dart';
import '../../providers/exam_tracking_provider.dart';

/// SınıfCepte - 3/3: MEB / ÖSYM Sınav Takibi & Okulum Yazılı Sınavları (Şirin & Kompakt Tasarım)
class ExamTrackingView extends ConsumerStatefulWidget {
  const ExamTrackingView({super.key});

  @override
  ConsumerState<ExamTrackingView> createState() => _ExamTrackingViewState();
}

class _ExamTrackingViewState extends ConsumerState<ExamTrackingView> {
  int _selectedTab = 0; // 0: Resmî, 1: Favoriler, 2: Okulum
  String _selectedInstitution = 'all'; // all, MEB, ÖSYM, AGS, MTSK, e-Sınav, AÖF, EKYS, MSÜ, BİLSEM

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examState = ref.watch(examTrackingProvider);

    List<ExamModel> currentExams;
    if (_selectedTab == 0) {
      currentExams = examState.officialExams;
      if (_selectedInstitution != 'all') {
        currentExams = currentExams
            .where((e) => e.institution.toUpperCase().contains(_selectedInstitution.toUpperCase()))
            .toList();
      }
    } else if (_selectedTab == 1) {
      currentExams = examState.favoriteExams;
    } else {
      currentExams = examState.schoolExams;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      extendBody: true,
      appBar: CustomAppBar(
        title: 'Sınav Takvimi',
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
        actions: [
          IconButton(
            tooltip: 'Sınav Takvimini Yenile',
            icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            onPressed: () async {
              // Mesaj DÜRÜST olmalı: eskiden hiçbir şey değişmese bile
              // "güncellendi!" deniyordu. Öğretmen yeni tarih beklerken
              // eski veriyle kalıyor ama sistem başarı bildiriyordu.
              final yeniVeriGeldi = await ref
                  .read(examTrackingProvider.notifier)
                  .syncOfficialExams();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(yeniVeriGeldi
                        ? 'Sınav takvimi güncellendi 🏛️'
                        : 'Sınav takviminiz güncel ✨'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Ana Kategori Segmented Tab Bar
            _buildCuteTabBar(isDark, examState),

            // 2. Resmî Sınavlar İçin Yatay Kurum Filtreleme Çipleri
            if (_selectedTab == 0) _buildInstitutionFilterChips(isDark),

            // 3. Sınav Kartları Listesi (Kompakt & Dip Dibe)
            Expanded(
              child: examState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => ref.read(examTrackingProvider.notifier).syncOfficialExams(),
                      child: _buildExamList(context, isDark, currentExams),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.38),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAddSchoolExamModal(context, isDark),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_task_rounded, color: Colors.white, size: 19),
                  const SizedBox(width: 6),
                  Text(
                    'Sınav Ekle',
                    style: AppFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
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
            debugPrint('ExamTrackingView bottom nav tap error: $e\n$stackTrace');
          }
        },
      ),
    );
  }

  Widget _buildCuteTabBar(bool isDark, ExamTrackingState state) {
    final tabs = [
      {'label': 'Sınavlar', 'icon': '🏛️', 'count': state.officialExams.length},
      {'label': 'Favoriler', 'icon': '⭐', 'count': state.favoriteExams.length},
      {'label': 'Okulum', 'icon': '📌', 'count': state.schoolExams.length},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE9EEF5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedTab == idx;
          final item = tabs[idx];
          final count = item['count'] as int;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = idx),
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.primary : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${item['icon']}', style: const TextStyle(fontSize: 11.5)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${item['label']}',
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.primary)
                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.12))
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDark ? Colors.white : AppColors.primary)
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInstitutionFilterChips(bool isDark) {
    final filters = [
      {'key': 'all', 'label': '🌟 Tümü'},
      {'key': 'MEB', 'label': '🏛️ MEB'},
      {'key': 'ÖSYM', 'label': '🎓 ÖSYM'},
      {'key': 'AGS', 'label': '🏫 AGS'},
      {'key': 'MTSK', 'label': '🚗 MTSK'},
      {'key': 'e-Sınav', 'label': '💻 e-Sınav'},
      {'key': 'AÖF', 'label': '📚 AÖF'},
      {'key': 'EKYS', 'label': '💼 EKYS'},
      {'key': 'MSÜ', 'label': '🎖️ MSÜ'},
      {'key': 'BİLSEM', 'label': '💡 BİLSEM'},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final item = filters[idx];
          final key = item['key']!;
          final isSelected = _selectedInstitution == key;

          return InkWell(
            onTap: () => setState(() => _selectedInstitution = key),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? const Color(0xFF334155) : Colors.transparent),
                ),
              ),
              child: Center(
                child: Text(
                  item['label']!,
                  style: AppFonts.outfit(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamList(BuildContext context, bool isDark, List<ExamModel> exams) {
    if (exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('📅', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(height: 10),
              Text(
                _selectedTab == 1
                    ? 'Henüz favori sınav eklemediniz.\nSınav satırlarındaki ⭐ ikonuna dokunarak ekleyebilirsiniz.'
                    : (_selectedTab == 2
                        ? 'Henüz okul sınavı eklemediniz.\nAlttaki (+ Sınav Ekle) butonuyla hemen ekleyebilirsiniz.'
                        : 'Kayıtlı resmî sınav bulunmuyor.'),
                textAlign: TextAlign.center,
                style: AppFonts.outfit(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 85),
      itemCount: exams.length,
      separatorBuilder: (context, index) => const SizedBox(height: 5),
      itemBuilder: (context, index) {
        final exam = exams[index];
        return _buildCompactExamRow(context, isDark, exam);
      },
    );
  }

  /// Ultra-Kompakt, Okunuşu Kolay ve Dip Dibe Sınav Satırı
  Widget _buildCompactExamRow(BuildContext context, bool isDark, ExamModel exam) {
    final days = exam.daysRemaining;
    final isLast24 = exam.isLast24Hours;
    final isPast = exam.isPast;
    final isSchool = exam.isSchoolExam;

    final institutionColor = _getInstitutionColor(exam.institution, isSchool);
    final institutionEmoji = _getInstitutionEmoji(exam.institution, isSchool);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EEF5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            // 1. Sol: Kurum Renkli Mini Avatar Kutusu
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: institutionColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(institutionEmoji, style: const TextStyle(fontSize: 13)),
                  Text(
                    isSchool
                        ? (exam.className ?? 'Okul')
                        : (exam.institution.length > 5 ? exam.institution.substring(0, 4) : exam.institution),
                    style: AppFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: institutionColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),

            // 2. Orta: Sınav Adı ve Tarih Bilgisi (Expanded)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sınav Başlığı
                  Text(
                    exam.title,
                    style: AppFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.5),

                  // Tarih & Son Başvuru Satırı
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.primary.withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Text(
                        _formatExamDate(exam.examDate),
                        style: AppFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                      if (exam.applicationDeadline != null && !isPast) ...[
                        const SizedBox(width: 5),
                        Text('•', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Başvuru: ${_formatShortDate(exam.applicationDeadline!)}',
                            style: AppFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.red.shade400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // 3. Sağ: Kalan Gün Rozeti
            _buildCountdownBadge(days, isPast, isLast24, isDark),
            const SizedBox(width: 4),

            // 4. Sağ Uç: Başvuru Linki veya Favori / Sil Butonu
            if (exam.applicationLink != null && exam.applicationLink!.isNotEmpty) ...[
              InkWell(
                onTap: () => _openApplicationLink(context, exam.applicationLink!),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(3.5),
                  child: Icon(Icons.open_in_new_rounded, size: 15, color: AppColors.primary.withValues(alpha: 0.9)),
                ),
              ),
            ],

            if (isSchool && exam.intId != null)
              InkWell(
                onTap: () => _confirmDeleteSchoolExam(context, exam),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(3.5),
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400),
                ),
              )
            else
              InkWell(
                onTap: () => ref.read(examTrackingProvider.notifier).toggleFavorite(exam.id),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(3.5),
                  child: Icon(
                    exam.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: exam.isFavorite ? Colors.amber : (isDark ? Colors.white30 : Colors.grey.shade400),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownBadge(int days, bool isPast, bool isLast24, bool isDark) {
    if (isPast) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Geçti',
          style: AppFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    if (isLast24 || days == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '🚨 Bugün!',
          style: AppFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.red),
        ),
      );
    }

    if (days <= 7) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '⚡ $days gün',
          style: AppFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade800,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '⏳ $days gün',
        style: AppFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Color _getInstitutionColor(String inst, bool isSchool) {
    if (isSchool) return const Color(0xFFD97706);
    final upper = inst.toUpperCase();
    if (upper.contains('MTSK') || upper.contains('EHLİYET')) return const Color(0xFF059669);
    if (upper.contains('E-SINAV') || upper.contains('E-YDS') || upper.contains('ESINAV')) return const Color(0xFF0284C7);
    if (upper.contains('BİLSEM') || upper.contains('BILSEM')) return const Color(0xFF9333EA);
    if (upper.contains('MSÜ') || upper.contains('MSU')) return const Color(0xFF0F766E);
    if (upper.contains('AÖF') || upper.contains('AOF')) return const Color(0xFF4F46E5);
    if (upper.contains('EKYS') || upper.contains('MÜDÜR') || upper.contains('MUDUR')) return const Color(0xFFB45309);
    if (upper.contains('AGS') || upper.contains('AKADEMİ') || upper.contains('AKADEMI')) return const Color(0xFFE11D48);
    if (upper.contains('ÖSYM') || upper.contains('OSYM')) return const Color(0xFF4F46E5);
    if (upper.contains('MEB')) return AppColors.primary;
    return Colors.teal;
  }

  String _getInstitutionEmoji(String inst, bool isSchool) {
    if (isSchool) return '🏫';
    final upper = inst.toUpperCase();
    if (upper.contains('MTSK') || upper.contains('EHLİYET')) return '🚗';
    if (upper.contains('E-SINAV') || upper.contains('E-YDS') || upper.contains('ESINAV')) return '💻';
    if (upper.contains('BİLSEM') || upper.contains('BILSEM')) return '💡';
    if (upper.contains('MSÜ') || upper.contains('MSU')) return '🎖️';
    if (upper.contains('AÖF') || upper.contains('AOF')) return '📚';
    if (upper.contains('EKYS') || upper.contains('MÜDÜR') || upper.contains('MUDUR')) return '💼';
    if (upper.contains('AGS') || upper.contains('AKADEMİ') || upper.contains('AKADEMI')) return '🏫';
    if (upper.contains('ÖSYM') || upper.contains('OSYM')) return '🎓';
    if (upper.contains('MEB')) return '🏛️';
    return '📝';
  }

  String _formatExamDate(DateTime dt) {
    final months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeStr = (dt.hour == 0 && dt.minute == 0) ? '' : ' ($hour:$minute)';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}$timeStr';
  }

  String _formatShortDate(DateTime dt) {
    final months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  void _openApplicationLink(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bağlantı açılamadı: $url')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('ExamTrackingView._openApplicationLink error: $e\n$stackTrace');
    }
  }

  void _showAddSchoolExamModal(BuildContext context, bool isDark) {
    final titleController = TextEditingController();
    String? selectedClassName;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    final classesAsync = ref.read(classListProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tutamaç Barı
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Başlık Satırı
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Yeni Okul Sınavı Ekle',
                                style: AppFonts.outfit(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Sınıfınız için yazılı / deneme takvimi oluşturun',
                                style: AppFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Sınav Başlığı
                    Text(
                      'SINAV ADI / KONUSU',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      maxLength: 80,
                      style: AppFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Örn: 1. Dönem 1. Matematik Yazılısı',
                        hintStyle: AppFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, size: 18, color: AppColors.primary),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Sınıf Seçimi
                    Text(
                      'SINIF VEYA ŞUBE',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    classesAsync.maybeWhen(
                      data: (classes) {
                        if (classes.isNotEmpty) {
                          return DropdownButtonFormField<String>(
                            initialValue: selectedClassName,
                            style: AppFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: InputDecoration(
                              hintText: 'Sınıf Seçin (Opsiyonel)',
                              hintStyle: AppFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            items: classes.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.name,
                                child: Text(c.name, style: AppFonts.outfit(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() => selectedClassName = val);
                            },
                          );
                        }
                        return TextField(
                          onChanged: (val) => selectedClassName = val,
                          maxLength: 20,
                          style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Sınıf (Örn: 10-A, 8-B)',
                            hintStyle: AppFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                        );
                      },
                      orElse: () => TextField(
                        onChanged: (val) => selectedClassName = val,
                        maxLength: 20,
                        style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Sınıf (Örn: 10-A, 8-B)',
                          hintStyle: AppFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Sınav Tarihi Seçici Kartı
                    Text(
                      'SINAV TARİHİ',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2028),
                          locale: const Locale('tr', 'TR'),
                          helpText: 'Sınav Tarihi Seçin',
                          cancelText: 'İptal',
                          confirmText: 'Seç',
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatExamDate(selectedDate),
                                style: AppFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_calendar_rounded, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Değiştir',
                                    style: AppFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Otomatik Hatırlatıcı Bilgi Kapsülü
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sınav gününe 24 saat kala otomatik alarm bildirimi kurulacaktır.',
                              style: AppFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 5. Kaydet Butonu
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isNotEmpty) {
                            await ref.read(examTrackingProvider.notifier).addSchoolExam(
                                  title: title,
                                  examDate: selectedDate,
                                  className: selectedClassName,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_task_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Takvime Kaydet & Bildirim Kur',
                              style: AppFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSchoolExam(BuildContext context, ExamModel exam) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Sınavı Sil', style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text('"${exam.title}" sınav kaydını silmek istediğinizden emin misiniz?', style: AppFonts.outfit(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (exam.intId != null) {
                  ref.read(examTrackingProvider.notifier).deleteSchoolExam(exam.intId!);
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }
}


