import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/cloud/remote_manifest_service.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/exam_operations/data/ogretmen_sinavlari.dart';
import 'package:sinifcepte/features/exam_operations/data/repositories/exam_operations_repository.dart';
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
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'exam_cloud_sync_test.db';
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

  group('Yalniz ogretmeni ilgilendiren sinavlar (DEG-11, 29 Ekim)', () {
    // Adlar 29 Ekim 2026'da buluttaki listeden AYNEN alındı.
    const kalan = [
      'KPSS Kamu Personel Seçme Sınavı 2026-KPSS Lisans (Genel Yetenek-Genel Kültür)',
      'MEB-AGS Millî Eğitim Bakanlığı Akademi Giriş Sınavı 2026-MEB-AGS',
      'MEB-EKYS Millî Eğitim Bakanlığı Eğitim Kurumlarına Yönetici Seçme Sınavı',
      'MEB EKYS - Eğitim Kurumlarına Yönetici Seçme Sınavı',
      'ALES Akademik Personel ve Lisansüstü Eğitimi Giriş Sınavı 2026-ALES/3',
      'YDS/1 - Yabancı Dil Bilgisi Seviye Tespit Sınavı',
      'e-YDS Elektronik Yabancı Dil Sınavı e-YDS 2026/12 İngilizce',
      'YÖKDİL Yükseköğretim Kurumları Yabancı Dil Sınavı 2026-YÖKDİL/2',
      'YKS Yükseköğretim Kurumları Sınavı 2026-YKS 2. Oturum (AYT)',
      'MSÜ Millî Savunma Üniversitesi Askerî Öğrenci Aday Belirleme Sınavı 2026-MSÜ',
      'TR-YÖS Türkiye Yurt Dışından Öğrenci Kabul Sınavı 2026-TR-YÖS/2',
      'DGS Dikey Geçiş Sınavı 2026-DGS',
      'EKPSS Engelli Kamu Personeli Seçme Sınavı 2026-EKPSS',
      'AGS - Akademi Giriş Sınavı',
    ];
    const elenen = [
      'Sayıştay Eleme Sayıştay Başkanlığı Sayıştay Denetçi Yardımcısı Adaylığı Eleme Sınavı',
      'DUS Diş Hekimliğinde Uzmanlık Eğitimi Giriş Sınavı 2026-DUS 2.Dönem',
      'STS Diş Hekimliği Diş Hekimliği Alanında Yurt Dışı Yükseköğretim Diploma Denkliği',
      'EUS Eczacılıkta Uzmanlık Eğitimi Giriş Sınavı 2026-EUS',
      'TUS Tıpta Uzmanlık Eğitimi Giriş Sınavı 2026-TUS 2. Dönem',
      'YDUS Tıpta Yan Dal Uzmanlık Eğitimi Giriş Sınavı 2026-YDUS',
      'HMGS Hukuk Mesleklerine Giriş Sınavı 2026-HMGS/2',
      'GUY Gelir İdaresi Başkanlığı Gelir Uzman Yardımcılığı Giriş Sınavı 2026-GUY/2',
      'BKUBTS Tarım ve Orman Bakanlığı Bitki Koruma Ürünleri Bayi ve Toptancılık',
      'İYÖS İdari Yargı Ön Sınavı 2026-İYÖS',
      'e-YDTS Elektronik Yabancı Dil Olarak Türkçe Sınavı e-YDTS/2',
      'e-TEP Elektronik İngilizce Yeterlik Sınavı',
      'DİB-MBSTS Diyanet İşleri Başkanlığı Mesleki Bilgiler Seviye Tespit Sınavı',
    ];

    test('KRITIK: tip, dis, eczacilik, Sayistay, hukuk sinavlari elenir', () {
      for (final ad in elenen) {
        expect(ogretmeniIlgilendirir(ad: ad, kurum: 'ÖSYM'), isFalse, reason: ad);
      }
      for (final ad in kalan) {
        expect(ogretmeniIlgilendirir(ad: ad, kurum: 'ÖSYM'), isTrue, reason: ad);
      }
    });

    test('MEB sinavlari suzulmez (elle secilmis liste)', () {
      for (final (ad, kurum) in const [
        ('MTSK e-Sınavı (Ehliyet Teori Oturumları)', 'MTSK'),
        ('LGS - Liselere Geçiş Sistemi Sınavı', 'MEB'),
        ('AÖF Bahar Dönemi Ara Sınavları (Gözetmenlik & Görev)', 'AÖF'),
      ]) {
        expect(ogretmeniIlgilendirir(ad: ad, kurum: kurum), isTrue, reason: ad);
      }
    });

    test('liste sunucudaki ayristiriciyla ayni', () {
      // functions/osym_parser.js OGRETMEN_SINAVLARI anahtarları.
      final js = File('functions/osym_parser.js').readAsStringSync();
      final blok = js.substring(js.indexOf('const OGRETMEN_SINAVLARI'), js.indexOf(']);', js.indexOf('const OGRETMEN_SINAVLARI')));
      final anahtarlar = RegExp(r"\['([^']+)',").allMatches(blok).map((m) => m.group(1)!).toList();
      expect(anahtarlar, hasLength(12));
      for (final k in anahtarlar) {
        expect(ogretmeniIlgilendirir(ad: '$k Örnek Sınavı 2026-$k', kurum: 'ÖSYM'), isTrue, reason: k);
      }
    });

    test('APK icindeki temiz listenin hepsi suzgecten gecer', () {
      final liste = jsonDecode(File('assets/data/official_exams.json').readAsStringSync()) as List;
      for (final s in liste.cast<Map<String, dynamic>>()) {
        expect(ogretmeniIlgilendirir(ad: s['title'] as String, kurum: s['institution'] as String), isTrue,
            reason: s['title'] as String);
      }
    });

    String liste(List<(String, String)> sinavlar) => jsonEncode([
          for (final (id, ad) in sinavlar)
            {'doc_id': id, 'title': ad, 'institution': 'ÖSYM', 'examDate': '2026-11-22T09:00:00.000'},
        ]);

    test('KRITIK: ilgisiz sinav buluttan gelse de yazilmaz', () async {
      final yazilan = await ExamSyncService().syncFromJsonString(liste([
        ('osym_yds_20261122', 'YDS Yabancı Dil Bilgisi Seviye Tespit Sınavı 2026-YDS/2'),
        ('osym_dus_20261101', 'DUS Diş Hekimliğinde Uzmanlık Eğitimi Giriş Sınavı 2026-DUS 2.Dönem'),
      ]));
      expect(yazilan, 1);
      final db = await DatabaseHelper.instance.database;
      final satir = await db.query('genel_sinavlar');
      expect(satir.map((r) => r['doc_id']), ['osym_yds_20261122']);
    });

    test('KRITIK: listeden cikan eski sinav telefondan silinir, favori korunur', () async {
      await ExamSyncService().syncFromJsonString(liste([
        ('osym_yds_20261122', 'YDS Yabancı Dil Bilgisi Seviye Tespit Sınavı 2026-YDS/2'),
        ('osym_ales_20261129', 'ALES Akademik Personel ve Lisansüstü Eğitimi Giriş Sınavı 2026-ALES/3'),
      ]));
      final db = await DatabaseHelper.instance.database;
      await db.insert('favori_sinavlar', {'doc_id': 'osym_yds_20261122'});

      await ExamSyncService().syncFromJsonString(liste([
        ('osym_yds_20261122', 'YDS Yabancı Dil Bilgisi Seviye Tespit Sınavı 2026-YDS/2'),
      ]));
      final satir = await db.query('genel_sinavlar');
      expect(satir.map((r) => r['doc_id']), ['osym_yds_20261122'], reason: 'ALES listeden çıktı');
      expect(await db.query('favori_sinavlar'), hasLength(1));
    });

    test('bos liste hicbir seyi silmez', () async {
      await ExamSyncService().syncFromJsonString(payload());
      expect(await ExamSyncService().syncFromJsonString('[]'), 0);
      final db = await DatabaseHelper.instance.database;
      expect(await db.query('genel_sinavlar'), hasLength(1));
    });

    test('KRITIK: telefonda kalmis eski kayit listede gorunmez', () async {
      // Eski sürüm (yalnız ekleyen) bu satırları yazmıştı.
      final db = await DatabaseHelper.instance.database;
      for (final (id, ad) in const [
        ('osym_sayistay_20261031', 'Sayıştay Eleme Sayıştay Başkanlığı Sayıştay Denetçi Yardımcısı Adaylığı Eleme Sınavı'),
        ('osym_kpss_20261101', 'KPSS Kamu Personel Seçme Sınavı 2026-KPSS Din Hizmetleri Alan Bilgisi Testi (DHBT)'),
      ]) {
        await db.insert('genel_sinavlar',
            {'doc_id': id, 'sinav_adi': ad, 'kurum': 'ÖSYM', 'sinav_tarihi': '2026-11-01T09:00:00.000'});
      }
      final sinavlar = await ExamOperationsRepository().getAllExams();
      expect(sinavlar.map((e) => e.id), ['osym_kpss_20261101']);
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
