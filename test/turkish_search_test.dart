import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/utils/turkish_text.dart';

/// Turkce arama (Faz 3.2).
///
/// Arama kutulari `toLowerCase()` kullaniyordu. Ogretmen telefon
/// klavyesinde Turkce karakter yazmadan aradiginda ogrenci BULUNAMIYORDU:
/// "Isil" yazinca "Isil Demir" cikmiyor, "Gulsah" yazinca "Gulsah" cikmiyordu.
void main() {
  group('Aksansiz arama ogrenciyi bulur', () {
    test('KRITIK: "Isil" -> "Işıl Demir"', () {
      expect(trContains('Işıl Demir', 'Isil'), isTrue,
          reason: 'toLowerCase ile bulunamiyordu');
    });

    test('KRITIK: "Gulsah" -> "Gülşah Yılmaz"', () {
      expect(trContains('Gülşah Yılmaz', 'Gulsah'), isTrue);
    });

    test('KRITIK: "Cagri" -> "Çağrı Öztürk"', () {
      expect(trContains('Çağrı Öztürk', 'Cagri'), isTrue);
    });

    test('"Ozturk" -> "Çağrı Öztürk"', () {
      expect(trContains('Çağrı Öztürk', 'Ozturk'), isTrue);
    });

    test('"ibrahim" -> "İbrahim Kaya"', () {
      expect(trContains('İbrahim Kaya', 'ibrahim'), isTrue);
    });
  });

  group('Turkce yazan da bulur', () {
    test('"Işıl" -> "Işıl Demir"', () {
      expect(trContains('Işıl Demir', 'Işıl'), isTrue);
    });

    test('"İrem" -> "İrem Yılmaz"', () {
      expect(trContains('İrem Yılmaz', 'İrem'), isTrue);
    });

    test('buyuk-kucuk harf farketmez', () {
      expect(trContains('Işıl Demir', 'IŞIL'), isTrue);
      expect(trContains('Işıl Demir', 'ışıl'), isTrue);
    });
  });

  group('Yanlis eslesme olmamali', () {
    test('alakasiz arama bulmaz', () {
      expect(trContains('Işıl Demir', 'Mehmet'), isFalse);
    });

    test('KRITIK: farkli ogrenciler karismaz', () {
      expect(trContains('Ali Veli', 'Ayse'), isFalse);
      expect(trContains('Ayşe Yılmaz', 'Ali'), isFalse);
    });
  });

  group('Bos arama', () {
    test('bos arama her zaman eslesir (liste tam gorunur)', () {
      expect(trContains('Herhangi Biri', ''), isTrue);
      expect(trContains('Herhangi Biri', '   '), isTrue);
    });
  });

  group('trFold davranisi', () {
    test('Turkce harfler ASCII karsiligina iner', () {
      expect(trFold('İIıiŞşĞğÜüÖöÇç'), 'iiiissgguuoocc');
    });

    test('KRITIK: I ve i ayni sonuca iner', () {
      // Turkce tuzaginin ozu: 'I'.toLowerCase() == 'i' degil normalde
      expect(trFold('I'), trFold('i'));
      expect(trFold('İ'), trFold('ı'));
    });

    test('katlama yalnizca karsilastirma icin, gosterim bozulmaz', () {
      const ad = 'Işıl';
      expect(trFold(ad), 'isil');
      expect(ad, 'Işıl', reason: 'orijinal metin degismemeli');
    });
  });

  group('Bos alan tuzagi', () {
    test('KRITIK: veli adi bos, arama dolu -> ESLESMEZ', () {
      // trContains bos ARAMA icin true doner; bos ALAN icin donmemeli.
      // Donseydi veli adi girilmemis her ogrenci her aramada cikardi.
      expect(trContains('', 'Ayse'), isFalse);
    });

    test('veli adi dolu, arama bos -> eslesir', () {
      expect(trContains('Ayse Yilmaz', ''), isTrue);
    });
  });
}
