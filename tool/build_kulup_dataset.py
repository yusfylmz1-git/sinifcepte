# -*- coding: utf-8 -*-
"""Sosyal kulup veri paketini uretir.

Cikti: `assets/data/kulup_planlari.json.gz`

Kazanim, rehberlik ve pano paketleriyle ayni mantik: veri TEK
SCRIPTTEN uretilir, APK ile tasinir, Firestore'a cikmaz.

## Kullanim
    python tool/build_kulup_dataset.py

## Kaynak
Kulup adlari MEB Ogrenci Kulupleri Cizelgesi'nden (EK-4,
Degisik: RG-18/1/2023-32077) alinmistir — 52 kulup. Plan metinleri
`kulup_icerikleri.py` icinde bu projede yazilmistir.

Yonetmelik MADDE 8/1 uyarinca okullar cizelge disinda da kulup
kurabilir; bu yuzden uygulama tarafinda "diger" secenegi acik
birakilir, paket yalnizca hazir icerigi tasir.
"""
import os
import sys
import json
import gzip

sys.stdout.reconfigure(encoding='utf-8')

BURASI = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(BURASI)
sys.path.insert(0, BURASI)

import kulup_icerikleri as icerik  # noqa: E402

CIKTI = os.path.join(PROJE, 'assets', 'data', 'kulup_planlari.json.gz')

# Paket surumu: icerik degisince artir. Dart tarafi bunu okuyup
# onbellegi tazeler.
SURUM = 1


def dogrula(kulupler):
    """Paket yazilmadan once icerigi denetler.

    Bozuk veri APK'ya girerse kullanicida fark edilir; burada
    yakalamak ucuz.
    """
    hata = []

    numaralar = [k['no'] for k in kulupler]
    eksik = [n for n in range(1, 53) if n not in numaralar]
    if eksik:
        hata.append(f'EK-4 numarasi eksik: {eksik}')

    for alan in ('kod', 'ad'):
        degerler = [k[alan] for k in kulupler]
        tekrar = {d for d in degerler if degerler.count(d) > 1}
        if tekrar:
            hata.append(f'tekrar eden {alan}: {sorted(tekrar)}')

    for k in kulupler:
        if len(k['plan']) != 10:
            hata.append(f"{k['ad']}: {len(k['plan'])} ay (10 olmali)")
        aylar = [p['ay'] for p in k['plan']]
        if aylar != icerik.AYLAR:
            hata.append(f"{k['ad']}: ay sirasi bozuk")
        for p in k['plan']:
            if not p['amac'].strip() or not p['etkinlik'].strip():
                hata.append(f"{k['ad']} / {p['ay']}: bos alan")

    if hata:
        for h in hata:
            print('HATA:', h)
        raise SystemExit('paket yazilmadi')


def main():
    kulupler = icerik.KULUPLER
    dogrula(kulupler)

    paket = {
        'surum': SURUM,
        'kaynak': 'MEB Ogrenci Kulupleri Cizelgesi (EK-4), '
                  'RG-18/1/2023-32077',
        'aylar': icerik.AYLAR,
        'kulupler': kulupler,
    }

    ham = json.dumps(paket, ensure_ascii=False, separators=(',', ':'))
    os.makedirs(os.path.dirname(CIKTI), exist_ok=True)
    # mtime=0: ayni icerik ayni ciktiyi versin, git'te sahte fark olmasin
    with gzip.GzipFile(CIKTI, 'wb', mtime=0) as f:
        f.write(ham.encode('utf-8'))

    blok = sum(len(k['plan']) for k in kulupler)
    print(f'kulup     : {len(kulupler)}')
    print(f'plan blogu: {blok}')
    print(f'ham       : {len(ham) / 1024:.1f} KB')
    print(f'sikistirmis: {os.path.getsize(CIKTI) / 1024:.1f} KB')
    print(f'cikti     : {CIKTI}')


if __name__ == '__main__':
    main()
