import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/data/services/communication_ids.dart';
import 'package:sinifcepte/features/parent_portal/data/services/phone_formatter.dart';

/// Veli iletisim testleri.
///
/// Iki hata sinifi kapsanir:
///  1) Bulut dokumani kimlikleri yalnizca zaman damgasiydi; ayni
///     milisaniyede yazan iki kullanici birbirinin kaydini siliyordu
///     (setDoc merge:false).
///  2) WhatsApp numara bicimlendirmesi bazi gecerli girdileri bozuyordu.
void main() {
  group('Bulut dokuman kimlikleri', () {
    test('KRITIK: ayni milisaniyede uretilen kimlikler carpismaz', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final a = CommunicationIds.message(authorUid: 'uid_ayse', now: fixed);
      final b = CommunicationIds.message(authorUid: 'uid_ayse', now: fixed);

      expect(a, isNot(b),
          reason: 'Ayni milisaniyede iki mesaj ayni kimligi aldi; '
              'merge:false ile ilki silinir');
    });

    test('KRITIK: farkli veliler ayni anda bildirim gonderebilir', () {
      // Eskiden kimlik 'rep_<ms>' idi: yazar bilgisi yoktu, iki veli
      // ayni milisaniyede yazinca biri digerinin kaydinin uzerine biniyordu.
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final ayse =
          CommunicationIds.statusReport(authorUid: 'uid_ayse', now: fixed);
      final mehmet =
          CommunicationIds.statusReport(authorUid: 'uid_mehmet', now: fixed);

      expect(ayse, isNot(mehmet),
          reason: 'Iki farkli velinin bildirimi ayni kimlige dustu');
    });

    test('KRITIK: farkli veliler ayni anda randevu isteyebilir', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final a = CommunicationIds.appointment(authorUid: 'uid_a', now: fixed);
      final b = CommunicationIds.appointment(authorUid: 'uid_b', now: fixed);

      expect(a, isNot(b));
    });

    test('KRITIK: farkli ogretmenler ayni anda duyuru yayinlayabilir', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final a =
          CommunicationIds.announcement(authorUid: 'uid_ogretmen1', now: fixed);
      final b =
          CommunicationIds.announcement(authorUid: 'uid_ogretmen2', now: fixed);

      expect(a, isNot(b));
    });

    test('Kimlik Firestore dokuman adi olarak gecerlidir', () {
      // Firestore: '/' yasak, '.' ve '..' tek basina yasak, en fazla 1500 bayt.
      final id = CommunicationIds.message(
        authorUid: 'google:abc/def.ghi',
        now: DateTime.now(),
      );

      expect(id.contains('/'), isFalse, reason: 'Kimlikte / var: $id');
      expect(id.length, lessThan(200));
      expect(id, isNot('.'));
      expect(id, isNot('..'));
    });

    test('Kimlik yazarina gore onek tasir', () {
      final id = CommunicationIds.message(
        authorUid: 'uid_ayse',
        now: DateTime.now(),
      );
      expect(id.startsWith('msg_'), isTrue, reason: id);
    });
  });

  group('WhatsApp numara bicimlendirme', () {
    test('Yerel 0 ile baslayan numara', () {
      expect(PhoneFormatter.toWhatsApp('0532 123 45 67'), '905321234567');
    });

    test('Ulke kodlu + bicimi', () {
      expect(PhoneFormatter.toWhatsApp('+90 532 123 45 67'), '905321234567');
    });

    test('Onsuz 10 haneli numara', () {
      expect(PhoneFormatter.toWhatsApp('532 123 45 67'), '905321234567');
    });

    test('Zaten 90 onekli numara iki kez oneklenmez', () {
      expect(PhoneFormatter.toWhatsApp('905321234567'), '905321234567');
    });

    test('KRITIK: 00 uluslararasi onek dogru cevrilir', () {
      // '0090...' girdisi '900905321234567' oluyordu: WhatsApp acilmiyordu.
      expect(PhoneFormatter.toWhatsApp('0090 532 123 45 67'), '905321234567');
    });

    test('Parantezli ve tireli yazim temizlenir', () {
      expect(PhoneFormatter.toWhatsApp('(0532) 123-45-67'), '905321234567');
    });

    test('Gecersiz numaralar reddedilir', () {
      expect(PhoneFormatter.toWhatsApp('123'), isNull);
      expect(PhoneFormatter.toWhatsApp(''), isNull);
      expect(PhoneFormatter.toWhatsApp('numara yok'), isNull);
    });

    test('Arama icin + korunur', () {
      expect(PhoneFormatter.toDial('+90 532 123 45 67'), '+905321234567');
      expect(PhoneFormatter.toDial('0532 123 45 67'), '05321234567');
      expect(PhoneFormatter.toDial('123'), isNull);
    });
  });

  group('Mesaj metni sinirlari', () {
    test('KRITIK: asiri uzun mesaj kirpilir', () {
      // Sinir yoktu: yapistirilan cok uzun metin Firestore 1 MiB dokuman
      // sinirina dayanip gonderimi sessizce basarisiz kilabiliyordu.
      final uzun = 'a' * 10000;
      final kirpik = CommunicationIds.clampBody(uzun);

      expect(kirpik.length, lessThanOrEqualTo(CommunicationIds.maxBodyLength));
    });

    test('Normal mesaj degismeden gecer', () {
      const mesaj = 'Merhaba, yarin veli toplantisi var.';
      expect(CommunicationIds.clampBody(mesaj), mesaj);
    });
  });
}
