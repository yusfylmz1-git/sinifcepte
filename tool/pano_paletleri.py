# -*- coding: utf-8 -*-
"""Belirli günlere özel pano paletleri — SİYAH-BEYAZ BASKI ÖNCE.

## Neden böyle bir dosya var

Öğretmenlerin çoğu okulda siyah-beyaz yazıcı kullanıyor. Renk seçerken
sorulacak soru "güzel mi" değil, "gri tonuna düşünce ayırt edilebiliyor
mu". Ölçmeden seçilen renk s/b çıktıda çöküyor.

Ölçtük: eski palette `bordo` (luma 58) ile `lacivert` (luma 54) gri
tonunda neredeyse aynıydı — panonun iki ana rengi tek renge düşüyordu.
`altin` (luma 167) üstündeki beyaz metnin kontrastı 2.4:1'di; okunmuyordu.

## Kural — gri merdiven

Her günün kendi rengi var, ama her rol sabit bir luma bandına oturuyor:

    koyu : luma  42-62   beyaz metin taşır  — başlık bandı, künye
    orta : luma  92-118  beyaz metin taşır  — vurgu bandı, kart başlığı
    acik : luma 200-228  siyah metin taşır  — kart zemini, doldurma alanı

Merdiven sabit olduğu için hangi gün seçilirse seçilsin s/b çıktıda
hiyerarşi aynı okunur. Renk değişir, kontrast düzeni değişmez.

Doğrulama `dogrula()` ile yapılır; `build_pano_dataset.py` bunu
üretim sırasında çağırır ve palet bozulmuşsa üretimi durdurur.
"""

# Gri merdivenin hedef bantları. Değiştirilirse dogrula() yeniden çalışır.
BANT = {
    'koyu': (42, 62),
    'orta': (92, 118),
    'acik': (200, 228),
}

# Beyaz metin koyu/orta üstünde en az bu kontrastı taşımalı (s/b baskıda).
MIN_BEYAZ_KONTRAST = 4.5
# Siyah metin açık zemin üstünde.
MIN_SIYAH_KONTRAST = 7.0
# koyu ile orta arasındaki luma farkı — bantlar birbirine girmesin.
MIN_AYRIM = 40

# ---------------------------------------------------------------------
# 20 gün. Renk günün konusundan geliyor; luma değerleri ölçülerek seçildi.
# `tema` alanı neden o rengin seçildiğini kaydeder — sonradan değiştiren
# kişi keyfî sanmasın.
# ---------------------------------------------------------------------
PALET = {
    'Ulusal Egemenlik ve Çocuk Bayramı': {
        'tema': 'bayrak kırmızısı, çocuk neşesi — saf ton',
        'koyu': '#800B0F', 'orta': '#F02228', 'acik': '#EDD3D4'},

    'Cumhuriyet Bayramı': {
        'tema': 'bayrak kırmızısı, ağırbaşlı — hafif morumsu',
        'koyu': '#780D1B', 'orta': '#E0243D', 'acik': '#EDD3D7'},

    'Zafer Bayramı': {
        'tema': 'zafer — turuncumsu kırmızı, askerî sıcaklık',
        'koyu': '#731308', 'orta': '#DB2E1A', 'acik': '#EDD6D3'},

    'Şehitler Günü': {
        'tema': 'anma — soluk bordo, düşük doygunluk',
        'koyu': '#4A2320', 'orta': '#914B46', 'acik': '#EDD5D3'},

    '15 Temmuz Demokrasi ve Millî Birlik Günü': {
        'tema': 'millî birlik — gece kırmızısı',
        'koyu': '#6E1023', 'orta': '#D12A4B', 'acik': '#EDD3D8'},

    'Kızılay Haftası': {
        'tema': 'kızılay — kırmızı hilal, temiz ton',
        'koyu': '#820B07', 'orta': '#F72019', 'acik': '#EDD4D3'},

    'Atatürk Haftası': {
        'tema': 'anma — koyu gri-mavi',
        'koyu': '#26323F', 'orta': '#5A6B7D', 'acik': '#DDE3E9'},

    "Atatürk'ü Anma ve Gençlik ve Spor Bayramı": {
        'tema': 'gençlik — canlı turkuaz',
        'koyu': '#0B4F52', 'orta': '#12888D', 'acik': '#D3E9EA'},

    "İstiklâl Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü": {
        'tema': 'şiir — mürekkep laciverti',
        'koyu': '#1E2F52', 'orta': '#4E6494', 'acik': '#DBE1EC'},

    'Öğretmenler Günü': {
        'tema': 'kara tahta yeşili + tebeşir',
        'koyu': '#1F3A2C', 'orta': '#4F7A62', 'acik': '#DCE7E0'},

    'Tutum, Yatırım ve Türk Malları Haftası': {
        'tema': 'tasarruf — kumbara mavisi',
        'koyu': '#1B3A52', 'orta': '#3E7396', 'acik': '#DAE4EC'},

    'Enerji Tasarrufu Haftası': {
        'tema': 'enerji — amber, ampul',
        'koyu': '#4A3410', 'orta': '#9C7220', 'acik': '#EDE3CC'},

    'Yeşilay Haftası': {
        'tema': 'yeşilay — sağlık yeşili',
        'koyu': '#14402A', 'orta': '#2E7D53', 'acik': '#D8E8DF'},

    'Bilim ve Teknoloji Haftası': {
        'tema': 'bilim — mor/indigo',
        'koyu': '#312075', 'orta': '#6446DB', 'acik': '#DDD8F2'},

    'Orman Haftası': {
        'tema': 'orman — koyu yeşil',
        'koyu': '#1B3D1E', 'orta': '#3F7A43', 'acik': '#DBE8DC'},

    'Engelliler Haftası': {
        'tema': 'erişilebilirlik — mavi',
        'koyu': '#123A5C', 'orta': '#2E76A8', 'acik': '#D8E5EE'},

    'Trafik ve İlkyardım Haftası': {
        'tema': 'trafik — uyarı turuncusu',
        'koyu': '#5A2A0C', 'orta': '#B85A18', 'acik': '#F0DFD1'},

    'Çevre Koruma Haftası': {
        'tema': 'çevre — yaprak yeşili',
        'koyu': '#17402F', 'orta': '#357F5C', 'acik': '#D9E8E1'},

    'Dünya Çocuk Hakları Günü': {
        'tema': 'çocuk hakları — BM mavisi',
        'koyu': '#153C63', 'orta': '#3878B0', 'acik': '#D9E5EF'},

    'İlköğretim Haftası': {
        'tema': 'okul — defter mavisi',
        'koyu': '#1D3557', 'orta': '#45709E', 'acik': '#DCE3EC'},
}

# Palete girmemiş bir gün için — nötr, her konuya oturur.
VARSAYILAN = {
    'tema': 'nötr — palete girmemiş günler',
    'koyu': '#2B3440', 'orta': '#5C6B7A', 'acik': '#DEE3E8',
}


# ---------------------------------------------------------------------
# Ölçüm
# ---------------------------------------------------------------------
def _rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def luma(h):
    """ITU-R BT.601 — yazıcı sürücülerinin yaygın gri dönüşümü. 0-255."""
    r, g, b = _rgb(h)
    return 0.299 * r + 0.587 * g + 0.114 * b


def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _rel(h):
    r, g, b = _rgb(h)
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def kontrast(h1, h2):
    a, b = _rel(h1), _rel(h2)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def gri_kontrast(h1, h2):
    """Gri tonuna düştükten SONRAKİ kontrast — asıl ölçüt bu."""
    g1 = '#%02X%02X%02X' % ((round(luma(h1)),) * 3)
    g2 = '#%02X%02X%02X' % ((round(luma(h2)),) * 3)
    return kontrast(g1, g2)


def paletAl(gun_adi):
    """Günün paleti; tanımlı değilse nötr varsayılan."""
    return PALET.get(gun_adi, VARSAYILAN)


def dogrula(yaz=False):
    """Tüm paletleri s/b baskı ölçütlerine göre denetler.

    Sorun listesi döner; boşsa palet sağlam.
    """
    sorunlar = []
    for ad, p in list(PALET.items()) + [('(varsayılan)', VARSAYILAN)]:
        L = {rol: round(luma(p[rol])) for rol in ('koyu', 'orta', 'acik')}

        for rol, (lo, hi) in BANT.items():
            if not (lo <= L[rol] <= hi):
                sorunlar.append(
                    '%s: %s luma %d, hedef %d-%d' % (ad, rol, L[rol], lo, hi))

        kb_koyu = gri_kontrast(p['koyu'], '#FFFFFF')
        kb_orta = gri_kontrast(p['orta'], '#FFFFFF')
        ks_acik = gri_kontrast(p['acik'], '#111111')
        ayrim = abs(L['koyu'] - L['orta'])

        if kb_koyu < MIN_BEYAZ_KONTRAST:
            sorunlar.append('%s: koyu üstünde beyaz metin %.1f:1' % (ad, kb_koyu))
        if kb_orta < MIN_BEYAZ_KONTRAST:
            sorunlar.append('%s: orta üstünde beyaz metin %.1f:1' % (ad, kb_orta))
        if ks_acik < MIN_SIYAH_KONTRAST:
            sorunlar.append('%s: açık üstünde siyah metin %.1f:1' % (ad, ks_acik))
        if ayrim < MIN_AYRIM:
            sorunlar.append('%s: koyu-orta ayrımı %d' % (ad, ayrim))

        if yaz:
            print('%-52s %s(%3d) %s(%3d) %s(%3d)  bk %4.1f/%4.1f  sk %5.1f  ayrım %3d'
                  % (ad[:52], p['koyu'], L['koyu'], p['orta'], L['orta'],
                     p['acik'], L['acik'], kb_koyu, kb_orta, ks_acik, ayrim))
    return sorunlar


if __name__ == '__main__':
    import sys, io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    print('=' * 104)
    print('PANO PALETLERİ — siyah-beyaz baskı doğrulaması')
    print('=' * 104)
    s = dogrula(yaz=True)
    print()
    if s:
        print('%d SORUN:' % len(s))
        for x in s:
            print('  -', x)
        sys.exit(1)
    print('%d palet, hepsi geçti.' % (len(PALET) + 1))
