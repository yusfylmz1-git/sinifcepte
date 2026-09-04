import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/student_model.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../providers/class_provider.dart';
import '../../providers/student_provider.dart';
import '../../data/services/pdf_student_parser.dart';
import '../../data/services/student_file_importer.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';

/// SınıfCepte - Akıllı Öğrenci İçe Aktarma ve Önizleme Ekranı (PDF + Excel)
/// Profesyonel (UI-UX MAX) Tasarım
class StudentImportPreviewView extends ConsumerStatefulWidget {
  final int? initialClassId;
  final String? initialClassName;
  final List<ParsedStudentItem>? initialParsedStudents;
  final String? initialDetectedClassName;
  final bool initialIsMultiClass;
  final List<String> initialDistinctClasses;
  final bool autoPickPdf;

  const StudentImportPreviewView({
    super.key,
    this.initialClassId,
    this.initialClassName,
    this.initialParsedStudents,
    this.initialDetectedClassName,
    this.initialIsMultiClass = false,
    this.initialDistinctClasses = const [],
    this.autoPickPdf = false,
  });

  @override
  ConsumerState<StudentImportPreviewView> createState() => _StudentImportPreviewViewState();
}

class _StudentImportPreviewViewState extends ConsumerState<StudentImportPreviewView> {
  /// Yeni sınıflar için ders adı: öğretmenin branşı.
  ///
  /// Sabit 'Genel Ders' yazılıyordu ve bu her ekranda görünüyordu
  /// (sınıf kartı, ders programı, katılım başlığı). Öğretmen Matematik
  /// öğretmeniyse sınıfın dersi de Matematik olmalı.
  String get _defaultSubject {
    final brans = ref.read(teacherProfileProvider).branch.trim();
    return brans.isNotEmpty ? brans : 'Genel Ders';
  }

  int? _selectedClassId;
  List<_EditableStudentDraft> _draftStudents = [];
  bool _isImporting = false;
  String _detectedClassName = '';
  bool _isCreatingNewClass = false;
  final TextEditingController _newClassNameController = TextEditingController();

  // Çoklu Sınıf Belgesi Desteği (Taşımalı / Kurs / Kulüp Listeleri)
  bool _isMultiClass = false;
  List<String> _distinctClasses = [];
  String? _selectedFilterClass; // null = Tümü

  String? _bannerMessage;
  bool _bannerIsError = false;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    if (widget.initialClassName != null && widget.initialClassName!.isNotEmpty) {
      _newClassNameController.text = widget.initialClassName!;
    }
    if (widget.initialParsedStudents != null && widget.initialParsedStudents!.isNotEmpty) {
      _processResult(
        true,
        widget.initialParsedStudents!,
        null,
        isPdf: true,
        detectedClassName: widget.initialDetectedClassName,
        isMultiClass: widget.initialIsMultiClass,
        distinctClasses: widget.initialDistinctClasses,
      );
    } else if (widget.autoPickPdf) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleFilePick();
        }
      });
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _newClassNameController.dispose();
    super.dispose();
  }

  String _normalizeClassName(String name) {
    return InputSanitizer.cleanClassName(name);
  }

  List<_EditableStudentDraft> get _displayedStudents {
    if (_selectedFilterClass == null) return _draftStudents;
    return _draftStudents.where((d) => d.className == _selectedFilterClass).toList();
  }

  Future<void> _checkDuplicatesAgainstExisting(List<_EditableStudentDraft> drafts) async {
    if (_isMultiClass) {
      final classRepo = ref.read(classRepositoryProvider);
      final studentRepo = ref.read(studentRepositoryProvider);
      final existingClasses = await classRepo.getAllClasses();
      final existingClassMap = <String, ClassModel>{};
      for (var c in existingClasses) {
        existingClassMap[_normalizeClassName(c.name)] = c;
      }

      final Map<int, Set<int>> classStudentNumbers = {};

      for (var draft in drafts) {
        if (draft.className != null && draft.className!.isNotEmpty) {
          final normalized = _normalizeClassName(draft.className!);
          if (existingClassMap.containsKey(normalized)) {
            final targetClass = existingClassMap[normalized]!;
            if (!classStudentNumbers.containsKey(targetClass.id)) {
              final studentsInClass = await studentRepo.getStudentsByClassId(targetClass.id!);
              classStudentNumbers[targetClass.id!] = studentsInClass.map((s) => s.schoolNumber).toSet();
            }
            if (classStudentNumbers[targetClass.id!]!.contains(draft.schoolNumber)) {
              draft.isAlreadyRegistered = true;
              draft.isSelected = false;
              continue;
            }
          }
        }
        draft.isAlreadyRegistered = false;
      }

      if (mounted) setState(() {});
    } else if (_selectedClassId != null && !_isCreatingNewClass) {
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
    } else {
      if (mounted) {
        setState(() {
          for (var draft in drafts) {
            draft.isAlreadyRegistered = false;
          }
        });
      }
    }
  }

  /// Dosya seçtirir ve içe aktarır.
  ///
  /// Tek seçici hem PDF hem Excel kabul eder; biçim uzantıdan anlaşılır.
  /// Öğretmen e-Okul'dan hangi biçimde indirdiyse onu kullanabilir.
  Future<void> _handleFilePick() async {
    setState(() => _isImporting = true);
    try {
      final result =
          await StudentFileImporter.pickAndParse(_selectedClassId ?? 0);
      _processResult(
        result.success,
        result.parsedStudents,
        result.errorMessage,
        isPdf: result.format != StudentFileFormat.excel,
        detectedClassName: result.detectedClassName,
        isMultiClass: result.isMultiClass,
        distinctClasses: result.distinctClasses,
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _processResult(
    bool success,
    List<ParsedStudentItem> parsedStudents,
    String? errorMessage, {
    required bool isPdf,
    String? detectedClassName,
    bool isMultiClass = false,
    List<String> distinctClasses = const [],
  }) {
    if (success) {
      _isMultiClass = isMultiClass;
      _distinctClasses = distinctClasses;
      _selectedFilterClass = null;

      final drafts = parsedStudents
          .map((s) => _EditableStudentDraft(
                schoolNumber: s.schoolNumber,
                firstName: s.firstName,
                lastName: s.lastName,
                gender: s.gender,
                className: s.className,
                isSelected: true,
              ))
          .toList();

      // Tek Sınıf Belgesi İse: Otomatik Eşleştirme / Yeni Sınıf Tespiti
      if (!_isMultiClass && detectedClassName != null && detectedClassName.trim().isNotEmpty) {
        _detectedClassName = detectedClassName.trim();
        final availableClasses = ref.read(classListProvider).valueOrNull ?? [];
        final normalizedDetected = _normalizeClassName(_detectedClassName);

        final matchingClass = availableClasses.where((c) {
          return _normalizeClassName(c.name) == normalizedDetected;
        }).firstOrNull;

        if (matchingClass != null) {
          _selectedClassId = matchingClass.id;
          _isCreatingNewClass = false;
          _newClassNameController.text = matchingClass.name;
        } else {
          _selectedClassId = null;
          _isCreatingNewClass = true;
          _newClassNameController.text = _detectedClassName;
        }
      }

      _checkDuplicatesAgainstExisting(drafts);

      setState(() {
        _draftStudents = drafts;
      });

      if (mounted) {
        if (_isMultiClass) {
          _showModernSnackBar(
            '${parsedStudents.length} öğrenci ve ${_distinctClasses.length} farklı sınıf tespit edildi! (Taşımalı / Çoklu Liste) 🎯',
            isError: false,
          );
        } else if (_isCreatingNewClass && _detectedClassName.isNotEmpty) {
          _showModernSnackBar(
            '${parsedStudents.length} öğrenci okundu. "$_detectedClassName" yeni sınıf olarak oluşturulacak! ✨',
            isError: false,
          );
        } else if (_selectedClassId != null && _detectedClassName.isNotEmpty) {
          _showModernSnackBar(
            '${parsedStudents.length} öğrenci okundu. Mevcut "$_detectedClassName" sınıfı ile eşleşti! 🎯',
            isError: false,
          );
        } else {
          _showModernSnackBar(
            '${parsedStudents.length} öğrenci başarıyla okundu! 🎉',
            isError: false,
          );
        }
      }
    } else if (errorMessage != null &&
        !errorMessage.contains('seçilmedi') &&
        !errorMessage.contains('iptal') &&
        mounted) {
      _showModernSnackBar(errorMessage, isError: true);
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerMessage = message;
      _bannerIsError = isError;
    });
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _bannerMessage = null);
    });
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    if (_bannerMessage == null) return;
    setState(() => _bannerMessage = null);
  }

  Future<void> _handleSaveToDatabase() async {
    final selectedDrafts = _draftStudents.where((d) => d.isSelected && !d.isAlreadyRegistered).toList();
    if (selectedDrafts.isEmpty) {
      _showModernSnackBar('Kaydedilecek en az 1 öğrenci seçmelisiniz!', isError: true);
      return;
    }

    // 1. Çoklu Sınıf Otomatik Dağıtım Akışı
    if (_isMultiClass) {
      setState(() => _isImporting = true);
      try {
        final classRepo = ref.read(classRepositoryProvider);
        final studentRepo = ref.read(studentRepositoryProvider);
        final existingClasses = await classRepo.getAllClasses();
        final existingClassMap = <String, ClassModel>{};
        for (var c in existingClasses) {
          existingClassMap[_normalizeClassName(c.name)] = c;
        }

        // Sınıflara göre grupla
        final Map<String, List<_EditableStudentDraft>> groupedByClass = {};
        for (var draft in selectedDrafts) {
          final clsName = (draft.className != null && draft.className!.isNotEmpty)
              ? draft.className!
              : 'Genel Sınıf';
          groupedByClass.putIfAbsent(clsName, () => []).add(draft);
        }

        int createdClassCount = 0;
        int savedStudentCount = 0;

        for (var entry in groupedByClass.entries) {
          final className = entry.key;
          final drafts = entry.value;
          final normalized = _normalizeClassName(className);

          int targetId;
          if (existingClassMap.containsKey(normalized)) {
            targetId = existingClassMap[normalized]!.id!;
          } else {
            // Yeni Sınıf Aç
            targetId = await classRepo.insertClass(
              ClassModel(
                name: className,
                subject: _defaultSubject,
                academicYear: '${DateTime.now().year}-${DateTime.now().year + 1}',
                isHomeroom: false,
              ),
            );
            createdClassCount++;
          }

          final studentModels = drafts.map((d) => StudentModel(
            classId: targetId,
            schoolNumber: d.schoolNumber,
            firstName: d.firstName,
            lastName: d.lastName,
            gender: d.gender,
          )).toList();

          await studentRepo.insertStudentsBatch(studentModels);
          savedStudentCount += studentModels.length;
          ref.invalidate(studentListProvider(targetId));
        }

        ref.invalidate(classListProvider);

        if (mounted) {
          _showModernSnackBar(
            createdClassCount > 0
                ? '🎉 $savedStudentCount öğrenci ${groupedByClass.length} farklı sınıfa dağıtıldı ($createdClassCount yeni sınıf açıldı)!'
                : '🎉 $savedStudentCount öğrenci ${groupedByClass.length} farklı sınıfa başarıyla dağıtıldı ve kaydedildi!',
          );
          Navigator.pop(context);
        }
      } catch (e, st) {
        debugPrint('Multi-Class Save Error: $e\n$st');
        if (mounted) {
          _showModernSnackBar('Kayıt esnasında bir hata oluştu: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isImporting = false);
      }
      return;
    }

    // 2. Tek Sınıf Kayıt Akışı
    final seenInSelection = <int>{};
    final internalDuplicates = <int>{};
    for (final draft in selectedDrafts) {
      if (!seenInSelection.add(draft.schoolNumber)) {
        internalDuplicates.add(draft.schoolNumber);
      }
    }
    if (internalDuplicates.isNotEmpty) {
      _showModernSnackBar(
        'Seçili listede aynı okul numarasına sahip birden fazla öğrenci var: #${internalDuplicates.join(", #")}. Lütfen mükerrer numaraları düzeltin.',
        isError: true,
      );
      return;
    }

    int targetClassId;
    String targetClassName = '';

    setState(() => _isImporting = true);

    try {
      if (_isCreatingNewClass) {
        final newName = _newClassNameController.text.trim();
        if (newName.isEmpty) {
          _showModernSnackBar('Lütfen oluşturulacak sınıf için bir ad giriniz!', isError: true);
          setState(() => _isImporting = false);
          return;
        }

        // Yeni Sınıfı Atomik Olarak Oluştur
        final classRepo = ref.read(classRepositoryProvider);
        final newClassId = await classRepo.insertClass(
          ClassModel(
            name: newName,
            subject: _defaultSubject,
            academicYear: '${DateTime.now().year}-${DateTime.now().year + 1}',
            isHomeroom: false,
          ),
        );
        targetClassId = newClassId;
        targetClassName = newName;
      } else {
        if (_selectedClassId == null) {
          _showModernSnackBar('Lütfen listeden mevcut bir sınıf seçin veya "Yeni Sınıf Aç" seçeneğini kullanın!', isError: true);
          setState(() => _isImporting = false);
          return;
        }
        targetClassId = _selectedClassId!;
        final available = ref.read(classListProvider).valueOrNull ?? [];
        final matched = available.where((c) => c.id == targetClassId).firstOrNull;
        targetClassName = matched?.name ?? 'Sınıf';

        // Mevcut sınıfta mükerrerlik kontrolü
        final repository = ref.read(studentRepositoryProvider);
        final existingStudents = await repository.getStudentsByClassId(targetClassId);
        final existingNumbers = existingStudents.map((s) => s.schoolNumber).toSet();

        final duplicateDrafts = selectedDrafts.where((d) => existingNumbers.contains(d.schoolNumber)).toList();
        if (duplicateDrafts.isNotEmpty) {
          _showModernSnackBar(
            'Seçili öğrenciler arasında bu sınıfa zaten kayıtlı olanlar var! Lütfen listedeki turuncu uyarıları kontrol edin.',
            isError: true,
          );
          setState(() {
            for (var draft in _draftStudents) {
              if (existingNumbers.contains(draft.schoolNumber)) {
                draft.isAlreadyRegistered = true;
                draft.isSelected = false;
              }
            }
            _isImporting = false;
          });
          return;
        }
      }

      final repository = ref.read(studentRepositoryProvider);
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
      ref.invalidate(classListProvider);
      ref.invalidate(studentListProvider(targetClassId));

      if (mounted) {
        _showModernSnackBar(
          _isCreatingNewClass
              ? '"$targetClassName" sınıfı oluşturuldu ve ${studentModels.length} öğrenci başarıyla eklendi! 🎯'
              : '${studentModels.length} öğrenci "$targetClassName" sınıfına başarıyla eklendi! 🎯',
        );
        Navigator.pop(context);
      }
    } catch (e, st) {
      debugPrint('Save Batch Error: $e\n$st');
      if (mounted) {
        _showModernSnackBar('Kayıt esnasında bir hata oluştu: $e', isError: true);
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
        title: const Text('Öğrenci İçe Aktarma', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Farklı Dosya Seç',
            onPressed: _isImporting ? null : _handleFilePick,
          ),
        ],
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
              padding: EdgeInsets.fromLTRB(
                20,
                _bannerMessage != null ? 92 : 20,
                20,
                120,
              ),
              children: [
                _buildClassSelection(isDark, availableClasses),
                if (_draftStudents.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildStatsRow(isDark, selectedCount, maleCount, femaleCount),
                  const SizedBox(height: 24),
                  _buildStudentListHeader(isDark),
                  const SizedBox(height: 12),
                  _buildStudentList(isDark),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, size: 64, color: isDark ? Colors.white30 : Colors.black26),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz bir dosya seçilmedi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isImporting ? null : _handleFilePick,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Dosya Seç (PDF veya Excel)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_bannerMessage != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
              left: 16,
              right: 16,
              child: Material(
                color: _bannerIsError ? Colors.redAccent : Colors.green.shade600,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                  child: Row(
                    children: [
                      Icon(
                        _bannerIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _bannerMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _dismissBanner,
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Kapat',
                      ),
                    ],
                  ),
                ),
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
                    padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 16),
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
                              _isMultiClass
                                  ? 'SEÇİLEN ($selectedCount) ÖĞRENCİYİ ŞUBELERİNE DAĞIT VE KAYDET'
                                  : 'SEÇİLEN ($selectedCount) ÖĞRENCİYİ KAYDET',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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

  Widget _buildClassSelection(bool isDark, List<ClassModel> availableClasses) {
    if (_isMultiClass) {
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
                    color: Colors.deepPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Colors.deepPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Çoklu Sınıf Dağıtımı (${_distinctClasses.length} Şube)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Bu listedeki her öğrenci kendi sınıfına (${_distinctClasses.join(', ')}) otomatik dağıtılacaktır. Sistemde henüz açılmamış sınıflar anında oluşturulur.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('Tümü (${_draftStudents.length})'),
                    selected: _selectedFilterClass == null,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilterClass = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._distinctClasses.map((cls) {
                    final count = _draftStudents.where((d) => d.className == cls).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$cls ($count)'),
                        selected: _selectedFilterClass == cls,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (val) {
                          setState(() => _selectedFilterClass = val ? cls : null);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
              Expanded(
                child: Text(
                  'Hedef Sınıf',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Algılanan Sınıf Rozeti (Varsa)
          if (_detectedClassName.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isCreatingNewClass
                    ? Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1)
                    : Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCreatingNewClass
                      ? Colors.amber.withValues(alpha: 0.5)
                      : Colors.green.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCreatingNewClass ? Icons.auto_awesome_rounded : Icons.check_circle_rounded,
                    size: 20,
                    color: _isCreatingNewClass ? Colors.amber.shade700 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isCreatingNewClass
                          ? 'Belgeden "$_detectedClassName" sınıfı algılandı (Yeni Sınıf Olarak Açılacak)'
                          : 'Belgeden "$_detectedClassName" algılandı ve mevcut sınıf ile eşleşti',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Mevcut Sınıf / Yeni Sınıf Seçim Çipleri
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_rounded, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Mevcut Sınıf',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  selected: !_isCreatingNewClass,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isCreatingNewClass = false;
                        _checkDuplicatesAgainstExisting(_draftStudents);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Yeni Sınıf Aç',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  selected: _isCreatingNewClass,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isCreatingNewClass = true;
                        _checkDuplicatesAgainstExisting(_draftStudents);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isCreatingNewClass)
            TextFormField(
              controller: _newClassNameController,
              decoration: InputDecoration(
                labelText: 'Yeni Sınıf Adı',
                hintText: 'Örn: 5-A',
                prefixIcon: const Icon(Icons.class_rounded, color: AppColors.primary),
                helperText: '✨ Kaydet butonuna basıldığında bu sınıf otomatik oluşturulacaktır.',
                helperStyle: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                setState(() {});
              },
            )
          else
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
              _selectedFilterClass != null ? '$_selectedFilterClass Öğrencileri' : 'Öğrenci Listesi',
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
                      className: _selectedFilterClass,
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
    final displayed = _displayedStudents;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayed.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final draft = displayed[index];
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
                          // Sınıf Rozeti (Çoklu liste ise)
                          if (draft.className != null && draft.className!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                draft.className!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            
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
  String? className;
  bool isSelected;
  bool isAlreadyRegistered = false;

  _EditableStudentDraft({
    required this.schoolNumber,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.className,
    this.isSelected = true,
  });
}
