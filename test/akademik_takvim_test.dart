import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/utils/date_formatter.dart';
import 'package:sinifcepte/features/documents/utils/plan_week_builder.dart';

/// Öğretim yılının uzunluğu (30 Ekim 2026).
///
/// Uygulama da kazanım paketi de yılı sabit 39 hafta sayıyordu. 2026-2027
/// resmî takvimi (MEB genelgesi, 13 Haziran 2026) 14 Eylül - 25 Haziran,
/// yani 41 hafta. Sonuçları:
/// - 14-25 Haziran Özet'te ve Kazanımlar'da "yaz tatili" görünecekti;
/// - resmî planların 36. ve 37. ders haftaları pakete girmiyordu; yıllık
///   plan 11 Haziran'da "Kapanış & Karne" yazarak bitiyordu;
/// - son ders haftası 35 diye eklenen uydurma "36. hafta" PDF'e 17-21
///   Mayıs tarihiyle basılıyordu;
/// - BEP planının bitişi 11.06.2027 yazıyordu.
void main() {
  group('Takvim hesabı', () {
    test('KRITIK: 2026-2027 41 hafta, karne 25 Haziran', () {
      final d = DateTime(2026, 10, 30);
      expect(AppDateFormatter.getAcademicYearStartDate(d), DateTime(2026, 9, 14));
      expect(AppDateFormatter.dersYiliSonu(d), DateTime(2027, 6, 25));
      expect(AppDateFormatter.toplamHafta(d), 41);
      expect(AppDateFormatter.yazTatiliHaftasi(d), 42);
    });

    test('KRITIK: Haziranın son iki haftası ders haftası, yaz tatili değil', () {
      int hafta(DateTime t) => AppDateFormatter.getCurrentAcademicWeek(targetDate: t);
      expect(hafta(DateTime(2026, 9, 14, 9)), 1);
      expect(hafta(DateTime(2026, 11, 16, 9)), 10, reason: '1. ara tatil haftası');
      expect(hafta(DateTime(2027, 6, 11, 15)), 39);
      expect(hafta(DateTime(2027, 6, 14, 9)), 40);
      expect(hafta(DateTime(2027, 6, 25, 15)), 41,
          reason: 'karne cuması öğleden sonra da ders yılı');
      expect(hafta(DateTime(2027, 6, 26, 9)), 42, reason: 'karneden sonra yaz');
      expect(hafta(DateTime(2027, 7, 15)), 42);
      expect(hafta(DateTime(2027, 8, 20)), 1, reason: 'yeni yıla hazırlık');
    });

    test('son hafta ve yaz tatili tarih metni', () {
      final d = DateTime(2026, 10, 30);
      expect(AppDateFormatter.getWeekDateRangeText(41, targetDate: d),
          '21 Haziran - 25 Haziran 2027');
      expect(AppDateFormatter.getWeekDateRangeText(42, targetDate: d),
          '26 Haziran - 12 Eylül 2027');
    });

    test('tablo dışı yıl kuralla ve varsayılan uzunlukla hesaplanır', () {
      final d = DateTime(2027, 10, 1);
      expect(AppDateFormatter.getAcademicYearStartDate(d), DateTime(2027, 9, 13));
      expect(AppDateFormatter.toplamHafta(d), AppDateFormatter.varsayilanHaftaSayisi);
      expect(AppDateFormatter.dersYiliSonu(d).weekday, DateTime.friday);
    });
  });

  test('KRITIK: uygulamanın takvimi kazanım boru hattınınkiyle aynı', () {
    // İki ayrı yerde duruyorlar: Python (paket üretimi) ve Dart (bugünün
    // haftası). Biri güncellenip öteki unutulursa paket 41 hafta, ekran
    // 39 hafta sayar.
    final resmi = AppDateFormatter.resmiYillar;
    final dosyalar = Directory('scripts/maarif/overrides')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    for (final f in dosyalar) {
      final o = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
      if (o['endDate'] == null) continue;
      final acilis = DateTime.parse(o['startDate'] as String);
      final yil = resmi[acilis.year];
      expect(yil, isNotNull, reason: '${f.path} uygulamanın tablosunda yok');
      expect(yil!.acilis, acilis, reason: f.path);
      expect(yil.kapanis, DateTime.parse(o['endDate'] as String), reason: f.path);
    }
    // Boru hattı 2026-2027'den beri bu dosyalarla çalışıyor; daha eski
    // yıl tabloda yalnız devreden BEP belgeleri için durur.
    for (final y in resmi.keys.where((y) => y >= 2026)) {
      expect(File('scripts/maarif/overrides/$y-${y + 1}.json').existsSync(), isTrue,
          reason: '$y tablosunun takvim dosyası yok');
    }
  });

  group('Yayın verisi', () {
    late List<dynamic> kayitlar;

    setUpAll(() {
      final f = File('assets/data/official_maarif_kazanimlar.json');
      kayitlar = json.decode(f.readAsStringSync()) as List<dynamic>;
    });

    test('KRITIK: her ders grubu yılın bütün haftalarını taşır', () {
      final toplam = AppDateFormatter.toplamHafta(DateTime(2026, 10, 1));
      final gruplar = <String, Set<int>>{};
      for (final k in kayitlar) {
        gruplar
            .putIfAbsent('${k['gradeLevel']}|${k['subjectCode']}|${k['publisher']}', () => {})
            .add(k['weekNumber'] as int);
      }
      final beklenen = {for (var w = 1; w <= toplam; w++) w};
      final bozuk = [
        for (final e in gruplar.entries)
          if (e.value.length != beklenen.length || !e.value.containsAll(beklenen)) e.key
      ];
      expect(bozuk, isEmpty, reason: '${bozuk.length} grupta hafta eksik/fazla');
    });

    test('KRITIK: karne etiketi son haftada, 7-11 Haziran sıradan hafta', () {
      final hafta39 = {for (final k in kayitlar) if (k['weekNumber'] == 39) k['dateRangeStr']};
      final hafta41 = {for (final k in kayitlar) if (k['weekNumber'] == 41) k['dateRangeStr']};
      expect(hafta39, {'7 - 11 Haziran 2027'});
      expect(hafta41, {'21 - 25 Haziran 2027 (Kapanış & Karne Haftası)'});
    });

    test('KRITIK: yıllık planın son ders haftası 37, tarihi 21-25 Haziran', () {
      // Plan ekranının kullandığı süzgeçle (PlanWeekBuilder).
      var i = 0;
      final satirlar = [
        for (final k in kayitlar)
          if (k['gradeLevel'] == 5 && k['subjectCode'] == 'TURKCE')
            <String, dynamic>{
              'id': i++,
              'week_number': k['weekNumber'],
              'teaching_week_number': k['teachingWeekNumber'],
              'date_range_str': k['dateRangeStr'],
            },
      ];
      final dersler = PlanWeekBuilder.dersHaftalari(satirlar);
      expect(dersler.length, 37);
      expect(PlanWeekBuilder.dersHaftaNo(dersler.last), 37);
      expect(PlanWeekBuilder.tarihAraligi(dersler.last, (_) => 'HESAPLANDI'),
          '21 - 25 Haziran 2027');
      expect(PlanWeekBuilder.tarihAraligi(dersler[dersler.length - 2], (_) => 'HESAPLANDI'),
          '14 - 18 Haziran 2027');
    });
  });
}
