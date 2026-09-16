import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/cloud/firestore_client.dart';
import '../models/okul_config_model.dart';

/// Okul panosu bulut deposu: nöbetçi listesi ve idare duyuruları.
///
/// ## Neden sınıf duyurularından ayrı
///
/// Sınıf duyuruları `class_rooms/{cls_{uid}_{id}}/announcements` altında
/// ve sahiplik doküman kimliğindeki öğretmen uid'sinden türüyor
/// (`lib/core/cloud/cloud_ids.dart`). Okul panosunun sahibi ise bir
/// öğretmen değil, **okulun yöneticisi**. Bu yüzden ayrı bir yol açıldı:
///
/// ```text
/// school_boards/{schoolId}
///   duty/{tarih}        → nöbetçi
///   notices/{noticeId}  → idare duyurusu
/// ```
///
/// Doküman kimliği kanonik okul kimliği (`meb_16_123456`) olduğu için
/// `firestore.rules` yetkiyi tek karşılaştırmayla denetliyor
/// (`isSchoolAdminOf(schoolId)`) — ekstra doküman okuması yok. Bu, maliyet
/// kararlarıyla tutarlı.
///
/// ## Yetki kapsamı nereden okunur
///
/// Yazma çağrılarında kullanılacak `schoolId`, **yerel profilden değil**
/// custom claim'den gelmeli (`UserRoleState.adminSchoolId`). Profil bir
/// tercih dosyasıdır; okul değişikliğinden sonra claim ile ayrışabilir ve
/// ayrıştığında istemci sunucunun reddedeceği bir yazma denemesi yapar.
///
/// ## Öğrenci verisi buraya ASLA yazılmaz
///
/// Pano içeriği tahtada herkese açık gösteriliyor. Nöbetçi kaydı öğretmen
/// adı taşır; öğrenci adı, numarası veya notu hiçbir koşulda girmez.
class SchoolBoardRepository {
  SchoolBoardRepository({FirestoreClient? client})
      : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const String _kok = 'school_boards';

  /// Panonun kök dokümanı yolu.
  static String boardPath(String schoolId) => '$_kok/$schoolId';

  /// Nöbetçi kaydı yolu. Tarih ISO biçiminde (`2026-09-16`).
  static String dutyPath(String schoolId, String tarih) =>
      '$_kok/$schoolId/duty/$tarih';

  /// Duyuru yolu.
  static String noticePath(String schoolId, String noticeId) =>
      '$_kok/$schoolId/notices/$noticeId';

  /// Panonun kök kaydını oluşturur veya günceller.
  ///
  /// `schoolId` alanı doküman kimliğiyle **aynı** yazılır: kural bunu
  /// şart koşuyor. Aksi halde bir okulun yöneticisi kendi yolunda başka
  /// okula ait veri tutabilir ve tahta yanlış okulun panosunu
  /// gösterebilirdi.
  Future<bool> upsertBoard({
    required String schoolId,
    required String okulAdi,
  }) async {
    if (schoolId.isEmpty) {
      debugPrint('SchoolBoardRepository: boş schoolId ile yazma reddedildi');
      return false;
    }

    return _client.setDoc(
      boardPath(schoolId),
      {
        'schoolId': schoolId,
        'okulAdi': okulAdi,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>?> readBoard(String schoolId) =>
      _client.getDoc(boardPath(schoolId));

  // --- Nöbetçi listesi ---

  /// Bir günün nöbetçisini yazar.
  ///
  /// Doküman kimliği tarihtir: aynı güne ikinci kez yazmak eski kaydı
  /// değiştirir, kuyruk oluşmaz. Bu hem maliyet hem de "hangisi
  /// geçerli" belirsizliğini önler.
  Future<bool> setDuty({
    required String schoolId,
    required NobetciKaydi nobetci,
  }) async {
    if (schoolId.isEmpty || nobetci.tarih.isEmpty) return false;

    return _client.setDoc(
      dutyPath(schoolId, nobetci.tarih),
      {
        'tarih': nobetci.tarih,
        'kat': nobetci.kat,
        'ad': nobetci.ad,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Birden fazla günün nöbetçisini tek turda yazar.
  ///
  /// İdareci genellikle haftalık/aylık girer; tek tek yazmak hem yavaş
  /// hem de bütçe freni açısından savurgan olurdu (`commitBatch`
  /// yazma sayısını toplu sayar).
  Future<bool> setDutyBatch({
    required String schoolId,
    required List<NobetciKaydi> nobetciler,
  }) async {
    if (schoolId.isEmpty || nobetciler.isEmpty) return false;

    final writes = <String, Map<String, dynamic>?>{};
    final now = DateTime.now().toIso8601String();

    for (final n in nobetciler) {
      if (n.tarih.isEmpty) continue;
      writes[dutyPath(schoolId, n.tarih)] = {
        'tarih': n.tarih,
        'kat': n.kat,
        'ad': n.ad,
        'updatedAt': now,
      };
    }

    if (writes.isEmpty) return false;
    return _client.commitBatch(writes);
  }

  Future<bool> deleteDuty({
    required String schoolId,
    required String tarih,
  }) =>
      _client.deleteDoc(dutyPath(schoolId, tarih));

  /// Belirli bir tarih aralığının nöbetçilerini okur.
  ///
  /// Tarih kimlik olduğu için sorgu yerine kimlik aralığı kullanılıyor
  /// (`FieldPath.documentId` yerine `tarih` alanı): indeks gerektirmez.
  Future<List<NobetciKaydi>> readDuties({
    required String schoolId,
    required String baslangicTarihi,
    required String bitisTarihi,
    int limit = 40,
  }) async {
    // Girdi denetimi ağ çağrısından ÖNCE.
    //
    // `ensureConfigured()` Firebase'i başlatmaya çalışıyor; geçersiz
    // girdi için bunu yapmanın anlamı yok. Sıra ters olduğunda test
    // ortamında MethodChannel hatası alınıyordu — gerçek cihazda ise
    // boş bir sorgu için gereksiz başlatma maliyeti doğuruyordu.
    if (schoolId.isEmpty) return const [];

    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      final snap = await db
          .collection(_kok)
          .doc(schoolId)
          .collection('duty')
          .where('tarih', isGreaterThanOrEqualTo: baslangicTarihi)
          .where('tarih', isLessThanOrEqualTo: bitisTarihi)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 8));

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final v = d.data();
        return NobetciKaydi(
          tarih: (v['tarih'] as String?) ?? d.id,
          kat: (v['kat'] as String?) ?? '',
          ad: (v['ad'] as String?) ?? '',
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('readDuties hatası: $e\n$stackTrace');
      return const [];
    }
  }

  // --- İdare duyuruları ---

  /// Duyuru yayımlar veya günceller.
  ///
  /// Uzunluk sınırları kuralda da var (başlık 1-100, metin 0-2000);
  /// burada önden kesmek, kullanıcıya sunucunun reddedeceği bir işlemi
  /// hiç denetmemek için.
  Future<bool> publishNotice({
    required String schoolId,
    required PanoDuyurusu duyuru,
  }) async {
    if (schoolId.isEmpty || duyuru.id.isEmpty) return false;

    final baslik = duyuru.baslik.trim();
    if (baslik.isEmpty || baslik.length > 100) {
      debugPrint('publishNotice: başlık 1-100 karakter olmalı');
      return false;
    }
    if (duyuru.metin.length > 2000) {
      debugPrint('publishNotice: metin 2000 karakteri aşıyor');
      return false;
    }

    return _client.setDoc(
      noticePath(schoolId, duyuru.id),
      {
        'id': duyuru.id,
        'baslik': baslik,
        'metin': duyuru.metin,
        'baslangic': duyuru.baslangic,
        'bitis': duyuru.bitis,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<bool> deleteNotice({
    required String schoolId,
    required String noticeId,
  }) =>
      _client.deleteDoc(noticePath(schoolId, noticeId));

  /// Panoda gösterilecek duyuruları okur.
  Future<List<PanoDuyurusu>> readNotices({
    required String schoolId,
    int limit = 20,
  }) async {
    // Girdi denetimi ağ çağrısından ÖNCE — bkz. [readDuties].
    if (schoolId.isEmpty) return const [];

    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      final snap = await db
          .collection(_kok)
          .doc(schoolId)
          .collection('notices')
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 8));

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final v = d.data();
        return PanoDuyurusu(
          id: (v['id'] as String?) ?? d.id,
          baslik: (v['baslik'] as String?) ?? '',
          metin: (v['metin'] as String?) ?? '',
          baslangic: (v['baslangic'] as String?) ?? '',
          bitis: (v['bitis'] as String?) ?? '',
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('readNotices hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Duyuru kimliği üretir.
  ///
  /// `communication_ids.dart` desenini izler: tahmin edilebilir kimlik,
  /// aynı anda yazan iki yöneticinin birbirinin kaydını ezmesine yol
  /// açıyordu.
  ///
  /// ## Sonek GERÇEKTEN rastgele olmalı
  ///
  /// İlk uygulamada sonek `zaman % 100000` idi — yani zamanın kendisi.
  /// Aynı milisaniyede üretilen iki kimlik **birebir aynı** oluyordu ve
  /// "rastgele" sonek hiçbir şey eklemiyordu. Test bunu yakaladı: 50
  /// ardışık çağrı tek milisaniyede bitince küme boyutu 1 çıktı.
  ///
  /// `Random.secure()` işletim sisteminin entropi kaynağını kullanır;
  /// `communication_ids.dart:19` da aynı sebeple onu seçiyor.
  static String newNoticeId() {
    final zaman = DateTime.now().millisecondsSinceEpoch;
    final rastgele = _rastgele.nextInt(1 << 32).toRadixString(36);
    return 'ntc_${zaman}_$rastgele';
  }

  static final Random _rastgele = Random.secure();
}
