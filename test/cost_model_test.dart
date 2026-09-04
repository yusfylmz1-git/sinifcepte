import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/cloud/cost_model.dart';

/// Firestore maliyet projeksiyonu (Faz 1.5).
///
/// Yayin karari icin "kac ogretmende ucretsiz katman dolar" sorusunun
/// cevabi gerekiyordu. Bu testler sayilari sabitler: mimaride bir sey
/// bozulur da okuma/yazma patlarsa test kirilir.
void main() {
  group('Ucretsiz katman esikleri', () {
    test('KRITIK: yaklasik 250 ogretmene kadar ucretsiz katman yeterli', () {
      final esik = CostProjection.blazeThreshold();
      expect(esik, greaterThan(200),
          reason: 'bu esigin altina duserse mimaride bir sey bozulmus');
      expect(esik, lessThan(400));
    });

    test('okuma ve yazma dengeli doluyor', () {
      final y = CostProjection.maxTeachersOnFreeWrites();
      final o = CostProjection.maxTeachersOnFreeReads();
      // Biri digerinden kat kat once dolmamali; dolarsa o taraf
      // optimize edilmemis demektir.
      expect(y / o, greaterThan(0.5));
      expect(y / o, lessThan(2.0));
    });
  });

  group('Senaryolar', () {
    test('100 ogretmen ucretsiz katmanda rahat', () {
      const p = CostProjection(teachers: 100);
      expect(p.exceedsFreeTier, isFalse);
      expect(p.parents, 2500);
    });

    test('KRITIK: 100 ogretmen YOGUN gunde bile tasmiyor', () {
      const p = CostProjection(
        teachers: 100,
        teacherUsage: TeacherDailyUsage.heavy,
      );
      expect(p.exceedsFreeTier, isFalse,
          reason: 'karne donemi / veli toplantisi gunu fatura surprizi olmamali');
    });

    test('1000 ogretmen ucretsiz katmani asar', () {
      const p = CostProjection(teachers: 1000);
      expect(p.exceedsFreeTier, isTrue);
      expect(p.exceedsFreeWrites, isTrue);
      expect(p.exceedsFreeReads, isTrue);
    });

    test('10000 ogretmen Blaze gerektirir', () {
      const p = CostProjection(teachers: 10000);
      expect(p.exceedsFreeTier, isTrue);
      expect(p.parents, 250000);
    });
  });

  group('Delta senkronizasyonunun etkisi', () {
    test('KRITIK: okuma tazeleme sayisina degil YENI MESAJA bagli', () {
      // Delta damgasi olmasaydi her tazeleme 70 dokuman okurdu.
      // Bu testin amaci: birinin `since` parametresini kaldirmasi
      // durumunda maliyet modelinin de degismesi gerektigini isaretlemek.
      const az = TeacherDailyUsage(messages: 5, refreshes: 5);
      const cokTazeleme = TeacherDailyUsage(messages: 5, refreshes: 100);

      expect(az.reads, cokTazeleme.reads,
          reason: 'delta damgasi sayesinde bos tazeleme dokuman okumaz');
    });

    test('mesaj artinca okuma artar', () {
      const az = TeacherDailyUsage(messages: 5);
      const cok = TeacherDailyUsage(messages: 50);
      expect(cok.reads, greaterThan(az.reads));
    });
  });

  group('Butce freni saglayiciyla tutarli', () {
    test('gunluk yazma freni tipik ogretmenin cok ustunde', () {
      // Fren 1500; tipik ogretmen gunde ~15 yazma yapiyor.
      // Fren normal kullanimi engellememeli ama kacak dongu yakalamali.
      const u = TeacherDailyUsage.typical;
      expect(u.writes, lessThan(100));

      const yogun = TeacherDailyUsage.heavy;
      expect(yogun.writes, lessThan(1500),
          reason: 'en yogun gunde bile fren tetiklenmemeli');
    });
  });

  group('Buyuk olcek (kullanici endisesi)', () {
    test('KRITIK: 1000 okul ucretsiz katmani asar ama makul kalir', () {
      // 1000 okul x ~30 ogretmen = 30.000 ogretmen, 750.000 veli.
      const p = CostProjection(teachers: 30000);

      expect(p.parents, 750000);
      expect(p.exceedsFreeTier, isTrue, reason: 'bu olcekte Blaze sart');

      // Blaze fiyatlari: yazma $0.18/100K, okuma $0.06/100K
      final ucretliYazma = (p.dailyWrites - FirestoreFreeTier.dailyWrites)
          .clamp(0, 1 << 62);
      final ucretliOkuma = (p.dailyReads - FirestoreFreeTier.dailyReads)
          .clamp(0, 1 << 62);
      final aylik = (ucretliYazma * 0.18 / 100000 +
              ucretliOkuma * 0.06 / 100000) *
          30;

      // Aylik maliyet 500 dolarin altinda kalmali. Bu esik asilirsa
      // mimaride bir sey bozulmus demektir (ornegin delta senkronizasyonu
      // devre disi kalmis ya da buluta yeni veri turu eklenmis).
      expect(aylik, lessThan(500),
          reason: '1000 okulda aylik maliyet kontrolden cikmamali');
      expect(aylik, greaterThan(50),
          reason: 'bu olcekte maliyet sifir olamaz; hesap yanlis olabilir');
    });

    test('KRITIK: maliyet veli SAYISIYLA degil MESAJLA orantili', () {
      // Delta senkronizasyonu sayesinde uygulamayi cok acan veli
      // ek maliyet uretmiyor. Bu, olcek buyudukce en kritik ozellik.
      const azAcan = ParentDailyUsage(messages: 2, refreshes: 3);
      const cokAcan = ParentDailyUsage(messages: 2, refreshes: 50);

      expect(azAcan.reads, cokAcan.reads,
          reason: 'tazeleme sayisi maliyeti degistirmemeli');
    });

    test('reklam geliri maliyeti kat kat asiyor', () {
      // 750.000 veli, gunde 1.5 acilis, acilis basina 2 gosterim.
      const veli = 750000;
      const aylikGosterim = veli * 1.5 * 2 * 30;

      // Turkiye egitim uygulamasi icin KOTUMSER eCPM
      const kotumser = 0.35;
      final gelir = aylikGosterim / 1000 * kotumser;

      // Maliyet ~240 dolar (islem + depolama)
      const maliyet = 240.0;

      expect(gelir, greaterThan(maliyet * 10),
          reason: 'reklam modeli maliyeti rahatlikla karsilamali');
    });
  });
}
