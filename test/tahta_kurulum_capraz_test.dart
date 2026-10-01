/// Ana Program'ın (Python) ürettiği öğretmen kurulum karekodunu telefon
/// okuyabiliyor mu?
///
/// ## Neden bu dosya var
///
/// Python tarafının testi telefonun ayrıştırıcısını Python'da yeniden
/// yazarak sınıyordu. Biri değişip kopyası değişmezse iki tarafın
/// testleri de geçer ve sahada "karekod tanınmadı" çıkar (hafıza: "tel
/// biçimi sınanmamış katman").
///
/// ## Aşağıdaki dizeler elle yazılmadı
///
/// `sinifcepte-tahta` deposunda üretildiler (1 Ekim 2026):
///
/// ```
/// python -c "from ana_program.cekirdek.ogretmen import kurulum_qr_yuku as k; \
///   print(k(okul_id='meb_775214', kod='YYILMAZ', ad='Yusuf Yılmaz', \
///     secret='KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU', \
///     okul_adi='Mimar Sinan Ortaokulu'))"
/// ```
///
/// Python tarafı biçimi değiştirirse bu testler kırılır — ve kırılması
/// gerekir: telefon o karekodu okuyamayacak demektir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/board_config/data/ogretmen_tahta_deposu.dart';

/// `okul_adi='Mimar Sinan Ortaokulu'`
const _anaProgram = 'SCT1:meb_775214:YYILMAZ:Yusuf Yilmaz:'
    'KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU:Mimar Sinan Ortaokulu';

/// `okul_adi='Şehit Öğretmen: İlkokulu'` (Türkçe harf ve iki nokta)
const _anaProgramTurkce = 'SCT1:meb_123456:YYILMAZ:Yusuf Yilmaz:'
    'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ:Sehit Ogretmen Ilkokulu';

/// Okul adı verilmeden (eski biçim, 5 alan).
const _anaProgramOkulAdsiz =
    'SCT1:meb_775214:YYILMAZ:Yusuf Yilmaz:KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU';

void main() {
  test('KRİTİK: okul adlı karekod ayrıştırılıyor', () {
    final k = OgretmenTahtaDeposu.qrAyristir(_anaProgram)!;
    expect(k.okulId, 'meb_775214');
    expect(k.kod, 'YYILMAZ');
    expect(k.ad, 'Yusuf Yilmaz');
    expect(k.totpSecret, 'KRSXG5CTMVRXEZLUKRSXG5CTMVRXEZLU');
    expect(k.okulAdi, 'Mimar Sinan Ortaokulu');
  });

  test('Türkçe harfli ve iki noktalı okul adı alanları kaydırmıyor', () {
    final k = OgretmenTahtaDeposu.qrAyristir(_anaProgramTurkce)!;
    expect(k.totpSecret, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(k.okulAdi, 'Sehit Ogretmen Ilkokulu');
  });

  test('okul adsız (eski) biçim hâlâ okunuyor', () {
    final k = OgretmenTahtaDeposu.qrAyristir(_anaProgramOkulAdsiz)!;
    expect(k.okulAdi, isEmpty);
    expect(k.okulGorunenAdi, 'Kurum kodu 775214');
  });
}
