import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_model.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/student_provider.dart';
import '../providers/class_provider.dart';
import '../../../data/models/student_model.dart';
import '../widgets/add_student_dialog.dart';
import '../presentation/views/student_import_preview_view.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/widgets/responsive_bottom_sheet.dart';
import 'parent_contacts_screen.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../parent_portal/data/services/student_lifecycle_coordinator.dart';
import '../../parent_portal/data/services/student_lifecycle_policy.dart';
import '../../../core/utils/search_debouncer.dart';
import '../../../core/utils/turkish_text.dart';

/// Sınıf İçi Öğrenci Listesi ve Yönetim Ekranı (StudentListScreen)
class StudentListScreen extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const StudentListScreen({
    super.key,
    required this.classModel,
  });

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _searchQuery = '';

  /// Arama her tusta setState cagiriyordu; 1114 satirlik ekran
  /// saniyede onlarca kez bastan ciziliyor ve klavye takiliyordu.
  final SearchDebouncer _searchDebouncer = SearchDebouncer();
  String _sortOption = 'no_asc'; // 'no_asc', 'no_desc', 'name_asc', 'name_desc'
  final TextEditingController _searchController = TextEditingController();

  final Set<int> _selectedStudentIds = {};
  bool get _isSelectionMode => _selectedStudentIds.isNotEmpty;

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentListAsync = ref.watch(studentListProvider(widget.classModel.id!));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allStudents = studentListAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _selectedStudentIds.clear()),
              ),
              title: Text('${_selectedStudentIds.length} Seçildi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                IconButton(
                  icon: Icon(_selectedStudentIds.length == allStudents.length ? Icons.deselect_rounded : Icons.select_all_rounded),
                  tooltip: 'Tümünü Seç / Kaldır',
                  onPressed: () {
                    setState(() {
                      if (_selectedStudentIds.length == allStudents.length) {
                        _selectedStudentIds.clear();
                      } else {
                        _selectedStudentIds.addAll(allStudents.map((e) => e.id!));
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline),
                  tooltip: 'Başka Sınıfa Taşı',
                  onPressed: () => _showMoveDialog(context, _selectedStudentIds.toList()),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Sil',
                  onPressed: () => _confirmDeleteSelected(context, _selectedStudentIds.toList()),
                ),
              ],
            )
          : CustomAppBar(
              title: widget.classModel.name,
              subtitle: widget.classModel.subject.trim().isNotEmpty 
                  ? '${widget.classModel.subject} • Öğrenci Listesi'
                  : 'Öğrenci Listesi',
              actions: [
                IconButton(
                  icon: const Icon(Icons.contact_phone_rounded, color: Colors.white),
                  tooltip: 'Veli İletişim Rehberi',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ParentContactsScreen(classModel: widget.classModel),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                  tooltip: 'Yeni Öğrenci Ekle',
                  onPressed: () => _openAddStudentDialog(context),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  color: isDark ? AppColors.darkCardBackground : Colors.white,
                  onSelected: (value) {
                    if (value == 'move_all') {
                      if (allStudents.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sınıfta taşınacak öğrenci yok.')));
                        return;
                      }
                      _showMoveDialog(context, allStudents.map((e) => e.id!).toList());
                    } else if (value == 'delete_all') {
                      if (allStudents.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sınıfta silinecek öğrenci yok.')));
                        return;
                      }
                      _confirmDeleteSelected(context, allStudents.map((e) => e.id!).toList());
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'move_all',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_move_outline, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 12),
                          const Text('Tüm Sınıfı Taşı (Sınıf Atlat)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete_all',
                      child: Row(
                        children: [
                          Icon(Icons.group_remove_outlined, size: 20, color: Colors.redAccent),
                          SizedBox(width: 12),
                          Text('Tüm Öğrencileri Sil', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ) as PreferredSizeWidget,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [
              // Hızlı Aksiyon Kartları (Öğrenci Ekle & PDF İçe Aktar)
              Row(
                children: [
                  // 1. Yeni Öğrenci Ekle
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openAddStudentDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      ),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text(
                        'Öğrenci Ekle',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 2. PDF İçe Aktar
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentImportPreviewView(
                              initialClassId: widget.classModel.id,
                              initialClassName: widget.classModel.name,
                              autoPickPdf: true,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.glassBorder : Colors.grey.shade300),
                        foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFFFF512F)),
                      label: Text(
                        widget.classModel.isHomeroom ? 'PDF Yükle' : 'PDF İçe Aktar',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // İstatistik Kartları
              if (studentListAsync.valueOrNull != null && studentListAsync.valueOrNull!.isNotEmpty)
                Row(
                  children: [
                    Expanded(child: _buildStatCard(context, isDark, 'Kız', studentListAsync.valueOrNull!.where((s) => s.gender.toLowerCase().contains('kız')).length, Colors.pinkAccent, Icons.face_3_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(context, isDark, 'Erkek', studentListAsync.valueOrNull!.where((s) => s.gender.toLowerCase().contains('erkek')).length, Colors.blueAccent, Icons.face_6_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(context, isDark, 'Toplam', studentListAsync.valueOrNull!.length, AppColors.primary, Icons.groups_rounded)),
                  ],
                ),
              
              if (studentListAsync.valueOrNull != null && studentListAsync.valueOrNull!.isNotEmpty)
                const SizedBox(height: 16),

              // Arama ve Sıralama Çubuğu
              if (studentListAsync.valueOrNull != null && studentListAsync.valueOrNull!.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => _searchDebouncer.run(
                            () {
                              if (!mounted) return;
                              setState(() => _searchQuery = v);
                            },
                          ),
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'İsim veya Okul No...',
                            hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white54 : Colors.black54),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOption,
                          icon: Icon(Icons.sort_rounded, size: 20, color: isDark ? Colors.white54 : Colors.black54),
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                          dropdownColor: isDark ? AppColors.darkCardBackground : Colors.white,
                          onChanged: (v) {
                            if (v != null) setState(() => _sortOption = v);
                          },
                          items: const [
                            DropdownMenuItem(value: 'no_asc', child: Text('No (1-9)')),
                            DropdownMenuItem(value: 'name_asc', child: Text('Ad Soyad (A-Z)')),
                            DropdownMenuItem(value: 'gender', child: Text('Erkek/Kız')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              if (studentListAsync.valueOrNull != null && studentListAsync.valueOrNull!.isNotEmpty)
                const SizedBox(height: 16),

              // Öğrenci Listesi Katmanı
              Expanded(
                child: studentListAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (err, stack) => Center(
                    child: Text(
                      'Hata: $err',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  data: (students) {
                    if (students.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    var filtered = students.where((s) {
                      if (_searchQuery.isEmpty) return true;
                      // `toLowerCase` Turkce'de yaniltiyordu: ogretmen
                      // "Isil" yazinca "Isil" ogrencisi bulunamiyordu.
                      return trContains(s.fullName, _searchQuery) ||
                          s.schoolNumber.toString().contains(
                            _searchQuery.trim(),
                          );
                    }).toList();

                    filtered.sort((a, b) {
                      switch (_sortOption) {
                        case 'no_asc':
                          return a.schoolNumber.compareTo(b.schoolNumber);
                        case 'name_asc':
                          return a.fullName.compareTo(b.fullName);
                        case 'gender':
                          final genderCompare = a.gender.compareTo(b.gender);
                          if (genderCompare != 0) return genderCompare;
                          return a.schoolNumber.compareTo(b.schoolNumber);
                        default:
                          return a.schoolNumber.compareTo(b.schoolNumber);
                      }
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'Arama sonucunda öğrenci bulunamadı.',
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final student = filtered[index];

                        final isSelected = _selectedStudentIds.contains(student.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: GestureDetector(
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() => _selectedStudentIds.add(student.id!));
                              }
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedStudentIds.remove(student.id!);
                                  } else {
                                    _selectedStudentIds.add(student.id!);
                                  }
                                });
                              } else {
                                _openAddStudentDialog(context, student: student);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    // Çoklu Seçim Checkbox
                                    if (_isSelectionMode) ...[
                                      Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: isSelected ? AppColors.primary : (isDark ? Colors.white30 : Colors.black26),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Cinsiyet Profil Avatarı
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : student.gender.toLowerCase().contains('kız') 
                                            ? Colors.pink.withValues(alpha: 0.15) 
                                            : Colors.blue.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected 
                                            ? AppColors.primary.withValues(alpha: 0.5)
                                            : student.gender.toLowerCase().contains('kız') 
                                              ? Colors.pink.withValues(alpha: 0.3) 
                                              : Colors.blue.withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        student.gender.toLowerCase().contains('kız') ? Icons.face_3_rounded : Icons.face_6_rounded,
                                        color: isSelected 
                                          ? AppColors.primary 
                                          : student.gender.toLowerCase().contains('kız') ? Colors.pinkAccent : Colors.blueAccent,
                                        size: 20,
                                      ),
                                    ),
                                const SizedBox(width: 12),

                                // Okul No Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${student.schoolNumber}',
                                    style: TextStyle(
                                      color: isDark ? AppColors.primary.withValues(alpha: 0.8) : AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // İsim
                                Expanded(
                                  child: Text(
                                    student.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),

                                // 3 Nokta İşlem Menüsü (Düzenle, Sınıfı Değiştir, Sil)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    size: 20,
                                  ),
                                  tooltip: 'Öğrenci İşlemleri',
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openAddStudentDialog(context, student: student);
                                    } else if (value == 'move') {
                                      _showMoveStudentSheet(context, ref, student);
                                    } else if (value == 'delete') {
                                      _confirmDeleteStudent(context, ref, student.id!, student.fullName);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Düzenle',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'move',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Sınıfını Değiştir',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                          SizedBox(width: 10),
                                          Text(
                                            'Öğrenciyi Sil',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
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
                  },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddStudentDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_add_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Sınıfta Öğrenci Yok',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tek tek öğrenci ekleyebilir veya Excel listesinden toplu yükleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _openAddStudentDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text('Öğrenci Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddStudentDialog(BuildContext context, {student}) {
    showDialog(
      context: context,
      builder: (_) => AddStudentDialog(
        classId: widget.classModel.id!,
        student: student,
      ),
    );
  }

  /// Öğrenci ayrılmadan önce veli erişimlerini kapatır.
  ///
  /// Yalnızca cihazdaki kaydı silmek yetmiyordu: veli bağı ve sınıf
  /// erişimi bulutta ayakta kaldığı için okuldan ayrılmış öğrencinin
  /// velisi duyuruları görmeye ve öğretmene yazmaya devam edebiliyordu.
  Future<void> _closeParentAccess({
    required List<int> studentIds,
    required DepartureReason reason,
  }) async {
    final teacher = ref.read(teacherProfileProvider);
    final coordinator = ref.read(studentLifecycleCoordinatorProvider);

    var parents = 0;
    var cloudOk = true;
    for (final id in studentIds) {
      final outcome = await coordinator.handleDeparture(
        studentId: id,
        reason: reason,
        teacherUid: teacher.id,
      );
      parents += outcome.affectedParents;
      if (!outcome.cloudSynced) cloudOk = false;
    }

    if (!mounted || parents == 0) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cloudOk
              ? '$parents veli erişimi kapatıldı.'
              : '$parents veli erişimi cihazda kapatıldı, ancak buluta '
                  'ulaşılamadı. İnternet gelince tekrar deneyin.',
        ),
        backgroundColor: cloudOk ? const Color(0xFF10B981) : Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _confirmDeleteStudent(BuildContext context, WidgetRef ref, int studentId, String studentName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        title: Text(
          '$studentName Silinsin mi?',
          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
        ),
        content: Text(
          'Bu öğrenciyi sınıftan silmek istediğinize emin misiniz?',
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('İptal', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Öğrenci silinmeden ÖNCE veli erişimleri kapatılır: bağ
              // kayıtları silinen öğrencinin kimliğine dayandığı için
              // sonra çalıştırmak onları erişilemez bırakırdı.
              await _closeParentAccess(
                studentIds: [studentId],
                reason: DepartureReason.deleted,
              );
              if (!mounted) return;
              await ref
                  .read(studentListProvider(widget.classModel.id!).notifier)
                  .deleteStudent(studentId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context, List<int> selectedIds) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        title: Text('${selectedIds.length} Öğrenci Silinsin mi?', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight)),
        content: Text('Seçili öğrencileri sınıftan kalıcı olarak silmek istediğinize emin misiniz?', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('İptal', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _closeParentAccess(
                studentIds: selectedIds,
                reason: DepartureReason.deleted,
              );
              if (!mounted) return;
              await ref
                  .read(studentListProvider(widget.classModel.id!).notifier)
                  .deleteStudentsBatch(selectedIds);
              if (mounted) setState(() => _selectedStudentIds.clear());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Toplu Sil'),
          ),
        ],
      ),
    );
  }

  /// Tek bir öğrencinin sınıfını değiştirme / şubeye aktarma modalı
  void _showMoveStudentSheet(BuildContext context, WidgetRef ref, StudentModel student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentGrade = InputSanitizer.extractGradeLevel(widget.classModel.name);
    final classes = ref.read(classListProvider).valueOrNull ?? [];

    // Yalnızca aynı kademedeki (örn: 5-A ise sadece 5-B, 5-C gibi 5. sınıf) diğer şubeleri listele
    final otherClasses = classes.where((c) {
      if (c.id == widget.classModel.id) return false;
      if (currentGrade != null) {
        final targetGrade = InputSanitizer.extractGradeLevel(c.name);
        return targetGrade == currentGrade;
      }
      return true;
    }).toList();

    if (otherClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentGrade != null
                ? '$currentGrade. sınıf kademesinde aktarılabilecek başka bir şube ($currentGrade-B, $currentGrade-C vb.) bulunamadı.'
                : 'Öğrenciyi aktarabileceğiniz başka bir sınıf bulunamadı.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    int? selectedTargetClassId = otherClasses.first.id;

    ResponsiveBottomSheet.show(
      context: context,
      title: 'Öğrenci Sınıfını Değiştir',
      child: StatefulBuilder(
        builder: (ctx, setStateModal) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Öğrenci Bilgi Kartı
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Okul No: #${student.schoolNumber} • Mevcut: ${widget.classModel.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                currentGrade != null
                    ? '$currentGrade. Sınıf Şubeleri:'
                    : 'Hedef Sınıf / Şube Seçin:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Sınıf Seçenekleri
              ...otherClasses.map((c) {
                final isSelected = selectedTargetClassId == c.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setStateModal(() => selectedTargetClassId = c.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white38 : Colors.black38),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  c.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (c.isHomeroom) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Rehberlik Sınıfım',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Aktar ve Onayla Butonu
              ElevatedButton.icon(
                onPressed: selectedTargetClassId == null
                    ? null
                    : () async {
                        final targetClass = otherClasses.firstWhere((c) => c.id == selectedTargetClassId);
                        Navigator.pop(ctx);

                        final result = await ref
                            .read(studentListProvider(widget.classModel.id!).notifier)
                            .moveStudent(
                              studentId: student.id!,
                              targetClassId: selectedTargetClassId!,
                            );

                        if (context.mounted) {
                          if (result.success) {
                            ref.invalidate(studentListProvider(selectedTargetClassId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${student.fullName} başarıyla ${targetClass.name} sınıfına aktarıldı! 🚀',
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.error ?? 'Aktarım sırasında bir hata oluştu.'),
                                backgroundColor: AppColors.danger,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Sınıfı Değiştir & Aktar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Şube değişikliğinde velinin sınıf erişimini yeni şubeye taşır.
  ///
  /// Bağ koparılmaz: çocuk aynı çocuktur. Yalnızca eski şubenin duyuru
  /// erişimi kapanır, yenisi açılır.
  Future<void> _moveParentAccess({
    required List<int> studentIds,
    required int newClassId,
    required String newClassName,
  }) async {
    final teacher = ref.read(teacherProfileProvider);
    final coordinator = ref.read(studentLifecycleCoordinatorProvider);

    var parents = 0;
    var cloudOk = true;
    for (final id in studentIds) {
      final outcome = await coordinator.handleClassChange(
        studentId: id,
        oldClassId: widget.classModel.id!,
        newClassId: newClassId,
        newClassName: newClassName,
        teacherUid: teacher.id,
      );
      parents += outcome.affectedParents;
      if (!outcome.cloudSynced) cloudOk = false;
    }

    if (!mounted || parents == 0) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cloudOk
              ? '$parents velinin erişimi $newClassName sınıfına taşındı. '
                  'Yeniden kod göndermenize gerek yok.'
              : '$parents veli erişimi cihazda taşındı, ancak buluta '
                  'ulaşılamadı. İnternet gelince tekrar deneyin.',
        ),
        backgroundColor: cloudOk ? const Color(0xFF10B981) : Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showMoveDialog(BuildContext context, List<int> selectedIds) {
    final classListAsync = ref.read(classListProvider);
    final classes = classListAsync.valueOrNull ?? [];
    final availableClasses = classes.where((c) => c.id != widget.classModel.id).toList();

    if (availableClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Taşınacak başka bir sınıf bulunamadı.')));
      return;
    }

    int selectedClassId = availableClasses.first.id!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
            title: Text('Öğrencileri Taşı', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${selectedIds.length} öğrenciyi hangi sınıfa taşımak istiyorsunuz?', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedClassId,
                  items: availableClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedClassId = val);
                  },
                  dropdownColor: isDark ? AppColors.darkCardBackground : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('İptal', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final target = availableClasses
                      .firstWhere((c) => c.id == selectedClassId);
                  await ref
                      .read(studentListProvider(widget.classModel.id!).notifier)
                      .moveStudentsBatch(selectedIds, selectedClassId);
                  // Şube değişikliğinde veli bağı KORUNUR; yalnızca sınıf
                  // erişimi taşınır. Aksi hâlde her şube değişikliğinde
                  // velilere yeniden kod dağıtmak gerekirdi.
                  await _moveParentAccess(
                    studentIds: selectedIds,
                    newClassId: selectedClassId,
                    newClassName: target.name,
                  );
                  if (mounted) setState(() => _selectedStudentIds.clear());
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Taşı'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, bool isDark, String title, int count, Color color, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
