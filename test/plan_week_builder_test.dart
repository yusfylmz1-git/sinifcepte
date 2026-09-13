import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/documents/utils/plan_week_builder.dart';

/// Yillik/gunluk plan uretiminin icerik dogrulugu.
///
/// ## Gercek olay
/// Planlar "MEB resmi plani" olarak sunuluyordu ama uretim katmani
/// kaynak veriyi bozuyordu. Dort ayri kusur vardi ve hicbiri teste
/// takilmiyordu: mevcut PDF testleri yalnizca `%PDF-` sihirli baytina
/// bakiyordu, yani icerik yanlis olsa da test yesil kaliyordu.
///
/// Bu dosya icerigi kilitler.
void main() {
  // Veri paketindeki gercek sutun adlariyla bir ders satiri kurar.
  Map<String, dynamic> satir({
    required int weekNumber,
    int? teachingWeekNumber,
    String unitTitle = 'ÜNİTE',
    String topicTitle = 'KONU',
    String dateRangeStr = '',
    String officialActivity = '',
    String maarifSummary = 'Bu hafta konu islenir.',
    int isHolidayWeek = 0,
  }) =>
      {
        'week_number': weekNumber,
        'teaching_week_number': teachingWeekNumber,
        'unit_title': unitTitle,
        'topic_title': topicTitle,
        'date_range_str': dateRangeStr,
        'official_activity': officialActivity,
        'maarif_summary': maarifSummary,
        'is_holiday_week': isHolidayWeek,
        'id': weekNumber,
      };

  group('Tatil suzgeci', () {
    test('KRITIK: "tatil" basligi tasiyan GERCEK ders silinmez', () {
      // 10. sinif Arapca "UNITE 4: Tatile Hazirlaniyorum" -> 7 gercek hafta.
      // Eski metin aramasi bunlari siliyor, 36 haftalik plan 28'e dusuyordu.
      final satirlar = [
        satir(
          weekNumber: 29,
          teachingWeekNumber: 29,
          unitTitle: 'ÜNİTE 4 : Tatile Hazırlanıyorum',
          topicTitle: 'Tatile Hazırlanıyorum',
        ),
      ];

      final dersler = PlanWeekBuilder.dersHaftalari(satirlar);

      expect(dersler, hasLength(1),
          reason: 'Unite adinda "tatil" gecmesi dersi tatil yapmaz');
    });

    test('KRITIK: gercek tatil haftasi plana girmez', () {
      final satirlar = [
        satir(weekNumber: 10, teachingWeekNumber: null, unitTitle: '1. Dönem Ara Tatili', isHolidayWeek: 1),
        satir(weekNumber: 11, teachingWeekNumber: 10),
      ];

      final dersler = PlanWeekBuilder.dersHaftalari(satirlar);

      expect(dersler, hasLength(1));
      expect(dersler.first['week_number'], 11);
    });

    test('Ders haftalari kendi numarasina gore siralanir', () {
      final satirlar = [
        satir(weekNumber: 13, teachingWeekNumber: 12),
        satir(weekNumber: 11, teachingWeekNumber: 10),
        satir(weekNumber: 12, teachingWeekNumber: 11),
      ];

      final dersler = PlanWeekBuilder.dersHaftalari(satirlar);

      expect(
        dersler.map(PlanWeekBuilder.dersHaftaNo).toList(),
        [10, 11, 12],
      );
    });
  });

  group('Dropdown bilesik anahtari', () {
    // Lisede ayni ders uc okul turuyle geldigi icin dropdown value'su
    // `subject_code|publisher`. Bu anahtarin ders kodu SANILIP sorguya
    // verilmesi gercek bir hataydi: `subject_code = 'TURKCE|'` hicbir
    // satir dondurmedi, ekran "plan bulunamadi" dedi (cihazda gozlendi).
    String anahtar(String kod, String yayinci) => '$kod|$yayinci';

    String kodCoz(String anahtar) => anahtar.split('|').first;

    test('KRITIK: anahtar ders kodu DEGILDIR', () {
      expect(anahtar('TURKCE', ''), 'TURKCE|');
      expect(anahtar('TURKCE', ''), isNot('TURKCE'),
          reason: 'Anahtar dogrudan subject_code olarak kullanilamaz');
    });

    test('Ayni ders farkli yayinci -> farkli anahtar', () {
      expect(
        anahtar('FIZIK', 'Fen Lisesi'),
        isNot(anahtar('FIZIK', 'Anadolu Lisesi')),
        reason: 'Ayni value iki kez uretilirse Dropdown assertion ile coker',
      );
    });

    test('Anahtardan ders kodu geri okunur', () {
      expect(kodCoz(anahtar('FIZIK', 'Fen Lisesi')), 'FIZIK');
      expect(kodCoz(anahtar('TURKCE', '')), 'TURKCE');
    });
  });

  group('Eski tohumlama (sutun bos)', () {
    test('KRITIK: teaching_week_number bos iken plan yine uretilir', () {
      // Sutun tabloya ALTER TABLE ile eklendi; ALTER ile eklenen sutun
      // MEVCUT satirlarda NULL kalir ve surum 12 temizligine dahil
      // degildi. Guncelleme alan cihazda tum satirlarda bostu. Tek olcut
      // bu sutun olunca HER SATIR elendi ve ekran "plan bulunamadi" dedi.
      // Cihazda bire bir gozlendi (5. sinif Turkce, 39 satir mevcutken).
      final eskiVeri = [
        satir(weekNumber: 1, teachingWeekNumber: null),
        satir(weekNumber: 2, teachingWeekNumber: null),
        satir(weekNumber: 10, teachingWeekNumber: null, isHolidayWeek: 1),
        satir(weekNumber: 11, teachingWeekNumber: null),
      ];

      final dersler = PlanWeekBuilder.dersHaftalari(eskiVeri);

      expect(dersler, hasLength(3),
          reason: 'Sutun bos olsa da tatil disi satirlar plana girmeli');
      expect(PlanWeekBuilder.planUretilebilir(dersler), isTrue);
    });

    test('Sutun bosken hafta no week_number-dan okunur', () {
      final s = satir(weekNumber: 7, teachingWeekNumber: null);
      expect(PlanWeekBuilder.dersHaftaNo(s), 7);
    });

    test('Sutun DOLU iken eski olcute dusulmez', () {
      // Karisik veri: biri dolu, biri bos. Dolu olan olcut alinir.
      final karisik = [
        satir(weekNumber: 1, teachingWeekNumber: 1),
        satir(weekNumber: 10, teachingWeekNumber: null, isHolidayWeek: 1),
      ];

      final dersler = PlanWeekBuilder.dersHaftalari(karisik);

      expect(dersler, hasLength(1));
      expect(dersler.first['week_number'], 1);
    });
  });

  group('Hafta numarasi ve tarih', () {
    test('KRITIK: hafta no sira indeksinden degil veriden okunur', () {
      // Tatiller atildiktan sonra yeniden numaralamak, ders haftasi ile
      // takvim haftasini karistiriyordu: 10. ders haftasi takvimdeki
      // 10. haftanin (ara tatil) tarihini aliyordu.
      final s = satir(weekNumber: 11, teachingWeekNumber: 10);

      expect(PlanWeekBuilder.dersHaftaNo(s), 10);
      expect(PlanWeekBuilder.takvimHaftaNo(s), 11,
          reason: 'Tarih TAKVIM haftasindan hesaplanmali');
    });

    test('KRITIK: tarih takvim haftasindan hesaplanir, ders haftasindan degil', () {
      final s = satir(weekNumber: 11, teachingWeekNumber: 10);
      final cagrilan = <int>[];

      PlanWeekBuilder.tarihAraligi(s, (hafta) {
        cagrilan.add(hafta);
        return 'X';
      });

      expect(cagrilan, [11],
          reason: 'Ders haftasi (10) ile hesaplanirsa tarih bir hafta kayar');
    });

    test('Satirda hazir tarih varsa o kullanilir', () {
      final s = satir(
        weekNumber: 1,
        teachingWeekNumber: 1,
        dateRangeStr: '14 - 18 Eylül 2026 (1. Hafta)',
      );

      final tarih = PlanWeekBuilder.tarihAraligi(s, (_) => 'HESAPLANAN');

      expect(tarih, '14 - 18 Eylül 2026',
          reason: 'Parantezli aciklama temizlenmeli');
    });
  });

  group('Haftalik ders saati', () {
    test('KRITIK: her ders "2 saat" degil', () {
      // Pakette lessonHours alani hic yok; kod `?? '2'` yaziyordu.
      // Teftiste ilk bakilan kolon budur.
      expect(PlanWeekBuilder.haftalikDersSaati(5, 'TURKCE'), 6);
      expect(PlanWeekBuilder.haftalikDersSaati(5, 'MAT'), 5);
      expect(PlanWeekBuilder.haftalikDersSaati(5, 'FEN'), 4);
      expect(PlanWeekBuilder.haftalikDersSaati(1, 'TURKCE'), 10);
      expect(PlanWeekBuilder.haftalikDersSaati(9, 'MAT'), 6);
    });

    test('Ayni ders sinifa gore degisir', () {
      expect(PlanWeekBuilder.haftalikDersSaati(5, 'TURKCE'), 6);
      expect(PlanWeekBuilder.haftalikDersSaati(7, 'TURKCE'), 5);
      expect(PlanWeekBuilder.haftalikDersSaati(9, 'FIZIK'), 2);
      expect(PlanWeekBuilder.haftalikDersSaati(11, 'FIZIK'), 4);
    });

    test('KRITIK: bilinmeyen derste sayi uydurulmaz', () {
      expect(PlanWeekBuilder.haftalikDersSaati(11, 'BILINMEYEN_DERS'), isNull);
      expect(PlanWeekBuilder.dersSaatiMetni(11, 'BILINMEYEN_DERS'), '—',
          reason: 'Yanlis sayi basmaktansa ogretmen elle doldurur');
    });
  });

  group('Etkinlik metinleri', () {
    test('KRITIK: "ogrencilerle tanisilir" yalnizca 1. haftada', () {
      // Resmi etkinlik alani ders haftalarinin %56'sinda bos. Eski kod
      // bos olan HER haftaya bu cumleyi basiyordu; mart ayindaki 22.
      // haftanin planinda da "ogretim yilinin ilk dersi" yaziyordu.
      final yirmiIkinci = PlanWeekBuilder.etkinlikAdimlari(
        satir: satir(weekNumber: 24, teachingWeekNumber: 22),
        haftaNo: 22,
        temaBasligi: 'Gelenekler',
        surecBilesenleri: const [],
      );

      expect(
        yirmiIkinci.any((a) => a.contains('ilk dersi')),
        isFalse,
        reason: '22. haftada tanisma metni olamaz',
      );
    });

    test('1. haftada tanisma metni korunur', () {
      final ilk = PlanWeekBuilder.etkinlikAdimlari(
        satir: satir(weekNumber: 1, teachingWeekNumber: 1),
        haftaNo: 1,
        temaBasligi: 'Oyun Dünyası',
        surecBilesenleri: const [],
      );

      expect(ilk.any((a) => a.contains('ilk dersi')), isTrue);
    });

    test('Resmi etkinlik varsa sablon yerine o kullanilir', () {
      final adimlar = PlanWeekBuilder.etkinlikAdimlari(
        satir: satir(
          weekNumber: 5,
          teachingWeekNumber: 5,
          officialActivity:
              'Ogrenciler metni sessizce okur ve anahtar kelimeleri belirler. '
              'Ardindan grup calismasiyla kavram haritasi olusturulur.',
        ),
        haftaNo: 5,
        temaBasligi: 'Konu',
        surecBilesenleri: const [],
      );

      expect(adimlar.first, contains('sessizce okur'));
    });
  });

  group('Sahte plan uretimi', () {
    test('KRITIK: veri yoksa plan uretilmez', () {
      // Eskiden 36 haftalik tamamen uydurma plan sessizce uretiliyordu;
      // ogretmen bos bir dersin planini "hazir" sanip teftise goturebilirdi.
      expect(PlanWeekBuilder.planUretilebilir(const []), isFalse);
      expect(
        PlanWeekBuilder.planYokGerekcesi('Felsefe', 11),
        contains('bulunmuyor'),
      );
    });

    test('Veri varsa uretilir', () {
      final dersler = PlanWeekBuilder.dersHaftalari([
        satir(weekNumber: 1, teachingWeekNumber: 1),
      ]);
      expect(PlanWeekBuilder.planUretilebilir(dersler), isTrue);
    });
  });
}
