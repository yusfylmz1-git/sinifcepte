import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/storage/prefs_keys.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/auth_profile/providers/user_role_provider.dart';

/// Çıkış akışı, hesap değiştirmenin ön koşuludur.
///
/// Tek cihazda hem öğretmen hem veli rolünü denemek isteyen kullanıcı
/// (ve gerçek hayatta hesap değiştiren kullanıcı) ancak oturum tamamen
/// kapanırsa başka bir Google hesabıyla girebilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
  });

  group('Rol sıfırlama', () {
    test('resetRole rol tercihini yerelden siler', () async {
      final notifier = UserRoleNotifier();
      await notifier.loadRole();
      await notifier.selectTeacherRole();

      final prefs = await PrefsService.instance();
      expect(prefs?.getString(PrefsKeys.activeUserRole), 'teacher');

      await notifier.resetRole();

      expect(notifier.state.hasSelectedRole, isFalse);
      expect(prefs?.getString(PrefsKeys.activeUserRole), isNull);
    });

    test('resetRole yönetici yetkisini de temizler', () async {
      final notifier = UserRoleNotifier();
      await notifier.loadRole();
      await notifier.selectTeacherRole();

      await notifier.resetRole();

      // Yeni hesap eski hesabın yöneticilik yetkisini devralmamalı.
      expect(notifier.state.adminStatus, SchoolAdminStatus.none);
      expect(notifier.state.isSuperAdmin, isFalse);
      expect(notifier.state.isSchoolAdmin, isFalse);
    });

    test('Çıkış sonrası yeni rol seçimi temiz başlar', () async {
      final notifier = UserRoleNotifier();
      await notifier.loadRole();

      // Öğretmen olarak gir, çık, veli olarak gir.
      await notifier.selectTeacherRole();
      await notifier.resetRole();
      await notifier.selectParentRole();

      expect(notifier.state.isParent, isTrue);
      expect(notifier.state.isTeacher, isFalse);

      // Cihaz yeniden açılsa da veli olarak kalmalı.
      final restored = UserRoleNotifier();
      await restored.loadRole();
      expect(restored.state.isParent, isTrue);
    });
  });

  group('Hesap değiştirme senaryosu', () {
    test('Rol tercihi silinince karşılama ekranına düşülür', () async {
      final notifier = UserRoleNotifier();
      await notifier.loadRole();
      await notifier.selectTeacherRole();
      await notifier.resetRole();

      // hasSelectedRole false ise WelcomeScreen otomatik yönlendirme yapmaz
      // ve kullanıcı rol seçim ekranında kalır.
      expect(notifier.state.hasSelectedRole, isFalse);
      expect(notifier.state.isInitialized, isTrue);
    });
  });
}
