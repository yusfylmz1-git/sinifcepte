import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth_profile/providers/user_role_provider.dart';
import '../../providers/parent_token_provider.dart';
import 'parent_dashboard_screen.dart';

/// Türkiye Telefon Numarası Maskeleme Formatlayıcısı
class _TurkishPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final trimmed = digitsOnly.length > 11 ? digitsOnly.substring(0, 11) : digitsOnly;
    final buffer = StringBuffer();

    if (trimmed.startsWith('0')) {
      for (int i = 0; i < trimmed.length; i++) {
        if (i == 1) buffer.write(' (');
        if (i == 4) buffer.write(') ');
        if (i == 7 || i == 9) buffer.write(' ');
        buffer.write(trimmed[i]);
      }
    } else {
      for (int i = 0; i < trimmed.length; i++) {
        if (i == 0) buffer.write('0 (');
        if (i == 3) buffer.write(') ');
        if (i == 6 || i == 8) buffer.write(' ');
        buffer.write(trimmed[i]);
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// SınıfCepte - Veli Kayıt & Öğrenci Bağlama Ekranı (ParentStudentConnectScreen)
class ParentStudentConnectScreen extends ConsumerStatefulWidget {
  final bool isAddingAnotherChild;

  const ParentStudentConnectScreen({
    super.key,
    this.isAddingAnotherChild = false,
  });

  @override
  ConsumerState<ParentStudentConnectScreen> createState() => _ParentStudentConnectScreenState();
}

class _ParentStudentConnectScreenState extends ConsumerState<ParentStudentConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _schoolNumberController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();

  String _selectedRelation = 'Anne';
  bool _isKvkkAccepted = false;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _relationOptions = [
    {'title': 'Anne', 'icon': Icons.family_restroom_rounded, 'color': Colors.pinkAccent},
    {'title': 'Baba', 'icon': Icons.person_outline_rounded, 'color': Colors.blueAccent},
    {'title': 'Vasi', 'icon': Icons.gavel_rounded, 'color': Colors.amber},
    {'title': 'Diğer', 'icon': Icons.handshake_outlined, 'color': Colors.purpleAccent},
  ];

  @override
  void dispose() {
    _tokenController.dispose();
    _schoolNumberController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  /// KVKK Aydınlatma Metni Modalı
  void _showKvkkDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'KVKK ve Gizlilik Aydınlatma Metni',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '6698 Sayılı Kişisel Verilerin Korunması Kanunu (KVKK) Uyarınca:',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Bu uygulama öğretmen ve veli arasındaki sınıf içi bilgilendirme ve acil durum iletişimini kolaylaştırmak amacıyla offline-first (yerel veri tabanı) mimarisiyle çalışır.\n\n'
                  '2. Çocuğunuza ait kişisel veriler ve okul numarası, yalnızca öğretmeniniz tarafından sağlanan güvenli referans kodu ve çift faktörlü doğrulama yoluyla eşleştirilir.\n\n'
                  '3. Velilerin iletişim bilgileri diğer velilerle paylaşılmaz; her veli yalnızca kendi çocuğunun gelişim raporlarına ve sınıf duyurularına erişebilir.\n\n'
                  '4. Dilediğiniz an bağlantınızı iptal edebilir ve unutulma hakkınızı kullanarak verilerinizin cihazdan silinmesini talep edebilirsiniz.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isKvkkAccepted = true;
              });
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Okudum, Kabul Ediyorum'),
          ),
        ],
      ),
    );
  }

  /// Öğrenciyi Doğrulama ve Bağlama İşlemi
  Future<void> _submitConnect() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isKvkkAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Lütfen devam etmek için KVKK metnini onaylayın.'),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(parentTokenRepositoryProvider);

      // 1. Token Doğrulama
      final inputCode = _tokenController.text.trim().toUpperCase();
      final inputNumber = _schoolNumberController.text.trim();

      final verifyResult = await repo.verifyToken(
        inputCode: inputCode,
        inputStudentNumber: inputNumber,
      );

      if (!verifyResult.isSuccess || verifyResult.token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = verifyResult.errorMessage ?? 'Referans kodu doğrulanamadı.';
        });
        return;
      }

      final validToken = verifyResult.token!;

      // 2. Veli Kullanıcı Kimliği Al / Oluştur
      final parentUserId = await repo.getOrCreateLocalParentUserId();

      // 3. Veli Bağlantısı Oluştur
      final link = await repo.linkParent(
        token: validToken,
        parentUserId: parentUserId,
        parentName: _parentNameController.text.trim(),
        parentPhone: _parentPhoneController.text.trim().isNotEmpty ? _parentPhoneController.text.trim() : null,
        relation: _selectedRelation,
      );

      if (link == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bağlantı kaydedilemedi. Lütfen tekrar deneyin.';
        });
        return;
      }

      // 4. Rolü Veli Olarak Kaydet ve Listeyi Yenile
      await ref.read(userRoleProvider.notifier).selectParentRole();
      ref.invalidate(myConnectedChildrenProvider);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 ${validToken.studentName} başarıyla bağlandı!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Dashboard'a yönlendir
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Veli bağlantı kurma hatası: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bağlantı sırasında bir hata oluştu. Lütfen bilgilerinizi kontrol edin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            size: 20,
          ),
          onPressed: () {
            if (widget.isAddingAnotherChild) {
              Navigator.of(context).pop();
            } else {
              ref.read(userRoleProvider.notifier).resetRole();
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          widget.isAddingAnotherChild ? 'Yeni Çocuk Ekle' : 'Veli Girişi & Öğrenci Bağlama',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Bilgilendirme Başlık Kartı
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Öğrencinize Bağlanın',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Öğretmeninizin size verdiği 8 haneli referans kodu ile sınıfa katılın.',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Hata Bildirimi (Varsa)
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.outfit(
                              color: Colors.redAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. Referans Kodu Alanı
                Text(
                  '🔑 Referans Kodu *',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tokenController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.firaCode(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Örn: SC-8A-9402',
                    hintStyle: GoogleFonts.firaCode(
                      fontSize: 14,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.primary),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen referans kodunu girin';
                    }
                    if (value.trim().length < 6) {
                      return 'Referans kodu en az 6 karakter olmalıdır';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // 3. İkinci Faktör Doğrulama: Öğrenci Okul No
                Text(
                  '🔒 Öğrenci Okul Numarası (2. Faktör Doğrulama) *',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _schoolNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Örn: 142',
                    prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen öğrencinin okul numarasını girin';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // 4. Veli Yakınlık Derecesi
                Text(
                  '👥 Yakınlık Dereceniz *',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _relationOptions.map((opt) {
                    final title = opt['title'] as String;
                    final isSelected = _selectedRelation == title;
                    final color = opt['color'] as Color;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRelation = title;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                opt['icon'] as IconData,
                                color: isSelected ? color : (isDark ? Colors.white54 : Colors.black45),
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // 5. Veli Ad Soyad
                Text(
                  '👤 Veli Adı Soyadı *',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _parentNameController,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Örn: Fatma Yılmaz',
                    prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen adınızı ve soyadınızı girin';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // 6. Veli Telefon Numarası (Opsiyonel)
                Text(
                  '📱 İletişim Telefon Numarası (İsteğe Bağlı)',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _parentPhoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_TurkishPhoneInputFormatter()],
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '0 (5XX) XXX XX XX',
                    prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 7. KVKK Onay Kutusu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _isKvkkAccepted,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      onChanged: (val) {
                        setState(() {
                          _isKvkkAccepted = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showKvkkDialog(context),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.35,
                              ),
                              children: const [
                                TextSpan(text: 'Kişisel verilerimin işlenmesine ilişkin '),
                                TextSpan(
                                  text: 'KVKK ve Gizlilik Aydınlatma Metni',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                TextSpan(text: '\'ni okudum ve onaylıyorum.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 8. Gönder / Bağlan Butonu
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.link_rounded, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Çocuğumu Bağla ve Sınıfa Katıl',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
