/// Tahta yetkisi bulut deposu — yol şeması ve önden doğrulama.
///
/// ## Neden Firestore'a bağlanmıyor
///
/// `FirestoreClient` gerçek bağlantı ister. Kuralların gerçekten
/// koruduğu `test_rules/rules.test.mjs` içinde emülatöre karşı
/// kanıtlanıyor.
///
/// Buradaki asıl değer: **yol şeması kuralla birebir aynı olmalı.**
/// Kural `school_boards/{schoolId}/teachers/{teacherUid}` bekliyor;
/// kod farklı bir yol üretirse yazma sessizce reddedilir ve sebebi
/// görünmez.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/tahta_yetki_deposu.dart';

void main() {
  const okulId = 'meb_775214';
  const uid = 'KplpM8ibNdhVJENzWz8tvJ0vsLR2';
  const secret = '45O6OJ5SJJTVLOD552RNFLCPONZ2U6EO';

  group('Yol şeması — kuralla uyum', () {
    test('KRİTİK: yetki kaydı yolu', () {
      expect(
        TahtaYetkiDeposu.yetkiPath(okulId, uid),
        'school_boards/meb_775214/teachers/$uid',
      );
    });

    test('KRİTİK: doküman kimliği öğretmenin uid\'si', () {
      // Kural `request.auth.uid == teacherUid` karşılaştırması
      // yapıyor. Kimlik başka bir şey olsaydı öğretmen kendi
      // kaydını hiç oluşturamazdı.
      final yol = TahtaYetkiDeposu.yetkiPath(okulId, uid);
      expect(yol.split('/').last, uid);
    });

    test('okul kimliği yolda — aynı öğretmen iki okulda olabilir', () {
      // İkinci okulda görevlendirme yaygın. Okul kimliği yolda
      // olduğu için iki kayıt çakışmıyor.
      final a = TahtaYetkiDeposu.yetkiPath('meb_775214', uid);
      final b = TahtaYetkiDeposu.yetkiPath('meb_123456', uid);
      expect(a, isNot(b));
    });
  });

  group('Önden doğrulama — sunucunun reddedeceğini denemeyiz', () {
    late TahtaYetkiDeposu depo;

    setUp(() => depo = TahtaYetkiDeposu());

    test('KRİTİK: boş okul kimliğiyle istek gönderilmez', () async {
      final sonuc = await depo.istekGonder(
        schoolId: '',
        teacherUid: uid,
        ad: 'Yusuf YILMAZ',
        kod: 'YYILMAZ',
        totpSecret: secret,
      );
      expect(sonuc.basarili, isFalse);
      expect(sonuc.hata, isNotNull);
    });

    test('KRİTİK: boş kullanıcı kimliğiyle istek gönderilmez', () async {
      final sonuc = await depo.istekGonder(
        schoolId: okulId,
        teacherUid: '',
        ad: 'Yusuf YILMAZ',
        kod: 'YYILMAZ',
        totpSecret: secret,
      );
      expect(sonuc.basarili, isFalse);
    });

    test('boş adla istek gönderilmez', () async {
      final sonuc = await depo.istekGonder(
        schoolId: okulId,
        teacherUid: uid,
        ad: '   ',
        kod: 'YYILMAZ',
        totpSecret: secret,
      );
      expect(sonuc.basarili, isFalse);
      expect(sonuc.hata, contains('ad'));
    });

    test('KRİTİK: kısa secret reddedilir', () async {
      // Kural da 16 karakter alt sınırı koyuyor. Önden kesmek,
      // kullanıcıya boş bir reddedilme yaşatmamak için.
      final sonuc = await depo.istekGonder(
        schoolId: okulId,
        teacherUid: uid,
        ad: 'Yusuf YILMAZ',
        kod: 'YYILMAZ',
        totpSecret: 'KISA',
      );
      expect(sonuc.basarili, isFalse);
      expect(sonuc.hata, contains('geçersiz'));
    });

    test('boş kimliklerle onay/ret/çıkarma yapılmaz', () async {
      expect(
        await depo.onayla(schoolId: '', teacherUid: uid, onaylayanUid: 'x'),
        isFalse,
      );
      expect(
        await depo.reddet(schoolId: okulId, teacherUid: '', onaylayanUid: 'x'),
        isFalse,
      );
      expect(await depo.cikar(schoolId: '', teacherUid: uid), isFalse);
    });

    test('boş okul kimliğiyle okuma boş liste döner', () async {
      expect(await depo.okulunKayitlari(schoolId: ''), isEmpty);
      expect(
        await depo.kendiKaydiniOku(schoolId: '', teacherUid: uid),
        isNull,
      );
    });
  });

  group('Durum çözümleme', () {
    test('bilinen değerler', () {
      expect(YetkiDurumu.cozumle('onayli'), YetkiDurumu.onayli);
      expect(YetkiDurumu.cozumle('reddedildi'), YetkiDurumu.reddedildi);
      expect(YetkiDurumu.cozumle('bekliyor'), YetkiDurumu.bekliyor);
    });

    test('KRİTİK: tanınmayan değer yetki VERMEZ', () {
      // Bozuk veya gelecekte eklenmiş bir değer yüzünden kimse
      // kendiliğinden yetkilenmemeli. Güvenli taraf `bekliyor`.
      expect(YetkiDurumu.cozumle('acik'), YetkiDurumu.bekliyor);
      expect(YetkiDurumu.cozumle(''), YetkiDurumu.bekliyor);
      expect(YetkiDurumu.cozumle(null), YetkiDurumu.bekliyor);
      expect(YetkiDurumu.cozumle('ONAYLI'), YetkiDurumu.bekliyor);
    });

    test('depo değeri kural ile aynı yazımda', () {
      // Kural `durum == 'bekliyor'` karşılaştırması yapıyor;
      // yazım farkı isteği sessizce reddettirir.
      expect(YetkiDurumu.bekliyor.depoDegeri, 'bekliyor');
      expect(YetkiDurumu.onayli.depoDegeri, 'onayli');
      expect(YetkiDurumu.reddedildi.depoDegeri, 'reddedildi');
    });
  });

  group('Kayıt çözümleme', () {
    test('tam haritadan okunuyor', () {
      final k = TahtaYetkiKaydi.haritadan({
        'teacherUid': uid,
        'ad': 'Yusuf YILMAZ',
        'kod': 'YYILMAZ',
        'totpSecret': secret,
        'durum': 'onayli',
        'istekZamani': '2026-09-18T14:00:00+03:00',
        'onayZamani': '2026-09-18T14:05:00+03:00',
        'onaylayanUid': 'admin1',
      });

      expect(k.teacherUid, uid);
      expect(k.onayli, isTrue);
      expect(k.totpSecret, secret);
    });

    test('eksik alanlar çökmez', () {
      // Eski sürümden kalan veya bozuk kayıt ekranı çökertmemeli.
      final k = TahtaYetkiKaydi.haritadan({});
      expect(k.teacherUid, isEmpty);
      expect(k.durum, YetkiDurumu.bekliyor);
      expect(k.onayli, isFalse);
    });

    test('KRİTİK: okul_config biçimine dönüşüyor', () {
      // Tahta tarafı bu üç alanı okuyor; biri boş kalırsa öğretmen
      // tahtayı açamaz ve sebebi sahada anlaşılmaz.
      final k = TahtaYetkiKaydi.haritadan({
        'teacherUid': uid,
        'ad': 'Yusuf YILMAZ',
        'kod': 'YYILMAZ',
        'totpSecret': secret,
        'durum': 'onayli',
      });

      final o = k.panoOgretmeni();
      expect(o.kod, 'YYILMAZ');
      expect(o.ad, 'Yusuf YILMAZ');
      expect(o.totpSecret, secret);
    });
  });
}
