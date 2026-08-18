import 'package:flutter/foundation.dart';
import '../storage/prefs_keys.dart';
import '../storage/prefs_service.dart';

/// Reklamın gösterilebileceği yerler.
///
/// Yeni bir yer eklemeden önce [AdGate.isAllowedSlot] içindeki gerekçeyi
/// okuyun: öğrenci verisi görünen hiçbir ekrana reklam konulamaz.
enum AdSlot {
  /// Veli ana ekranının altındaki sabit banner.
  parentDashboardBanner,

  /// Veli duyuru listesinde araya giren yerleşim.
  parentAnnouncementFeed,

  /// Öğretmen PDF/rapor ürettikten sonra isteğe bağlı ödüllü reklam.
  teacherRewardedExport,
}

/// SınıfCepte reklam kapısı (Faz 1: altyapı kurulur, reklam kapalıdır).
class AdGate {
  AdGate._();

  static final AdGate instance = AdGate._();

  bool _initialized = false;
  bool _enabled = false;

  /// Reklam sistemi aktif mi?
  bool get isEnabled => _enabled;

  /// Reklam sistemi başlatıldı mı?
  bool get isInitialized => _initialized;

  /// Yerelde saklanan reklam tercihini yükler.
  ///
  /// Uygulama açılışında bir kez çağrılır. Hata durumunda reklam kapalı
  /// kabul edilir — güvenli varsayılan.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await PrefsService.instance();
      _enabled = prefs?.getBool(PrefsKeys.adsEnabled) ?? false;
    } catch (e, stackTrace) {
      debugPrint('AdGate başlatma hatası (reklam kapalı varsayıldı): $e\n$stackTrace');
      _enabled = false;
    }
    _initialized = true;

    if (_enabled) {
      await _initializeSdk();
    }
  }

  /// Reklamı açar/kapatır ve tercihi kalıcılaştırır.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await PrefsService.instance();
      if (prefs != null) {
        await prefs.setBool(PrefsKeys.adsEnabled, value);
      }
    } catch (e, stackTrace) {
      debugPrint('AdGate tercihi kaydedilemedi: $e\n$stackTrace');
    }

    if (value) {
      await _initializeSdk();
    }
  }

  /// Belirtilen yerde reklam gösterilmesine izin var mı?
  ///
  /// Rol kontrolü çağıran tarafın sorumluluğundadır: öğretmen ekranlarında
  /// yalnızca [AdSlot.teacherRewardedExport] kullanılabilir.
  bool isAllowedSlot(AdSlot slot, {required bool showsStudentData}) {
    if (!_enabled) return false;

    // Öğrenci verisi görünen hiçbir ekranda reklam yok — istisnasız.
    if (showsStudentData) return false;

    return true;
  }

  /// SDK başlatma. Faz 7'de `google_mobile_ads` eklendiğinde doldurulur.
  Future<void> _initializeSdk() async {
    // Faz 7:
    //   await MobileAds.instance.initialize();
    //   await MobileAds.instance.updateRequestConfiguration(
    //     RequestConfiguration(
    //       tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
    //       maxAdContentRating: MaxAdContentRating.g,
    //     ),
    //   );
    debugPrint('AdGate: SDK henüz eklenmedi (Faz 7). Reklam isteği yok sayıldı.');
  }
}
