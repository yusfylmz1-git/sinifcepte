import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/auth_profile/data/services/auth_claims_service.dart';
import 'package:sinifcepte/features/auth_profile/providers/user_role_provider.dart';

/// Okul yöneticiliğinin KAPSAMI testleri.
///
/// ## Neden bu test var
///
/// `firestore.rules` içindeki `isSchoolAdminOf(schoolId)`,
/// `request.auth.token.schoolId` alanına dayanıyor ve sunucu bu alanı
/// onay sırasında yazıyor (`scripts/admin/approve_school_admin.mjs`).
/// Ama istemci tarafı bu alanı **hiç okumuyordu**: `AuthClaims`
/// `schoolId`'yi ayrıştırmıyordu ve yönetici hangi okulu yönettiğini
/// yerel profildeki `schoolName`'den tahmin ediyordu.
///
/// Profil yerel bir tercihtir; yetkinin kapsamıyla aynı olduğu garanti
/// değil. Okul panosu (`school_boards/{schoolId}`) yetkiyi bu alanla
/// sınırladığı için, kapsamın yetkiyle aynı yerden okunması şart.
void main() {
  group('AuthClaims schoolId ayrıştırma', () {
    test('KRİTİK: schoolId claim\'den okunur', () {
      // Sunucunun yazdığı biçim (approve_school_admin.mjs:117).
      final claims = AuthClaims.fromTokenClaims({
        'schoolAdminStatus': 'approved',
        'schoolId': 'meb_16_123456',
      });

      expect(claims.schoolId, 'meb_16_123456');
      expect(claims.schoolAdminStatus, SchoolAdminStatus.approved);
    });

    test('claim yoksa boş dize', () {
      final claims = AuthClaims.fromTokenClaims({});
      expect(claims.schoolId, '');
    });

    test('reddedilen başvuruda okul kapsamı taşınmaz', () {
      // Red sırasında script her iki claim'i de siliyor
      // (approve_school_admin.mjs:132-135).
      final claims = AuthClaims.fromTokenClaims({
        'schoolAdminStatus': 'rejected',
      });

      expect(claims.schoolId, '');
      expect(claims.schoolAdminStatus, SchoolAdminStatus.rejected);
    });

    test('mevcut claim\'ler bozulmaz', () {
      // Script diğer yetkileri koruyor; ayrıştırma da korumalı.
      final claims = AuthClaims.fromTokenClaims({
        'role': 'teacher',
        'adminRole': 'super',
        'schoolAdminStatus': 'approved',
        'schoolId': 'meb_34_999',
      });

      expect(claims.role, 'teacher');
      expect(claims.isSuperAdmin, isTrue);
      expect(claims.schoolId, 'meb_34_999');
    });
  });

  group('AuthClaims.isSchoolAdminOf', () {
    test('kendi okulunda yetkili', () {
      final claims = AuthClaims.fromTokenClaims({
        'schoolAdminStatus': 'approved',
        'schoolId': 'meb_16_1',
      });

      expect(claims.isSchoolAdminOf('meb_16_1'), isTrue);
    });

    test('KRİTİK: başka okulda yetkisiz', () {
      // Kuralların en önemli sınırı: bir okulun yöneticisi başka
      // okulun kaydına dokunamaz.
      final claims = AuthClaims.fromTokenClaims({
        'schoolAdminStatus': 'approved',
        'schoolId': 'meb_16_1',
      });

      expect(claims.isSchoolAdminOf('meb_34_999'), isFalse);
    });

    test('KRİTİK: onaysız başvuru yetki vermez', () {
      // Firestore'daki kaydın 'pending' olması yetki değildir.
      final claims = AuthClaims.fromTokenClaims({
        'schoolAdminStatus': 'pending',
        'schoolId': 'meb_16_1',
      });

      expect(claims.isSchoolAdminOf('meb_16_1'), isFalse);
    });

    test('KRİTİK: boş schoolId hiçbir okula yetki vermez', () {
      // Aksi halde boş dize karşılaştırması beklenmedik şekilde
      // eşleşebilirdi.
      final claims = AuthClaims.fromTokenClaims({
        'schoolAdminStatus': 'approved',
      });

      expect(claims.isSchoolAdminOf(''), isFalse);
      expect(claims.isSchoolAdminOf('meb_16_1'), isFalse);
    });
  });

  group('UserRoleState okul kapsamı', () {
    test('onaylı öğretmen kendi okulunda yetkili', () {
      const durum = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.approved,
        adminSchoolId: 'meb_16_1',
      );

      expect(durum.isSchoolAdmin, isTrue);
      expect(durum.isSchoolAdminOf('meb_16_1'), isTrue);
    });

    test('KRİTİK: başka okulda yetkisiz', () {
      const durum = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.approved,
        adminSchoolId: 'meb_16_1',
      );

      expect(durum.isSchoolAdminOf('meb_34_999'), isFalse);
    });

    test('KRİTİK: veli rolü yönetici olamaz', () {
      // `isSchoolAdmin` rolü de kontrol ediyor; kapsam tek başına
      // yeterli olmamalı.
      const durum = UserRoleState(
        role: UserRole.parent,
        adminStatus: SchoolAdminStatus.approved,
        adminSchoolId: 'meb_16_1',
      );

      expect(durum.isSchoolAdmin, isFalse);
      expect(durum.isSchoolAdminOf('meb_16_1'), isFalse);
    });

    test('varsayılan durumda kapsam boş', () {
      const durum = UserRoleState(role: UserRole.none);
      expect(durum.adminSchoolId, '');
      expect(durum.isSchoolAdminOf('meb_16_1'), isFalse);
    });

    test('copyWith kapsamı taşır', () {
      const durum = UserRoleState(role: UserRole.teacher);
      final yeni = durum.copyWith(
        adminStatus: SchoolAdminStatus.approved,
        adminSchoolId: 'meb_06_42',
      );

      expect(yeni.adminSchoolId, 'meb_06_42');
      expect(yeni.isSchoolAdminOf('meb_06_42'), isTrue);
    });

    test('copyWith verilmeyen alanı korur', () {
      const durum = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.approved,
        adminSchoolId: 'meb_16_1',
      );

      final yeni = durum.copyWith(isInitialized: true);
      expect(yeni.adminSchoolId, 'meb_16_1');
    });
  });
}
