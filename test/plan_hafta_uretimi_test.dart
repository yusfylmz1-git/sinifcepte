import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/documents/utils/plan_week_builder.dart';

/// Hafta plani uretimi ekran DURUMUNDAN bagimsiz.
///
/// ## Neden bu dosya var
/// Bu mantik iki ekrana (`annual_plans_view`, `daily_plans_view`)
/// `_donustur` adiyla kopyalanmisti ve kopyalar sapmisti: SDB varsayilan
/// metni, disiplinler arasi iliski cumlesi ve yil sonu haftasi ucu de
/// farkliydi. Ayrica ikisi de `_seciliSinif` / `_seciliDersKodu` gibi
/// ekran alanlarini okuyordu, yani EKRAN ACMADAN plan uretilemiyordu.
///
/// Sohbet asistani "5. sinif turkce yillik plan" diyebilsin diye bu bag
/// koparildi. Bu testler tasimanin davranisi bozmadigini kilitler.
void main() {
  String takvim(int hafta) => '$hafta. hafta tarihi';

  Map<String, dynamic> satir({
    String unitTitle = 'OYUN DÜNYASI',
    String topicTitle = 'OYUN DURDU!',
    String outcomeDescription = 'T.D.5.3. Tahminde bulunabilme',
    String? outcomeCode = 'T.D.5.3',
    String officialActivity = '',
    String maarifSummary = 'Bu hafta konu islenir.',
    String maarifSkills = '',
    String maarifValues = '',
    String differentiation = '',
    int weekNumber = 1,
    int? teachingWeekNumber = 1,
    String dateRangeStr = '14 - 18 Eylül 2026',
  }) =>
      {
        'subject_name': 'Türkçe',
        'unit_title': unitTitle,
        'topic_title': topicTitle,
        'outcome_description': outcomeDescription,
        'outcome_code': outcomeCode,
        'official_activity': officialActivity,
        'maarif_summary': maarifSummary,
        'maarif_skills': maarifSkills,
        'maarif_values': maarifValues,
        'differentiation': differentiation,
        'week_number': weekNumber,
        'teaching_week_number': teachingWeekNumber,
        'date_range_str': dateRangeStr,
      };

  Map<String, dynamic> uret({
    Map<String, dynamic>? kayit,
    int haftaNo = 1,
    int sinif = 5,
    String dersKodu = 'TURKCE',
    bool ayrintili = false,
  }) =>
      PlanWeekBuilder.haftaPlani(
        satir: kayit ?? satir(),
        haftaNo: haftaNo,
        sinif: sinif,
        dersKodu: dersKodu,
        takvimdenTarih: takvim,
        ayrintili: ayrintili,
      );

  group('Ekran durumundan bagimsizlik', () {
    test('KRITIK: ekran acmadan plan uretilir', () {
      final plan = uret();
      final meta = plan['meta'] as Map<String, dynamic>;

      expect(meta['ders'], 'Türkçe');
      expect(meta['sinif'], '5. Sınıf');
      expect(meta['hafta'], '1. Hafta');
    });

    test('Ders adi disaridan verilebilir', () {
      final plan = PlanWeekBuilder.haftaPlani(
        satir: satir(),
        haftaNo: 3,
        sinif: 6,
        dersKodu: 'MAT',
        dersAdi: 'Matematik',
        takvimdenTarih: takvim,
      );
      expect((plan['meta'] as Map)['ders'], 'Matematik');
      expect((plan['meta'] as Map)['sinif'], '6. Sınıf');
    });

    test('KRITIK: ders saati sinif+ders ciftinden gelir', () {
      // Pakette lessonHours alani yok; eski kod her derse "2" yaziyordu.
      expect((uret()['meta'] as Map)['ders_saati'], '6'); // 5. sinif Turkce
      expect(
        (uret(sinif: 9, dersKodu: 'MAT')['meta'] as Map)['ders_saati'],
        '6',
      );
      expect(
        (uret(sinif: 5, dersKodu: 'BILISIM')['meta'] as Map)['ders_saati'],
        '2',
      );
    });

    test('Tarih satirdaki hazir degerden okunur', () {
      expect((uret()['meta'] as Map)['tarih_araligi'], '14 - 18 Eylül 2026');
    });
  });

  group('Yillik ve gunluk varyant', () {
    test('KRITIK: yillik varyant sade ogretim sureci uretir', () {
      final surecMap = uret()['ogretim_sureci'] as Map<String, dynamic>;
      expect(surecMap.containsKey('etkinlikler'), isTrue);
      expect(surecMap.containsKey('dikkat_cekme'), isFalse,
          reason: 'yillik PDF bu alanlari okumaz');
      expect(surecMap.containsKey('farklilastirma'), isFalse);
    });

    test('KRITIK: ayrintili varyant gunluk planin tum alanlarini tasir', () {
      final surecMap =
          uret(ayrintili: true)['ogretim_sureci'] as Map<String, dynamic>;
      for (final alan in [
        'dikkat_cekme',
        'guduleme',
        'derse_gecis',
        'etkinlikler',
        'bireysel_etkinlikler',
        'grupla_etkinlikler',
        'ozet',
        'temel_kabuller',
        'on_degerlendirme_sureci',
        'kopru_kurma',
        'ogrenme_ogretme_uygulamalari',
        'farklilastirma',
      ]) {
        expect(surecMap.containsKey(alan), isTrue, reason: '$alan eksik');
      }
    });

    test('Iki varyant ayni kazanim ve ozel alanlari uretir', () {
      final sade = uret();
      final zengin = uret(ayrintili: true);

      expect(sade['kazanimlar_ve_surec'], zengin['kazanimlar_ve_surec']);
      expect(sade['ozel_alanlar'], zengin['ozel_alanlar']);
      expect(sade['meta'], zengin['meta']);
    });
  });

  group('Kazanim ve tema', () {
    test('Kazanim metni oldugu gibi korunur', () {
      // Kaynak metin varsa DOKUNULMAZ: MEB'in yazdigi kazanim
      // cumlesi neyse kart ve PDF onu gosterir.
      final plan = uret(
        kayit: satir(
          outcomeDescription: 'Tahminde bulunabilme',
          outcomeCode: 'T.D.5.3',
        ),
      );
      final ciktilar =
          (plan['kazanimlar_ve_surec'] as Map)['ogrenme_ciktilari'] as List;
      expect(ciktilar.first, 'Tahminde bulunabilme');
    });

    test('Metin bos ise kazanim kodu basa yazilir', () {
      // Kod bazli aramanin tutmasi icin kart bos kalmamali.
      final plan = uret(
        kayit: satir(outcomeDescription: '', outcomeCode: 'T.D.5.3'),
      );
      final ciktilar =
          (plan['kazanimlar_ve_surec'] as Map)['ogrenme_ciktilari'] as List;
      expect(ciktilar.first, startsWith('T.D.5.3.'));
    });

    test('Unite ve konu ayni ise tema tekrarlanmaz', () {
      final plan = uret(
        kayit: satir(unitTitle: 'GELENEKLERİMİZ', topicTitle: 'GELENEKLERİMİZ'),
      );
      expect((plan['meta'] as Map)['tema_unite'], 'GELENEKLERİMİZ');
    });

    test('OTP haftasi zumre metnine duser', () {
      final plan = uret(
        kayit: satir(
          unitTitle: 'OKUL TEMELLİ PLANLAMA',
          topicTitle: 'Planlanmamış Hafta',
          outcomeDescription: 'Planlanmamış',
          outcomeCode: '',
        ),
      );
      final ciktilar =
          (plan['kazanimlar_ve_surec'] as Map)['ogrenme_ciktilari'] as List;
      expect(ciktilar.first, contains('zümre öğretmenler kurulunca'));
    });
  });

  group('Yil sonu haftasi', () {
    test('KRITIK: tarih SABIT degil, takvimden gelir', () {
      // Gunluk ekranda `'14 - 18 Haziran 2027'` diye sabitlenmisti;
      // 2027-2028'de yanlis basacakti.
      final plan = PlanWeekBuilder.yilSonuHaftasi(
        haftaNo: 36,
        sinif: 5,
        dersKodu: 'TURKCE',
        dersAdi: 'Türkçe',
        takvimdenTarih: takvim,
      );
      expect((plan['meta'] as Map)['tarih_araligi'], '36. hafta tarihi');
      expect((plan['meta'] as Map)['tarih_araligi'], isNot(contains('2027')));
    });

    test('Yil sonu haftasi da gercek ders saatini tasir', () {
      final plan = PlanWeekBuilder.yilSonuHaftasi(
        haftaNo: 36,
        sinif: 5,
        dersKodu: 'TURKCE',
        dersAdi: 'Türkçe',
        takvimdenTarih: takvim,
      );
      expect((plan['meta'] as Map)['ders_saati'], '6');
    });

    test('Ayrintili yil sonu haftasi gunluk alanlari tasir', () {
      final plan = PlanWeekBuilder.yilSonuHaftasi(
        haftaNo: 36,
        sinif: 5,
        dersKodu: 'TURKCE',
        dersAdi: 'Türkçe',
        takvimdenTarih: takvim,
        ayrintili: true,
      );
      final surecMap = plan['ogretim_sureci'] as Map<String, dynamic>;
      expect(surecMap['dikkat_cekme'], isNotEmpty);
      expect(surecMap['farklilastirma'], isA<Map>());
    });
  });
}
