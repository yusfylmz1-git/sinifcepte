import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/okul_config_service.dart';
import 'package:sinifcepte/features/board_config/models/okul_config_model.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_imza.dart';
import 'package:sinifcepte/features/schedule/models/schedule_settings.dart';

/// `okul_config` üretim servisi.
///
/// ## Dosya yazma testleri neden yok
///
/// `getApplicationDocumentsDirectory()` platform kanalı istiyor ve
/// birim testinde mevcut değil. Bu yüzden testler **dosya yazmayan**
/// yolları kapsıyor: anahtar türetme, eksik alan denetimi, imza
/// doğruluğu.
///
/// Gerçek dosya üretimi uçtan uca doğrulandı: Python tarafı Dart'ın
/// ürettiği imzalı paketi kabul ediyor
/// (`sinifcepte-tahta/tests/test_capraz_dogrulama.py`, 24 test).
void main() {
  OkulConfigModel ornek({
    int surum = 3,
    String okulId = 'meb_16_123456',
    String okulAdi = 'Örnek Ortaokulu',
  }) =>
      OkulConfigModel(
        surum: surum,
        okulId: okulId,
        okulAdi: okulAdi,
        uretimZamani: '2026-09-16T10:00:00+03:00',
        gecerlilikBitis: '2026-12-31T23:59:59+03:00',
        zil: const ScheduleSettings(),
        ogretmenler: const [
          PanoOgretmeni(kod: 'OGR001', ad: 'A. Yılmaz'),
        ],
      );

  group('Anahtar üretimi ve türetme', () {
    test('anahtar çifti doğru uzunlukta', () {
      final cift = OkulConfigService.anahtarUret();

      expect(cift.ozelAnahtar.length, 64);
      expect(cift.dogrulamaAnahtari.length, 32);
    });

    test('KRİTİK: doğrulama anahtarı özel anahtarın son 32 baytı', () {
      // RFC 8032: 64 baytlık özel anahtar = 32 bayt tohum +
      // 32 bayt doğrulama anahtarı. Yanlış yarıyı alsaydık tahta
      // hiçbir dosyayı doğrulayamazdı.
      final cift = OkulConfigService.anahtarUret();

      final turetilen = OkulConfigService.dogrulamaAnahtariBase64(
        cift.ozelAnahtar,
      );

      expect(turetilen, cift.dogrulamaAnahtariBase64);
    });

    test('türetilen anahtar gerçekten doğrulama yapabiliyor', () {
      final cift = OkulConfigService.anahtarUret();
      final veri = Uint8List.fromList(utf8.encode('deneme'));
      final imza = TahtaImza.imzala(veri, cift.ozelAnahtar);

      final turetilen = TahtaImza.anahtarBase64Coz(
        OkulConfigService.dogrulamaAnahtariBase64(cift.ozelAnahtar),
      );

      expect(TahtaImza.dogrula(veri, imza, turetilen), isTrue);
    });

    test('yanlış uzunlukta anahtar hata verir', () {
      expect(
        () => OkulConfigService.dogrulamaAnahtariBase64(Uint8List(32)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Eksik alan denetimi — hata sahada değil burada yakalanmalı', () {
    test('KRİTİK: boş okulId üretimi durdurur', () async {
      final cift = OkulConfigService.anahtarUret();

      final sonuc = await OkulConfigService.uret(
        config: ornek(okulId: ''),
        ozelAnahtar: cift.ozelAnahtar,
      );

      expect(sonuc.basarili, isFalse);
      expect(sonuc.hataMesaji, contains('okulId'));
    });

    test('KRİTİK: boş okulAdi üretimi durdurur', () async {
      final cift = OkulConfigService.anahtarUret();

      final sonuc = await OkulConfigService.uret(
        config: ornek(okulAdi: '   '),
        ozelAnahtar: cift.ozelAnahtar,
      );

      expect(sonuc.basarili, isFalse);
      expect(sonuc.hataMesaji, contains('okulAdi'));
    });

    test('KRİTİK: sürüm 0 üretimi durdurur', () async {
      // Geri sarma koruması sürüme dayanıyor; 0 ile yayımlanan dosya
      // her zaman kabul edilirdi.
      final cift = OkulConfigService.anahtarUret();

      final sonuc = await OkulConfigService.uret(
        config: ornek(surum: 0),
        ozelAnahtar: cift.ozelAnahtar,
      );

      expect(sonuc.basarili, isFalse);
      expect(sonuc.hataMesaji, contains('surum'));
    });

    test('hata mesajı birden fazla eksiği birlikte bildirir', () async {
      final cift = OkulConfigService.anahtarUret();

      final sonuc = await OkulConfigService.uret(
        config: ornek(okulId: '', okulAdi: '', surum: 0),
        ozelAnahtar: cift.ozelAnahtar,
      );

      expect(sonuc.hataMesaji, contains('okulId'));
      expect(sonuc.hataMesaji, contains('okulAdi'));
      expect(sonuc.hataMesaji, contains('surum'));
    });
  });

  group('UretimSonucu', () {
    test('başarılı sonuç yolları taşır', () {
      final sonuc = UretimSonucu.basarili(
        jsonYolu: '/yol/okul_config.json',
        imzaYolu: '/yol/okul_config.sig',
        anahtarYolu: '/yol/dogrulama_anahtari.b64',
        baytSayisi: 836,
      );

      expect(sonuc.basarili, isTrue);
      expect(sonuc.baytSayisi, 836);
      expect(sonuc.hataMesaji, isEmpty);
    });

    test('hata sonucu yol taşımaz', () {
      const mesaj = 'Bir şey ters gitti';
      final sonuc = UretimSonucu.hata(mesaj);

      expect(sonuc.basarili, isFalse);
      expect(sonuc.jsonYolu, isEmpty);
      expect(sonuc.hataMesaji, mesaj);
    });

    test('KRİTİK: başarısız sonuç paylaşılmaz', () async {
      // Paylaşım, olmayan dosyayı açmaya kalkmamalı.
      expect(
        await OkulConfigService.paylas(UretimSonucu.hata('hata')),
        isFalse,
      );
    });
  });

  group('Dosya adları tahtanın beklediği gibi', () {
    test('Python tarafı bu adları okuyor', () {
      expect(TahtaYapilandirmaPaketi.jsonDosyaAdi, 'okul_config.json');
      expect(TahtaYapilandirmaPaketi.imzaDosyaAdi, 'okul_config.sig');
    });
  });

  group('Doğrulama anahtarı — ÜÇÜNCÜ dosya', () {
    // Bu dosya bir dönem hiç üretilmiyordu ve ekran "bu iki dosyayı
    // kopyalayın" diyordu. Tahta ise üçünü arıyor; bulamayınca
    // "Doğrulama anahtarı yok" deyip duruyordu ve müdür o dosyanın
    // var olduğunu bile bilmiyordu.
    //
    // ETAP'ta gerçek kurulumda görüldü (19 Eylül 2026): dosya elle
    // türetilerek kurtarıldı. Hiçbir müdür bunu yapamazdı.

    test('KRİTİK: Python tarafının aradığı ad', () {
      expect(
        TahtaYapilandirmaPaketi.anahtarDosyaAdi,
        'dogrulama_anahtari.b64',
        reason: 'servis/ana.py bu adı okuyor; ayrışırsa tahta çalışmaz',
      );
    });

    test('KRİTİK: sonuç üçüncü yolu taşıyor', () {
      final sonuc = UretimSonucu.basarili(
        jsonYolu: '/yol/okul_config.json',
        imzaYolu: '/yol/okul_config.sig',
        anahtarYolu: '/yol/dogrulama_anahtari.b64',
        baytSayisi: 836,
      );

      expect(sonuc.anahtarYolu, isNotEmpty);
      expect(sonuc.anahtarYolu, endsWith('dogrulama_anahtari.b64'));
    });

    test('KRİTİK: yazılan anahtar özel anahtarla eşleşiyor', () {
      // Yanlış anahtar yazılırsa imza tahtada DOĞRULANMAZ ve hata
      // "bozuk imza" gibi görünür; gerçek sebep eşleşmeyen anahtar
      // olurdu — bu depoda o hata sınıfı bir kez yaşandı.
      final cift = TahtaImza.anahtarCiftiUret();
      final baytlar = TahtaImza.jsonBaytlari({'a': 1});
      final imza = TahtaImza.imzala(baytlar, cift.ozelAnahtar);

      // Servisin yazdığı base64, çiftin doğrulama anahtarı olmalı.
      final yazilan = base64Encode(cift.dogrulamaAnahtari);
      final geri = base64Decode(yazilan);

      expect(geri.length, 32, reason: 'açık anahtar 32 bayt');
      expect(TahtaImza.dogrula(baytlar, imza, geri), isTrue);
    });

    test('KRİTİK: yazılan dosya ÖZEL anahtarı içermiyor', () {
      // Özel anahtar sızarsa flash belleği kopyalayan herkes geçerli
      // yapılandırma üretebilir — kilidin tüm anlamı kaybolur.
      final cift = TahtaImza.anahtarCiftiUret();
      final yazilan = base64Encode(cift.dogrulamaAnahtari);

      expect(base64Decode(yazilan).length, 32);
      expect(
        yazilan,
        isNot(contains(base64Encode(cift.ozelAnahtar))),
        reason: 'dosyaya yalnızca AÇIK anahtar yazılmalı',
      );
    });
  });

  group('Pano içeriği dosyaya GİRİYOR — Y8', () {
    // Nöbetçi ve duyurular bir dönem dosyaya hiç girmiyordu:
    // `OkulConfigModel` kurulurken verilmiyorlardı ve boş varsayılana
    // düşüyorlardı. Müdür nöbetçi giriyor, "kaydedildi" mesajını
    // alıyor, tahtada hiçbir zaman görmüyordu.
    //
    // Nöbetçi listesi bu modülün rakiplerde olmayan TEK ayırt edici
    // özelliği; bağlanmamış olması modülün varlık sebebini
    // boşaltıyordu (bağımsız incelemede bildirildi, 19 Eylül 2026'da
    // doğrulandı).
    //
    // Varsayılanın boş liste olması hatayı SESSİZ kılıyordu: derleme
    // hatası yok, çalışma zamanı hatası yok, yalnızca eksik veri.

    test('KRİTİK: nöbetçi listesi JSON çıktısında', () {
      final config = OkulConfigModel(
        surum: 1,
        okulId: 'meb_1',
        okulAdi: 'Deneme',
        uretimZamani: '2026-09-19T10:00:00+03:00',
        gecerlilikBitis: '2027-08-31T23:59:59+03:00',
        zil: const ScheduleSettings(
          firstLessonTime: TimeOfDay(hour: 8, minute: 30),
          lessonDuration: 40,
          breakDuration: 10,
          dailyLessonCount: 8,
        ),
        ogretmenler: const [
          PanoOgretmeni(kod: 'AYILMAZ', ad: 'A. Yilmaz', totpSecret: 'X'),
        ],
        nobetciler: const [
          NobetciKaydi(gun: 'pazartesi', kat: '1. Kat', ad: 'A. Yilmaz'),
          NobetciKaydi(gun: 'sali', kat: '2. Kat', ad: 'B. Kaya'),
        ],
        duyurular: const [
          PanoDuyurusu(id: 'd1', baslik: 'Veli toplantisi', metin: 'Cuma'),
        ],
      );

      final json = config.toJson();
      final nobetciler = json['nobetciler'] as List<Object?>;
      final duyurular = json['duyurular'] as List<Object?>;

      expect(nobetciler, hasLength(2), reason: 'tahtada boş görünürdü');
      expect(duyurular, hasLength(1));

      final ilk = nobetciler.first as Map<String, Object?>;
      expect(ilk['gun'], 'pazartesi');
      expect(ilk['ad'], 'A. Yilmaz');
    });

    test('boş liste verilirse JSON alanı yine VAR (boş dizi)', () {
      // Tahta tarafı alanın varlığını bekliyor; eksik alan farklı bir
      // hata sınıfı olurdu.
      final config = OkulConfigModel(
        surum: 1,
        okulId: 'meb_1',
        okulAdi: 'Deneme',
        uretimZamani: '2026-09-19T10:00:00+03:00',
        gecerlilikBitis: '2027-08-31T23:59:59+03:00',
        zil: const ScheduleSettings(
          firstLessonTime: TimeOfDay(hour: 8, minute: 30),
          lessonDuration: 40,
          breakDuration: 10,
          dailyLessonCount: 8,
        ),
        ogretmenler: const [
          PanoOgretmeni(kod: 'A', ad: 'A', totpSecret: 'X'),
        ],
      );

      final json = config.toJson();
      expect(json.containsKey('nobetciler'), isTrue);
      expect(json['nobetciler'], isEmpty);
    });

    test('KRİTİK: nöbetçi GÜN adı tahtanın beklediği biçimde', () {
      // `ekran.py::_GUNLER` aksansız küçük harf bekliyor. Şema bir kez
      // `tarih` → `gun` değişmiş ve liste tahtada SESSİZCE boş
      // kalmıştı; bu test o hata sınıfını kilitliyor.
      const kayit = NobetciKaydi(
        gun: 'carsamba',
        kat: '1. Kat',
        ad: 'A. Yilmaz',
      );

      final json = kayit.toJson();
      expect(json['gun'], 'carsamba');
      expect(json.containsKey('tarih'), isFalse);
    });
  });
}
