import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../models/teacher_profile_model.dart';
import '../../providers/teacher_profile_provider.dart';

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

  Future<TeacherProfileModel> signInWithGoogle({
    required TeacherProfileNotifier profileNotifier,
    required TeacherProfileModel current,
  }) async {
    await FirebaseBootstrap.ensureInitialized();
    if (!FirebaseBootstrap.ready) {
      throw const TeacherAuthException(
        'Firebase henüz hazır değil. İnterneti kontrol edip tekrar deneyin.',
      );
    }

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

    await DatabaseHelper.instance.openForUid(user.uid);

    final names = (user.displayName ?? googleUser.displayName ?? '').trim().split(RegExp(r'\s+'));
    final firstName = names.isNotEmpty && names.first.isNotEmpty ? names.first : current.firstName;
    final lastName = names.length > 1 ? names.sublist(1).join(' ') : current.lastName;

    final updated = current.copyWith(
      id: user.uid,
      firstName: firstName,
      lastName: lastName,
      email: user.email ?? googleUser.email,
      photoUrl: user.photoURL ?? googleUser.photoUrl,
    );
    await profileNotifier.saveProfile(updated);
    return updated;
  }

  Future<void> signOut() async {
    try {
      if (FirebaseBootstrap.ready) {
        await FirebaseAuth.instance.signOut();
      }
      await _googleSignIn.signOut();
    } catch (e, stackTrace) {
      debugPrint('TeacherAuthService.signOut hatası: $e\n$stackTrace');
    }
  }
}
