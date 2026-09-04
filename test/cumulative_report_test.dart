import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kumulatif katilim raporu.
///
/// Bu ekran 1.613 satirdi ve HIC gercek veri gormeden yazilmisti;
/// cihazda `participation_records` sifir kayitla duruyordu. Sonuc: uc
/// somut hata.
///
/// Kullanici bir hafta gercek derste kullandiktan sonra dogruladi:
/// dokunma hizi iyi, gri nokta ise yariyor, kura sessiz ogrenciyi one
/// aliyor. Artik rapor da bu veriyi gostermeli.
void main() {
  String depo() => File(
        'lib/features/attendance/data/repositories/'
        'classroom_participation_repository.dart',
      ).readAsStringSync();

  String ekran() => File(
        'lib/features/attendance/presentation/widgets/'
        'participation_cumulative_reports_modal.dart',
      ).readAsStringSync();

  group('HATA 1: veri yoklugu "%100" gosteriliyordu', () {
    test('KRITIK: depo artik 100.0 yedegi kullanmiyor', () {
      // `sSessions > 0 ? ... : 100.0` yaziliyordu: hic
      // degerlendirilmemis ogrenci raporda "Odev: %100, Yildiz: 3.0"
      // gorunuyordu. Ogretmen bu raporu veli toplantisinda acsa, hic
      // takip etmedigi ogrenci icin "her sey harika" diyecekti.
      final kod = depo();
      expect(kod.contains('* 100).clamp(0.0, 100.0) : 100.0'), isFalse,
          reason: 'veri yoklugu mukemmellik olarak sunulmamali');
      expect(kod.contains('(stars / sSessions).clamp(0.0, 3.0) : 3.0'), isFalse);
    });

    test('KRITIK: arayuzde de 100.0 yedegi yok', () {
      final kod = ekran();
      expect(kod.contains('?? 100.0'), isFalse,
          reason: '9 yerde "veri yoksa %100" yaziyordu');
      expect(kod.contains("(student['averageStars'] as num?)?.toDouble() ?? 3.0"),
          isFalse);
    });
  });

  group('HATA 2: isaretlenmemis kayit "yapti" sayiliyordu', () {
    test('KRITIK: varsayilan artik "bilinmiyor"', () {
      // Model tarafinda `unknown` yapilmisti ama rapor sorgusu eski
      // varsayilani kullanmaya devam ediyordu: dunku duzeltme burada
      // delinmisti.
      final kod = depo();
      expect(kod.contains("r['homework_status'] as String? ?? 'yapti'"), isFalse);
      expect(kod.contains("r['materials_status'] as String? ?? 'tam'"), isFalse);
      expect(kod, contains("?? 'bilinmiyor'"));
    });

    test('KRITIK: oranin paydasi ISARETLENEN ders sayisi', () {
      // Ogretmen 20 dersin 3'unde isaretlediyse oran %15 cikiyordu;
      // oysa isaretlenen 3 dersin hepsinde odev yapilmis olabilir.
      final kod = depo();
      expect(kod, contains('hwMarked'));
      expect(kod, contains('matMarked'));
      expect(kod, contains('homeworkMarkedLessons'),
          reason: 'oranin kac derse dayandigi da raporlanmali');
    });
  });

  group('HATA 3: soz hakki raporda hic yoktu', () {
    test('KRITIK: depo soz hakkini sayiyor', () {
      final kod = depo();
      expect(kod, contains("r['speaking_turns']"));
      expect(kod, contains("'speakingTurns': speakingTurns"));
      expect(kod, contains("'isSilent'"));
    });

    test('KRITIK: sinif geneli ozet uretiliyor', () {
      final kod = depo();
      expect(kod, contains('classTotalSpeakingTurns'));
      expect(kod, contains('silentStudentCount'));
    });

    test('KRITIK: ogrenci kartinda soz hakki gorunuyor', () {
      final kod = ekran();
      expect(kod, contains("studentMap['speakingTurns']"));
      expect(kod, contains('hiç konuşmadı'),
          reason: 'sessiz ogrenci acikca belirtilmeli');
    });

    test('KRITIK: sinif ozeti karti eklendi', () {
      final kod = ekran();
      expect(kod, contains('_buildClassSummary'));
      expect(kod, contains('söz hakkı verildi'));
    });

    test('veri yokken dogru mesaj gosteriliyor', () {
      final kod = ekran();
      expect(kod, contains('henüz değerlendirme kaydı yok'),
          reason: 'bos rapor "%100 basarili" gibi gorunmemeli');
    });
  });
}
