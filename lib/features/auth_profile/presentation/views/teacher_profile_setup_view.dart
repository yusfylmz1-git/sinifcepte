import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../schools/presentation/widgets/school_selection_modal.dart';
import '../../providers/teacher_profile_provider.dart';
import '../../../auth/screens/welcome_screen.dart';
import '../../providers/user_role_provider.dart';
import '../../../../core/backup/backup_service.dart';
import '../../../../core/utils/name_formatter.dart';
import '../../../navigation/providers/navigation_provider.dart';

/// SınıfCepte - Öğretmen Profil Düzenleme & Ayarlar Ekranı
class TeacherProfileSetupView extends ConsumerStatefulWidget {
  const TeacherProfileSetupView({super.key});

  @override
  ConsumerState<TeacherProfileSetupView> createState() => _TeacherProfileSetupViewState();
}

class _TeacherProfileSetupViewState extends ConsumerState<TeacherProfileSetupView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _branchController;
  late TextEditingController _schoolNameController;
  late TextEditingController _schoolPrincipalController;
  late TextEditingController _emailController;

  String _selectedGender = 'Erkek';
  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedSchoolId;
  String? _selectedSchoolType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(teacherProfileProvider);

    _firstNameController = TextEditingController(text: profile.firstName);
    _lastNameController = TextEditingController(text: profile.lastName);
    _branchController = TextEditingController(text: profile.branch);
    _schoolNameController = TextEditingController(text: profile.schoolName);
    _schoolPrincipalController = TextEditingController(text: profile.schoolPrincipalName);
    _emailController = TextEditingController(text: profile.email);
    _selectedGender = profile.gender;
    _selectedCity = profile.city;
    _selectedDistrict = profile.district;
    _selectedSchoolId = profile.schoolId;
    _selectedSchoolType = profile.schoolType;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _branchController.dispose();
    _schoolNameController.dispose();
    _schoolPrincipalController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateName(String? value, String fieldName) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$fieldName alanı boş bırakılamaz';
    if (text.length < 2) return '$fieldName en az 2 karakter olmalıdır';
    return null;
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final currentProfile = ref.read(teacherProfileProvider);
        final updated = currentProfile.copyWith(
          // Standart yazim: "yusuf yilmaz" -> "Yusuf YILMAZ".
          firstName: NameFormatter.formatFirstName(_firstNameController.text),
          lastName: NameFormatter.formatLastName(_lastNameController.text),
          gender: _selectedGender,
          branch: _branchController.text.trim(),
          schoolName: _schoolNameController.text.trim(),
          city: _selectedCity,
          district: _selectedDistrict,
          schoolId: _selectedSchoolId,
          schoolType: _selectedSchoolType,
          schoolPrincipalName: _schoolPrincipalController.text.trim(),
          email: _emailController.text.trim(),
        );

        final success = await ref.read(teacherProfileProvider.notifier).saveProfile(updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Profil ve mesleki bilgiler başarıyla kaydedildi! 🚀'
                    : 'Kaydetme esnasında bir hata oluştu.',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } catch (e, stackTrace) {
        debugPrint('Profil kaydetme exception: $e\n$stackTrace');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// Veritabanini yedekleyip paylasim penceresini acar.
  ///
  /// Bulut yedeklemesi bilincli olarak yok: ogrenci notlari ve katilim
  /// cihazda kaliyor (KVKK karari). Yedegi nereye koyacagina ogretmen
  /// karar verir.
  Future<void> _yedekAl() async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Yedek hazırlanıyor...'),
        duration: Duration(seconds: 2),
      ),
    );

    final yol = await BackupService.instance.exportDatabase();

    if (!mounted) return;

    if (yol == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Yedek alınamadı. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final paylasildi = await BackupService.instance.shareBackup(yol);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          paylasildi
              ? 'Yedek dosyası paylaşıldı. Güvenli bir yerde saklayın.'
              : 'Yedek hazırlandı ancak paylaşılmadı.',
        ),
        backgroundColor: paylasildi ? const Color(0xFF10B981) : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: const CustomAppBar(
        title: 'Öğretmen Profili & Ayarlar',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Başlık Alanı
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 54,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Kişisel Bilgiler Kapsayıcısı
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kişisel Bilgiler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        maxLength: 40,
                        controller: _firstNameController,
                        validator: (v) => _validateName(v, 'Ad'),
                        decoration: const InputDecoration(
                          labelText: 'Ad',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        maxLength: 40,
                        controller: _lastNameController,
                        validator: (v) => _validateName(v, 'Soyad'),
                        decoration: const InputDecoration(
                          labelText: 'Soyad',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Cinsiyet Seçimi Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Cinsiyet',
                          prefixIcon: Icon(Icons.wc_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                          DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGender = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Mesleki & Evrak Bilgileri Kapsayıcısı
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Mesleki & Evrak Bilgileri',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bu bilgiler Zümre, Veli Toplantısı ve BEP gibi tüm resmî evraklara otomatik basılır.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        maxLength: 60,
                        controller: _branchController,
                        validator: (v) => _validateName(v, 'Branş'),
                        decoration: const InputDecoration(
                          labelText: 'Branş',
                          hintText: 'Örn: Matematik Öğretmeni',
                          prefixIcon: Icon(Icons.work_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Akıllı Okul Seçim Kartı (81 İl Dizinli)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.school_rounded, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'GÖREV YAPILAN OKUL',
                                      style: AppFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () async {
                                    final picked = await SchoolSelectionModal.show(context);
                                    if (picked != null) {
                                      setState(() {
                                        _schoolNameController.text = picked.name;
                                        _selectedCity = picked.city;
                                        _selectedDistrict = picked.district;
                                        _selectedSchoolId = picked.id;
                                        _selectedSchoolType = picked.type;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search_rounded, size: 13, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '81 İlden Seç',
                                          style: AppFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Okul Adı Metin Girişi
                            TextFormField(
                              controller: _schoolNameController,
                              readOnly: true,
                              onTap: () async {
                                final picked = await SchoolSelectionModal.show(context);
                                if (picked != null) {
                                  setState(() {
                                    _schoolNameController.text = picked.name;
                                    _selectedCity = picked.city;
                                    _selectedDistrict = picked.district;
                                    _selectedSchoolId = picked.id;
                                    _selectedSchoolType = picked.type;
                                  });
                                }
                              },
                              validator: (v) => _validateName(v, 'Okul Adı'),
                              style: AppFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Okulunuzu dizininden seçin',
                                prefixIcon: const Icon(Icons.apartment_rounded, size: 18),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.primary),
                                  tooltip: 'Okul Seçim Modalı',
                                  onPressed: () async {
                                    final picked = await SchoolSelectionModal.show(context);
                                    if (picked != null) {
                                      setState(() {
                                        _schoolNameController.text = picked.name;
                                        _selectedCity = picked.city;
                                        _selectedDistrict = picked.district;
                                        _selectedSchoolId = picked.id;
                                        _selectedSchoolType = picked.type;
                                      });
                                    }
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),

                            // İl & İlçe ve Tür Rozetleri
                            if (_selectedCity != null && _selectedCity!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669).withValues(alpha: isDark ? 0.25 : 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF059669)),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$_selectedCity${_selectedDistrict != null ? ' / $_selectedDistrict' : ''}',
                                          style: AppFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_selectedSchoolType != null && _selectedSchoolType!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _selectedSchoolType!,
                                        style: AppFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        maxLength: 80,
                        controller: _schoolPrincipalController,
                        validator: (v) => _validateName(v, 'Okul Müdürü Adı'),
                        decoration: const InputDecoration(
                          labelText: 'Okul Müdürü Ad-Soyad',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 3. İletişim & Oturum Bilgileri
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-posta & İletişim Bilgisi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        maxLength: 120,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta Adresi (İsteğe Bağlı)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Veri Yedekleme & Oturumu Kapat Butonları
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        // Bu dugme eskiden YALNIZCA bir mesaj gosteriyordu:
                        // "Veri Yedekleme Dosyasi Hazirlandi!" — hicbir dosya
                        // yazilmiyordu. Ogretmene "verin guvende" dedirtip
                        // telefonu bozuldugunda bir yili kaybettirecek bir
                        // yalandi. Artik gercekten yedek aliyor.
                        onPressed: _yedekAl,
                        icon: const Icon(Icons.backup_rounded),
                        label: const Text('Verileri Yedekle'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await ref.read(teacherProfileProvider.notifier).logout();
                          await ref.read(userRoleProvider.notifier).resetRole();

                          // Alt bar sekmesini sıfırla.
                          //
                          // Çıkış düğmesi PROFİL sekmesinde; sekme
                          // sıfırlanmazsa değer 4'te kalıyor ve tekrar
                          // girişte uygulama doğrudan profil ekranıyla
                          // açılıyordu.
                          ref.invalidate(navigationIndexProvider);

                          // Karşılama ekranına dön: profil ekranında kalmak
                          // kullanıcıyı boş bir formla baş başa bırakırdı.
                          if (!mounted) return;
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const WelcomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout_rounded, color: Colors.red),
                        label: const Text('Oturumu Kapat', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // KAYDET BUTONU
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'KAYDET VE GÜNCELLE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
