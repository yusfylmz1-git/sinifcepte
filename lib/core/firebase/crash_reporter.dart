import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Çökme ve yakalanmamış hata raporlama.
///
/// ## Neden gerekli
/// Uygulama Türkiye genelinde kullanılacak. Şu ana kadar bir çökme
/// olduğunda **hiçbir kaydı kalmıyordu**: öğretmen "uygulama kapandı"
/// diyor, elimizde ne yığın izi ne de hangi ekranda olduğu bilgisi var.
///
/// ## Açılış sırasıyla ilişkisi
/// `main()` hızlı açılış için Firebase'i `runApp`'ten **sonra**, arka
/// planda başlatıyor. Bu yüzden ilk anlarda Crashlytics henüz hazır
/// olmuyor. Bu sınıf o boşlukta oluşan hataları **tamponda tutar** ve
/// Firebase hazır olunca gönderir; aksi hâlde en kritik hatalar
/// (açılışta çökme) hiç görünmezdi.
class CrashReporter {
  CrashReporter._();

  static bool _installed = false;
  static bool _firebaseReady = false;

  /// Firebase hazır olmadan önce biriken hatalar.
  ///
  /// Sınırlı tutulur: hata döngüsüne giren bir kod yolu belleği
  /// doldurmamalı.
  static final List<_PendingError> _pending = [];
  static const int _maxPending = 20;

  /// Hata yakalayıcıları kurar. `runApp`'ten **önce** çağrılmalı.
  ///
  /// Firebase'i beklemez; beklerse açılış yavaşlar ve zaten asıl amaç
  /// açılıştaki hatayı yakalamak.
  static void install() {
    if (_installed) return;
    _installed = true;

    // 1. Flutter çatısı içindeki hatalar (build, layout, paint).
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      record(details.exception, details.stack, reason: 'FlutterError');
    };

    // 2. Çatı dışındaki asenkron hatalar (Future, Isolate).
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, reason: 'PlatformDispatcher');
      return true; // işlendi say; uygulama kapanmasın
    };
  }

  /// Firebase hazır olduğunda çağrılır; tamponu boşaltır.
  static Future<void> onFirebaseReady() async {
    if (!FirebaseBootstrap.ready) return;

    try {
      // Hata ayıklama derlemesinde rapor gönderilmez: geliştirme
      // sırasındaki hatalar üretim istatistiğini kirletirdi.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      _firebaseReady = true;

      for (final e in _pending) {
        await FirebaseCrashlytics.instance.recordError(
          e.error,
          e.stack,
          reason: e.reason,
        );
      }
      _pending.clear();
    } catch (e) {
      // Raporlayıcı asla uygulamayı düşürmemeli.
      debugPrint('Crashlytics hazırlama hatası: $e');
    }
  }

  /// Bir hatayı kaydeder. Firebase hazır değilse tamponlar.
  static void record(Object error, StackTrace? stack, {String? reason}) {
    debugPrint('ÇÖKME KAYDI [${reason ?? "-"}]: $error');

    if (!_firebaseReady) {
      if (_pending.length < _maxPending) {
        _pending.add(_PendingError(error, stack, reason));
      }
      return;
    }

    unawaited(
      FirebaseCrashlytics.instance
          .recordError(error, stack, reason: reason)
          .catchError((_) {}),
    );
  }

  /// Çökme raporuna bağlam ekler: hangi ekranda, hangi işlemde olunduğu.
  ///
  /// Yığın izi tek başına "neden" sorusuna cevap vermiyor; öğretmenin ne
  /// yaptığını bilmek hatayı tekrar üretmeyi kolaylaştırır.
  static void log(String message) {
    if (!_firebaseReady) return;
    unawaited(
      FirebaseCrashlytics.instance.log(message).catchError((_) {}),
    );
  }

  /// Test ve gözlem için: bekleyen hata sayısı.
  @visibleForTesting
  static int get pendingCount => _pending.length;

  @visibleForTesting
  static void resetForTest() {
    _pending.clear();
    _firebaseReady = false;
    _installed = false;
  }
}

class _PendingError {
  final Object error;
  final StackTrace? stack;
  final String? reason;

  _PendingError(this.error, this.stack, this.reason);
}
