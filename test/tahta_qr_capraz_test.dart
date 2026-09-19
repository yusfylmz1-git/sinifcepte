/// Python tahtasının ürettiği QR yükünü Dart telefon tarafı okuyabiliyor mu?
///
/// ## Neden bu dosya var
///
/// `qrAyristir`'ın kendi testleri var ama hepsi **Dart'ın kendi
/// yazdığı** dizeleri okuyor. İki taraf da kendi kendini doğrularsa
/// aradaki sözleşme hiç sınanmamış olur.
///
/// Bu depoda tam olarak o hata sınıfı yaşandı: nöbetçi şeması
/// `tarih` → `gun` değişti, Python tarafı eski şemada kaldı, iki
/// tarafın testleri de geçti ve liste tahtada **sessizce boş**
/// göründü.
///
/// ## Aşağıdaki dizeler elle yazılmadı
///
/// `sinifcepte-tahta` deposunda üretildiler:
///
/// ```
/// python -c "from sinifcepte_tahta.servis.yerel_sunucu import qr_yuku; \
///   print(qr_yuku(okul_id='meb_16_123456', sinif='8/B', pencere=58000000))"
/// ```
///
/// Python tarafı biçimi değiştirirse bu testler kırılır — ve kırılması
/// gerekir: telefon o yükü okuyamayacak demektir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_totp.dart';

/// Python `qr_yuku(okul_id='meb_16_123456', sinif='8/B', pencere=58000000)`
const _pythonSc1 = 'SC1:meb_16_123456:tahta_8B:3750280:58000000';

/// Aynı çağrı, `ip='192.168.1.50', port=8443` ile.
const _pythonSc2 =
    'SC2:meb_16_123456:tahta_8B:3750280:58000000:192.168.1.50:8443';

/// Sınıf adı boşken (`sinif=''`), farklı port.
const _pythonSc2Sinifsiz =
    'SC2:meb_16_123456:tahta:3750280:58000000:10.0.0.7:9000';

void main() {
  group('Python tahtasının ürettiği SC1', () {
    test('KRİTİK: ayrıştırılabiliyor', () {
      final yuk = TahtaTotp.qrAyristir(_pythonSc1);

      expect(yuk, isNotNull, reason: 'Python SC1 yükü okunamadı');
      expect(yuk!.okulId, 'meb_16_123456');
      expect(yuk.tahtaId, 'tahta_8B');
      expect(yuk.unixDakika, 58000000);
    });

    test('KRİTİK: ağdan açılamaz olarak işaretleniyor', () {
      // SC1, tahtanın yerel sunucusu çalışmadığı anlamına geliyor.
      // Telefon burada ağ isteği denerse 4 saniye boşa bekler ve
      // öğretmen ders başında bekletilir.
      final yuk = TahtaTotp.qrAyristir(_pythonSc1)!;

      expect(yuk.agdanAcilabilir, isFalse);
      expect(yuk.ip, isEmpty);
      expect(yuk.port, isNull);
    });
  });

  group('Python tahtasının ürettiği SC2', () {
    test('KRİTİK: adres doğru okunuyor', () {
      final yuk = TahtaTotp.qrAyristir(_pythonSc2);

      expect(yuk, isNotNull, reason: 'Python SC2 yükü okunamadı');
      expect(yuk!.agdanAcilabilir, isTrue);
      expect(yuk.ip, '192.168.1.50');
      expect(yuk.port, 8443);
    });

    test('KRİTİK: açma adresi tahtanın dinlediği yol', () {
      // Python tarafı yalnızca `POST /ac` sunuyor. Yol ayrışırsa
      // tahta 404 döner ve telefon "reddedildi" der — oysa kod
      // doğrudur ve sebebi sahada anlaşılmaz.
      final yuk = TahtaTotp.qrAyristir(_pythonSc2)!;

      expect(yuk.acmaAdresi, 'http://192.168.1.50:8443/ac');
    });

    test('KRİTİK: okul kimliği SC1 ile aynı yerden okunuyor', () {
      // Alan kayması olsaydı telefon okul kimliğini yanlış alandan
      // okur ve "bu tahta başka bir okula ait" derdi. O hata bir kez
      // yaşandı (18 Eylül 2026, deneme verisiyle).
      final sc1 = TahtaTotp.qrAyristir(_pythonSc1)!;
      final sc2 = TahtaTotp.qrAyristir(_pythonSc2)!;

      expect(sc2.okulId, sc1.okulId);
      expect(sc2.tahtaId, sc1.tahtaId);
      expect(sc2.nonce, sc1.nonce);
      expect(sc2.unixDakika, sc1.unixDakika);
    });

    test('sınıfsız tahta ve farklı port okunuyor', () {
      final yuk = TahtaTotp.qrAyristir(_pythonSc2Sinifsiz)!;

      expect(yuk.tahtaId, 'tahta');
      expect(yuk.ip, '10.0.0.7');
      expect(yuk.port, 9000);
    });
  });

  group('Okul eşleşmesi', () {
    test('KRİTİK: başka okulun tahtası reddediliyor', () {
      final yuk = TahtaTotp.qrAyristir(_pythonSc2)!;

      expect(yuk.ayniOkul('meb_16_123456'), isTrue);
      expect(yuk.ayniOkul('meb_775214'), isFalse);
    });
  });
}
