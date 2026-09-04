import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sosyal kulup modulu: veri paketi ve ekran denetimleri.
///
/// ## Neden bu test var
/// Kulup planlari APK'ya gomulu bir varlıktan geliyor. Paket bozuk
/// uretilirse hata kullanicida ortaya cikar: kulup listesi bos gorunur
/// ya da bir kulubun plani eksik aylarla acilir. Burada paketin kendisi
/// denetleniyor.
///
/// Ayrica ekranlarin HER IKI TEMADA da okunur oldugu dogrulaniyor —
/// `theme_contrast_test.dart` ile ayni gerekce.
void main() {
  const paketYolu = 'assets/data/kulup_planlari.json.gz';

  /// Sikistirilmis paketi acar.
  Map<String, dynamic> paketiOku() {
    final bayt = File(paketYolu).readAsBytesSync();
    // UTF-8 sart: "Çevre", "Yeşilay" gibi adlar Latin-1 ile bozulur.
    final ham = utf8.decode(gzip.decode(bayt));
    return jsonDecode(ham) as Map<String, dynamic>;
  }

  group('Kulup veri paketi', () {
    test('KRITIK: paket var ve okunabiliyor', () {
      expect(File(paketYolu).existsSync(), isTrue,
          reason: '$paketYolu yok — `python tool/build_kulup_dataset.py` '
              'calistirilmali');
      expect(() => paketiOku(), returnsNormally);
    });

    test('KRITIK: EK-4 cizelgesinin 52 kulubu de var', () {
      final kulupler = paketiOku()['kulupler'] as List;
      expect(kulupler.length, 52,
          reason: 'EK-4 (RG-18/1/2023-32077) 52 kulup listeliyor');

      final numaralar =
          kulupler.map((k) => (k as Map)['no'] as int).toSet();
      final eksik = [
        for (var i = 1; i <= 52; i++)
          if (!numaralar.contains(i)) i
      ];
      expect(eksik, isEmpty, reason: 'EK-4 sira numarasi eksik: $eksik');
    });

    test('KRITIK: her kulubun 10 ayi dolu', () {
      const aylar = [
        'Eylül', 'Ekim', 'Kasım', 'Aralık', 'Ocak',
        'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      ];

      final bozuk = <String>[];
      for (final k in paketiOku()['kulupler'] as List) {
        final kulup = k as Map<String, dynamic>;
        final plan = kulup['plan'] as List;
        final ad = kulup['ad'] as String;

        if (plan.length != 10) {
          bozuk.add('$ad: ${plan.length} ay');
          continue;
        }
        for (var i = 0; i < plan.length; i++) {
          final satir = plan[i] as Map<String, dynamic>;
          if (satir['ay'] != aylar[i]) {
            bozuk.add('$ad: ${i + 1}. ay ${satir['ay']} (${aylar[i]} olmali)');
          }
          if ((satir['amac'] as String).trim().isEmpty ||
              (satir['etkinlik'] as String).trim().isEmpty) {
            bozuk.add('$ad / ${satir['ay']}: bos alan');
          }
        }
      }
      expect(bozuk, isEmpty, reason: bozuk.join(' | '));
    });

    test('KRITIK: kulup kodlari benzersiz', () {
      // Kod `club_members.club_code` ile eslesiyor; tekrar ederse iki
      // kulup ayni plani gosterir.
      final kodlar = [
        for (final k in paketiOku()['kulupler'] as List)
          (k as Map)['kod'] as String
      ];
      expect(kodlar.toSet().length, kodlar.length,
          reason: 'tekrar eden kulup kodu var');
    });

    test('icerik yazim kurallarina uyuyor', () {
      // `tool/PANO_ICERIK_KURALLARI.md`: yil sabitlenmez, sube adi
      // gecmez. Icerik her yil ve her subede kullanilabilmeli.
      final yilKalibi = RegExp(r'20\d{2}\s*[-–]\s*20\d{2}');
      final subeKalibi = RegExp(r'\b[1-8]\s*[-/]\s*[A-DEF]\b');

      final ihlal = <String>[];
      for (final k in paketiOku()['kulupler'] as List) {
        final kulup = k as Map<String, dynamic>;
        for (final s in kulup['plan'] as List) {
          final satir = s as Map<String, dynamic>;
          final metin = '${satir['amac']} ${satir['etkinlik']}';
          if (yilKalibi.hasMatch(metin)) {
            ihlal.add('${kulup['ad']} / ${satir['ay']}: yil sabitlenmis');
          }
          if (subeKalibi.hasMatch(metin)) {
            ihlal.add('${kulup['ad']} / ${satir['ay']}: sube adi gecmis');
          }
        }
      }
      expect(ihlal, isEmpty, reason: ihlal.join(' | '));
    });
  });

  group('Kulup ekranlari', () {
    const ekranlar = [
      'lib/features/clubs/presentation/screens/clubs_hub_screen.dart',
      'lib/features/clubs/presentation/views/club_detail_view.dart',
      'lib/features/clubs/presentation/widgets/club_catalog_sheet.dart',
      'lib/features/clubs/presentation/widgets/club_plan_editor.dart',
      'lib/features/clubs/presentation/widgets/club_activity_editor.dart',
      'lib/features/clubs/presentation/widgets/club_member_picker_sheet.dart',
    ];

    test('KRITIK: her ekran iki temayi da ele aliyor', () {
      for (final d in ekranlar) {
        expect(File(d).existsSync(), isTrue, reason: '$d yok');
        final kod = File(d).readAsStringSync();
        expect(kod.contains('isDark') || kod.contains('Brightness.dark'),
            isTrue,
            reason: '$d tema ayrimi yapmiyor');
      }
    });

    test('KRITIK: cip ve metin renkleri acikca verilmis', () {
      // BEP cip hatasinin tekrari: `label: Text(...)` rengi
      // belirtilmezse aydinlik modda beyaz kalip okunmuyordu.
      final bozuk = <String>[];
      for (final d in ekranlar) {
        if (!File(d).existsSync()) continue;
        final satirlar = File(d).readAsLinesSync();
        for (var i = 0; i < satirlar.length; i++) {
          if (!satirlar[i].contains('label: Text')) continue;
          final pencere =
              satirlar.sublist(i, (i + 8).clamp(0, satirlar.length)).join(' ');
          if (!pencere.contains('color:')) {
            bozuk.add('${d.split('/').last}:${i + 1}');
          }
        }
      }
      expect(bozuk, isEmpty,
          reason: 'renk devralan cip etiketi: ${bozuk.join(", ")}');
    });

    test('KRITIK: Expanded kullanan sayfa ResponsiveBottomSheet ile acilmiyor',
        () {
      // YASANDI: "Kulup Kur"a basinca sayfa BOS aciliyordu.
      //
      // ResponsiveBottomSheet icerigi SingleChildScrollView'a koyuyor,
      // yani SINIRSIZ yukseklik veriyor. Icerideki `Expanded` orada
      // sifir yukseklik alir ve liste hic cizilmez — hata sessiz,
      // analiz de yakalamiyor.
      //
      // Kural: `Expanded` kullanan sayfa kendi yuksekligini bilen bir
      // kapsayiciyla (DraggableScrollableSheet) acilmali.
      const sayfalar = [
        'lib/features/clubs/presentation/widgets/club_catalog_sheet.dart',
        'lib/features/clubs/presentation/widgets/club_member_picker_sheet.dart',
      ];

      for (final d in sayfalar) {
        final kod = File(d).readAsStringSync();
        if (!kod.contains('Expanded(')) continue;
        // Aciklama yorumlarinda ad gecebilir; aranan CAGRIDIR.
        expect(kod.contains('ResponsiveBottomSheet.show'), isFalse,
            reason: '$d hem Expanded kullaniyor hem '
                'ResponsiveBottomSheet ile aciliyor — liste cizilmez');
        expect(kod.contains('DraggableScrollableSheet'), isTrue,
            reason: '$d Expanded kullaniyor; kendi yuksekligini bilen '
                'bir kapsayiciyla acilmali');
      }
    });

    test('KRITIK: ogretim yili sabitlenmemis', () {
      // Sinif belgelerinde "2024-2025" elle yazilmisti ve her yil
      // eskiyordu. Kulup belgeleri yili AppDateFormatter'dan alir.
      const pdf = 'lib/features/clubs/utils/club_pdf_generator.dart';
      final kod = File(pdf).readAsStringSync();
      expect(RegExp(r"'20\d{2}-20\d{2}").hasMatch(kod), isFalse,
          reason: 'kulup PDF ureticisinde ogretim yili sabitlenmis');
      expect(kod.contains('AppDateFormatter.academicYearLabel'), isTrue,
          reason: 'ogretim yili hesaplanarak gelmeli');
    });
  });

  group('Belgeler bastan hazir', () {
    test('KRITIK: kulup kurulunca faaliyet raporu tohumlaniyor', () {
      // Ogretmen kulubu kurar kurmaz UC PDF'i de indirebilmeli.
      // Rapor bos gelirse yil sonunda on ayi hatirlamak gerekiyordu.
      const provider = 'lib/features/clubs/providers/club_provider.dart';
      final kod = File(provider).readAsStringSync();
      expect(kod.contains('faaliyetleriTohumla'), isTrue,
          reason: 'kulup kurulumunda faaliyet kayitlari olusturulmuyor');
      // Hem katalogdan hem cizelge disi kurulumda cagrilmali.
      expect('faaliyetleriTohumla'.allMatches(kod).length,
          greaterThanOrEqualTo(2),
          reason: 'tohumlama yalnizca bir kurulum yolunda cagriliyor');
    });

    test('KRITIK: tohumlama mevcut kaydin uzerine yazmiyor', () {
      // Ogretmenin yazdigi metin kaybolmamali.
      const repo =
          'lib/features/clubs/data/repositories/club_repository.dart';
      final kod = File(repo).readAsStringSync();
      final govde = kod.substring(kod.indexOf('faaliyetleriTohumla'));
      final son = govde.substring(0, govde.indexOf('faaliyetKaydet'));
      expect(son.contains('ConflictAlgorithm.ignore'), isTrue,
          reason: 'tohumlama replace kullaniyor — ogretmenin yazdigi '
              'metnin uzerine yazar');
    });

    test('KRITIK: uye listesi bosken elle doldurulacak sablon basiliyor', () {
      // "Uye eklenmemis" yazan PDF hicbir ise yaramaz; ogretmen
      // listeyi henuz girmemis olsa da evrak bugun lazim olabilir.
      const pdf = 'lib/features/clubs/utils/club_pdf_generator.dart';
      final kod = File(pdf).readAsStringSync();
      expect(kod.contains('_bosUyeSablonu'), isTrue,
          reason: 'bos uye listesinde sablon uretilmiyor');
      expect(kod.contains("_bosUyari('Bu kulübe henüz üye eklenmemiş.')"),
          isFalse,
          reason: 'bos listede hala kullanilamaz uyari basiliyor');
    });

    test('KRITIK: uc belge tek yerden aciliyor', () {
      const detay =
          'lib/features/clubs/presentation/views/club_detail_view.dart';
      final kod = File(detay).readAsStringSync();
      for (final c in ['yillikPlanAc', 'faaliyetRaporuAc', 'uyeListesiAc']) {
        expect(kod.contains(c), isTrue,
            reason: 'Belgeler sayfasinda $c cagrilmiyor');
      }
    });
  });

  group('Menu baglantisi', () {
    const digerEvraklar =
        'lib/features/documents/presentation/views/other_documents_view.dart';

    test('KRITIK: kulup ekrani menuye bagli', () {
      final kod = File(digerEvraklar).readAsStringSync();
      expect(kod.contains('ClubsHubScreen'), isTrue,
          reason: 'Sosyal Kulupler ekrani menuden acilmiyor');
    });

    test('KRITIK: "Yakinda" yer tutucusu kaldirilmis', () {
      // Modul hazir; ayni is hem hazir kart hem "yakinda" olarak
      // gorunmemeli.
      final kod = File(digerEvraklar).readAsStringSync();
      expect(kod.contains("ad: 'Sosyal Kulüp Planı'"), isFalse,
          reason: 'kulup hem hazir hem "yakinda" gorunuyor');
    });
  });
}
