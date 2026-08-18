import 'package:flutter/material.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/schedule_settings.dart';

/// SınıfCepte - Kompakt Program Ayarları Modalı
class ScheduleSettingsDialog extends StatefulWidget {
  final ScheduleSettings initialSettings;
  final ValueChanged<ScheduleSettings> onSaved;

  const ScheduleSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required ScheduleSettings initialSettings,
    required ValueChanged<ScheduleSettings> onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleSettingsDialog(
        initialSettings: initialSettings,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ScheduleSettingsDialog> createState() => _ScheduleSettingsDialogState();
}

class _ScheduleSettingsDialogState extends State<ScheduleSettingsDialog> {
  late TimeOfDay _firstLessonTime;
  late int _lessonDuration;
  late int _breakDuration;
  late int _dailyLessonCount;
  late bool _hasLunchBreak;
  late int _lunchBreakDuration;
  late int _lunchBreakAfterLesson;

  @override
  void initState() {
    super.initState();
    _firstLessonTime = widget.initialSettings.firstLessonTime;
    _lessonDuration = widget.initialSettings.lessonDuration;
    _breakDuration = widget.initialSettings.breakDuration;
    _dailyLessonCount = widget.initialSettings.dailyLessonCount;
    _hasLunchBreak = widget.initialSettings.hasLunchBreak;
    _lunchBreakDuration = widget.initialSettings.lunchBreakDuration;
    _lunchBreakAfterLesson = widget.initialSettings.lunchBreakAfterLesson;
  }

  void _save() {
    final updated = ScheduleSettings(
      firstLessonTime: _firstLessonTime,
      lessonDuration: _lessonDuration,
      breakDuration: _breakDuration,
      dailyLessonCount: _dailyLessonCount,
      hasLunchBreak: _hasLunchBreak,
      lunchBreakDuration: _lunchBreakDuration,
      lunchBreakAfterLesson: _lunchBreakAfterLesson,
    );
    widget.onSaved(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
                  child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ders Programı Ayarları',
                        style: AppFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Saat aralıkları otomatik hesaplanacaktır',
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
          const Divider(height: 24, thickness: 0.6),

          // Ayarlar Listesi
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 1. İLK DERS SAATİ SEÇİCİ
                  _buildSettingRow(
                    icon: Icons.access_time_rounded,
                    title: 'İlk Ders Başlama Saati',
                    subtitle: 'Günün 1. dersinin başladığı saat',
                    valueWidget: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _firstLessonTime,
                        );
                        if (picked != null) {
                          setState(() => _firstLessonTime = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _firstLessonTime.format(context),
                          style: AppFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    isDark: isDark,
                  ),
                  const Divider(height: 16, thickness: 0.4),

                  // 2. GÜNLÜK DERS SAYISI
                  _buildStepperRow(
                    icon: Icons.format_list_numbered_rounded,
                    title: 'Günlük Ders Sayısı',
                    subtitle: 'Toplam ders saati (1-12)',
                    value: '$_dailyLessonCount Saat',
                    onDecrement: _dailyLessonCount > 1
                        ? () => setState(() => _dailyLessonCount--)
                        : null,
                    onIncrement: _dailyLessonCount < 12
                        ? () => setState(() => _dailyLessonCount++)
                        : null,
                    isDark: isDark,
                  ),
                  const Divider(height: 16, thickness: 0.4),

                  // 3. DERS SÜRESİ
                  _buildStepperRow(
                    icon: Icons.timer_outlined,
                    title: 'Ders Süresi',
                    subtitle: 'Her bir dersin süresi',
                    value: '$_lessonDuration dk',
                    onDecrement: _lessonDuration > 20
                        ? () => setState(() => _lessonDuration -= 5)
                        : null,
                    onIncrement: _lessonDuration < 90
                        ? () => setState(() => _lessonDuration += 5)
                        : null,
                    isDark: isDark,
                  ),
                  const Divider(height: 16, thickness: 0.4),

                  // 4. TENEFFÜS SÜRESİ
                  _buildStepperRow(
                    icon: Icons.coffee_outlined,
                    title: 'Teneffüs Süresi',
                    subtitle: 'Dersler arası dinlenme süresi',
                    value: '$_breakDuration dk',
                    onDecrement: _breakDuration > 0
                        ? () => setState(() => _breakDuration -= 5)
                        : null,
                    onIncrement: _breakDuration < 60
                        ? () => setState(() => _breakDuration += 5)
                        : null,
                    isDark: isDark,
                  ),
                  const Divider(height: 16, thickness: 0.4),

                  // 5. ÖĞLE ARASI
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: Color(0xFFF59E0B), size: 18),
                    ),
                    title: Text(
                      'Öğle Arası',
                      style: AppFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      _hasLunchBreak ? 'Aktif' : 'Yok / Kesintisiz',
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    value: _hasLunchBreak,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _hasLunchBreak = val),
                  ),

                  if (_hasLunchBreak) ...[
                    const SizedBox(height: 6),
                    _buildStepperRow(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Öğle Arası Süresi',
                      subtitle: 'Yemek ve dinlenme aralığı',
                      value: '$_lunchBreakDuration dk',
                      onDecrement: _lunchBreakDuration > 15
                          ? () => setState(() => _lunchBreakDuration -= 5)
                          : null,
                      onIncrement: _lunchBreakDuration < 120
                          ? () => setState(() => _lunchBreakDuration += 5)
                          : null,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildStepperRow(
                      icon: Icons.vertical_align_center_rounded,
                      title: 'Öğle Arası Konumu',
                      subtitle: 'Kaçıncı dersten sonra başlar',
                      value: '$_lunchBreakAfterLesson. Dersten Sonra',
                      onDecrement: _lunchBreakAfterLesson > 2
                          ? () => setState(() => _lunchBreakAfterLesson--)
                          : null,
                      onIncrement: _lunchBreakAfterLesson < _dailyLessonCount - 1
                          ? () => setState(() => _lunchBreakAfterLesson++)
                          : null,
                      isDark: isDark,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
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
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Ayarları Kaydet',
                      style: AppFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget valueWidget,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isDark ? Colors.white70 : const Color(0xFF475569), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: AppFonts.outfit(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          valueWidget,
        ],
      ),
    );
  }

  Widget _buildStepperRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
    required bool isDark,
  }) {
    return _buildSettingRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      valueWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
            visualDensity: VisualDensity.compact,
            color: onDecrement != null ? AppColors.primary : Colors.grey.shade400,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 54),
            alignment: Alignment.center,
            child: Text(
              value,
              style: AppFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            visualDensity: VisualDensity.compact,
            color: onIncrement != null ? AppColors.primary : Colors.grey.shade400,
          ),
        ],
      ),
      isDark: isDark,
    );
  }
}
