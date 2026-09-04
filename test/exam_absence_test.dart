import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/analytics/data/models/exam_analysis_model.dart';

/// Sinava girmeyen ogrenci (Faz 2.4).
///
/// `isAbsent` model icinde 10 yerde OKUNUYOR ama ogretmenin onu
/// isaretleyebilecegi hicbir arayuz yoktu. Duzenleyici her ogrenciyi
/// `totalScore: 0.0` ile baslatiyor ve bos alan `?? 0.0` ile 0 oluyor.
///
/// Sonuc: sinava girmeyen ogrenci GERCEK bir 0 gibi sayiliyor ve
/// ortalamayi, basari yuzdesini, standart sapmayi, not dagilimini ve
/// soru basari oranlarini bozuyordu.
void main() {
  StudentExamScore ogrenci(String ad, double puan,
          {bool girmedi = false, List<double>? sorular}) =>
      StudentExamScore(
        studentName: ad,
        studentNumber: 1,
        questionScores: sorular ?? [puan],
        totalScore: puan,
        isAbsent: girmedi,
      );

  ExamAnalysisModel sinav(List<StudentExamScore> ogrenciler,
          {List<double>? soruPuanlari, String tip = 'klasik'}) =>
      ExamAnalysisModel(
        examTitle: '1. Yazılı',
        className: '5-A',
        subjectName: 'Matematik',
        examDate: '2026-11-15',
        examType: tip,
        questionMaxScores: soruPuanlari ?? [100],
        studentScores: ogrenciler,
      );

  group('Girmeyen ogrenci istatistige katilmaz', () {
    test('KRITIK: ortalama girmeyeni saymaz', () {
      final girenler = List.generate(28, (i) => ogrenci('Giren $i', 70));
      final tumu = [
        ...girenler,
        ogrenci('Gelmedi 1', 0, girmedi: true),
        ogrenci('Gelmedi 2', 0, girmedi: true),
      ];

      expect(sinav(tumu).classAverage, 70.0,
          reason: '0 sayilsaydi 65.33 cikardi (4.67 puan sapma)');
    });

    test('KRITIK: basari yuzdesi girmeyeni basarisiz saymaz', () {
      final tumu = [
        ...List.generate(28, (i) => ogrenci('Giren $i', 70)),
        ogrenci('Gelmedi', 0, girmedi: true),
      ];

      expect(sinav(tumu).passRate, 100.0,
          reason: 'girmeyen ogrenci sinifta kalmis gibi gorunmemeli');
    });

    test('en dusuk puan girmeyenin 0 i degildir', () {
      final tumu = [
        ogrenci('A', 45),
        ogrenci('B', 90),
        ogrenci('Gelmedi', 0, girmedi: true),
      ];

      expect(sinav(tumu).lowestScore, 45.0);
      expect(sinav(tumu).highestScore, 90.0);
    });

    test('ogrenci sayisi yalnizca girenleri sayar', () {
      final tumu = [
        ogrenci('A', 60),
        ogrenci('B', 80),
        ogrenci('Gelmedi', 0, girmedi: true),
      ];

      expect(sinav(tumu).studentCount, 2);
    });

    test('not dagilimi girmeyeni Gecersiz kutusuna atmaz', () {
      final tumu = [
        ogrenci('A', 90),
        ogrenci('B', 75),
        ogrenci('Gelmedi', 0, girmedi: true),
      ];

      final dagilim = sinav(tumu).gradeDistribution;
      expect(dagilim['0-49 (Geçersiz)'], 0,
          reason: 'girmeyen ogrenci basarisiz gibi gosterilmemeli');
      expect(dagilim['85-100 (Pekiyi)'], 1);
      expect(dagilim['70-84 (İyi)'], 1);
    });

    test('medyan girmeyeni disarida birakir', () {
      final tumu = [
        ogrenci('A', 60),
        ogrenci('B', 70),
        ogrenci('C', 80),
        ogrenci('Gelmedi', 0, girmedi: true),
      ];

      expect(sinav(tumu).medianScore, 70.0);
    });

    test('standart sapma girmeyenin 0 i ile sismez', () {
      final esitler = List.generate(5, (i) => ogrenci('E $i', 70));
      final tumu = [...esitler, ogrenci('Gelmedi', 0, girmedi: true)];

      expect(sinav(tumu).standardDeviation, 0.0,
          reason: 'herkes 70 aldiysa sapma sifir olmali');
    });

    test('soru basari orani girmeyeni saymaz', () {
      final tumu = [
        ogrenci('A', 20, sorular: [10, 10]),
        ogrenci('B', 20, sorular: [10, 10]),
        ogrenci('Gelmedi', 0, girmedi: true, sorular: [0, 0]),
      ];

      final oranlar = sinav(tumu,
              soruPuanlari: [10, 10], tip: 'soru_bazli')
          .questionSuccessRates;

      expect(oranlar[0], 100.0, reason: 'iki soru da tam yapilmis');
      expect(oranlar[1], 100.0);
    });
  });

  group('Herkes girmediyse cokme olmaz', () {
    test('bos sinif sifir doner, hata firlatmaz', () {
      final tumu = [
        ogrenci('Gelmedi 1', 0, girmedi: true),
        ogrenci('Gelmedi 2', 0, girmedi: true),
      ];

      final s = sinav(tumu);
      expect(s.classAverage, 0.0);
      expect(s.studentCount, 0);
      expect(s.passRate, 0.0);
      expect(s.medianScore, 0.0);
      expect(s.standardDeviation, 0.0);
    });
  });

  group('Kalicilik: girmeyen kaydedilip geri okunabilmeli', () {
    test('KRITIK: girmeyen ogrenci kaydedilip geri yuklenince girmeyen kalir',
        () {
      final girmeyen = ogrenci('Gelmedi', 0, girmedi: true);
      final kayit = girmeyen.toMap(sinavId: 1);
      final geri = StudentExamScore.fromMap({
        ...kayit,
        'soru_bazli_notlar': kayit['soru_bazli_notlar'],
      });

      expect(geri.isAbsent, isTrue,
          reason: 'girmeyen bilgisi diske yazilip geri okunabilmeli');
    });

    test('gercek 0 alan ogrenci girmeyen sayilmaz', () {
      final sifirAlan = ogrenci('Sifir aldi', 0);
      final kayit = sifirAlan.toMap(sinavId: 1);
      final geri = StudentExamScore.fromMap(kayit);

      expect(geri.isAbsent, isFalse,
          reason: 'sinava girip 0 alan ogrenci farkli bir durum');
      expect(geri.totalScore, 0.0);
    });
  });
}
