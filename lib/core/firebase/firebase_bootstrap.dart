import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Firebase başlatıcı. Test / masaüstü / eksik config'de uygulama çökmez.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;

  static Future<void> ensureInitialized() async {
    if (ready && Firebase.apps.isNotEmpty) return;
    try {
      if (Firebase.apps.isEmpty) {
        // Zaman aşımı şart: ağ yanıt vermezse initializeApp süresiz
        // bekler ve uygulama açılışta donar (Android ANR).
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 10));
      }
      ready = Firebase.apps.isNotEmpty;
    } catch (e, stackTrace) {
      ready = false;
      debugPrint('Firebase başlatılamadı (yerel devam): $e\n$stackTrace');
    }
  }
}
