import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
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
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Sorun, öneri veya hata bildirimlerinizi iletin',
                        style: GoogleFonts.outfit(
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

            Center(
              child: Text(
                'Talepleriniz en geç 24 saat içinde incelenir ve yanıtlanır.',
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
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
        const SnackBar(content: Text('Lütfen başlık ve açıklama alanlarını doldurun.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await KvkkConsentService.logAudit(
      actorId: widget.userId,
      actorRole: widget.userRole,
      action: 'support_ticket_created',
      targetId: _category,
      details: '$subject: $message',
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('✅ Destek talebiniz başarıyla iletildi.')),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
