import 'package:flutter/foundation.dart';

/// Ana iş parçacığını bloke eden işlemleri yakalayan basit ölçüm aracı.
///
/// ## Neden var
/// Kullanıcı "ekran donuyor" bildirdi; Android ANR logu dokunma olayının
/// 13 saniye bloke olduğunu gösterdi ama hangi işlemin bloke ettiğini
/// söylemedi. Testler bu sorunu göremiyor — yalnızca gerçek cihazda,
/// gerçek veriyle ortaya çıkıyor.
///
/// [PerfTrace.run] ile sarmalanan işlemler süre eşiğini aşarsa konsola
/// uyarı basar. Üretimde de çalışır ama yalnızca yavaş işlemleri loglar;
/// normal akışta sessizdir.
class PerfTrace {
  PerfTrace._();

  /// Bu süreyi aşan işlemler loglanır. 16 ms = bir kare (60 fps);
  /// 300 ms kullanıcının fark ettiği eşiktir.
  static const Duration _warnThreshold = Duration(milliseconds: 300);

  /// Asenkron bir işlemi ölçer ve yavaşsa uyarır.
  static Future<T> run<T>(String label, Future<T> Function() action) async {
    final sw = Stopwatch()..start();
    try {
      return await action();
    } finally {
      sw.stop();
      if (sw.elapsed > _warnThreshold) {
        debugPrint(
          'YAVAŞ İŞLEM: "$label" ${sw.elapsedMilliseconds} ms sürdü '
          '(eşik ${_warnThreshold.inMilliseconds} ms). '
          'Ana iş parçacığı bloke olmuş olabilir.',
        );
      }
    }
  }

  /// Senkron bir işlemi ölçer. Ana iş parçacığında çalışan ağır
  /// hesaplamalar (JSON ayrıştırma, liste dönüşümü) için kullanılır.
  static T runSync<T>(String label, T Function() action) {
    final sw = Stopwatch()..start();
    try {
      return action();
    } finally {
      sw.stop();
      if (sw.elapsed > _warnThreshold) {
        debugPrint(
          'YAVAŞ SENKRON İŞLEM: "$label" ${sw.elapsedMilliseconds} ms sürdü. '
          'Bu süre boyunca arayüz tamamen donar.',
        );
      }
    }
  }
}
