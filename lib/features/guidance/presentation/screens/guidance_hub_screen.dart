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
import 'rehberlik_dosyasi_screen.dart';

/// Rehberlik iş ve işlemleri.
///
/// ## Neden sekmesiz tek liste (29 Ekim 2026)
/// Dört sekme vardı: BEP Gelişim, Rehberlik Planı, Özel Eğitim, Formlar.
/// Kullanıcı: "Özel eğitim kısmı gereksiz, kaldıralım. Sekmeye gerek yok,
/// alt alta koyalım: en üstte BEP gelişim raporu, altında rehberlik
/// dosyası, en altta formlar. Formlara basınca Rehberlik & Resmî Form
/// Merkezi doğrudan açılsın." Özel Eğitim sekmesi (özel eğitim OKULLARININ
/// ORGM programları) koddan da kalktı.
///
/// Belgeler sınıf bağlamında üretildiği için sınıf seçici üstte durur.
/// Kullanılamayan kart soluk durur ve nedenini altında yazar.
class GuidanceHubScreen extends ConsumerStatefulWidget {
  const GuidanceHubScreen({super.key});

  @override
  ConsumerState<GuidanceHubScreen> createState() => _GuidanceHubScreenState();
}

class _GuidanceHubScreenState extends ConsumerState<GuidanceHubScreen> {
  /// Belgeler sınıf bağlamında üretiliyor; hangi sınıf seçili?
  ClassModel? _selected;

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
    final students = active == null
        ? const <StudentModel>[]
        : ref.watch(studentListProvider(active.id ?? 0)).valueOrNull ??
            const <StudentModel>[];
    final profile = ref.watch(teacherProfileProvider);

    // Kart kullanılamıyorsa nedeni, kullanılabiliyorsa null.
    final sinifYok = active == null ? 'Önce bir sınıf ekleyin.' : null;
    final ogrenciYok = sinifYok ??
        (students.isEmpty
            ? '${active!.name} sınıfında öğrenci yok; önce öğrenci ekleyin.'
            : null);
    // Branş öğretmeni sınıf rehberliği yapmaz; plan herkese açılsaydı
    // listede uygulanmayacak planlar birikirdi.
    final rehberDegil = sinifYok ??
        (active!.isHomeroom
            ? null
            : 'Rehberlik dosyası, rehber öğretmeni olduğunuz şube için '
                'açılır. Sınıfı düzenleyip "Rehberlik/Şube sınıfım" '
                'seçeneğini işaretleyebilirsiniz.');

    void sayfa(Widget hedef) => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => hedef),
        );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Rehberlik',
        subtitle: 'BEP, rehberlik dosyası ve formlar',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (classes.isNotEmpty)
              _buildClassPicker(classes, active, isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _GuidanceCard(
                    key: const ValueKey('rehberlik_bep'),
                    isDark: isDark,
                    icon: Icons.star_border_rounded,
                    color: const Color(0xFF10B981),
                    title: 'BEP Gelişim Raporu',
                    subtitle:
                        'Kaynaştırma öğrencilerinin amaç takibi ve PDF raporu',
                    neden: ogrenciYok,
                    // Belge penceresi araya girmez: BEP tek seferlik çıktı
                    // değil, yıl boyunca üzerinde çalışılan bir plan.
                    onTap: () => sayfa(BepListView(
                      classModel: active!,
                      students: students,
                      teacher: profile,
                    )),
                  ),
                  const SizedBox(height: 10),
                  _GuidanceCard(
                    key: const ValueKey('rehberlik_dosyasi'),
                    isDark: isDark,
                    icon: Icons.folder_shared_outlined,
                    color: const Color(0xFF6366F1),
                    title: 'Rehberlik Dosyası',
                    subtitle: 'Plan, haftalık kayıtlar, listeler, risk haritası, raporlar',
                    neden: rehberDegil,
                    onTap: () => sayfa(RehberlikDosyasiScreen(classModel: active!)),
                  ),
                  const SizedBox(height: 10),
                  _GuidanceCard(
                    key: const ValueKey('rehberlik_formlar'),
                    isDark: isDark,
                    icon: Icons.description_outlined,
                    color: const Color(0xFF3B82F6),
                    title: 'Formlar',
                    subtitle:
                        'Görüşme formları, tanıma fişi, gezi izni, risk haritası',
                    neden: ogrenciYok,
                    onTap: () => CounselingInterviewModal.show(
                      context,
                      classModel: active!,
                      students: students,
                      teacherProfile: profile,
                    ),
                  ),
                ],
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
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    super.key,
    required this.isDark,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.neden,
  });

  final bool isDark;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Kart kullanılamıyorsa nedeni; kart soluk durur, neden altında yazar.
  final String? neden;

  @override
  Widget build(BuildContext context) {
    final pasif = neden != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: pasif ? 0.5 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: pasif ? null : onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
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
        ),
        if (pasif)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: _EmptyHint(isDark: isDark, text: neden!),
          ),
      ],
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
