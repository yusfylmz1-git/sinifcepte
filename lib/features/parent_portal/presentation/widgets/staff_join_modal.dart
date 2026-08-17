import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../providers/cloud_communication_provider.dart';

/// Branş öğretmeninin sınıf kadrosuna katılma ekranı.
///
/// Kadro akışının ikinci yarısıdır: sınıf öğretmeni [ClassStaffManagerModal]
/// üzerinden davet açar ve katılım kodunu iletir; branş öğretmeni burada
/// kodu girerek kendi Firebase UID'siyle kadroya yazılır.
///
/// Katılım tamamlanana kadar mesajlaşma yetkisi **açılmaz** — kural motoru
/// yetkiyi UID'ye bağlar, isme değil.
class StaffJoinModal extends ConsumerStatefulWidget {
  const StaffJoinModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StaffJoinModal(),
    );
  }

  @override
  ConsumerState<StaffJoinModal> createState() => _StaffJoinModalState();
}

class _StaffJoinModalState extends ConsumerState<StaffJoinModal> {
  final _classIdCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _classIdCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final classCloudId = _classIdCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();

    if (classCloudId.isEmpty || code.isEmpty) {
      setState(() => _error = 'Sınıf kimliği ve katılım kodunu girin.');
      return;
    }

    final teacher = ref.read(teacherProfileProvider);
    if (teacher.id.isEmpty) {
      setState(() => _error = 'Önce Google ile giriş yapmanız gerekiyor.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = await ref.read(cloudCommunicationRepositoryProvider).joinStaffByCode(
            classCloudId: classCloudId,
            joinCode: code,
            teacherUid: teacher.id,
            teacherName: teacher.fullName,
          );

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _error = 'Kod doğrulanamadı. Sınıf kimliğini ve kodu kontrol edin.';
          _busy = false;
        });
        return;
      }

      HapticFeedback.mediumImpact();
      ref.invalidate(classStaffProvider(classCloudId));
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kadroya katıldınız. Artık velilerle yazışabilirsiniz.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Kadroya katılma hatası: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Beklenmeyen bir sorun oluştu. Tekrar deneyin.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add_rounded,
                    color: Color(0xFF3B82F6), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sınıf Kadrosuna Katıl',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Sınıf öğretmeninin ilettiği katılım kodunu girin. '
              'Katıldıktan sonra o sınıfın velileriyle yazışabilirsiniz.',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classIdCtrl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Sınıf Kimliği',
                hintText: 'cls_...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Katılım Kodu',
                hintText: 'Örn: K7M2P9',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _join,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_busy ? 'Doğrulanıyor...' : 'Kadroya Katıl'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
