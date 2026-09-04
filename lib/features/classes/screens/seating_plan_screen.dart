import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/models/class_model.dart';
import '../models/seating_plan_model.dart';
import '../providers/student_provider.dart';
import '../providers/seating_plan_provider.dart';
import '../utils/seating_plan_pdf_generator.dart';
import '../../../core/utils/turkish_text.dart';

/// SınıfCepte - Mobil Uyumlu Gerçekçi Sınıf Oturma Planı Ekranı (Sıfır Overflow Garantili)
class SeatingPlanScreen extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const SeatingPlanScreen({super.key, required this.classModel});

  @override
  ConsumerState<SeatingPlanScreen> createState() => _SeatingPlanScreenState();
}

class _SeatingPlanScreenState extends ConsumerState<SeatingPlanScreen> {
  int? _selectedStudentForSwap;
  bool _hasEnsuredCapacity = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studentsAsync = ref.watch(studentListProvider(widget.classModel.id!));
    final planAsync = ref.watch(seatingPlanProvider(widget.classModel.id!));

    final students = studentsAsync.valueOrNull ?? [];
    final plan = planAsync.valueOrNull;

    // Öğrenci sayısına göre satır sayısını otomatik garanti et (İlk yüklemede)
    // ve sınıftan silinmiş öğrencilerin koltuklarını boşalt.
    if (students.isNotEmpty && plan != null && !_hasEnsuredCapacity) {
      _hasEnsuredCapacity = true;
      final notifier =
          ref.read(seatingPlanProvider(widget.classModel.id!).notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await notifier.pruneMissingStudents(
          students.map((s) => s.id).whereType<int>(),
        );
        await notifier.ensureCapacityForStudents(students.length);
      });
    }

    final assignedCount = plan?.assignments.length ?? 0;
    final totalSeats = (plan != null) ? (plan.columns * plan.rows * 2) : 30;
    final currentBlocks = plan?.columns ?? 3;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.classModel.name} Oturma Planı',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              'Yerleşen: $assignedCount/${students.length} • Kapasite: $totalSeats ($currentBlocks Blok)',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          // 1. Sihirli Otomatik Dağıtım Menüsü
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primary),
            tooltip: 'Sihirli Otomatik Dağıt',
            onSelected: (value) => _handleMagicAction(value, students),
            itemBuilder: (context) => [
              _buildPopupMenuItem('random', '🎲 Rastgele Dağıt', 'Tüm sınıfı sıralara otomatik yerleştirir'),
              _buildPopupMenuItem('gender', '👫 Kız - Erkek Dengeli Dağıt', 'Yan yana bir kız bir erkek oturtur'),
              _buildPopupMenuItem('number', '🔢 Okul Numarasına Göre Dağıt', '1. sıradan başlayarak dizer'),
              _buildPopupMenuItem('alpha', '🔤 Alfabetik Sıraya Göre Dağıt', 'İsim sırasına göre yerleştirir'),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Tümünü Temizle', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),

          // 2. Sınıf Sıra Blok Düzeni Seçimi (2'li, 3'lü, 4'lü Blok)
          PopupMenuButton<int>(
            icon: const Icon(Icons.view_column_rounded),
            tooltip: 'Sınıf Blok Düzeni',
            onSelected: (blocks) {
              ref.read(seatingPlanProvider(widget.classModel.id!).notifier).updateBlocksLayout(blocks, students.length);
              _showSuccessSnack('$blocks Sıra Grubu Düzenine Geçildi!');
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Icons.looks_two_rounded, color: currentBlocks == 2 ? AppColors.primary : Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '2 Sıra Grubu (Pencere - Kapı)',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Icon(Icons.looks_3_rounded, color: currentBlocks == 3 ? AppColors.primary : Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '3 Sıra Grubu (Pencere - Orta - Kapı)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 4,
                child: Row(
                  children: [
                    Icon(Icons.looks_4_rounded, color: currentBlocks == 4 ? AppColors.primary : Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '4 Sıra Grubu (Geniş Sınıflar)',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 3. PDF ve WhatsApp Paylaşım Butonu
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            tooltip: 'A4 PDF Krokisi Oluştur & Paylaş',
            onPressed: (students.isEmpty || plan == null)
                ? null
                : () async {
                    await SeatingPlanPdfGenerator.generateAndShare(
                      context: context,
                      classModel: widget.classModel,
                      students: students,
                      plan: plan,
                    );
                  },
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (loadedStudents) {
          return planAsync.when(
            data: (loadedPlan) {
              return Column(
                children: [
                  // Takas Modu Aktifse Bilgi Çubuğu
                  if (_selectedStudentForSwap != null)
                    _buildSwapNotificationBar(loadedStudents, isDark),

                  // Sınıf Ön Krokisi: Yazı Tahtası, Kürsü, Pencereler, Kapı
                  _buildClassroomFront(isDark),

                  // Ana Sınıf Sıraları (Mobil Kaydırılabilir Alan)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        children: [
                          _buildClassroomRows(
                            context: context,
                            allStudents: loadedStudents,
                            plan: loadedPlan,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),

                          // Manuel Sıra Ekle / Kaldır Aksiyon Butonları
                          _buildRowControls(loadedPlan, isDark),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, st) => Center(child: Text('Hata: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, st) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, String title, String desc) {
    return PopupMenuItem(
      value: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(desc, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ],
      ),
    );
  }

  /// Sihirli Dağıtım İşlemleri
  void _handleMagicAction(String action, List<StudentModel> students) {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem için sınıfta en az 1 öğrenci bulunmalıdır.')),
      );
      return;
    }

    final notifier = ref.read(seatingPlanProvider(widget.classModel.id!).notifier);

    switch (action) {
      case 'random':
        notifier.autoAssignRandom(students);
        _showSuccessSnack('🎲 Tüm sınıf sıralara otomatik yerleştirildi!');
        break;
      case 'gender':
        notifier.autoAssignGenderBalanced(students);
        _showSuccessSnack('👫 Kız ve erkek öğrenciler dengeli yerleştirildi!');
        break;
      case 'number':
        notifier.autoAssignByNumber(students);
        _showSuccessSnack('🔢 Öğrenciler okul numarasına göre sıralandı!');
        break;
      case 'alpha':
        notifier.autoAssignAlphabetical(students);
        _showSuccessSnack('🔤 Öğrenciler alfabetik isim sırasına göre yerleştirildi!');
        break;
      case 'clear':
        notifier.clearAllAssignments();
        setState(() => _selectedStudentForSwap = null);
        _showSuccessSnack('🧹 Tüm oturma planı sıfırlandı.');
        break;
    }
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// Takas Uyarı Barı
  Widget _buildSwapNotificationBar(List<StudentModel> allStudents, bool isDark) {
    final student = allStudents.firstWhere((s) => s.id == _selectedStudentForSwap, orElse: () => allStudents.first);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.amber.shade700,
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${student.fullName} için hedef masaya dokunun.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedStudentForSwap = null),
            style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
            child: const Text('İPTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Sınıf Ön Bölgesi (Tahta, Kürsü, Kapı, Pencereler - Sıfır Overflow Garantili)
  Widget _buildClassroomFront(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Sol: Pencere
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.window_rounded, size: 14, color: Colors.cyan.shade600),
                const SizedBox(width: 4),
                Text(
                  'Pencere Kenarı',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan.shade700),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Kürsü
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.brown.shade400,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Öğretmen Masası',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Yazı Tahtası
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A2F),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.brown.shade600, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded, color: Colors.white70, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'YAZI TAHTASI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Sağ: Kapı
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kapı Kenarı',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 4),
                Icon(Icons.door_front_door_outlined, size: 14, color: Colors.orange.shade600),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sınıf Sıra Blokları (2, 3 veya 4 Kolon)
  Widget _buildClassroomRows({
    required BuildContext context,
    required List<StudentModel> allStudents,
    required SeatingPlanModel plan,
    required bool isDark,
  }) {
    final blocks = plan.columns;
    final rows = plan.rows;

    List<String> blockTitles;
    if (blocks == 2) {
      blockTitles = ['Pencere', 'Kapı'];
    } else if (blocks == 4) {
      blockTitles = ['Pencere', 'Orta 1', 'Orta 2', 'Kapı'];
    } else {
      blockTitles = ['Pencere', 'Orta Sıra', 'Kapı'];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(blocks, (blockIndex) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: blockIndex < blocks - 1 ? 6 : 0,
            ),
            child: Column(
              children: [
                // Blok Başlığı
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      blockTitles[blockIndex],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Sıralar
                ...List.generate(rows, (rowIndex) {
                  return _buildDualDesk(
                    context: context,
                    blockIndex: blockIndex,
                    rowIndex: rowIndex,
                    allStudents: allStudents,
                    assignments: plan.assignments,
                    isDark: isDark,
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// 2'li Sıra (Çift Koltuklu Masa)
  Widget _buildDualDesk({
    required BuildContext context,
    required int blockIndex,
    required int rowIndex,
    required List<StudentModel> allStudents,
    required Map<int, String> assignments,
    required bool isDark,
  }) {
    final leftPos = '$blockIndex,$rowIndex,0';
    final rightPos = '$blockIndex,$rowIndex,1';

    final leftStudent = _getStudentAtPos(leftPos, allStudents, assignments);
    final rightStudent = _getStudentAtPos(rightPos, allStudents, assignments);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Masa No
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 2),
            child: Text(
              '${rowIndex + 1}. Sıra',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ),

          // Sol ve Sağ Koltuklar
          Row(
            children: [
              Expanded(
                child: _buildSeatSlot(
                  context: context,
                  student: leftStudent,
                  block: blockIndex,
                  row: rowIndex,
                  seat: 0,
                  allStudents: allStudents,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildSeatSlot(
                  context: context,
                  student: rightStudent,
                  block: blockIndex,
                  row: rowIndex,
                  seat: 1,
                  allStudents: allStudents,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  StudentModel? _getStudentAtPos(String pos, List<StudentModel> all, Map<int, String> assignments) {
    for (var entry in assignments.entries) {
      if (entry.value == pos) {
        return all.where((s) => s.id == entry.key).firstOrNull;
      }
    }
    return null;
  }

  /// Tekil Koltuk (SIFIR OVERFLOW: FittedBox ile metinler dar ekranda güvenle sığar)
  Widget _buildSeatSlot({
    required BuildContext context,
    required StudentModel? student,
    required int block,
    required int row,
    required int seat,
    required List<StudentModel> allStudents,
    required bool isDark,
  }) {
    final isSelectedForSwap = student != null && student.id == _selectedStudentForSwap;

    return DragTarget<int>(
      onAcceptWithDetails: (details) {
        ref.read(seatingPlanProvider(widget.classModel.id!).notifier).assignSeat(details.data, block, row, seat);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        if (student != null) {
          // DOLU KOLTUK
          final isGirl = student.gender.toLowerCase().contains('kız');
          final bgColor = isGirl ? const Color(0xFFEC4899) : const Color(0xFF2563EB);

          final cardContent = Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: isSelectedForSwap ? Colors.amber.shade600 : (isHovered ? bgColor.withValues(alpha: 0.8) : bgColor),
              borderRadius: BorderRadius.circular(6),
              border: isSelectedForSwap ? Border.all(color: Colors.white, width: 2) : null,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.25),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    student.schoolNumber > 0 ? 'No: ${student.schoolNumber}' : 'Öğrenci',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${student.firstName} ${student.lastName.isNotEmpty ? "${student.lastName[0]}." : ""}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          return Draggable<int>(
            data: student.id,
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.85,
                child: SizedBox(width: 70, height: 44, child: cardContent),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
            child: InkWell(
              onTap: () {
                if (_selectedStudentForSwap != null) {
                  ref.read(seatingPlanProvider(widget.classModel.id!).notifier).swapStudents(_selectedStudentForSwap!, student.id!);
                  setState(() => _selectedStudentForSwap = null);
                  _showSuccessSnack('Öğrencilerin yerleri değiştirildi! 🔄');
                } else {
                  _showStudentSeatActions(context, student, block, row, seat);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: cardContent,
            ),
          );
        } else {
          // BOŞ KOLTUK
          return InkWell(
            onTap: () {
              if (_selectedStudentForSwap != null) {
                ref.read(seatingPlanProvider(widget.classModel.id!).notifier).assignSeat(_selectedStudentForSwap!, block, row, seat);
                setState(() => _selectedStudentForSwap = null);
                _showSuccessSnack('Öğrenci boş sıraya taşındı!');
              } else {
                _openStudentPickerModal(context, allStudents, block, row, seat);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isHovered
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isHovered ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey.shade300),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade500),
                    Text(
                      'Seç',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  /// Sıra Ekle / Kaldır Kontrol Butonları
  Widget _buildRowControls(SeatingPlanModel plan, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: plan.rows > 3
              ? () {
                  ref.read(seatingPlanProvider(widget.classModel.id!).notifier).removeRow();
                  _showSuccessSnack('Bir sıra kaldırıldı.');
                }
              : null,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
          label: const Text('Sıra Kaldır', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(seatingPlanProvider(widget.classModel.id!).notifier).addRow();
            _showSuccessSnack('Yeni sıra eklendi!');
          },
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
          label: const Text('Sıra Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  /// Masada oturan öğrenci için eylemler
  void _showStudentSeatActions(BuildContext context, StudentModel student, int block, int row, int seat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: student.gender.toLowerCase().contains('kız') ? Colors.pinkAccent : Colors.blueAccent,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'No: ${student.schoolNumber} • ${student.gender} • ${row + 1}. Sıra',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: Colors.amber),
                title: const Text('Başka Sırayla Yer Değiştir (Takas)'),
                subtitle: const Text('Bu öğrenciyi seçer ve dokunacağınız sırayla takas eder'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedStudentForSwap = student.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${student.fullName} seçildi. Şimdi hedef masaya dokunun.'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                title: const Text('Masadan Kaldır (Havuza Gönder)'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(seatingPlanProvider(widget.classModel.id!).notifier).removeStudent(student.id!);
                  _showSuccessSnack('${student.fullName} masadan kaldırıldı.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Boş koltuk için Öğrenci Seçici Modal
  void _openStudentPickerModal(
    BuildContext context,
    List<StudentModel> allStudents,
    int block,
    int row,
    int seat,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = ref.read(seatingPlanProvider(widget.classModel.id!)).value;
    final unassigned = allStudents.where((s) => plan == null || !plan.assignments.containsKey(s.id)).toList();

    if (unassigned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm öğrenciler zaten sıralara yerleştirildi!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = unassigned.where((s) {
              // `toLowerCase` Turkce'de yaniltiyordu: ogretmen Turkce
              // karakter yazmadan aradiginda sonuc bulunamiyordu.
              return trContains(s.fullName, query) ||
                  s.schoolNumber.toString().contains(query.trim());
            }).toList();

            return Container(
              height: MediaQuery.sizeOf(context).height * 0.65,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${row + 1}. Sıra İçin Öğrenci Seç',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Kalan: ${unassigned.length}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'İsim veya numara ile ara...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Eşleşen öğrenci bulunamadı.'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final s = filtered[index];
                              final isGirl = s.gender.toLowerCase().contains('kız');

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isGirl ? Colors.pink.shade100 : Colors.blue.shade100,
                                  child: Text(
                                    s.schoolNumber > 0 ? '${s.schoolNumber}' : s.firstName[0],
                                    style: TextStyle(
                                      color: isGirl ? Colors.pink.shade800 : Colors.blue.shade800,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                subtitle: Text('${s.gender} • No: ${s.schoolNumber}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  ref.read(seatingPlanProvider(widget.classModel.id!).notifier).assignSeat(s.id!, block, row, seat);
                                  _showSuccessSnack('${s.fullName} sıraya oturtuldu.');
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
