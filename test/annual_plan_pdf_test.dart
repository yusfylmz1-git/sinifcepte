import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/documents/utils/annual_plan_pdf_generator.dart';

/// Yillik plan PDF uretimi.
///
/// ## Neden bu dosya var
/// `AnnualPlanPdfGenerator` icin HIC test yoktu; gunluk planin testi
/// vardi ama yillik planinki yazilmamisti. Yillik plan A4 YATAY tabloda
/// her haftayi TEK SATIRA basar, yani tasmaya gunluk plandan cok daha
/// yatkindir.
///
/// Risk somut: mufredat paketi duzeltildikten sonra (kazanim kirpmasi
/// dil derslerinde okuma/konusma/yazmayi siliyordu) bir hafta artik
/// dort beceri alaninin kazanimlarini birden tasiyor. 566 kayitta 15'ten
/// cok kazanim var; 6. sinif Turkce'de bir hafta 33 kazanim tasiyor.
/// Sinirsiz basilirsa satir tasiyor ve sayfa okunmaz oluyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const teacher = TeacherProfileModel(
    id: 'test_teacher',
    firstName: 'Ayşe',
    lastName: 'Demir',
    gender: 'Kadın',
    branch: 'Türkçe',
    schoolName: 'Mimar Sinan Ortaokulu',
    schoolPrincipalName: 'Mehmet Yılmaz',
    email: 'ayse@meb.k12.tr',
  );

  Map<String, dynamic> hafta(int no, List<String> ciktilar) => {
        'meta': {
          'ders': 'Türkçe',
          'sinif': '6. Sınıf',
          'hafta': '$no. Hafta',
          'tarih_araligi': '14 - 18 Eylül 2026',
          'ders_saati': '6',
          'tema_unite': 'OYUN DÜNYASI',
        },
        'kazanimlar_ve_surec': {
          'ogrenme_ciktilari': ciktilar,
          'surec_bilesenleri': const ['a) Ipuclarini belirler.'],
        },
        'ozel_alanlar': const {
          'alan_becerileri': 'TAB1. Dinleme/İzleme',
          'kavramsal_beceriler': 'KB2.4. Çözümleme',
          'sosyal_duygusal_ogrenme_becerileri': 'SDB2.1. İletişim',
          'okuryazarlik_becerileri': 'OB1. Bilgi Okuryazarlığı',
          'degerler': 'D14. Saygı',
          'disiplinler_arasi_iliskiler': 'Sosyal Bilgiler',
        },
        'ogretim_sureci': const {},
      };

  test('Yillik plan PDF baytlari uretilir', () async {
    final bytes = await AnnualPlanPdfGenerator.generate(
      allWeeksPlanData: [hafta(1, const ['T.D.6.2. Strateji secimi'])],
      teacher: teacher,
      ders: 'Türkçe',
      sinif: '6. Sınıf',
      academicYear: '2026-2027',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));
    expect(bytes[0], 0x25); // %
    expect(bytes[1], 0x50); // P
    expect(bytes[2], 0x44); // D
    expect(bytes[3], 0x46); // F
  });

  test('KRITIK: 33 kazanimli hafta tabloyu tasirmadan uretilir', () {
    // 6. sinif Turkce'de gercek durum: dort beceri alani birden.
    final ciktilar = List.generate(
      33,
      (i) => 'T.D.6.${i + 1}. Dinledigini/izledigini cozumleyebilme becerisi',
    );

    final metin = AnnualPlanPdfGenerator.hucreListesiForTest(ciktilar);
    final satirlar = metin.split('\n');

    expect(satirlar.length, lessThanOrEqualTo(9),
        reason: 'A4 yatay tabloda bir hafta tek satira basilir; '
            '33 madde sayfayi okunmaz yapiyordu');
    expect(metin, contains('25 kazanım daha'),
        reason: 'Kesilen kazanimlar SAYIYLA bildirilmeli, sessizce kaybolmamali');
  });

  test('Az kazanimli haftada liste kisaltilmaz', () {
    final ciktilar = List.generate(4, (i) => 'T.D.6.$i. Kazanim');
    final metin = AnnualPlanPdfGenerator.hucreListesiForTest(ciktilar);

    expect(metin.split('\n'), hasLength(4));
    expect(metin, isNot(contains('daha')));
  });

  test('33 kazanimli hafta PDF olarak da uretilebilir', () async {
    final bytes = await AnnualPlanPdfGenerator.generate(
      allWeeksPlanData: [
        hafta(
          1,
          List.generate(33, (i) => 'T.D.6.${i + 1}. Uzun kazanim metni'),
        ),
      ],
      teacher: teacher,
      ders: 'Türkçe',
      sinif: '6. Sınıf',
      academicYear: '2026-2027',
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes[0], 0x25);
  });
}
