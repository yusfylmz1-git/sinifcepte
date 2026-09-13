import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../data/services/recent_student_documents.dart';
import 'student_import_source_sheet.dart';

/// Android "Son dosyalar" yerine WhatsApp belgelerini gösteren seçici.
enum StudentDocumentBrowseAction {
  pickPath,
  openWhatsAppFolder,
  grantFolder,
  shareFromWhatsApp,
  systemPicker,
}

class StudentDocumentBrowseResult {
  final StudentDocumentBrowseAction action;
  final String? path;

  const StudentDocumentBrowseResult(this.action, {this.path});
}

class StudentDocumentBrowserSheet {
  StudentDocumentBrowserSheet._();

  static Future<StudentDocumentBrowseResult?> show(
    BuildContext context, {
    required List<RecentStudentDocument> documents,
    required bool hasFolderGrant,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    return ResponsiveBottomSheet.show<StudentDocumentBrowseResult>(
      context: context,
      title: 'WhatsApp belgeleriniz',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Android "Son dosyalar" WhatsApp PDF\'ini göstermez. '
            'Okulun attığı liste burada veya WhatsApp klasöründedir.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (documents.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Henüz listelenecek dosya yok. "WhatsApp klasörünü aç" ile '
                'Belgeler klasörüne gidin — Son sekmesine değil.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            )
          else
            ...documents.take(20).map((doc) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(
                      context,
                      StudentDocumentBrowseResult(
                        StudentDocumentBrowseAction.pickPath,
                        path: doc.path,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            doc.name.toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf_rounded
                                : Icons.table_chart_rounded,
                            color: const Color(0xFFFF512F),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${doc.sourceLabel} · ${dateFmt.format(doc.modified)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              context,
              const StudentDocumentBrowseResult(
                StudentDocumentBrowseAction.openWhatsAppFolder,
              ),
            ),
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('WhatsApp klasörünü aç'),
            style: FilledButton.styleFrom(
              backgroundColor: StudentImportSourceSheet.whatsappGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(
              context,
              const StudentDocumentBrowseResult(
                StudentDocumentBrowseAction.grantFolder,
              ),
            ),
            icon: const Icon(Icons.folder_special_rounded),
            label: Text(
              hasFolderGrant
                  ? 'Klasör iznini yenile'
                  : 'Klasöre bir kez izin ver (liste dolsun)',
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const StudentDocumentBrowseResult(
                StudentDocumentBrowseAction.shareFromWhatsApp,
              ),
            ),
            child: const Text('WhatsApp\'tan paylaş'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const StudentDocumentBrowseResult(
                StudentDocumentBrowseAction.systemPicker,
              ),
            ),
            child: Text(
              'Drive / başka konum',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showFolderHint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Son dosyalarda aramayın',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Açılan ekranın en üstünde "Son" yazıyorsa ona dokunun.\n\n'
          'Ardından: WhatsApp → Media → WhatsApp Documents\n'
          'veya Android → media → com.whatsapp → WhatsApp Documents.\n\n'
          'Okulun attığı PDF oradadır; Son listesinde olmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım, klasörü aç'),
          ),
        ],
      ),
    );
  }
}
