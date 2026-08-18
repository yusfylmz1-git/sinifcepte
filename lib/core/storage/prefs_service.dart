import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences erişiminin tek kapısı.
///
/// ## Neden var
/// Kullanıcı "öğrenciye basınca 20 saniye tepki yok" bildirdi. İzleme
/// logları `SharedPreferences.getInstance()` çağrısının **hiç dönmediğini**
/// gösterdi: platform kanalı yanıt vermediğinde bu çağrı süresiz bekler ve
/// Android bunu ANR olarak raporlar.
///
/// Kod tabanında 55 ayrı `getInstance()` çağrısı vardı. Biri bloke
/// olduğunda hepsi sırada bekliyordu; üstelik her biri ayrı ayrı platform
/// kanalına gidiyordu.
///
/// Bu servis üç şey yapar:
/// 1. **Tek örnek**: ilk çağrıda alınan nesne saklanır, sonrakiler bekleme
///    yapmadan onu kullanır.
/// 2. **Tek uçuş**: aynı anda gelen çağrılar tek bir isteği paylaşır
///    (yinelenen platform çağrısı olmaz).
/// 3. **Zaman aşımı**: platform yanıt vermezse belirli süre sonra vazgeçilir
///    ve `null` dönülür. Çağıranlar bu durumda varsayılan davranışa
///    düşer — uygulama donmaz.
///
/// Offline-first ilkesi gereği doğru davranış beklemek değil, hızlıca
/// vazgeçip kullanıcıya bir şey göstermektir.
class PrefsService {
  PrefsService._();

  /// Platform kanalı bu sürede yanıt vermezse vazgeçilir.
  ///
  /// Normalde birkaç milisaniye sürer; 3 saniye fazlasıyla cömerttir ve
  /// kullanıcının "dondu" hissetmesinden çok önce devreye girer.
  static const Duration _timeout = Duration(seconds: 3);

  static SharedPreferences? _cached;
  static Future<SharedPreferences?>? _inFlight;

  /// Hazır olan örnek (varsa). Senkron erişim gereken yerler için.
  static SharedPreferences? get cached => _cached;

  /// SharedPreferences örneğini getirir; alınamazsa `null` döner.
  ///
  /// **Asla exception fırlatmaz ve asla süresiz beklemez.**
  static Future<SharedPreferences?> instance() async {
    final ready = _cached;
    if (ready != null) return ready;

    // Aynı anda gelen çağrılar tek isteği paylaşsın.
    return _inFlight ??= _load();
  }

  static Future<SharedPreferences?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_timeout);
      _cached = prefs;
      return prefs;
    } on TimeoutException {
      debugPrint(
        'PrefsService: SharedPreferences ${_timeout.inSeconds} saniyede '
        'yanıt vermedi. Uygulama varsayılan değerlerle devam ediyor.',
      );
      return null;
    } catch (e, stackTrace) {
      debugPrint('PrefsService yükleme hatası: $e');
      debugPrint('$stackTrace');
      return null;
    } finally {
      // Sonraki çağrılar yeniden denesin (başarısızsa önbellek dolmaz).
      _inFlight = null;
    }
  }

  /// Uygulama açılışında çağrılır: platform kanalını erkenden ısıtır.
  ///
  /// Böylece ilk ekran açıldığında bekleme olmaz. Başarısız olsa bile
  /// açılışı engellemez.
  static Future<void> warmUp() async {
    await instance();
  }

  /// Test ve hesap değişimi için önbelleği temizler.
  @visibleForTesting
  static void resetCache() {
    _cached = null;
    _inFlight = null;
  }
}
