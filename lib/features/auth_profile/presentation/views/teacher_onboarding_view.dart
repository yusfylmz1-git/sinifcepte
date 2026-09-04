import '../../../schools/providers/school_selector_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../schools/data/models/school_model.dart';
import '../../../schools/presentation/widgets/school_selection_modal.dart';
import '../../data/models/teacher_profile_model.dart';
import '../../data/services/teacher_branches.dart';
import '../../providers/teacher_profile_provider.dart';
import '../../../../core/utils/name_formatter.dart';

/// Öğretmenin ilk kurulumu: Ad-Soyad → Okul → Branş.
///
/// ## Neden bu sıra
/// Önceden yalnızca okul soruluyordu ve seçilir seçilmez uygulamaya
/// giriliyordu — yanlışlıkla bir okula basmak bile yeterliydi. Branş
/// hiç sorulmadığı için okul dizininde `branch: ""` kalıyor, sınıf
/// öğretmeni kadroya birini eklerken kimin hangi derse girdiğini
/// göremiyordu.
///
/// Branş listesi okulun türüne bağlıdır (ortaokulda "Fen Bilimleri",
/// lisede "Fizik/Kimya/Biyoloji"), bu yüzden okul branştan ÖNCE gelir.
/// Ad-soyad en başta: kullanıcı önce kendini tanıtır, ayrıca Google'dan
/// gelen ad bazen e-posta kullanıcı adıdır ve düzeltilmesi gerekir.
class TeacherOnboardingView extends ConsumerStatefulWidget {
  /// Kurulum tamamlandığında çağrılır.
  final Future<void> Function(TeacherProfileModel profile) onCompleted;

  /// Vazgeçip çıkış yapma.
  final VoidCallback onCancel;

  const TeacherOnboardingView({
    super.key,
    required this.onCompleted,
    required this.onCancel,
  });

  @override
  ConsumerState<TeacherOnboardingView> createState() =>
      _TeacherOnboardingViewState();
}

class _TeacherOnboardingViewState extends ConsumerState<TeacherOnboardingView> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _customBranch;

  SchoolModel? _school;
  String? _branch;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(teacherProfileProvider);
    _firstName = TextEditingController(text: profile.firstName);
    _lastName = TextEditingController(text: profile.lastName);
    _customBranch = TextEditingController();

    // Kayıtlı okulu geri yükle.
    //
    // Ekran her alanı boş başlatıyordu: branşı olmayan (kurulum ekranı
    // eklenmeden önce kaydolmuş) bir öğretmen buraya düştüğünde okulunu
    // yeniden seçmek zorunda kalıyordu — "yine okul soruyor" şikâyetinin
    // sebebi buydu. Oysa eksik olan yalnızca branştı.
    if (profile.isSchoolBound) {
      _school = SchoolModel(
        id: profile.schoolId ?? '',
        name: profile.schoolName,
        city: profile.city ?? '',
        district: profile.district ?? '',
        type: profile.schoolType ?? '',
      );

      // Eski kayıtlarda okul ADI boş kalmış (yalnızca kimlik ve şehir
      // saklanmış). Adı MEB listesinden tamamla; aksi hâlde ekranda boş
      // bir satır görünür ve kaydedilen ad da boş kalır.
      if (profile.schoolName.trim().isEmpty) {
        _restoreSchoolName(profile.schoolId ?? '', profile.city ?? '');
      }
    }

    // Kayıtlı branş listede varsa seçili gelsin; yoksa "Diğer" olarak
    // elle giriş alanına düşer.
    final savedBranch = profile.branch.trim();
    if (savedBranch.isNotEmpty && _school != null) {
      final options = TeacherBranches.forSchoolType(_school!.type);
      if (options.contains(savedBranch)) {
        _branch = savedBranch;
      } else {
        _branch = TeacherBranches.other;
        _customBranch.text = savedBranch;
      }
    }
  }

  /// Okul adını MEB listesinden tamamlar.
  Future<void> _restoreSchoolName(String schoolId, String city) async {
    if (schoolId.isEmpty || city.isEmpty) return;
    try {
      final found = await ref
          .read(schoolRepositoryProvider)
          .findById(schoolId: schoolId, city: city);
      if (found != null && mounted) {
        setState(() => _school = found);
      }
    } catch (e, stackTrace) {
      debugPrint('Okul adı geri yüklenemedi: $e\n$stackTrace');
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _customBranch.dispose();
    super.dispose();
  }

  bool get _nameReady =>
      _firstName.text.trim().isNotEmpty && _lastName.text.trim().isNotEmpty;

  /// Kaydedilecek branş; "Diğer" seçiliyse elle yazılan metin.
  String get _resolvedBranch {
    if (_branch == TeacherBranches.other) return _customBranch.text.trim();
    return _branch?.trim() ?? '';
  }

  bool get _canFinish =>
      _nameReady && _school != null && TeacherBranches.isValid(_resolvedBranch);

  Future<void> _pickSchool() async {
    final picked = await SchoolSelectionModal.show(context, dismissible: true);
    if (picked == null || !mounted) return;

    setState(() {
      _school = picked;
      // Okul değişince branş listesi de değişir; eski seçim geçersiz olabilir.
      _branch = null;
      _customBranch.clear();
    });
  }

  Future<void> _finish() async {
    if (!_canFinish || _saving) return;
    setState(() => _saving = true);

    try {
      final current = ref.read(teacherProfileProvider);
      final school = _school!;

      final updated = current.copyWith(
        // Standart yazim: "yusuf yilmaz" -> "Yusuf YILMAZ".
        firstName: NameFormatter.formatFirstName(_firstName.text),
        lastName: NameFormatter.formatLastName(_lastName.text),
        branch: _resolvedBranch,
        schoolName: school.name,
        schoolId: school.id,
        city: school.city,
        district: school.district,
        schoolType: school.type,
      );

      await widget.onCompleted(updated);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onCancel();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Profilinizi Tamamlayın',
            style: AppFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Çıkış'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Bu bilgiler veliye ve meslektaşlarınıza görünür. '
                'Sınıf kadrosuna eklenirken adınız ve branşınızla '
                'listelenirsiniz.',
                style: AppFonts.outfit(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 22),

              // --- 1. ADIM: Ad Soyad ---
              _StepHeader(
                step: 1,
                title: 'Ad ve Soyad',
                done: _nameReady,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      maxLength: 40,
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ad',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      maxLength: 40,
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Soyad',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- 2. ADIM: Okul ---
              _StepHeader(
                step: 2,
                title: 'Okul',
                done: _school != null,
                isDark: isDark,
                // Ad girilmeden okul seçilemez: adım sırası korunur.
                enabled: _nameReady,
              ),
              const SizedBox(height: 10),
              _SelectorTile(
                icon: Icons.school_rounded,
                label: _school?.name ?? 'MEB dizininden okul seçin',
                subtitle: _school == null
                    ? null
                    : '${_school!.district} / ${_school!.city} · ${_school!.type}',
                filled: _school != null,
                enabled: _nameReady,
                isDark: isDark,
                onTap: _pickSchool,
              ),
              const SizedBox(height: 24),

              // --- 3. ADIM: Branş ---
              _StepHeader(
                step: 3,
                title: 'Branş',
                done: TeacherBranches.isValid(_resolvedBranch),
                isDark: isDark,
                enabled: _school != null,
              ),
              const SizedBox(height: 10),
              if (_school == null)
                Text(
                  'Branş listesi okulun türüne göre hazırlanır; '
                  'önce okulunuzu seçin.',
                  style: AppFonts.outfit(
                    fontSize: 12.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _branch,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Branşınız',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final b
                        in TeacherBranches.forSchoolType(_school!.type))
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (v) => setState(() => _branch = v),
                ),
                if (_branch == TeacherBranches.other) ...[
                  const SizedBox(height: 10),
                  TextField(
                    maxLength: 60,
                    controller: _customBranch,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Branşınızı yazın',
                      hintText: 'Örn: Denizcilik',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _canFinish && !_saving ? _finish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Kurulumu Tamamla',
                        style: AppFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final String title;
  final bool done;
  final bool isDark;
  final bool enabled;

  const _StepHeader({
    required this.step,
    required this.title,
    required this.done,
    required this.isDark,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? const Color(0xFF10B981)
        : (enabled ? AppColors.primary : Colors.grey);

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check_rounded, size: 16, color: color)
              : Text(
                  '$step',
                  style: AppFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: enabled
                ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _SelectorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool filled;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.filled,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: enabled ? AppColors.primary : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppFonts.outfit(
                        fontSize: 14,
                        fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                        color: enabled
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: enabled ? Colors.grey : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
