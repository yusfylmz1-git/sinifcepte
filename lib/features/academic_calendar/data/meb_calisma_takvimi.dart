import 'package:sqflite/sqflite.dart';

/// MEB çalışma takviminin resmî olayları. APK ile gelir.
///
/// ## Neden (30 Ekim 2026)
/// Kurulum yalnız 2025-2026 olaylarını tohumluyordu, takvim sağlayıcısı
/// da sabit '2025-2026' yılını yüklüyordu. 2026-2027'de Özet hiçbir
/// tatili tanımıyordu (29 Ekim'de günün akışı sıradan ders günü), takvim
/// ekranı geçen yılın tarihlerini gösteriyordu. Bulut eşitlemesi takvimi
/// indirmez (SyncService: "takvim APK ile gelir"); her yılın listesi
/// buraya eklenmeli.
///
/// Kaynaklar:
/// - MEB genelgesi, 13 Haziran 2026 (meb.gov.tr haber 41057): açılış,
///   ara tatiller, yarıyıl, dönem sonları.
/// - Diyanet 2027 takvimi: Ramazan Bayramı 9-11 Mart (arife 8 Mart),
///   Kurban Bayramı 16-19 Mayıs (arife 15 Mayıs).
///
/// Arife yarım günleri tatil sayılmaz; Özet onları tam gün tatil
/// gösterirdi, eklenmedi. Tatil haftaları kazanım takvimiyle
/// (`scripts/maarif/overrides`) aynı olmalı; test karşılaştırır.
const Map<String, List<Map<String, Object>>> mebCalismaTakvimleri = {
  '2026-2027': [
    {
      'doc_id': 'meb_2627_donem1_baslangic',
      'title': '1. Dönem Ders Başlangıcı',
      'description': '2026-2027 Eğitim Öğretim Yılı 1. Dönem Açılışı',
      'start_date': '2026-09-14T08:00:00',
      'end_date': '2026-09-14T17:00:00',
      'category': 'period',
      'is_official_holiday': 0,
    },
    {
      'doc_id': 'meb_2627_29ekim',
      'title': '29 Ekim Cumhuriyet Bayramı',
      'description': 'Cumhuriyetimizin Kuruluş Yıldönümü Resmî Tatili',
      'start_date': '2026-10-29T00:00:00',
      'end_date': '2026-10-29T23:59:59',
      'category': 'officialHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_ara_tatil_1',
      'title': '1. Dönem Ara Tatili',
      'description': 'Kasım ara tatili (16-20 Kasım 2026)',
      'start_date': '2026-11-16T00:00:00',
      'end_date': '2026-11-20T23:59:59',
      'category': 'breakHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_yilbasi',
      'title': 'Yılbaşı Tatili',
      'description': '1 Ocak Resmî Tatili',
      'start_date': '2027-01-01T00:00:00',
      'end_date': '2027-01-01T23:59:59',
      'category': 'officialHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_donem1_sonu',
      'title': '1. Dönem Sonu (Karne Günü)',
      'description': '1. dönemin son günü, karneler verilir',
      'start_date': '2027-01-22T08:00:00',
      'end_date': '2027-01-22T17:00:00',
      'category': 'period',
      'is_official_holiday': 0,
    },
    {
      'doc_id': 'meb_2627_yariyil',
      'title': 'Yarıyıl (Sömestr) Tatili',
      'description': '2 haftalık yarıyıl tatili (25 Ocak - 5 Şubat 2027)',
      'start_date': '2027-01-25T00:00:00',
      'end_date': '2027-02-05T23:59:59',
      'category': 'breakHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_donem2_baslangic',
      'title': '2. Dönem Ders Başlangıcı',
      'description': '2026-2027 Eğitim Öğretim Yılı 2. Dönem Açılışı',
      'start_date': '2027-02-08T08:00:00',
      'end_date': '2027-02-08T17:00:00',
      'category': 'period',
      'is_official_holiday': 0,
    },
    {
      'doc_id': 'meb_2627_ara_tatil_2',
      'title': '2. Dönem Ara Tatili',
      'description': 'Mart ara tatili (8-12 Mart 2027), Ramazan Bayramı bu haftada',
      'start_date': '2027-03-08T00:00:00',
      'end_date': '2027-03-12T23:59:59',
      'category': 'breakHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_ramazan_bayrami',
      'title': 'Ramazan Bayramı',
      'description': 'Ramazan Bayramı (9-11 Mart 2027)',
      'start_date': '2027-03-09T00:00:00',
      'end_date': '2027-03-11T23:59:59',
      'category': 'officialHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_23nisan',
      'title': '23 Nisan Ulusal Egemenlik ve Çocuk Bayramı',
      'description': 'Resmî Tatil',
      'start_date': '2027-04-23T00:00:00',
      'end_date': '2027-04-23T23:59:59',
      'category': 'officialHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_1mayis',
      'title': '1 Mayıs Emek ve Dayanışma Günü',
      'description': 'Resmî Tatil',
      'start_date': '2027-05-01T00:00:00',
      'end_date': '2027-05-01T23:59:59',
      'category': 'officialHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_kurban_bayrami',
      'title': 'Kurban Bayramı',
      'description': 'Kurban Bayramı (16-19 Mayıs 2027)',
      'start_date': '2027-05-16T00:00:00',
      'end_date': '2027-05-19T23:59:59',
      'category': 'officialHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_19mayis',
      'title': "19 Mayıs Atatürk'ü Anma, Gençlik ve Spor Bayramı",
      'description': 'Resmî Tatil (Kurban Bayramı ile aynı gün)',
      'start_date': '2027-05-19T00:00:00',
      'end_date': '2027-05-19T23:59:59',
      'category': 'officialHoliday',
      'is_official_holiday': 1,
    },
    {
      'doc_id': 'meb_2627_yil_sonu',
      'title': 'Eğitim Öğretim Yılı Sonu (Karne Günü)',
      'description': '2026-2027 Eğitim Öğretim Yılı Kapanışı ve Yaz Tatili Başlangıcı',
      'start_date': '2027-06-25T08:00:00',
      'end_date': '2027-06-25T17:00:00',
      'category': 'period',
      'is_official_holiday': 0,
    },
  ],
};

/// Eksik resmî olayları ekler. Her açılışta çağrılır.
///
/// Yalnız `doc_id`'si tabloda olmayan olay eklenir: öğretmenin eklediği
/// ya da önceki yıldan kalan kayıtlara dokunulmaz, listeye sonradan
/// eklenen olay da eski cihaza ulaşır.
Future<void> mebTakviminiTohumla(DatabaseExecutor db) async {
  final mevcut = (await db.query('academic_calendar_events', columns: ['doc_id']))
      .map((r) => r['doc_id'])
      .toSet();
  for (final MapEntry(key: yil, value: olaylar) in mebCalismaTakvimleri.entries) {
    for (final olay in olaylar) {
      if (mevcut.contains(olay['doc_id'])) continue;
      await db.insert('academic_calendar_events', {...olay, 'academic_year': yil});
    }
  }
}
