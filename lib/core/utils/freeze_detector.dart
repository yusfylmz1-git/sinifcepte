import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../support/tani_log.dart';

/// Ana iş parçacığının donduğu anı yakalar.
///
/// ## Neden var
/// "Ekran donuyor" şikâyeti üç tur boyunca yanlış yerlerde arandı: font
/// indirme, Firestore zaman aşımı, SharedPreferences kilidi. Hepsi gerçek
/// sorunlardı ama hiçbiri donmanın sebebi değildi.
///
/// Sebep tahmin edilemiyor çünkü blokaj **testlerde görünmüyor** — yalnızca
/// gerçek cihazda, gerçek veriyle oluşuyor. Bu sınıf tahmini bırakıp
/// ölçüme geçer.
///
/// ## Nasıl çalışır
/// Ana iş parçacığında düzenli bir "kalp atışı" tutar. Atış gecikirse
/// (yani ana iş parçacığı bir işlemde takılmışsa) ne kadar donduğunu
/// loglar. Bu, hangi kullanıcı eyleminden sonra donduğunu net gösterir.
///
/// Yalnızca hata ayıklama derlemesinde çalışır; üretimde hiçbir maliyeti
/// yoktur.
class FreezeDetector {
  FreezeDetector._();

  /// Bu süreden uzun donmalar loglanır.
  ///
  /// 500 ms kullanıcının "takıldı" hissettiği eşiktir; altındaki gecikmeler
  /// normal karşılanır ve gürültü yapmaz.
  static const Duration _threshold = Duration(milliseconds: 500);

  /// Kalp atışı aralığı.
  static const Duration _interval = Duration(milliseconds: 200);

  static Timer? _timer;
  static DateTime _lastBeat = DateTime.now();

  /// İzlemeyi başlatır. `main()` içinde çağrılır.
  /// İzlemeyi başlatır. `main()` içinde çağrılır.
  ///
  /// Yalnızca hata ayıklama derlemesinde çalışır; üretimde maliyeti
  /// yoktur. Kayıtlar [TaniLog] üzerinden cihazdaki dosyaya da yazılır,
  /// böylece kablo çıkarıldıktan sonra okunabilir.
  static void start() {
    if (!kDebugMode) return;
    if (_timer != null) return;

    _lastBeat = DateTime.now();

    _timer = Timer.periodic(_interval, (_) {
      final now = DateTime.now();
      final gap = now.difference(_lastBeat);
      _lastBeat = now;

      // Zamanlayıcı ana iş parçacığında çalışır: gecikme, ana iş
      // parçacığının o süre boyunca meşgul olduğu anlamına gelir.
      if (gap > _threshold) {
        TaniLog.yaz(
          'DONMA ⚠ ana iş parçacığı ${gap.inMilliseconds} ms bloke',
        );
      }
    });

    // Kare atlamalarını da izle: uzun kareler donma habercisidir.
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        final total = t.totalSpan;
        if (total > _threshold) {
          TaniLog.yaz(
            'YAVAŞ KARE ⚠ ${total.inMilliseconds} ms '
            '(build ${t.buildDuration.inMilliseconds}, '
            'çizim ${t.rasterDuration.inMilliseconds})',
          );
        }
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
