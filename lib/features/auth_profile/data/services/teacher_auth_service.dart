import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../models/teacher_profile_model.dart';
import '../../providers/teacher_profile_provider.dart';

/// Google girişinin sonucu.
class TeacherSignInResult {
  final TeacherProfileModel profile;

  /// Bu cihazda daha önce **başka** bir hesapla çalışılmış mı?
  ///
  /// `true` ise kullanıcıya "her hesabın çalışma alanı ayrıdır" bilgisi
  /// gösterilmelidir; aksi halde sınıflarının kaybolduğunu sanır.
  final bool switchedAccount;

  const TeacherSignInResult({
    required this.profile,
    required this.switchedAccount,
  });
}

class TeacherAuthException implements Exception {
  final String message;
  const TeacherAuthException(this.message);

  @override
  String toString() => message;
}

/// Öğretmen Google + Firebase Auth. Veli bu servisi kullanmaz.
class TeacherAuthService {
  TeacherAuthService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    // Firebase Auth Google sağlayıcısının web (type 3) istemcisi
    serverClientId:
        '80400507045-4cat4nanfcfnvo3o3d9a6v8eg8i0ji5n.apps.googleusercontent.com',
  );

  User? get firebaseUser =>
      FirebaseBootstrap.ready ? FirebaseAuth.instance.currentUser : null;

  Future<TeacherSignInResult> signInWithGoogle({
    required TeacherProfileNotifier profileNotifier,
    required TeacherProfileModel current,
  }) async {
    await FirebaseBootstrap.ensureInitialized();
    if (!FirebaseBootstrap.ready) {
      throw const TeacherAuthException(
        'Firebase henüz hazır değil. İnterneti kontrol edip tekrar deneyin.',
      );
    }

    // Cihazdaki önceki Google oturumunu sıfırla ki kullanıcı hesap seçebilsin
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const TeacherAuthException('Google girişi iptal edildi.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw const TeacherAuthException('Google oturumu doğrulanamadı.');
    }

    // Bu cihazda daha önce başka bir hesapla çalışılmış mı?
    // Veri hesap başına ayrı tutulduğu için kullanıcı bilgilendirilmeli
    // (bkz. DatabaseHelper.openForUid dokümantasyonu).
    final switchedAccount =
        await DatabaseHelper.isDifferentAccountThanLast(user.uid);

    await DatabaseHelper.instance.openForUid(user.uid);

    // BU HESABIN kayıtlı profilini önce diskten oku.
    //
    // Buradaki `current`, giriş ÖNCESİNDEKİ state'tir; çıkış yapılmışsa
    // boştur. Doğrudan `current.copyWith(...)` yazmak, diskte duran
    // branş ve okul bilgisinin üstüne BOŞ değer geçiriyordu:
    //
    //   profil_brans__{uid} = "Bilişim Teknolojileri"   (kayıtlı)
    //   giriş → saveProfile(branch: '')                  (eziliyor)
    //   → kurulum ekranı yeniden açılıyor
    //
    // Kullanıcı bunu defalarca bildirdi: "profilden çıkış yapıp tekrar
    // girince yine branş soruyor". Kimlik ancak girişten sonra belli
    // olduğu için okuma da burada yapılmalı.
    await profileNotifier.loadProfileFromStorage();
    final saved = profileNotifier.currentProfile;

    final names = (user.displayName ?? googleUser.displayName ?? '').trim().split(RegExp(r'\s+'));

    // Google'dan gelen ad YALNIZCA kayıtlı ad boşsa kullanılır.
    // Öğretmen adını düzeltmişse (ör. "Yusuf YILMAZ"), Google'ın
    // gönderdiği ham değer onu ezmemeli.
    final firstName = saved.firstName.trim().isNotEmpty
        ? saved.firstName
        : (names.isNotEmpty && names.first.isNotEmpty ? names.first : '');
    final lastName = saved.lastName.trim().isNotEmpty
        ? saved.lastName
        : (names.length > 1 ? names.sublist(1).join(' ') : '');

    final updated = saved.copyWith(
      id: user.uid,
      firstName: firstName,
      lastName: lastName,
      email: user.email ?? googleUser.email,
      photoUrl: user.photoURL ?? googleUser.photoUrl,
    );
    await profileNotifier.saveProfile(updated);
    return TeacherSignInResult(
      profile: updated,
      switchedAccount: switchedAccount,
    );
  }

  Future<void> signOut() async {
    try {
      if (FirebaseBootstrap.ready) {
        await FirebaseAuth.instance.signOut();
      }
      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
    } catch (e, stackTrace) {
      debugPrint('TeacherAuthService.signOut hatası: $e\n$stackTrace');
    }
  }
}
