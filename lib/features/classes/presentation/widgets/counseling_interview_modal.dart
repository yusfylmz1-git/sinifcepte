import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../utils/classroom_documents_pdf_generator.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../bep/presentation/views/bep_list_view.dart';

/// SınıfCepte - Rehberlik & Görüşme Evrakları Seçim ve Hazırlama Modalı
class CounselingInterviewModal extends StatefulWidget {
  final ClassModel classModel;
  final List<StudentModel> students;
  final TeacherProfileModel teacherProfile;
  final int initialDocumentIndex; // 0: Veli Görüşme, 1: Öğrenci Görüşme, 2: BEP Takip, 3: Tanıma Fişi, 4: Gezi İzin

  const CounselingInterviewModal({
    super.key,
    required this.classModel,
    required this.students,
    required this.teacherProfile,
    this.initialDocumentIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacherProfile,
    int initialDocumentIndex = 0,
  }) {
    return ResponsiveBottomSheet.show(
      context: context,
      title: 'Rehberlik & Resmî Form Merkezi',
      child: CounselingInterviewModal(
        classModel: classModel,
        students: students,
        teacherProfile: teacherProfile,
        initialDocumentIndex: initialDocumentIndex,
      ),
    );
  }

  @override
  State<CounselingInterviewModal> createState() => _CounselingInterviewModalState();
}

class _CounselingInterviewModalState extends State<CounselingInterviewModal> {
  late int _selectedDocIndex;
  StudentModel? _selectedStudent;

  // Form ek alanları
  final _fieldTripNameController = TextEditingController(text: 'Anıtkabir ve Müze Gezisi');
  final _fieldTripDestController = TextEditingController(text: 'Ankara / Anıtkabir');
  final _fieldTripDateController = TextEditingController(text: '..... / ..... / 202...');
  final _fieldTripTimeController = TextEditingController(text: '09:00 - 16:30');

  @override
  void initState() {
    super.initState();
    _selectedDocIndex = widget.initialDocumentIndex;
    if (widget.students.isNotEmpty) {
      _selectedStudent = widget.students.first;
    }
  }

  @override
  void dispose() {
    _fieldTripNameController.dispose();
    _fieldTripDestController.dispose();
    _fieldTripDateController.dispose();
    _fieldTripTimeController.dispose();
    super.dispose();
  }

  final _docTypes = [
    {
      'title': 'Bireysel Veli Görüşme Formu',
      'desc': 'Veli görüşme tutanağı ve imza formu',
      'icon': Icons.connect_without_contact_outlined,
      'color': const Color(0xFF6366F1),
    },
    {
      'title': 'Bireysel Öğrenci Görüşme Tutanağı',
      'desc': 'Rehberlik odaklı öğrenci görüşme formu',
      'icon': Icons.psychology_outlined,
      'color': const Color(0xFF3B82F6),
    },
    {
      'title': 'BEP Kazanım & Gelişim Takip Formu',
      'desc': 'Kaynaştırma/Özel eğitim amaç takip çizelgesi',
      'icon': Icons.star_border_rounded,
      'color': const Color(0xFF10B981),
    },
    {
      'title': 'Öğrenci Tanıma Fişi (Bireyi Tanıma)',
      'desc': 'Aile yapısı, sağlık ve ilgi alanları formu',
      'icon': Icons.badge_outlined,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'Gezi & Sosyal Etkinlik Veli İzin Belgesi',
      'desc': 'Tek A4\'e 2 adet kesilebilir muvafakatname',
      'icon': Icons.directions_bus_outlined,
      'color': const Color(0xFFEC4899),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Evrak Türü Seçimi
          Text(
            'Hazırlamak İstediğiniz Belgeyi Seçin',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),

          ...List.generate(_docTypes.length, (index) {
            final doc = _docTypes[index];
            final isSelected = _selectedDocIndex == index;
            final color = doc['color'] as Color;

            return InkWell(
              onTap: () => setState(() => _selectedDocIndex = index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                      : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : (isDark ? Colors.white10 : Colors.grey.shade200),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(doc['icon'] as IconData, color: isSelected ? color : Colors.grey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['title'] as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? Colors.white : color)
                                  : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                            ),
                          ),
                          Text(
                            doc['desc'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: color, size: 18),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),

          // 2. Öğrenci Seçimi (Gezi hariç)
          if (_selectedDocIndex != 4) ...[
            Text(
              'Öğrenci Seçimi (Opsiyonel - Boş Şablon için seçmeyin)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<StudentModel?>(
                  value: _selectedStudent,
                  isExpanded: true,
                  hint: const Text('Boş Şablon Olarak Üret (Öğrenci Seçilmedi)'),
                  items: [
                    const DropdownMenuItem<StudentModel?>(
                      value: null,
                      child: Text('Boş Şablon (Tüm Öğrenciler İçin Yazdırılabilir)'),
                    ),
                    ...widget.students.map((s) => DropdownMenuItem<StudentModel?>(
                          value: s,
                          child: Text('${s.schoolNumber > 0 ? "${s.schoolNumber} - " : ""}${s.fullName}'),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedStudent = val),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Gezi İzin Özel Alanları
          if (_selectedDocIndex == 4) ...[
            TextField(
              maxLength: 100,
              controller: _fieldTripNameController,
              decoration: InputDecoration(
                labelText: 'Etkinlik / Gezi Adı',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    maxLength: 80,
                    controller: _fieldTripDestController,
                    decoration: InputDecoration(
                      labelText: 'Gidilecek Yer',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    maxLength: 20,
                    controller: _fieldTripDateController,
                    decoration: InputDecoration(
                      labelText: 'Tarih',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Önizleme & Yazdır Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openSelectedDocument();
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
              label: Text(
                'Belgeyi Canlı Önizle & Yazdır',
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

  void _openSelectedDocument() {
    switch (_selectedDocIndex) {
      case 0: // Veli Görüşme
        PdfPreviewScreen.open(
          context,
          title: 'Veli Görüşme Formu',
          subtitle: _selectedStudent != null ? _selectedStudent!.fullName : '${widget.classModel.name} Bireysel Form',
          fileName: 'Veli_Gorusme_Formu_${widget.classModel.name}.pdf',
          documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateParentInterviewFormPdfBytes(
            classModel: widget.classModel,
            teacherProfile: widget.teacherProfile,
            student: _selectedStudent,
          ),
        );
        break;
      case 1: // Öğrenci Görüşme
        PdfPreviewScreen.open(
          context,
          title: 'Öğrenci Görüşme Tutanağı',
          subtitle: _selectedStudent != null ? _selectedStudent!.fullName : '${widget.classModel.name} Rehberlik Tutanağı',
          fileName: 'Ogrenci_Gorusme_Tutanagi_${widget.classModel.name}.pdf',
          documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateStudentInterviewFormPdfBytes(
            classModel: widget.classModel,
            teacherProfile: widget.teacherProfile,
            student: _selectedStudent,
          ),
        );
        break;
      case 2: // BEP Takip — gerçek plan ekranı (şablon PDF değil)
        final nav = Navigator.of(context);
        nav.pop();
        nav.push(
          MaterialPageRoute(
            builder: (_) => BepListView(
              classModel: widget.classModel,
              students: widget.students,
              teacher: widget.teacherProfile,
            ),
          ),
        );
        break;
      case 3: // Tanıma Fişi
        PdfPreviewScreen.open(
          context,
          title: 'Öğrenci Tanıma Fişi',
          subtitle: _selectedStudent != null ? _selectedStudent!.fullName : '${widget.classModel.name} Bireyi Tanıma Formu',
          fileName: 'Ogrenci_Tanima_Fisi_${widget.classModel.name}.pdf',
          documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateStudentInfoSheetPdfBytes(
            classModel: widget.classModel,
            teacherProfile: widget.teacherProfile,
            student: _selectedStudent,
          ),
        );
        break;
      case 4: // Gezi İzin Belgesi
        PdfPreviewScreen.open(
          context,
          title: 'Gezi & Etkinlik Veli İzin Belgesi',
          subtitle: '${widget.classModel.name} - Tek A4\'te 2 Muvafakatname',
          fileName: 'Gezi_Veli_Izin_Belgesi_${widget.classModel.name}.pdf',
          documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateFieldTripPermissionPdfBytes(
            classModel: widget.classModel,
            teacherProfile: widget.teacherProfile,
            eventName: _fieldTripNameController.text.trim(),
            destination: _fieldTripDestController.text.trim(),
            eventDate: _fieldTripDateController.text.trim(),
            departureReturnTime: _fieldTripTimeController.text.trim(),
          ),
        );
        break;
    }
  }
}
