import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/add_student_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/student_model.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/class_provider.dart';
import '../../providers/student_provider.dart';
import '../../data/services/excel_student_parser.dart';
import '../../data/services/pdf_student_parser.dart';
import '../../../../data/models/class_model.dart';

/// SınıfCepte - PDF & Excel Akıllı Öğrenci İçe Aktarma ve Önizleme Ekranı
/// Profesyonel (UI-UX MAX) Tasarım
class StudentImportPreviewView extends ConsumerStatefulWidget {
  final int? initialClassId;
  final String? initialClassName;

  const StudentImportPreviewView({
    super.key,
    this.initialClassId,
    this.initialClassName,
  });

  @override
  ConsumerState<StudentImportPreviewView> createState() => _StudentImportPreviewViewState();
}

class _StudentImportPreviewViewState extends ConsumerState<StudentImportPreviewView> {
  int? _selectedClassId;
  List<_EditableStudentDraft> _draftStudents = [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkDuplicatesAgainstExisting(List<_EditableStudentDraft> drafts) async {
    if (_selectedClassId != null) {
      final repository = ref.read(studentRepositoryProvider);
      final existingStudents = await repository.getStudentsByClassId(_selectedClassId!);
      final existingNumbers = existingStudents.map((s) => s.schoolNumber).toSet();

      if (mounted) {
        setState(() {
          for (var draft in drafts) {
            if (existingNumbers.contains(draft.schoolNumber)) {
              draft.isAlreadyRegistered = true;
              draft.isSelected = false;
            } else {
              draft.isAlreadyRegistered = false;
            }
          }
        });
      }
    }
  }

  Future<void> _handleExcelPick() async {
    setState(() => _isImporting = true);
    try {
      final result = await ExcelStudentParser.pickAndParseExcel(_selectedClassId ?? 0);
      _processResult(result.success, result.students, result.errorMessage, isPdf: false);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _handlePdfPick() async {
    setState(() => _isImporting = true);
    try {
      final result = await PdfStudentParser.pickAndParsePdf(_selectedClassId ?? 0);
      _processResult(result.success, result.students, result.errorMessage, isPdf: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _processResult(bool success, List<StudentModel> students, String? errorMessage, {required bool isPdf}) {
    if (success) {
      final drafts = students
          .map((s) => _EditableStudentDraft(
                schoolNumber: s.schoolNumber,
                firstName: s.firstName,
                lastName: s.lastName,
                gender: s.gender,
                isSelected: true,
              ))
          .toList();

      _checkDuplicatesAgainstExisting(drafts);

      setState(() {
        _draftStudents = drafts;
      });

      if (mounted) {
        _showModernSnackBar(
          '${students.length} öğrenci başarıyla okundu! 🎉',
          isError: false,
        );
      }
    } else if (errorMessage != null && mounted) {
      _showModernSnackBar(errorMessage, isError: true);
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleSaveToDatabase() async {
    final selectedDrafts = _draftStudents.where((d) => d.isSelected && !d.isAlreadyRegistered).toList();
    if (selectedDrafts.isEmpty) {
      _showModernSnackBar('Kaydedilecek en az 1 öğrenci seçmelisiniz!', isError: true);
      return;
    }

    if (_selectedClassId == null) {
      _showModernSnackBar('Lütfen listeden mevcut bir sınıf seçin!', isError: true);
      return;
    }

    final repository = ref.read(studentRepositoryProvider);
    final existingStudents = await repository.getStudentsByClassId(_selectedClassId!);
    final existingNumbers = existingStudents.map((s) => s.schoolNumber).toSet();

    final duplicateDrafts = selectedDrafts.where((d) => existingNumbers.contains(d.schoolNumber)).toList();
    
    if (duplicateDrafts.isNotEmpty) {
      _showModernSnackBar('Seçili öğrenciler arasında bu sınıfa zaten kayıtlı olanlar var! Lütfen listedeki turuncu uyarıları kontrol edin.', isError: true);
      setState(() {
        for (var draft in _draftStudents) {
          if (existingNumbers.contains(draft.schoolNumber)) {
            draft.isAlreadyRegistered = true;
            draft.isSelected = false;
          }
        }
      });
      return;
    }

    int targetClassId = _selectedClassId!;
    
    setState(() => _isImporting = true);

    try {
      final studentModels = selectedDrafts
          .map((d) => StudentModel(
                classId: targetClassId,
                schoolNumber: d.schoolNumber,
                firstName: d.firstName,
                lastName: d.lastName,
                gender: d.gender,
              ))
          .toList();

      await repository.insertStudentsBatch(studentModels);
      ref.invalidate(studentListProvider(targetClassId));

      if (mounted) {
        _showModernSnackBar('${studentModels.length} öğrenci sınıfa başarıyla eklendi! 🎯');
        Navigator.pop(context);
      }
    } catch (e, st) {
      debugPrint('Save Batch Error: $e\n$st');
      if (mounted) {
        _showModernSnackBar('Kayıt esnasında hata oluştu', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      for (var d in _draftStudents) {
        if (!d.isAlreadyRegistered) {
          d.isSelected = select;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classesState = ref.watch(classListProvider);
    final availableClasses = classesState.value ?? [];

    final selectedCount = _draftStudents.where((d) => d.isSelected).length;
    final maleCount = _draftStudents.where((d) => d.isSelected && d.gender == 'Erkek').length;
    final femaleCount = _draftStudents.where((d) => d.isSelected && d.gender == 'Kız').length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Toplu Öğrenci Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Arka Plan Dekorasyon (Hafif Glow)
          Positioned(
            top: -100,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                ),
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                _buildUploadCards(isDark),
                const SizedBox(height: 24),
                _buildClassSelection(isDark, availableClasses),
                if (_draftStudents.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildStatsRow(isDark, selectedCount, maleCount, femaleCount),
                  const SizedBox(height: 24),
                  _buildStudentListHeader(isDark),
                  const SizedBox(height: 12),
                  _buildStudentList(isDark),
                ]
              ],
            ),
          ),

          // Sticky Bottom Save Button
          if (_draftStudents.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                      border: Border(
                        top: BorderSide(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _isImporting || selectedCount == 0 ? null : _handleSaveToDatabase,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isImporting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Text(
                              'SEÇİLEN ($selectedCount) ÖĞRENCİYİ KAYDET',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _CompactUploadCard(
            title: 'Excel',
            icon: Icons.table_chart_rounded,
            color: const Color(0xFF11998e),
            onTap: _isImporting ? null : _handleExcelPick,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CompactUploadCard(
            title: 'e-Okul PDF',
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFFF512F),
            onTap: _isImporting ? null : _handlePdfPick,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CompactUploadCard(
            title: 'Manuel',
            icon: Icons.person_add_rounded,
            color: Colors.blueAccent,
            onTap: _isImporting ? null : () {
              if (_selectedClassId == null) {
                _showModernSnackBar('Lütfen listeden mevcut bir sınıf seçin!', isError: true);
                return;
              }
              showDialog(
                context: context,
                builder: (ctx) => AddStudentDialog(
                  classId: _selectedClassId!,
                ),
              );
            },
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildClassSelection(bool isDark, List<ClassModel> availableClasses) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Hedef Sınıf',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildExistingClassDropdown(isDark, availableClasses),
        ],
      ),
    );
  }

  Widget _buildExistingClassDropdown(bool isDark, List<ClassModel> availableClasses) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedClassId,
          isExpanded: true,
          hint: const Text('Sınıf Seçiniz'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: availableClasses
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.subject.isNotEmpty ? '${c.name} (${c.subject})' : c.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)
                    ),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedClassId = val;
              _checkDuplicatesAgainstExisting(_draftStudents);
            });
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, int selected, int male, int female) {
    return Row(
      children: [
        Expanded(
          child: _StatBadge(label: 'Seçilen', value: '$selected', color: Colors.blueAccent, icon: Icons.check_circle, isDark: isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBadge(label: 'Erkek', value: '$male', color: Colors.indigoAccent, icon: Icons.male_rounded, isDark: isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBadge(label: 'Kız', value: '$female', color: Colors.pinkAccent, icon: Icons.female_rounded, isDark: isDark),
        ),
      ],
    );
  }

  Widget _buildStudentListHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Öğrenci Listesi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _toggleSelectAll(true),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tümünü Seç'),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_rounded, color: AppColors.primary),
              onPressed: () {
                setState(() {
                  _draftStudents.insert(
                    0,
                    _EditableStudentDraft(
                      schoolNumber: 100 + _draftStudents.length,
                      firstName: 'Yeni',
                      lastName: 'Öğrenci',
                      gender: 'Erkek',
                      isSelected: true,
                    ),
                  );
                });
              },
              tooltip: 'Elle Öğrenci Ekle',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentList(bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _draftStudents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final draft = _draftStudents[index];
        final isLocked = draft.isAlreadyRegistered;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLocked
                  ? Colors.orange.withValues(alpha: 0.3)
                  : draft.isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : (isDark ? Colors.white12 : Colors.black12),
              width: draft.isSelected && !isLocked ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (draft.isSelected && !isLocked)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Seçim veya Kilit
                if (isLocked)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.lock_rounded, color: Colors.orange, size: 24),
                  )
                else
                  Checkbox(
                    value: draft.isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onChanged: (val) {
                      setState(() => draft.isSelected = val ?? true);
                    },
                  ),

                // Bilgiler
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Okul No
                          Container(
                            width: 50,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black12 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: TextEditingController(text: '${draft.schoolNumber}'),
                              enabled: !isLocked,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                              onChanged: (v) => draft.schoolNumber = int.tryParse(v) ?? draft.schoolNumber,
                            ),
                          ),
                          // Ad
                          Expanded(
                            flex: 3,
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black12 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                controller: TextEditingController(text: draft.firstName),
                                enabled: !isLocked,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  hintText: 'Ad',
                                ),
                                onChanged: (v) => draft.firstName = v,
                              ),
                            ),
                          ),
                          // Soyad
                          Expanded(
                            flex: 3,
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black12 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                controller: TextEditingController(text: draft.lastName),
                                enabled: !isLocked,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  hintText: 'Soyad',
                                ),
                                onChanged: (v) => draft.lastName = v,
                              ),
                            ),
                          ),
                          
                          // Cinsiyet veya Kayıtlı Badge
                          if (isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Kayıtlı', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                            )
                          else
                            GestureDetector(
                              onTap: () => setState(() => draft.gender = draft.gender == 'Erkek' ? 'Kız' : 'Erkek'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: draft.gender == 'Erkek' ? Colors.indigo.withValues(alpha: 0.15) : Colors.pink.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  draft.gender == 'Erkek' ? 'E' : 'K',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: draft.gender == 'Erkek' ? Colors.indigoAccent : Colors.pinkAccent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sürükle Bırak Hissiyatlı Zarif Yükleme Kartı
class _CompactUploadCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isDark;

  const _CompactUploadCard({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// İstatistik Rozeti
class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableStudentDraft {
  int schoolNumber;
  String firstName;
  String lastName;
  String gender;
  bool isSelected;
  bool isAlreadyRegistered = false;

  _EditableStudentDraft({
    required this.schoolNumber,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.isSelected = true,
  });
}
