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

    test('KRITIK: yerine "Diger Evraklar" karti var', () {
      final kod = oku(anaSayfa);
      expect(kod, contains("'title': 'Diğer Evraklar'"));
      expect(kod, contains('OtherDocumentsView'));
    });

    test('KRITIK: "Evraklarim" -> "Kurullar" olarak adlandirildi', () {
      // Icinde YALNIZCA iki kurul tutanagi var; "Evraklarim" adi
      // uygulamadaki onlarca baska belgeyi de kapsiyormus gibi
      // duruyordu.
      final kod = oku(anaSayfa);
      expect(kod, contains("'title': 'Kurullar'"));
      expect(kod.contains("'title': 'Evraklarım'"), isFalse);
    });

    test('ana sayfada alti kart var', () {
      // Kazanimlar, Katilim, Kurullar, Sinav, Rehberlik, Diger Evraklar
      final kod = oku(anaSayfa);
      final sayi = RegExp(r"'title': '").allMatches(kod).length;
      expect(sayi, greaterThanOrEqualTo(6));
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
