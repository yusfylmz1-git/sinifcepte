# -*- coding: utf-8 -*-
"""`pano_paletleri.py` içindeki paleti Dart kaynağına çevirir.

Çıktı: `lib/features/documents/utils/pano_palette.dart`

Palet iki dilde ayrı ayrı yazılırsa zamanla ayrışır: Python'da düzeltilen
bir renk Dart'ta eski kalır ve fark ancak baskıda görülür. Tek kaynak
Python tarafıdır; Dart dosyası buradan ÜRETİLİR, elle düzenlenmez.

Kullanım:
    python tool/build_pano_palet_dart.py
"""
import os
import sys
import io

from pano_paletleri import PALET, VARSAYILAN, dogrula, luma

BURASI = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(BURASI)
HEDEF = os.path.join(PROJE, 'lib', 'features', 'documents', 'utils',
                     'pano_palette.dart')

BASLIK = '''// ÜRETİLMİŞ DOSYA — elle düzenlemeyin.
// Kaynak: tool/pano_paletleri.py
// Yeniden üretmek için: python tool/build_pano_palet_dart.py
//
// Belirli günlere özel pano paletleri.
//
// ## Neden gri değerleri yazılı
//
// Öğretmenlerin çoğu okulda siyah-beyaz yazıcı kullanıyor. Her palet bu
// yüzden sabit bir "gri merdivene" oturuyor:
//
//   koyu : gri  42-62   beyaz metin taşır  — başlık bandı
//   orta : gri  92-118  beyaz metin taşır  — vurgu bandı
//   acik : gri 200-228  siyah metin taşır  — kart zemini
//
// Merdiven sabit olduğu için hangi gün seçilirse seçilsin s/b çıktıda
// hiyerarşi aynı okunur. Renk değişir, kontrast düzeni değişmez.
//
// Ölçütler `tool/pano_paletleri.py` içindeki dogrula() ile denetlenir;
// palet bozulursa veri üretimi durur.

import 'package:pdf/pdf.dart';

/// Bir günün pano paleti — üç basamak.
class PanoPalette {
  /// Başlık bandı. Beyaz metin taşır.
  final PdfColor koyu;

  /// Vurgu bandı, kart başlığı. Beyaz metin taşır.
  final PdfColor orta;

  /// Kart zemini, doldurma alanı. Siyah metin taşır.
  final PdfColor acik;

  /// Rengin neden seçildiği — sonradan değiştiren keyfî sanmasın.
  final String tema;

  const PanoPalette({
    required this.koyu,
    required this.orta,
    required this.acik,
    required this.tema,
  });

  /// Günün paleti; tanımlı değilse nötr varsayılan.
  ///
  /// Ad, `belirli_gun_hafta.json` içindeki adla birebir eşleşmeli.
  static PanoPalette of(String gunAdi) => _paletler[gunAdi] ?? varsayilan;
'''


def _dart_renk(hx):
    return 'PdfColor.fromInt(0x%s)' % ('FF' + hx.lstrip('#').upper())


def main():
    sorunlar = dogrula()
    if sorunlar:
        print('Palet doğrulamadan geçmedi, Dart üretilmedi:')
        for s in sorunlar:
            print('  -', s)
        raise SystemExit(1)

    p = []
    p.append(BASLIK)

    # varsayılan
    p.append('')
    p.append('  /// Palete girmemiş günler için nötr palet.')
    p.append('  static const varsayilan = PanoPalette(')
    p.append('    koyu: %s,' % _dart_renk(VARSAYILAN['koyu']))
    p.append('    orta: %s,' % _dart_renk(VARSAYILAN['orta']))
    p.append('    acik: %s,' % _dart_renk(VARSAYILAN['acik']))
    p.append("    tema: '%s'," % VARSAYILAN['tema'].replace("'", r"\'"))
    p.append('  );')
    p.append('')
    p.append('  static const Map<String, PanoPalette> _paletler = {')

    for ad, v in PALET.items():
        gk, go, ga = (round(luma(v[r])) for r in ('koyu', 'orta', 'acik'))
        p.append("    // gri %d / %d / %d" % (gk, go, ga))
        p.append("    '%s': PanoPalette(" % ad.replace("'", r"\'"))
        p.append('      koyu: %s,' % _dart_renk(v['koyu']))
        p.append('      orta: %s,' % _dart_renk(v['orta']))
        p.append('      acik: %s,' % _dart_renk(v['acik']))
        p.append("      tema: '%s'," % v['tema'].replace("'", r"\'"))
        p.append('    ),')

    p.append('  };')
    p.append('}')
    p.append('')

    metin = '\n'.join(p)
    with io.open(HEDEF, 'w', encoding='utf-8', newline='\n') as f:
        f.write(metin)

    print('%d palet + varsayılan -> %s' % (len(PALET), HEDEF))
    print('%d satır' % metin.count('\n'))


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
