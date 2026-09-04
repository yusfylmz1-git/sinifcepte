import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../bep/presentation/views/bep_list_view.dart';
import '../../../classes/presentation/widgets/counseling_interview_modal.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../views/guidance_plan_view.dart';
import '../views/special_education_view.dart';

/// Rehberlik iş ve işlemleri.
///
/// ## Neden ayrı ekran
/// Ana sayfadaki "Rehberlik" düğmesi doğrudan Sınıfım sayfasına
/// gidiyordu; rehberlik işleri o sayfanın alt kısmındaki belge
/// listesine gömülüydü. Öğretmen BEP formuna ulaşmak için önce sınıf
/// seçip sonra kategoriler arasında aramak zorundaydı.
///
/// İki sekme:
///   1. **BEP Gelişim Raporları** — kaynaştırma/özel eğitim takibi
///   2. **Sınıf Rehberliği** — görüşme, tanıma fişi, izin belgeleri
class GuidanceHubScreen extends ConsumerStatefulWidget {
  const GuidanceHubScreen({super.key});

  @override
  ConsumerState<GuidanceHubScreen> createState() => _GuidanceHubScreenState();
}

class _GuidanceHubScreenState extends ConsumerState<GuidanceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  /// Belgeler sınıf bağlamında üretiliyor; hangi sınıf seçili?
  ClassModel? _selected;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// Rehberlik sınıfı varsayılan seçilir; yoksa ilk sınıf.
  ClassModel? _resolveClass(List<ClassModel> classes) {
    if (classes.isEmpty) return null;
    if (_selected != null &&
        classes.any((c) => c.id == _selected!.id)) {
      return _selected;
    }
    return classes.where((c) => c.isHomeroom).firstOrNull ?? classes.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classListProvider).valueOrNull ?? const [];
    final active = _resolveClass(classes);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Rehberlik',
        subtitle: 'BEP & Sınıf Rehberliği',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        // Sinif yoksa ekran tumden kapatilmiyor.
        //
        // Ozel egitim programlari ve rehberlik etkinlikleri SALT OKUNUR
        // kaynak; sinifla ilgileri yok. Once "once sinif ekleyin" deyip
        // hepsini kilitliyorduk — sinifi henuz tanimlamamis ogretmen
        // (yil basi, yeni atanan) hicbir belgeye ulasamiyordu.
        child: Column(
          children: [
            if (classes.isNotEmpty)
              _buildClassPicker(classes, active, isDark),
            _buildTabBar(isDark),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  active == null
                      ? _buildNoClass(isDark, 'BEP planı')
                      : _BepTab(classModel: active),
                        // Plan yalnizca SINIF REHBER OGRETMENI icin
                        // anlamlidir; brans ogretmeni sinif rehberligi
                        // yapmaz, listede anlamsiz plan birikmesin.
                  if (active == null)
                    _buildNoClass(isDark, 'rehberlik planı')
                  else if (active.isHomeroom)
                    GuidancePlanView(
                      classModel: active,
                      teacher: ref.watch(teacherProfileProvider),
                      students: ref
                              .watch(studentListProvider(active.id ?? 0))
                              .valueOrNull ??
                          const [],
                    )
                  else
                    _SadeceRehberOgretmen(isDark: isDark),
                  // Sinif GEREKMEZ: ORGM programlari salt okunur.
                  const SpecialEducationView(),
                  active == null
                      ? _buildNoClass(isDark, 'form üretimi')
                      : _ClassGuidanceTab(classModel: active),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoClass(bool isDark, String ne) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined,
                size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              '$ne için sınıf eklemeniz gerekiyor.\n\n'
              'Özel Eğitim sekmesindeki programlara sınıf olmadan da '
              'bakabilirsiniz.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Belgeler sınıf bağlamında üretildiği için seçici üstte durur.
  Widget _buildClassPicker(
    List<ClassModel> classes,
    ClassModel? active,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: active?.id,
                isExpanded: true,
                isDense: true,
                style: AppFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                dropdownColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                items: classes
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.isHomeroom ? '${c.name} (Rehberlik)' : c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (id) {
                  final secilen =
                      classes.where((c) => c.id == id).firstOrNull;
                  if (secilen != null) {
                    setState(() => _selected = secilen);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? Colors.white60 : const Color(0xFF64748B),
        labelStyle:
            AppFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppFonts.outfit(fontSize: 12.5),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'BEP Gelişim'),
          Tab(text: 'Rehberlik Planı'),
          Tab(text: 'Özel Eğitim'),
          Tab(text: 'Formlar'),
        ],
      ),
    );
  }
}

/// 1. sekme — BEP gelişim raporları.
class _BepTab extends ConsumerWidget {
  const _BepTab({required this.classModel});

  final ClassModel classModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students =
        ref.watch(studentListProvider(classModel.id ?? 0)).valueOrNull ??
            const <StudentModel>[];
    final profile = ref.watch(teacherProfileProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _InfoNote(
          isDark: isDark,
          text: 'BEP; kaynaştırma ve özel eğitim öğrencileri için '
              'hazırlanır. Bu form takip amaçlıdır; kurul kararı ve '
              'imzalar okul dosyasında tamamlanır.',
        ),
        const SizedBox(height: 12),
        _GuidanceCard(
          isDark: isDark,
          icon: Icons.star_border_rounded,
          color: const Color(0xFF10B981),
          title: 'BEP Gelişim Raporları',
          subtitle: 'Kaynaştırma / özel eğitim amaç takibi ve PDF çıktısı',
          onTap: students.isEmpty
              ? null
              // Belge modali araya girmez: BEP tek seferlik cikti degil,
              // yil boyunca uzerinde calisilan bir plan.
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BepListView(
                        classModel: classModel,
                        students: students,
                        teacher: profile,
                      ),
                    ),
                  ),
        ),
        if (students.isEmpty) ...[
          const SizedBox(height: 10),
          _EmptyHint(
            isDark: isDark,
            text: '${classModel.name} sınıfında öğrenci yok. '
                'Form üretmek için önce öğrenci ekleyin.',
          ),
        ],
      ],
    );
  }
}

/// 2. sekme — sınıf rehberliği belgeleri.
class _ClassGuidanceTab extends ConsumerWidget {
  const _ClassGuidanceTab({required this.classModel});

  final ClassModel classModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students =
        ref.watch(studentListProvider(classModel.id ?? 0)).valueOrNull ??
            const <StudentModel>[];
    final profile = ref.watch(teacherProfileProvider);

    void ac(int index) => CounselingInterviewModal.show(
          context,
          classModel: classModel,
          students: students,
          teacherProfile: profile,
          initialDocumentIndex: index,
        );

    final bosMu = students.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _GuidanceCard(
          isDark: isDark,
          icon: Icons.connect_without_contact_outlined,
          color: const Color(0xFF3B82F6),
          title: 'Veli Görüşme Formu',
          subtitle: 'Görüşme tutanağı ve takip planı',
          onTap: bosMu ? null : () => ac(0),
        ),
        const SizedBox(height: 10),
        _GuidanceCard(
          isDark: isDark,
          icon: Icons.record_voice_over_outlined,
          color: const Color(0xFF8B5CF6),
          title: 'Öğrenci Görüşme Formu',
          subtitle: 'Bireysel öğrenci görüşme tutanağı',
          onTap: bosMu ? null : () => ac(1),
        ),
        const SizedBox(height: 10),
        _GuidanceCard(
          isDark: isDark,
          icon: Icons.badge_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Öğrenci Tanıma Fişi',
          subtitle: 'Aile yapısı, sağlık, yetenek ve sosyo-ekonomik bilgi',
          onTap: bosMu ? null : () => ac(3),
        ),
        const SizedBox(height: 10),
        _GuidanceCard(
          isDark: isDark,
          icon: Icons.directions_bus_outlined,
          color: const Color(0xFF0EA5E9),
          title: 'Gezi & Etkinlik İzin Belgesi',
          subtitle: 'Kesilebilir veli izin dilekçesi',
          onTap: bosMu ? null : () => ac(4),
        ),
        if (bosMu) ...[
          const SizedBox(height: 12),
          _EmptyHint(
            isDark: isDark,
            text: '${classModel.name} sınıfında öğrenci yok. '
                'Belge üretmek için önce öğrenci ekleyin.',
          ),
        ],
      ],
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.isDark,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pasif = onTap == null;

    return Opacity(
      opacity: pasif ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.isDark, required this.text});

  final bool isDark;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppFonts.outfit(
          fontSize: 11.5,
          height: 1.4,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.isDark, required this.text});

  final bool isDark;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline_rounded,
            size: 15, color: Colors.orange.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppFonts.outfit(
              fontSize: 11.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rehberlik planı yalnızca sınıf rehber öğretmenine açıktır.
///
/// Branş öğretmeni sınıf rehberliği yapmaz; plan herkese açılsaydı
/// listede uygulanmayacak planlar birikirdi.
class _SadeceRehberOgretmen extends StatelessWidget {
  const _SadeceRehberOgretmen({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Sınıf rehberlik planı, rehber öğretmeni olduğunuz şube '
              'için açılır.\n\nSınıfı düzenleyip "Rehberlik/Şube sınıfım" '
              'seçeneğini işaretleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
