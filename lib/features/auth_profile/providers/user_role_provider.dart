import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SınıfCepte Kullanıcı Rolleri
enum UserRole {
  teacher, // Öğretmen
  parent,  // Veli
  none,    // Henüz seçim yapılmadı
}

/// Aktif Kullanıcı Rol Durumu
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
  static const String _prefKey = 'sinifcepte_active_user_role';

  UserRoleNotifier() : super(const UserRoleState(role: UserRole.none)) {
    loadRole();
  }

  /// Kaydedilmiş rolü SharedPreferences'tan yükle
  Future<void> loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRoleStr = prefs.getString(_prefKey);

      if (savedRoleStr == 'teacher') {
        state = const UserRoleState(role: UserRole.teacher, isInitialized: true);
      } else if (savedRoleStr == 'parent') {
        state = const UserRoleState(role: UserRole.parent, isInitialized: true);
      } else {
        state = const UserRoleState(role: UserRole.none, isInitialized: true);
      }
    } catch (e, stackTrace) {
      debugPrint('Kullanıcı rolü yükleme hatası: $e\n$stackTrace');
      state = const UserRoleState(role: UserRole.none, isInitialized: true);
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
