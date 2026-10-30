import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/utils/date_formatter.dart';
import 'package:sinifcepte/features/academic_calendar/data/meb_calisma_takvimi.dart';
import 'package:sinifcepte/features/academic_calendar/data/models/academic_calendar_event_model.dart';
import 'package:sinifcepte/features/academic_calendar/providers/academic_calendar_provider.dart';

/// MEB çalışma takvimi (30 Ekim 2026).
///
/// Kurulum yalnız 2025-2026 olaylarını tohumluyor, sağlayıcı sabit
/// '2025-2026' yılını yüklüyordu. 2026-2027'de Özet hiçbir tatili
/// tanımıyordu: 29 Ekim'de günün akışı ders günü gibi göründü, 16-20
/// Kasım ara tatilinde de öyle görünecekti. Takvim ekranı geçen yılı
/// gösteriyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'meb_calisma_takvimi_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final olaylar = mebCalismaTakvimleri['2026-2027']!
      .map((m) => AcademicCalendarEventModel.fromMap({...m, 'academic_year': '2026-2027'}))
      .toList();

  AcademicCalendarEventModel? tatil(DateTime gun) {
    for (final e in olaylar) {
      final tatilMi = e.category == CalendarEventCategory.officialHoliday ||
          e.category == CalendarEventCategory.breakHoliday;
      final bas = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final son = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      if (tatilMi && !gun.isBefore(bas) && !gun.isAfter(son)) return e;
    }
    return null;
  }

  group('2026-2027 olayları', () {
    test('KRITIK: resmî tatil ve ara tatil günleri tatil, okul günleri değil', () {
      expect(tatil(DateTime(2026, 10, 29))?.title, contains('Cumhuriyet'));
      expect(tatil(DateTime(2026, 11, 18))?.title, '1. Dönem Ara Tatili');
      expect(tatil(DateTime(2027, 2, 1)), isNotNull, reason: 'yarıyıl');
      expect(tatil(DateTime(2027, 3, 10)), isNotNull, reason: 'Ramazan Bayramı');
      expect(tatil(DateTime(2027, 4, 23)), isNotNull);
      expect(tatil(DateTime(2027, 5, 18))?.title, 'Kurban Bayramı');
      // Okul günleri
      expect(tatil(DateTime(2026, 10, 28)), isNull, reason: 'arife yarım gün, tatil değil');
      expect(tatil(DateTime(2026, 11, 23)), isNull);
      expect(tatil(DateTime(2027, 2, 8)), isNull, reason: '2. dönem başı');
      expect(tatil(DateTime(2027, 6, 21)), isNull, reason: 'son hafta ders var');
    });

    test('KRITIK: kazanım takvimiyle aynı yıl ve aynı tatil haftaları', () {
      final acilis = AppDateFormatter.getAcademicYearStartDate(DateTime(2026, 10, 1));
      DateTime gunu(String docId) =>
          olaylar.firstWhere((e) => e.docId == docId).startDate;
      DateTime sadeGun(DateTime d) => DateTime(d.year, d.month, d.day);

      expect(sadeGun(gunu('meb_2627_donem1_baslangic')), acilis);
      expect(sadeGun(gunu('meb_2627_yil_sonu')),
          AppDateFormatter.dersYiliSonu(DateTime(2026, 10, 1)));

      // Ara tatil ve yarıyılın kapladığı takvim haftaları ==
      // scripts/maarif/overrides holidayWeeks.
      final haftalar = <int>{};
      for (final e in olaylar.where((e) => e.category == CalendarEventCategory.breakHoliday)) {
        for (var g = sadeGun(e.startDate); !g.isAfter(e.endDate); g = DateTime(g.year, g.month, g.day + 7)) {
          haftalar.add(DateTime.utc(g.year, g.month, g.day)
                      .difference(DateTime.utc(acilis.year, acilis.month, acilis.day))
                      .inDays ~/
                  7 +
              1);
        }
      }
      final o = json.decode(File('scripts/maarif/overrides/2026-2027.json').readAsStringSync())
          as Map<String, dynamic>;
      final beklenen = (o['holidayWeeks'] as Map).keys.map((k) => int.parse(k as String)).toSet();
      expect(haftalar, beklenen);
    });

    test('kimlikler tekil ve eski yılın kimlikleriyle çakışmaz', () {
      final kimlikler = olaylar.map((e) => e.docId).toList();
      expect(kimlikler.toSet().length, kimlikler.length);
      // Eski tohum 2025-2026 olaylarına 'meb_2026_' öneki veriyordu.
      expect(kimlikler.where((k) => k.startsWith('meb_2026_')), isEmpty);
    });
  });

  group('Veritabanı', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseHelper.instance.resetForTests();
    });

    Future<List<Map<String, Object?>>> yilinOlaylari(String yil) async {
      final db = await DatabaseHelper.instance.database;
      return db.query('academic_calendar_events', where: 'academic_year = ?', whereArgs: [yil]);
    }

    test('KRITIK: yeni kurulumda bu yılın takvimi var', () async {
      final kayitlar = await yilinOlaylari('2026-2027');
      expect(kayitlar.length, mebCalismaTakvimleri['2026-2027']!.length);
    });

    test('KRITIK: eski kurulum (yalnız 2025-2026) açılışta tamamlanır', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('academic_calendar_events');
      await db.insert('academic_calendar_events', {
        'doc_id': 'meb_2026_donem2_kapanis',
        'title': 'Eğitim Öğretim Yılı Sonu (Karne Günü)',
        'start_date': '2026-06-19T08:00:00',
        'end_date': '2026-06-19T17:00:00',
        'category': 'period',
        'academic_year': '2025-2026',
        'is_official_holiday': 0,
      });
      await db.insert('academic_calendar_events', {
        'doc_id': 'ogretmen_1',
        'title': 'Veli toplantısı',
        'start_date': '2026-11-05T14:00:00',
        'end_date': '2026-11-05T16:00:00',
        'category': 'specialDay',
        'academic_year': '2026-2027',
        'is_official_holiday': 0,
      });

      // Uygulama güncellenip yeniden açılıyor (veritabanı sürümü aynı:
      // yalnız açılış adımı çalışır). İki kez: ikinci açılış çoğaltmaz.
      for (var i = 0; i < 2; i++) {
        await DatabaseHelper.instance.closeConnection();
        await DatabaseHelper.instance.database;
      }

      final buYil = await yilinOlaylari('2026-2027');
      expect(buYil.length, mebCalismaTakvimleri['2026-2027']!.length + 1,
          reason: 'resmî olaylar + öğretmenin olayı, çift kayıt yok');
      expect(buYil.where((r) => r['doc_id'] == 'ogretmen_1'), hasLength(1));
      expect(await yilinOlaylari('2025-2026'), hasLength(1), reason: 'eski kayıt yerinde');
    });

    test('KRITIK: sağlayıcı bugünün öğretim yılını yükler', () async {
      final kap = ProviderContainer();
      addTearDown(kap.dispose);
      final n = kap.read(academicCalendarProvider.notifier);
      await n.loadEvents();
      final yil = AppDateFormatter.academicYearLabel();
      final olaylar = kap.read(academicCalendarProvider);
      // Tarihten bağımsız: yıl tabloda varsa olaylar o yılın olmalı.
      expect(olaylar.every((e) => e.academicYear == yil), isTrue);
      if (mebCalismaTakvimleri.containsKey(yil)) {
        expect(olaylar, isNotEmpty, reason: '$yil takvimi yüklenmedi');
      }

      await n.loadEvents(academicYear: '2026-2027');
      expect(kap.read(academicCalendarProvider).length,
          mebCalismaTakvimleri['2026-2027']!.length);
    });
  });
}
