import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/account/hesap_silme_servisi.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/name_formatter.dart';
import '../../../auth/screens/welcome_screen.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../../parent_portal/providers/parent_token_provider.dart';
import '../../providers/teacher_profile_provider.dart';
import '../../providers/user_role_provider.dart';

enum HesapRolu { ogretmen, veli }

/// "Hesabımı sil" (Google Play şartı, KVKK m.7).
///
/// Silinecekler açıkça sayılır, onay için "SİL" yazılır. Bulut silinmeden
/// telefondaki veriye dokunulmaz: bulut hatasında öğretmen verisini
/// kaybetmesin. Bittiğinde oturum kapanır, karşılama ekranı açılır.
class HesapSilmeEkrani extends ConsumerStatefulWidget {
  const HesapSilmeEkrani({super.key, required this.rol, this.servis, this.uid});

  final HesapRolu rol;

  /// Testte sahte servis verilir.
  final HesapSilmeServisi? servis;

  /// Varsayılan: Firebase oturumundaki kullanıcı.
  final String? uid;

  @override
  ConsumerState<HesapSilmeEkrani> createState() => _HesapSilmeEkraniState();
}

class _HesapSilmeEkraniState extends ConsumerState<HesapSilmeEkrani> {
  final _onay = TextEditingController();
  bool _telefondanDaSil = true;
  bool _siliniyor = false;
  String? _hata;

  bool get _ogretmen => widget.rol == HesapRolu.ogretmen;
  bool get _onaylandi => trUpper(_onay.text.trim()) == HesapSilmeServisi.onaySozu;

  @override
  void dispose() {
    _onay.dispose();
    super.dispose();
  }

  List<String> get _silinenler => _ogretmen
      ? const [
          'Sınıflarınızın bulut kayıtları: duyurular, veli mesajları, randevular ve durum bildirimleri.',
          'Velilere verdiğiniz bağlantı kodları ve veli bağlantıları. Veliler sınıfınızı artık göremez.',
          'Okul dizinindeki adınız ve branşınız; kadrosunda olduğunuz sınıflardaki yazışmalarınız.',
          'Engelleme kayıtlarınız ve destek talepleriniz.',
          'SınıfCepte hesabınız. Google hesabınız silinmez.',
        ]
      : const [
          'Çocuklarınızla kurduğunuz bağlantılar.',
          'Öğretmenlerle yazışmalarınız, randevu ve durum bildirimleriniz, duyuru okuma işaretleriniz.',
          'Engelleme kayıtlarınız ve destek talepleriniz.',
          'SınıfCepte hesabınız. Google hesabınız silinmez.',
        ];

  Future<void> _sil() async {
    final uid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _hata = 'Oturum açık değil. Çıkış yapıp yeniden giriş yapın.');
      return;
    }
    setState(() {
      _siliniyor = true;
      _hata = null;
    });

    final sonuc = await (widget.servis ?? HesapSilmeServisi()).buluttanSil();
    if (!mounted) return;
    if (sonuc case HesapSilinemedi(:final mesaj)) {
      setState(() {
        _siliniyor = false;
        _hata = mesaj;
      });
      return;
    }

    if (_telefondanDaSil) {
      if (_ogretmen) {
        await HesapSilmeServisi.ogretmenVerisiniSil(uid);
      } else {
        await HesapSilmeServisi.veliVerisiniSil(uid);
      }
    }

    // Firebase hesabı sunucuda silindi; yerel oturum da kapanmalı.
    if (_ogretmen) {
      await ref.read(teacherProfileProvider.notifier).logout();
    } else {
      await ref.read(parentAuthServiceProvider).signOut();
    }
    await ref.read(userRoleProvider.notifier).resetRole();
    ref.invalidate(navigationIndexProvider);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
    messenger.showSnackBar(const SnackBar(content: Text('Hesabınız silindi.')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ikincil = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final birincil = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Scaffold(
      appBar: AppBar(title: const Text('Hesabımı sil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hesabınız ve buluttaki bütün kayıtlarınız kalıcı olarak silinir. '
                      'Bu işlem geri alınamaz.',
                      style: AppFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600, color: birincil),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Silinenler',
                style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: birincil)),
            const SizedBox(height: 8),
            for (final m in _silinenler)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.remove_circle_outline_rounded, size: 16, color: ikincil),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(m, style: AppFonts.outfit(fontSize: 13, height: 1.35, color: birincil)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Hakkınızda yapılmış içerik bildirimleri, kötüye kullanımı önlemek için '
              'incelenene kadar saklanır.',
              style: AppFonts.outfit(fontSize: 12, height: 1.35, color: ikincil),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              key: const ValueKey('hesap_sil_telefon'),
              value: _telefondanDaSil,
              onChanged: _siliniyor ? null : (v) => setState(() => _telefondanDaSil = v ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                _ogretmen
                    ? 'Bu telefondaki sınıf, öğrenci, not ve fotoğraf verilerini de sil'
                    : 'Bu telefondaki bağlantı ve bildirim kayıtlarını da sil',
                style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: birincil),
              ),
              subtitle: _ogretmen
                  ? Text(
                      'Silinen hesapla yeniden giriş yapılamaz; veriler telefonda kalsa da açılmaz. '
                      'Saklamak istiyorsanız önce Profil\'de "Verileri Yedekle" ile yedek alın.',
                      style: AppFonts.outfit(fontSize: 11.5, height: 1.35, color: ikincil),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('hesap_sil_onay'),
              controller: _onay,
              enabled: !_siliniyor,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Onaylamak için SİL yazın',
                border: OutlineInputBorder(),
              ),
            ),
            if (_hata != null) ...[
              const SizedBox(height: 12),
              Text(_hata!,
                  key: const ValueKey('hesap_sil_hata'),
                  style: AppFonts.outfit(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('hesap_sil_dugme'),
              onPressed: _onaylandi && !_siliniyor ? _sil : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _siliniyor
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever_rounded),
              label: Text(_siliniyor ? 'Siliniyor…' : 'Hesabımı kalıcı olarak sil'),
            ),
          ],
        ),
      ),
    );
  }
}
