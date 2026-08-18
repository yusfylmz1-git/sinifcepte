import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/storage/prefs_keys.dart';

class ParentAuthException implements Exception {
  final String message;
  const ParentAuthException(this.message);

  @override
  String toString() => message;
}

/// Giriş yapmış velinin kimliği.
class ParentIdentity {
  /// Firebase UID. Bulut tarafında `parent_links/{uid}_{studentCloudId}`
  /// doküman kimliğinin ilk parçasıdır.
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  const ParentIdentity({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });
}

/// Veli Google + Firebase Auth servisi.
///
/// Öğretmen tarafındaki [TeacherAuthService] ile aynı Google istemcisini
/// kullanır ancak yerel SQLite veritabanını **açmaz**: velinin cihazında
/// öğrenci/sınıf veritabanı bulunmaz, veli yalnızca bulut üzerinden
/// kendi çocuğunun verisine erişir.
///
/// Karar (17 Ağustos 2026): Veli girişi **yalnızca Google** ile yapılır.
/// SMS doğrulama Spark planında ücretlidir ve telefon numarası toplamak
/// gereksiz KVKK yükü getirir.
class ParentAuthService {
  ParentAuthService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    // Öğretmen servisiyle aynı web (type 3) istemcisi
    serverClientId:
        '80400507045-4cat4nanfcfnvo3o3d9a6v8eg8i0ji5n.apps.googleusercontent.com',
  );

  User? get firebaseUser =>
      FirebaseBootstrap.ready ? FirebaseAuth.instance.currentUser : null;

  /// Oturum açmış velinin kimliği; oturum yoksa null.
  ParentIdentity? get currentIdentity {
    final user = firebaseUser;
    if (user == null) return null;
    return ParentIdentity(
      uid: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  /// Google ile veli girişi yapar ve kalıcı kimliği döndürür.
  Future<ParentIdentity> signInWithGoogle() async {
    await FirebaseBootstrap.ensureInitialized();
    if (!FirebaseBootstrap.ready) {
      throw const ParentAuthException(
        'Bağlantı kurulamadı. İnterneti kontrol edip tekrar deneyin.',
      );
    }

    // Cihazdaki önceki Google oturumunu sıfırla ki kullanıcı hesap seçebilsin
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const ParentAuthException('Google girişi iptal edildi.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw const ParentAuthException('Google oturumu doğrulanamadı.');
    }

    final displayName =
        (user.displayName ?? googleUser.displayName ?? '').trim();

    // Görünen adı yerelde de tut: bağlantı kartlarında ve mesaj imzasında
    // ağ beklemeden gösterilebilsin.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.parentDisplayName, displayName);
    } catch (e, stackTrace) {
      debugPrint('Veli görünen adı kaydedilemedi: $e\n$stackTrace');
    }

    return ParentIdentity(
      uid: user.uid,
      displayName: displayName,
      email: user.email ?? googleUser.email,
      photoUrl: user.photoURL ?? googleUser.photoUrl,
    );
  }

  /// Yerelde saklanan veli görünen adı (offline gösterim için).
  Future<String> readCachedDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(PrefsKeys.parentDisplayName) ?? '';
    } catch (e, stackTrace) {
      debugPrint('Veli görünen adı okunamadı: $e\n$stackTrace');
      return '';
    }
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
      debugPrint('ParentAuthService.signOut hatası: $e\n$stackTrace');
    }
  }
}
