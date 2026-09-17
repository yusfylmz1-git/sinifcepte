import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/models/okul_config_model.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_imza.dart';
import 'package:sinifcepte/features/schedule/models/schedule_settings.dart';

/// Tahta yapılandırmasının imzalanması ve paketlenmesi.
///
/// ## Karşı taraf
///
/// Doğrulamayı tahta yapıyor:
/// `sinifcepte-tahta/sinifcepte_tahta/cekirdek/yapilandirma.py`
///
/// Buradaki testler Dart tarafının **doğru baytları** ve **doğru alan
/// adlarını** ürettiğini kanıtlar. Alan adı uyuşmazsa Python sessizce
/// varsayılana düşer — sahada teşhisi zor bir hata, o yüzden burada
/// açıkça sınanıyor.
void main() {
  OkulConfigModel ornekConfig({
    int surum = 3,
    String okulId = 'meb_16_123456',
    String okulAdi = 'Örnek Ortaokulu',
  }) {
    return OkulConfigModel(
      surum: surum,
      okulId: okulId,
      okulAdi: okulAdi,
      uretimZamani: '2026-09-16T10:00:00+03:00',
      gecerlilikBitis: '2026-12-31T23:59:59+03:00',
      zil: const ScheduleSettings(),
      ogretmenler: const [
        PanoOgretmeni(
          kod: 'OGR001',
          ad: 'A. Yılmaz',
          totpSecret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        ),
      ],
      nobetciler: const [
        NobetciKaydi(gun: 'carsamba', kat: '1. Kat', ad: 'A. Yılmaz'),
      ],
      duyurular: const [
        PanoDuyurusu(id: 'd1', baslik: 'Veli toplantısı', metin: 'Cuma 15:00'),
      ],
    );
  }

  group('Anahtar çifti', () {
    test('üretilen anahtarlar doğru uzunlukta', () {
      final cift = TahtaImza.anahtarCiftiUret();

      // Ed25519: 64 bayt özel, 32 bayt doğrulama (RFC 8032).
      expect(cift.ozelAnahtar.length, 64);
      expect(cift.dogrulamaAnahtari.length, 32);
    });

    test('her çağrı farklı anahtar üretir', () {
      final a = TahtaImza.anahtarCiftiUret();
      final b = TahtaImza.anahtarCiftiUret();
      expect(a.ozelAnahtar, isNot(b.ozelAnahtar));
    });

    test('base64 gidiş-dönüş kayıpsız', () {
      final cift = TahtaImza.anahtarCiftiUret();
      final geri = TahtaImza.anahtarBase64Coz(cift.dogrulamaAnahtariBase64);
      expect(geri, cift.dogrulamaAnahtari);
    });
  });

  group('İmzalama ve doğrulama', () {
    test('kendi imzasını doğrular', () {
      final cift = TahtaImza.anahtarCiftiUret();
      final veri = Uint8List.fromList(utf8.encode('deneme'));

      final imza = TahtaImza.imzala(veri, cift.ozelAnahtar);

      expect(imza.length, 64);
      expect(TahtaImza.dogrula(veri, imza, cift.dogrulamaAnahtari), isTrue);
    });

    test('KRİTİK: bozuk imza reddedilir', () {
      final cift = TahtaImza.anahtarCiftiUret();
      final veri = Uint8List.fromList(utf8.encode('deneme'));
      final imza = TahtaImza.imzala(veri, cift.ozelAnahtar);

      final bozuk = Uint8List.fromList(imza);
      bozuk[0] ^= 0xFF;

      expect(TahtaImza.dogrula(veri, bozuk, cift.dogrulamaAnahtari), isFalse);
    });

    test('KRİTİK: değiştirilmiş veri reddedilir', () {
      final cift = TahtaImza.anahtarCiftiUret();
      final imza = TahtaImza.imzala(
        Uint8List.fromList(utf8.encode('asıl veri')),
        cift.ozelAnahtar,
      );

      expect(
        TahtaImza.dogrula(
          Uint8List.fromList(utf8.encode('kurcalanmış veri')),
          imza,
          cift.dogrulamaAnahtari,
        ),
        isFalse,
      );
    });

    test('KRİTİK: başka anahtarla imzalanmış veri reddedilir', () {
      // Başka okulun idarecisinin dosyası bu tahtada çalışmamalı.
      final bizim = TahtaImza.anahtarCiftiUret();
      final yabanci = TahtaImza.anahtarCiftiUret();
      final veri = Uint8List.fromList(utf8.encode('deneme'));

      final imza = TahtaImza.imzala(veri, yabanci.ozelAnahtar);

      expect(TahtaImza.dogrula(veri, imza, bizim.dogrulamaAnahtari), isFalse);
    });

    test('yanlış uzunlukta özel anahtar hata verir', () {
      expect(
        () => TahtaImza.imzala(
          Uint8List.fromList([1, 2, 3]),
          Uint8List(32),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('yanlış uzunlukta doğrulama anahtarı çökmez, false döner', () {
      final veri = Uint8List.fromList(utf8.encode('x'));
      expect(TahtaImza.dogrula(veri, Uint8List(64), Uint8List(10)), isFalse);
    });

    test('yanlış uzunlukta imza çökmez, false döner', () {
      final cift = TahtaImza.anahtarCiftiUret();
      final veri = Uint8List.fromList(utf8.encode('x'));
      expect(
        TahtaImza.dogrula(veri, Uint8List(10), cift.dogrulamaAnahtari),
        isFalse,
      );
    });
  });

  group('Paketleme', () {
    test('paket doğrulanabilir imza taşır', () {
      final cift = TahtaImza.anahtarCiftiUret();
      final paket = TahtaImza.paketle(
        yapilandirma: ornekConfig().toJson(),
        ozelAnahtar: cift.ozelAnahtar,
      );

      expect(
        TahtaImza.dogrula(
          paket.jsonBaytlari,
          paket.imza,
          cift.dogrulamaAnahtari,
        ),
        isTrue,
      );
    });

    test('KRİTİK: imzalanan baytlar dosyaya yazılacak baytlarla aynı', () {
      // En sinsi hata sınıfı: JSON ikinci kez farklı biçimde
      // kodlanırsa (girinti, alan sırası) imza geçersiz olur ve tahta
      // dosyayı reddeder. `jsonBaytlari` tek kaynak olmalı.
      final config = ornekConfig();
      final cift = TahtaImza.anahtarCiftiUret();

      final paket = TahtaImza.paketle(
        yapilandirma: config.toJson(),
        ozelAnahtar: cift.ozelAnahtar,
      );
      final ikinciKodlama = TahtaImza.jsonBaytlari(config.toJson());

      expect(paket.jsonBaytlari, ikinciKodlama);
    });

    test('JSON geçerli UTF-8 ve Türkçe karakterleri korur', () {
      final config = OkulConfigModel(
        surum: 1,
        okulId: 'meb_16_1',
        okulAdi: 'Şehit Öğretmen İğdır Çağlayan İlkokulu',
        uretimZamani: '2026-09-16T10:00:00+03:00',
        gecerlilikBitis: '2026-12-31T23:59:59+03:00',
        zil: const ScheduleSettings(),
      );

      final baytlar = TahtaImza.jsonBaytlari(config.toJson());
      final geri = jsonDecode(utf8.decode(baytlar)) as Map<String, dynamic>;

      expect(geri['okulAdi'], 'Şehit Öğretmen İğdır Çağlayan İlkokulu');
    });

    test('dosya adları tahtanın beklediği gibi', () {
      // Python tarafı bu adları okuyor.
      expect(TahtaYapilandirmaPaketi.jsonDosyaAdi, 'okul_config.json');
      expect(TahtaYapilandirmaPaketi.imzaDosyaAdi, 'okul_config.sig');
    });
  });

  group('Python ile alan adı uyumu', () {
    // Bu grup, `cekirdek/yapilandirma.py` ve `cekirdek/zil.py`
    // dosyalarının okuduğu anahtar adlarını sabitliyor.

    test('KRİTİK: üst düzey alan adları', () {
      final json = ornekConfig().toJson();

      expect(json.keys, containsAll(<String>[
        'surum',
        'okulId',
        'okulAdi',
        'uretimZamani',
        'gecerlilikBitis',
        'zil',
        'ogretmenler',
        'nobetciler',
        'duyurular',
      ]));
    });

    test('KRİTİK: zil bloğu alan adları ZilAyarlari.sozlukten ile aynı', () {
      final zil = ornekConfig().toJson()['zil'] as Map<String, Object?>;

      // Python: ilkDersSaati, dersSuresi, teneffusSuresi, gunlukDersSayisi,
      // ogleArasiVar, ogleArasiSuresi, ogleArasiKacinciDerstenSonra
      expect(zil.keys, containsAll(<String>[
        'ilkDersSaati',
        'dersSuresi',
        'teneffusSuresi',
        'gunlukDersSayisi',
        'ogleArasiVar',
        'ogleArasiSuresi',
        'ogleArasiKacinciDerstenSonra',
      ]));
    });

    test('KRİTİK: ilkDersSaati "HH:MM" biçiminde', () {
      // Python `_baslangic_dakika` bunu ':' ile bölüyor; biçim bozulursa
      // tahta açılışta çöker.
      final zil = ornekConfig().toJson()['zil'] as Map<String, Object?>;
      expect(zil['ilkDersSaati'], '08:30');
      expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(zil['ilkDersSaati'] as String),
          isTrue);
    });

    test('tek haneli saat iki haneye doldurulur', () {
      final config = OkulConfigModel(
        surum: 1,
        okulId: 'meb_16_1',
        okulAdi: 'X',
        uretimZamani: '',
        gecerlilikBitis: '',
        zil: const ScheduleSettings(
          firstLessonTime: TimeOfDay(hour: 9, minute: 5),
        ),
      );

      final zil = config.toJson()['zil'] as Map<String, Object?>;
      expect(zil['ilkDersSaati'], '09:05');
    });

    test('KRİTİK: öğretmen alan adları', () {
      final ogretmenler =
          ornekConfig().toJson()['ogretmenler'] as List<Object?>;
      final ilk = ogretmenler.first as Map<String, Object?>;

      expect(ilk.keys, containsAll(<String>['kod', 'ad', 'totpSecret', 'pinHash']));
    });

    test('KRİTİK: nöbetçi alan adları', () {
      final nobetciler = ornekConfig().toJson()['nobetciler'] as List<Object?>;
      final ilk = nobetciler.first as Map<String, Object?>;

      // Python `Nobetci` `gun` okuyor, `tarih` DEĞİL.
      //
      // Bu test bir dönem `tarih` bekliyordu ve **yanlış tarafa
      // kilitlenmişti**: geçiyordu ama üretilen dosyada nöbetçi
      // listesi tahtada tamamen boş kalıyordu — imza geçerli, dosya
      // yükleniyor, liste görünmüyor, hata mesajı yok.
      expect(ilk.keys, containsAll(<String>['gun', 'kat', 'ad']));
      expect(ilk.containsKey('tarih'), isFalse,
          reason: 'tarih alanı tahta tarafında okunmuyor');
    });

    test('KRİTİK: nöbetçi günü tahtanın tanıdığı biçimde', () {
      final nobetciler = ornekConfig().toJson()['nobetciler'] as List<Object?>;
      final ilk = nobetciler.first as Map<String, Object?>;

      // `ekran.py::_GUNLER` — aksansız, küçük harf.
      expect(
        const [
          'pazartesi',
          'sali',
          'carsamba',
          'persembe',
          'cuma',
          'cumartesi',
          'pazar',
        ],
        contains(ilk['gun']),
      );
    });

    test('KRİTİK: duyuru alan adları', () {
      final duyurular = ornekConfig().toJson()['duyurular'] as List<Object?>;
      final ilk = duyurular.first as Map<String, Object?>;

      expect(ilk.keys,
          containsAll(<String>['id', 'baslik', 'metin', 'baslangic', 'bitis']));
    });
  });

  group('Üretim öncesi doğrulama', () {
    test('eksiksiz yapılandırmada uyarı yok', () {
      expect(ornekConfig().eksikAlanlar(), isEmpty);
    });

    test('boş okulId yakalanır', () {
      expect(ornekConfig(okulId: '').eksikAlanlar(), contains('okulId'));
    });

    test('boş okulAdi yakalanır', () {
      expect(ornekConfig(okulAdi: '   ').eksikAlanlar(), contains('okulAdi'));
    });

    test('KRİTİK: sürüm 0 veya negatif olamaz', () {
      // Geri sarma koruması sürüme dayanıyor; 0 ile yayımlanan dosya
      // her zaman kabul edilirdi.
      expect(ornekConfig(surum: 0).eksikAlanlar(), contains('surum'));
      expect(ornekConfig(surum: -1).eksikAlanlar(), contains('surum'));
    });
  });
}
