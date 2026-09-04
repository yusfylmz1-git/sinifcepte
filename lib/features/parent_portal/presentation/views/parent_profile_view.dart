import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../auth/screens/welcome_screen.dart';
import '../../data/models/parent_link_model.dart';
import '../../providers/parent_token_provider.dart';
import '../screens/parent_student_connect_screen.dart';
import '../widgets/parent_app_bar.dart';
import '../../../auth_profile/providers/user_role_provider.dart';
import '../widgets/help_support_modal.dart';

/// Profil sekmesi: veli bilgileri, bağlı çocuklar ve KVKK işlemleri.
class ParentProfileView extends ConsumerWidget {
  final List<ParentLinkModel> children;

  const ParentProfileView({super.key, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parent = children.first;

    return Column(
      children: [
        const ParentAppBar(title: 'Hesabım', subtitle: 'Profil'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _ProfileHeader(parent: parent, isDark: isDark),
              const SizedBox(height: 20),

              _Section(title: 'Bağlı Çocuklar', isDark: isDark),
              for (final child in children)
                _ChildRow(child: child, isDark: isDark),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.add_circle_outline_rounded,
                title: 'Çocuk Ekle',
                subtitle: 'Referans kodu ile yeni öğrenci bağla',
                color: AppColors.primary,
                isDark: isDark,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ParentStudentConnectScreen(),
                    ),
                  );
                  ref.invalidate(myConnectedChildrenProvider);
                },
              ),

              const SizedBox(height: 20),
              _Section(title: 'Gizlilik ve Veri', isDark: isDark),
              _ActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'KVKK Aydınlatma Metni',
                subtitle: 'Verileriniz nasıl işleniyor?',
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                onTap: () => _showKvkk(context, isDark),
              ),
              _ActionTile(
                icon: Icons.link_off_rounded,
                title: 'Bağlantıyı Kaldır',
                subtitle: 'Bir çocuğun bağını sonlandır',
                color: Colors.orange,
                isDark: isDark,
                onTap: () => _confirmUnlink(context, ref, isDark),
              ),

              const SizedBox(height: 20),
              _Section(title: 'Yardım', isDark: isDark),
              _ActionTile(
                icon: Icons.help_outline_rounded,
                title: 'Yardım ve Destek',
                subtitle: 'Sık sorulanlar ve bizimle iletişim',
                color: const Color(0xFF0EA5E9),
                isDark: isDark,
                onTap: () => HelpSupportModal.show(
                  context,
                  userId: parent.parentUserId,
                  userRole: 'parent',
                ),
              ),

              const SizedBox(height: 20),
              _Section(title: 'Oturum', isDark: isDark),
              _ActionTile(
                icon: Icons.logout_rounded,
                title: 'Çıkış Yap',
                subtitle: 'Hesabınızdan güvenle çıkın',
                color: Colors.redAccent,
                isDark: isDark,
                onTap: () => _confirmSignOut(context, ref),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'SınıfCepte · Veli Portalı',
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showKvkk(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KVKK Aydınlatma Metni',
                  style: AppFonts.outfit(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Text(
                // ESKI METIN YANLISTI: "bu veriler buluta aktarilmaz"
                // diyordu ama ogrencinin ADI en az uc koleksiyonda buluta
                // gidiyor (veli baglantilari, mesajlar, durum bildirimleri).
                // Yanlis beyan hukuki risk tasir; metin kodla dogrulanarak
                // yeniden yazildi.
                'Notlar, katılım değerlendirmeleri, devamsızlık ve veli '
                'telefonu YALNIZCA öğretmenin telefonunda kalır; sunucuya '
                'hiç gönderilmez.\n\n'
                'Buluta yalnızca iletişim için gerekenler çıkar: '
                'öğrencinin adı ve soyadı, sınıf ve okul adı, veli adı, '
                'mesaj ve duyuru içerikleri, randevu ve durum '
                'bildirimleri.\n\n'
                'Durum bildirimleri 30 gün, randevu kayıtları 90 gün sonra '
                'otomatik olarak silinir.\n\n'
                'Bağlantınızı istediğiniz zaman kaldırabilirsiniz; '
                'kaldırdığınızda sınıf duyurularına erişiminiz sona erer.',
                style: AppFonts.outfit(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Anladım'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) async {
    final selected = await showDialog<ParentLinkModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Hangi bağlantı kaldırılsın?',
            style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
        children: [
          for (final c in children)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text('${c.studentName} (${c.className})',
                  style: AppFonts.outfit(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,),
            ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bağlantı Kaldırılsın mı?'),
        content: Text(
          '${selected.studentName} ile bağlantınız sonlanacak. '
          'Sınıf duyurularını ve öğretmen mesajlarını artık göremezsiniz.\n\n'
          'Yeniden bağlanmak için öğretmenden yeni bir referans kodu '
          'istemeniz gerekir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(parentTokenRepositoryProvider);
    await repo.removeParentLink(
      selected.id,
      actorId: selected.parentUserId,
      actorRole: 'parent',
      reason: 'Veli kendi bağını kaldırdı (KVKK)',
    );
    ref.invalidate(myConnectedChildrenProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.studentName} bağlantısı kaldırıldı.')),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yapılsın mı?'),
        content: const Text(
          'Hesabınızdan çıkacaksınız. Çocuk bağlantılarınız silinmez; '
          'tekrar giriş yaptığınızda kaldığınız yerden devam edersiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(parentAuthServiceProvider).signOut();

    // Rol tercihini de sıfırla: aksi hâlde karşılama ekranı kaydedilmiş
    // "veli" rolüyle otomatik ilerliyor ve kullanıcı öğretmen/veli
    // seçimini bir daha göremiyordu.
    await ref.read(userRoleProvider.notifier).resetRole();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ParentLinkModel parent;
  final bool isDark;

  const _ProfileHeader({required this.parent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parent.parentName,
                  style: AppFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  parent.relation,
                  style: AppFonts.outfit(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  final ParentLinkModel child;
  final bool isDark;

  const _ChildRow({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.school_rounded, size: 19, color: AppColors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.studentName,
                  style: AppFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  '${child.className} · No: ${child.studentNumber}',
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    color: isDark
                        ? Colors.white54
                        : AppColors.textSecondaryLight,
                  ),
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
}

class _Section extends StatelessWidget {
  final String title;
  final bool isDark;

  const _Section({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        title,
        style: AppFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
