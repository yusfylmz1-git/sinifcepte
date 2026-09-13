import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/assistant/data/cepte_belge_servisi.dart';
import 'package:sinifcepte/features/assistant/data/cepte_niyet.dart';

/// Sohbetten belge uretimi — EKRAN ACMADAN.
///
/// ## Neden bu dosya var
/// Plan haritasini kuran mantik ekran durumuna bagliydi; `PlanWeekBuilder`
/// ile koparildi. Bu servis o koparmanin karsiligi. Testler iki seyi
/// kilitler: dogru veriyle plan uretilebildigini ve BELIRSIZ durumda
/// Cepte'nin TAHMIN ETMEDIGINI.
void main() {
  String takvim(int hafta) => '$hafta. hafta';

  /// N ders haftasi uretir (tatil satiri yok).
  List<Map<String, dynamic>> haftalar(int adet, {int baslangic = 1}) {
    return List.generate(adet, (i) {
      final h = baslangic + i;
      return {
        'id': h,
        'subject_name': 'Türkçe',
        'unit_title': 'ÜNİTE $h',
        'topic_title': 'KONU $h',
        'outcome_description': 'T.D.5.$h. Kazanım metni',
        'outcome_code': 'T.D.5.$h',
        'maarif_summary': 'Bu hafta konu islenir.',
        'week_number': h,
        'teaching_week_number': h,
        'date_range_str': '$h. hafta tarihi',
      };
    });
  }

  CepteBelgeServisi servis({
    List<Map<String, dynamic>>? dersler,
    List<Map<String, dynamic>>? kazanimlar,
  }) {
    return CepteBelgeServisi(
      dersleriGetir: (sinif) async =>
          dersler ??
          [
            {
              'subject_code': 'TURKCE',
              'subject_name': 'Türkçe',
              'publisher': '',
            },
          ],
      kazanimlariGetir: ({
        required int gradeLevel,
        required String subjectCode,
        required String publisher,
      }) async =>
          kazanimlar ?? haftalar(35),
      takvimdenTarih: takvim,
    );
  }

  group('Belge uretimi', () {
    test('KRITIK: ekran acmadan 36 haftalik plan kurulur', () async {
      final sonuc = await servis().planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe yıllık plan'),
        ayrintili: false,
      );

      expect(sonuc.basarili, isTrue);
      expect(sonuc.planlar, hasLength(36),
          reason: '35 ders haftasi + yil sonu degerlendirme haftasi');
      expect(sonuc.dersAdi, 'Türkçe');
      expect(sonuc.sinif, 5);
    });

    test('Gunluk plan ayrintili ogretim sureci tasir', () async {
      final sonuc = await servis().planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe günlük plan'),
        ayrintili: true,
      );

      final ilk = sonuc.planlar.first['ogretim_sureci'] as Map;
      expect(ilk.containsKey('dikkat_cekme'), isTrue);
      expect(ilk.containsKey('farklilastirma'), isTrue);
    });

    test('Yillik varyant sade ogretim sureci uretir', () async {
      final sonuc = await servis().planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe yıllık plan'),
        ayrintili: false,
      );

      final ilk = sonuc.planlar.first['ogretim_sureci'] as Map;
      expect(ilk.containsKey('dikkat_cekme'), isFalse);
    });

    test('Ders saati gercek degerden gelir', () async {
      final sonuc = await servis().planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe yıllık plan'),
        ayrintili: false,
      );
      expect((sonuc.planlar.first['meta'] as Map)['ders_saati'], '6');
    });

    test('35 hafta yoksa yil sonu haftasi EKLENMEZ', () async {
      final sonuc = await servis(kazanimlar: haftalar(28)).planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe yıllık plan'),
        ayrintili: false,
      );
      expect(sonuc.planlar, hasLength(28));
    });
  });

  group('TAHMIN YOK', () {
    test('KRITIK: eksik bilgide uretim yerine soru doner', () async {
      final sonuc = await servis().planHazirla(
        CepteCozumleyici.coz('yıllık plan hazırla'),
        ayrintili: false,
      );

      expect(sonuc.durum, CepteBelgeDurumu.secimGerekli);
      expect(sonuc.basarili, isFalse);
      expect(sonuc.mesaj, contains('hangi sınıf'));
      expect(sonuc.mesaj, contains('hangi ders'));
    });

    test('KRITIK: lisede coklu okul turu SORULUR, secilmez', () async {
      // Anadolu / Fen / Sosyal Bilimler Lisesi planlari farklidir;
      // hangisinin istendigi bilinemez. Dun bu ayrimin eksikligi
      // dropdown cokmesine yol acmisti.
      final sonuc = await servis(dersler: [
        {
          'subject_code': 'FIZIK',
          'subject_name': 'Fizik',
          'publisher': 'Anadolu Lisesi',
        },
        {
          'subject_code': 'FIZIK',
          'subject_name': 'Fizik',
          'publisher': 'Fen Lisesi',
        },
      ]).planHazirla(
        CepteCozumleyici.coz('9. sınıf fizik yıllık plan'),
        ayrintili: false,
      );

      expect(sonuc.durum, CepteBelgeDurumu.secimGerekli);
      expect(sonuc.secenekler, contains('Anadolu Lisesi'));
      expect(sonuc.secenekler, contains('Fen Lisesi'));
    });

    test('KRITIK: veri yoksa uydurma plan uretilmez', () async {
      final sonuc = await servis(kazanimlar: const []).planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe yıllık plan'),
        ayrintili: false,
      );

      expect(sonuc.durum, CepteBelgeDurumu.yapilamaz);
      expect(sonuc.mesaj, contains('bulunmuyor'));
      expect(sonuc.planlar, isEmpty);
    });

    test('Ders o sinifta yoksa gerekce doner', () async {
      final sonuc = await servis(dersler: const []).planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe yıllık plan'),
        ayrintili: false,
      );

      expect(sonuc.durum, CepteBelgeDurumu.yapilamaz);
      expect(sonuc.mesaj, contains('müfredat paketinde bulunmuyor'));
    });
  });

  group('Tatil suzgeci servise de uygulanir', () {
    test('KRITIK: tatil satirlari plana girmez', () async {
      final karisik = <Map<String, dynamic>>[
        ...haftalar(3),
        {
          'id': 99,
          'subject_name': 'Türkçe',
          'unit_title': '1. Dönem Ara Tatili',
          'topic_title': '1. Dönem Ara Tatili',
          'outcome_description': 'Tatil',
          'week_number': 10,
          'teaching_week_number': null,
          'is_holiday_week': 1,
          'date_range_str': 'tatil',
        },
      ];

      final sonuc = await servis(kazanimlar: karisik).planHazirla(
        CepteCozumleyici.coz('5. sınıf türkçe yıllık plan'),
        ayrintili: false,
      );

      expect(sonuc.planlar, hasLength(3));
    });
  });
}
