import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../providers/outcomes_provider.dart';
import '../widgets/holiday_card.dart';
import '../widgets/outcome_carousel_card.dart';

/// SınıfCepte - Resmî MEB Maarif Modeli 39+1 Haftalık Kazanımlar Modülü
class WeeklyOutcomesView extends ConsumerStatefulWidget {
  const WeeklyOutcomesView({super.key});

  @override
  ConsumerState<WeeklyOutcomesView> createState() => _WeeklyOutcomesViewState();
}

class _WeeklyOutcomesViewState extends ConsumerState<WeeklyOutcomesView> {
  PageController? _pageController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Yeni MEB Maarif Kategori ve Akordeon Durumları
  int _selectedCategoryIndex = 0; // 0: Ders, 1: Seçmeli, 2: Kurs, 3: İHO, 4: Harezmi
  final Set<String> _expandedSubjectCodes = {};
  final TextEditingController _subjectSearchController = TextEditingController();
  bool _isSubjectSearching = false;

  @override
  void initState() {
    super.initState();
    final activeWeek = ref.read(activeAcademicWeekProvider);
    _pageController = PageController(
      initialPage: (activeWeek - 1).clamp(0, 39),
      viewportFraction: 0.88,
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _searchController.dispose();
    _subjectSearchController.dispose();
    super.dispose();
  }

  void _scrollToCurrentWeek(int totalWeeks) {
    if (_pageController == null || totalWeeks == 0) return;
    final currentWeek = ref.read(activeAcademicWeekProvider);
    final targetPage = (currentWeek - 1).clamp(0, totalWeeks - 1);

    _pageController!.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currentWeek >= 40
                    ? 'Yaz Tatili kartına yönlendirildi 🏖️'
                    : 'Aktif haftaya ($currentWeek. Hafta) yönlendirildi 🎯',
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSubject(Map<String, dynamic> item) {
    final activeWeek = ref.read(activeAcademicWeekProvider);
    _pageController?.dispose();
    _pageController = PageController(
      initialPage: (activeWeek - 1).clamp(0, 39),
      viewportFraction: 0.88,
    );
    ref.read(selectedSubjectProvider.notifier).state = item;
  }

  void _openFavoriteSubject(int grade, String subjectCode, String publisher) {
    final activeWeek = ref.read(activeAcademicWeekProvider);
    _pageController?.dispose();
    _pageController = PageController(
      initialPage: (activeWeek - 1).clamp(0, 39),
      viewportFraction: 0.88,
    );
    ref.read(selectedGradeProvider.notifier).state = grade;
    ref.read(selectedSubjectProvider.notifier).state = {
      'subject_code': subjectCode,
      'subject_name': subjectCode,
      'publisher': publisher,
    };
    ref.read(isFavoritesModeProvider.notifier).state = false;
  }

  IconData _getSubjectIcon(String subjectName, String subjectCode) {
    final lower = subjectName.toLowerCase();
    if (lower.contains('bilişim') || lower.contains('yazılım') || lower.contains('robot')) {
      return Icons.computer_rounded;
    } else if (lower.contains('matematik')) {
      return Icons.calculate_rounded;
    } else if (lower.contains('fen') || lower.contains('fizik') || lower.contains('kimya') || lower.contains('biyoloji')) {
      return Icons.science_rounded;
    } else if (lower.contains('türkçe') || lower.contains('edebiyat')) {
      return Icons.menu_book_rounded;
    } else if (lower.contains('sosyal') || lower.contains('tarih') || lower.contains('coğrafya') || lower.contains('inkılap')) {
      return Icons.public_rounded;
    } else if (lower.contains('ingilizce') || lower.contains('almanca') || lower.contains('fransızca') || lower.contains('yabancı')) {
      return Icons.language_rounded;
    } else if (lower.contains('din') || lower.contains('ahlak')) {
      return Icons.auto_stories_rounded;
    } else if (lower.contains('beden') || lower.contains('spor')) {
      return Icons.sports_basketball_rounded;
    } else if (lower.contains('görsel') || lower.contains('resim') || lower.contains('sanat')) {
      return Icons.palette_rounded;
    } else if (lower.contains('müzik')) {
      return Icons.music_note_rounded;
    } else if (lower.contains('teknoloji') || lower.contains('tasarım')) {
      return Icons.architecture_rounded;
    } else if (lower.contains('rehberlik') || lower.contains('kariyer')) {
      return Icons.psychology_rounded;
    }
    return Icons.school_rounded;
  }

  Color _getSubjectColor(String subjectName) {
    final lower = subjectName.toLowerCase();
    if (lower.contains('bilişim') || lower.contains('yazılım')) {
      return const Color(0xFF0EA5E9);
    } else if (lower.contains('matematik')) {
      return const Color(0xFF6366F1);
    } else if (lower.contains('fen')) {
      return const Color(0xFF10B981);
    } else if (lower.contains('türkçe') || lower.contains('edebiyat')) {
      return const Color(0xFFF59E0B);
    } else if (lower.contains('sosyal') || lower.contains('tarih')) {
      return const Color(0xFFEC4899);
    } else if (lower.contains('ingilizce') || lower.contains('dil')) {
      return const Color(0xFF8B5CF6);
    } else if (lower.contains('din')) {
      return const Color(0xFF14B8A6);
    } else if (lower.contains('beden')) {
      return const Color(0xFFF97316);
    } else if (lower.contains('müzik') || lower.contains('görsel')) {
      return const Color(0xFFD946EF);
    }
    return const Color(0xFF4F46E5);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedGrade = ref.watch(selectedGradeProvider);
    final selectedSubject = ref.watch(selectedSubjectProvider);
    final isFavMode = ref.watch(isFavoritesModeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: isFavMode
            ? '⭐ Favori Derslerim'
            : (selectedSubject != null
                ? '${selectedSubject['subject_name']}'
                : (selectedGrade != null ? '$selectedGrade. Sınıf' : 'Müfredat & Kazanımlar')),
        subtitle: selectedSubject != null
            ? '$selectedGrade. Sınıf • ${selectedSubject['publisher']}'
            : (selectedGrade != null ? null : null),
        showBackButton: true,
        showDrawerButton: false,
        onBackPressed: () {
          try {
            if (selectedSubject != null) {
              ref.read(selectedSubjectProvider.notifier).state = null;
              ref.read(outcomeSearchQueryProvider.notifier).state = '';
              setState(() => _isSearching = false);
            } else if (selectedGrade != null) {
              ref.read(selectedGradeProvider.notifier).state = null;
              setState(() {
                _isSubjectSearching = false;
                _subjectSearchController.clear();
              });
            } else if (isFavMode) {
              ref.read(isFavoritesModeProvider.notifier).state = false;
            } else {
              ref.read(navigationIndexProvider.notifier).state = 0; // Ana Sayfaya / Özet sekmesine dön
            }
          } catch (e, stackTrace) {
            debugPrint('WeeklyOutcomesView geri navigasyon hatası: $e\n$stackTrace');
          }
        },
        showProfileAvatar: false,
        actions: [
          if (selectedSubject != null) ...[
            IconButton(
              onPressed: () {
                setState(() => _isSearching = !_isSearching);
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(outcomeSearchQueryProvider.notifier).state = '';
                }
              },
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              tooltip: 'Kazanımlarda Ara',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () {
                final outcomesAsync = ref.read(currentCurriculumOutcomesProvider);
                outcomesAsync.whenData((list) => _scrollToCurrentWeek(list.length));
              },
              icon: const Icon(Icons.my_location_rounded),
              tooltip: 'Bu Haftaya Git',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () {
                ref.read(isCarouselViewProvider.notifier).state =
                    !ref.read(isCarouselViewProvider);
              },
              icon: Icon(
                ref.watch(isCarouselViewProvider)
                    ? Icons.view_agenda_outlined
                    : Icons.view_carousel_rounded,
              ),
              tooltip: 'Görünümü Değiştir',
              visualDensity: VisualDensity.compact,
            ),
          ] else if (selectedGrade != null && !isFavMode) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isSubjectSearching = !_isSubjectSearching;
                  if (!_isSubjectSearching) {
                    _subjectSearchController.clear();
                  }
                });
              },
              icon: Icon(_isSubjectSearching ? Icons.close_rounded : Icons.search_rounded),
              tooltip: 'Derslerde Ara',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () {
                ref.read(isFavoritesModeProvider.notifier).state = true;
              },
              icon: const Icon(Icons.star_rounded, color: Colors.amber),
              tooltip: 'Favori Derslerim',
              visualDensity: VisualDensity.compact,
            ),
          ] else if (!isFavMode) ...[
            IconButton(
              onPressed: () {
                ref.read(isFavoritesModeProvider.notifier).state = true;
              },
              icon: const Icon(Icons.star_rounded, color: Colors.amber),
              tooltip: 'Favori Derslerim',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: isFavMode
            ? _buildFavoritesView(context)
            : (selectedSubject != null
                ? _buildOutcomesScreen(context, selectedGrade!, selectedSubject)
                : (selectedGrade != null
                    ? _buildSubjectSelection(context, selectedGrade)
                    : _buildCompactGradeGrid(context))),
      ),
    );
  }

  // ==========================================================
  // ADIM 1: ULTRA-KOMPAKT 1 - 12 SINIF SEÇİMİ (SingleScrollView)
  // ==========================================================
  Widget _buildCompactGradeGrid(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoriteKeys = ref.watch(favoriteSubjectsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. İLKOKUL KADEMESİ (1 - 4. Sınıf)
          _buildKademeRow(
            title: 'İLKOKUL',
            color: const Color(0xFF0284C7),
            icon: Icons.child_care_rounded,
            grades: const [1, 2, 3, 4],
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // 2. ORTAOKUL KADEMESİ (5 - 8. Sınıf)
          _buildKademeRow(
            title: 'ORTAOKUL',
            color: const Color(0xFF6366F1),
            icon: Icons.school_rounded,
            grades: const [5, 6, 7, 8],
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // 3. LİSE KADEMESİ (9 - 12. Sınıf)
          _buildKademeRow(
            title: 'LİSE',
            color: const Color(0xFF8B5CF6),
            icon: Icons.account_balance_rounded,
            grades: const [9, 10, 11, 12],
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // 4. FAVORİ DERSLERİM (Varsa ilk 5'i burada listelenir, 5'ten fazlaysa Tümünü Gör)
          if (favoriteKeys.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'FAVORİ DERSLERİM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  if (favoriteKeys.length > 5)
                    TextButton(
                      onPressed: () {
                        ref.read(isFavoritesModeProvider.notifier).state = true;
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tümünü Gör (${favoriteKeys.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.primary),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // İlk 5 Favori Kartı
            ...favoriteKeys.take(5).map((key) {
              final parts = key.split('_');
              final grade = int.tryParse(parts[0]) ?? 5;
              final subjectCode = parts.length > 1 ? parts[1] : 'GENEL';
              // Boş publisher BOŞ kalır: "MEB Yayınları" bir okul türü
              // değil, eski verideki "bilinmiyor" değeriydi. Varsayılan
              // olarak yazılınca favori açıldığında sorgu hiçbir kayıt
              // bulamıyor ve ders boş görünüyordu.
              final publisher = parts.length > 2 ? parts.sublist(2).join('_') : '';

              final iconColor = _getSubjectColor(subjectCode);
              final iconData = _getSubjectIcon(subjectCode, subjectCode);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => _openFavoriteSubject(grade, subjectCode, publisher),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(iconData, color: iconColor, size: 17),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$grade. Sınıf - $subjectCode',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  publisher,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () {
                              ref
                                  .read(favoriteSubjectsProvider.notifier)
                                  .toggleFavorite(grade, subjectCode, publisher);
                            },
                            icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                            tooltip: 'Favorilerden Çıkar',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ] else ...[
            // Favori Yoksa İpucu Kutusu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: isDark ? 0.25 : 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sık baktığınız dersleri yıldızlayarak buraya ekleyebilirsiniz.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKademeRow({
    required String title,
    required Color color,
    required IconData icon,
    required List<int> grades,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: grades.map((grade) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () {
                      ref.read(selectedGradeProvider.notifier).state = grade;
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withValues(alpha: isDark ? 0.35 : 0.2),
                          width: 1.1,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: isDark ? 0.18 : 0.08),
                            color.withValues(alpha: isDark ? 0.05 : 0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            '$grade. Sınıf',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================================
  // ADIM 2: BRANŞ / DERS SEÇİM EKRANI (MEB Maarif Akordeon & Kategori Mimarisi)
  // ==========================================================
  Widget _buildSubjectSelection(BuildContext context, int grade) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectsAsync = ref.watch(availableSubjectsForGradeProvider(grade));
    final favoriteKeys = ref.watch(favoriteSubjectsProvider);

    return subjectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(
        child: Text(
          'Dersler yüklenemedi: $err',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (allSubjects) {
        if (allSubjects.isEmpty) {
          return _buildNoSubjectsState(context, grade, isDark);
        }

        // 1. Kategori & Arama Filtreleme
        final filteredList = _filterSubjects(allSubjects, _selectedCategoryIndex, _subjectSearchController.text);

        // 2. Ders İsmine Göre Gruplama (Akordeon Yapısı)
        final groupedMap = _groupSubjects(filteredList);

        return Column(
          children: [
            const SizedBox(height: 8),

            // Arama Çubuğu (Açıksa)
            if (_isSubjectSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _subjectSearchController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Ders veya yayınevi ara...',
                    hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF10B981)),
                    suffixIcon: _subjectSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _subjectSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                ),
              ),

            // Üst Kategori Sekmeleri (Pill Filters: [ Ders | Seçmeli | Kurs | İHO | Harezmi ])
            _buildCategoryTabs(isDark),
            const SizedBox(height: 10),

            // Ders Listesi
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list_off_rounded, size: 40, color: isDark ? Colors.white30 : Colors.black26),
                            const SizedBox(height: 10),
                            Text(
                              _emptyCategoryTitle(_selectedCategoryIndex),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Boş sekmenin nedenini söyle: öğretmen "uygulama
                            // bozuk mu?" diye düşünmesin.
                            Text(
                              _emptyCategoryHint(_selectedCategoryIndex),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 85),
                      itemCount: groupedMap.keys.length,
                      itemBuilder: (context, index) {
                        final subjectName = groupedMap.keys.elementAt(index);
                        final items = groupedMap[subjectName]!;

                        final kart = items.length == 1
                            // Tek Yayınevi Olan Ders Kartı
                            ? _buildSingleSubjectCard(
                                context, grade, items.first, favoriteKeys, isDark)
                            // Çoklu Yayınevi Olan Açılır-Kapanır Akordeon Kartı
                            : _buildAccordionSubjectCard(
                                context, grade, subjectName, items,
                                favoriteKeys, isDark);

                        // Seçmeli bölümün başlığı.
                        //
                        // Öğretmen kendi dersini ararken pilot okul
                        // dersleri (Çoklu Yabancı Dil) ve seçmeliler
                        // arasında kaybolmamalı. Sorgu zaten temel
                        // dersleri öne alıyor; burada görsel ayrım
                        // yapılıyor.
                        if (!_secmeliBasliyor(groupedMap, index)) return kart;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _secmeliAyirici(isDark),
                            kart,
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Kategori Filtreleme Sekmeleri (Pills)
  Widget _buildCategoryTabs(bool isDark) {
    const categories = ['Ders', 'Seçmeli', 'Kurs', 'İHO', 'Harezmi'];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          final cat = categories[index];
          return InkWell(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF10B981) // Resmî MEB Maarif Yeşili
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Kategoriye ve Arama Sorgusuna Göre Ders Filtreleme
  List<Map<String, dynamic>> _filterSubjects(
    List<Map<String, dynamic>> subjects,
    int categoryIndex,
    String searchQuery,
  ) {
    final searchLower = searchQuery.trim().toLowerCase();

    return _applyCategoryFilter(subjects, categoryIndex, searchLower);
  }

  /// Boş kategori sekmesinin başlığı.
  String _emptyCategoryTitle(int categoryIndex) {
    switch (categoryIndex) {
      case 1:
        return 'Seçmeli ders planı henüz yok';
      case 2:
        return 'Kurs planı henüz yok';
      case 3:
        return 'İmam Hatip ders planı henüz yok';
      case 4:
        return 'Harezmî proje planı henüz yok';
      default:
        return 'Bu kategoride ders bulunamadı';
    }
  }

  /// Sekme neden boş? Öğretmen uygulamayı arızalı sanmasın diye açıklanır.
  String _emptyCategoryHint(int categoryIndex) {
    if (categoryIndex == 0) {
      return 'Arama filtresini temizleyip yeniden deneyin.';
    }
    return 'MEB bu kategori için haftalık yıllık plan yayımladığında '
        'uygulamaya otomatik eklenecek.';
  }

  List<Map<String, dynamic>> _applyCategoryFilter(
    List<Map<String, dynamic>> subjects,
    int categoryIndex,
    String searchLower,
  ) {
    return subjects.where((s) {
      final name = (s['subject_name'] as String? ?? '').toLowerCase();
      final code = (s['subject_code'] as String? ?? '').toLowerCase();
      final publisher = (s['publisher'] as String? ?? '').toLowerCase();
      final cat = (s['category'] as String? ?? '').toLowerCase();

      // Arama Kontrolü
      if (searchLower.isNotEmpty) {
        final matches = name.contains(searchLower) || code.contains(searchLower) || publisher.contains(searchLower);
        if (!matches) return false;
      }

      // 1. Veritabanındaki Doğrudan Kategori Alanı Eşleşmesi
      if (cat.isNotEmpty && cat != 'core') {
        if (categoryIndex == 1 && cat == 'elective') return true;
        if (categoryIndex == 2 && cat == 'course') return true;
        if (categoryIndex == 3 && cat == 'iho') return true;
        if (categoryIndex == 4 && cat == 'harezmi') return true;
        if (categoryIndex == 0 && cat != 'core') return false;
      }

      // 2. Anahtar Kelime Kural Tabanlı Eşleşme
      if (categoryIndex == 1) {
        // Seçmeli Dersler
        return name.contains('seçmeli') ||
            name.contains('secmeli') ||
            name.contains('masal') ||
            name.contains('zeka') ||
            name.contains('hukuk') ||
            name.contains('yazarlık') ||
            name.contains('düşünme') ||
            name.contains('çevre');
      } else if (categoryIndex == 2) {
        // Kurs (DYK)
        return name.contains('kurs') || name.contains('dyk') || name.contains('destekleme');
      } else if (categoryIndex == 3) {
        // İmam Hatip Ortaokulu (İHO)
        return name.contains('arapça') ||
            name.contains('arapca') ||
            name.contains('kur\'an') ||
            name.contains('kuran') ||
            name.contains('siyer') ||
            name.contains('peygamber') ||
            name.contains('temel dini') ||
            name.contains('dini');
      } else if (categoryIndex == 4) {
        // Harezmi Eğitim Modeli & Proje
        return name.contains('harezmi') || name.contains('proje') || name.contains('stem') || name.contains('bütünleşik');
      } else {
        // Ders (Zorunlu / Ana Dersler)
        final isElective = name.contains('seçmeli') ||
            name.contains('secmeli') ||
            name.contains('masal') ||
            name.contains('zeka') ||
            name.contains('hukuk') ||
            name.contains('yazarlık');
        final isKurs = name.contains('kurs') || name.contains('dyk');
        final isHarezmi = name.contains('harezmi');
        final isIhoSpecial = name.contains('arapça') ||
            name.contains('arapca') ||
            name.contains('kur\'an') ||
            name.contains('kuran') ||
            name.contains('siyer') ||
            name.contains('peygamber');
        return !isElective && !isKurs && !isHarezmi && !isIhoSpecial;
      }
    }).toList();
  }

  /// Ders İsmine Göre Gruplama (Akordeon İçin)
  /// Bu satırda seçmeli bölüm mü başlıyor?
  ///
  /// Sorgu sırası: temel (core) -> imam hatip (iho) -> seçmeli.
  /// Ayırıcı yalnızca geçişte bir kez çizilir.
  bool _secmeliBasliyor(
    Map<String, List<Map<String, dynamic>>> gruplar,
    int index,
  ) {
    if (index == 0) return false;
    String kategori(int i) =>
        gruplar[gruplar.keys.elementAt(i)]!.first['category'] as String? ??
        'core';
    final bu = kategori(index);
    if (bu == 'core' || bu == 'iho') return false;
    final onceki = kategori(index - 1);
    return onceki == 'core' || onceki == 'iho';
  }

  /// Temel derslerle seçmelileri ayıran başlık.
  Widget _secmeliAyirici(bool isDark) {
    final cizgi = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Expanded(child: Divider(thickness: 0.8, color: cizgi)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Seçmeli ve özel program dersleri',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(child: Divider(thickness: 0.8, color: cizgi)),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupSubjects(List<Map<String, dynamic>> subjects) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final item in subjects) {
      final name = item['subject_name'] as String? ?? 'Ders';
      map.putIfAbsent(name, () => []).add(item);
    }
    return map;
  }

  /// Tek Yayınevi Olan Ders Kartı (Örn: İngilizce Maarif)
  Widget _buildSingleSubjectCard(
    BuildContext context,
    int grade,
    Map<String, dynamic> item,
    Set<String> favoriteKeys,
    bool isDark,
  ) {
    final subjectCode = item['subject_code'] as String? ?? '';
    final subjectName = item['subject_name'] as String? ?? 'Ders';
    final publisher = item['publisher'] as String? ?? '';
    // Rozet VERIDEN gelir, metin aramasiyla degil.
    //
    // Once publisher'da "maarif"/"tymm" geciyor mu diye bakiliyordu.
    // Olcum: 89 ders rozet almasi gerekirken almiyor, 2 ders yanlis
    // aliyordu — publisher hem kaynagi hem okul turunu tasiyor,
    // bulunamayinca "MEB Yayinlari" yaziliyordu.
    final isMaarif = (item['is_maarif'] as int? ?? 0) == 1;

    final favKey = '${grade}_${subjectCode}_$publisher';
    final isFav = favoriteKeys.contains(favKey);

    final iconData = _getSubjectIcon(subjectName, subjectCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _openSubject(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Sol İkon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconData,
                    color: const Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Ders Adı
                Expanded(
                  child: Text(
                    subjectName,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Maarif Rozeti
                if (isMaarif) ...[
                  _buildMaarifBadge(),
                  const SizedBox(width: 6),
                ],

                // Favori Butonu
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    ref.read(favoriteSubjectsProvider.notifier).toggleFavorite(grade, subjectCode, publisher);
                  },
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFav ? Colors.amber : (isDark ? Colors.white30 : Colors.grey.shade400),
                    size: 20,
                  ),
                ),

                // Sağ Ok
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Çoklu Yayınevi Olan Açılır-Kapanır Akordeon Kartı (Örn: Türkçe 3 ⌄)
  Widget _buildAccordionSubjectCard(
    BuildContext context,
    int grade,
    String subjectName,
    List<Map<String, dynamic>> items,
    Set<String> favoriteKeys,
    bool isDark,
  ) {
    final groupKey = '${grade}_$subjectName';
    final isExpanded = _expandedSubjectCodes.contains(groupKey);
    final iconData = _getSubjectIcon(subjectName, items.first['subject_code'] as String? ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Ana Başlık Satırı
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSubjectCodes.remove(groupKey);
                  } else {
                    _expandedSubjectCodes.add(groupKey);
                  }
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Sol İkon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        iconData,
                        color: const Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Ders Adı
                    Expanded(
                      child: Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Yayın Sayısı Rozeti (Örn: 3)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Aç/Kapa Oku
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF10B981),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            // Açıldığında Görünen Alt Yayınevi Listesi
            if (isExpanded) ...[
              Divider(
                height: 1,
                thickness: 0.8,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 48,
                  thickness: 0.5,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                ),
                itemBuilder: (context, idx) {
                  final subItem = items[idx];
                  final publisher = subItem['publisher'] as String? ?? '';
                  final subjectCode = subItem['subject_code'] as String? ?? '';
                  // Rozet veriden gelir (bkz. yukarıdaki not).
                  final isMaarif = (subItem['is_maarif'] as int? ?? 0) == 1;
                  final favKey = '${grade}_${subjectCode}_$publisher';
                  final isFav = favoriteKeys.contains(favKey);

                  // Görüntülenecek Başlık (Örn: "Türkçe (Anıttepe Yay.)" veya "Türkçe")
                  String displayTitle = subjectName;
                  if (publisher.toLowerCase().contains('anıt') || publisher.toLowerCase().contains('anittepe')) {
                    displayTitle = '$subjectName (Anıttepe Yay.)';
                  } else if (publisher.toLowerCase().contains('koza')) {
                    displayTitle = '$subjectName (Koza Yayınları)';
                  } else if (publisher.toLowerCase().contains('özgün') || publisher.toLowerCase().contains('ozgun')) {
                    displayTitle = '$subjectName (Özgün Yayınları)';
                  } else if (publisher.toLowerCase().contains('hecce')) {
                    displayTitle = '$subjectName (Hecce Yayınları)';
                  } else if (isMaarif) {
                    displayTitle = subjectName;
                  } else if (publisher != 'MEB Yayınları' && publisher.isNotEmpty) {
                    displayTitle = '$subjectName ($publisher)';
                  }

                  return InkWell(
                    onTap: () => _openSubject(subItem),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 36, right: 12, top: 8, bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Color(0xFF10B981),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayTitle,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMaarif) ...[
                            _buildMaarifBadge(),
                            const SizedBox(width: 6),
                          ],
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () {
                              ref.read(favoriteSubjectsProvider.notifier).toggleFavorite(grade, subjectCode, publisher);
                            },
                            icon: Icon(
                              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFav ? Colors.amber : (isDark ? Colors.white30 : Colors.grey.shade400),
                              size: 18,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Yeşil "Maarif" Rozeti
  Widget _buildMaarifBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: const Text(
        'Maarif',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF10B981),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Sınıfta Henüz Ders Bulunmadığında Gösterilecek Durum
  Widget _buildNoSubjectsState(BuildContext context, int grade, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.menu_book_rounded, size: 36, color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 12),
            Text(
              '$grade. Sınıf İçin Henüz Plan Yüklenmedi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Müfredat veritabanından bu sınıfa ait planları yükleyebilirsiniz.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white38 : Colors.black54,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ADIM 3: 39+1 HAFTALIK KAZANIM AKIŞI (Bugüne Doğrudan Odaklı)
  // ==========================================================
  Widget _buildOutcomesScreen(
    BuildContext context,
    int grade,
    Map<String, dynamic> subject,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outcomesAsync = ref.watch(currentCurriculumOutcomesProvider);
    final activeWeek = ref.watch(activeAcademicWeekProvider);
    final isCarousel = ref.watch(isCarouselViewProvider);

    return Column(
      children: [
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Kazanım kodu veya konu ara...',
                hintStyle: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              onChanged: (val) {
                ref.read(outcomeSearchQueryProvider.notifier).state = val;
              },
            ),
          ),

        Expanded(
          child: outcomesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text(
                'Kazanımlar yüklenemedi: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (outcomes) {
              if (outcomes.isEmpty) {
                return Center(
                  child: Text(
                    'Aranan kritere uygun kazanım bulunamadı.',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                );
              }

              // CAROUSEL VIEW (PageView)
              if (isCarousel) {
                return PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: outcomes.length,
                  itemBuilder: (context, index) {
                    final item = outcomes[index];
                    final isCurrent = item.weekNumber == activeWeek;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 85),
                      child: item.isHolidayWeek
                          ? HolidayCard(
                              outcome: item,
                              isCurrentWeek: isCurrent,
                              isCarousel: true,
                            )
                          : OutcomeCarouselCard(
                              outcome: item,
                              isCurrentWeek: isCurrent,
                              isCarousel: true,
                            ),
                    );
                  },
                );
              }

              // LIST VIEW (Dikey Liste)
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 85),
                itemCount: outcomes.length,
                itemBuilder: (context, index) {
                  final item = outcomes[index];
                  final isCurrent = item.weekNumber == activeWeek;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: item.isHolidayWeek
                        ? HolidayCard(
                            outcome: item,
                            isCurrentWeek: isCurrent,
                            isCarousel: false,
                          )
                        : OutcomeCarouselCard(
                            outcome: item,
                            isCurrentWeek: isCurrent,
                            isCarousel: false,
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ADIM 4: FAVORİ DERSLERİM EKRANI
  // ==========================================
  Widget _buildFavoritesView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoriteKeys = ref.watch(favoriteSubjectsProvider);

    return favoriteKeys.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_outline_rounded, size: 44, color: Colors.amber),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz Favori Ders Eklenmedi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ders listesindeki yıldız ikonuna dokunarak sık kullandığınız dersleri buraya ekleyebilirsiniz.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 85),
            itemCount: favoriteKeys.length,
            itemBuilder: (context, index) {
              final key = favoriteKeys.elementAt(index);
              final parts = key.split('_');
              final grade = int.tryParse(parts[0]) ?? 5;
              final subjectCode = parts.length > 1 ? parts[1] : 'GENEL';
              // Boş publisher BOŞ kalır: "MEB Yayınları" bir okul türü
              // değil, eski verideki "bilinmiyor" değeriydi. Varsayılan
              // olarak yazılınca favori açıldığında sorgu hiçbir kayıt
              // bulamıyor ve ders boş görünüyordu.
              final publisher = parts.length > 2 ? parts.sublist(2).join('_') : '';

              final iconColor = _getSubjectColor(subjectCode);
              final iconData = _getSubjectIcon(subjectCode, subjectCode);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => _openFavoriteSubject(grade, subjectCode, publisher),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconData, color: iconColor, size: 19),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$grade. Sınıf - $subjectCode',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  publisher,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              ref
                                  .read(favoriteSubjectsProvider.notifier)
                                  .toggleFavorite(grade, subjectCode, publisher);
                            },
                            icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                            tooltip: 'Favorilerden Çıkar',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }
}
