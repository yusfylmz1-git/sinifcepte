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

  // 18 Ekim 2026: Sinifim merkezi kalkti; sinif evraklari sinif
  // sayfasindaki Evrak dugmesinden acilan sayfada.
  const sinifim = 'lib/features/classes/screens/sinif_evraklari_ekrani.dart';
  const anaSayfa = 'lib/features/dashboard/screens/dashboard_screen.dart';
  // 17 Ekim 2026: "Diğer Evraklar" sayfası Evraklar oldu (tek katalog).
  // 26 Ekim 2026: alt çubukta değil, Özet'teki "Evraklar" düğmesinden
  // açılan sayfa.
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

    test('KRITIK: Evraklar Ozet`teki dugmeden acilir, alt cubukta degil', () {
      // 17 Ekim'de alt cubuga tasinmisti; kullanici geri istedi: "Ozet'teki
      // dugmelerin kalkmasi iyi olmadi" (26 Ekim 2026). Tek kapi: Ozet.
      final kod = oku(anaSayfa);
      expect(kod.contains("'title': 'Diğer Evraklar'"), isFalse);
      expect(kod, contains("'title': 'Evraklar'"));
      expect(kod, contains('const EvraklarSekmesi()'));
      expect(
        oku('lib/features/navigation/screens/main_navigation_screen.dart').contains('EvraklarSekmesi'),
        isFalse,
      );
    });

    test('KRITIK: kurul tutanaklari ana sayfada AYRI KART degil', () {
      // Kart tam bir yer kapliyordu ama arkasinda YALNIZCA iki belge
      // vardi (zumre + SOK). Ogretmen tutanak icin Kurullar'a, yillik
      // plan icin Diger Evraklar'a, nobetci listesi icin Sinifim'a
      // gidiyordu; ucu de evrak.
      final kod = oku(anaSayfa);
      expect(kod.contains("'title': 'Kurullar'"), isFalse,
          reason: 'kurul tutanaklari Evraklar sayfasinda olmali');
      expect(kod.contains("'title': 'Evraklarım'"), isFalse);
    });

    test('KRITIK: kurul tutanaklari Evraklar sayfasinda, ara sayfasiz', () {
      // Tek yerden acilir: sinifa BAGLI OLMAYAN evraklarin yani. DEG-1
      // (30 Ekim 2026): "Kurul Tutanaklari" ara sayfasi atlandi; zumre ve
      // SOK tek dokunusta acilir (ara sayfa Cepte aramasi icin duruyor).
      final kod = oku(evraklar);
      expect(kod, contains('CouncilMinutesView.open(context, CouncilKind.zumre)'));
      expect(kod, contains('CouncilMinutesView.open(context, CouncilKind.sok)'));
      expect(kod.contains('DocumentsHubView'), isFalse);
    });

    test('KRITIK: sinif evraklari Evraklar`da gosteriliyor, evine goturuyor', () {
      // Oturma plani, nobetci listesi gibi belgeler once "hangi
      // sinif?" sorusunu gerektirdigi icin sinif sayfasinda KALIR; ama
      // ogretmen "evrak" diye buraya baktiginda nerede olduklarini
      // gormeli. Kart sinif listesini acar.
      final kod = oku(evraklar);
      expect(kod, contains("ad: 'Sınıf Evrakları'"));
      expect(kod, contains('ClassListScreen.ac(context)'));
      expect(kod.contains('MyClassHubScreen'), isFalse,
          reason: 'Sinifim ikinci kapidan acilmamali');
    });

    test('ana sayfada is bazli kartlar duruyor', () {
      // Kart SAYISI kilitlenmez: kirilgan olcut, her duzen
      // degisikliginde testi bozar. Onemli olan hangi ISLERIN
      // ana sayfada durdugu.
      //
      // 26 Ekim 2026 (kullanici karari): Ozet'te alti dugme. 17 Ekim'de
      // "tek kapi" kuraliyla Kazanimlar, Rehberlik ve Diger Evraklar alt
      // cubuga tasinmisti; alt cubuk artik Ozet · Ders Programi · Sinifim ·
      // Profil. Cepte kart degil, ekranin tepesinde arama kutusu.
      final kod = oku(anaSayfa);
      for (final baslik in [
        'Kazanımlar',
        'Ders İçi Katılım',
        'Rehberlik',
        'Sınıflar',
        'Sınav İşlemleri',
        'Evraklar',
      ]) {
        expect(kod, contains("'title': '$baslik'"),
            reason: '$baslik dugmesi Ozet\'te olmali');
      }
      for (final baslik in ['Diğer Evraklar', 'Cepte']) {
        expect(kod.contains("'title': '$baslik'"), isFalse, reason: baslik);
      }
      // Evraklar'da sinav belgeleri dogrudan (DEG-1); Sinav Islemleri
      // sayfasi Ozet'teki dugmeden acilir.
      final ev = oku(evraklar);
      expect(ev, contains('GuidanceHubScreen'));
      expect(ev, contains('ExamAnalysisListView'));
      expect(ev, contains('ClassReportCardCommentsModal.show(context)'));
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
    test('KRITIK: rehberlik ekrani sinif OLMADAN da aciliyor', () {
      // Once "once sinif ekleyin" deyip TUM ekrani kilitliyorduk.
      // Artik kartlar gorunur, kullanilamayan kart nedenini yazar
      // (rehberlik_ekrani_test.dart bunu ekranda sinar).
      final kod = oku('lib/features/guidance/presentation/screens/'
          'guidance_hub_screen.dart');
      expect(kod.contains('_buildNoClass'), isFalse,
          reason: 'ekran tumden kilitlenmemeli');
      expect(kod, contains("'Önce bir sınıf ekleyin.'"));
    });
  });
}
