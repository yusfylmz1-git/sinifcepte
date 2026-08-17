import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../sync/services/sync_service.dart';
import '../data/models/academic_calendar_event_model.dart';
import '../providers/academic_calendar_provider.dart';

/// SınıfCepte - Resmî MEB Akademik Takvim Ekranı (UI-UX-MAX)
class AcademicCalendarScreen extends ConsumerStatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  ConsumerState<AcademicCalendarScreen> createState() =>
      _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState
    extends ConsumerState<AcademicCalendarScreen> {
  CalendarEventCategory? _selectedCategory;
  bool _isSyncing = false;

  final DateFormat _dateFormat = DateFormat('d MMMM y', 'tr_TR');
  final DateFormat _shortDateFormat = DateFormat('d MMM', 'tr_TR');

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final result = await SyncService.instance.checkAndSyncData(force: true);
    await ref.read(academicCalendarProvider.notifier).loadEvents();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Takvim senkronize edildi'),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEvents = ref.watch(academicCalendarProvider);
    final nextEvent = ref.watch(nextUpcomingCalendarEventProvider);

    final filteredEvents = _selectedCategory == null
        ? allEvents
        : allEvents.where((e) => e.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'MEB Çalışma Takvimi',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Buluttan Senkronize Et Butonu
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 20),
              tooltip: 'Bulut Takvimini Güncelle',
              color: AppColors.primary,
              onPressed: _isSyncing ? null : _handleSync,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(academicCalendarProvider.notifier).loadEvents();
          },
          child: Column(
            children: [
              // 1. SIRADAKİ EN YAKIN TATİL HERO ALANI
              if (nextEvent != null) _buildNextHolidayHero(nextEvent, isDark),

              // 2. KATEGORİ FİLTRE ÇİPLERİ
              _buildCategoryFilterBar(isDark),

              // 3. TAKVİM OLAYLARI LİSTESİ
              Expanded(
                child: filteredEvents.isEmpty
                    ? Center(
                        child: Text(
                          'Kayıtlı takvim olayı bulunamadı.',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                        itemCount: filteredEvents.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final event = filteredEvents[index];
                          return _buildEventCard(event, isDark);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Sıradaki En Yakın Tatil Hero Kartı
  Widget _buildNextHolidayHero(AcademicCalendarEventModel next, bool isDark) {
    final days = next.daysRemaining;

    String countdownText;
    if (next.isToday) {
      countdownText = 'Bugün Tatil / Olay Günü 🎉';
    } else if (days == 1) {
      countdownText = 'Yarın Başlıyor ⚡';
    } else {
      countdownText = '$days Gün Kaldı 🏖️';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEEF2FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: next.category.color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: next.category.color.withValues(alpha: isDark ? 0.1 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol İkon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: next.category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(next.category.icon, color: next.category.color, size: 26),
          ),
          const SizedBox(width: 14),

          // Orta Başlık & Kalan Süre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: next.category.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    countdownText,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_shortDateFormat.format(next.startDate)} - ${_shortDateFormat.format(next.endDate)} • ${next.durationInDays} Gün',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Kategori Filtre Çipleri
  Widget _buildCategoryFilterBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Tümü Çipi
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('Tüm Takvim', style: TextStyle(fontSize: 11.5)),
              selected: _selectedCategory == null,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _selectedCategory == null
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => setState(() => _selectedCategory = null),
              visualDensity: VisualDensity.compact,
            ),
          ),

          // Kategoriler
          ...CalendarEventCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 13, color: isSelected ? Colors.white : cat.color),
                    const SizedBox(width: 4),
                    Text(cat.title, style: const TextStyle(fontSize: 11.5)),
                  ],
                ),
                selected: isSelected,
                selectedColor: cat.color,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 3. Takvim Olay Kartı
  Widget _buildEventCard(AcademicCalendarEventModel event, bool isDark) {
    final isPast = event.daysRemaining < 0;
    final isToday = event.isToday;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? event.category.color
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol Renkli Kategori Çubuğu
          Container(
            width: 5,
            height: 64,
            decoration: BoxDecoration(
              color: isPast ? Colors.grey.shade400 : event.category.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Kategori İkonu
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: event.category.color.withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(event.category.icon, color: event.category.color, size: 20),
          ),
          const SizedBox(width: 12),

          // Başlık ve Açıklama
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isPast
                        ? (isDark ? Colors.white38 : Colors.grey.shade500)
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                Text(
                  '${_shortDateFormat.format(event.startDate)} - ${_dateFormat.format(event.endDate)} (${event.durationInDays} Gün)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Durum Rozeti (Bugün / X Gün Kaldı / Tamamlandı)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isToday
                    ? event.category.color
                    : (isPast
                        ? (isDark ? Colors.white10 : Colors.grey.shade200)
                        : event.category.color.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isToday
                    ? 'BUGÜN'
                    : (isPast
                        ? 'Geçti'
                        : '${event.daysRemaining} Gün'),
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isToday
                      ? Colors.white
                      : (isPast
                          ? (isDark ? Colors.white38 : Colors.grey.shade600)
                          : event.category.color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
