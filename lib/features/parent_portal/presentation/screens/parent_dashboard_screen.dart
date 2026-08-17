import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/screens/welcome_screen.dart';
import '../../../auth_profile/providers/user_role_provider.dart';
import '../../../auth_profile/presentation/views/school_bind_gate.dart';
import '../../data/models/class_teacher_contact_model.dart';
import '../../data/models/parent_appointment_model.dart';
import '../../data/models/parent_link_model.dart';
import '../../data/models/parent_status_report_model.dart';
import '../../data/services/kvkk_consent_service.dart';
import '../../data/services/parent_lifecycle_service.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_portal_provider.dart';
import '../../providers/parent_token_provider.dart';
import '../widgets/help_support_modal.dart';

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

/// SınıfCepte - Veli Portalı & Öğrenci Yönetim Masası (ParentDashboardScreen)
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  // Hızlı Öğrenci Bağlama Form Controller'ları
  final _quickCodeCtrl = TextEditingController();
  final _quickStudentNoCtrl = TextEditingController();
  final _quickParentNameCtrl = TextEditingController();
  final _quickPhoneCtrl = TextEditingController();
  String _quickRelation = 'Anne';
  bool _quickKvkkAccepted = true;
  bool _isConnecting = false;

  @override
  void dispose() {
    _quickCodeCtrl.dispose();
    _quickStudentNoCtrl.dispose();
    _quickParentNameCtrl.dispose();
    _quickPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final childrenAsync = ref.watch(myConnectedChildrenProvider);
    final selectedIndex = ref.watch(selectedChildIndexProvider);
    final activeChild = ref.watch(activeSelectedChildProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Veli Yönetim Portalı',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'SınıfCepte Veli Masası & Güvenlik Köprüsü',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Destek ve Menü Butonu
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF10B981)),
            tooltip: 'Yardım & Destek',
            onPressed: () {
              HelpSupportModal.show(
                context,
                userId: activeChild?.parentUserId ?? 'parent_guest',
                userRole: 'parent',
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) async {
              if (value == 'export_data') {
                await _handleExportData(context, activeChild?.parentUserId ?? 'parent_guest');
              } else if (value == 'delete_account') {
                await _handleDeleteAccount(context, activeChild?.parentUserId ?? 'parent_guest');
              } else if (value == 'switch_teacher') {
                await ref.read(userRoleProvider.notifier).selectTeacherRole();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SchoolBindGate()),
                    (route) => false,
                  );
                }
              } else if (value == 'logout') {
                await ref.read(userRoleProvider.notifier).resetRole();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'export_data',
                child: Row(
                  children: const [
                    Icon(Icons.download_rounded, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Text('KVKK Verilerimi İndir (JSON)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'switch_teacher',
                child: Row(
                  children: const [
                    Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Text('Öğretmen Moduna Geç'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete_account',
                child: Row(
                  children: const [
                    Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Hesabımı & Verilerimi Sil', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, color: Colors.grey, size: 20),
                    SizedBox(width: 10),
                    Text('Çıkış Yap / Rol Değiştir'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text('Veriler yüklenemedi: $err', style: GoogleFonts.outfit(fontSize: 14)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(myConnectedChildrenProvider),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
        data: (children) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myConnectedChildrenProvider);
                if (activeChild != null) {
                  ref.invalidate(classAnnouncementsProvider(activeChild.classId));
                  ref.invalidate(studentStatusReportsProvider(activeChild.studentId));
                  ref.invalidate(classTeacherContactsProvider(activeChild.classId));
                  ref.invalidate(parentAppointmentsProvider(activeChild.parentUserId));
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (children.isEmpty) ...[
                      // --- ÖĞRENCİ HENÜZ EKLİ DEĞİLSE: YÖNETİM PANELİ VE HIZLI BAĞLAMA KARTI ---
                      _buildQuickConnectPortalView(context, isDark),
                    ] else ...[
                      // --- ÖĞRENCİ EKLİ İSE: ÇOKLU ÇOCUK SEÇİCİ & AKTİF DASHBOARD ---
                      _buildChildSelectorTabs(children, selectedIndex, isDark),

                      const SizedBox(height: 14),

                      if (activeChild != null)
                        _buildActiveChildCard(activeChild, isDark),

                      const SizedBox(height: 18),

                      Text(
                        '📱 Sınıf & Öğrenci Yönetim Modülleri',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildModuleGrid(context, activeChild, isDark),

                      const SizedBox(height: 20),

                      // Alt Hızlı Ekleme ve Bilgi Kartı
                      _buildAddAnotherChildCard(context, isDark),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ÖĞRENCİ HENÜZ EKLİ DEĞİLSE GÖSTERİLEN MODERN YÖNETİM PORTALI
  Widget _buildQuickConnectPortalView(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hoş Geldiniz Banner Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldiniz!',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Öğretmeninizin verdiği referans koduyla çocuğunuzun sınıfına anında bağlanın.',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Ortada Yer Alan Hızlı Öğrenci Bağlama Kartı
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Öğrencinizi Ekleyin',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Referans Kodu
              TextField(
                controller: _quickCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: InputDecoration(
                  labelText: '🔑 Veli Referans Kodu',
                  hintText: 'Örn: SC-8A-9402',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF10B981)),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Öğrenci Okul No (2. Faktör Doğrulama)
              TextField(
                controller: _quickStudentNoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '🔢 Öğrenci Okul Numarası (2. Faktör Güvenlik)',
                  hintText: 'Örn: 142',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF10B981)),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Veli Adı ve Yakınlık
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _quickParentNameCtrl,
                      decoration: InputDecoration(
                        labelText: '👤 Veli Adı Soyadı',
                        hintText: 'Örn: Ayşe Yılmaz',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _quickRelation,
                      decoration: InputDecoration(
                        labelText: 'Yakınlık',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Anne', child: Text('Anne')),
                        DropdownMenuItem(value: 'Baba', child: Text('Baba')),
                        DropdownMenuItem(value: 'Vasi', child: Text('Vasi')),
                        DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _quickRelation = v);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 4. Veli Telefon Numarası (İsteğe Bağlı)
              TextField(
                controller: _quickPhoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [_TurkishPhoneInputFormatter()],
                decoration: InputDecoration(
                  labelText: '📞 Veli Telefon Numarası (İsteğe Bağlı)',
                  hintText: '0 (5XX) XXX XX XX',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981)),
                  helperText: 'Acil durumlarda okul ve öğretmenin iletişime geçebilmesi içindir.',
                  helperMaxLines: 2,
                ),
              ),

              const SizedBox(height: 12),

              // 5. KVKK Onay Kutusu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _quickKvkkAccepted,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (v) => setState(() => _quickKvkkAccepted = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'KVKK Aydınlatma Metnini okudum; eğitim ve bilgilendirme süreçleri kapsamında verilerimin yerel olarak işlenmesine rıza gösteriyorum.',
                        style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 6. Bağlan Butonu
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _handleConnectStudent,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(_isConnecting ? 'Doğrulanıyor...' : 'Öğrenciyi Sınıfa Bağla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Referans Kodu Bilgilendirme Kartı
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Referans Kodu Nedir?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    Text(
                      'Sınıf öğretmeninizin ürettiği 8 haneli güvenli koddur. Kodunuz yoksa sınıf öğretmeninizden talep edebilirsiniz.',
                      style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleConnectStudent() async {
    final code = _quickCodeCtrl.text.trim();
    final studentNoStr = _quickStudentNoCtrl.text.trim();
    final parentName = _quickParentNameCtrl.text.trim();
    // Veli telefonu bilinçli olarak buluta gönderilmez: öğretmen ve veli
    // birbirinin numarasını görmez (KVKK + proje anayasası). Numara yalnızca
    // velinin kendi cihazında kalır.

    if (code.isEmpty || studentNoStr.isEmpty || parentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen referans kodu, okul numarası ve adınızı girin.')),
      );
      return;
    }

    if (!_quickKvkkAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen KVKK Aydınlatma onay kutusunu işaretleyin.')),
      );
      return;
    }

    final studentNo = int.tryParse(studentNoStr);
    if (studentNo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir okul numarası giriniz.')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      // Bağlama bulut üzerinden yapılır: öğretmenin ürettiği kod bu cihazda
      // bulunmadığı için doğrulama yerel depodan yapılamaz.
      final identity = ref.read(parentAuthServiceProvider).currentIdentity;
      final bridge = ref.read(parentLinkBridgeProvider);

      final bridgeResult = await bridge.verifyAndLink(
        inputCode: code,
        inputStudentNumber: studentNo.toString(),
        parentUid: identity?.uid ?? '',
        parentName: parentName,
        relation: _quickRelation,
      );

      // Bağ kurulduysa yerele önbellekle: ağ yokken de çocuk listesi görünsün.
      if (bridgeResult.success && bridgeResult.link != null) {
        await ref
            .read(parentTokenRepositoryProvider)
            .cacheParentLinkLocally(bridgeResult.link!);
      }

      final result = <String, dynamic>{
        'success': bridgeResult.success,
        'message': bridgeResult.message,
      };

      if (result['success'] == true) {
        // KVKK Kaydı — kalıcı Firebase UID'si ile (cihaz değişse de korunur)
        await KvkkConsentService.recordConsent(
          userId: identity?.uid ?? 'puser_${DateTime.now().millisecondsSinceEpoch}',
        );

        ref.invalidate(myConnectedChildrenProvider);
        _quickCodeCtrl.clear();
        _quickStudentNoCtrl.clear();
        _quickPhoneCtrl.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ${result['message']}'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result['message']}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Öğrenci bağlama hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  /// Çoklu Çocuk Seçici Sekmeleri
  Widget _buildChildSelectorTabs(List<ParentLinkModel> children, int selectedIndex, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ...children.asMap().entries.map((entry) {
            final idx = entry.key;
            final child = entry.value;
            final isSelected = idx == selectedIndex;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  ref.read(selectedChildIndexProvider.notifier).state = idx;
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.face_rounded,
                        size: 16,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${child.studentName} (${child.className})',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Aktif Çocuk Profil Kartı (Doğrulanmış Öğretmen Rozetli)
  Widget _buildActiveChildCard(ParentLinkModel child, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.face_6_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            child.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${child.studentNumber}',
                            style: GoogleFonts.firaCode(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${child.className} Sınıfı • ${child.relation}: ${child.parentName}',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (child.parentPhone != null && child.parentPhone!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_rounded, size: 10, color: Color(0xFF10B981)),
                                const SizedBox(width: 3),
                                Text(
                                  child.parentPhone!,
                                  style: GoogleFonts.firaCode(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Okul Adı & Doğrulanmış Güvenlik Rozeti
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  child.schoolName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Doğrulanmış Sınıf',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4 Ana Modül Kartı Grid Görünümü
  Widget _buildModuleGrid(BuildContext context, ParentLinkModel? child, bool isDark) {
    final modules = [
      {
        'title': 'Hızlı Durum Bildirimi',
        'subtitle': 'İlaç, geç kalma, acil not',
        'icon': Icons.medication_liquid_rounded,
        'color': const Color(0xFF10B981),
        'onTap': () => _showQuickStatusModal(context, child),
      },
      {
        'title': 'Sınıf Duyuruları',
        'subtitle': 'Okundu onaylı duyurular',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFFF59E0B),
        'onTap': () => _showAnnouncementsModal(context, child),
      },
      {
        'title': 'Öğretmen Kadrosu',
        'subtitle': 'Ders öğretmenleri & randevu',
        'icon': Icons.co_present_rounded,
        'color': const Color(0xFF3B82F6),
        'onTap': () => _showTeachersModal(context, child),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final item = modules[index];
        final color = item['color'] as Color;

        return InkWell(
          onTap: item['onTap'] as VoidCallback,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['subtitle'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Başka Bir Çocuk Ekleme / Hızlı Referans Kutusu
  Widget _buildAddAnotherChildCard(BuildContext context, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text(
                'Başka Bir Öğrenci Ekle',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir sınıfta veya okulda öğrenim gören diğer çocuğunuzu da aynı panelden yönetebilirsiniz.',
            style: GoogleFonts.outfit(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              _showAddChildModal(context);
            },
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: const Text('Yeni Öğrenci Referans Kodu Gir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10B981),
              side: const BorderSide(color: Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChildModal(BuildContext context) {
    final codeCtrl = TextEditingController();
    final noCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String relation = 'Anne';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Yeni Öğrenci Ekle', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Referans Kodu', hintText: 'Örn: SC-8B-1024'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Öğrenci Numarası', hintText: 'Örn: 205'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Veli Adı', hintText: 'Örn: Ayşe'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: relation,
                        decoration: const InputDecoration(labelText: 'Yakınlık'),
                        items: const [
                          DropdownMenuItem(value: 'Anne', child: Text('Anne')),
                          DropdownMenuItem(value: 'Baba', child: Text('Baba')),
                          DropdownMenuItem(value: 'Vasi', child: Text('Vasi')),
                          DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => relation = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_TurkishPhoneInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Telefon (İsteğe Bağlı)',
                    hintText: '0 (5XX) XXX XX XX',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final c = codeCtrl.text.trim();
                final n = int.tryParse(noCtrl.text.trim());
                final parentName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Veli';
                // Telefon buluta gönderilmez (KVKK): yalnızca velinin cihazında kalır.

                if (c.isNotEmpty && n != null) {
                  Navigator.of(ctx).pop();
                  final identity =
                      ref.read(parentAuthServiceProvider).currentIdentity;
                  final res =
                      await ref.read(parentLinkBridgeProvider).verifyAndLink(
                            inputCode: c,
                            inputStudentNumber: n.toString(),
                            parentUid: identity?.uid ?? '',
                            parentName: parentName,
                            relation: relation,
                          );
                  if (res.success && res.link != null) {
                    await ref
                        .read(parentTokenRepositoryProvider)
                        .cacheParentLinkLocally(res.link!);
                  }
                  ref.invalidate(myConnectedChildrenProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          res.success ? '✅ ${res.message}' : '⚠️ ${res.message}',
                        ),
                        backgroundColor:
                            res.success ? const Color(0xFF10B981) : Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL DİALOGLARI & MODERASYON ENTEGRASYONU ---

  void _showAnnouncementsModal(BuildContext context, ParentLinkModel? child) {
    if (child == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, modalRef, _) {
          // Duyurular buluttan gelir: öğretmenin yayımladığı duyuru bu
          // cihazda bulunmaz. Delta senkron sayesinde çoğu açılış sıfır
          // doküman okur.
          final announcementsAsync = modalRef.watch(cloudAnnouncementsProvider(child));

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_rounded, color: Color(0xFFF59E0B), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${child.className} Sınıfı Duyuruları',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: announcementsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Center(child: Text('Duyurular yüklenemedi: $e')),
                    data: (announcements) {
                      if (announcements.isEmpty) {
                        return Center(
                          child: Text('Sınıfta henüz yayınlanmış duyuru bulunmuyor.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: announcements.length,
                        itemBuilder: (context, idx) {
                          final a = announcements[idx];
                          final isRead = a.readByMe;
                          final dateStr = DateFormat('dd.MM.yyyy').format(a.createdAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: a.isUrgent ? Colors.redAccent.withValues(alpha: 0.5) : (isDark ? Colors.white12 : Colors.black12),
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
                                        Icon(a.priorityIcon, size: 16, color: a.priorityColor),
                                        const SizedBox(width: 6),
                                        Text(a.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                      ],
                                    ),
                                    Text(dateStr, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(a.content, style: GoogleFonts.outfit(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white70 : Colors.black87)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: isRead
                                          ? null
                                          : () async {
                                              // Veli yalnızca kendi okundu
                                              // kaydını yazar; duyuru
                                              // dokümanına dokunulmaz
                                              // (maliyet kararı #1).
                                              await ref.read(
                                                markAnnouncementReadProvider,
                                              )(
                                                link: child,
                                                announcementId: a.id,
                                              );
                                            },
                                      child: Row(
                                        children: [
                                          Icon(Icons.done_all_rounded, size: 16, color: isRead ? const Color(0xFF10B981) : AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            isRead ? 'Okundu Onaylandı' : 'Okundu Olarak Onayla',
                                            style: TextStyle(fontSize: 11.5, color: isRead ? const Color(0xFF10B981) : AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Şikayet Bildir Butonu (İçerik Moderasyonu)
                                    IconButton(
                                      icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.grey),
                                      tooltip: 'Uygunsuz İçerik Bildir',
                                      onPressed: () => _showReportContentDialog(
                                        context,
                                        child,
                                        contentId: a.id,
                                        contentTitle: a.title,
                                        contentSnippet: a.content,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// İçerik şikâyeti dialogu.
  ///
  /// Belirli bir duyuru modeline bağlı değildir: yalnızca kimlik, başlık ve
  /// içerik parçası alır. Böylece yerel ve bulut duyuru modellerinin ikisiyle
  /// de çalışır.
  void _showReportContentDialog(
    BuildContext context,
    ParentLinkModel child, {
    required String contentId,
    required String contentTitle,
    required String contentSnippet,
  }) {
    final reasonCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.flag_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('İçerik Şikayeti Bildir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duyuru: "$contentTitle"', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Şikayet Sebebiniz',
                hintText: 'Örn: Uygunsuz ifade, yanlış bilgi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isNotEmpty) {
                Navigator.of(ctx).pop();
                await KvkkConsentService.reportContent(
                  reportedByUserId: child.parentUserId,
                  reportedRole: 'parent',
                  contentId: contentId,
                  contentType: 'Duyuru',
                  contentSnippet: contentSnippet,
                  reason: reason,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Şikayetiniz okul idaresine iletildi.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Bildir'),
          ),
        ],
      ),
    );
  }

  void _showTeachersModal(BuildContext context, ParentLinkModel? child) {
    if (child == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, modalRef, _) {
          final teachersAsync = modalRef.watch(classTeacherContactsProvider(child.classId));

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.co_present_rounded, color: Color(0xFF3B82F6), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${child.className} Ders Öğretmenleri & Randevu',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: teachersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Center(child: Text('Öğretmenler yüklenemedi: $e')),
                    data: (teachers) {
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: teachers.length,
                        itemBuilder: (context, idx) {
                          final t = teachers[idx];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Color(0xFF3B82F6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(t.teacherName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 14),
                                        ],
                                      ),
                                      Text(t.branch, style: GoogleFonts.outfit(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule_rounded, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('${t.meetingDay} ${t.meetingTime}', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _openAppointmentRequestDialog(context, child, t),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Randevu Al', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openAppointmentRequestDialog(BuildContext context, ParentLinkModel child, ClassTeacherContactModel teacher) {
    final topicCtrl = TextEditingController(text: 'Ders gelişimi ve akademik değerlendirme');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Randevu Talebi Oluştur', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Öğretmen: ${teacher.teacherName} (${teacher.branch})', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Görüşme Saati: ${teacher.meetingDay} ${teacher.meetingTime}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: topicCtrl,
              decoration: const InputDecoration(labelText: 'Görüşme Konusu / Notu'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final repo = ref.read(parentPortalRepositoryProvider);
              final appointment = ParentAppointmentModel(
                id: 'app_${DateTime.now().millisecondsSinceEpoch}',
                classId: child.classId,
                className: child.className,
                studentId: child.studentId,
                studentName: child.studentName,
                studentNumber: child.studentNumber,
                parentUserId: child.parentUserId,
                parentName: child.parentName,
                relation: child.relation,
                teacherName: teacher.teacherName,
                branch: teacher.branch,
                appointmentDate: DateTime.now().add(const Duration(days: 2)),
                timeSlot: teacher.meetingTime,
                topic: topicCtrl.text.trim(),
                createdAt: DateTime.now(),
              );

              final result = await repo.requestAppointment(appointment);
              ref.invalidate(parentAppointmentsProvider(child.parentUserId));

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['success'] == true ? '✅ Randevu talebiniz iletildi.' : '⚠️ ${result['message']}'),
                    backgroundColor: result['success'] == true ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            child: const Text('Talebi Gönder'),
          ),
        ],
      ),
    );
  }

  void _showQuickStatusModal(BuildContext context, ParentLinkModel? child) {
    if (child == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, modalRef, _) {
          final reportsAsync = modalRef.watch(studentStatusReportsProvider(child.studentId));

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medication_liquid_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${child.studentName} İçin Hızlı Durum Bildirimi',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildQuickActionChip(
                        context,
                        child: child,
                        icon: Icons.medical_services_outlined,
                        label: '💊 İlaç Bildir',
                        type: 'medication',
                        defaultTitle: 'İlaç Kullanımı',
                        defaultDetails: 'Öğle saatinde içmesi gereken reçeteli ilacı var.',
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        context,
                        child: child,
                        icon: Icons.timer_outlined,
                        label: '⏳ Erken Çıkış',
                        type: 'early_leave',
                        defaultTitle: 'Erken Çıkış / Randevu',
                        defaultDetails: 'Doktor kontrolü sebebiyle dersten önce alınacak.',
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        context,
                        child: child,
                        icon: Icons.edit_note_rounded,
                        label: '📝 Özel Not',
                        type: 'note',
                        defaultTitle: 'Veli Notu',
                        defaultDetails: '',
                        isCustomPrompt: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text('📋 Gönderilen Bildirimler & Öğretmen Onayı', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: reportsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Center(child: Text('Bildirimler yüklenemedi: $e')),
                    data: (reports) {
                      if (reports.isEmpty) {
                        return Center(child: Text('Henüz gönderilmiş durum bildirimi yok.', style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey)));
                      }
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: reports.length,
                        itemBuilder: (context, idx) {
                          final r = reports[idx];
                          final timeStr = DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(r.typeIcon, size: 18, color: r.typeColor),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(r.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: r.isAcknowledged ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(r.isAcknowledged ? 'Görüldü ✅' : 'İletildi ⏳', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: r.isAcknowledged ? const Color(0xFF10B981) : Colors.orange)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(r.details, style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                                const SizedBox(height: 4),
                                Text(timeStr, style: GoogleFonts.outfit(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionChip(
    BuildContext context, {
    required ParentLinkModel child,
    required IconData icon,
    required String label,
    required String type,
    required String defaultTitle,
    required String defaultDetails,
    bool isCustomPrompt = false,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: const Color(0xFF10B981),
      onPressed: () {
        if (isCustomPrompt) {
          _showCustomNoteDialog(context, child, type);
        } else {
          _createAndSendReport(context, child, type: type, title: defaultTitle, details: defaultDetails);
        }
      },
    );
  }

  Future<void> _createAndSendReport(
    BuildContext context,
    ParentLinkModel child, {
    required String type,
    required String title,
    required String details,
  }) async {
    try {
      final repo = ref.read(parentPortalRepositoryProvider);
      final newReport = ParentStatusReportModel(
        id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
        studentId: child.studentId,
        studentName: child.studentName,
        studentNumber: child.studentNumber,
        classId: child.classId,
        className: child.className,
        parentUserId: child.parentUserId,
        parentName: child.parentName,
        relation: child.relation,
        type: type,
        title: title,
        details: details,
        createdAt: DateTime.now(),
      );

      await repo.createStatusReport(newReport);
      ref.invalidate(studentStatusReportsProvider(child.studentId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $title sınıf öğretmenine iletildi.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Durum bildirimi hatası: $e\n$stackTrace');
    }
  }

  void _showCustomNoteDialog(BuildContext context, ParentLinkModel child, String type) {
    final titleCtrl = TextEditingController(text: 'Veli Notu');
    final detailsCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Öğretmene Not İlet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Başlık')),
            const SizedBox(height: 10),
            TextField(controller: detailsCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Mesajınız')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final details = detailsCtrl.text.trim();
              if (details.isNotEmpty) {
                Navigator.of(ctx).pop();
                _createAndSendReport(context, child, type: type, title: title.isNotEmpty ? title : 'Veli Notu', details: details);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  // --- KVKK SELF-SERVICE İŞLEMLERİ ---

  Future<void> _handleExportData(BuildContext context, String parentUserId) async {
    final export = await ParentLifecycleService.exportParentDataAsJson(parentUserId);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('KVKK Veri Taşınabilirliği (JSON)'),
        content: SingleChildScrollView(
          child: Text(
            const JsonEncoder.withIndent('  ').convert(export),
            style: GoogleFonts.firaCode(fontSize: 10.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonEncode(export)));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Tüm veriler panoya kopyalandı!')),
              );
            },
            child: const Text('Panoya Kopyala'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context, String parentUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hesabımı ve Verilerimi Sil'),
        content: const Text(
          'KVKK Unutulma Hakkı kapsamında bağlı tüm çocuk bağlantılarınız, randevularınız ve bildirimleriniz cihazınızdan ve sistemden kalıcı olarak silinecektir. Bu işlem geri alınamaz.\n\nEmin misiniz?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ParentLifecycleService.deleteParentSelfAccount(parentUserId);
      await ref.read(userRoleProvider.notifier).resetRole();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }
}
