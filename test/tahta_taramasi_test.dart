import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/ogretmen_tahta_deposu.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_taramasi.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_totp.dart';

/// "Tahtadaki QR'ı Okut" düğmesiyle okunan karekodun yorumu ve
/// birden çok okulda doğru kaydın seçilmesi.
///
/// Cihazda (1 Ekim 2026): öğretmen Ana Program'ın tanımlama karekodunu
/// bu düğmeyle okuttu ve "Bu QR bir SınıfCepte tahtasına ait değil"
/// gördü. Aynı gün: iki okulda ders veren öğretmen ikinci okula
/// kaydolunca birincinin tahtalarını açamıyordu.
void main() {
  const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
  const birinci = OgretmenTahtaKaydi(
    okulId: 'meb_16_123456',
    kod: 'YUSUFYILMA',
    ad: 'Yusuf YILMAZ',
    totpSecret: secret,
  );
  const ikinci = OgretmenTahtaKaydi(
    okulId: 'meb_775214',
    kod: 'YYILMAZ',
    ad: 'Yusuf Yilmaz',
    totpSecret: 'KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU',
    okulAdi: 'Mimar Sinan Ortaokulu',
  );

  // Ana Program'ın ürettiği biçim (`ana_program/cekirdek/ogretmen.py`).
  const anaProgramKurulumu = 'SCT1:meb_775214:YYILMAZ:Yusuf Yilmaz:'
      'KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU:Mimar Sinan Ortaokulu';

  group('karekodun yorumu', () {
    test('tahtanın kilit ekranı karekodu (SC1 ve SC2) tahta sayılıyor', () {
      expect(
        tahtaTaramasiniYorumla(
            'SC1:meb_16_123456:tahta_8B:3b9aca0:62500000', [birinci]),
        TahtaTaramasi.tahta,
      );
      expect(
        tahtaTaramasiniYorumla(
            'SC2:meb_16_123456:tahta_8B:3b9aca0:62500000:192.168.1.150:8443',
            [birinci]),
        TahtaTaramasi.tahta,
      );
    });

    test('KRITIK: yeni okulun tanımlama karekodu "ait değil" denmeden EKLENİR',
        () {
      expect(tahtaTaramasiniYorumla(anaProgramKurulumu, [birinci]),
          TahtaTaramasi.kurulumEkle);
      expect(tahtaTaramasiniYorumla(anaProgramKurulumu, const []),
          TahtaTaramasi.kurulumEkle);
    });

    test('telefondaki tanımın kendi karekodu "zaten kayıtlı"', () {
      expect(tahtaTaramasiniYorumla(anaProgramKurulumu, [birinci, ikinci]),
          TahtaTaramasi.kurulumAyni);
    });

    test('KRITIK: kayıtlı okulun YENİ secret\'i → yenileme (sorulur)', () {
      expect(
        tahtaTaramasiniYorumla(
            'SCT1:meb_16_123456:YUSUFYILMA:Yusuf YILMAZ:'
            'KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU',
            [birinci, ikinci]),
        TahtaTaramasi.kurulumYenile,
      );
    });

    test('ilgisiz karekod tanımsız', () {
      for (final ham in ['https://eba.gov.tr', 'SCT1:eksik:alan', '', 'SC1:a:b']) {
        expect(tahtaTaramasiniYorumla(ham, [birinci]), TahtaTaramasi.tanimsiz,
            reason: ham);
      }
    });
  });

  group('birden çok okulda doğru kayıt', () {
    test('KRITIK: tahtanın okulu hangisiyse o okulun kaydı seçilir', () {
      final yuk1 = TahtaTotp.qrAyristir(
          'SC1:meb_16_123456:tahta_8B:3b9aca0:62500000')!;
      final yuk2 = TahtaTotp.qrAyristir(
          'SC2:meb_775214:tahta_5A:3b9aca0:62500000:192.168.1.182:8443')!;

      expect(tahtaIcinKayit(yuk1, [birinci, ikinci]), same(birinci));
      expect(tahtaIcinKayit(yuk2, [birinci, ikinci]), same(ikinci));
      // Sıra önemli değil.
      expect(tahtaIcinKayit(yuk1, [ikinci, birinci]), same(birinci));
    });

    test('tanımlı olmayan okulun tahtası için kayıt yok', () {
      final yuk = TahtaTotp.qrAyristir('SC1:meb_06_1:tahta:3b9aca0:62500000')!;
      expect(tahtaIcinKayit(yuk, [birinci, ikinci]), isNull);
    });

    test('KRITIK: telefondan kilitleme yalnız tanımlı okulun yakın tarihli tahtasında', () {
      final simdi = DateTime(2026, 10, 1, 21, 30);
      SonTahta tahta({String okul = 'meb_775214', Duration once = Duration.zero,
              String ip = '192.168.1.182'}) =>
          SonTahta(okulId: okul, tahtaId: 'tahta_5A', ip: ip, port: 8443,
              zaman: simdi.subtract(once));

      expect(telefondanKilitlenebilir(tahta(), [ikinci], simdi), isTrue);
      expect(telefondanKilitlenebilir(null, [ikinci], simdi), isFalse);
      // Okul telefondan silinmiş.
      expect(telefondanKilitlenebilir(tahta(), [birinci], simdi), isFalse);
      // Dünkü tahta: başka ders, başka sınıf olabilir.
      expect(telefondanKilitlenebilir(tahta(once: const Duration(hours: 13)),
          [ikinci], simdi), isFalse);
      expect(telefondanKilitlenebilir(tahta(ip: ''), [ikinci], simdi), isFalse);
    });

    test('son tahtanın görünen adı', () {
      SonTahta t(String id) => SonTahta(okulId: 'o', tahtaId: id, ip: '1.1.1.1',
          port: 1, zaman: DateTime(2026));
      expect(t('tahta_5A').gorunenAd, '5A');
      expect(t('tahta').gorunenAd, 'tahta');
      expect(t('tahta_5A').kilitlemeAdresi, 'http://1.1.1.1:1/kilitle');
    });

    test('okulKaydi okul kimliğiyle bulur', () {
      expect(okulKaydi([birinci, ikinci], 'meb_775214'), same(ikinci));
      expect(okulKaydi([birinci], 'meb_775214'), isNull);
    });
  });
}

