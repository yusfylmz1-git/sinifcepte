import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_bootstrap.dart';
import 'firestore_budget_guard.dart';

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

  /// Bulut işlemleri için üst sınır.
  ///
  /// Firestore çağrılarının varsayılan zaman aşımı yoktur: ağ yanıt
  /// vermezse istek süresiz bekler ve arayüz donar. Android bunu ANR
  /// olarak raporlar ("uygulama yanıt vermiyor").
  ///
  /// Offline-first ilkesi gereği doğru davranış beklemek değil, hızlıca
  /// vazgeçip yerel veriyle devam etmektir.
  static const Duration _networkTimeout = Duration(seconds: 3);

  FirebaseFirestore? _db;
  bool _configured = false;

  /// Firestore hazır mı? Değilse çağıranlar yerel yola düşmelidir.
  bool get isReady => FirebaseBootstrap.ready && _db != null;

  /// Firestore'u hazırlar ve kalıcı önbelleği açar.
  ///
  /// Ayarlar yalnızca ilk erişimden önce uygulanabilir; bu yüzden tek
  /// noktadan ve bir kez yapılır.
  Future<void> ensureConfigured() async {
    if (_configured && _db != null) return;
    try {
      await FirebaseBootstrap.ensureInitialized()
          .timeout(_networkTimeout, onTimeout: () {});
      if (!FirebaseBootstrap.ready) return;

      final db = FirebaseFirestore.instance;
      try {
        db.settings = const Settings(
          persistenceEnabled: true,
          // Sınırsız önbellek: veli tarafında veri hacmi küçük (duyuru, mesaj)
          // ama ağsız kullanımda tamamının elde olması gerekiyor.
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (_) {
        // Önceden ayarlanmışsa veya SDK kısıtında sessizce devam et
      }
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

  /// Firestore'u hazırlar ve hazır olup olmadığını döndürür.
  ///
  /// ## Neden her giriş noktası bunu çağırmak zorunda
  ///
  /// `isReady` yalnızca **durumu okur**, yapılandırmayı tetiklemez.
  /// `getDoc`/`setDoc` bir dönem doğrudan `isReady`'ye bakıyordu ve
  /// `ensureConfigured()` yalnızca sorgu (`where`) kullanan metotlara
  /// eklenmişti — çünkü orada `db` null olunca kod **çöküyordu**, yani
  /// eksiklik hemen görünüyordu.
  ///
  /// `getDoc`/`setDoc` ise sessizce `null`/`false` dönüyordu. Sonuç:
  /// uygulama açılışında başka bir kod yapılandırmayı tetiklemediyse
  /// **her tek doküman okuma/yazma başarısız oluyor** ve kullanıcı
  /// "internet bağlantınızı kontrol edin" görüyordu — interneti
  /// çalışırken.
  ///
  /// Sahada görülen hâli: okul yöneticiliği başvurusu hiç
  /// gönderilemiyordu ve mevcut başvuru da okunamadığı için ekran
  /// sürekli boş form gösteriyordu.
  Future<bool> _hazirla() async {
    if (isReady) return true;
    await ensureConfigured();
    return isReady;
  }

  /// Tek doküman okur.
  ///
  /// Deterministik doküman kimliği kullanıldığında bu, sorgu (`where`)
  /// yerine tercih edilmelidir: indeks gerektirmez ve tek okuma sayılır.
  Future<Map<String, dynamic>?> getDoc(String path) async {
    if (!await _hazirla()) {
      debugPrint('Firestore getDoc atlandı ($path): bulut hazır değil');
      return null;
    }
    try {
      final snap = await _db!.doc(path).get().timeout(_networkTimeout);
      await FirestoreBudgetGuard.instance.recordRead();
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
    if (!await _hazirla()) {
      debugPrint('Firestore setDoc atlandı ($path): bulut hazır değil');
      return false;
    }

    // Bütçe freni: kaçak bir döngü faturayı patlatmadan burada durur.
    if (!await FirestoreBudgetGuard.instance.allowWrite()) {
      debugPrint('Firestore setDoc atlandı ($path): günlük yazma sınırı');
      return false;
    }

    try {
      await _db!
          .doc(path)
          .set(data, SetOptions(merge: merge))
          .timeout(_networkTimeout);
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
    if (!await _hazirla()) {
      debugPrint('Firestore deleteDoc atlandı ($path): bulut hazır değil');
      return false;
    }
    if (!await FirestoreBudgetGuard.instance.allowWrite()) {
      debugPrint('Firestore deleteDoc atlandı ($path): günlük yazma sınırı');
      return false;
    }

    try {
      await _db!.doc(path).delete().timeout(_networkTimeout);
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
    if (writes.isEmpty) return false;
    if (!await _hazirla()) {
      debugPrint('Firestore commitBatch atlandı: bulut hazır değil');
      return false;
    }

    // Batch, işlem sayısı kadar yazma sayılır.
    if (!await FirestoreBudgetGuard.instance.allowWrite(count: writes.length)) {
      debugPrint('Firestore commitBatch atlandı: günlük yazma sınırı');
      return false;
    }

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
        await batch.commit().timeout(_networkTimeout);
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('Firestore commitBatch hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Sorgu sonucundaki doküman sayısını okuma sayacına işler.
  ///
  /// [getDoc] tek doküman okumasını kendi sayar, ancak sorgular (`where`
  /// + `get()`) doğrudan `db` üzerinden yapılır. Firestore sorguyu dönen
  /// doküman sayısı kadar ücretlendirdiği için sayaç da öyle işler.
  /// Boş sorgu bile en az bir okuma sayılır.
  Future<void> recordQueryReads(int documentCount) {
    return FirestoreBudgetGuard.instance
        .recordRead(count: documentCount > 0 ? documentCount : 1);
  }

  /// Sunucu zaman damgası (istemci saati güvenilmez).
  static FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  /// Sayaç artırma — okuma yapmadan güncelleme sağlar, bir okumadan tasarruf.
  static FieldValue increment(int by) => FieldValue.increment(by);
}
