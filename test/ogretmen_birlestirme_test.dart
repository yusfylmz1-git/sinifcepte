/// `okul_config` öğretmen listesinin iki kaynaktan birleştirilmesi.
///
/// ## Neden bu test kritik
///
/// Bu fonksiyon **yetki kararı veriyor**: hangi öğretmenin tahtayı
/// açabileceğini belirleyen dosyayı o üretiyor. Bekleyen bir isteğin
/// sızması, onay mekanizmasını tamamen anlamsız kılar.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/tahta_yetki_deposu.dart';
import 'package:sinifcepte/features/board_config/models/okul_config_model.dart';
import 'package:sinifcepte/features/board_config/utils/ogretmen_birlestirme.dart';

void main() {
  const secretA = 'AAAAOJ5SJJTVLOD552RNFLCPONZ2U6EO';
  const secretB = 'BBBBOJ5SJJTVLOD552RNFLCPONZ2U6EO';

  TahtaYetkiKaydi yetki({
    required String uid,
    required String kod,
    String ad = 'Bulut Öğretmen',
    String secret = secretB,
    YetkiDurumu durum = YetkiDurumu.onayli,
  }) =>
      TahtaYetkiKaydi(
        teacherUid: uid,
        ad: ad,
        kod: kod,
        totpSecret: secret,
        durum: durum,
      );

  group('Temel birleştirme', () {
    test('iki kaynak birleşiyor', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: 'AYILMAZ', ad: 'A. Yılmaz', totpSecret: secretA),
        ],
        bulut: [yetki(uid: 'u2', kod: 'BDEMIR')],
      );

      expect(sonuc, hasLength(2));
      expect(sonuc.map((o) => o.kod), containsAll(['AYILMAZ', 'BDEMIR']));
    });

    test('iki kaynak da boşsa boş liste', () {
      expect(
        ogretmenleriBirlestir(cihaz: const [], bulut: const []),
        isEmpty,
      );
    });

    test('yalnızca cihaz varsa o dönüyor', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: 'AYILMAZ', ad: 'A. Yılmaz', totpSecret: secretA),
        ],
        bulut: const [],
      );
      expect(sonuc, hasLength(1));
    });

    test('yalnızca bulut varsa o dönüyor', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [yetki(uid: 'u1', kod: 'BDEMIR')],
      );
      expect(sonuc, hasLength(1));
      expect(sonuc.first.totpSecret, secretB);
    });
  });

  group('Yetki süzgeci — onay mekanizmasının kendisi', () {
    test('KRİTİK: BEKLEYEN istek dosyaya GİRMEZ', () {
      // Girerse onay mekanizması tamamen anlamsız olur: öğretmen
      // istek gönderir ve onay beklemeden tahtayı açar.
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [
          yetki(uid: 'u1', kod: 'BEKLEYEN', durum: YetkiDurumu.bekliyor),
        ],
      );
      expect(sonuc, isEmpty);
    });

    test('KRİTİK: REDDEDİLEN istek dosyaya GİRMEZ', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [
          yetki(uid: 'u1', kod: 'RED', durum: YetkiDurumu.reddedildi),
        ],
      );
      expect(sonuc, isEmpty);
    });

    test('karışık listeden yalnızca onaylılar geçiyor', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [
          yetki(uid: 'u1', kod: 'ONAYLI1'),
          yetki(uid: 'u2', kod: 'BEKLER', durum: YetkiDurumu.bekliyor),
          yetki(uid: 'u3', kod: 'ONAYLI2'),
          yetki(uid: 'u4', kod: 'REDDI', durum: YetkiDurumu.reddedildi),
        ],
      );

      expect(sonuc, hasLength(2));
      expect(sonuc.map((o) => o.kod), containsAll(['ONAYLI1', 'ONAYLI2']));
    });

    test('KRİTİK: secret\'ı boş onaylı kayıt GİRMEZ', () {
      // Secret boşsa öğretmen kod üretemez; dosyaya yazmak tahtada
      // "tanımlı ama açamıyor" durumu üretir ve sebebi anlaşılmaz.
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [yetki(uid: 'u1', kod: 'BOSSECRET', secret: '')],
      );
      expect(sonuc, isEmpty);
    });

    test('kodu boş kayıt girmez', () {
      // Tahtada elle girilecek kod yoksa öğretmen kendini
      // tanıtamaz.
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [yetki(uid: 'u1', kod: '   ')],
      );
      expect(sonuc, isEmpty);
    });

    test('cihaz tarafında kodu boş kayıt girmez', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: '', ad: 'Kodsuz', totpSecret: secretA),
        ],
        bulut: const [],
      );
      expect(sonuc, isEmpty);
    });
  });

  group('Çakışma — cihaz kazanıyor', () {
    test('KRİTİK: aynı kod iki kez GİRMİYOR', () {
      // Aynı kod iki kez girse tahta hangisini kullanacağını
      // bilemez; `ogretmen_bul` ilk eşleşmeyi döndürüyor ve
      // öğretmenin telefonundaki secret farklı olabilir.
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: 'AYILMAZ', ad: 'A. Yılmaz', totpSecret: secretA),
        ],
        bulut: [yetki(uid: 'u1', kod: 'AYILMAZ')],
      );

      expect(sonuc, hasLength(1));
    });

    test('KRİTİK: çakışmada CİHAZDAKİ secret korunuyor', () {
      // İdareci o kaydı bilerek girmiş ve secret'ını öğretmene QR ile
      // vermiş olabilir. Bulut kaydı üzerine yazarsa öğretmenin
      // telefonundaki secret geçersiz olur ve sebebi anlaşılmaz.
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: 'AYILMAZ', ad: 'Elle Eklenen',
              totpSecret: secretA),
        ],
        bulut: [yetki(uid: 'u1', kod: 'AYILMAZ', ad: 'Buluttan')],
      );

      expect(sonuc.first.totpSecret, secretA);
      expect(sonuc.first.ad, 'Elle Eklenen');
    });

    test('KRİTİK: kod karşılaştırması büyük/küçük harf duyarsız', () {
      // Tahtada elle giriliyor; `ogr001` ile `OGR001` aynı kişi.
      // Duyarlı olsaydı aynı öğretmen iki kez dosyaya girerdi.
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: 'ogr001', ad: 'Küçük', totpSecret: secretA),
        ],
        bulut: [yetki(uid: 'u1', kod: 'OGR001')],
      );

      expect(sonuc, hasLength(1));
      expect(sonuc.first.ad, 'Küçük');
    });

    test('kod çevresindeki boşluk çakışmayı bozmuyor', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: ' OGR001 ', ad: 'Boşluklu',
              totpSecret: secretA),
        ],
        bulut: [yetki(uid: 'u1', kod: 'OGR001')],
      );
      expect(sonuc, hasLength(1));
    });

    test('cihazda aynı kod iki kez varsa tek kez giriyor', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [
          PanoOgretmeni(kod: 'OGR001', ad: 'Bir', totpSecret: secretA),
          PanoOgretmeni(kod: 'OGR001', ad: 'İki', totpSecret: secretB),
        ],
        bulut: const [],
      );
      expect(sonuc, hasLength(1));
      expect(sonuc.first.ad, 'Bir');
    });

    test('bulutta aynı kod iki kez varsa tek kez giriyor', () {
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [
          yetki(uid: 'u1', kod: 'OGR001', ad: 'Bir'),
          yetki(uid: 'u2', kod: 'OGR001', ad: 'İki'),
        ],
      );
      expect(sonuc, hasLength(1));
      expect(sonuc.first.ad, 'Bir');
    });
  });

  group('Tahta tarafının beklediği alanlar', () {
    test('KRİTİK: üç alan da dolu geçiyor', () {
      // Tahta `kod`, `ad` ve `totpSecret` okuyor. Biri boş kalırsa
      // öğretmen tahtayı açamaz ve sebebi sahada anlaşılmaz.
      final sonuc = ogretmenleriBirlestir(
        cihaz: const [],
        bulut: [yetki(uid: 'u1', kod: 'BDEMIR', ad: 'B. Demir')],
      );

      final o = sonuc.first;
      expect(o.kod, 'BDEMIR');
      expect(o.ad, 'B. Demir');
      expect(o.totpSecret, secretB);
    });
  });
}
