import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/cloud/remote_manifest_service.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/exam_operations/data/services/exam_sync_service.dart';

/// Resmî sınav takviminin BULUTTAN gerçekten inmesi.
///
/// ## Neden bu test var
/// Sınav tarihleri yıl içinde değişiyor: ertelenen bir LGS, açıklanan
/// yeni başvuru tarihi. Önceki hâlde veri yalnızca APK ile geliyordu ve
/// öğretmen uygulama güncellemesi beklemek zorundaydı.
///
/// Diğer modüllerden (takvim, kazanım, okul dizini) FARKI: bu modül
/// veriyi gerçekten indirip veritabanına yazıyor. `SyncService` içindeki
/// yorumda bu ayrım açıkça anlatılıyor.
///
/// Test iki şeyi güvenceye alır:
/// 1. Gelen JSON gerçekten veritabanına yazılıyor
/// 2. Öğretmenin favorileri ve kişisel sınavları BOZULMUYOR
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
  });

  /// Buluttan gelecek örnek veri.
  String payload({
    String docId = 'lgs_2026',
    String baslik = 'LGS 2026',
    String tarih = '2026-06-14T09:30:00.000',
  }) =>
      jsonEncode([
        {
          'doc_id': docId,
          'title': baslik,
          'institution': 'MEB',
          'examDate': tarih,
          'applicationDeadline': '2026-05-20T23:59:59.000',
          'applicationUrl': 'https://meb.gov.tr',
        }
      ]);

  group('Buluttan sinav indirme', () {
    test('KRITIK: gelen JSON veritabanina yaziliyor', () async {
      final yazilan =
          await ExamSyncService().syncFromJsonString(payload());
      expect(yazilan, 1);

      final db = await DatabaseHelper.instance.database;
      final satir = await db.query('genel_sinavlar',
          where: 'doc_id = ?', whereArgs: ['lgs_2026']);
      expect(satir, hasLength(1));
      expect(satir.first['sinav_adi'], 'LGS 2026');
    });

    test('KRITIK: ERTELENEN sinavin tarihi guncelleniyor', () async {
      // Asıl senaryo bu: sınav zaten kayıtlı, tarihi değişti.
      await ExamSyncService()
          .syncFromJsonString(payload(tarih: '2026-06-14T09:30:00.000'));

      await ExamSyncService()
          .syncFromJsonString(payload(tarih: '2026-06-21T09:30:00.000'));

      final db = await DatabaseHelper.instance.database;
      final satir = await db.query('genel_sinavlar',
          where: 'doc_id = ?', whereArgs: ['lgs_2026']);
      // Yinelenen kayıt OLMAMALI: doc_id ile upsert ediliyor.
      expect(satir, hasLength(1));
      expect(satir.first['sinav_tarihi'], '2026-06-21T09:30:00.000');
    });

    test('KRITIK: ogretmenin favorisi bulut guncellemesinde silinmiyor',
        () async {
      await ExamSyncService().syncFromJsonString(payload());

      final db = await DatabaseHelper.instance.database;
      await db.insert('favori_sinavlar', {'doc_id': 'lgs_2026'});

      // Bulut yeni sürüm gönderdi.
      await ExamSyncService()
          .syncFromJsonString(payload(baslik: 'LGS 2026 (Güncellendi)'));

      final favori = await db.query('favori_sinavlar',
          where: 'doc_id = ?', whereArgs: ['lgs_2026']);
      expect(favori, hasLength(1),
          reason: 'favori ayrı tabloda; bulut güncellemesi silmemeli');
    });

    test('bozuk JSON veritabanini bozmuyor', () async {
      await ExamSyncService().syncFromJsonString(payload());

      // Liste değil nesne geldi — yönetici yanlış biçim yayımladı.
      final sonuc =
          await ExamSyncService().syncFromJsonString('{"hata": true}');
      expect(sonuc, 0);

      final db = await DatabaseHelper.instance.database;
      final satir = await db.query('genel_sinavlar');
      expect(satir, hasLength(1), reason: 'eski veri korunmalı');
    });

    test('eksik alanli kayit atlaniyor', () async {
      // doc_id yok: kaydedilemez, ama diğerleri yazılmalı.
      final karisik = jsonEncode([
        {'title': 'Adsız', 'examDate': '2026-01-01T09:00:00.000'},
        {
          'doc_id': 'saglam',
          'title': 'Sağlam Sınav',
          'examDate': '2026-02-01T09:00:00.000',
        },
      ]);

      final yazilan = await ExamSyncService().syncFromJsonString(karisik);
      expect(yazilan, 1, reason: 'yalnızca geçerli kayıt yazılmalı');
    });
  });

  group('Manifest sozlesmesi', () {
    test('KRITIK: manifest sinav surumu ve verisi tasiyor', () {
      // Varsayılan güvenli olmalı: sürüm 1, veri boş.
      // Veri boşken APK'daki varlık kullanılır (offline-first).
      const varsayilan = RemoteManifest.fallback;
      expect(varsayilan.examsVersion, 1);
      expect(varsayilan.examsPayload, isEmpty);
    });

    test('KRITIK: sync servisi GERCEK indirme yapiyor', () {
      // Diğer modüller yalnızca sürüm karşılaştırıyor; sınav indirmeli.
      final kod =
          File('lib/features/sync/services/sync_service.dart').readAsStringSync();
      expect(kod.contains('_syncExams'), isTrue,
          reason: 'sınav indirme yöntemi yok');
      expect(kod.contains('syncFromJsonString'), isTrue,
          reason: 'gelen veri veritabanına yazılmıyor');
    });

    test('KRITIK: basarisiz indirmede surum sayaci ilerlemiyor', () {
      // Sayaç erken ilerlerse bir kez başarısız olan indirme kalıcı
      // olarak "güncel" sayılır ve öğretmen eski tarihle kalır.
      final kod =
          File('lib/features/sync/services/sync_service.dart').readAsStringSync();
      final govde = kod.substring(kod.indexOf('Future<bool> _syncExams'));

      // Sayaç güncellemesi, başarısızlık dönüşlerinden SONRA olmalı.
      final sayacYeri = govde.indexOf('_kExamsSyncKey');
      final hataDonusu = govde.indexOf('return false');
      expect(sayacYeri, greaterThan(hataDonusu),
          reason: 'sayaç hata kontrolünden önce ilerliyor');
    });
  });
}
