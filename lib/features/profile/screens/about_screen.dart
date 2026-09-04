import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import 'legal_document_screen.dart';

/// "Hakkında" ekranı.
///
/// ## Neden ayrı bir ekran
/// Kullanım Koşulları ve Gizlilik Politikası uygulamanın **hiçbir yerinde
/// görünmüyordu**. Play Store bunları zorunlu tutuyor; ayrıca KVKK
/// açısından kullanıcının verisinin ne olduğunu okuyabilmesi gerekiyor.
///
/// Bu maddeler profil menüsüne tek tek eklenseydi menü şişerdi. Benzer
/// uygulamalar (ör. KazanımCEP'te) bunları tek bir "Hakkında" başlığı
/// altında topluyor; aynı kalıp izlendi.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Uygulama sürümü. Destek talebinde de kullanılır.
  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(title: 'Hakkında'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            isDark: isDark,
            children: [
              _Row(
                isDark: isDark,
                icon: Icons.thumb_up_alt_outlined,
                title: 'Puan Ver',
                onTap: () => _openStore(context),
              ),
              _Divider(isDark: isDark),
              _Row(
                isDark: isDark,
                icon: Icons.description_outlined,
                title: 'Kullanım Koşulları',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalDocumentScreen(
                      kind: LegalDocumentKind.terms,
                    ),
                  ),
                ),
              ),
              _Divider(isDark: isDark),
              _Row(
                isDark: isDark,
                icon: Icons.shield_outlined,
                title: 'Gizlilik Politikası',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalDocumentScreen(
                      kind: LegalDocumentKind.privacy,
                    ),
                  ),
                ),
              ),
              _Divider(isDark: isDark),
              _Row(
                isDark: isDark,
                icon: Icons.quiz_outlined,
                title: 'Sıkça Sorulan Sorular',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalDocumentScreen(
                      kind: LegalDocumentKind.faq,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  'SınıfCepte',
                  style: AppFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sürüm $appVersion',
                  style: AppFonts.outfit(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.sinifcepte.sinifcepte',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _storeError(context);
      }
    } catch (_) {
      if (context.mounted) _storeError(context);
    }
  }

  void _storeError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mağaza açılamadı.')),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.children});

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 60,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: AppFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 15,
        color: isDark ? Colors.white38 : Colors.grey,
      ),
    );
  }
}
