import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../providers/user_role_provider.dart';

/// Firebase custom claim'lerinden okunan yetki bilgisi.
///
/// Bu değerler **yalnızca sunucu** tarafından (Admin SDK) yazılır; istemci
/// hiçbir koşulda değiştiremez. Yerel bir tercih dosyasına yazılmaz, aksi
/// halde kullanıcı kendini yönetici ilan edebilirdi.
class AuthClaims {
  /// Firestore kurallarındaki `request.auth.token.role` alanı.
  final String role;

  /// Firestore kurallarındaki `request.auth.token.adminRole` alanı.
  /// Beklenen değerler: 'super' | 'moderator' | '' (yok).
  final String adminRole;

  /// Okul yöneticiliği başvurusunun durumu.
  final SchoolAdminStatus schoolAdminStatus;

  /// Yöneticiliğin geçerli olduğu okul (`request.auth.token.schoolId`).
  ///
  /// Sunucu bu alanı onay sırasında yazıyor
  /// (`scripts/admin/approve_school_admin.mjs`) ve `firestore.rules`
  /// içindeki `isSchoolAdminOf(schoolId)` yetkiyi bununla sınırlıyor —
  /// bir okulun yöneticisi başka okulun kaydına dokunamaz.
  ///
  /// İstemci tarafı bu alanı **okumuyordu**: yönetici hangi okulu
  /// yönettiğini yerel profildeki `schoolName`'den tahmin ediyordu.
  /// Profil yerel bir tercih olduğu için yetkinin kapsamıyla aynı
  /// olduğu garanti değildi; okul değişikliğinden sonra ikisi
  /// ayrışabiliyordu. Yetkinin kapsamı yetkiyle aynı yerden okunmalı.
  final String schoolId;

  const AuthClaims({
    this.role = '',
    this.adminRole = '',
    this.schoolAdminStatus = SchoolAdminStatus.none,
    this.schoolId = '',
  });

  bool get isSuperAdmin => adminRole == 'super';
  bool get isModerator => adminRole == 'moderator';

  /// Admin portalına erişebilen herkes (süper admin veya moderatör).
  bool get isPortalAdmin => isSuperAdmin || isModerator;

  /// Bu kullanıcı verilen okulun onaylı yöneticisi mi?
  ///
  /// `firestore.rules` içindeki `isSchoolAdminOf` ile **aynı mantık**:
  /// onay durumu + okul eşleşmesi. İstemcide önden kontrol etmek,
  /// kullanıcıya reddedilecek bir işlemi hiç göstermemeyi sağlar;
  /// gerçek koruma yine sunucudadır.
  bool isSchoolAdminOf(String okulId) =>
      schoolAdminStatus == SchoolAdminStatus.approved &&
      schoolId.isNotEmpty &&
      schoolId == okulId;

  factory AuthClaims.fromTokenClaims(Map<String, dynamic> claims) {
    return AuthClaims(
      role: claims['role'] as String? ?? '',
      adminRole: claims['adminRole'] as String? ?? '',
      schoolAdminStatus: _parseAdminStatus(claims['schoolAdminStatus']),
      schoolId: claims['schoolId'] as String? ?? '',
    );
  }

  static SchoolAdminStatus _parseAdminStatus(Object? raw) {
    switch (raw as String? ?? '') {
      case 'approved':
        return SchoolAdminStatus.approved;
      case 'pending':
        return SchoolAdminStatus.pending;
      case 'rejected':
        return SchoolAdminStatus.rejected;
      default:
        return SchoolAdminStatus.none;
    }
  }
}

/// Firebase Auth custom claim okuyucusu.
///
/// Claim'ler ID token içinde taşınır. Token varsayılan olarak saatte bir
/// yenilenir; sunucu tarafında claim değiştiğinde (örneğin yönetici başvurusu
/// onaylandığında) [readClaims] `forceRefresh: true` ile çağrılmalıdır,
/// aksi halde kullanıcı bir saate kadar eski yetkiyle kalır.
class AuthClaimsService {
  AuthClaimsService._();

  static final AuthClaimsService instance = AuthClaimsService._();

  /// Oturum açmış kullanıcının claim'lerini okur.
  ///
  /// Firebase hazır değilse veya oturum yoksa `null` döner — çağıran taraf
  /// bu durumda mevcut yetkisiz durumu korumalıdır.
  Future<AuthClaims?> readClaims({bool forceRefresh = false}) async {
    try {
      if (!FirebaseBootstrap.ready) return null;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final tokenResult = await user.getIdTokenResult(forceRefresh);
      return AuthClaims.fromTokenClaims(tokenResult.claims ?? const {});
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AuthClaimsService.readClaims) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------------');
      return null;
    }
  }

  /// Oturum açmış kullanıcının Firebase UID'si (yoksa null).
  String? get currentUid =>
      FirebaseBootstrap.ready ? FirebaseAuth.instance.currentUser?.uid : null;

  /// Oturum açık mı?
  bool get isSignedIn => currentUid != null;
}
