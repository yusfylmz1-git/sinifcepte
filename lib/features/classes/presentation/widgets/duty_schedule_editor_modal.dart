import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../utils/classroom_documents_pdf_generator.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';

/// SınıfCepte - Haftalık Nöbet Çizelgesi Düzenleme & Dağıtım Modalı
class DutyScheduleEditorModal extends StatefulWidget {
  final ClassModel classModel;
  final List<StudentModel> students;
  final TeacherProfileModel teacherProfile;

  const DutyScheduleEditorModal({
    super.key,
    required this.classModel,
    required this.students,
    required this.teacherProfile,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
  }) {
    return ResponsiveBottomSheet.show(
      context: context,
      title: 'Haftalık Nöbet Çizelgesi Ayarları',
      child: DutyScheduleEditorModal(
        classModel: classModel,
        students: students,
        teacherProfile: teacherProfile,
      ),
    );
  }

  @override
  State<DutyScheduleEditorModal> createState() => _DutyScheduleEditorModalState();
}

class _DutyScheduleEditorModalState extends State<DutyScheduleEditorModal> {
  int _dailyDutyCount = 2; // Varsayılan günlük 2 nöbetçi
  final List<String> _days = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA'];
  late Map<String, List<String>> _dayAssignments;

  @override
  void initState() {
    super.initState();
    _dayAssignments = {};
    _autoDistribute();
  }

  void _autoDistribute() {
    final sortedStudents = List<StudentModel>.from(widget.students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    final assignments = <String, List<String>>{};
    int studentIndex = 0;

    for (final day in _days) {
      final list = <String>[];
      for (int i = 0; i < _dailyDutyCount; i++) {
        if (sortedStudents.isNotEmpty) {
          final s = sortedStudents[studentIndex % sortedStudents.length];
          final noStr = s.schoolNumber > 0 ? '${s.schoolNumber} - ' : '';
          list.add('$noStr${s.fullName}');
          studentIndex++;
        } else {
          list.add('');
        }
      }
      assignments[day] = list;
    }

    setState(() {
      _dayAssignments = assignments;
    });
  }

  void _onCountChanged(int count) {
    if (_dailyDutyCount == count) return;
    setState(() {
      _dailyDutyCount = count;
      _autoDistribute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Günlük Nöbetçi Sayısı Seçimi
          Text(
            'Günlük Kaç Öğrenci Nöbetçi Olacak?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 3, 4].map((count) {
              final isSelected = _dailyDutyCount == count;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        '$count Öğrenci',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (selected) {
                      if (selected) _onCountChanged(count);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 2. Otomatik Dağıt Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Haftalık Görev Dağılımı',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              TextButton.icon(
                onPressed: _autoDistribute,
                icon: const Icon(Icons.shuffle_rounded, size: 16),
                label: const Text('Otomatik Yeniden Dağıt', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 3. Gün Gün Dağıtım Kartları
          ..._days.map((day) {
            final assignedList = _dayAssignments[day] ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_dailyDutyCount Nöbetçi Görevli',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_dailyDutyCount, (index) {
                      final currentName = index < assignedList.length ? assignedList[index] : '';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline, size: 14, color: isDark ? Colors.white60 : Colors.grey.shade700),
                            const SizedBox(width: 6),
                            Text(
                              currentName.isNotEmpty ? currentName : '${index + 1}. Nöbetçi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // 4. Önizleme ve Yazdırma Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                PdfPreviewScreen.open(
                  context,
                  title: 'Haftalık Nöbet Çizelgesi',
                  subtitle: '${widget.classModel.name} Resmî Çizelgesi',
                  fileName: 'Nobet_Cizelgesi_${widget.classModel.name}.pdf',
                  documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateCustomDutySchedulePdfBytes(
                    classModel: widget.classModel,
                    teacherProfile: widget.teacherProfile,
                    dailyDutyCount: _dailyDutyCount,
                    dayAssignments: _dayAssignments,
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
              label: Text(
                'Belgeyi Önizle & Yazdır',
                style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
