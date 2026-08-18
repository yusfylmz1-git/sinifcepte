import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/ads/ad_gate.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/auth_profile/data/models/school_admin_request_model.dart';
import 'package:sinifcepte/features/auth_profile/data/services/auth_claims_service.dart';
import 'package:sinifcepte/features/auth_profile/providers/user_role_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
  });

  group('1. Rol ve Yetki Modeli', () {
    test('Yönetici rolü opsiyoneldir: onaysız öğretmen tam yetkiyle çalışır', () {
      const state = UserRoleState(role: UserRole.teacher, isInitialized: true);

      // Öğretmen, yönetici onayı olmadan da öğretmendir.
      expect(state.isTeacher, isTrue);
      expect(state.isSchoolAdmin, isFalse);
      // Başvuru butonu görünmeli.
      expect(state.canApplyForSchoolAdmin, isTrue);
    });

    test('Yönetici paneli yalnızca onaylanmış öğretmene açılır', () {
      const pending = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.pending,
      );
      const approved = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.approved,
      );

      expect(pending.isSchoolAdmin, isFalse);
      expect(approved.isSchoolAdmin, isTrue);

      // Başvurusu beklemedeyken tekrar başvuramaz.
      expect(pending.canApplyForSchoolAdmin, isFalse);
      // Reddedilmişse yeniden başvurabilir.
      const rejected = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.rejected,
      );
      expect(rejected.canApplyForSchoolAdmin, isTrue);
    });

    test('Veli hiçbir koşulda okul yöneticisi olamaz', () {
      // Claim bozulsa/taklit edilse bile veli rolü yönetici paneli açmaz.
      const parentWithAdminClaim = UserRoleState(
        role: UserRole.parent,
        adminStatus: SchoolAdminStatus.approved,
      );

      expect(parentWithAdminClaim.isSchoolAdmin, isFalse);
      expect(parentWithAdminClaim.canApplyForSchoolAdmin, isFalse);
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

    test('resetRole yönetici yetkisini de temizler', () async {
      final notifier = UserRoleNotifier();
      await notifier.loadRole();
      await notifier.selectTeacherRole();

      await notifier.resetRole();

      expect(notifier.state.hasSelectedRole, isFalse);
      expect(notifier.state.adminStatus, SchoolAdminStatus.none);
      expect(notifier.state.isSuperAdmin, isFalse);
    });
  });

  group('2. Custom Claim Ayrıştırma', () {
    test('Süper admin ve moderatör claim rolleri doğru okunur', () {
      final superAdmin = AuthClaims.fromTokenClaims({'adminRole': 'super'});
      final moderator = AuthClaims.fromTokenClaims({'adminRole': 'moderator'});
      final normal = AuthClaims.fromTokenClaims({'role': 'parent'});

      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.isPortalAdmin, isTrue);

      expect(moderator.isSuperAdmin, isFalse);
      expect(moderator.isModerator, isTrue);
      expect(moderator.isPortalAdmin, isTrue);

      expect(normal.isPortalAdmin, isFalse);
    });

    test('Eksik veya bozuk claim güvenli varsayılana düşer', () {
      final empty = AuthClaims.fromTokenClaims({});
      final garbage = AuthClaims.fromTokenClaims({'adminRole': 'hacker'});

      expect(empty.isPortalAdmin, isFalse);
      expect(empty.schoolAdminStatus, SchoolAdminStatus.none);

      // Tanınmayan değer yetki vermez.
      expect(garbage.isPortalAdmin, isFalse);
    });

    test('schoolAdminStatus claim değeri enum karşılığına çevrilir', () {
      expect(
        AuthClaims.fromTokenClaims({'schoolAdminStatus': 'approved'}).schoolAdminStatus,
        SchoolAdminStatus.approved,
      );
      expect(
        AuthClaims.fromTokenClaims({'schoolAdminStatus': 'pending'}).schoolAdminStatus,
        SchoolAdminStatus.pending,
      );
      expect(
        AuthClaims.fromTokenClaims({'schoolAdminStatus': 'rejected'}).schoolAdminStatus,
        SchoolAdminStatus.rejected,
      );
    });
  });

  group('3. Okul Yöneticisi Başvuru Modeli', () {
    SchoolAdminRequestModel buildRequest({
      SchoolAdminStatus status = SchoolAdminStatus.pending,
    }) {
      return SchoolAdminRequestModel(
        id: 'req_1',
        teacherUid: 'uid_ahmet',
        teacherName: 'Ahmet Yılmaz',
        teacherEmail: 'ahmet@example.com',
        schoolId: 'meb_16_123456',
        schoolName: 'Cumhuriyet Ortaokulu',
        city: 'Bursa',
        district: 'Nilüfer',
        note: 'Müdür yardımcısıyım.',
        status: status,
        requestedAt: DateTime(2026, 8, 17),
      );
    }

    test('toMap ve fromMap kayıpsız dönüşüm yapar', () {
      final original = buildRequest();
      final restored = SchoolAdminRequestModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.teacherUid, original.teacherUid);
      expect(restored.schoolId, original.schoolId);
      expect(restored.status, SchoolAdminStatus.pending);
      expect(restored.requestedAt, original.requestedAt);
    });

    test('Okul başlığı il ve ilçeyle birlikte biçimlenir', () {
      expect(
        buildRequest().fullSchoolTitle,
        'Bursa / Nilüfer — Cumhuriyet Ortaokulu',
      );
    });

    test('Onay durumu ve Türkçe etiketler doğru döner', () {
      expect(buildRequest().isPending, isTrue);
      expect(buildRequest().statusText, 'Onay bekliyor');

      final approved = buildRequest(status: SchoolAdminStatus.approved);
      expect(approved.isApproved, isTrue);
      expect(approved.statusText, 'Onaylandı');
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
