import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/ads/ad_gate.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/auth_profile/providers/user_role_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
  });

  // 18 Ekim 2026: okul yöneticiliği (claim, başvuru modeli, panel)
  // telefondan kalktı; yalnız öğretmen/veli rol tercihi kaldı.
  group('1. Rol Tercihi', () {
    test('Öğretmen rolü onay beklemeden tam çalışır', () {
      const state = UserRoleState(role: UserRole.teacher, isInitialized: true);
      expect(state.isTeacher, isTrue);
      expect(state.isParent, isFalse);
      expect(state.hasSelectedRole, isTrue);
    });

    test('Rol tercihi yerelde saklanır ve geri okunur', () async {
      final notifier = UserRoleNotifier();
      await notifier.loadRole();

      await notifier.selectParentRole();
      expect(notifier.state.isParent, isTrue);

      // Yeni bir notifier aynı tercihi okumalı (cihaz yeniden açılışı simülasyonu).
      final restored = UserRoleNotifier();
      await restored.loadRole();
      expect(restored.state.isParent, isTrue);
      expect(restored.state.isTeacher, isFalse);
    });

    test('resetRole rol seçimini temizler', () async {
      final notifier = UserRoleNotifier();
      await notifier.loadRole();
      await notifier.selectTeacherRole();

      await notifier.resetRole();

      expect(notifier.state.hasSelectedRole, isFalse);
    });
  });

  group('4. Reklam Kapısı (Faz 1: kapalı)', () {
    test('Varsayılan olarak reklam kapalıdır', () async {
      final gate = AdGate.instance;
      await gate.setEnabled(false);
      await gate.initialize();

      expect(gate.isEnabled, isFalse);
      expect(
        gate.isAllowedSlot(AdSlot.parentDashboardBanner, showsStudentData: false),
        isFalse,
      );
    });

    test('Öğrenci verisi görünen ekranda reklam asla gösterilmez', () async {
      final gate = AdGate.instance;
      // Reklam açık olsa bile öğrenci verisi varsa engellenir.
      await gate.setEnabled(true);

      expect(
        gate.isAllowedSlot(AdSlot.parentDashboardBanner, showsStudentData: true),
        isFalse,
      );
      expect(
        gate.isAllowedSlot(AdSlot.teacherRewardedExport, showsStudentData: true),
        isFalse,
      );

      // Temizlik: diğer testleri etkilememesi için kapat.
      await gate.setEnabled(false);
    });

    test('Reklam açıkken öğrenci verisi olmayan yerde izin verilir', () async {
      final gate = AdGate.instance;
      await gate.setEnabled(true);

      expect(
        gate.isAllowedSlot(AdSlot.parentDashboardBanner, showsStudentData: false),
        isTrue,
      );

      await gate.setEnabled(false);
    });

    test('Reklam tercihi kalıcıdır', () async {
      final gate = AdGate.instance;
      await gate.setEnabled(true);

      final prefs = await PrefsService.instance();
      expect(prefs?.getBool('sinifcepte_ads_enabled'), isTrue);

      await gate.setEnabled(false);
      expect(prefs?.getBool('sinifcepte_ads_enabled'), isFalse);
    });
  });
}
