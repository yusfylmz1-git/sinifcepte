/// İmzalama anahtarının bulut yedeği — yol şeması ve önden doğrulama.
///
/// ## Neden bu katman riskli ve test edilmeli
///
/// Özel anahtar bulutta **düz** duruyor (kullanıcı kararı, 18 Eylül
/// 2026: parolasız yedek). Yani bozuk bir değerin yedeklenmesi veya
/// bozuk bir yedeğin geri yüklenmesi **her imzayı sessizce geçersiz
/// kılar** — sahada teşhisi en zor hata sınıfı.
///
/// Bu testler o iki yolu da kapatıyor.
///
/// Kuralların gerçekten koruduğu `test_rules/rules.test.mjs` içinde
/// emülatöre karşı kanıtlanıyor (8 test).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/tahta_anahtar_bulut_yedegi.dart';

void main() {
  const okulId = 'meb_775214';
  final gecerliAnahtar = 'A' * 88;

  group('Yol şeması — kuralla uyum', () {
    test('KRİTİK: yedek yolu gizli alt koleksiyonunda', () {
      // `school_boards/{schoolId}` okumaya herkese açık; anahtar
      // oraya yazılsaydı okuldaki her öğretmen okuyabilirdi.
      expect(
        TahtaAnahtarBulutYedegi.yedekPath(okulId),
        'school_boards/meb_775214/gizli/imzalama_anahtari',
      );
    });

    test('yol okul kimliğini taşıyor', () {
      final a = TahtaAnahtarBulutYedegi.yedekPath('meb_111');
      final b = TahtaAnahtarBulutYedegi.yedekPath('meb_222');
      expect(a, isNot(b));
    });
  });

  group('Önden doğrulama', () {
    late TahtaAnahtarBulutYedegi yedek;

    setUp(() => yedek = TahtaAnahtarBulutYedegi());

    test('boş okul kimliğiyle yedeklenmez', () async {
      expect(
        await yedek.yedekle(schoolId: '', base64Anahtar: gecerliAnahtar),
        isFalse,
      );
    });

    test('boş anahtar yedeklenmez', () async {
      expect(
        await yedek.yedekle(schoolId: okulId, base64Anahtar: ''),
        isFalse,
      );
    });

    test('KRİTİK: yanlış uzunluktaki anahtar yedeklenmez', () async {
      // 64 bayt → 88 karakter. Bozuk bir değeri yedeklemek, geri
      // yüklendiğinde sessizce geçersiz imza üretirdi.
      expect(
        await yedek.yedekle(schoolId: okulId, base64Anahtar: 'A' * 87),
        isFalse,
      );
      expect(
        await yedek.yedekle(schoolId: okulId, base64Anahtar: 'A' * 89),
        isFalse,
      );
      expect(
        await yedek.yedekle(schoolId: okulId, base64Anahtar: 'kisa'),
        isFalse,
      );
    });

    test('boş okul kimliğiyle okuma null', () async {
      expect(await yedek.oku(schoolId: ''), isNull);
      expect(await yedek.yedekZamani(schoolId: ''), isNull);
    });

    test('boş okul kimliğiyle silme yapılmaz', () async {
      expect(await yedek.sil(schoolId: ''), isFalse);
    });

    test('bulut yokken okuma çökmez', () async {
      // Testte Firestore bağlantısı yok; sessizce null dönmeli.
      expect(await yedek.oku(schoolId: okulId), isNull);
    });
  });
}
