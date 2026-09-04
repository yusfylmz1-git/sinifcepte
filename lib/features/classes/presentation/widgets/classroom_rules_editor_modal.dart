import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../utils/classroom_documents_pdf_generator.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';

/// SınıfCepte - Sınıf Kuralları Afişi Düzenleme Modalı
class ClassroomRulesEditorModal extends StatefulWidget {
  final ClassModel classModel;
  final TeacherProfileModel teacherProfile;

  const ClassroomRulesEditorModal({
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
      title: 'Sınıf Kuralları Afişi Düzenleyici',
      child: ClassroomRulesEditorModal(
        classModel: classModel,
        teacherProfile: teacherProfile,
      ),
    );
  }

  @override
  State<ClassroomRulesEditorModal> createState() => _ClassroomRulesEditorModalState();
}

class _ClassroomRulesEditorModalState extends State<ClassroomRulesEditorModal> {
  final List<String> _rules = [
    'Derse vaktinde ve gerekli ders araç-gereçlerimle gelirim.',
    'Söz alarak konuşur, konuşan arkadaşımı ve öğretmenimi saygıyla dinlerim.',
    'Arkadaşlarıma ve eşyalarına zarar vermem, her zaman nezaket dili kullanırım.',
    'Sınıfımı, sıramı ve panomuzu temiz, tertipli ve düzenli tutarım.',
    'Ders esnasında izin almadan yerimden kalkmam ve dikkat dağıtmam.',
    'Elektronik cihazları ve akıllı tahtayı öğretmenimin yönergelerine uygun kullanırım.',
    'Verilen ödev ve sınıf sorumluluklarımı zamanında yerine getiririm.',
    'Koridorlarda ve sınıfta koşmadan güvenli bir şekilde hareket ederim.',
    'Farklılıklara saygı duyar, kimseyi oyunlardan ve etkinliklerden dışlamam.',
    'Sınıf ve okul kaynaklarını özenle korur, israftan kaçınırım.',
  ];

  final _newRuleController = TextEditingController();

  @override
  void dispose() {
    _newRuleController.dispose();
    super.dispose();
  }

  void _addRule() {
    final text = _newRuleController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _rules.add(text);
        _newRuleController.clear();
      });
    }
  }

  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _editRule(int index) {
    final controller = TextEditingController(text: _rules[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kuralı Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _rules[index] = controller.text.trim();
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bilgi Kartı
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sınıf panosuna asılmaya hazır, renkli rozetli ve şık çerçeveli A4 poster çıktısı üretir.',
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

          // Yeni Kural Ekleme Satırı
          Row(
            children: [
              Expanded(
                child: TextField(
                  maxLength: 120,
                  controller: _newRuleController,
                  decoration: InputDecoration(
                    hintText: 'Yeni sınıf kuralı yazın...',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.add_circle_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addRule(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addRule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Kurallar Listesi (${_rules.length} Madde)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),

          // Kurallar Listesi
          ...List.generate(_rules.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _rules[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blueAccent),
                    onPressed: () => _editRule(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    onPressed: () => _removeRule(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // Önizleme & Yazdır Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                PdfPreviewScreen.open(
                  context,
                  title: 'Sınıf Kuralları Afişi',
                  subtitle: '${widget.classModel.name} Sınıf Panosu Afişi',
                  fileName: 'Sinif_Kurallari_Afisi_${widget.classModel.name}.pdf',
                  documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateClassroomRulesPosterPdfBytes(
                    classModel: widget.classModel,
                    teacherProfile: widget.teacherProfile,
                    rules: _rules,
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
              label: Text(
                'Afişi Önizle & Yazdır (A4)',
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
