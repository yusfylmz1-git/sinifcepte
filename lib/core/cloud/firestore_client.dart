import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_bootstrap.dart';

/// Firestore erişiminin tek kapısı.
///
/// ## Maliyet kuralları (bu sınıf bunları zorunlu kılar)
/// 1. **Snapshot listener kullanılmaz.** Açık kalan bir dinleyici her
///    değişiklikte okuma yazar ve unutulduğunda faturayı sessizce katlar.
///    Anlık bildirim gerekiyorsa FCM push kullanılır (mesaj başına ücretsiz).
/// 2. **Kalıcı disk önbelleği açıktır.** Ağ yoksa uygulama son bilinen
///    veriyle çalışmaya devam eder (offline-first ilkesi).
/// 3. **Yazmalar toplu (batch) gönderilir.** 30 öğrenci için 30 ayrı istek
///    yerine tek batch: maliyet aynı, ağ turu ve kısmi başarı riski yok.
///
/// Firebase hazır değilse tüm metotlar sessizce başarısız olur ve uygulama
/// yerel verilerle çalışmaya devam eder.
class FirestoreClient {
  FirestoreClient._();

  static final FirestoreClient instance = FirestoreClient._();

  FirebaseFirestore? _db;
  bool _configured = false;

  /// Firestore hazır mı? Değilse çağıranlar yerel yola düşmelidir.
  bool get isReady => FirebaseBootstrap.ready && _db != null;

  /// Firestore'u hazırlar ve kalıcı önbelleği açar.
  ///
  /// Ayarlar yalnızca ilk erişimden önce uygulanabilir; bu yüzden tek
  /// noktadan ve bir kez yapılır.
  Future<void> ensureConfigured() async {
    if (_configured) return;
    try {
      await FirebaseBootstrap.ensureInitialized();
      if (!FirebaseBootstrap.ready) return;

      final db = FirebaseFirestore.instance;
      db.settings = const Settings(
        persistenceEnabled: true,
        // Sınırsız önbellek: veli tarafında veri hacmi küçük (duyuru, mesaj)
        // ama ağsız kullanımda tamamının elde olması gerekiyor.
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _db = db;
      _configured = true;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (FirestoreClient.ensureConfigured) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-------------------------------------------------------------------------------');
      _configured = false;
    }
  }

  FirebaseFirestore? get db => _db;

  /// Tek doküman okur.
  ///
  /// Deterministik doküman kimliği kullanıldığında bu, sorgu (`where`)
  /// yerine tercih edilmelidir: indeks gerektirmez ve tek okuma sayılır.
  Future<Map<String, dynamic>?> getDoc(String path) async {
    if (!isReady) return null;
    try {
      final snap = await _db!.doc(path).get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (e, stackTrace) {
      debugPrint('Firestore getDoc hatası ($path): $e\n$stackTrace');
      return null;
    }
  }

  /// Tek doküman yazar (varsa birleştirir).
  Future<bool> setDoc(
    String path,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    if (!isReady) return false;
    try {
      await _db!.doc(path).set(data, SetOptions(merge: merge));
      return true;
    } catch (e, stackTrace) {
      debugPrint('Firestore setDoc hatası ($path): $e\n$stackTrace');
      return false;
    }
  }

  /// Doküman siler.
  ///
  /// Silme ($0,02/100K) okumadan üç kat ucuzdur; kullanılmayan veriyi
  /// tutmak yerine silmek hem maliyeti hem KVKK yüzeyini azaltır.
  Future<bool> deleteDoc(String path) async {
    if (!isReady) return false;
    try {
      await _db!.doc(path).delete();
      return true;
    } catch (e, stackTrace) {
      debugPrint('Firestore deleteDoc hatası ($path): $e\n$stackTrace');
      return false;
    }
  }

  /// Birden fazla yazma/silmeyi tek turda gönderir (maliyet kararı #7).
  ///
  /// [writes] içindeki `null` değer o yolun silineceği anlamına gelir.
  /// Firestore batch sınırı 500 işlemdir; daha fazlası parçalara bölünür.
  Future<bool> commitBatch(Map<String, Map<String, dynamic>?> writes) async {
    if (!isReady || writes.isEmpty) return false;
    try {
      const chunkSize = 500;
      final entries = writes.entries.toList();

      for (var i = 0; i < entries.length; i += chunkSize) {
        final chunk = entries.skip(i).take(chunkSize);
        final batch = _db!.batch();

        for (final entry in chunk) {
          final ref = _db!.doc(entry.key);
          if (entry.value == null) {
            batch.delete(ref);
          } else {
            batch.set(ref, entry.value!, SetOptions(merge: true));
          }
        }
        await batch.commit();
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('Firestore commitBatch hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Sunucu zaman damgası (istemci saati güvenilmez).
  static FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  /// Sayaç artırma — okuma yapmadan güncelleme sağlar, bir okumadan tasarruf.
  static FieldValue increment(int by) => FieldValue.increment(by);
}
