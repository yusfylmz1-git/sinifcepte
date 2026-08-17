import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/storage/prefs_keys.dart';
import '../data/services/auth_claims_service.dart';

/// SınıfCepte Kullanıcı Rolleri
enum UserRole {
  teacher, // Öğretmen
  parent,  // Veli
  none,    // Henüz seçim yapılmadı
}

/// Okul yöneticiliği başvuru/onay durumu.
///
/// Yönetici rolü **opsiyoneldir**: yöneticisi olmayan okullarda uygulamanın
/// tamamı normal çalışır. Bu yüzden [UserRole] içine değil, ayrı bir eksen
/// olarak tutulur — bir kullanıcı hem öğretmen hem okul yöneticisi olabilir.
enum SchoolAdminStatus {
  none,     // Başvurmamış
  pending,  // Başvurdu, süper admin onayı bekliyor
  approved, // Onaylandı, yönetici paneline erişebilir
  rejected, // Başvurusu reddedildi
}

/// Aktif Kullanıcı Rol Durumu
class UserRoleState {
  final UserRole role;
  final bool isInitialized;

  /// Okul yöneticiliği durumu. Kaynağı Firebase custom claim'dir; yerel
  /// tercih olarak saklanmaz çünkü kullanıcı kendini yönetici ilan edememeli.
  final SchoolAdminStatus adminStatus;

  /// Süper admin (uygulama sahibi). Yalnızca custom claim ile verilir.
  final bool isSuperAdmin;

  const UserRoleState({
    required this.role,
    this.isInitialized = false,
    this.adminStatus = SchoolAdminStatus.none,
    this.isSuperAdmin = false,
  });

  bool get isTeacher => role == UserRole.teacher;
  bool get isParent => role == UserRole.parent;
  bool get hasSelectedRole => role != UserRole.none;

  /// Yönetici paneli yalnızca onaylanmış öğretmenlere açılır.
  bool get isSchoolAdmin =>
      role == UserRole.teacher && adminStatus == SchoolAdminStatus.approved;

  /// Başvuru butonunun gösterilip gösterilmeyeceği.
  bool get canApplyForSchoolAdmin =>
      role == UserRole.teacher &&
      (adminStatus == SchoolAdminStatus.none ||
          adminStatus == SchoolAdminStatus.rejected);

  UserRoleState copyWith({
    UserRole? role,
    bool? isInitialized,
    SchoolAdminStatus? adminStatus,
    bool? isSuperAdmin,
  }) {
    return UserRoleState(
      role: role ?? this.role,
      isInitialized: isInitialized ?? this.isInitialized,
      adminStatus: adminStatus ?? this.adminStatus,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    );
  }
}

/// SınıfCepte - Rol Yönetimi Notifier
class UserRoleNotifier extends StateNotifier<UserRoleState> {
  static const String _prefKey = PrefsKeys.activeUserRole;

  /// Kullanıcı bu oturumda açıkça rol seçtiyse, geç tamamlanan [loadRole]
  /// bu seçimi ezmemelidir. Aksi halde uygulama açılır açılmaz rol seçen
  /// kullanıcının seçimi, yapıcıdaki yükleme bittiğinde kayboluyordu.
  bool _roleExplicitlySelected = false;

  UserRoleNotifier() : super(const UserRoleState(role: UserRole.none)) {
    loadRole();
  }

  /// Kaydedilmiş rolü SharedPreferences'tan yükle.
  ///
  /// Yerelde tutulan yalnızca "hangi panele girmek istiyorum" tercihidir;
  /// yetki değildir. Yönetici/süper admin bilgisi [refreshClaims] ile
  /// sunucudan gelir.
  Future<void> loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRoleStr = prefs.getString(_prefKey);

      // Yükleme sürerken kullanıcı seçim yaptıysa onun kararı geçerlidir.
      if (_roleExplicitlySelected) {
        state = state.copyWith(isInitialized: true);
        return;
      }

      if (savedRoleStr == 'teacher') {
        state = state.copyWith(role: UserRole.teacher, isInitialized: true);
      } else if (savedRoleStr == 'parent') {
        state = state.copyWith(role: UserRole.parent, isInitialized: true);
      } else {
        state = state.copyWith(role: UserRole.none, isInitialized: true);
      }
    } catch (e, stackTrace) {
      debugPrint('Kullanıcı rolü yükleme hatası: $e\n$stackTrace');
      state = state.copyWith(isInitialized: true);
    }
  }

  /// Öğretmen rolünü seç ve kaydet
  Future<void> selectTeacherRole() async {
    await _setRole(UserRole.teacher);
  }

  /// Veli rolünü seç ve kaydet
  Future<void> selectParentRole() async {
    await _setRole(UserRole.parent);
  }

  /// Rolü sıfırla (Çıkış veya Rol Değiştirme)
  Future<void> resetRole() async {
    await _setRole(UserRole.none);
    state = state.copyWith(
      adminStatus: SchoolAdminStatus.none,
      isSuperAdmin: false,
    );
  }

  /// Yetki bilgisini Firebase custom claim'lerinden tazeler.
  ///
  /// Girişten sonra ve yönetici başvurusu onaylandığında çağrılır. Ağ yoksa
  /// mevcut durum korunur — offline-first ilkesi gereği uygulama çalışmaya
  /// devam eder, yalnızca yönetici paneli görünmez.
  Future<void> refreshClaims({bool forceRefresh = false}) async {
    try {
      final claims = await AuthClaimsService.instance.readClaims(
        forceRefresh: forceRefresh,
      );
      if (claims == null) return;

      state = state.copyWith(
        adminStatus: claims.schoolAdminStatus,
        isSuperAdmin: claims.isSuperAdmin,
      );
    } catch (e, stackTrace) {
      debugPrint('Rol claim tazeleme hatası: $e\n$stackTrace');
    }
  }

  Future<void> _setRole(UserRole newRole) async {
    _roleExplicitlySelected = newRole != UserRole.none;
    state = state.copyWith(role: newRole);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newRole == UserRole.none) {
        await prefs.remove(_prefKey);
      } else {
        await prefs.setString(_prefKey, newRole == UserRole.teacher ? 'teacher' : 'parent');
      }
    } catch (e, stackTrace) {
      debugPrint('Kullanıcı rolü kaydetme hatası: $e\n$stackTrace');
    }
  }
}

/// Global Kullanıcı Rol Sağlayıcısı
final userRoleProvider = StateNotifierProvider<UserRoleNotifier, UserRoleState>((ref) {
  return UserRoleNotifier();
});
