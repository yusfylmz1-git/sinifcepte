import 'package:flutter/material.dart';

import '../../../../core/storage/prefs_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// Velinin ilk açılışta gördüğü kısa tanıtım.
///
/// ## Neden gerekli
/// Veli uygulamaya giriyor ve **hiçbir yönlendirme almadan** kendi
/// başına anlamaya çalışıyordu. Sonuç: çalışan özellikler kullanılmıyor.
///
/// Somut örnek: randevu sistemi uçtan uca çalışıyor (veli talep açıyor,
/// öğretmen onaylıyor/reddediyor) ama veli tarafında ne olduğunu anlatan
/// tek bir cümle yoktu. Kullanıcı "buna gerek var mı?" diye sordu —
/// özellik kötü olduğu için değil, **görünmez olduğu için**.
///
/// Tanıtım bir kez gösterilir; kapatıldıktan sonra tekrar çıkmaz.
class ParentOnboardingScreen extends StatefulWidget {
  const ParentOnboardingScreen({super.key});

  /// Tanıtımın daha önce gösterilip gösterilmediğini tutan anahtar.
  static const String _seenKey = 'parent_onboarding_seen_v1';

  /// Tanıtım gösterilmeli mi?
  static Future<bool> shouldShow() async {
    try {
      final prefs = await PrefsService.instance();
      return !(prefs?.getBool(_seenKey) ?? false);
    } catch (_) {
      // Tercih okunamazsa tanıtımı göstermemek daha güvenli:
      // her açılışta tekrar çıkması sinir bozucu olurdu.
      return false;
    }
  }

  /// Tanıtımı görüldü olarak işaretler.
  static Future<void> markSeen() async {
    try {
      final prefs = await PrefsService.instance();
      await prefs?.setBool(_seenKey, true);
    } catch (_) {
      // Yazılamazsa bir sonraki açılışta tekrar çıkar; veri kaybı yok.
    }
  }

  @override
  State<ParentOnboardingScreen> createState() => _ParentOnboardingScreenState();
}

class _ParentOnboardingScreenState extends State<ParentOnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const List<_Step> _steps = [
    _Step(
      icon: Icons.key_rounded,
      title: 'Çocuğunuzu Ekleyin',
      body: 'Sınıf rehber öğretmeninden bir referans kodu isteyin. '
          'Kodu girdiğinizde çocuğunuzla bağlantınız kurulur.\n\n'
          'Birden fazla çocuğunuz varsa her biri için ayrı kod alırsınız. '
          'Anne ve baba ayrı ayrı bağlanabilir.',
    ),
    _Step(
      icon: Icons.campaign_rounded,
      title: 'Duyuruları Takip Edin',
      body: 'Öğretmenin sınıfa yaptığı duyurular Özet sekmesinde görünür. '
          'Sınav tarihleri, gezi bilgileri ve toplantı çağrıları buradan '
          'gelir.',
    ),
    _Step(
      icon: Icons.chat_bubble_rounded,
      title: 'Öğretmenle Yazışın',
      body: 'Mesajlar sekmesinden çocuğunuzun dersine giren öğretmenlere '
          'yazabilirsiniz.\n\n'
          'Öğretmenlerin akşam dinlenme saati vardır; gece geç saatte '
          'gönderilen mesajlar ertesi güne kalır.',
    ),
    _Step(
      icon: Icons.event_available_rounded,
      title: 'Randevu Alın',
      body: 'Yüz yüze görüşmek istediğinizde öğretmene randevu talebi '
          'gönderebilirsiniz. Tarih ve saat önerirsiniz, öğretmen '
          'onaylar veya başka bir zaman önerir.\n\n'
          'Onaylanan randevu Takvim sekmesinde durur — "ne zaman '
          'görüşecektik?" diye aramanıza gerek kalmaz.',
    ),
    _Step(
      icon: Icons.shield_rounded,
      title: 'Verileriniz Güvende',
      body: 'Çocuğunuzun notları, devamsızlığı ve katılım kayıtları '
          'yalnızca öğretmenin telefonunda kalır; sunucuya gönderilmez.\n\n'
          'Bu bilgiler için öğretmeninizle doğrudan görüşün.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ParentOnboardingScreen.markSeen();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sonSayfa = _page == _steps.length - 1;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Atla',
                  style: AppFonts.outfit(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _StepView(
                  step: _steps[i],
                  isDark: isDark,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final aktif = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: aktif ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: aktif
                        ? AppColors.primary
                        : (isDark ? Colors.white24 : Colors.black26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (sonSayfa) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    sonSayfa ? 'Başlayalım' : 'Devam',
                    style: AppFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step, required this.isDark});

  final _Step step;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 26),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: AppFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: AppFonts.outfit(
              fontSize: 13.5,
              height: 1.6,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
