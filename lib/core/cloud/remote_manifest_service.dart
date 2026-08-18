import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_bootstrap.dart';

/// Uygulamanın uzaktan yönetilen yapılandırması.
///
/// Sürüm numaraları, bakım modu ve asgari sürüm zorlaması buradan gelir.
class RemoteManifest {
  final int calendarVersion;
  final int outcomesVersion;
  final int announcementsVersion;
  final int schoolDirectoryVersion;
  final String minAppVersion;
  final String latestAppVersion;
  final bool maintenanceMode;
  final String maintenanceMessage;

  const RemoteManifest({
    this.calendarVersion = 1,
    this.outcomesVersion = 1,
    this.announcementsVersion = 1,
    this.schoolDirectoryVersion = 1,
    this.minAppVersion = '1.0.0',
    this.latestAppVersion = '1.0.0',
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
  });

  /// Ağ hiç kurulamadığında kullanılan güvenli varsayılan.
  ///
  /// Bakım modu kapalı, sürümler 1: uygulama offline-first çalışmaya
  /// devam eder, hiçbir şey engellenmez.
  static const RemoteManifest fallback = RemoteManifest();
}

/// Uzak yapılandırma okuyucusu (maliyet kararı #3).
///
/// ## Neden Firestore değil
/// Sürüm/bakım kontrolü her açılışta yapılır. Bunu Firestore'dan okumak
/// 10M kullanıcıda günde ~10M okuma, yani aylık ~$180 demekti — üstelik
/// veri tek bir küçük dokümandı.
///
/// **Firebase Remote Config ücretsizdir ve okuma kotası yoktur**; tam
/// olarak bu iş için tasarlanmıştır. Değerler istemcide önbelleklenir ve
/// yalnızca [_minimumFetchInterval] dolduğunda sunucuya gidilir.
///
/// ## Admin portalı bağlantısı
/// Panelin "+1 Artır (Yayınla)" butonu artık Firestore yerine Remote
/// Config parametrelerini günceller. Önceki `SyncService` bulut
/// manifestini kod içinde sabit üretiyordu (simülasyon), bu yüzden panel
/// mobil tarafı hiç etkilemiyordu.
class RemoteManifestService {
  RemoteManifestService._();

  static final RemoteManifestService instance = RemoteManifestService._();

  /// İki sunucu isteği arasındaki asgari süre.
  ///
  /// Remote Config ücretsiz olsa da istemci tarafında gereksiz ağ trafiği
  /// ve pil tüketimi yaratmamak için 6 saatte bir tazelenir. Sürüm
  /// güncellemeleri acil değildir; bakım modu için bu gecikme kabul
  /// edilebilir.
  static const Duration _minimumFetchInterval = Duration(hours: 6);

  FirebaseRemoteConfig? _config;
  RemoteManifest _cached = RemoteManifest.fallback;
  bool _initialized = false;

  /// En son okunan manifest. Ağ yoksa varsayılan döner.
  RemoteManifest get manifest => _cached;

  bool get isReady => _initialized && _config != null;

  /// Servisi hazırlar ve ilk değerleri çeker.
  ///
  /// Hata durumunda sessizce varsayılana düşer: uzak yapılandırma
  /// okunamadı diye uygulama açılmamazlık etmemelidir.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await FirebaseBootstrap.ensureInitialized();
      if (!FirebaseBootstrap.ready) {
        _initialized = true;
        return;
      }

      final config = FirebaseRemoteConfig.instance;

      await config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 12),
          minimumFetchInterval: _minimumFetchInterval,
        ),
      );

      // Varsayılanlar: sunucuya hiç ulaşılamasa bile anlamlı değerler.
      await config.setDefaults(const {
        'calendar_version': 1,
        'outcomes_version': 1,
        'announcements_version': 1,
        'school_directory_version': 1,
        'min_app_version': '1.0.0',
        'latest_app_version': '1.0.0',
        'maintenance_mode': false,
        'maintenance_message': '',
      });

      _config = config;
      _initialized = true;

      await refresh();
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (RemoteManifestService.initialize) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-------------------------------------------------------------------------------');
      _initialized = true; // Tekrar denemeyi engelle; varsayılanla çalış.
    }
  }

  /// Sunucudan taze değerleri çeker ve önbelleği günceller.
  ///
  /// [force] verildiğinde asgari aralık yok sayılır — yalnızca kullanıcı
  /// açıkça "güncellemeleri denetle" dediğinde kullanılmalıdır.
  Future<bool> refresh({bool force = false}) async {
    final config = _config;
    if (config == null) return false;

    try {
      if (force) {
        await config.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 12),
            minimumFetchInterval: Duration.zero,
          ),
        );
      }

      final activated = await config.fetchAndActivate();

      _cached = RemoteManifest(
        calendarVersion: config.getInt('calendar_version'),
        outcomesVersion: config.getInt('outcomes_version'),
        announcementsVersion: config.getInt('announcements_version'),
        schoolDirectoryVersion: config.getInt('school_directory_version'),
        minAppVersion: config.getString('min_app_version'),
        latestAppVersion: config.getString('latest_app_version'),
        maintenanceMode: config.getBool('maintenance_mode'),
        maintenanceMessage: config.getString('maintenance_message'),
      );

      // Zorlamalı çekimden sonra normal aralığa dön.
      if (force) {
        await config.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 12),
            minimumFetchInterval: _minimumFetchInterval,
          ),
        );
      }

      return activated;
    } catch (e, stackTrace) {
      debugPrint('RemoteManifestService.refresh hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Yüklü sürüm, uzak yapılandırmadaki asgari sürümün altında mı?
  ///
  /// `true` dönerse kullanıcı güncellemeye yönlendirilmelidir.
  bool isUpdateRequired(String currentVersion) =>
      compareVersions(currentVersion, _cached.minAppVersion) < 0;

  /// Daha yeni bir sürüm yayımlanmış mı? (zorunlu değil, bilgilendirme)
  bool isUpdateAvailable(String currentVersion) =>
      compareVersions(currentVersion, _cached.latestAppVersion) < 0;

  /// Semantik sürüm karşılaştırması: a<b → negatif, a==b → 0, a>b → pozitif.
  ///
  /// Sayısal karşılaştırma yapar; "1.10.0" > "1.9.0" doğru sonuçlanır
  /// (metin karşılaştırmasında tersi olurdu).
  static int compareVersions(String a, String b) {
    final pa = a.split('.');
    final pb = b.split('.');
    final len = pa.length > pb.length ? pa.length : pb.length;

    for (var i = 0; i < len; i++) {
      final na = i < pa.length ? (int.tryParse(pa[i].trim()) ?? 0) : 0;
      final nb = i < pb.length ? (int.tryParse(pb[i].trim()) ?? 0) : 0;
      if (na != nb) return na.compareTo(nb);
    }
    return 0;
  }
}
