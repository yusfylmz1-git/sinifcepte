import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/teacher_profile_model.dart';

/// SınıfCepte - Öğretmen Profil Durum Yöneticisi (Riverpod + SharedPrefs Persistence)
final teacherProfileProvider =
    StateNotifierProvider<TeacherProfileNotifier, TeacherProfileModel>((ref) {
  return TeacherProfileNotifier();
});

class TeacherProfileNotifier extends StateNotifier<TeacherProfileModel> {
  TeacherProfileNotifier()
      : super(
          const TeacherProfileModel(
            id: 'local_teacher',
            firstName: '',
            lastName: '',
            gender: 'Erkek',
            branch: '',
            schoolName: '',
            schoolPrincipalName: '',
            email: '',
          ),
        ) {
    loadProfileFromStorage();
  }

  Future<void>? _loadFuture;

  Future<void> ensureLoaded() {
    return _loadFuture ??= loadProfileFromStorage();
  }

  /// Yerel hafızadan profil yükleme
  Future<void> loadProfileFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('profil_ad') ?? state.firstName;
      final lastName = prefs.getString('profil_soyad') ?? state.lastName;
      final gender = prefs.getString('profil_cinsiyet') ?? state.gender;
      final branch = prefs.getString('profil_brans') ?? state.branch;
      final schoolName = prefs.getString('profil_okul') ?? state.schoolName;
      final city = prefs.getString('profil_il') ?? state.city;
      final district = prefs.getString('profil_ilce') ?? state.district;
      final schoolId = prefs.getString('profil_okul_id') ?? state.schoolId;
      final schoolType = prefs.getString('profil_okul_turu') ?? state.schoolType;
      final schoolPrincipalName = prefs.getString('profil_mudur') ?? state.schoolPrincipalName;
      final email = prefs.getString('profil_email') ?? state.email;
      final photoUrl = prefs.getString('profil_foto') ?? state.photoUrl;

      state = state.copyWith(
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        branch: branch,
        schoolName: schoolName,
        city: city,
        district: district,
        schoolId: schoolId,
        schoolType: schoolType,
        schoolPrincipalName: schoolPrincipalName,
        email: email,
        photoUrl: photoUrl,
      );
    } catch (e, stackTrace) {
      debugPrint('Profil SharedPreferences yükleme hatası: $e\n$stackTrace');
    }
  }

  /// Profil bilgilerini kaydetme
  Future<bool> saveProfile(TeacherProfileModel updated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profil_ad', updated.firstName);
      await prefs.setString('profil_soyad', updated.lastName);
      await prefs.setString('profil_cinsiyet', updated.gender);
      await prefs.setString('profil_brans', updated.branch);
      await prefs.setString('profil_okul', updated.schoolName);
      if (updated.city != null) await prefs.setString('profil_il', updated.city!);
      if (updated.district != null) await prefs.setString('profil_ilce', updated.district!);
      if (updated.schoolId != null) await prefs.setString('profil_okul_id', updated.schoolId!);
      if (updated.schoolType != null) await prefs.setString('profil_okul_turu', updated.schoolType!);
      await prefs.setString('profil_mudur', updated.schoolPrincipalName);
      await prefs.setString('profil_email', updated.email);
      if (updated.photoUrl != null) {
        await prefs.setString('profil_foto', updated.photoUrl!);
      }

      state = updated;
      return true;
    } catch (e, stackTrace) {
      debugPrint('Profil kaydetme hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Oturumu Kapat / Temizle
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      state = const TeacherProfileModel(
        id: 'local_teacher',
        firstName: '',
        lastName: '',
        gender: 'Erkek',
        branch: '',
        schoolName: '',
        schoolPrincipalName: '',
        email: '',
      );
    } catch (e, stackTrace) {
      debugPrint('Oturum kapatma hatası: $e\n$stackTrace');
    }
  }
}
