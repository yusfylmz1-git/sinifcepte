import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/prefs_keys.dart';
import '../../../core/storage/prefs_service.dart';

/// SınıfCepte Kullanıcı Rolleri
enum UserRole {
  teacher, // Öğretmen
  parent,  // Veli
  none,    // Henüz seçim yapılmadı
}

/// Aktif Kullanıcı Rol Durumu
///
/// ## Okul yöneticiliği yok (18 Ekim 2026)
/// Burada bir de "okul yöneticisi" ekseni vardı (süper adminin onayladığı
/// custom claim). Telefondaki yönetici paneli öğretmen doğrulamıyordu:
/// yalnızca başka başvuruları ve hiç dolmayan şikâyet listesini
/// gösteriyordu. Kullanıcı kararıyla kalktı; okul yönetimi masaüstü Ana
/// Program'da.
class UserRoleState {
  final UserRole role;
  final bool isInitialized;

  const UserRoleState({
    required this.role,
    this.isInitialized = false,
  });

  bool get isTeacher => role == UserRole.teacher;
  bool get isParent => role == UserRole.parent;
  bool get hasSelectedRole => role != UserRole.none;

  UserRoleState copyWith({
    UserRole? role,
    bool? isInitialized,
  }) {
    return UserRoleState(
      role: role ?? this.role,
      isInitialized: isInitialized ?? this.isInitialized,
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
  /// yetki değildir. Yetkiyi sunucu kuralları verir (sınıf sahipliği,
  /// veli kodu, kadro).
  Future<void> loadRole() async {
    try {
      final prefs = await PrefsService.instance();
      final savedRoleStr = prefs?.getString(_prefKey);

      // Yükleme sürerken kullanıcı seçim yaptıysa onun kararı geçerlidir.
      if (_roleExplicitlySelected) {
        if (mounted) state = state.copyWith(isInitialized: true);
        return;
      }

      if (savedRoleStr == 'teacher') {
        if (mounted) state = state.copyWith(role: UserRole.teacher, isInitialized: true);
      } else if (savedRoleStr == 'parent') {
        if (mounted) state = state.copyWith(role: UserRole.parent, isInitialized: true);
      } else {
        if (mounted) state = state.copyWith(role: UserRole.none, isInitialized: true);
      }
    } catch (e, stackTrace) {
      debugPrint('Kullanıcı rolü yükleme hatası: $e\n$stackTrace');
      if (mounted) state = state.copyWith(isInitialized: true);
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
  }

  Future<void> _setRole(UserRole newRole) async {
    _roleExplicitlySelected = newRole != UserRole.none;
    state = state.copyWith(role: newRole);
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
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
