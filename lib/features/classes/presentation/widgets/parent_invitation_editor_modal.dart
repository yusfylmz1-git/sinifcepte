import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../utils/classroom_documents_pdf_generator.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';

/// SınıfCepte - Veli Toplantı Davetiye Mektubu (Tek A4'te 8 Adet) Düzenleme Modalı
class ParentInvitationEditorModal extends StatefulWidget {
  final ClassModel classModel;
  final TeacherProfileModel teacherProfile;

  const ParentInvitationEditorModal({
    super.key,
    required this.classModel,
    required this.teacherProfile,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassModel classModel,
    required TeacherProfileModel teacherProfile,
  }) {
    return ResponsiveBottomSheet.show(
      context: context,
      title: 'Veli Davetiye Mektubu (8\'li A4)',
      child: ParentInvitationEditorModal(
        classModel: classModel,
        teacherProfile: teacherProfile,
      ),
    );
  }

  @override
  State<ParentInvitationEditorModal> createState() => _ParentInvitationEditorModalState();
}

class _ParentInvitationEditorModalState extends State<ParentInvitationEditorModal> {
  final _dateController = TextEditingController(text: '..... / ..... / 202...');
  final _timeController = TextEditingController(text: '15:30');
  final _locationController = TextEditingController();
  final _agendaController = TextEditingController(text: 'Akademik Başarı, Uyum ve Dönem Hedefleri');
  final _noteController = TextEditingController(text: '* Katılımınız öğrencimiz için çok değerlidir.');

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
    _agendaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bilgilendirme Rozeti
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.print_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tek bir A4 sayfasına 8 adet kesilebilir (✂) davetiye basılır. Kâğıt tasarrufu sağlar.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Toplantı Tarihi & Saati
          Row(
            children: [
              Expanded(
                child: TextField(
                  maxLength: 20,
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Toplantı Tarihi',
                    hintText: 'Örn: 15.10.2024',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  maxLength: 10,
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: 'Toplantı Saati',
                    hintText: 'Örn: 15:30',
                    prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Toplantı Yeri
          TextField(
            maxLength: 80,
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Toplantı Yeri',
              prefixIcon: const Icon(Icons.place_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Gündem Özeti
          TextField(
            maxLength: 200,
            controller: _agendaController,
            decoration: InputDecoration(
              labelText: 'Gündem Başlığı / Özeti',
              prefixIcon: const Icon(Icons.list_alt_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Özel Veli Notu
          TextField(
            maxLength: 300,
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Davetiye Alt Notu',
              prefixIcon: const Icon(Icons.favorite_border_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),

          // Önizleme & Yazdır Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                PdfPreviewScreen.open(
                  context,
                  title: 'Veli Davetiye Mektubu',
                  subtitle: '${widget.classModel.name} - Tek A4\'te 8 Davetiye',
                  fileName: 'Veli_Davetiye_8li_${widget.classModel.name}.pdf',
                  documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generate8in1ParentInvitationPdfBytes(
                    classModel: widget.classModel,
                    teacherProfile: widget.teacherProfile,
                    meetingDate: _dateController.text.trim(),
                    meetingTime: _timeController.text.trim(),
                    meetingLocation: _locationController.text.trim(),
                    agendaSummary: _agendaController.text.trim(),
                    customNote: _noteController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
              label: Text(
                '8\'li Davetiyeyi Önizle & Yazdır',
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
