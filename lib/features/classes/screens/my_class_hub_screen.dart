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
import '../../../core/widgets/responsive_bottom_sheet.dart';
import '../presentation/widgets/duty_schedule_editor_modal.dart';
import '../presentation/widgets/parent_invitation_editor_modal.dart';
import '../presentation/widgets/classroom_rules_editor_modal.dart';
import '../presentation/widgets/parent_meeting_editor_modal.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import 'seating_plan_screen.dart';
import 'student_list_screen.dart';
import 'parent_contacts_screen.dart';
import '../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../navigation/providers/navigation_provider.dart';
import '../../attendance/presentation/widgets/participation_cumulative_reports_modal.dart';
import '../../parent_portal/presentation/widgets/class_reference_codes_modal.dart';
import '../../parent_portal/presentation/screens/teacher_parent_panel_screen.dart';
import '../../parent_portal/presentation/screens/notification_center_screen.dart';
import '../../parent_portal/providers/notification_provider.dart';
import '../../parent_portal/presentation/widgets/class_staff_manager_modal.dart';
import '../../parent_portal/presentation/screens/bulk_announcement_screen.dart';

/// SınıfCepte - Sınıfım (Yönetim & Evrak Merkezi) Hub Ekranı
/// UI-UX MAX: Bento Grid + Segmented Control Mimarisi
class MyClassHubScreen extends ConsumerStatefulWidget {
  final ClassModel? initialClass;

  const MyClassHubScreen({super.key, this.initialClass});

  @override
  ConsumerState<MyClassHubScreen> createState() => _MyClassHubScreenState();
}

class _MyClassHubScreenState extends ConsumerState<MyClassHubScreen> {
  int? _selectedClassId;
  int _activeTabIndex = 0; // 0: Resmî Evraklar, 1: Öğrenci & Veri

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClass?.id;
  }

  /// Bildirim merkezini açar.
  Future<void> _openNotifications(
    BuildContext context,
    List<ClassModel>? classes,
  ) async {
    final list = classes ?? const <ClassModel>[];
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir sınıf ekleyin.')),
      );
      return;
    }

    final target = list.firstWhere(
      (c) => c.isHomeroom,
      orElse: () => list.first,
    );

    final notifications =
        await ref.read(teacherNotificationsProvider(target).future);
    if (!context.mounted) return;

    await NotificationCenterScreen.show(
      context,
      notifications: notifications,
      onRefresh: () async {
        ref.invalidate(teacherNotificationsProvider(target));
      },
    );
  }

  /// Veli yönetim panelini açar.
  ///
  /// Sınıf seçili değilse (birden fazla sınıf varsa ilki) kullanıcıya
  /// sebebi söylenir; sessizce hiçbir şey yapmamak kafa karıştırıyordu.
  void _openParentPanel(
    BuildContext context,
    List<ClassModel>? classes,
    TeacherPanelTab tab,
  ) {
    final list = classes ?? const <ClassModel>[];
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce bir sınıf ekleyin.'),
        ),
      );
      return;
    }

    // Rehberlik sınıfı varsa onu, yoksa ilk sınıfı aç.
    final target = list.firstWhere(
      (c) => c.isHomeroom,
      orElse: () => list.first,
    );

    TeacherParentPanelScreen.show(
      context,
      classModel: target,
      initialTab: tab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classListAsync = ref.watch(classListProvider);
    final profile = ref.watch(teacherProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F7FB),
      extendBody: true,
      appBar: CustomAppBar(
        title: 'Sınıfım',
        subtitle: 'Sınıf Yönetimi & Evrak Merkezi',
        showProfileAvatar: false,
        showBackButton: Navigator.of(context).canPop(),
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        // Mesaj ikonu doğrudan mesaj kutusuna götürür.
        //
        // Önceden "Mesaj Kutusu (Yakında)" uyarısı gösteriyordu: veli
        // mesaj gönderiyor, öğretmen ikona basıyor ama hiçbir şey
        // olmuyordu.
        onMessageTap: () => _openParentPanel(
          context,
          classListAsync.valueOrNull,
          TeacherPanelTab.messages,
        ),
        // Çan ikonu bildirim merkezine gider (panele değil).
        onNotificationTap: () =>
            _openNotifications(context, classListAsync.valueOrNull),
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

            // Seçili sınıfı belirle (Rehberlik sınıfı öncelikli)
            final homeroomClass = classes.where((c) => c.isHomeroom).firstOrNull;
            final activeClass = classes.firstWhere(
              (c) => c.id == _selectedClassId,
              orElse: () => homeroomClass ?? classes.first,
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
                        // Rehberlik Sınıfı Yoksa Bilgilendirme ve Hızlı Atama Kartı
                        if (homeroomClass == null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Henüz bir Rehberlik Sınıfı seçilmedi. "${activeClass.name}" sınıfını şubeniz olarak atayabilirsiniz.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    await ref.read(classListProvider.notifier).setHomeroomClass(activeClass.id!);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${activeClass.name} Rehberlik Sınıfınız olarak belirlendi! 🌟'),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Şubem Yap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // 1. Sınıf Profil & İstatistik Hero Kartı
                        _buildClassHeroCard(context, ref, activeClass, students, profile, classes, isDark),
                        const SizedBox(height: 16),

                        // 2. VELİ İLETİŞİMİ
                        //
                        // Bölüm başlıkları eklendi: kartlar tek bir
                        // ızgaradaydı ve öğretmen hangi işin nerede
                        // olduğunu aramak zorunda kalıyordu.
                        _buildSectionTitle(
                          'Veli İletişimi',
                          Icons.family_restroom_rounded,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildParentGrid(context, activeClass, students, isDark),
                        const SizedBox(height: 20),

                        // 3. SINIF YÖNETİMİ
                        _buildSectionTitle(
                          'Sınıf Yönetimi',
                          Icons.school_rounded,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildClassGrid(context, activeClass, students, isDark),
                        const SizedBox(height: 20),

                        // 3. Segmentli Sekme Switcher (Resmî Evraklar | Öğrenci Yönetimi)
                        _buildSegmentedTab(isDark),
                        const SizedBox(height: 14),

                        // 4. Aktif Sekme İçeriği
                        if (_activeTabIndex == 0)
                          _buildDocumentsList(context, activeClass, students, isDark)
                        else
                          _buildStudentManagementTab(context, activeClass, students, isDark),

                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),

              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1, // Sınıf sekmesi aktif
        onTap: (index) {
          try {
            ref.read(navigationIndexProvider.notifier).state = index;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } catch (e, stackTrace) {
            debugPrint('MyClassHubScreen alt menü navigasyon hatası: $e\n$stackTrace');
          }
        },
      ),
    );
  }

  /// Rehberlik Şubesini Değiştirme Modalı
  void _showChangeHomeroomModal(
    BuildContext context,
    WidgetRef ref,
    List<ClassModel> classes,
    ClassModel currentHomeroom,
  ) {
    final otherClasses = classes.where((c) => c.id != currentHomeroom.id).toList();
    if (otherClasses.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    int? selectedId = otherClasses.first.id;

    ResponsiveBottomSheet.show(
      context: context,
      title: 'Rehberlik Şubesini Değiştir',
      builder: (ctx, setStateModal) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Mevcut şubeniz "${currentHomeroom.name}". Rehberlik unvanını devretmek istediğiniz yeni sınıfı seçin.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Diğer Sınıflarınız:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            ...otherClasses.map((c) {
              final isSelected = selectedId == c.id;
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
                  onTap: () => setStateModal(() => selectedId = c.id),
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
                          child: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
      bottomActionBuilder: (ctx, setStateModal) {
        return ElevatedButton.icon(
          onPressed: selectedId == null
              ? null
              : () async {
                  final targetClass = otherClasses.firstWhere((c) => c.id == selectedId);
                  Navigator.pop(ctx);

                  await ref.read(classListProvider.notifier).setHomeroomClass(selectedId!);
                  setState(() => _selectedClassId = selectedId);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rehberlik Sınıfınız ${targetClass.name} olarak güncellendi! 🌟'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        );
      },
    );
  }

  /// Sınıf Bilgi ve İstatistik Başlık Kartı
  Widget _buildClassHeroCard(
    BuildContext context,
    WidgetRef ref,
    ClassModel classModel,
    List<StudentModel> students,
    dynamic profile,
    List<ClassModel> classes,
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        classModel.isHomeroom ? Icons.stars_rounded : Icons.class_outlined,
                        color: classModel.isHomeroom ? Colors.amber : Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          classModel.isHomeroom ? 'Rehberlik Sınıfım' : 'Ders Sınıfım',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  profile.schoolName.isNotEmpty ? profile.schoolName : 'Millî Eğitim Bakanlığı',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${classModel.name} Şubesi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (classes.length > 1) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showChangeHomeroomModal(context, ref, classes, classModel),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Şube Değiştir',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Rehber Öğretmen: ${profile.fullName.isNotEmpty ? profile.fullName : "Belirtilmedi"}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),

          // 3'lü İstatistik Satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStatItem('Toplam', '$total', Icons.groups_rounded, Colors.white),
              Container(width: 1, height: 26, color: Colors.white24),
              _buildHeroStatItem('Kız Öğrenci', '$girls', Icons.face_3_rounded, const Color(0xFFF472B6)),
              Container(width: 1, height: 26, color: Colors.white24),
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
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
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

  /// Bölüm başlığı.
  ///
  /// Kartlar önceden tek bir ızgaradaydı; öğretmen "duyuru nerede,
  /// kodlar nerede" diye aramak zorunda kalıyordu. Başlıklar ilgili
  /// işleri bir arada tutar.
  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  /// Veli iletişimi kartları.
  ///
  /// "Duyuru Merkezi" ve "Veli Portalı" ayrı kartlardı ve ikisi de veli
  /// iletişimiyle ilgiliydi; hangisinin ne yaptığı adlarından
  /// anlaşılmıyordu. Adlar işlevi anlatacak şekilde değiştirildi.
  Widget _buildParentGrid(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    final withPhone =
        students.where((s) => s.parentPhone?.trim().isNotEmpty == true).length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.15,
      children: [
        // Mesajlar, duyurular, randevular — tek panel.
        _buildBentoTile(
          context: context,
          title: 'Veli Paneli',
          subtitle: 'Mesaj · Duyuru · Randevu',
          icon: Icons.forum_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          accent: const Color(0xFFF59E0B),
          isDark: isDark,
          onTap: () {
            TeacherParentPanelScreen.show(
              context,
              classModel: classModel,
            );
          },
        ),

        // Veliyi sisteme bağlayan referans kodları.
        _buildBentoTile(
          context: context,
          title: 'Referans Kodları',
          subtitle: 'Veli bağlantı kodu',
          icon: Icons.vpn_key_rounded,
          gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          accent: const Color(0xFF8B5CF6),
          isDark: isDark,
          onTap: () {
            ClassReferenceCodesModal.show(
              context,
              classModel: classModel,
            );
          },
        ),

        // Telefon rehberi (arama / WhatsApp).
        _buildBentoTile(
          context: context,
          title: 'Veli Rehberi',
          subtitle: 'Telefon: $withPhone / ${students.length}',
          icon: Icons.contact_phone_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
          accent: const Color(0xFF10B981),
          isDark: isDark,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ParentContactsScreen(classModel: classModel),
              ),
            );
          },
        ),

        // Sınıfa giren branş öğretmenleri.
        //
        // Bu ekrana ulaşmak için önce Veli Paneli'ni açmak gerekiyordu;
        // öğretmen kadro yönetimini bulamıyordu. Artık doğrudan kart.
        _buildBentoTile(
          context: context,
          title: 'Öğretmen Kadrosu',
          subtitle: 'Derse giren öğretmenler',
          icon: Icons.groups_rounded,
          gradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
          accent: const Color(0xFF0EA5E9),
          isDark: isDark,
          onTap: () {
            ClassStaffManagerModal.show(
              context,
              classModel: classModel,
            );
          },
        ),

        // Birden fazla sınıfa aynı anda duyuru.
        //
        // Branş öğretmeni beş sınıfa giriyor ve "yarın quiz var"
        // duyurusunu hepsine yapmak istiyor; önceden bunu ancak her
        // sınıfın rehber öğretmeninden rica ederek yapabiliyordu.
        _buildBentoTile(
          context: context,
          title: 'Toplu Duyuru',
          subtitle: 'Birden fazla sınıfa',
          icon: Icons.campaign_rounded,
          gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
          accent: const Color(0xFFEC4899),
          isDark: isDark,
          onTap: () => BulkAnnouncementScreen.show(context),
        ),
      ],
    );
  }

  /// Sınıf yönetimi kartları.
  Widget _buildClassGrid(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.15,
      children: [
        _buildBentoTile(
          context: context,
          title: 'Oturma Planı',
          subtitle: 'Kroki & Yerleşim',
          icon: Icons.event_seat_rounded,
          gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
          accent: const Color(0xFF3B82F6),
          isDark: isDark,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SeatingPlanScreen(classModel: classModel),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Dashboard ile 1:1 Tasarım Bütünlüklü Kompakt Modül Kartı
  Widget _buildBentoTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required Color accent,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  Color.alphaBlend(accent.withValues(alpha: 0.08), const Color(0xFF1E293B)),
                ]
              : [
                  Colors.white,
                  Color.alphaBlend(accent.withValues(alpha: 0.04), Colors.white),
                ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark
              ? accent.withValues(alpha: 0.22)
              : accent.withValues(alpha: 0.16),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : accent.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Arka Plan Hafif 3D Filigran İkonu
            Positioned(
              right: -6,
              bottom: -6,
              child: Icon(
                icon,
                size: 48,
                color: accent.withValues(alpha: isDark ? 0.04 : 0.035),
              ),
            ),

            // Tıklanabilir İçerik
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: accent.withValues(alpha: 0.12),
                highlightColor: accent.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Sol: Gradyan İkon Rozeti
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: gradient[0].withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sağ: Başlık & Alt Metin
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmentli Sekme Switcher
  Widget _buildSegmentedTab(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              title: 'Evraklar (PDF)',
              icon: Icons.assignment_outlined,
              isSelected: _activeTabIndex == 0,
              isDark: isDark,
              onTap: () => setState(() => _activeTabIndex = 0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              title: 'Öğrenci Yönetimi',
              icon: Icons.group_outlined,
              isSelected: _activeTabIndex == 1,
              isDark: isDark,
              onTap: () => setState(() => _activeTabIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isDark ? Colors.white60 : Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kompakt & Kategorize Edilmiş Resmî Evraklar (PDF) Merkezi
  Widget _buildDocumentsList(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    final profile = ref.read(teacherProfileProvider);

    final sections = [
      {
        'category': 'Resmî Çizelgeler & Sınıf Belgeleri',
        'icon': Icons.folder_shared_outlined,
        'color': const Color(0xFF3B82F6),
        'items': [
          {
            'title': 'Ders İçi Katılım & Ödev Rapor Merkezi',
            'desc': 'Dönem sonu raporu, toplantı kılavuzu & karneler',
            'icon': Icons.assessment_rounded,
            'color': const Color(0xFF6366F1),
            'action': () => ParticipationCumulativeReportsModal.show(context, initialClassId: classModel.id),
          },
          {
            'title': 'Sınıf Öğrenci Listesi Formu',
            'desc': 'Resmî imzalı standart A4 sınıf listesi',
            'icon': Icons.format_list_numbered_rounded,
            'color': const Color(0xFF3B82F6),
            'action': () => ClassroomDocumentsPdfGenerator.generateStudentListPdf(
                  context: context,
                  classModel: classModel,
                  students: students,
                  teacherProfile: profile,
                ),
          },
          {
            'title': 'Haftalık Sınıf Nöbet Çizelgesi',
            'desc': '1-4 nöbetçi sayısı & otomatik dağıtım motoru',
            'icon': Icons.shield_outlined,
            'color': const Color(0xFFF59E0B),
            'action': () => DutyScheduleEditorModal.show(
                  context,
                  classModel: classModel,
                  students: students,
                  teacherProfile: profile,
                ),
          },
          {
            'title': 'Ders İçi Değerlendirme Not Çizelgesi',
            'desc': 'A4 yatay 10 etkinlikli değerlendirme formu',
            'icon': Icons.fact_check_outlined,
            'color': const Color(0xFF10B981),
            'action': () => PdfPreviewScreen.open(
                  context,
                  title: 'Ders İçi Değerlendirme Çizelgesi',
                  subtitle: '${classModel.name} - ${classModel.subject.toUpperCase()}',
                  fileName: 'Degerlendirme_Cizelgesi_${classModel.name}.pdf',
                  documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateEvaluationSheetPdfBytes(
                    classModel: classModel,
                    students: students,
                    teacherProfile: profile,
                  ),
                ),
          },
          {
            'title': 'Sosyal Kulüp Öğrenci Dağılımı',
            'desc': 'Kulüp tercihleri ve öğrenci eşleştirme tablosu',
            'icon': Icons.palette_outlined,
            'color': const Color(0xFFEC4899),
            'action': () => ClassroomDocumentsPdfGenerator.generateClubDistributionPdf(
                  context: context,
                  classModel: classModel,
                  students: students,
                  teacherProfile: profile,
                ),
          },
          {
            'title': 'Acil Durum & Veli İletişim Listesi',
            'desc': 'Veli telefonları ve acil durum rehberlik belgesi',
            'icon': Icons.contact_phone_outlined,
            'color': const Color(0xFF8B5CF6),
            'action': () => ClassroomDocumentsPdfGenerator.generateEmergencyContactListPdf(
                  context: context,
                  classModel: classModel,
                  students: students,
                  teacherProfile: profile,
                ),
          },
        ],
      },
      {
        'category': 'Veli Toplantısı & Davetiye Mektupları',
        'icon': Icons.groups_2_outlined,
        'color': const Color(0xFF10B981),
        'items': [
          {
            'title': 'Veli Davetiye Mektubu (8\'li A4 Kuponu)',
            'desc': 'Tek A4\'te 8 adet kesilebilir (✂) davetiye mektubu',
            'icon': Icons.mail_outline_rounded,
            'color': const Color(0xFF6366F1),
            'action': () => ParentInvitationEditorModal.show(
                  context,
                  classModel: classModel,
                  teacherProfile: profile,
                ),
          },
          {
            'title': 'Veli Toplantı Tutanağı & İmza Sirküsü',
            'desc': 'Gündem maddeleri, kararlar ve veli imza çizelgesi',
            'icon': Icons.how_to_reg_outlined,
            'color': const Color(0xFF10B981),
            'action': () => ParentMeetingEditorModal.show(
                  context,
                  classModel: classModel,
                  students: students,
                  teacherProfile: profile,
                ),
          },
        ],
      },
      {
        'category': 'Sınıf Yaşamı & Pano Düzeni',
        'icon': Icons.dashboard_customize_outlined,
        'color': const Color(0xFFEC4899),
        'items': [
          {
            'title': 'Sınıf Kuralları Afişi (A4 Pano Posteri)',
            'desc': 'Hazır 10 MEB kuralı veya düzenlenebilir afiş',
            'icon': Icons.format_paint_outlined,
            'color': const Color(0xFFEC4899),
            'action': () => ClassroomRulesEditorModal.show(
                  context,
                  classModel: classModel,
                  teacherProfile: profile,
                ),
          },
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        final categoryTitle = section['category'] as String;
        final categoryColor = section['color'] as Color;
        final categoryIcon = section['icon'] as IconData;
        final items = section['items'] as List<Map<String, dynamic>>;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kategori Başlığı
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(categoryIcon, size: 16, color: categoryColor),
                    const SizedBox(width: 6),
                    Text(
                      categoryTitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Kategori İçerisindeki Evraklar Kartı
              GlassCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 14,
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final doc = items[index];
                      final color = doc['color'] as Color;
                      final action = doc['action'] as VoidCallback;

                      return InkWell(
                        onTap: students.isEmpty
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Evrak oluşturmak için önce sınıfa öğrenci ekleyin.')),
                                );
                              }
                            : action,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              // Sol: Renkli Kompakt İkon Rozeti
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Icon(
                                    doc['icon'] as IconData,
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Orta: Başlık ve Açıklama
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc['title'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      doc['desc'] as String,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Sağ: Önizleme / PDF Rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.remove_red_eye_outlined,
                                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Color(0xFFFF512F),
                                      size: 15,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Öğrenci Yönetimi Sekmesi İçeriği
  Widget _buildStudentManagementTab(
    BuildContext context,
    ClassModel classModel,
    List<StudentModel> students,
    bool isDark,
  ) {
    final girls = students.where((s) => s.gender.toLowerCase().contains('kız')).length;
    final boys = students.where((s) => s.gender.toLowerCase().contains('erkek')).length;
    final withPhone = students.where((s) => s.parentPhone?.trim().isNotEmpty == true).length;
    final missingPhone = students.length - withPhone;

    return Column(
      children: [
        // 1 & 2: Öğrenci Listesi ve Toplu İçe Aktarım (Kompakt Liste Kartı)
        GlassCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Sınıf Öğrenci Listesi
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentListScreen(classModel: classModel),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.people_alt_rounded, color: Colors.blue, size: 17),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sınıf Öğrenci Listesi',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${students.length} Öğrenci • Düzenle, Sil, Şube Taşı',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),

                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 14,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),

                // Toplu Öğrenci Yükle
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentImportPreviewView(
                          initialClassId: classModel.id,
                          initialClassName: classModel.name,
                          autoPickPdf: true,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.file_upload_outlined, color: Color(0xFF10B981), size: 17),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Toplu Öğrenci Yükle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'e-Okul PDF veya Excel sınıf listesinden aktar',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Sınıf Veri & Sağlık Özeti (Health/Status Card)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Şube Veri & Sağlık Özeti',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniHealthItem(
                      'Kız / Erkek',
                      '$girls K / $boys E',
                      Icons.people_outline_rounded,
                      Colors.blue,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniHealthItem(
                      'Eksik Veli Tel',
                      missingPhone > 0 ? '$missingPhone Öğrenci' : 'Eksik Yok 🎉',
                      missingPhone > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                      missingPhone > 0 ? Colors.amber : Colors.green,
                      isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniHealthItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
