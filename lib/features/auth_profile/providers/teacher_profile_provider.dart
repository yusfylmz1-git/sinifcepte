import '../../../core/cloud/cloud_ids.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/prefs_service.dart';
import '../data/services/teacher_auth_service.dart';
import '../data/models/teacher_profile_model.dart';
import '../../../core/database/database_helper.dart';

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

  /// Profil anahtarlarını hesaba bağlar.
  ///
  /// Anahtarlar eskiden sabitti (`profil_okul` gibi). Bu yüzden cihazda
  /// tek bir profil tutuluyordu: ikinci hesapla girildiğinde okuyacak
  /// kayıt bulunamıyor ve okul yeniden soruluyordu. Artık her hesabın
  /// kendi anahtar seti vardır.
  ///
  /// [uid] boşsa eski (sabit) anahtar kullanılır: henüz giriş yapmamış
  /// ya da masaüstü yerel modundaki öğretmen için geçerli davranış budur.
  static String _key(String base, String uid) =>
      uid.isEmpty ? base : '${base}__$uid';

  /// O an açık olan hesabın kimliği.
  ///
  /// Profil henüz yüklenmemişken de doğru anahtarı bulabilmek için
  /// cihazda son çalışılan hesap kullanılır.
  Future<String> _activeUid() async {
    // DİKKAT: `state.id` başlangıçta 'local_teacher' yer tutucusudur —
    // boş DEĞİLDİR. Yalnızca `isNotEmpty` bakmak, profil yüklenmeden
    // önce anahtarı `profil_okul__local_teacher` yapıyor, o kayıt hiç
    // bulunmadığı için okul bilgisi okunamıyor ve kurulum ekranı her
    // açılışta yeniden çıkıyordu.
    if (CloudIds.isValidUid(state.id)) return state.id;
    try {
      return await DatabaseHelper.lastKnownUid();
    } catch (_) {
      return '';
    }
  }


  Future<void> ensureLoaded() {
    return _loadFuture ??= loadProfileFromStorage();
  }

  /// Yerel hafızadan profil yükleme
  /// Bellekteki güncel profil.
  ///
  ///  korumalı olduğu için servis katmanı okuyamıyordu.
  TeacherProfileModel get currentProfile => state;

  Future<void> loadProfileFromStorage() async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      final uid = await _activeUid();
      final savedId = prefs.getString(_key('profil_id', uid));
      final id = (savedId != null && savedId.isNotEmpty) ? savedId : state.id;
      final firstName = prefs.getString(_key('profil_ad', uid)) ?? state.firstName;
      final lastName = prefs.getString(_key('profil_soyad', uid)) ?? state.lastName;
      final gender = prefs.getString(_key('profil_cinsiyet', uid)) ?? state.gender;
      final branch = prefs.getString(_key('profil_brans', uid)) ?? state.branch;
      final schoolName = prefs.getString(_key('profil_okul', uid)) ?? state.schoolName;
      final city = prefs.getString(_key('profil_il', uid)) ?? state.city;
      final district = prefs.getString(_key('profil_ilce', uid)) ?? state.district;
      final schoolId = prefs.getString(_key('profil_okul_id', uid)) ?? state.schoolId;
      final schoolType = prefs.getString(_key('profil_okul_turu', uid)) ?? state.schoolType;
      final schoolPrincipalName = prefs.getString(_key('profil_mudur', uid)) ?? state.schoolPrincipalName;
      final email = prefs.getString(_key('profil_email', uid)) ?? state.email;
      final photoUrl = prefs.getString(_key('profil_foto', uid)) ?? state.photoUrl;

      state = state.copyWith(
        id: id,
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
      final prefs = await PrefsService.instance();
      if (prefs == null) return false;

      // Anahtar kimliği OKUMA tarafıyla aynı kuralla çözülmeli.
      //
      // Burada `updated.id` doğrudan kullanılıyordu: o değer yer tutucu
      // ('local_teacher') olduğunda kayıt `profil_okul__local_teacher`
      // anahtarına gidiyor, okuma tarafı ise gerçek UID arıyordu. Yazma
      // ve okuma farklı anahtarlara düştüğü için kurulum her açılışta
      // yeniden isteniyordu.
      final uid = CloudIds.isValidUid(updated.id)
          ? updated.id
          : await _activeUid();

      await prefs.setString(_key('profil_id', uid), updated.id);
      await prefs.setString(_key('profil_ad', uid), updated.firstName);
      await prefs.setString(_key('profil_soyad', uid), updated.lastName);
      await prefs.setString(_key('profil_cinsiyet', uid), updated.gender);
      await prefs.setString(_key('profil_brans', uid), updated.branch);
      await prefs.setString(_key('profil_okul', uid), updated.schoolName);
      if (updated.city != null) await prefs.setString(_key('profil_il', uid), updated.city!);
      if (updated.district != null) await prefs.setString(_key('profil_ilce', uid), updated.district!);
      if (updated.schoolId != null) await prefs.setString(_key('profil_okul_id', uid), updated.schoolId!);
      if (updated.schoolType != null) await prefs.setString(_key('profil_okul_turu', uid), updated.schoolType!);
      await prefs.setString(_key('profil_mudur', uid), updated.schoolPrincipalName);
      await prefs.setString(_key('profil_email', uid), updated.email);
      if (updated.photoUrl != null) {
        await prefs.setString(_key('profil_foto', uid), updated.photoUrl!);
      }

      state = updated;
      return true;
    } catch (e, stackTrace) {
      debugPrint('Profil kaydetme hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Oturumu Kapat / Temizle.
  Future<void> logout() async {
    try {
      // Önce kimlik oturumunu kapat, sonra yerel izleri temizle.
      await TeacherAuthService().signOut();

      // Hesabın KENDİ profil kayıtlarına dokunulmaz.
      //
      // Profil anahtarları artık hesaba bağlıdır (`profil_okul__{uid}`).
      // Eskiden sabit anahtarlar silindiği için öğretmen çıkış yapıp
      // yeniden girdiğinde okul bilgisi kayboluyor ve okul seçimi
      // baştan soruluyordu. Aşağıdaki temizlik yalnızca eski (hesaba
      // bağlı olmayan) anahtarları kaldırır; bunlar zaten kullanılmıyor.
      final prefs = await PrefsService.instance();
      if (prefs != null) {
        for (final k in [
          'profil_id',
          'profil_ad',
          'profil_soyad',
          'profil_cinsiyet',
          'profil_brans',
          'profil_okul',
          'profil_il',
          'profil_ilce',
          'profil_okul_id',
          'profil_okul_turu',
          'profil_mudur',
          'profil_email',
          'profil_foto',
        ]) {
          await prefs.remove(k);
        }
      }
      // Onbellegi bosalt: aksi halde yeniden giris yapildiginda
      // `ensureLoaded` eski (bos) sonucu dondurur ve hesabin kayitli
      // okul bilgisi hic okunmaz — okul her defasinda yeniden sorulur.
      _loadFuture = null;

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
