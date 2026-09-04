import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/utils/name_formatter.dart';

/// Ad-soyad yazim standardi: **Yusuf YILMAZ**.
///
/// Kullanici ne yazarsa o kaliyordu: "yusuf yilmaz", "YUSUF YILMAZ",
/// "Yusuf yilmaz". Ayni ogretmen profilde bir turlu, veli ekraninda
/// baska turlu gorunuyordu.
///
/// En kritik nokta TURKCE TUZAGI: `toUpperCase()` bozuk calisiyor.
///   'isik'.toUpperCase() -> 'ISIK'  ama dogrusu 'ISIK' degil 'İŞIK'
void main() {
  group('Turkce buyuk harf', () {
    test('KRITIK: i -> İ (nokta korunur)', () {
      expect(trUpper('i'), 'İ');
      expect(trUpper('işık'), 'İŞIK',
          reason: 'toUpperCase "IŞIK" verir — noktasi kaybolur');
    });

    test('KRITIK: ı -> I (nokta eklenmez)', () {
      expect(trUpper('ı'), 'I');
      expect(trUpper('ıshak'), 'ISHAK');
    });

    test('diger Turkce harfler', () {
      expect(trUpper('şğüöç'), 'ŞĞÜÖÇ');
      expect(trUpper('çiçek'), 'ÇİÇEK');
    });

    test('yaygin soyadlari dogru buyuyor', () {
      expect(trUpper('yılmaz'), 'YILMAZ');
      expect(trUpper('şahin'), 'ŞAHİN');
      expect(trUpper('gündoğdu'), 'GÜNDOĞDU');
      expect(trUpper('çelik'), 'ÇELİK');
    });
  });

  group('Turkce kucuk harf', () {
    test('KRITIK: I -> ı (noktasiz)', () {
      expect(trLower('I'), 'ı');
      expect(trLower('IŞIK'), 'ışık');
    });

    test('KRITIK: İ -> i (noktali)', () {
      expect(trLower('İ'), 'i');
      expect(trLower('İSTANBUL'), 'istanbul');
    });
  });

  group('Ad bicimlendirme', () {
    test('KRITIK: kucuk yazilan ad duzelir', () {
      expect(NameFormatter.formatFirstName('yusuf'), 'Yusuf');
    });

    test('KRITIK: buyuk yazilan ad duzelir', () {
      expect(NameFormatter.formatFirstName('YUSUF'), 'Yusuf');
    });

    test('cok adli isimler korunur', () {
      expect(NameFormatter.formatFirstName('ali rıza'), 'Ali Rıza');
      expect(NameFormatter.formatFirstName('MEHMET AKİF'), 'Mehmet Akif');
    });

    test('KRITIK: Turkce bas harf dogru', () {
      expect(NameFormatter.formatFirstName('irem'), 'İrem',
          reason: 'i -> İ olmali');
      expect(NameFormatter.formatFirstName('ışıl'), 'Işıl',
          reason: 'ı -> I olmali');
    });

    test('tireli adlar', () {
      expect(NameFormatter.formatFirstName('ayşe-nur'), 'Ayşe-Nur');
    });

    test('fazla bosluk temizlenir', () {
      expect(NameFormatter.formatFirstName('  yusuf   can  '), 'Yusuf Can');
    });
  });

  group('Soyad bicimlendirme', () {
    test('KRITIK: soyad TAMAMEN buyuk', () {
      expect(NameFormatter.formatLastName('yılmaz'), 'YILMAZ');
      expect(NameFormatter.formatLastName('Yılmaz'), 'YILMAZ');
      expect(NameFormatter.formatLastName('YILMAZ'), 'YILMAZ');
    });

    test('KRITIK: Turkce soyad bozulmuyor', () {
      expect(NameFormatter.formatLastName('işık'), 'İŞIK');
      expect(NameFormatter.formatLastName('çiçek'), 'ÇİÇEK');
    });

    test('cift soyad', () {
      expect(NameFormatter.formatLastName('kaya demir'), 'KAYA DEMİR');
    });
  });

  group('Tam ad: Yusuf YILMAZ', () {
    test('KRITIK: standart bicim', () {
      expect(
        NameFormatter.format(firstName: 'yusuf', lastName: 'yılmaz'),
        'Yusuf YILMAZ',
      );
    });

    test('KRITIK: her turlu giris ayni sonuca gelir', () {
      const beklenen = 'Yusuf YILMAZ';
      expect(NameFormatter.format(firstName: 'YUSUF', lastName: 'YILMAZ'),
          beklenen);
      expect(NameFormatter.format(firstName: 'Yusuf', lastName: 'yılmaz'),
          beklenen);
      expect(NameFormatter.format(firstName: '  yusuf ', lastName: ' Yılmaz'),
          beklenen);
    });

    test('soyad bossa yalniz ad doner', () {
      expect(NameFormatter.format(firstName: 'yusuf', lastName: ''), 'Yusuf');
    });

    test('ad bossa yalniz soyad doner', () {
      expect(NameFormatter.format(firstName: '', lastName: 'yılmaz'), 'YILMAZ');
    });

    test('ikisi de bossa bos doner', () {
      expect(NameFormatter.format(firstName: '  ', lastName: ''), '');
    });
  });

  group('Tek parca ad (veli, ogretmen)', () {
    test('KRITIK: son kelime soyad sayilir', () {
      expect(NameFormatter.formatFull('yusuf yılmaz'), 'Yusuf YILMAZ');
    });

    test('cok adli: yalnizca SON kelime soyad', () {
      expect(NameFormatter.formatFull('yusuf can yılmaz'), 'Yusuf Can YILMAZ');
    });

    test('KRITIK: tek kelime soyad sayilmaz', () {
      // "Yusuf" yazan biri "YUSUF" gormemeli — bagirmis gibi olur.
      expect(NameFormatter.formatFull('yusuf'), 'Yusuf');
    });

    test('bos giris bos doner', () {
      expect(NameFormatter.formatFull('   '), '');
    });
  });

  group('Kisa gosterim: Yusuf Y.', () {
    test('KRITIK: dar alanlarda kisalir', () {
      expect(
        NameFormatter.formatShort(firstName: 'yusuf', lastName: 'yılmaz'),
        'Yusuf Y.',
      );
    });

    test('Turkce bas harf dogru', () {
      expect(
        NameFormatter.formatShort(firstName: 'ali', lastName: 'işık'),
        'Ali İ.',
        reason: 'i -> İ olmali, I degil',
      );
    });

    test('soyad yoksa yalniz ad', () {
      expect(
        NameFormatter.formatShort(firstName: 'yusuf', lastName: ''),
        'Yusuf',
      );
    });
  });

  group('Bas harfler (avatar)', () {
    test('iki harf doner', () {
      expect(
        NameFormatter.initials(firstName: 'yusuf', lastName: 'yılmaz'),
        'YY',
      );
    });

    test('KRITIK: Turkce bas harf', () {
      expect(
        NameFormatter.initials(firstName: 'irem', lastName: 'ışık'),
        'İI',
        reason: 'i -> İ, ı -> I',
      );
    });

    test('bos girise soru isareti', () {
      expect(NameFormatter.initials(firstName: '', lastName: ''), '?');
    });
  });

  group('Bicimlendirme kararli (idempotent)', () {
    test('KRITIK: iki kez uygulamak sonucu degistirmez', () {
      const ad = 'yusuf';
      const soyad = 'yılmaz';

      final bir = NameFormatter.format(firstName: ad, lastName: soyad);
      final iki = NameFormatter.formatFull(bir);

      expect(iki, bir,
          reason: 'kayitli veri yeniden bicimlendirilince bozulmamali');
    });
  });
}
