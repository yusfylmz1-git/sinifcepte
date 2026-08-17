import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_model.dart';
import '../models/lesson_model.dart';
import '../models/schedule_settings.dart';

/// SınıfCepte - Kompakt ve Akıllı Ders Ekle / Düzenle Modalı
class AddLessonDialog extends StatefulWidget {
  final List<ClassModel> availableClasses;
  final List<LessonModel> existingLessons;
  final ScheduleSettings settings;
  final String initialDay;
  final int initialLessonIndex;
  final LessonModel? lessonToEdit;
  final ValueChanged<LessonModel> onSaved;

  const AddLessonDialog({
    super.key,
    required this.availableClasses,
    required this.existingLessons,
    required this.settings,
    required this.initialDay,
    required this.initialLessonIndex,
    this.lessonToEdit,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required List<ClassModel> availableClasses,
    required List<LessonModel> existingLessons,
    required ScheduleSettings settings,
    required String initialDay,
    required int initialLessonIndex,
    LessonModel? lessonToEdit,
    required ValueChanged<LessonModel> onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddLessonDialog(
        availableClasses: availableClasses,
        existingLessons: existingLessons,
        settings: settings,
        initialDay: initialDay,
        initialLessonIndex: initialLessonIndex,
        lessonToEdit: lessonToEdit,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddLessonDialog> createState() => _AddLessonDialogState();
}

class _AddLessonDialogState extends State<AddLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _lessonNameController = TextEditingController();

  late String _selectedDay;
  late int _selectedLessonHourIndex;
  late Color _selectedColor;

  static const List<String> _days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static const List<Color> _palette = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEF4444), // Red
    Color(0xFF64748B), // Slate
  ];

  @override
  void initState() {
    super.initState();
    if (widget.lessonToEdit != null) {
      final l = widget.lessonToEdit!;
      _classNameController.text = l.className;
      _lessonNameController.text = l.lessonName;
      _selectedDay = l.day;
      _selectedLessonHourIndex = l.lessonHourIndex;
      _selectedColor = l.color;
    } else {
      _selectedDay = widget.initialDay;
      _selectedLessonHourIndex = widget.initialLessonIndex;
      _selectedColor = _palette.first;

      // Eğer kayıtlı sınıflar varsa ilkini otomatik öner
      if (widget.availableClasses.isNotEmpty) {
        final firstClass = widget.availableClasses.first;
        _classNameController.text = firstClass.name;
        _lessonNameController.text = firstClass.subject.trim().isNotEmpty
            ? firstClass.subject
            : 'Genel Ders';
      }
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _lessonNameController.dispose();
    super.dispose();
  }

  void _onClassSelected(ClassModel c) {
    setState(() {
      _classNameController.text = c.name;
      if (c.subject.trim().isNotEmpty && c.subject != 'Genel Ders') {
        _lessonNameController.text = c.subject;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final className = _classNameController.text.trim();
    final lessonName = _lessonNameController.text.trim();

    // Çakışma Kontrolü (Conflict Detection)
    final conflict = widget.existingLessons.where((l) {
      if (widget.lessonToEdit != null && l.id == widget.lessonToEdit!.id) {
        return false;
      }
      return l.day == _selectedDay && l.lessonHourIndex == _selectedLessonHourIndex;
    }).firstOrNull;

    if (conflict != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text('Ders Çakışması Uyarısı', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            '$_selectedDay günü ${_selectedLessonHourIndex + 1}. Ders saatinde zaten "${conflict.className} - ${conflict.lessonName}" dersiniz bulunuyor.\n\nYine de bu saati değiştirmek istiyor musunuz?',
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _finalizeSave(className, lessonName);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Üzerine Yaz & Değiştir', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    _finalizeSave(className, lessonName);
  }

  void _finalizeSave(String className, String lessonName) {
    final lesson = LessonModel(
      id: widget.lessonToEdit?.id,
      docId: widget.lessonToEdit?.docId,
      className: className,
      lessonName: lessonName,
      day: _selectedDay,
      lessonHourIndex: _selectedLessonHourIndex,
      color: _selectedColor,
    );

    widget.onSaved(lesson);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.lessonToEdit != null;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 100),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sürükleme Tutacağı
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Başlık
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Dersi Düzenle' : 'Yeni Ders Ekle',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${widget.settings.calculateTimeRange(_selectedLessonHourIndex)} • $_selectedDay',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, thickness: 0.6),

            // Form İçeriği
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. KAYITLI SINIFLARDAN HIZLI SEÇİM ÇİPLERİ
                      if (widget.availableClasses.isNotEmpty) ...[
                        Text(
                          'Kayıtlı Sınıflardan Seçin:',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: widget.availableClasses.map((c) {
                              final isSelected = _classNameController.text.trim() == c.name.trim();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c.name),
                                  selected: isSelected,
                                  onSelected: (_) => _onClassSelected(c),
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 2. SINIF ADI & DERS ADI GİRİŞ ALANLARI
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _classNameController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Sınıf / Şube *',
                                hintText: 'Örn: 5-A',
                                prefixIcon: const Icon(Icons.school_rounded, size: 18),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Gerekli' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _lessonNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Ders Adı *',
                                hintText: 'Örn: Matematik',
                                prefixIcon: const Icon(Icons.book_rounded, size: 18),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Gerekli' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. GÜN VE SAAT SEÇİCİ
                      Row(
                        children: [
                          // Gün Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedDay,
                              decoration: InputDecoration(
                                labelText: 'Gün',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _days
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d, style: const TextStyle(fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDay = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Ders Saati Dropdown
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedLessonHourIndex.clamp(0, widget.settings.dailyLessonCount - 1),
                              decoration: InputDecoration(
                                labelText: 'Ders Saati',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: List.generate(
                                widget.settings.dailyLessonCount,
                                (idx) => DropdownMenuItem(
                                  value: idx,
                                  child: Text('${idx + 1}. Ders', style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedLessonHourIndex = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. KART RENK PALETİ
                      Text(
                        'Kart Rengi:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _palette.map((c) {
                          final isSelected = _selectedColor.toARGB32() == c.toARGB32();
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = c),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: c.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Alt Butonlar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isEditing ? 'Dersi Güncelle' : 'Dersi Kaydet',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
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
