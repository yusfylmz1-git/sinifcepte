import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/search_debouncer.dart';
import '../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../data/models/absence_followup_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../parent_portal/data/services/phone_formatter.dart';
import '../providers/absence_followup_provider.dart';
import '../providers/student_provider.dart';
import '../utils/classroom_documents_pdf_generator.dart';

/// Devamsız Öğrenci Takip Ekranı.
///
/// Bakanlığın devamsızlık çalışmasında sınıf rehber öğretmeninden
/// istenen liste: **öğrenci no · adı soyadı · veli no · not**.
///
/// Uygulamada günlük yoklama YOK. Öğretmen e-Okul'daki devamsızlığa
/// bakıp buradan öğrenci ekliyor; ekran o işareti, nedenini ve notunu
/// yönetir.
class AbsenceFollowupScreen extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const AbsenceFollowupScreen({super.key, required this.classModel});

  @override
  ConsumerState<AbsenceFollowupScreen> createState() =>
      _AbsenceFollowupScreenState();
}

class _AbsenceFollowupScreenState extends ConsumerState<AbsenceFollowupScreen> {
  final SearchDebouncer _searchDebouncer = SearchDebouncer();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Neden süzgeci. `null` = tümü.
  AbsenceReason? _reasonFilter;

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entriesAsync = ref.watch(absenceFollowupProvider(widget.classModel));
    final entries = entriesAsync.valueOrNull ?? const <AbsenceFollowupEntry>[];
    final filtered = _applyFilters(entries);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF7F8FC),
      appBar: CustomAppBar(
        title: 'Devamsızlık Takibi',
        subtitle:
            '${widget.classModel.name} • ${absenceAcademicYear(widget.classModel)}',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Takip Çizelgesi (PDF)',
            onPressed: () => _openPdf(entries),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openStudentPicker(entries),
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Öğrenci Ekle',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(isDark, e),
          data: (_) => Column(
            children: [
              _buildSummary(entries, isDark),
              if (entries.isNotEmpty) _buildSearchAndFilters(entries, isDark),
              Expanded(
                child: entries.isEmpty
                    ? _buildEmptyState(isDark)
                    : filtered.isEmpty
                        ? _buildNoMatchState(isDark)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 92),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _buildEntryCard(filtered[index], isDark),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AbsenceFollowupEntry> _applyFilters(List<AbsenceFollowupEntry> all) {
    final q = _searchQuery.trim().toLowerCase();
    return all.where((e) {
      if (_reasonFilter != null && e.followup.reason != _reasonFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.fullName.toLowerCase().contains(q) ||
          '${e.schoolNumber}'.contains(q) ||
          (e.parentName ?? '').toLowerCase().contains(q) ||
          (e.parentPhone ?? '').contains(q);
    }).toList();
  }

  // ==========================================
  // ÜST ÖZET
  // ==========================================

  Widget _buildSummary(List<AbsenceFollowupEntry> entries, bool isDark) {
    final telefonsuz = entries.where((e) => !e.hasPhone).length;
    final notsuz = entries.where((e) => !e.followup.hasNote).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.24 : 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entries.length} devamsız öğrenci',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Eksik veriyi söylemek gerekiyor: çizelge veli
                  // telefonu boş basılırsa öğretmen bunu ancak
                  // yazıcıdan çıkınca fark ediyordu.
                  entries.isEmpty
                      ? 'Henüz öğrenci eklenmedi'
                      : [
                          if (telefonsuz > 0) '$telefonsuz veli numarası eksik',
                          if (notsuz > 0) '$notsuz kayıtta not yok',
                          if (telefonsuz == 0 && notsuz == 0)
                            'Tüm kayıtlar eksiksiz',
                        ].join(' • '),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
    List<AbsenceFollowupEntry> entries,
    bool isDark,
  ) {
    // Yalnızca listede GEÇEN nedenler çip olur; boş süzgece basıp
    // "sonuç yok" görmek kafa karıştırıyor.
    final mevcutNedenler = <AbsenceReason>{
      for (final e in entries) e.followup.reason,
    }.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => _searchDebouncer.run(() {
              if (mounted) setState(() => _searchQuery = value);
            }),
            decoration: InputDecoration(
              hintText: 'Ad, numara veya veli ara...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (mevcutNedenler.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildReasonChip(null, 'Tümü', entries.length, isDark),
                for (final r in mevcutNedenler)
                  _buildReasonChip(
                    r,
                    r.label,
                    entries.where((e) => e.followup.reason == r).length,
                    isDark,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReasonChip(
    AbsenceReason? reason,
    String label,
    int count,
    bool isDark,
  ) {
    final selected = _reasonFilter == reason;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _reasonFilter = reason),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        selectedColor: const Color(0xFFEF4444),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        showCheckmark: false,
      ),
    );
  }

  // ==========================================
  // SATIR KARTI: No · Adı Soyadı · Veli No · Not
  // ==========================================

  Widget _buildEntryCard(AbsenceFollowupEntry entry, bool isDark) {
    final f = entry.followup;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE8ECF3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetailSheet(entry),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Okul numarası rozeti
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444)
                            .withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${entry.schoolNumber}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _parentLine(entry),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: entry.hasPhone
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              color: entry.hasPhone
                                  ? (isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569))
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hızlı iletişim
                    if (entry.hasPhone) ...[
                      _iconAction(
                        icon: Icons.call_rounded,
                        color: const Color(0xFF3B82F6),
                        tooltip: 'Ara',
                        onTap: () => _makePhoneCall(entry.parentPhone!),
                      ),
                      _iconAction(
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        tooltip: 'WhatsApp',
                        onTap: () =>
                            _openWhatsApp(entry.parentPhone!, entry.fullName),
                      ),
                    ],
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                      ),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openDetailSheet(entry);
                        } else if (value == 'remove') {
                          _confirmUnmark(entry);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Neden & Not Düzenle'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_remove_rounded,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Takipten Çıkar',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _reasonColor(f.reason)
                            .withValues(alpha: isDark ? 0.20 : 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        f.reason.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _reasonColor(f.reason),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f.hasNote ? f.note!.trim() : 'Not eklenmedi',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle:
                              f.hasNote ? FontStyle.normal : FontStyle.italic,
                          color: f.hasNote
                              ? (isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569))
                              : (isDark
                                  ? Colors.white30
                                  : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kartın ikinci satırı: veli adı + numarası.
  ///
  /// Numara yoksa boş bırakılmıyor, uyarı yazılıyor: çizelgede o hücre
  /// boş kalacak ve öğretmen bunu yazdırmadan önce bilmeli.
  static String _parentLine(AbsenceFollowupEntry entry) {
    if (!entry.hasPhone) return 'Veli numarası kayıtlı değil';
    final ad = (entry.parentName ?? '').trim();
    final numara = PhoneFormatter.toDisplay(entry.parentPhone!);
    return ad.isEmpty ? numara : '$ad • $numara';
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: 19, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      onPressed: onTap,
    );
  }

  static Color _reasonColor(AbsenceReason reason) {
    switch (reason) {
      case AbsenceReason.saglik:
        return const Color(0xFF3B82F6);
      case AbsenceReason.ailevi:
        return const Color(0xFF8B5CF6);
      case AbsenceReason.ekonomik:
        return const Color(0xFFF59E0B);
      case AbsenceReason.okulUyumu:
        return const Color(0xFF10B981);
      case AbsenceReason.mevsimlikIs:
        return const Color(0xFF0EA5E9);
      case AbsenceReason.diger:
        return const Color(0xFF64748B);
      case AbsenceReason.bilinmiyor:
        return const Color(0xFF94A3B8);
    }
  }

  // ==========================================
  // DURUM EKRANLARI
  // ==========================================

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 64,
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 14),
            Text(
              'Devamsız öğrenci yok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Devamsızlığını takip etmek istediğiniz öğrencileri '
              '"Öğrenci Ekle" ile listeye alın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchState(bool isDark) {
    return Center(
      child: Text(
        'Aramanıza uyan kayıt yok.',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              'Liste yüklenemedi.\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref
                  .read(absenceFollowupProvider(widget.classModel).notifier)
                  .load(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EYLEMLER
  // ==========================================

  /// Sınıf listesinden devamsız öğrenci seçtirir.
  Future<void> _openStudentPicker(List<AbsenceFollowupEntry> entries) async {
    final classId = widget.classModel.id;
    if (classId == null) return;

    final students =
        ref.read(studentListProvider(classId)).valueOrNull ?? const [];
    if (students.isEmpty) {
      _showSnack('Sınıfta kayıtlı öğrenci yok.');
      return;
    }

    final zatenIsaretli = entries.map((e) => e.followup.studentId).toSet();
    final secilebilir =
        students.where((s) => !zatenIsaretli.contains(s.id)).toList();

    if (secilebilir.isEmpty) {
      _showSnack('Sınıftaki tüm öğrenciler zaten listede.');
      return;
    }

    final secilenler = <int>{};

    final onay = await ResponsiveBottomSheet.show<bool>(
      context: context,
      title: 'Devamsız Öğrenci Seç',
      builder: (sheetContext, setSheetState) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'Devamsızlığı takip edilecek öğrencileri işaretleyin. '
                'Neden ve notu sonra ekleyebilirsiniz.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ),
            ...secilebilir.map((s) {
              final secili = secilenler.contains(s.id);
              return CheckboxListTile(
                value: secili,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setSheetState(() {
                  if (v == true) {
                    secilenler.add(s.id!);
                  } else {
                    secilenler.remove(s.id);
                  }
                }),
                title: Text(
                  '${s.schoolNumber} • ${s.fullName}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  (s.parentPhone ?? '').trim().isEmpty
                      ? 'Veli numarası yok'
                      : PhoneFormatter.toDisplay(s.parentPhone!),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }),
          ],
        );
      },
      bottomActionBuilder: (sheetContext, setSheetState) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: secilenler.isEmpty
              ? null
              : () => Navigator.of(sheetContext).pop(true),
          icon: const Icon(Icons.check_rounded),
          label: Text(
            secilenler.isEmpty
                ? 'Öğrenci seçin'
                : '${secilenler.length} öğrenciyi listeye ekle',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );

    if (onay != true || secilenler.isEmpty) return;

    final ok = await ref
        .read(absenceFollowupProvider(widget.classModel).notifier)
        .markBatch(secilenler.toList());
    _showSnack(
      ok
          ? '${secilenler.length} öğrenci takip listesine eklendi.'
          : 'Öğrenciler eklenirken hata oluştu.',
    );
  }

  /// Neden ve not düzenleme sayfası.
  Future<void> _openDetailSheet(AbsenceFollowupEntry entry) async {
    var reason = entry.followup.reason;
    final noteController =
        TextEditingController(text: entry.followup.note ?? '');

    final kaydet = await ResponsiveBottomSheet.show<bool>(
      context: context,
      title: entry.fullName,
      builder: (sheetContext, setSheetState) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Devamsızlık Nedeni',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AbsenceReason.values.map((r) {
                final secili = reason == r;
                return ChoiceChip(
                  label: Text(r.label),
                  selected: secili,
                  showCheckmark: false,
                  onSelected: (_) => setSheetState(() => reason = r),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: secili
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                  selectedColor: _reasonColor(r),
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Not',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              maxLines: 4,
              maxLength: 400,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Örn: 12.09 veli arandı, sağlık raporu getirecek.',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        );
      },
      bottomActionBuilder: (sheetContext, _) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => Navigator.of(sheetContext).pop(true),
          icon: const Icon(Icons.save_rounded),
          label: const Text(
            'Kaydet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );

    final metin = noteController.text.trim();
    noteController.dispose();

    if (kaydet != true) return;

    final ok = await ref
        .read(absenceFollowupProvider(widget.classModel).notifier)
        .updateDetails(
          studentId: entry.followup.studentId,
          reason: reason,
          note: metin.isEmpty ? null : metin,
        );
    _showSnack(ok ? 'Kayıt güncellendi.' : 'Kayıt güncellenemedi.');
  }

  Future<void> _confirmUnmark(AbsenceFollowupEntry entry) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takipten Çıkar'),
        content: Text(
          '${entry.fullName} devamsızlık takip listesinden çıkarılsın mı?\n\n'
          'Öğrenci sınıf listesinden SİLİNMEZ; yalnızca bu takip kaydı '
          've yazdığınız not kaldırılır.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    final ok = await ref
        .read(absenceFollowupProvider(widget.classModel).notifier)
        .unmark(entry.followup.studentId);
    _showSnack(ok ? 'Öğrenci takipten çıkarıldı.' : 'İşlem başarısız.');
  }

  Future<void> _openPdf(List<AbsenceFollowupEntry> entries) async {
    await ClassroomDocumentsPdfGenerator.generateAbsenceFollowupPdf(
      context: context,
      classModel: widget.classModel,
      entries: entries,
      teacherProfile: ref.read(teacherProfileProvider),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final cleaned = PhoneFormatter.toDial(phoneNumber);
      if (cleaned == null) {
        _showSnack('Geçersiz telefon numarası ($phoneNumber)');
        return;
      }
      final uri = Uri.parse('tel:$cleaned');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Arama başlatılamadı ($cleaned)');
      }
    } catch (e, st) {
      debugPrint(
          '---------------- HATA DETAYI (AbsenceFollowup._makePhoneCall) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint(
          '------------------------------------------------------------------------------');
      _showSnack('Arama başlatılırken hata oluştu.');
    }
  }

  Future<void> _openWhatsApp(String phoneNumber, String studentName) async {
    try {
      final cleaned = PhoneFormatter.toWhatsApp(phoneNumber);
      if (cleaned == null) {
        _showSnack('Geçersiz WhatsApp telefon numarası ($phoneNumber)');
        return;
      }
      final message = Uri.encodeComponent(
        'Merhaba, $studentName öğrencimizin devamsızlığı hakkında '
        'görüşmek istiyorum.',
      );
      final uri = Uri.parse('https://wa.me/$cleaned?text=$message');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('WhatsApp uygulaması açılamadı ($cleaned)');
      }
    } catch (e, st) {
      debugPrint(
          '---------------- HATA DETAYI (AbsenceFollowup._openWhatsApp) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $st');
      debugPrint(
          '----------------------------------------------------------------------------');
      _showSnack('WhatsApp başlatılırken hata oluştu.');
    }
  }
}

/// Ekran iki yerden açılıyor (hub kartı ve öğrenci listesi); gezinme
/// kodu iki yerde ayrı yazılsaydı biri güncellenip diğeri unutulurdu.
Future<void> openAbsenceFollowupScreen(
  BuildContext context,
  ClassModel classModel,
) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AbsenceFollowupScreen(classModel: classModel),
    ),
  );
}

/// Öğrenci listesinden tek öğrenciyi devamsız işaretleme kısayolu.
Future<bool> markStudentAbsent({
  required WidgetRef ref,
  required ClassModel classModel,
  required StudentModel student,
}) {
  return ref
      .read(absenceFollowupProvider(classModel).notifier)
      .mark(student.id!);
}
