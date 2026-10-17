import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Menu yapisi: her is TEK yerden acilir.
///
/// ## Neden bu test var
/// Menude iki farkli ayrim mantigi ayni anda isliyordu: kartlarin bir
/// kismi ISE gore ("Kazanimlar", "Sinav Islemleri"), bir kismi CIKTI
/// TURUNE gore ("Evraklarim", "Analiz & Rapor") ayrilmisti. Sonuc,
/// ayni isin uc ayri yerden acilmasiydi:
///
///   * kurul tutanaklari -> Evraklarim VE Sinifim
///   * BEP/rehberlik     -> Rehberlik VE Sinifim
///   * katilim raporu    -> Katilim VE Analiz VE Sinifim
///
/// Kural: belge, onu ureten isin yaninda durur. Bu test kopyalarin
/// geri gelmedigini dogrular.
void main() {
  String oku(String yol) => File(yol).readAsStringSync();

  const sinifim = 'lib/features/classes/screens/my_class_hub_screen.dart';
  const anaSayfa = 'lib/features/dashboard/screens/dashboard_screen.dart';
  // 17 Ekim 2026: "Diğer Evraklar" sayfası alt çubuktaki Evraklar
  // sekmesi oldu (tek katalog).
  const evraklar =
      'lib/features/documents/presentation/views/evraklar_sekmesi.dart';

  group('Kopya girisler geri gelmedi', () {
    test('KRITIK: kurul tutanaklari Sinifim`da YOK', () {
      // Kendi karti var ("Kurullar"); Sinifim'daki kategori kaldirildi.
      expect(oku(sinifim).contains('Kurul Tutanak Taslakları'), isFalse,
          reason: 'kurul tutanaklari iki yerden aciliyor');
    });

    test('KRITIK: rehberlik formlari Sinifim`da YOK', () {
      // Rehberlik kendi ekraninda (dort sekme); Sinifim'daki kategori
      // ayni dort belgeyi aciyordu.
      expect(oku(sinifim).contains('Rehberlik, Görüşmeler & BEP'), isFalse,
          reason: 'BEP iki yerden aciliyor');
    });
  });

  group('Ana sayfa kartlari', () {
    test('KRITIK: "Analiz & Rapor" karti kaldirildi', () {
      // Bir is degil, cikti turuydu. Raporlar kendi islerine dagildi.
      expect(oku(anaSayfa).contains("'title': 'Analiz & Rapor'"), isFalse);
    });

    test('KRITIK: evraklar alt cubukta; ana sayfada ikinci kapi yok', () {
      // "Diger Evraklar" karti ana sayfadaydi; evraklar alt cubukta sekme
      // olunca ayni ekranda ikinci kapi oldu ve kalkti.
      final kod = oku(anaSayfa);
      expect(kod.contains("'title': 'Diğer Evraklar'"), isFalse);
      expect(kod.contains('EvraklarSekmesi'), isFalse);
      expect(
        oku('lib/features/navigation/screens/main_navigation_screen.dart'),
        contains('const EvraklarSekmesi()'),
      );
    });

    test('KRITIK: kurul tutanaklari ana sayfada AYRI KART degil', () {
      // Kart tam bir yer kapliyordu ama arkasinda YALNIZCA iki belge
      // vardi (zumre + SOK). Ogretmen tutanak icin Kurullar'a, yillik
      // plan icin Diger Evraklar'a, nobetci listesi icin Sinifim'a
      // gidiyordu; ucu de evrak.
      final kod = oku(anaSayfa);
      expect(kod.contains("'title': 'Kurullar'"), isFalse,
          reason: 'kurul tutanaklari Evraklar sekmesinde olmali');
      expect(kod.contains("'title': 'Evraklarım'"), isFalse);
    });

    test('KRITIK: kurul tutanaklari Evraklar sekmesinde', () {
      // Tek yerden acilir: sinifa BAGLI OLMAYAN evraklarin yani.
      final kod = oku(evraklar);
      expect(kod, contains("ad: 'Kurul Tutanakları'"));
      expect(kod, contains('DocumentsHubView'));
    });

    test('KRITIK: sinif evraklari Evraklar`da gosteriliyor, evine goturuyor', () {
      // Oturma plani, nobetci listesi gibi belgeler once "hangi
      // sinif?" sorusunu gerektirdigi icin Siniflar sekmesinde KALIR; ama
      // ogretmen "evrak" diye buraya baktiginda nerede olduklarini
      // gormeli. Kart ayni ekrani ikinci kapidan ACMAZ, sekmeye goturur.
      final kod = oku(evraklar);
      expect(kod, contains("ad: 'Sınıf Evrakları'"));
      expect(kod, contains('AnaSekme.siniflar'));
      expect(kod.contains('MyClassHubScreen'), isFalse,
          reason: 'Sinifim ikinci kapidan acilmamali');
    });

    test('ana sayfada is bazli kartlar duruyor', () {
      // Kart SAYISI kilitlenmez: kirilgan olcut, her duzen
      // degisikliginde testi bozar. Onemli olan hangi ISLERIN
      // ana sayfada durdugu.
      //
      // 17 Ekim 2026: "Kazanimlar" ve "Cepte" kartlari kaldirildi (tek
      // kapi kurali). Kazanimlar alt sekmede, Cepte ekranin tepesinde
      // arama kutusu olarak duruyor; ayni ekranda ikinci kapi aciyorlardi.
      // Ayni gun "Rehberlik" ve "Diger Evraklar" da Evraklar sekmesine
      // gecti. Kalanlar her gun derste yapilan iki is (kisayol).
      final kod = oku(anaSayfa);
      for (final baslik in [
        'Ders İçi Katılım',
        'Sınav İşlemleri',
      ]) {
        expect(kod, contains("'title': '$baslik'"),
            reason: '$baslik karti ana sayfada olmali');
      }
      for (final baslik in ['Rehberlik', 'Diğer Evraklar']) {
        expect(kod.contains("'title': '$baslik'"), isFalse,
            reason: '$baslik Evraklar sekmesinde; ana sayfada ikinci kapi');
      }
      final ev = oku(evraklar);
      expect(ev, contains('GuidanceHubScreen'));
      expect(ev, contains('ExamOperationsMenuView'));
      expect(kod, contains('CepteAramaView'),
          reason: 'Cepte arama kutusu ana sayfanin tepesinde olmali');
    });
  });

  group('Raporlar kendi isinin yaninda', () {
    test('KRITIK: sinav analizi Sinav Islemleri`nden aciliyor', () {
      final kod =
          oku('lib/features/exam_operations/presentation/views/'
              'exam_operations_menu_view.dart');
      expect(kod, contains('ExamAnalysisListView'),
          reason: 'sinav analizi kendi isinin altinda olmali');
      expect(kod.contains('AnalyticsDashboardView'), isFalse,
          reason: 'kaldirilan ekrana yonlendirme kalmamali');
    });

    test('KRITIK: karne gorusu Sinav Islemleri`nden aciliyor', () {
      // Belgede "Sinav Islemleri'ne tasindi" yaziyordu ama tasinmamisti:
      // yalniz uc cizgili menudeki Raporlar ekranindan aciliyordu. Menu
      // kalkinca evsiz kalacakti (17 Ekim 2026).
      final kod =
          oku('lib/features/exam_operations/presentation/views/'
              'exam_operations_menu_view.dart');
      expect(kod, contains('ClassReportCardCommentsModal.show(context)'));
    });

    test('KRITIK: Raporlar merkezi silindi, adi hicbir yerde gecmiyor', () {
      // Uc raporun ucu de kendi isinin yaninda; merkez ikinci kapiydi.
      expect(
        File('lib/features/analytics/presentation/views/'
                'analytics_dashboard_view.dart')
            .existsSync(),
        isFalse,
      );
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        expect(f.readAsStringSync().contains('AnalyticsDashboardView'),
            isFalse,
            reason: f.path);
      }
    });

    test('KRITIK: kumulatif katilim raporu Katilim ekranindan aciliyor', () {
      final kod =
          oku('lib/features/attendance/presentation/views/'
              'classroom_participation_view.dart');
      expect(kod, contains('ParticipationCumulativeReportsModal'));
    });
  });

  group('Sinifsiz ogretmen', () {
    test('KRITIK: ozel egitim programlari sinif OLMADAN acilabiliyor', () {
      // ORGM programlari salt okunur kaynak; sinifla ilgileri yok.
      // Once "once sinif ekleyin" deyip TUM ekrani kilitliyorduk;
      // yil basinda sinifini henuz tanimlamamis ogretmen hicbir
      // belgeye ulasamiyordu.
      final kod = oku('lib/features/guidance/presentation/screens/'
          'guidance_hub_screen.dart');
      // Tum govde artik `classes.isEmpty ? bos : icerik` degil.
      expect(
        kod.contains('child: classes.isEmpty\n            ? _buildNoClass'),
        isFalse,
        reason: 'ekran tumden kilitlenmemeli',
      );
      expect(kod, contains('const SpecialEducationView()'));
    });
  });
}
