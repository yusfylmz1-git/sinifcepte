# -*- coding: utf-8 -*-
"""MEB Belirli Gün ve Haftalar çizelgesini JSON'a çıkarır.

Kaynak: MEB Talim ve Terbiye Kurulu "Belirli Gün ve Haftalar Çizelgesi"
(il/ilçe MEM sitelerinde yayımlanan resmî PDF).

Çıktı `assets/data/belirli_gun_hafta.json.gz` içine gömülür.

## Tarih türleri
Çizelgede üç farklı anlatım var, üçü de ayrı ele alınır:
  * SABIT   — "23 Nisan", "10 Kasım"      -> gün + ay
  * ARALIK  — "10-16 Kasım", "8-12 Ekim"  -> baş/bitiş günü + ay
  * KURAL   — "Eylül ayının 3. haftası", "Mayıs ayının 2. pazarı"
              -> serbest metin; takvim yılına göre hesaplanamaz,
                 olduğu gibi gösterilir.
Kural tipini uydurup yanlış tarih üretmektense metni göstermek doğru.
"""
import sys, re, os, json, gzip, unicodedata

sys.stdout.reconfigure(encoding='utf-8')
import pypdf

BURASI = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(BURASI)

AYLAR = {
    'ocak': 1, 'şubat': 2, 'mart': 3, 'nisan': 4, 'mayıs': 5, 'haziran': 6,
    'temmuz': 7, 'ağustos': 8, 'eylül': 9, 'ekim': 10, 'kasım': 11,
    'aralık': 12,
}
# Öğretim yılı sırası: Eylül'den başlar.
OGRETIM_SIRASI = [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8]


def nrm(t):
    return unicodedata.normalize('NFC', t or '')


def ayNo(ad):
    return AYLAR.get(ad.strip().lower())


# Okulda ETKINLIK/PANO calismasi yapilan gunler.
#
# Cizelgedeki 60 maddenin hepsi icin pano hazirlanmaz; "Dunya Fikri
# Mulkiyet Gunu" anilir ama siniflar tore hazirlamaz. Bu liste,
# ogretmenin fiilen calisma yaptigi gunleri isaretler.
ETKINLIKLI = {
    'Cumhuriyet Bayramı',
    'Atatürk Haftası',
    'Öğretmenler Günü',
    "İstiklâl Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü",
    'Şehitler Günü',
    'Ulusal Egemenlik ve Çocuk Bayramı',
    "Atatürk'ü Anma ve Gençlik ve Spor Bayramı",
    '15 Temmuz Demokrasi ve Millî Birlik Günü',
    'Zafer Bayramı',
    'İlköğretim Haftası',
    'Kızılay Haftası',
    'Tutum, Yatırım ve Türk Malları Haftası',
    'Enerji Tasarrufu Haftası',
    'Yeşilay Haftası',
    'Bilim ve Teknoloji Haftası',
    'Orman Haftası',
    'Engelliler Haftası',
    'Trafik ve İlkyardım Haftası',
    'Çevre Koruma Haftası',
    'Dünya Çocuk Hakları Günü',
}


def ayristir(satir):
    """Bir çizelge satırını yapılandırır."""
    s = re.sub(r'\s+', ' ', satir).strip()
    if not s or s.startswith('*') or 'Çizelgesi' in s:
        return None

    # Parantez içi tarih açıklaması
    m = re.match(r'^(.*?)\s*\(([^)]*)\)\s*$', s)
    if not m:
        return None
    ad, tarih = m.group(1).strip(), m.group(2).strip()
    if not ad:
        return None

    kayit = {'ad': ad, 'tarihMetni': tarih, 'tur': 'kural',
             'ay': None, 'baslangicGun': None, 'bitisGun': None,
             'etkinlikli': ad in ETKINLIKLI}

    # ARALIK: "10-16 Kasım" | "29 Ekim-4 Kasım" | "8-12 Ekim"
    a = re.match(r'^(\d{1,2})\s*[-–]\s*(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)$',
                 tarih)
    if a:
        kayit.update(tur='aralik', ay=ayNo(a.group(3)),
                     baslangicGun=int(a.group(1)), bitisGun=int(a.group(2)))
        return kayit

    # ARALIK, iki aya yayılan: "29 Ekim-4 Kasım"
    a2 = re.match(
        r'^(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)\s*[-–]\s*'
        r'(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)$', tarih)
    if a2:
        kayit.update(tur='aralik', ay=ayNo(a2.group(2)),
                     baslangicGun=int(a2.group(1)),
                     bitisGun=int(a2.group(3)))
        kayit['bitisAy'] = ayNo(a2.group(4))
        return kayit

    # SABIT: "23 Nisan"
    t = re.match(r'^(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)$', tarih)
    if t and ayNo(t.group(2)):
        kayit.update(tur='sabit', ay=ayNo(t.group(2)),
                     baslangicGun=int(t.group(1)))
        return kayit

    # KURAL: ay adı geçiyorsa sıralama için ayı yakala
    for ad_ay, no in AYLAR.items():
        if ad_ay in tarih.lower():
            kayit['ay'] = no
            break
    return kayit


def main():
    yol = os.path.join(BURASI, '_kaynak_belirli_gun.pdf')
    r = pypdf.PdfReader(yol)
    ham = '\n'.join(nrm(p.extract_text()) for p in r.pages)

    kayitlar = []
    for satir in ham.split('\n'):
        k = ayristir(satir)
        if k:
            kayitlar.append(k)

    # 15 Temmuz çizelgede PARANTEZSİZ ve yıldızlı geçiyor:
    #   "15 Temmuz Demokrasi ve Millî Birlik Günü *"
    #   "* Ders yılının başladığı 2. hafta içerisinde anma programları
    #    uygulanır."
    # Parantez aramayan ayrıştırıcıya takılmıyor; elle eklenir.
    if not any('15 Temmuz' in k['ad'] for k in kayitlar):
        kayitlar.append({
            'ad': '15 Temmuz Demokrasi ve Millî Birlik Günü',
            'tarihMetni': 'Ders yılının 2. haftasında anma programı',
            'tur': 'kural',
            'ay': 9,
            'baslangicGun': None,
            'bitisGun': None,
            'etkinlikli': True,
        })

    # Öğretim yılı sırasına diz
    def anahtar(k):
        ay = k['ay'] or 13
        i = OGRETIM_SIRASI.index(ay) if ay in OGRETIM_SIRASI else 99
        return (i, k['baslangicGun'] or 99)

    kayitlar.sort(key=anahtar)

    tur = {}
    for k in kayitlar:
        tur[k['tur']] = tur.get(k['tur'], 0) + 1
    print(f'madde: {len(kayitlar)}  tur dagilimi: {tur}')
    aysiz = [k['ad'] for k in kayitlar if k['ay'] is None]
    if aysiz:
        print('ay cozulemeyen:', aysiz)

    paket = {'surum': 1, 'kaynak': 'MEB Belirli Gün ve Haftalar Çizelgesi',
             'maddeler': kayitlar}
    hedef = os.path.join(PROJE, 'assets', 'data', 'belirli_gun_hafta.json.gz')
    veri = json.dumps(paket, ensure_ascii=False,
                      separators=(',', ':')).encode('utf-8')
    with gzip.open(hedef, 'wb', compresslevel=9) as f:
        f.write(veri)
    print(f'ham {len(veri)} B -> gzip {os.path.getsize(hedef)} B')
    print(hedef)
    print()
    for k in kayitlar[:8]:
        print(f"  {k['tur']:7s} ay={str(k['ay']):>4s} {k['ad'][:44]:46s} {k['tarihMetni'][:26]}")


if __name__ == '__main__':
    main()
