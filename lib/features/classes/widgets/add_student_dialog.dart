import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/student_model.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/student_provider.dart';
import '../providers/class_provider.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/name_formatter.dart';

/// Öğrenci Ekleme ve Düzenleme Diyaloğu (AddStudentDialog)
class AddStudentDialog extends ConsumerStatefulWidget {
  final int classId;
  final StudentModel? student; // Null ise ekleme, dolu ise düzenleme

  const AddStudentDialog({super.key, required this.classId, this.student});

  @override
  ConsumerState<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends ConsumerState<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _selectedGender = 'Erkek';
  int? _selectedClassId;
  bool _isLoading = false;
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.student != null;
    _selectedClassId = widget.student?.classId ?? widget.classId;
    if (_isEditing) {
      _numController.text = widget.student!.schoolNumber.toString();
      _firstNameController.text = widget.student!.firstName;
      _lastNameController.text = widget.student!.lastName;
      _selectedGender = widget.student!.gender;
    }
  }

  @override
  void dispose() {
    _numController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final numText = _numController.text.trim();
    // Standart yazim baştan uygulanir: "yusuf" / "yilmaz" ->
    // "Yusuf" / "YILMAZ". Ham hali kaydedilirse liste, PDF ve veli
    // ekrani her yerde farkli gorunuyordu.
    final firstName = NameFormatter.formatFirstName(_firstNameController.text);
    final lastName = NameFormatter.formatLastName(_lastNameController.text);

    bool success = false;
    String? errorMessage;

    if (_isEditing) {
      final result = await ref
          .read(studentListProvider(widget.classId).notifier)
          .updateStudent(
            id: widget.student!.id!,
            schoolNumber: int.parse(numText),
            firstName: firstName,
            lastName: lastName,
            gender: _selectedGender,
            newClassId: _selectedClassId,
          );
      success = result.success;
      errorMessage = result.error;
      if (success && _selectedClassId != null && _selectedClassId != widget.classId) {
        ref.invalidate(studentListProvider(_selectedClassId!));
      }
    } else {
      success = await ref
          .read(studentListProvider(widget.classId).notifier)
          .addStudent(
            schoolNumber: int.parse(numText),
            firstName: firstName,
            lastName: lastName,
            gender: _selectedGender,
          );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? (_selectedClassId != widget.classId
                      ? 'Öğrenci bilgileri ve sınıfı güncellendi! 🔄'
                      : 'Öğrenci bilgileri güncellendi! ✏️')
                  : 'Öğrenci başarıyla eklendi! 🎓',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Bir hata oluştu, lütfen tekrar deneyin.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                      child: Icon(
                        _isEditing
                            ? Icons.edit_rounded
                            : Icons.person_add_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _isEditing ? 'Öğrenciyi Düzenle' : 'Yeni Öğrenci Ekle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Okul No Input
                TextFormField(
                  controller: _numController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                  decoration: _buildInputDecoration(
                    'Okul Numarası',
                    'Örn: 452',
                    Icons.numbers_rounded,
                    isDark,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Okul nosu girin';
                    }
                    final num = int.tryParse(val.trim());
                    if (num == null) {
                      return 'Sadece sayı girin';
                    }
                    if (num <= 0) {
                      return 'Geçerli bir numara girin';
                    }

                    // Sınıf içi mükerrer numara kontrolü (1. Katman - Anlık UI Doğrulama)
                    final currentStudents =
                        ref.read(studentListProvider(widget.classId)).valueOrNull ?? [];
                    final duplicateStudent = currentStudents.where((s) {
                      if (_isEditing && s.id == widget.student?.id) return false;
                      return s.schoolNumber == num;
                    }).firstOrNull;

                    if (duplicateStudent != null) {
                      return 'Bu numara (${duplicateStudent.firstName} ${duplicateStudent.lastName}) zaten kayıtlı!';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Ad Input
                TextFormField(
                  controller: _firstNameController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(30),
                  ],
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                  decoration: _buildInputDecoration(
                    'Öğrenci Adı',
                    'Örn: Ahmet',
                    Icons.person_rounded,
                    isDark,
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Adı girin' : null,
                ),
                const SizedBox(height: 14),

                // Soyad Input
                TextFormField(
                  controller: _lastNameController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(30),
                  ],
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                  decoration: _buildInputDecoration(
                    'Öğrenci Soyadı',
                    'Örn: Yılmaz',
                    Icons.badge_rounded,
                    isDark,
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Soyadı girin' : null,
                ),
                const SizedBox(height: 14),

                // Sınıf / Şube Değiştirme (Düzenleme Modunda - Yalnızca Aynı Kademedeki Şubeler)
                if (_isEditing) ...[
                  Builder(
                    builder: (context) {
                      final allClasses = ref.watch(classListProvider).valueOrNull ?? [];
                      final currentClass = allClasses.where((c) => c.id == widget.classId).firstOrNull;
                      final currentGrade = currentClass != null
                          ? InputSanitizer.extractGradeLevel(currentClass.name)
                          : null;

                      final availableClasses = allClasses.where((c) {
                        if (c.id == widget.classId) return true; // Mevcut sınıf listede kalsın
                        if (currentGrade != null) {
                          return InputSanitizer.extractGradeLevel(c.name) == currentGrade;
                        }
                        return true;
                      }).toList();

                      if (availableClasses.length <= 1) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: _selectedClassId,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight, fontSize: 14),
                            decoration: _buildInputDecoration(
                              currentGrade != null ? '$currentGrade. Sınıf Şubesi' : 'Kayıtlı Olduğu Sınıf',
                              'Sınıf seçin',
                              Icons.school_rounded,
                              isDark,
                            ),
                            items: availableClasses.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(
                                  c.isHomeroom ? '${c.name} (Rehberlik Sınıfı)' : c.name,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    fontWeight: c.id == widget.classId ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId != null) {
                                setState(() => _selectedClassId = newId);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      );
                    },
                  ),
                ],

                // Cinsiyet Seçimi
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Cinsiyet',
                    style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'Erkek'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedGender == 'Erkek' ? Colors.blueAccent.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                            border: Border.all(
                              color: _selectedGender == 'Erkek' ? Colors.blueAccent : (isDark ? Colors.white12 : Colors.black12),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.face_6_rounded, color: _selectedGender == 'Erkek' ? Colors.blueAccent : (isDark ? Colors.white54 : AppColors.textSecondaryLight), size: 20),
                              const SizedBox(width: 8),
                              Text('Erkek', style: TextStyle(color: _selectedGender == 'Erkek' ? Colors.blueAccent : (isDark ? Colors.white54 : AppColors.textSecondaryLight), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'Kız'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedGender == 'Kız' ? Colors.pinkAccent.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                            border: Border.all(
                              color: _selectedGender == 'Kız' ? Colors.pinkAccent : (isDark ? Colors.white12 : Colors.black12),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.face_3_rounded, color: _selectedGender == 'Kız' ? Colors.pinkAccent : (isDark ? Colors.white54 : AppColors.textSecondaryLight), size: 20),
                              const SizedBox(width: 8),
                              Text('Kız', style: TextStyle(color: _selectedGender == 'Kız' ? Colors.pinkAccent : (isDark ? Colors.white54 : AppColors.textSecondaryLight), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'İptal',
                          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight),
                        ),
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
                          elevation: 0,
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isEditing ? 'Güncelle' : 'Öğrenciyi Ekle',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
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

  InputDecoration _buildInputDecoration(
    String label,
    String hint,
    IconData icon,
    bool isDark,
  ) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      hintStyle: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3)),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? AppColors.glassBorder : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
