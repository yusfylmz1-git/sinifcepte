import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/exam_operations/data/services/score_input.dart';

/// Not girisi denetimi (Faz 2.3).
///
/// Eski davranis `int.tryParse` + `clamp(0, 100)` idi. Bu ikili uc ayri
/// durumu tek sonuca indirgiyordu ve ikisi SESSIZCE yanlis sonuc uretiyordu:
///   * "abc" -> null -> mevcut not siliniyordu
///   * "955" -> 100 -> ogretmen 95 yazdigini saniyordu
void main() {
  group('Gecerli notlar', () {
    test('0 ve 100 sinir degerleri kabul edilir', () {
      expect(parseScoreInput('0').score, 0);
      expect(parseScoreInput('100').score, 100);
      expect(parseScoreInput('0').isValid, isTrue);
      expect(parseScoreInput('100').isValid, isTrue);
    });

    test('aradaki degerler kabul edilir', () {
      expect(parseScoreInput('85').score, 85);
      expect(parseScoreInput('47').score, 47);
    });

    test('bastaki ve sondaki bosluk yok sayilir', () {
      expect(parseScoreInput('  72  ').score, 72);
    });
  });

  group('Bilincli silme', () {
    test('bos alan notu siler, hata vermez', () {
      final r = parseScoreInput('');
      expect(r.status, ScoreParseStatus.cleared);
      expect(r.errorMessage, isNull);
      expect(r.canSave, isTrue);
      expect(r.score, isNull);
    });

    test('yalnizca bosluk da silme sayilir', () {
      expect(parseScoreInput('   ').status, ScoreParseStatus.cleared);
    });
  });

  group('Aralik disi giris kirpilmaz, reddedilir', () {
    test('100 ustu deger kaydedilmez', () {
      final r = parseScoreInput('955');
      expect(r.status, ScoreParseStatus.outOfRange);
      expect(r.canSave, isFalse, reason: 'sessizce 100 olarak kaydedilmemeli');
      expect(r.score, isNull);
      expect(r.rawValue, 955, reason: 'ogretmen ne yazdigini gormeli');
      expect(r.errorMessage, contains('955'));
    });

    test('101 de reddedilir', () {
      expect(parseScoreInput('101').status, ScoreParseStatus.outOfRange);
    });

    test('negatif deger kaydedilmez', () {
      final r = parseScoreInput('-50');
      expect(r.status, ScoreParseStatus.outOfRange);
      expect(r.canSave, isFalse, reason: 'sessizce 0 olarak kaydedilmemeli');
      expect(r.rawValue, -50);
    });
  });

  group('Sayi olmayan giris notu SILMEZ', () {
    test('harf girisi reddedilir, silme sayilmaz', () {
      final r = parseScoreInput('abc');
      expect(r.status, ScoreParseStatus.notANumber);
      expect(r.canSave, isFalse,
          reason: 'eski kod bunu null yapip mevcut notu siliyordu');
      expect(r.isCleared, isFalse);
      expect(r.errorMessage, isNotNull);
    });

    test('yarim sayi reddedilir', () {
      expect(parseScoreInput('9a').status, ScoreParseStatus.notANumber);
    });

    test('ondalik ayirici reddedilir', () {
      expect(parseScoreInput('85,5').status, ScoreParseStatus.notANumber);
      expect(parseScoreInput('85.5').status, ScoreParseStatus.notANumber);
    });

    test('hata mesaji dogru dugmeye yonlendirir', () {
      expect(parseScoreInput('abc').errorMessage, contains('Notu Sil'));
    });
  });
}
