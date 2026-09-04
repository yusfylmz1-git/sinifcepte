import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/class_provider.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';

/// Yeni Sınıf Ekleme Diyaloğu (AddClassDialog)
class AddClassDialog extends ConsumerStatefulWidget {
  const AddClassDialog({super.key});

  @override
  ConsumerState<AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends ConsumerState<AddClassDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _yearController = TextEditingController(text: '2024-2025');
  final _descController = TextEditingController();
  bool _isHomeroom = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Ders alanı öğretmenin BRANŞIYLA açılır.
    //
    // Boş bırakılıyordu; öğretmen her sınıfta aynı branşı elle yazmak
    // zorunda kalıyor, çoğu zaman boş geçiyordu. Boş kalınca sistem
    // "Genel Ders" yazıyordu ve bu her ekranda görünüyordu.
    //
    // Öğretmen isterse değiştirebilir (ör. ikinci branş).
    final brans = ref.read(teacherProfileProvider).branch.trim();
    if (brans.isNotEmpty) _subjectController.text = brans;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _yearController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(classListProvider.notifier).addClass(
          name: _nameController.text.trim(),
          subject: _subjectController.text.trim(),
          academicYear: _yearController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          isHomeroom: _isHomeroom,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sınıf başarıyla eklendi! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.class_rounded, color: AppColors.primaryLight),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Yeni Sınıf Oluştur',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Sınıf Adı Input
                TextFormField(
                  controller: _nameController,
                  maxLength: 50,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Sınıf Adı', 'Örn: 5-A', Icons.meeting_room_rounded),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Lütfen sınıf adını girin' : null,
                ),
                const SizedBox(height: 14),

                // Ders Adı Input
                TextFormField(
                  controller: _subjectController,
                  maxLength: 60,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(
                    'Ders / Branş',
                    'Örn: Matematik',
                    Icons.menu_book_rounded,
                  ),
                ),
                const SizedBox(height: 14),

                // Akademik Yıl Input
                TextFormField(
                  controller: _yearController,
                  maxLength: 12,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Akademik Yıl', '2024-2025', Icons.calendar_today_rounded),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Akademik yıl girin' : null,
                ),
                const SizedBox(height: 14),

                // Açıklama Input (Opsiyonel)
                TextFormField(
                  controller: _descController,
                  maxLength: 300,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Not / Açıklama (İsteğe Bağlı)', 'Örn: Salı-Perşembe dersleri', Icons.notes_rounded),
                ),
                const SizedBox(height: 16),

                // Rehberlik Sınıfı Anahtarı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isHomeroom
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isHomeroom ? AppColors.primary : AppColors.glassBorder,
                    ),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Rehberlik / Şube Sınıfım',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Bu sınıfı resmî şube rehberlik sınıfınız olarak belirler.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    value: _isHomeroom,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _isHomeroom = val);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('İptal', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Kaydet',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}
