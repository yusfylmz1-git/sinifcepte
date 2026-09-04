# -*- coding: utf-8 -*-
"""Pano içeriğini yayın öncesi denetler.

`PANO_ICERIK_KURALLARI.md` içindeki kuralların makine tarafından
kontrol edilebilenleri. `build_pano_dataset.py` üretim sırasında
çağırır; ihlal varsa üretim durur.

Kural belgesi tek başına bir şey engellemiyor — denetim burada.
"""
import re
import datetime

# "4-A", "2/B", "6 - C" gibi şube adları. Panoyu tek sınıfa kilitler.
SUBE = re.compile(r'\b\d\s*[-/]\s*[A-ZÇĞİÖŞÜ]\b')

# "2026-2027" gibi öğretim yılı sabitleri. İçerik her yıl kullanılır.
YIL_ARALIGI = re.compile(r'\b20\d\d\s*[-/]\s*20\d\d\b')

# Pano dörtlüğünde bir mısranın en fazla uzunluğu.
#
# Şiir kartı ~262 punto genişliğinde, 12.5 punto yazı. Bu ölçüde satıra
# yaklaşık 42 karakter sığıyor; fazlası alt satıra kırılıyor ve şiirin
# ölçüsü bozuluyor.
MISRA_SINIR = 42

# Metin taşımayan, denetime girmeyecek alanlar.
ATLA = {'kaynak', 'duzey', 'sure', 'mekan', 'hazirlik', 'tip', 'ton',
        'malzemesiz', 'yil'}


def _metinleri_gez(dugum, yol=''):
    """İç içe yapıdaki tüm metinleri (yol, metin) olarak üretir."""
    if isinstance(dugum, str):
        yield yol, dugum
    elif isinstance(dugum, dict):
        for k, v in dugum.items():
            if k in ATLA:
                continue
            yield from _metinleri_gez(v, '%s.%s' % (yol, k) if yol else k)
    elif isinstance(dugum, list):
        for i, v in enumerate(dugum):
            yield from _metinleri_gez(v, '%s[%d]' % (yol, i))


def denetle(icerikler):
    """İhlal listesi döner; boşsa içerik kurallara uygun."""
    ihlaller = []

    for gun in icerikler:
        ad = gun.get('ad', '(adsız)')

        # --- metin kuralları ---
        for yol, metin in _metinleri_gez(gun):
            # 'kronoloji' içindeki "1919-1922" gibi tarihî aralıklar meşru;
            # yasak olan içinde bulunulan öğretim yılını sabitlemek.
            if YIL_ARALIGI.search(metin):
                simdi = datetime.date.today().year
                for m in YIL_ARALIGI.findall(metin):
                    ilk = int(re.match(r'(20\d\d)', m).group(1))
                    if ilk >= simdi - 5:
                        ihlaller.append(
                            '%s → %s: öğretim yılı sabitlenmiş (%s)'
                            % (ad, yol, m))

            if SUBE.search(metin):
                ihlaller.append(
                    '%s → %s: şube adı geçiyor (%s)'
                    % (ad, yol, SUBE.search(metin).group(0)))

        # --- yapı kuralları ---
        # Havuz şemasına geçmiş günlerde en az bir hazırlıksız etkinlik
        # bulunmalı. Etiket taşımayan eski kayıtlar bu kuralın dışında —
        # onlar henüz yeni şemaya taşınmamış demektir, ayrı iş.
        etkinlikler = gun.get('etkinlikler', [])
        etiketli = [e for e in etkinlikler if 'hazirlik' in e]
        if etiketli and not any(e.get('hazirlik') == 'yok' for e in etiketli):
            ihlaller.append(
                '%s: hazırlık istemeyen etkinlik yok — fotokopi/malzeme '
                'bulamayan öğretmen bu günü uygulayamaz' % ad)

        # Pano dörtlüğünde mısra uzunluğu.
        #
        # Şiir kartı ~262 punto genişliğinde. Uzun mısra ortadan kırılıp
        # alt satıra taşıyor ve şiir okunmaz hâle geliyor. Ölçüyü baskıda
        # değil burada yakalarız.
        for i, d in enumerate(gun.get('panoDortlukler', [])):
            for misra in d.get('metin', '').split('\n'):
                if len(misra) > MISRA_SINIR:
                    ihlaller.append(
                        '%s → panoDortlukler[%d]: mısra %d karakter '
                        '(sınır %d) — pano kartında satır kırılır: "%s"'
                        % (ad, i, len(misra), MISRA_SINIR, misra[:50]))

        # kaynak alanı dürüst mü
        k = gun.get('kaynak')
        if k not in ('meb', 'genel'):
            ihlaller.append('%s: kaynak alanı "%s" — meb veya genel olmalı'
                            % (ad, k))

    return ihlaller


if __name__ == '__main__':
    import sys, io, os, gzip, json
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

    proje = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    yol = os.path.join(proje, 'assets', 'data', 'pano_icerikleri.json.gz')
    with gzip.open(yol, 'rt', encoding='utf-8') as f:
        paket = json.load(f)

    print('=' * 72)
    print('PANO İÇERİK DENETİMİ —', len(paket['icerikler']), 'gün')
    print('=' * 72)
    ihlaller = denetle(paket['icerikler'])
    if ihlaller:
        for x in ihlaller:
            print('  -', x)
        print()
        print('%d ihlal' % len(ihlaller))
        sys.exit(1)
    print('Temiz.')
