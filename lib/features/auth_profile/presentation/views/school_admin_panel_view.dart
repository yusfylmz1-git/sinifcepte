import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../board_config/presentation/tahta_yonetimi_screen.dart';
import '../../data/repositories/school_admin_repository.dart';
import '../../providers/teacher_profile_provider.dart';
import '../../providers/user_role_provider.dart';

/// Okul yöneticisi paneli.
///
/// ## Yöneticinin görebildikleri
/// - Okuluna başvuran öğretmenlerin doğrulama listesi
/// - Velilerden gelen içerik şikâyetleri
///
/// ## Yöneticinin göremedikleri (bilinçli sınır)
/// Öğretmenlerin sınıf içi notları, katılım yıldızları, quiz/rubrik
/// puanları, veli telefon numaraları ve öğretmen↔veli mesaj içerikleri.
/// Yetki genişlemesini baştan sınırlamak, sonradan daraltmaktan kolaydır;
/// KVKK açısından da doğru sınır budur.
class SchoolAdminPanelView extends ConsumerStatefulWidget {
  const SchoolAdminPanelView({super.key});

  @override
  ConsumerState<SchoolAdminPanelView> createState() =>
      _SchoolAdminPanelViewState();
}

class _SchoolAdminPanelViewState extends ConsumerState<SchoolAdminPanelView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = SchoolAdminRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleState = ref.watch(userRoleProvider);
    final teacher = ref.watch(teacherProfileProvider);

    // Yetki kaynağı custom claim'dir; başvuru kaydı tek başına yetmez.
    if (!roleState.isSchoolAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Okul Yönetimi')),
        body: _buildNoAccess(isDark),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Okul Yönetimi', style: AppFonts.outfit(fontSize: 17)),
            Text(
              teacher.schoolName,
              style: AppFonts.outfit(fontSize: 11.5, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // Tahta Yönetimi ayrı bir ekran (sekme değil): nöbetçi takvimi
        // ve duyuru formu geniş alan istiyor. Giriş noktası buraya
        // konuldu çünkü idareci zaten bu paneldedir; ayrı bir gezinme
        // noktası aramak zorunda kalmasın.
        actions: [
          IconButton(
            tooltip: 'Tahta Yönetimi',
            icon: const Icon(Icons.desktop_windows_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TahtaYonetimiScreen(),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          labelStyle: AppFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: '👨‍🏫 Öğretmen Onayı'),
            Tab(text: '🚩 Şikâyetler'),
          ],
        ),
      ),
      // Yetkinin KAPSAMI claim'den okunur, yerel profilden değil.
      //
      // `firestore.rules` içindeki `isSchoolAdminOf(schoolId)`
      // `request.auth.token.schoolId` ile karar veriyor. Yerel profil
      // bir tercih dosyasıdır ve okul değişikliğinden sonra claim ile
      // ayrışabilir; ayrıştığında panel, sunucunun reddedeceği bir
      // okulun kayıtlarını istemeye çalışır ve kullanıcı sebebini
      // anlamaz. Claim boşsa (eski oturum, token henüz yenilenmemiş)
      // profile düşülür.
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeachersTab(isDark, _yetkiliOkulId(roleState, teacher.schoolId)),
          _buildReportsTab(isDark, _yetkiliOkulId(roleState, teacher.schoolId)),
        ],
      ),
    );
  }

  /// Yöneticiliğin geçerli olduğu okul kimliği.
  ///
  /// Öncelik custom claim'dedir: yetkiyi veren de kapsamı belirleyen de
  /// sunucudur. Claim henüz gelmemişse (token bir saate kadar eski
  /// kalabiliyor) yerel profil kullanılır; bu durumda sunucu yine son
  /// sözü söyler ve yetkisiz istek reddedilir.
  String _yetkiliOkulId(UserRoleState roleState, String? profilOkulId) {
    if (roleState.adminSchoolId.isNotEmpty) return roleState.adminSchoolId;
    return profilOkulId ?? '';
  }

  Widget _buildNoAccess(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'Bu panel yalnızca onaylı okul yöneticilerine açıktır',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Başvurunuz onaylandıysa çıkış yapıp tekrar giriş yapmayı deneyin; '
              'yetki bilgisi oturum tazelendiğinde güncellenir.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref
                  .read(userRoleProvider.notifier)
                  .refreshClaims(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Yetkiyi yenile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachersTab(bool isDark, String schoolId) {
    return FutureBuilder(
      future: _repo.pendingRequestsForSchool(schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final requests = snapshot.data ?? const [];
        if (requests.isEmpty) {
          return _emptyState(
            icon: Icons.how_to_reg_rounded,
            title: 'Bekleyen başvuru yok',
            body: 'Okulunuzdaki öğretmenler yöneticilik başvurusu yaptığında '
                'burada görünür.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, idx) {
            final r = requests[idx];
            final dateStr = DateFormat('dd.MM.yyyy').format(r.requestedAt);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.teacherName,
                          style: AppFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: AppFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (r.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      r.note,
                      style: AppFonts.outfit(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Yöneticilik onayı süper admin tarafından verilir.',
                            style: AppFonts.outfit(
                              fontSize: 11.5,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildReportsTab(bool isDark, String schoolId) {
    return FutureBuilder(
      future: _repo.fetchReports(schoolId: schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final reports = snapshot.data ?? const [];
        if (reports.isEmpty) {
          return _emptyState(
            icon: Icons.flag_outlined,
            title: 'Şikâyet bulunmuyor',
            body: 'Veliler uygunsuz içerik bildirdiğinde burada görünür.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, idx) {
            final rep = reports[idx];
            final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(rep.reportedAt);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: rep.isOpen
                      ? Colors.redAccent.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        rep.isOpen
                            ? Icons.flag_rounded
                            : Icons.check_circle_rounded,
                        size: 17,
                        color: rep.isOpen
                            ? Colors.redAccent
                            : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rep.contentType,
                          style: AppFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: AppFonts.outfit(
                          fontSize: 10.5,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Gerekçe: ${rep.reason}',
                    style: AppFonts.outfit(
                      fontSize: 12.5,
                      height: 1.35,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (rep.contentSnippet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        rep.contentSnippet,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
