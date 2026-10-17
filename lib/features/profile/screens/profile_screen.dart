import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_surumu.dart';
import '../../../core/backup/yedek_penceresi.dart';
import '../../../core/privacy/veri_saklama_metni.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import 'about_screen.dart';
import '../../auth_profile/presentation/views/teacher_profile_setup_view.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../auth_profile/presentation/views/school_admin_panel_view.dart';
import '../../auth_profile/presentation/views/school_admin_request_view.dart';
import '../../auth_profile/providers/user_role_provider.dart';
import '../../board_config/presentation/tahta_kilidi_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../parent_portal/presentation/widgets/help_support_modal.dart';

/// SınıfCepte - Ben sekmesi (profil, okul, yedek, ayarlar, yardım).
///
/// ## Tek yer (17 Ekim 2026)
/// Üç çizgili menüdeki "Veri Yedekleme", "Veri Gizliliği" ve "Ayarlar"
/// buraya toplandı; menü kalktı. Gizlilik politikası Hakkında'da.
/// Profil kartının altındaki "Profil ve Mesleki Bilgiler" satırı da kalktı:
/// kartın kendisiyle aynı ekranı açıyordu.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacherProfile = ref.watch(teacherProfileProvider);
    // Yönetici yetkisi custom claim'den gelir; yerel tercihten değil.
    final roleState = ref.watch(userRoleProvider);

    void ac(Widget hedef) => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => hedef),
        );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Öğretmen Bilgi Kartı (Tıklanınca Düzenleme Ekranı Açılır)
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: InkWell(
                  onTap: () => ac(const TeacherProfileSetupView()),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          teacherProfile.gender == 'Kadın'
                              ? Icons.face_3_rounded
                              : Icons.person_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    teacherProfile.fullName.isNotEmpty
                                        ? teacherProfile.fullName
                                        : 'Öğretmen Profili',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Okul idaresince doğrulanmış öğretmen rozeti.
                                // Bir KAPI değil, ROZET: doğrulanmamış
                                // öğretmen de tüm özellikleri kullanır.
                                if (teacherProfile.isVerifiedBySchoolAdmin) ...[
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message: 'Okul idaresince doğrulandı',
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 17,
                                      color: Colors.blue.shade400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${teacherProfile.branch} • ${teacherProfile.fullSchoolTitle.isNotEmpty ? teacherProfile.fullSchoolTitle : teacherProfile.schoolName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Düzenlemek İçin Dokunun ✏️',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.edit_rounded,
                        color: isDark ? Colors.white54 : Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              _baslik(isDark, 'Okul'),

              // Tahta Kilidi: öğretmen tarafı. Okul yöneticiliği kartından
              // ayrı: bu kart her öğretmene görünür, yöneticilik isteğe bağlı
              // bir ek yetkidir.
              _satir(
                isDark,
                ikon: Icons.desktop_windows_outlined,
                renk: AppColors.primary,
                baslik: 'Tahta Kilidi',
                altBaslik: 'Etkileşimli tahtayı telefonunuzla açın',
                onTap: () => ac(const TahtaKilidiScreen()),
              ),
              const SizedBox(height: 12),

              // Okul Yöneticiliği
              //
              // Yönetici rolü opsiyoneldir: yöneticisi olmayan okullarda
              // uygulamanın tamamı normal çalışır. Kart, kullanıcının
              // durumuna göre başvuru veya panel açar.
              _satir(
                isDark,
                ikon: Icons.admin_panel_settings_rounded,
                renk: roleState.isSchoolAdmin
                    ? const Color(0xFF10B981)
                    : AppColors.primary,
                baslik: roleState.isSchoolAdmin
                    ? 'Okul Yönetim Paneli'
                    : 'Okul Yöneticiliği Başvurusu',
                altBaslik: roleState.isSchoolAdmin
                    ? 'Öğretmen onayı ve veli şikâyetleri'
                    : 'İsteğe bağlı — onay olmadan da tüm özellikler açık',
                onTap: () {
                  if (roleState.isSchoolAdmin) {
                    ac(const SchoolAdminPanelView());
                  } else {
                    SchoolAdminRequestView.show(context);
                  }
                },
              ),

              _baslik(isDark, 'Veriler ve ayarlar'),

              // Yedek eskiden yalnız üç çizgili menüdeydi (17 Ekim 2026).
              _satir(
                isDark,
                ikon: Icons.sd_storage_rounded,
                renk: AppColors.primary,
                baslik: 'Yedekle ve geri yükle',
                altBaslik: 'Sınıflar, öğrenciler ve fotoğraflar tek dosyada',
                onTap: () => yedekPenceresiniAc(context),
              ),
              const SizedBox(height: 12),

              // Tema TEK yerde: Ayarlar ekranı (açık, koyu, telefonunki).
              // Burada ayrıca "Karanlık Mod" anahtarı vardı; aynı ayarı ikinci
              // kapıdan değiştiriyordu ve "telefonun teması" seçeneğini
              // bilmiyordu (17 Ekim 2026).
              _satir(
                isDark,
                ikon: Icons.settings_rounded,
                renk: AppColors.accent,
                // Eskiden "Veritabanı yedekleme, dışa aktarma" yazıyordu;
                // o ekranda yedekleme hiç yoktu.
                baslik: 'Ayarlar',
                altBaslik: 'Tema ve uygulama sürümü',
                onTap: () => ac(const SettingsScreen()),
              ),

              _baslik(isDark, 'Yardım'),

              // `HelpSupportModal` yazılmıştı ama hiçbir yerden
              // açılmıyordu: kullanıcı takıldığında gidecek yeri yoktu.
              _satir(
                isDark,
                ikon: Icons.help_outline_rounded,
                renk: AppColors.accent,
                baslik: 'Yardım ve Destek',
                altBaslik: 'Sık sorulanlar ve bizimle iletişim',
                onTap: () => HelpSupportModal.show(
                  context,
                  userId: teacherProfile.id,
                  userRole: 'teacher',
                ),
              ),
              const SizedBox(height: 12),

              // Hakkında
              //
              // Kullanım Koşulları ve Gizlilik Politikası uygulamanın
              // hiçbir yerinde görünmüyordu. Play Store gizlilik
              // politikasını zorunlu tutuyor; KVKK ise kullanıcının
              // verisinin ne olduğunu okuyabilmesini gerektiriyor.
              //
              // Menüyü şişirmemek için tek başlık altında toplandılar.
              _satir(
                isDark,
                ikon: Icons.info_outline_rounded,
                renk: AppColors.primary,
                baslik: 'Hakkında',
                altBaslik: 'Kullanım koşulları, gizlilik politikası ve SSS',
                onTap: () => ac(const AboutScreen()),
              ),
              const SizedBox(height: 12),

              // Bilgi ve Destek Kartı
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'SınıfCepte v$uygulamaSurumu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      VeriSaklamaMetni.uzun,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  /// Bölüm başlığı. toUpperCase() YOK: Dart 'i'yi 'I' yapar.
  Widget _baslik(bool isDark, String metin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        metin,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
    );
  }

  /// Ben sekmesindeki tek tip satır: ikon, başlık, alt başlık, ok.
  Widget _satir(
    bool isDark, {
    required IconData ikon,
    required Color renk,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
  }) {
    final ikincil =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ikon, color: renk),
        ),
        title: Text(
          baslik,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        subtitle: Text(
          altBaslik,
          style: TextStyle(fontSize: 12, color: ikincil),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ikincil),
      ),
    );
  }
}
