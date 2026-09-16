import 'dart:convert';
import 'dart:typed_data';

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
}
