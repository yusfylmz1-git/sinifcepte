import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';

/// Sınıf listesi nereden yüklenecek?
enum StudentImportSourceChoice {
  whatsapp,
  files,
}

/// WhatsApp belgesi Android "Son dosyalar"da görünmez.
/// Öğretmene iki gerçek yolu gösterir: paylaşım ve dosya gezgini.
class StudentImportSourceSheet {
  StudentImportSourceSheet._();

  static const Color whatsappGreen = Color(0xFF25D366);

  static Future<StudentImportSourceChoice?> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveBottomSheet.show<StudentImportSourceChoice>(
      context: context,
      title: 'Sınıf listesini yükle',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Android "Son dosyalar" WhatsApp PDF\'ini göstermez. '
              'Ya paylaşın ya da WhatsApp Belgeler klasörünü açın.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            _SourceOption(
              icon: Icons.chat_rounded,
              iconColor: whatsappGreen,
              title: 'WhatsApp\'tan paylaş',
              subtitle:
                  'PDF\'ye dokunun → Paylaş → SınıfCepte. Liste doğrudan açılır.',
              recommended: true,
              isDark: isDark,
              onTap: () => Navigator.pop(
                context,
                StudentImportSourceChoice.whatsapp,
              ),
            ),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.folder_open_rounded,
              iconColor: AppColors.primary,
              title: 'WhatsApp klasöründen seç',
              subtitle:
                  'Son sekmesine değil; WhatsApp Documents klasörünü açar.',
              recommended: false,
              isDark: isDark,
              onTap: () => Navigator.pop(
                context,
                StudentImportSourceChoice.files,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showWhatsAppSteps(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: whatsappGreen),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'WhatsApp\'tan yükle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepRow(number: '1', text: 'WhatsApp\'ta okulun attığı PDF\'ye dokunun.'),
            SizedBox(height: 10),
            _StepRow(number: '2', text: 'Paylaş (kâğıt uçağı / üç nokta) simgesine basın.'),
            SizedBox(height: 10),
            _StepRow(number: '3', text: 'Uygulama listesinden SınıfCepte\'yi seçin.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await openWhatsAppApp();
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('WhatsApp\'ı aç'),
            style: FilledButton.styleFrom(backgroundColor: whatsappGreen),
          ),
        ],
      ),
    );
  }

  /// WhatsApp veya WhatsApp Business'ı açar; yoksa sessizce false döner.
  static Future<bool> openWhatsAppApp() async {
    final uris = <Uri>[
      Uri.parse('whatsapp://'),
      Uri.parse('https://wa.me/'),
    ];
    for (final uri in uris) {
      try {
        if (await canLaunchUrl(uri)) {
          return launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e, stackTrace) {
        debugPrint('WhatsApp açılamadı ($uri): $e\n$stackTrace');
      }
    }
    return false;
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool recommended;
  final bool isDark;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.recommended,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: recommended
          ? iconColor.withValues(alpha: isDark ? 0.16 : 0.10)
          : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: recommended
                  ? iconColor.withValues(alpha: 0.45)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Önerilen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? Colors.white60 : Colors.black54,
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
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: StudentImportSourceSheet.whatsappGreen,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ),
      ],
    );
  }
}
