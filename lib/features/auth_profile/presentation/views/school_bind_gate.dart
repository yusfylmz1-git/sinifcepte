import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../navigation/screens/main_navigation_screen.dart';
import '../../../schools/data/models/school_model.dart';
import '../../../schools/presentation/widgets/school_selection_modal.dart';
import '../../providers/teacher_profile_provider.dart';

/// Öğretmen kromuna tek giriş: kanonik okul bağı yoksa MainNavigation açılmaz.
class SchoolBindGate extends ConsumerStatefulWidget {
  const SchoolBindGate({super.key});

  @override
  ConsumerState<SchoolBindGate> createState() => _SchoolBindGateState();
}

class _SchoolBindGateState extends ConsumerState<SchoolBindGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      await ref.read(teacherProfileProvider.notifier).ensureLoaded();
    } catch (e, stackTrace) {
      debugPrint('SchoolBindGate hydrate hatası: $e\n$stackTrace');
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _bindSchool(SchoolModel school) async {
    final current = ref.read(teacherProfileProvider);
    final updated = current.copyWith(
      schoolName: school.name,
      schoolId: school.id,
      city: school.city,
      district: school.district,
      schoolType: school.type,
    );
    await ref.read(teacherProfileProvider.notifier).saveProfile(updated);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = ref.watch(teacherProfileProvider);
    if (profile.isSchoolBound) {
      return const MainNavigationScreen();
    }

    return _ForcedSchoolBindScreen(onSchoolSelected: _bindSchool);
  }
}

class _ForcedSchoolBindScreen extends StatelessWidget {
  final Future<void> Function(SchoolModel school) onSchoolSelected;

  const _ForcedSchoolBindScreen({required this.onSchoolSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'Okulunuzu seçin',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SınıfCepte\'de öğretmen hesabınız bir okula bağlanmadan kullanılamaz. Listede yoksa “Okulumu ekle” ile onay kuyruğuna düşürebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await SchoolSelectionModal.show(
                      context,
                      dismissible: false,
                    );
                    if (picked != null) {
                      await onSchoolSelected(picked);
                    }
                  },
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Okul Dizininden Seç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
