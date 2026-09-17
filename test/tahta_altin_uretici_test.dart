/// Çapraz doğrulama için altın dosya **üreticisi**.
///
/// ## Neden test dosyası, ayrı bir script değil
///
/// Üretici `TahtaImza` ve `OkulConfigModel`'i gerçek hâlleriyle
/// çağırmak zorunda. Flutter paketine bağımlı kodu çalıştırmanın en
/// kısa yolu `flutter test`; ayrı bir `bin/` scripti aynı bağımlılıkları
/// ister ama CI'da unutulur.
///
/// ## Neden gerekliydi
///
/// Python tarafındaki `tests/altin_dart/` dosyaları bir kez **elle**
/// oluşturulmuştu. Çapraz doğrulama testinin başlığı "Dart tarafı
/// değişirse yenilenecek" diyordu ama yenilemenin bir yolu yoktu.
///
/// Sonuç: `NobetciKaydi` şeması `tarih` → `gun` değiştiğinde altın
/// dosya eski şemada kaldı ve **uyuşmazlık fark edilmedi**. İmza
/// geçerliydi, dosya yükleniyordu, yalnızca nöbetçi listesi tahtada
/// sessizce boş kalıyordu.
///
/// ## Çalıştırma
///
/// ```
/// flutter test test/tahta_altin_uretici_test.dart --dart-define=ALTIN_YAZ=1
/// ```
///
/// `ALTIN_YAZ` verilmezse üretim yapılmaz, yalnızca mevcut dosyalarla
/// tutarlılık sınanır — böylece normal `flutter test` koşusunda
/// dosyalar kazara değişmez.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/models/okul_config_model.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_imza.dart';
import 'package:sinifcepte/features/schedule/models/schedule_settings.dart';

/// Altın dosyaların bulunduğu Python deposu.
///
/// Göreli yol: iki depo yan yana duruyor. Yol bulunamazsa üretim
/// atlanıyor (başka bir makinede farklı yerleşim olabilir).
const _pythonDepoYolu = '../sinifcepte-tahta/tests/altin_dart';

/// Altın yapılandırma — Python tarafındaki testler bu değerleri
/// birebir bekliyor (`test_capraz_dogrulama.py`).
///
/// Türkçe karakter **bilinçli olarak yok**: Python testleri ASCII
/// yazılmış ve dosya baytları imzalanıyor; kodlama farkı imzayı
/// geçersiz kılardı.
OkulConfigModel _altinConfig() => OkulConfigModel(
      surum: 3,
      okulId: 'meb_16_123456',
      okulAdi: 'Sehit Ogretmen Igdir Caglayan Ilkokulu',
      uretimZamani: '2026-09-16T10:00:00+03:00',
      // Uzak tarih: altın dosya süre geçti diye kırılmamalı.
      // Sabit tarihli testler tazelik sınırını aşınca kod değişmeden
      // kırılıyor — bu depoda bir kez yaşandı.
      gecerlilikBitis: '2099-12-31T23:59:59+03:00',
      zil: const ScheduleSettings(
        firstLessonTime: TimeOfDay(hour: 9, minute: 5),
        lessonDuration: 45,
        breakDuration: 15,
        dailyLessonCount: 7,
        hasLunchBreak: true,
        lunchBreakDuration: 50,
        lunchBreakAfterLesson: 3,
      ),
      ogretmenler: const [
        PanoOgretmeni(
          kod: 'OGR001',
          ad: 'A. Yilmaz',
          totpSecret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        ),
      ],
      nobetciler: const [
        // Haftalık döngü — 16 Eylül 2026 çarşambaydı, eski tarih
        // bazlı altın dosyayla aynı günü koruyor.
        NobetciKaydi(gun: 'carsamba', kat: '1. Kat', ad: 'A. Yilmaz'),
      ],
      duyurular: const [
        PanoDuyurusu(id: 'd1', baslik: 'Veli toplantisi', metin: 'Cuma 15:00'),
      ],
    );

void main() {
  const yaz = String.fromEnvironment('ALTIN_YAZ') == '1';

  group('Altın dosya şeması', () {
    test('KRİTİK: nöbetçi gün adı taşıyor', () {
      final json = _altinConfig().toJson();
      final nobetciler = json['nobetciler'] as List<Object?>;
      final ilk = nobetciler.first as Map<String, Object?>;

      expect(ilk['gun'], 'carsamba');
      expect(ilk.containsKey('tarih'), isFalse);
    });

    test('KRİTİK: imzalanan baytlar dosyaya yazılacak baytlarla aynı', () {
      final config = _altinConfig();
      final baytlar = TahtaImza.jsonBaytlari(config.toJson());

      // Aynı veriyi ikinci kez kodlamak farklı bayt üretirse imza
      // geçersiz olur. Bu, sahada teşhisi en zor hata sınıfı.
      final ikinci = TahtaImza.jsonBaytlari(config.toJson());
      expect(baytlar, ikinci);
    });

    test('üretilen JSON çözülebilir', () {
      final baytlar = TahtaImza.jsonBaytlari(_altinConfig().toJson());
      final geri = jsonDecode(utf8.decode(baytlar)) as Map<String, Object?>;
      expect(geri['okulId'], 'meb_16_123456');
    });
  });

  group('Python deposundaki altın dosya ile tutarlılık', () {
    late Directory depo;

    setUp(() {
      depo = Directory(_pythonDepoYolu);
    });

    test('KRİTİK: mevcut altın dosya güncel şemada', () {
      if (!depo.existsSync()) {
        markTestSkipped('Python deposu bulunamadı: $_pythonDepoYolu');
        return;
      }

      final dosya = File('${depo.path}/okul_config.json');
      if (!dosya.existsSync()) {
        markTestSkipped('Altın dosya yok — üretmek için ALTIN_YAZ=1');
        return;
      }

      final mevcut =
          jsonDecode(dosya.readAsStringSync()) as Map<String, Object?>;
      final nobetciler = mevcut['nobetciler'] as List<Object?>;

      if (nobetciler.isEmpty) return;
      final ilk = nobetciler.first as Map<String, Object?>;

      expect(
        ilk.containsKey('gun'),
        isTrue,
        reason: 'Altın dosya eski şemada (tarih). Yenilemek için: '
            'flutter test test/tahta_altin_uretici_test.dart '
            '--dart-define=ALTIN_YAZ=1',
      );
    });

    test('altın dosyaları üret', () {
      if (!yaz) {
        markTestSkipped('ALTIN_YAZ=1 verilmedi — üretim atlandı');
        return;
      }
      if (!depo.existsSync()) {
        markTestSkipped('Python deposu bulunamadı: $_pythonDepoYolu');
        return;
      }

      final cift = TahtaImza.anahtarCiftiUret();
      final config = _altinConfig();
      final baytlar = TahtaImza.jsonBaytlari(config.toJson());
      final imza = TahtaImza.imzala(baytlar, cift.ozelAnahtar);

      // Üç dosya BİRLİKTE yazılıyor. Biri eskisi kalırsa imza
      // doğrulaması başarısız olur ve sebebi "bozuk imza" gibi
      // görünür — gerçek sebep eşleşmeyen anahtar olurdu.
      File('${depo.path}/okul_config.json').writeAsBytesSync(baytlar);
      File('${depo.path}/okul_config.sig').writeAsBytesSync(imza);
      File('${depo.path}/dogrulama_anahtari.b64')
          .writeAsStringSync(base64Encode(cift.dogrulamaAnahtari));

      // Yazdığımızı kendi doğrulayıcımızla sınıyoruz; Python tarafı da
      // aynı baytları aynı anahtarla doğrulayacak.
      final gecerli = TahtaImza.dogrula(
        baytlar,
        imza,
        cift.dogrulamaAnahtari,
      );
      expect(gecerli, isTrue);
    });
  });
}
