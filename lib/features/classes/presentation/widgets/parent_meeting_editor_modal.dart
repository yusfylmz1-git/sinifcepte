import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../utils/classroom_documents_pdf_generator.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';

/// SınıfCepte - Veli Toplantı Tutanağı ve İmza Sirküsü Düzenleme Modalı
class ParentMeetingEditorModal extends StatefulWidget {
  final ClassModel classModel;
  final List<StudentModel> students;
  final TeacherProfileModel teacherProfile;

  const ParentMeetingEditorModal({
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
      title: 'Veli Toplantı Tutanağı ve İmza Sirküsü',
      child: ParentMeetingEditorModal(
        classModel: classModel,
        students: students,
        teacherProfile: teacherProfile,
      ),
    );
  }

  @override
  State<ParentMeetingEditorModal> createState() => _ParentMeetingEditorModalState();
}

class _ParentMeetingEditorModalState extends State<ParentMeetingEditorModal> {
  String _selectedMeetingType = '1. Dönem Sene Başı';
  final _dateController = TextEditingController(text: '..... / ..... / 202...');
  final _timeController = TextEditingController(text: '15:30');
  final _locationController = TextEditingController();

  final List<String> _agendaItems = [
    '1. Açılış, yoklama ve veli tanışması.',
    '2. Sınıfın genel akademik başarı durumu ve hedeflerin değerlendirilmesi.',
    '3. Öğrenci devamsızlık durumu ve okul kuralları hakkında bilgilendirme.',
    '4. Sosyal etkinlikler, kulüpler ve rehberlik çalışmaları.',
    '5. Veli-okul iş birliği, sınıf temsilcisi seçimi ve veli görüşleri.',
    '6. Dilek, temenniler ve kapanış.',
  ];

  final List<String> _decisions = [
    '1. Öğrencilerin ders çalışma ve ödev takibinin veliler tarafından günlük yapılmasına karar verildi.',
    '2. Sınıf kitaplığı için kitap bağışı kampanyası başlatılması kararlaştırıldı.',
    '3. Devamsızlık sınırına yaklaşan öğrencilerin velilerine anında bildirim yapılması kararı alındı.',
    '4. Bir sonraki veli toplantısının dönem ortasında yapılması uygun görüldü.',
  ];

  @override
  void initState() {
    super.initState();
    _locationController.text = '${widget.classModel.name} Sınıfı Dersliği';
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Toplantı Türü
          Text(
            'Toplantı Türü',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              '1. Dönem Sene Başı',
              '1. Dönem Ara Toplantı',
              '2. Dönem Sene Başı',
              'Olağanüstü Toplantı',
            ].map((type) {
              final isSelected = _selectedMeetingType == type;
              return ChoiceChip(
                label: Text(
                  type,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedMeetingType = type);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 2. Tarih, Saat ve Yer
          Row(
            children: [
              Expanded(
                child: TextField(
                  maxLength: 20,
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Tarih',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  maxLength: 10,
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: 'Saat',
                    prefixIcon: const Icon(Icons.access_time_rounded, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            maxLength: 80,
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Toplantı Yeri',
              prefixIcon: const Icon(Icons.place_outlined, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Bilgilendirme Rozeti
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in_outlined, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sınıftaki ${widget.students.length} öğrencinin velisi için hazır imza sirküsü tablosu otomatik üretilecektir.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Önizleme & Yazdır Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                PdfPreviewScreen.open(
                  context,
                  title: 'Veli Toplantı Tutanağı & İmza Sirküsü',
                  subtitle: '${widget.classModel.name} Resmî Tutanağı',
                  fileName: 'Veli_Toplanti_Tutanagi_${widget.classModel.name}.pdf',
                  documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateParentMeetingMinutesPdfBytes(
                    classModel: widget.classModel,
                    students: widget.students,
                    teacherProfile: widget.teacherProfile,
                    meetingType: _selectedMeetingType,
                    meetingDate: _dateController.text.trim(),
                    meetingTime: _timeController.text.trim(),
                    meetingLocation: _locationController.text.trim(),
                    agendaItems: _agendaItems,
                    decisions: _decisions,
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
              label: Text(
                'Tutanağı & İmza Sirküsünü Önizle',
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
