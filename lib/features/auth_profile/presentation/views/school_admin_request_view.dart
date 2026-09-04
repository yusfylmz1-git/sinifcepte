import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/school_admin_request_model.dart';
import '../../data/repositories/school_admin_repository.dart';
import '../../providers/teacher_profile_provider.dart';
import '../../providers/user_role_provider.dart';

/// Okul yöneticiliği başvuru ekranı.
///
/// ## Rolün yeri
/// Okul yöneticiliği **opsiyoneldir**: yöneticisi olmayan okullarda
/// uygulamanın tamamı normal çalışır. Yöneticinin işi öğretmenleri
/// doğrulamak ve veli şikâyetlerini görmektir — öğretmenlerin sınıf
/// verilerine erişimi yoktur.
///
/// ## Neden onay gerekiyor
/// Bir okula ilk kaydolan kişinin otomatik yönetici olması kötüye
/// kullanıma açıktır. Bu yüzden başvuru süper admin tarafından incelenir;
/// yetki ancak onaydan sonra custom claim ile verilir.
class SchoolAdminRequestView extends ConsumerStatefulWidget {
  const SchoolAdminRequestView({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SchoolAdminRequestView(),
    );
  }

  @override
  ConsumerState<SchoolAdminRequestView> createState() =>
      _SchoolAdminRequestViewState();
}

class _SchoolAdminRequestViewState
    extends ConsumerState<SchoolAdminRequestView> {
  final _noteCtrl = TextEditingController();
  final _repo = SchoolAdminRepository();

  bool _loading = true;
  bool _submitting = false;
  SchoolAdminRequestModel? _existing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final teacher = ref.read(teacherProfileProvider);
      final found = await _repo.myRequest(teacher.id);
      if (!mounted) return;
      setState(() {
        _existing = found;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Başvuru okuma hatası: $e\n$stackTrace');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final teacher = ref.read(teacherProfileProvider);

    if (teacher.id.isEmpty) {
      setState(() => _error = 'Önce Google ile giriş yapmanız gerekiyor.');
      return;
    }
    if (!teacher.isSchoolBound) {
      setState(() => _error = 'Başvuru için önce okulunuzu seçmelisiniz.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final request = SchoolAdminRequestModel(
        id: SchoolAdminRepository.requestIdFor(teacher.id),
        teacherUid: teacher.id,
        teacherName: teacher.fullName,
        teacherEmail: teacher.email,
        schoolId: teacher.schoolId ?? '',
        schoolName: teacher.schoolName,
        city: teacher.city ?? '',
        district: teacher.district ?? '',
        note: _noteCtrl.text.trim(),
        requestedAt: DateTime.now(),
      );

      final ok = await _repo.submitRequest(request);
      if (!mounted) return;

      if (!ok) {
        setState(() {
          _submitting = false;
          _error =
              'Başvuru gönderilemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.';
        });
        return;
      }

      setState(() {
        _existing = request;
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başvurunuz alındı. İnceleme sonrası bilgilendirileceksiniz.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Başvuru gönderme hatası: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Beklenmeyen bir sorun oluştu. Tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = ref.watch(teacherProfileProvider);
    final roleState = ref.watch(userRoleProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Okul Yöneticiliği Başvurusu',
                      style: AppFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (roleState.isSchoolAdmin)
                _buildApprovedState(isDark)
              else if (_existing != null && _existing!.isPending)
                _buildPendingState(isDark)
              else
                _buildForm(isDark, teacher.fullSchoolTitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovedState(bool isDark) {
    return _infoBox(
      isDark: isDark,
      color: const Color(0xFF10B981),
      icon: Icons.verified_rounded,
      title: 'Okul yöneticisisiniz',
      body: 'Öğretmen doğrulama ve şikâyet yönetimi paneline '
          'profil ekranından erişebilirsiniz.',
    );
  }

  Widget _buildPendingState(bool isDark) {
    final req = _existing!;
    final dateStr = DateFormat('dd.MM.yyyy').format(req.requestedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          isDark: isDark,
          color: Colors.orange,
          icon: Icons.hourglass_top_rounded,
          title: 'Başvurunuz inceleniyor',
          body: '$dateStr tarihinde ${req.fullSchoolTitle} için başvurdunuz. '
              'Sonuç açıklandığında bilgilendirileceksiniz.',
        ),
        const SizedBox(height: 12),
        Text(
          'Bu süreçte uygulamanın tüm özelliklerini normal şekilde '
          'kullanmaya devam edebilirsiniz — yöneticilik onayı hiçbir '
          'özelliğin ön koşulu değildir.',
          style: AppFonts.outfit(
            fontSize: 12.5,
            color: Colors.grey,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(bool isDark, String schoolTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Okul yöneticisi, okulundaki öğretmenleri doğrular ve velilerden '
          'gelen şikâyetleri görür. Öğretmenlerin sınıf verilerine, notlarına '
          'veya veli iletişimine erişimi yoktur.',
          style: AppFonts.outfit(
            fontSize: 12.5,
            color: Colors.grey,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Başvurulan okul',
                style: AppFonts.outfit(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 3),
              Text(
                schoolTitle.isEmpty ? 'Okul seçilmedi' : schoolTitle,
                style: AppFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _noteCtrl,
          enabled: !_submitting,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Görev bilginiz',
            hintText:
                'Örn: Okul müdür yardımcısıyım, 2019\'dan beri görevdeyim.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
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
              style: AppFonts.outfit(fontSize: 12.5, color: Colors.redAccent),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_submitting ? 'Gönderiliyor...' : 'Başvuruyu Gönder'),
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
    );
  }

  Widget _infoBox({
    required bool isDark,
    required Color color,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppFonts.outfit(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
