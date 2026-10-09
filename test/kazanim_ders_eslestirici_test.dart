import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/utils/date_formatter.dart';
import 'package:sinifcepte/features/outcomes/data/repositories/curriculum_outcome_repository.dart';
import 'package:sinifcepte/features/outcomes/utils/kazanim_ders_eslestirici.dart';

/// Ana sayfadaki "Günün dersleri"nde derse dokununca 40. hafta (yaz tatili)
/// açılıyordu (kullanıcı bildirimi, 9 Ekim 2026). Ders adı kod yerine
/// gönderiliyor, hiçbir kazanım gelmiyor, yalnız tatil kartı kalıyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'kazanim_ders_eslestirici_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Map<String, dynamic> d(String kod, String ad, [String yayinci = '']) =>
      {'subject_code': kod, 'subject_name': ad, 'publisher': yayinci};

  group('eşleştirme kuralları', () {
    final liste = [
      d('TURKCE', 'Türkçe'),
      d('MAT', 'Matematik'),
      d('MAT_UYG', 'Matematik Uygulamaları'),
      d('FEN', 'Fen Bilimleri'),
      d('BILISIM', 'Bilişim Teknolojileri ve Yazılım'),
      d('FIZIK', 'Fizik', 'Fen Lisesi'),
      d('FIZIK', 'Fizik'),
    ];

    String? kod(String ad) => kazanimDersiBul(liste, ad)?['subject_code'] as String?;

    test('KRITIK: ders adı ders KODUNA çevriliyor (Türkçe harf duyarsız)', () {
      expect(kod('Türkçe'), 'TURKCE');
      expect(kod('TÜRKÇE'), 'TURKCE');
      expect(kod('turkce'), 'TURKCE');
    });

    test('birebir ad, benzer uzun adın önünde', () {
      expect(kod('Matematik'), 'MAT', reason: '"Matematik Uygulamaları" değil');
    });

    test('kısaltma ve uzun resmî ad', () {
      expect(kod('Fen'), 'FEN');
      expect(kod('Bilişim Teknolojileri'), 'BILISIM');
    });

    test('kodla da bulunuyor', () {
      expect(kod('MAT'), 'MAT');
    });

    test('aynı adda genel kayıt (yayınevi boş) seçiliyor', () {
      expect(kazanimDersiBul(liste, 'Fizik')!['publisher'], '');
    });

    test('bulunamayan ders ve boş ad null (boş liste açılmasın)', () {
      expect(kod('Sınıf Öğretmeni'), isNull);
      expect(kod('  '), isNull);
    });
  });

  group('gerçek kazanım verisi', () {
    setUpAll(() async {
      await DatabaseHelper.instance.resetForTests();
      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();
    });

    // Ders programındaki ad sınıfın branşından gelir (teacher_branches).
    const ornekler = <(int, String)>[
      (5, 'Türkçe'),
      (5, 'Matematik'),
      (5, 'Fen Bilimleri'),
      (5, 'Sosyal Bilgiler'),
      (5, 'İngilizce'),
      (5, 'Din Kültürü ve Ahlak Bilgisi'),
      (5, 'Bilişim Teknolojileri'),
      (6, 'Matematik'),
      (7, 'Fen Bilimleri'),
      (8, 'Türkçe'),
      (8, 'İngilizce'),
    ];

    for (final (sinif, ad) in ornekler) {
      test('KRITIK: $sinif. sınıf "$ad" bu haftanın kazanımıyla açılıyor', () async {
        final repo = CurriculumOutcomeRepository();
        final ders = kazanimDersiBul(await repo.getAvailableSubjects(sinif), ad);
        expect(ders, isNotNull, reason: '"$ad" kazanım listesinde bulunamadı');

        final kazanimlar = await repo.getOutcomes(
          gradeLevel: sinif,
          subjectCode: ders!['subject_code'] as String,
          publisher: ders['publisher'] as String?,
        );
        final haftalar = kazanimlar.where((k) => !k.isHolidayWeek || k.weekNumber < 40);
        expect(haftalar.length, greaterThan(30),
            reason: 'yalnız 40. hafta kartı kalmamalı');
        // Kazanım ekranı sayfa = hafta − 1 sayıyor.
        final hafta = AppDateFormatter.getCurrentAcademicWeek(targetDate: DateTime(2026, 10, 9));
        expect(kazanimlar[hafta - 1].weekNumber, hafta,
            reason: 'bu haftanın sayfası bu haftanın kazanımı');
      });
    }
  });

  test('ana sayfa eşleştiriciyi kullanıyor, ders adını kod diye göndermiyor', () {
    final s = File('lib/features/dashboard/screens/dashboard_screen.dart').readAsStringSync();
    expect(s.contains('kazanimDersiBul('), isTrue);
    expect(s.contains("'subject_code': lesson.lessonName"), isFalse);
  });
}
