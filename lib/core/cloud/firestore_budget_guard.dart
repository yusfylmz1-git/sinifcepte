import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firestore işlem sayacı ve istemci tarafı kota freni.
///
/// ## Neden var
/// Blaze planında Firebase **varsayılan harcama tavanı koymaz**. Faturayı
/// patlatan şey genelde özellik kullanımı değil, bir kod hatasıdır:
/// döngüye giren bir yenileme, unutulmuş bir dinleyici, hatalı bir yeniden
/// deneme. Böyle bir kaçak sunucu tarafında fark edildiğinde saatler
/// geçmiş olur.
///
/// Bu sınıf her cihazın **kendi** günlük işlem sayısını sayar ve makul bir
/// sınırı aşarsa yazmayı durdurur. Sunucu tarafı bütçe alarmı hâlâ şarttır
/// (bkz. `docs/BUDGET.md`), ancak bu fren kaçağı kaynağında keser.
///
/// ## Sınırlar nasıl seçildi
/// Maliyet planındaki gerçekçi kullanım tek kullanıcı için günde ~10 okuma
/// ve ~2 yazmaydı. Buradaki sınırlar bunun **50 katı**: normal kullanımda
/// asla tetiklenmez, ama sonsuz döngü birkaç saniyede yakalanır.
///
/// ## Ne yapmaz
/// Okumayı engellemez — okuma engellenirse uygulama kullanılamaz hale
/// gelir ve kullanıcı sebebini anlamaz. Yalnızca **yazma** durdurulur;
/// yazma üç kat pahalıdır ve kaçakların çoğu yazma döngüsüdür.
class FirestoreBudgetGuard {
  FirestoreBudgetGuard._();

  static final FirestoreBudgetGuard instance = FirestoreBudgetGuard._();

  /// Tek cihaz için günlük yazma tavanı.
  static const int dailyWriteLimit = 500;

  /// Tek cihaz için günlük okuma uyarı eşiği (engellemez, yalnızca loglar).
  static const int dailyReadWarnThreshold = 2000;

  static const String _kDateKey = 'sinifcepte_budget_date';
  static const String _kWritesKey = 'sinifcepte_budget_writes';
  static const String _kReadsKey = 'sinifcepte_budget_reads';

  int _writes = 0;
  int _reads = 0;
  String _day = '';
  bool _loaded = false;

  /// Bugünkü yazma sayısı.
  int get writesToday => _writes;

  /// Bugünkü okuma sayısı.
  int get readsToday => _reads;

  /// Yazma tavanına ulaşıldı mı?
  bool get isWriteBlocked => _writes >= dailyWriteLimit;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureLoaded() async {
    if (_loaded && _day == _today()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDay = prefs.getString(_kDateKey) ?? '';
      final today = _today();

      if (storedDay != today) {
        // Gün değişti: sayaçlar sıfırlanır.
        _writes = 0;
        _reads = 0;
        _day = today;
        await prefs.setString(_kDateKey, today);
        await prefs.setInt(_kWritesKey, 0);
        await prefs.setInt(_kReadsKey, 0);
      } else {
        _writes = prefs.getInt(_kWritesKey) ?? 0;
        _reads = prefs.getInt(_kReadsKey) ?? 0;
        _day = today;
      }
      _loaded = true;
    } catch (e, stackTrace) {
      debugPrint('FirestoreBudgetGuard yükleme hatası: $e\n$stackTrace');
      // Hata durumunda freni devre dışı bırakma: sayaç sıfırdan başlar,
      // uygulama çalışmaya devam eder.
      _loaded = true;
    }
  }

  /// Bir yazma işlemine izin var mı? İzin varsa sayacı artırır.
  ///
  /// `false` dönerse çağıran işlemi **yapmamalıdır**.
  Future<bool> allowWrite({int count = 1}) async {
    await _ensureLoaded();

    if (_writes + count > dailyWriteLimit) {
      debugPrint(
        'BÜTÇE FRENİ: Günlük yazma sınırı aşıldı ($_writes/$dailyWriteLimit). '
        'Olası neden: döngüye giren bir kod yolu. İşlem durduruldu.',
      );
      return false;
    }

    _writes += count;
    await _persist(writes: _writes);
    return true;
  }

  /// Okuma sayacını artırır. Okuma hiçbir zaman engellenmez.
  Future<void> recordRead({int count = 1}) async {
    await _ensureLoaded();
    _reads += count;

    if (_reads == dailyReadWarnThreshold) {
      debugPrint(
        'BÜTÇE UYARISI: Günlük okuma $dailyReadWarnThreshold değerine ulaştı. '
        'Beklenen kullanımın çok üzerinde — açık bir dinleyici veya '
        'yenileme döngüsü olabilir.',
      );
    }

    await _persist(reads: _reads);
  }

  Future<void> _persist({int? writes, int? reads}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (writes != null) await prefs.setInt(_kWritesKey, writes);
      if (reads != null) await prefs.setInt(_kReadsKey, reads);
    } catch (e, stackTrace) {
      debugPrint('FirestoreBudgetGuard kaydetme hatası: $e\n$stackTrace');
    }
  }

  /// Test ve hata ayıklama için sayaçları sıfırlar.
  Future<void> reset() async {
    _writes = 0;
    _reads = 0;
    _day = _today();
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDateKey, _day);
      await prefs.setInt(_kWritesKey, 0);
      await prefs.setInt(_kReadsKey, 0);
    } catch (e, stackTrace) {
      debugPrint('FirestoreBudgetGuard sıfırlama hatası: $e\n$stackTrace');
    }
  }

  /// Bellekteki durumu boşaltır; bir sonraki işlem diskten yeniden okur.
  ///
  /// Testlerde gün değişimi gibi disk kaynaklı davranışları sınamak için
  /// gereklidir: [reset] belleği "yüklendi" işaretlediği için tek başına
  /// diski okutmaz.
  @visibleForTesting
  void invalidateCache() {
    _loaded = false;
    _day = '';
  }

  /// Kullanıcıya/geliştiriciye gösterilecek özet.
  String get summary =>
      'Bugün: $_reads okuma, $_writes/$dailyWriteLimit yazma';
}
