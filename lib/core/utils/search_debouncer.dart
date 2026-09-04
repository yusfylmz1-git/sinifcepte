import 'dart:async';

import 'package:flutter/foundation.dart';

/// Arama kutuları için gecikmeli tetikleyici.
///
/// ## Neden gerekliydi
/// Arama alanları her tuş vuruşunda `setState` çağırıyordu; 1100+ satırlık
/// ekranlar saniyede onlarca kez baştan çiziliyor ve klavye takılıyordu.
/// Kullanıcı "WhatsApp'ta akıcı, bende yavaş" diye bildirdi.
///
/// Bu sınıf yazmayı bitirmeyi bekler: yalnızca son tuştan [delay] kadar
/// sonra bir kez tetiklenir. Arada geçen tuşlar hiç çizim üretmez.
class SearchDebouncer {
  SearchDebouncer({this.delay = const Duration(milliseconds: 250)});

  /// Son tuştan sonra beklenecek süre.
  ///
  /// 250 ms bilinçli: daha kısası (100 ms) hızlı yazanlarda hâlâ birkaç
  /// gereksiz çizim üretir; daha uzunu (500 ms) arama "geç kalıyor" hissi
  /// verir.
  final Duration delay;

  Timer? _timer;

  /// [action] çağrısını geciktirir; bu sürede yeni çağrı gelirse
  /// öncekini iptal eder.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Bekleyen çağrıyı iptal eder (ör. arama temizlendiğinde).
  void cancel() => _timer?.cancel();

  /// Bekleyen çağrı var mı?
  bool get isPending => _timer?.isActive ?? false;

  /// Widget dispose edilirken çağrılmalıdır; aksi hâlde ekran
  /// kapandıktan sonra `setState` çağrılır ve hata düşer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
