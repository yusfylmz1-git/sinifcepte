import 'package:flutter/foundation.dart';
import '../storage/prefs_service.dart';

/// Delta senkron zaman damgası deposu (maliyet kararı #2).
///
/// ## Neden var
/// Veli günde ortalama iki kez uygulamayı açıyor. Her açılışta sınıfın tüm
/// duyurularını yeniden indirmek, 10M kullanıcı ölçeğinde ayda ~$1.010'lık
/// gereksiz okuma demekti. Oysa sınıfta günde ortalama 0,2 duyuru
/// yayımlanıyor: açılışların %90'ından fazlası hiç yeni veri bulmayacak.
///
/// Bu sınıf her akış için "en son ne zaman senkron oldum" bilgisini tutar;
/// sorgular `where('updatedAt', '>', sonSenkron)` ile daraltılır ve boş
/// sonuç neredeyse bedava olur.
///
/// ## Güvenli geri çekme
/// Zaman damgası [_safetyMargin] kadar geriye alınarak döndürülür. Sunucu
/// ve istemci saatleri arasındaki küçük farklar yüzünden sınırda kalan bir
/// dokümanın atlanmasını engeller: aynı kaydı iki kez indirmek, bir kaydı
/// hiç görmemekten iyidir.
class DeltaSyncTracker {
  DeltaSyncTracker._();

  static final DeltaSyncTracker instance = DeltaSyncTracker._();

  /// Zaman damgasını bu kadar geriden başlat: sınırda kalan güncellemeler
  /// saat farkı yüzünden atlanmasın.
  static const Duration _safetyMargin = Duration(minutes: 5);

  /// Uzun süre açılmamış uygulamada delta zincirinin kopmasını önler.
  static const Duration _maxStaleness = Duration(days: 30);

  static String _key(String stream) => 'sinifcepte_delta_$stream';

  /// Belirli bir akış için son senkron zamanı.
  ///
  /// `null` dönerse tam çekim yapılmalıdır (ilk açılış veya çok eski senkron).
  Future<DateTime?> lastSyncOf(String stream) async {
    try {
      final prefs = await PrefsService.instance();
      final raw = prefs?.getString(_key(stream));
      if (raw == null || raw.isEmpty) return null;

      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;

      // Çok eskiyse baştan çek.
      if (DateTime.now().difference(parsed) > _maxStaleness) return null;

      return parsed.subtract(_safetyMargin);
    } catch (e, stackTrace) {
      debugPrint('DeltaSyncTracker.lastSyncOf hatası ($stream): $e\n$stackTrace');
      return null; // Hata durumunda tam çekim — veri kaybetmektense fazla oku.
    }
  }

  /// Başarılı senkron sonrası zaman damgasını günceller.
  ///
  /// Yalnızca istek **başarılı** olduğunda çağrılmalıdır; başarısız bir
  /// çekimden sonra damgayı ilerletmek veri atlamasına yol açar.
  Future<void> markSynced(String stream, {DateTime? at}) async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      await prefs.setString(
        _key(stream),
        (at ?? DateTime.now()).toIso8601String(),
      );
    } catch (e, stackTrace) {
      debugPrint('DeltaSyncTracker.markSynced hatası ($stream): $e\n$stackTrace');
    }
  }

  /// Akışı sıfırlar (bir sonraki çekim tam olur).
  Future<void> reset(String stream) async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      await prefs.remove(_key(stream));
    } catch (e, stackTrace) {
      debugPrint('DeltaSyncTracker.reset hatası ($stream): $e\n$stackTrace');
    }
  }

  /// Akış adı üreticileri — anahtar çakışmasını önlemek için tek yerden.
  static String announcementsStream(String classCloudId) =>
      'ann_$classCloudId';

  static String messagesStream(String studentCloudId) =>
      'msg_$studentCloudId';
}
