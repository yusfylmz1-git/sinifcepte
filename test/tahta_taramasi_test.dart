import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/ogretmen_tahta_deposu.dart';
import 'package:sinifcepte/features/board_config/utils/tahta_taramasi.dart';

/// "Tahtadaki QR'ı Okut" düğmesiyle okunan karekodun yorumu.
///
/// Cihazda (1 Ekim 2026): öğretmen Ana Program'ın tanımlama karekodunu
/// bu düğmeyle okuttu ve "Bu QR bir SınıfCepte tahtasına ait değil"
/// gördü; tanımlama düğmesi telefon tanımlıyken ekranda yoktu.
void main() {
  const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
  const mevcut = OgretmenTahtaKaydi(
    okulId: 'meb_16_123456',
    kod: 'YUSUFYILMA',
    ad: 'Yusuf YILMAZ',
    totpSecret: secret,
  );

  // Ana Program'ın ürettiği biçim (`ana_program/cekirdek/ogretmen.py`).
  const anaProgramKurulumu = 'SCT1:meb_16_123456:YYILMAZ:Yusuf YILMAZ:'
      'KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU';

  test('tahtanın kilit ekranı karekodu (SC1 ve SC2) tahta sayılıyor', () {
    expect(
      tahtaTaramasiniYorumla('SC1:meb_16_123456:tahta_8B:3b9aca0:62500000', mevcut),
      TahtaTaramasi.tahta,
    );
    expect(
      tahtaTaramasiniYorumla(
          'SC2:meb_16_123456:tahta_8B:3b9aca0:62500000:192.168.1.150:8443', mevcut),
      TahtaTaramasi.tahta,
    );
  });

  test('KRITIK: başka bir tanımlama karekodu "ait değil" denmeden tanınıyor', () {
    expect(tahtaTaramasiniYorumla(anaProgramKurulumu, mevcut), TahtaTaramasi.kurulumYeni);
  });

  test('telefondaki tanımın kendi karekodu "zaten kayıtlı" sayılıyor', () {
    expect(
      tahtaTaramasiniYorumla('SCT1:meb_16_123456:YUSUFYILMA:Yusuf YILMAZ:$secret', mevcut),
      TahtaTaramasi.kurulumAyni,
    );
  });

  test('KRITIK: aynı kod ama YENİ secret → yeni tanım (eski secret kalmasın)', () {
    expect(
      tahtaTaramasiniYorumla(
          'SCT1:meb_16_123456:YUSUFYILMA:Yusuf YILMAZ:KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU',
          mevcut),
      TahtaTaramasi.kurulumYeni,
    );
  });

  test('ilgisiz karekod tanımsız', () {
    for (final ham in ['https://eba.gov.tr', 'SCT1:eksik:alan', '', 'SC1:a:b']) {
      expect(tahtaTaramasiniYorumla(ham, mevcut), TahtaTaramasi.tanimsiz, reason: ham);
    }
  });
}
