import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/school_model.dart';
import '../../data/models/school_types.dart';
import '../../providers/school_selector_provider.dart';

/// SınıfCepte - MEB 81 İl ve Okul Seçim Modalı (UI-UX-MAX & Zero-Overflow)
class SchoolSelectionModal extends ConsumerStatefulWidget {
  final Function(SchoolModel selectedSchool) onSchoolSelected;
  final bool dismissible;

  const SchoolSelectionModal({
    super.key,
    required this.onSchoolSelected,
    this.dismissible = true,
  });

  static Future<SchoolModel?> show(
    BuildContext context, {
    bool dismissible = true,
  }) {
    return showModalBottomSheet<SchoolModel>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SchoolSelectionModal(
        dismissible: dismissible,
        onSchoolSelected: (school) {
          Navigator.of(ctx).pop(school);
        },
      ),
    );
  }

  @override
  ConsumerState<SchoolSelectionModal> createState() => _SchoolSelectionModalState();
}

class _SchoolSelectionModalState extends ConsumerState<SchoolSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const List<String> _schoolTypes = SchoolTypes.filterChips;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  IconData _getSchoolIcon(String type) {
    if (type.contains('İlkokul')) return Icons.child_care_rounded;
    if (type.contains('Ortaokul') || type.contains('İHO')) return Icons.school_rounded;
    if (type.contains('Fen')) return Icons.biotech_rounded;
    if (type.contains('İmam Hatip') || type.contains('İHL')) return Icons.account_balance_rounded;
    if (type.contains('Mesleki') || type.contains('MTAL')) return Icons.engineering_rounded;
    if (type.contains('Özel') || type.contains('Kolej')) return Icons.workspace_premium_rounded;
    return Icons.domain_rounded;
  }

  Color _getSchoolColor(String type) {
    if (type.contains('İlkokul')) return const Color(0xFF0284C7);
    if (type.contains('Ortaokul')) return const Color(0xFF6366F1);
    if (type.contains('Fen')) return const Color(0xFF10B981);
    if (type.contains('İmam Hatip')) return const Color(0xFF8B5CF6);
    if (type.contains('Mesleki')) return const Color(0xFFF59E0B);
    if (type.contains('Özel')) return const Color(0xFFE11D48);
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCity = ref.watch(selectedSchoolCityProvider);
    final selectedDistrict = ref.watch(selectedSchoolDistrictProvider);
    final selectedType = ref.watch(selectedSchoolTypeProvider);
    final provincesAsync = ref.watch(provincesListProvider);
    final districtsAsync = ref.watch(districtsForSelectedCityProvider);
    final schoolsAsync = ref.watch(filteredSchoolsListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Sürükleme Çubuğu ve Başlık
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 8, left: 20, right: 16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Okulunuzu Seçin',
                              style: AppFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Türkiye geneli MEB okulları dizini',
                              style: AppFonts.outfit(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (widget.dismissible)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. İl & İlçe Seçici Alanı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // İl Seçici Butonu
                Expanded(
                  flex: 5,
                  child: InkWell(
                    onTap: () => _openProvincePicker(context, provincesAsync.valueOrNull ?? []),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_city_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'İL',
                                  style: AppFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                                Text(
                                  selectedCity.isNotEmpty ? selectedCity : 'İl Seçin',
                                  style: AppFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // İlçe Seçici Butonu
                Expanded(
                  flex: 5,
                  child: InkWell(
                    onTap: () {
                      final districts = districtsAsync.valueOrNull ?? [];
                      _openDistrictPicker(context, selectedCity, districts);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, size: 18, color: Color(0xFF059669)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'İLÇE',
                                  style: AppFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                                Text(
                                  selectedDistrict != null && selectedDistrict.isNotEmpty
                                      ? selectedDistrict
                                      : 'Tüm İlçeler',
                                  style: AppFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Okul Arama Çubuğu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: AppFonts.outfit(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: '$selectedCity içindeki okullarda ara... (Örn: Atatürk, Fen)',
                  hintStyle: AppFonts.outfit(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(schoolSearchQueryProvider.notifier).state = '';
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 150), () {
                    if (!mounted) return;
                    ref.read(schoolSearchQueryProvider.notifier).state = val.trim();
                    setState(() {});
                  });
                },
              ),
            ),
          ),

          // 4. Okul Türü Filtre Çipleri
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _schoolTypes.map((type) {
                  final isSelected = selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(selectedSchoolTypeProvider.notifier).state = type;
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: Text(
                          type,
                          style: AppFonts.outfit(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // 5. Okul Listesi
          Expanded(
            child: schoolsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Okullar yüklenirken hata oluştu', style: AppFonts.outfit(fontSize: 13)),
              ),
              data: (schools) {
                if (schools.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aradığınız kriterde okul bulunamadı',
                            style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aşağıdaki butona basarak okulunuzu saniyeler içinde ekleyebilirsiniz.',
                            style: AppFonts.outfit(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openAddCustomSchoolDialog(context, selectedCity, selectedDistrict),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Bu Okulu Listeye Ekle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final queryText = _searchController.text.trim();
                final bool showQuickAdd = queryText.length >= 3 &&
                    !schools.any((s) => s.name.toLowerCase().trim() == queryText.toLowerCase());

                final totalItems = schools.length + 1 + (showQuickAdd ? 1 : 0);

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: totalItems,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    // 1. En üstteki Anında Ekle ve Seç Kartı
                    if (showQuickAdd && index == 0) {
                      return InkWell(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final repo = ref.read(schoolRepositoryProvider);
                          final school = await repo.addCustomSchool(
                            name: queryText,
                            city: selectedCity,
                            district: selectedDistrict ?? 'Merkez',
                            type: selectedType != 'Tümü' ? selectedType : 'Diğer',
                          );
                          if (school != null) {
                            ref.invalidate(filteredSchoolsListProvider);
                            widget.onSchoolSelected(school);
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bu Okul Olarak Kaydet & Seç:',
                                      style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                    Text(
                                      '"$queryText"',
                                      style: AppFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                      );
                    }

                    final schoolIndex = showQuickAdd ? index - 1 : index;

                    if (schoolIndex == schools.length) {
                      // Listenin en altındaki "Okulum Listede Yok" Ekle Butonu
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _openAddCustomSchoolDialog(context, selectedCity, selectedDistrict),
                          icon: const Icon(Icons.add_business_rounded, size: 18, color: AppColors.primary),
                          label: Text(
                            'Aradığınız okul yok mu? + Yeni Okul Ekle',
                            style: AppFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      );
                    }

                    final school = schools[schoolIndex];
                    final icon = _getSchoolIcon(school.type);
                    final color = _getSchoolColor(school.type);

                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onSchoolSelected(school);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    school.name,
                                    style: AppFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          school.type,
                                          style: AppFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          school.fullLocation,
                                          style: AppFonts.outfit(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 81 İl Seçici Modal Penceresi
  void _openProvincePicker(BuildContext context, List<Map<String, dynamic>> provinces) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String provSearch = '';
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final filteredProvinces = provinces.where((p) {
              if (provSearch.isEmpty) return true;
              final name = (p['name']?.toString() ?? '').toLowerCase();
              final code = (p['code']?.toString() ?? '');
              final q = provSearch.toLowerCase().trim();
              return name.contains(q) || code.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('İl Seçin (81 İl)', style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'İl adı veya plaka ara... (Örn: 16 veya Bursa)',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      onChanged: (val) => setDialogState(() => provSearch = val),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredProvinces.length,
                      itemBuilder: (_, i) {
                        final prov = filteredProvinces[i];
                        final name = prov['name']?.toString() ?? '';
                        final code = prov['code']?.toString() ?? '';
                        final isSelected = ref.read(selectedSchoolCityProvider) == name;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
                            child: Text(
                              code,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                              ),
                            ),
                          ),
                          title: Text(name, style: AppFonts.outfit(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                          trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                          onTap: () {
                            ref.read(selectedSchoolCityProvider.notifier).state = name;
                            ref.read(selectedSchoolDistrictProvider.notifier).state = null; // reset district
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// İlçe Seçici Modal Penceresi
  void _openDistrictPicker(BuildContext context, String city, List<String> districts) {
    if (districts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$city - İlçe Seçin', style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded, color: AppColors.primary),
                title: Text('Tüm İlçeler', style: AppFonts.outfit(fontWeight: FontWeight.bold)),
                onTap: () {
                  ref.read(selectedSchoolDistrictProvider.notifier).state = null;
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: districts.length,
                  itemBuilder: (_, i) {
                    final dist = districts[i];
                    final isSelected = ref.read(selectedSchoolDistrictProvider) == dist;
                    return ListTile(
                      title: Text(dist, style: AppFonts.outfit(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                      onTap: () {
                        ref.read(selectedSchoolDistrictProvider.notifier).state = dist;
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Yeni/Özel Okul Ekleme Diyaloğu
  void _openAddCustomSchoolDialog(BuildContext context, String currentCity, String? currentDistrict) {
    final nameCtrl = TextEditingController(text: _searchController.text.trim());
    String selectedDist = currentDistrict ?? 'Merkez';
    String selectedType = 'Anadolu Lisesi';

    final districtsAsync = ref.read(districtsForSelectedCityProvider);
    final availableDistricts = districtsAsync.valueOrNull ?? ['Merkez'];
    if (!availableDistricts.contains(selectedDist) && availableDistricts.isNotEmpty) {
      selectedDist = availableDistricts.first;
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.add_business_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Yeni Okul Ekle', style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Okulunuzu sisteme kaydedin:',
                    style: AppFonts.outfit(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),

                  // İl (Kilitli/Bilgi)
                  Text('İL: $currentCity', style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // İlçe Seçimi
                  DropdownButtonFormField<String>(
                    initialValue: selectedDist,
                    decoration: InputDecoration(
                      labelText: 'İlçe',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: availableDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedDist = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Okul Türü
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Okul Türü',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _schoolTypes.where((t) => t != 'Tümü').map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Okul Adı
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Okulun Tam Adı',
                      hintText: 'Örn: Şehit Ömer Halisdemir İlkokulu',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final schoolName = nameCtrl.text.trim();
                  if (schoolName.isEmpty) return;

                  final repo = ref.read(schoolRepositoryProvider);
                  final created = await repo.addCustomSchool(
                    name: schoolName,
                    city: currentCity,
                    district: selectedDist,
                    type: selectedType,
                  );

                  if (created != null && dlgCtx.mounted) {
                    Navigator.pop(dlgCtx);
                    ref.invalidate(filteredSchoolsListProvider);
                    widget.onSchoolSelected(created);
                  }
                },
                child: const Text('Kaydet ve Seç'),
              ),
            ],
          );
        },
      ),
    );
  }
}
