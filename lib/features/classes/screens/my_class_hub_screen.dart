import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../providers/class_provider.dart';
import '../providers/student_provider.dart';
import '../utils/classroom_documents_pdf_generator.dart';
import '../presentation/views/student_import_preview_view.dart';
import 'seating_plan_screen.dart';
import 'student_list_screen.dart';
import 'parent_contacts_screen.dart';
import '../../attendance/presentation/widgets/participation_cumulative_reports_modal.dart';

/// SınıfCepte - Sınıfım (Yönetim & Evrak Merkezi) Hub Ekranı
class MyClassHubScreen extends ConsumerStatefulWidget {
  final ClassModel? initialClass;

  const MyClassHubScreen({super.key, this.initialClass});

  @override
  ConsumerState<MyClassHubScreen> createState() => _MyClassHubScreenState();
}

class _MyClassHubScreenState extends ConsumerState<MyClassHubScreen> {
  int? _selectedClassId;
  bool _isGeneratingPdf = false;
  String _generatingDocumentName = '';

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClass?.id;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classListAsync = ref.watch(classListProvider);
    final profile = ref.watch(teacherProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F7FB),
      appBar: const CustomAppBar(
        title: 'Sınıfım',
        subtitle: 'Sınıf Yönetimi & Resmî Evrak Merkezi',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: classListAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Sınıflar yüklenirken hata oluştu: $err',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          data: (classes) {
            if (classes.isEmpty) {
              return _buildNoClassState(context, isDark);
            }

            // Seçili sınıfı belirle
            final activeClass = classes.firstWhere(
              (c) => c.id == _selectedClassId,
              orElse: () => classes.first,
            );
            _selectedClassId = activeClass.id;

            final studentListAsync = ref.watch(studentListProvider(activeClass.id!));
            final students = studentListAsync.valueOrNull ?? [];

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await ref.read(classListProvider.notifier).loadClasses();
                      if (activeClass.id != null) {
                        await ref.read(studentListProvider(activeClass.id!).notifier).loadStudents();
                      }
                    } catch (e, stackTrace) {
                      debugPrint('Sınıfım ekranı yenileme hatası: $e\n$stackTrace');
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sınıf Seçim Çubuğu (Birden fazla sınıf varsa)
                        if (classes.length > 1) ...[
                          _buildClassSelector(classes, activeClass, isDark),
                          const SizedBox(height: 12),
                        ],

                        // 1. Sınıf Profil & İstatistik Kartı
                        _buildClassHeroCard(context, activeClass, students, profile, isDark),
                        const SizedBox(height: 16),

                        // 2. Öne Çıkan Modüller: Oturma Planı & Veli Rehberi
                        _buildSeatingPlanHero(context, activeClass, students, isDark),
                        const SizedBox(height: 10),
                        _buildParentContactsHero(context, activeClass, students, isDark),
                        const SizedBox(height: 20),

                        // 3. Resmî Sınıf Evrakları & Çizelgeler Bölümü
                        _buildSectionHeader(
                          context,
                          title: 'Resmî Sınıf Evrakları (A4 PDF)',
                          subtitle: 'Otomatik başlıklı, imzaya hazır MEB formatı',
                          icon: Icons.assignment_outlined,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),

                        _buildDocumentsList(context, activeClass, students, isDark),
                        const SizedBox(height: 20),

                        // 4. Öğrenci Yönetimi & Hızlı Araçlar
                        _buildSectionHeader(
                          context,
                          title: 'Öğrenci Yönetimi & Veri Araçları',
                          subtitle: 'Öğrenci listesi, düzenleme ve içe aktarma',
                          icon: Icons.group_outlined,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),

                        _buildStudentManagementCards(context, activeClass, students, isDark),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                // PDF Üretim Yükleniyor Katmanı
                if (_isGeneratingPdf)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCardBackground : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.primary),
                            const SizedBox(height: 16),
                            Text(
                              '$_generatingDocumentName Hazırlanıyor...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Türkçe karakter ve A4 formatı optimize ediliyor',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Birden fazla sınıf varsa hızlı geçiş çubuğu
  Widget _buildClassSelector(List<ClassModel> classes, ClassModel activeClass, bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: classes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final c = classes[index];
          final isSelected = c.id == activeClass.id;

          return ChoiceChip(
            label: Text(
              c.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey.shade300),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (selected) {
              if (selected && c.id != null) {
                setState(() => _selectedClassId = c.id);
              }
            },
          );
        },
      ),
    );
  }

  /// Sınıf Bilgi ve İstatistik Başlık Kartı
  Widget _buildClassHeroCard(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    dynamic profile,
    bool isDark,
  ) {
    final girls = students.where((s) => s.gender.toLowerCase().contains('kız')).length;
    final boys = students.where((s) => s.gender.toLowerCase().contains('erkek')).length;
    final total = students.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      classModel.subject.trim().isNotEmpty ? classModel.subject : 'Genel Sınıf',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                profile.schoolName.isNotEmpty ? profile.schoolName : 'Millî Eğitim Bakanlığı',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${classModel.name} Şubesi',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rehber Öğretmen: ${profile.fullName.isNotEmpty ? profile.fullName : "Belirtilmedi"}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // 3'lü İstatistik Satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStatItem('Toplam', '$total', Icons.groups_rounded, Colors.white),
              Container(width: 1, height: 28, color: Colors.white24),
              _buildHeroStatItem('Kız Öğrenci', '$girls', Icons.face_3_rounded, const Color(0xFFF472B6)),
              Container(width: 1, height: 28, color: Colors.white24),
              _buildHeroStatItem('Erkek Öğrenci', '$boys', Icons.face_6_rounded, const Color(0xFF60A5FA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  /// Sınıf Oturma Planı Hero Kartı
  Widget _buildSeatingPlanHero(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sınıf Oturma Planı',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sürükle-bırak kroki & A4 PDF Çıktısı',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SeatingPlanScreen(classModel: classModel),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Veli İletişim Rehberi Hero Kartı
  Widget _buildParentContactsHero(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    final withPhone = students.where((s) => s.parentPhone?.trim().isNotEmpty == true).length;
    final total = students.length;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.contact_phone_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Veli İletişim Rehberi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kayıtlı: $withPhone / $total • Hızlı Arama & WhatsApp',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ParentContactsScreen(classModel: classModel),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bölüm Başlığı
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Resmî Sınıf Evrakları Kart Listesi
  Widget _buildDocumentsList(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    final profile = ref.read(teacherProfileProvider);

    final documents = [
      {
        'title': 'Ders İçi Katılım & Ödev Rapor Merkezi',
        'desc': 'İdare teslim resmî dönem sonu çizelgesi, veli toplantısı kılavuzu ve bireysel veli gelişim karneleri.',
        'icon': Icons.assessment_rounded,
        'action': () => ParticipationCumulativeReportsModal.show(context, initialClassId: classModel.id),
      },
      {
        'title': 'Sınıf Öğrenci Listesi Formu',
        'desc': 'No, Adı Soyadı, Cinsiyet ve İmza sütunlu standart A4 resmî liste.',
        'icon': Icons.format_list_numbered_rounded,
        'action': () => _runPdfAction(
              'Sınıf Listesi',
              () => ClassroomDocumentsPdfGenerator.generateStudentListPdf(
                context: context,
                classModel: classModel,
                students: students,
                teacherProfile: profile,
              ),
            ),
      },
      {
        'title': 'Ders İçi Not & Değerlendirme Çizelgesi',
        'desc': 'Etkinlik, ödev, proje ve sözlü notu takibi için yatay (landscape) A4 şablonu.',
        'icon': Icons.score_rounded,
        'action': () => _runPdfAction(
              'Değerlendirme Çizelgesi',
              () => ClassroomDocumentsPdfGenerator.generateEvaluationSheetPdf(
                context: context,
                classModel: classModel,
                students: students,
                teacherProfile: profile,
              ),
            ),
      },
      {
        'title': 'Haftalık Sınıf Nöbet Çizelgesi',
        'desc': 'Pazartesi-Cuma nöbetçi öğrenci dağıtım ve görev talimatı formu.',
        'icon': Icons.shield_outlined,
        'action': () => _runPdfAction(
              'Nöbet Çizelgesi',
              () => ClassroomDocumentsPdfGenerator.generateDutySchedulePdf(
                context: context,
                classModel: classModel,
                students: students,
                teacherProfile: profile,
              ),
            ),
      },
      {
        'title': 'Sosyal Kulüp Öğrenci Dağılım Çizelgesi',
        'desc': 'Öğrencilerin seçtiği sosyal kulüpler ve kulüp görevleri eşleştirme listesi.',
        'icon': Icons.palette_outlined,
        'action': () => _runPdfAction(
              'Sosyal Kulüp Listesi',
              () => ClassroomDocumentsPdfGenerator.generateClubDistributionPdf(
                context: context,
                classModel: classModel,
                students: students,
                teacherProfile: profile,
              ),
            ),
      },
      {
        'title': 'Acil Durum & Veli İletişim Listesi (KVKK Uyumlu)',
        'desc': 'Veli telefonları ve özel durum notlarını içeren güvenli rehberlik belgesi.',
        'icon': Icons.contact_phone_outlined,
        'action': () => _runPdfAction(
              'İletişim Listesi',
              () => ClassroomDocumentsPdfGenerator.generateEmergencyContactListPdf(
                context: context,
                classModel: classModel,
                students: students,
                teacherProfile: profile,
              ),
            ),
      },
    ];

    return Column(
      children: documents.map((doc) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(doc['icon'] as IconData, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title'] as String,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc['desc'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: students.isEmpty
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Evrak oluşturmak için önce sınıfa öğrenci ekleyin.')),
                          );
                        }
                      : (doc['action'] as VoidCallback),
                  icon: const Icon(Icons.share_rounded, color: AppColors.primary, size: 20),
                  tooltip: 'PDF Oluştur & Paylaş',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Öğrenci Yönetimi Kartları
  Widget _buildStudentManagementCards(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    return Row(
      children: [
        // 1. Öğrenci Listesi
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentListScreen(classModel: classModel),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Öğrenci Listesi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${students.length} Öğrenciyi Yönet',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 2. Excel / PDF İçe Aktar
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentImportPreviewView(
                    initialClassId: classModel.id,
                    initialClassName: classModel.name,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_upload_outlined, color: Colors.green, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Toplu Aktar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Excel & e-Okul PDF',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// PDF Üretim Yardımcısı
  Future<void> _runPdfAction(String name, Future<void> Function() action) async {
    setState(() {
      _isGeneratingPdf = true;
      _generatingDocumentName = name;
    });

    try {
      await action();
    } catch (e, stackTrace) {
      debugPrint('PDF üretimi işlem hatası: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name oluşturulurken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _generatingDocumentName = '';
        });
      }
    }
  }

  /// Henüz sınıf yoksa gösterilen durum
  Widget _buildNoClassState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: isDark ? Colors.white30 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Henüz Tanımlı Sınıfınız Yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sınıfım modülünü kullanabilmek ve resmi evraklar üretebilmek için lütfen önce "Sınıf Ekle" butonunu kullanarak sınıfınızı tanımlayın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Sınıflar Listesine Dön'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
