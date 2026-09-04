import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/support/support_repository.dart';
import '../../../../core/support/support_request.dart';
import '../../data/services/kvkk_consent_service.dart';

/// SınıfCepte - Yardım, Destek & Hata Bildirim Modalı
class HelpSupportModal extends StatefulWidget {
  final String userId;
  final String userRole; // 'parent', 'teacher'

  const HelpSupportModal({
    super.key,
    required this.userId,
    required this.userRole,
  });

  static Future<void> show(BuildContext context, {required String userId, required String userRole}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HelpSupportModal(userId: userId, userRole: userRole),
    );
  }

  @override
  State<HelpSupportModal> createState() => _HelpSupportModalState();
}

class _HelpSupportModalState extends State<HelpSupportModal> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'code_issue'; // 'code_issue', 'bug_report', 'suggestion', 'other'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yardım & Destek Merkezi',
                        style: AppFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Sorun, öneri veya hata bildirimlerinizi iletin',
                        style: AppFonts.outfit(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Destek Konusu',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'code_issue', child: Text('🔑 Veli Referans Kodu Sorunu')),
                DropdownMenuItem(value: 'bug_report', child: Text('🐛 Uygulama Hatası Bildir')),
                DropdownMenuItem(value: 'suggestion', child: Text('💡 Öneri & İyileştirme')),
                DropdownMenuItem(value: 'other', child: Text('❓ Diğer Sorular')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _subjectCtrl,
              maxLength: SupportRequest.maxSubjectLength,
              decoration: const InputDecoration(
                labelText: 'Başlık / Özet',
                hintText: 'Örn: Kod girerken öğrenci numarası uyuşmuyor',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _messageCtrl,
              maxLines: 4,
              maxLength: SupportRequest.maxMessageLength,
              decoration: const InputDecoration(
                labelText: 'Açıklamanız',
                hintText: 'Detaylı bilgi yazmanız sorununuzu daha hızlı çözmemizi sağlar...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitRequest,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'İletiliyor...' : 'Destek Talebini Gönder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Onceden "en gec 24 saat icinde yanitlanir" yaziyordu; talep
            // hicbir yere gitmedigi icin bu vaat karsiliksizdi. Artik
            // gercek adres gosteriliyor: kullanici buluta yazma basarisiz
            // olsa bile ulasabilecegi bir yol goruyor.
            Center(
              child: Column(
                children: [
                  Text(
                    'Talebiniz ekibimize iletilir.',
                    style: AppFonts.outfit(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    SupportRepository.supportEmail,
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen başlık ve açıklama alanlarını doldurun.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final request = SupportRequest.create(
      userId: widget.userId,
      userRole: widget.userRole,
      category: SupportCategory.fromId(_category),
      subject: subject,
      message: message,
      platform: defaultTargetPlatform.name,
    );

    // Yerel denetim gunlugu korunuyor: buluta yazma basarisiz olsa bile
    // cihazda bir iz kalir.
    await KvkkConsentService.logAudit(
      actorId: widget.userId,
      actorRole: widget.userRole,
      action: 'support_ticket_created',
      targetId: request.category.id,
      details: '$subject: $message',
    );

    final gonderildi = await SupportRepository.instance.submit(request);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (gonderildi) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Destek talebiniz iletildi.')),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Buluta yazilamadi. Onceden yine de "basariyla iletildi" deniyordu;
    // kullanici yardim istedigini saniyor ama talep hicbir yere gitmiyordu.
    // Artik durum dogru soylenir ve e-posta yolu sunulur.
    await _offerEmailFallback(request);
  }

  /// Bulut yazimi basarisiz oldugunda e-posta ile gonderme secenegi sunar.
  Future<void> _offerEmailFallback(SupportRequest request) async {
    final gonder = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Talep Gönderilemedi',
          style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'İnternet bağlantısı kurulamadı. Talebinizi e-posta ile '
          'gönderebilirsiniz:\n\n${SupportRepository.supportEmail}',
          style: AppFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('E-posta ile Gönder'),
          ),
        ],
      ),
    );

    if (gonder != true || !mounted) return;

    final uri = SupportRepository.mailtoUri(request);
    try {
      final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!acildi && mounted) {
        _showEmailManually();
      }
    } catch (e) {
      debugPrint('mailto acilamadi: $e');
      if (mounted) _showEmailManually();
    }
  }

  /// E-posta uygulamasi yoksa adresi kopyalanabilir sekilde gosterir.
  void _showEmailManually() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'E-posta uygulaması açılamadı. '
          'Adres: ${SupportRepository.supportEmail}',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }
}
