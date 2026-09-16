import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/school_board_repository.dart';
import 'package:sinifcepte/features/board_config/models/okul_config_model.dart';

/// Okul panosu deposu — yol şeması ve giriş doğrulaması.
///
/// ## Neden Firestore'a bağlanmıyor
///
/// `FirestoreClient` gerçek bir bağlantı ister; bu testler yolların ve
/// önden doğrulamanın doğruluğunu sınıyor. Kuralların gerçekten
/// koruduğu `test_rules/rules.test.mjs` içinde emülatöre karşı
/// kanıtlanıyor (24 test).
///
/// Buradaki asıl değer: **yol şeması kuralla birebir aynı olmalı.**
/// Kural `school_boards/{schoolId}/duty/{tarih}` bekliyor; kod farklı
/// bir yol üretirse yazma sessizce reddedilir ve sebebi görünmez.
void main() {
  const okulId = 'meb_16_123456';

  group('Yol şeması — kuralla uyum', () {
    test('KRİTİK: pano kök yolu', () {
      expect(
        SchoolBoardRepository.boardPath(okulId),
        'school_boards/meb_16_123456',
      );
    });

    test('KRİTİK: nöbetçi yolu tarih kimlikli', () {
      // Tarih kimlik olduğu için aynı güne ikinci yazma eskiyi
      // değiştirir, kuyruk oluşmaz.
      expect(
        SchoolBoardRepository.dutyPath(okulId, '2026-09-16'),
        'school_boards/meb_16_123456/duty/2026-09-16',
      );
    });

    test('KRİTİK: duyuru yolu', () {
      expect(
        SchoolBoardRepository.noticePath(okulId, 'ntc_1'),
        'school_boards/meb_16_123456/notices/ntc_1',
      );
    });

    test('doküman kimliği kanonik okul kimliğidir', () {
      // Kural yetkiyi `isSchoolAdminOf(schoolId)` ile tek
      // karşılaştırmada denetliyor; kimlik başka bir şey olursa
      // ekstra okuma gerekirdi.
      final yol = SchoolBoardRepository.boardPath(okulId);
      expect(yol.split('/')[1], okulId);
    });
  });

  group('Duyuru kimliği üretimi', () {
    test('ntc_ önekiyle başlar', () {
      expect(SchoolBoardRepository.newNoticeId(), startsWith('ntc_'));
    });

    test('KRİTİK: ardışık çağrılar AYNI milisaniyede de farklı kimlik üretir', () {
      // Tahmin edilebilir kimlik, aynı anda yazan iki yöneticinin
      // birbirinin kaydını ezmesine yol açıyordu
      // (communication_ids.dart:5-15'te belgelenen hata).
      //
      // Bu test gerçek bir kusur yakaladı: sonek `zaman % 100000` idi,
      // yani zamanın kendisi. Hızlı makinede 50 çağrı tek milisaniyede
      // bitiyor ve TÜM kimlikler aynı çıkıyordu.
      const adet = 200;
      final kimlikler = <String>{};
      for (var i = 0; i < adet; i++) {
        kimlikler.add(SchoolBoardRepository.newNoticeId());
      }

      // Gerçek rastgelelikle hepsi ayrı olmalı. 2^32 alanda 200 çekimde
      // çakışma olasılığı ihmal edilebilir (~0.0000046).
      expect(kimlikler.length, adet);
    });

    test('Firestore doküman kimliği için geçerli karakterler', () {
      final id = SchoolBoardRepository.newNoticeId();
      // Firestore kimliklerinde '/' olamaz, boş olamaz, '.' ve '..'
      // olamaz.
      expect(id, isNot(contains('/')));
      expect(id.length, greaterThan(4));
      expect(id, isNot('.'));
      expect(id, isNot('..'));
    });
  });

  group('Önden doğrulama — sunucunun reddedeceğini denemeyiz', () {
    late SchoolBoardRepository repo;

    setUp(() {
      repo = SchoolBoardRepository();
    });

    test('KRİTİK: boş schoolId ile pano yazılmaz', () async {
      expect(await repo.upsertBoard(schoolId: '', okulAdi: 'X'), isFalse);
    });

    test('KRİTİK: boş schoolId ile nöbetçi yazılmaz', () async {
      final sonuc = await repo.setDuty(
        schoolId: '',
        nobetci: const NobetciKaydi(
          tarih: '2026-09-16',
          kat: '1. Kat',
          ad: 'A. Yılmaz',
        ),
      );
      expect(sonuc, isFalse);
    });

    test('tarihsiz nöbetçi yazılmaz', () async {
      final sonuc = await repo.setDuty(
        schoolId: okulId,
        nobetci: const NobetciKaydi(tarih: '', kat: '1. Kat', ad: 'A. Yılmaz'),
      );
      expect(sonuc, isFalse);
    });

    test('boş liste ile toplu yazma yapılmaz', () async {
      expect(
        await repo.setDutyBatch(schoolId: okulId, nobetciler: const []),
        isFalse,
      );
    });

    test('KRİTİK: boş başlıklı duyuru yayımlanmaz', () async {
      final sonuc = await repo.publishNotice(
        schoolId: okulId,
        duyuru: const PanoDuyurusu(id: 'n1', baslik: '   ', metin: 'Metin'),
      );
      expect(sonuc, isFalse);
    });

    test('KRİTİK: 100 karakterden uzun başlık yayımlanmaz', () async {
      // Kural da reddediyor; önden kesmek kullanıcıya boş bir
      // reddedilme yaşatmamak için.
      final sonuc = await repo.publishNotice(
        schoolId: okulId,
        duyuru: PanoDuyurusu(
          id: 'n1',
          baslik: 'x' * 101,
          metin: 'Metin',
        ),
      );
      expect(sonuc, isFalse);
    });

    test('KRİTİK: 2000 karakterden uzun metin yayımlanmaz', () async {
      final sonuc = await repo.publishNotice(
        schoolId: okulId,
        duyuru: PanoDuyurusu(
          id: 'n1',
          baslik: 'Başlık',
          metin: 'x' * 2001,
        ),
      );
      expect(sonuc, isFalse);
    });

    test('kimliksiz duyuru yayımlanmaz', () async {
      final sonuc = await repo.publishNotice(
        schoolId: okulId,
        duyuru: const PanoDuyurusu(id: '', baslik: 'Başlık', metin: 'M'),
      );
      expect(sonuc, isFalse);
    });

    test('okul kimliği boşsa okuma boş liste döner', () async {
      expect(await repo.readNotices(schoolId: ''), isEmpty);
      expect(
        await repo.readDuties(
          schoolId: '',
          baslangicTarihi: '2026-09-01',
          bitisTarihi: '2026-09-30',
        ),
        isEmpty,
      );
    });
  });
}
