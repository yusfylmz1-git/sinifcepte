import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PDF sessiz donmasi (ANR).
///
/// ## Gercek olay
/// Ogretmen "PDF'e dokundum, yanit vermedi" dedi. Cihaz logu sebebi
/// kesinlestirdi:
///
///     ANR in com.sinifcepte.sinifcepte
///     Reason: Input dispatching timed out ...
///     Waited 5001ms for MotionEvent(action=DOWN)
///
/// Dokunus BILE islenemiyordu: ana is parcacigi PDF uretiminde
/// kilitlenmisti.
///
/// ## Iki ayri kusur vardi
///
/// 1. **Kurulum**: telefondaki yapi F5 (debugger bagli) ile
///    kurulmustu. `pdf` paketi belgeyi ayri izolatta kaydediyor; VM
///    servisi bagliyken o izolat duraklatilmis basliyor ve
///    devam ettirilmiyor. Bilinen tuzak; `tool/kur_test.sh` bunu
///    anlatiyor. Kullanici etkilenmez ama gelistirici yaniltir.
///
/// 2. **Kod**: kumulatif rapor modalindaki bes PDF yolu
///    `PdfPreviewScreen`i ATLIYORDU. O ekranin 45 sn zaman asimi,
///    gorunur hata ekrani ve tani logu var; dogrudan
///    `Printing.sharePdf` cagrisi hicbirini kullanmiyordu. `catch`
///    yalnizca `debugPrint` yapiyordu ve release'de o cikti hicbir
///    yere gitmiyor. Yani takilma bir yana, HATA BILE gorunmuyordu.
///
/// Bu dosya ikinci kusuru kilitler.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const modal =
      'lib/features/attendance/presentation/widgets/participation_cumulative_reports_modal.dart';
  const onizleme = 'lib/shared/screens/pdf_preview_screen.dart';

  group('Zaman asimi', () {
    test('KRITIK: PDF uretimi sinirsiz beklemiyor', () {
      final s = read(modal);
      expect(s.contains('_pdfZamanAsimi'), isTrue,
          reason: 'Sinir olmadan save() sessizce bekleyip ANR uretiyordu');
      expect(s.contains('TimeoutException'), isTrue);
    });

    test('Sinir onizleme ekraniyla ayni ruhta', () {
      // PdfPreviewScreen 45 sn kullaniyor; iki yol farkli davranmasin.
      expect(read(modal).contains('Duration(seconds: 45)'), isTrue);
      expect(read(onizleme).contains('Duration(seconds: 45)'), isTrue);
    });

    test('Zaman asiminda kullaniciya ne yapacagi soyleniyor', () {
      expect(read(modal).contains('belge çok uzun sürdü'), isTrue);
    });
  });

  group('Sessiz basarisizlik bitti', () {
    test('KRITIK: hata KULLANICIYA gosteriliyor', () {
      // debugPrint release'de gorunmez: ogretmen dokunuyor, hicbir
      // sey olmuyor, sebebini kimse goremiyordu.
      final s = read(modal);
      expect(s.contains('void _hataGoster('), isTrue);
      expect(s.contains('ScaffoldMessenger.of(context).showSnackBar'), isTrue);
    });

    test('KRITIK: veri yoksa sebebi soyleniyor', () {
      // Once sessizce `return` ediliyordu.
      final s = read(modal);
      expect(s.contains('_veriYokUyarisi'), isTrue);
      expect(s.contains('değerlendirme kaydı bulunamadı'), isTrue);
    });

    test('KRITIK: sessiz `data == null` donusu kalmadi', () {
      expect(read(modal).contains('if (data == null) return;'), isFalse,
          reason: 'Her cikis yolu kullaniciya bir sey soylemeli');
    });

    test('Hata rengi tehlike rengi', () {
      expect(read(modal).contains('backgroundColor: AppColors.danger'), isTrue);
    });
  });

  group('Tek yol, bes cagri', () {
    test('KRITIK: tum PDF yollari ortak yardimciyi kullaniyor', () {
      // Bes metot ayni kalibi kopyalamisti; biri duzeltilip digerleri
      // unutulabilirdi.
      final s = read(modal);
      // 5 cagri + yardimcinin kendi tanimi.
      expect('_pdfUret('.allMatches(s).length, 6,
          reason: 'Veli toplantisi, 1./2. donem, yil sonu, bireysel kart');
    });

    test('KRITIK: korumasiz Printing cagrisi kalmadi', () {
      final s = read(modal);
      final satirlar = s
          .split('\n')
          .where((l) =>
              l.contains('Printing.sharePdf') ||
              l.contains('Printing.layoutPdf'))
          .toList();

      // Yalnizca yardimcinin icindeki iki cagri kalmali.
      expect(satirlar.length, 2,
          reason: 'Her PDF yolu _pdfUret uzerinden gecmeli');
      for (final l in satirlar) {
        expect(l.contains('dosyaAdi'), isTrue,
            reason: 'Kalan cagrilar yardimciya ait olmali: $l');
      }
    });

    test('Yardimci paylas/yazdir ayrimini koruyor', () {
      final s = read(modal);
      expect(s.contains('required bool isShare'), isTrue);
      expect(s.contains('isShare: isShare'), isTrue);
    });
  });

  group('Onizleme ekrani korumalari duruyor', () {
    test('45 sn sinir ve gorunur hata hala var', () {
      final s = read(onizleme);
      expect(s.contains('_zamanAsimi'), isTrue);
      expect(s.contains('_hataDurumu'), isTrue);
    });

    test('Tek uretim onbellegi duruyor', () {
      // PdfPreview build geri cagrisini birden cok kez tetikliyor;
      // her seferinde bastan uretmek eszamanli iki uretim yaratiyordu.
      expect(read(onizleme).contains('_uretim ??='), isTrue);
    });
  });

  group('Kurulum tuzagi belgeli', () {
    test('KRITIK: kur_test.sh F5 tuzagini anlatiyor', () {
      // Telefondaki yapi F5 ile kurulmustu; PDF'in takilmasinin
      // birinci sebebi buydu ve kod degisikligiyle cozulmez.
      final s = read('tool/kur_test.sh');
      expect(s.contains('flutter run / F5'), isTrue);
      expect(s.contains('TAKILIYOR'), isTrue);
    });

    test('Betik hem debug hem release kurabiliyor', () {
      final s = read('tool/kur_test.sh');
      expect(s.contains('--release'), isTrue);
    });
  });
}
