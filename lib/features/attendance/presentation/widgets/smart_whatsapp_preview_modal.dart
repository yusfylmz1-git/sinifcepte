import 'package:flutter/material.dart';
import '../../../../core/services/whatsapp_share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';

/// SınıfCepte - Akıllı WhatsApp Önizleme ve Paylaşım Modal'ı
class SmartWhatsAppPreviewModal {
  SmartWhatsAppPreviewModal._();

  static void show({
    required BuildContext context,
    required String className,
    required String subjectName,
    required int totalStudents,
    required List<String> starStudentNames,
    required List<String> needsWorkStudentNames,
  }) {
    final summaryText = WhatsAppShareService.generateClassSummaryText(
      className: className,
      subjectName: subjectName,
      totalStudents: totalStudents,
      starStudentNames: starStudentNames,
      needsWorkStudentNames: needsWorkStudentNames,
    );

    ResponsiveBottomSheet.show(
      context: context,
      title: 'Akıllı WhatsApp Bilgilendirmesi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              summaryText,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final success = await WhatsAppShareService.copyToClipboard(summaryText);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'WhatsApp özet metni panoya kopyalandı! 📋'
                                : 'Kopyalama başarısız.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Panoya Kopyala'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
