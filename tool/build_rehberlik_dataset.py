# -*- coding: utf-8 -*-
"""Sinif rehberlik veri paketini uretir: plan + etkinlik tek JSON.

Cikti: `assets/data/sinif_rehberlik_plani.json.gz` (~500 KB)
Kazanim paketiyle ayni mantik: veri TEK SCRIPTTEN uretilir, APK ile
tasinir, Firestore'a cikmaz.

## Kaynaklar
1. Sinif rehberlik planlari (13 xlsx) — okul oncesi + 1-12. sinif.
   MEB il/ilce sitelerinden yayimlanir, ogretim yili basinda yenilenir.
2. ORGM sinif rehberlik etkinlikleri (4 pdf, ~147 MB):
   orgm.meb.gov.tr/meb_iys_dosyalar/2025_02/
     14142217_okuloncesisinifrehberliketkinlikleri.pdf
     14142148_ilokulsinifrehberliketkinlikleri.pdf
     14142433_ortaokulsinifrehberliketkinlikleri.pdf
     14142542_ortaogretimsinifrehberliketkinlikleri.pdf

## Kullanim
    pip install pypdf openpyxl
    python tool/build_rehberlik_dataset.py [kaynak_klasoru]

Kaynak klasoru verilmezse `~/Downloads` kullanilir; pdf'ler ayni
klasorde `etk_*.pdf` adiyla aranir.

## Ayristirma tuzaklari (hepsi yasandi, geri gelmesin)
* Etkinlik imzasi GEVSEK aranirsa devam sayfalari da yakalanir —
  ortaokulda 98 sahte etkinlik cikmisti. Imza baslik blogunda
  PES PESE olmali.
* Sinif ve hafta yazimi tutarsiz: "5. Sınıf" ile "6.sınıf",
  "/ 1. Hafta" ile "/4.hafta" ve "(25.Hafta)" ayni belgede.
* Sinif duzeyi sayfa genelinde aranmamali; surec metninde de
  "5. Sınıf" geciyor. 'Sınıf Düzeyi' etiketinden sonraki ilk
  eslesme dogru.
* Etkinlik adi ortaokulda tablonun USTUNDE, ortaogretimde ALTINDA.
* Arac-gerec ile surec ayni metin blogunda; "Süreç" etiketi tablo
  hucresi oldugu icin metinde ARADA GECMIYOR. Numaralandirmanin
  basa donmesi kullanilir.
* Excel'de ay sutunu ile HAFTA/TARIH sutunu bitisik DEGIL: metin
  hucresi birlesik (B5:E5), hafta ayri sutunda (F).
"""
import sys, re, os, json, gzip, unicodedata
sys.stdout.reconfigure(encoding='utf-8')
import pypdf, openpyxl

BURASI = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(BURASI)
INDIRILEN = (sys.argv[1] if len(sys.argv) > 1
             else os.path.join(os.path.expanduser('~'), 'Downloads'))

# ---------------------------------------------------------------- ortak

def nrm(t):
    return unicodedata.normalize('NFC', t or '')

def tek(t):
    if not t:
        return ''
    # PDF satir sonu tirelemesi: "duzen-\nlenebilir" tek kelimedir.
    # Kaldirilmazsa metinde "duzen - lenebilir" diye kaliyor.
    t = re.sub(r'(\w)\s*-\s*\n\s*(\w)', r'\1\2', t)
    return re.sub(r'[ \t]+', ' ', re.sub(r'\s*\n\s*', ' ', t)).strip()

def maddeKes(t):
    """Numaralandirma 1'e donunce listeyi boler.

    PDF'te arac-gerecler bitip surec basladiginda "Surec" etiketi
    tablo hucresi oldugu icin metinde ARADA GECMIYOR; tek ipucu
    numaranin 1,2,3 -> 1 diye basa donmesi.
    """
    parca = madde(t)
    if not parca:
        return [], []
    ham = re.sub(r'\s*\n\s*', ' ', t)
    nolar = [int(m.group(1)) for m in
             re.finditer(r'(?:(?<=\s)|^)(\d{1,2})\s*[.\-)]\s+', ' ' + ham)]
    for i in range(1, min(len(nolar), len(parca))):
        if nolar[i] <= nolar[i - 1]:
            return parca[:i], parca[i:]
    return parca, []


def madde(t):
    """'1. ... 2. ...' bicimli metni maddelere ayirir.

    PDF'te madde numarasi kendi satirinda duruyor ("1.\n Oturma...");
    duz metin olarak birakilirsa okunmuyor.
    """
    if not t:
        return []
    t = re.sub(r'(\w)\s*-\s*\n\s*(\w)', r'\1\2', t)
    t = re.sub(r'\s*\n\s*', ' ', t)
    parcalar = re.split(r'(?:(?<=\s)|^)(\d{1,2})\s*[.\-)]\s+', ' ' + t)
    if len(parcalar) <= 1:
        g = tek(t)
        return [g] if g else []
    cikti = []
    for i in range(1, len(parcalar), 2):
        g = tek(parcalar[i + 1]) if i + 1 < len(parcalar) else ''
        g = re.sub(r'\s*-\s*$', '', g)
        if len(g) > 2:
            cikti.append(g)
    return cikti

# ------------------------------------------------------- 1) plan (xlsx)

AYLAR = ['EYLÜL','EKİM','KASIM','ARALIK','OCAK','ŞUBAT',
         'MART','NİSAN','MAYIS','HAZİRAN']

def planKaynaklari():
    yield 0, os.path.join(INDIRILEN, 'Okul-Oncesi-Rehberlik-Plani-2026-2027.xlsx')
    for g in range(1, 13):
        yield g, os.path.join(INDIRILEN, f'{g}-Sinif-Rehberlik-Plani-2026-2027.xlsx')

def planAyristir(yol):
    w = openpyxl.load_workbook(yol)
    s = w[w.sheetnames[0]]

    def hucre(r, c):
        return tek(nrm(str(s.cell(r, c).value))) if s.cell(r, c).value is not None else ''

    def haftaSutunu(bsatir, asutun):
        for c in range(asutun + 1, s.max_column + 1):
            if 'HAFTA' in hucre(bsatir, c).upper():
                return c
        return asutun + 1

    basliklar = []
    for r in range(1, s.max_row + 1):
        for c in range(1, s.max_column + 1):
            if hucre(r, c).upper() in AYLAR:
                basliklar.append((r, c, hucre(r, c).upper()))
    baslikSatirlari = sorted({r for r, _, _ in basliklar})

    kayit = []
    for r, c, ay in basliklar:
        sonra = [x for x in baslikSatirlari if x > r]
        bitis = min(sonra) if sonra else s.max_row + 1
        hc = haftaSutunu(r, c)
        for rr in range(r + 1, bitis):
            metin = hucre(rr, c)
            if not metin:
                continue
            hafta_ham = hucre(rr, hc)
            tatil = 'TATİL' in metin.upper() or 'TATIL' in metin.upper()
            # Bazi kazanimlar yildizla basliyor: "*36- Sinif rehberlik
            # programi etkinliklerine...". Bas kismi es gecilmezse
            # kazanim ayristirilamiyor ve IDARI IS sayiliyordu; bu
            # yuzden 36 kazanimin sonuncusu listede gorunmuyordu.
            m = re.match(r'^[*\s]*(\d+)\s*-\s*(.*)$', metin)
            no = int(m.group(1)) if m else None
            govde = m.group(2).strip() if m else metin
            etk = re.search(r'\(Etkinlik:\s*(.+?)\)\s*$', govde)
            mh = re.search(r'(\d{1,2})\s*\.\s*HAFTA', hafta_ham.upper())
            tarih = re.search(r'\(([^)]+)\)', hafta_ham)
            kayit.append({
                'ay': ay,
                # Planin GERCEK sirasi. Tatillerin hafta numarasi
                # olmadigi icin siralama yalnizca `hafta` ile
                # yapilinca hepsi listenin SONUNA dusuyordu; oysa
                # ara tatil Kasim'da, yariyil Ocak'ta.
                'ayIndex': AYLAR.index(ay) if ay in AYLAR else 99,
                'satirIndex': rr,
                'siraNo': no,
                'hafta': int(mh.group(1)) if mh else None,
                'tarihAraligi': tarih.group(1).strip() if tarih else hafta_ham,
                'kazanim': re.sub(r'\s*\(Etkinlik:.*\)\s*$', '', govde).strip(),
                'etkinlikAdi': etk.group(1).strip() if etk else None,
                'tatilMi': tatil,
                'idariIsMi': no is None and not tatil,
            })
    return kayit

# -------------------------------------------------- 2) etkinlik (pdf)

PDF = [
    ('okuloncesi', 'etk_okuloncesi.pdf'),
    ('ilkokul', 'etk_ilkokul.pdf'),
    ('ortaokul', 'orgm_etkinlik.pdf'),
    ('ortaogretim', 'etk_ortaogretim.pdf'),
]

ETIKET = [
    'Gelişim Alanı', 'Kazanım/Hafta', 'Yeterlik Alanı', 'Sınıf Düzeyi',
    'Süre', 'Uygulayıcı İçin', 'Ön Hazırlık', 'Araç-Gereçler',
    'Araç- Gereçler', 'Süreç', 'Kazanımın', 'Değerlendirilmesi',
    'Uygulayıcıya Not', 'Öğretmene Not', 'Etkinliği Geliştiren',
    'Çalışma Yaprağı', 'Özel gereksinimli',
]

def kes(metin, bas, sonrakiler, kaynak=None):
    i = metin.find(bas)
    if i < 0:
        return ''
    i += len(bas)
    son = len(metin)
    for s in sonrakiler:
        j = metin.find(s, i)
        if 0 <= j < son:
            son = j
    return metin[i:son].strip()

def basligiBul(t):
    """Etkinlik adi: sayfadaki BUYUK HARFLI tek satir.

    Konumu belgeden belgeye degisiyor — ortaokulda tablonun USTUNDE,
    ortaogretimde ALTINDA duruyor. Sadece ilk satirlara bakmak
    ortaogretimde 42 etkinligi adsiz birakmisti; sayfanin tamami
    taranir, ilk uygun satir alinir.
    """
    for satir in t.split('\n')[:60]:
        s = satir.strip()
        if not (3 <= len(s) <= 70):
            continue
        if 'SINIF ETKİNLİKLERİ' in s or 'HAFTA' in s:
            continue
        harf = [k for k in s if k.isalpha()]
        if len(harf) >= 3 and all(k.isupper() for k in harf):
            return tek(s)
    return ''

def etkinlikAyristir():
    cikti = []
    for kademe, dosya in PDF:
        yol = os.path.join(INDIRILEN, dosya)
        if not os.path.exists(yol):
            print(f'! {kademe} yok'); continue
        r = pypdf.PdfReader(yol)
        sayfalar = [nrm(p.extract_text()) for p in r.pages]

        def baslangicMi(t):
            i = t.find('Gelişim Alanı')
            if i < 0 or i > 400:
                return False
            p = t[i:i + 500]
            return 'Yeterlik Alanı' in p and 'Sınıf Düzeyi' in p

        bas = [i for i, t in enumerate(sayfalar) if baslangicMi(t)]
        for n, i in enumerate(bas):
            bitis = bas[n + 1] if n + 1 < len(bas) else len(sayfalar)
            blok = '\n'.join(sayfalar[i:bitis])
            bt = sayfalar[i]
            if 'Etkinlik Geliştirmede Dikkat' in bt:
                continue

            j = bt.find('Sınıf Düzeyi')
            kuyruk = bt[j:j + 400] if j >= 0 else bt
            m = re.search(r'(\d{1,2})\s*\.\s*[Ss]ınıf', kuyruk)
            grade = int(m.group(1)) if m else (0 if re.search(r'Okul\s*Öncesi', kuyruk, re.I) else None)

            # Kademe belgeye gore SINIRLANIR.
            #
            # Okul oncesi belgesindeki bazi etkinlikler metninde
            # "1. Sınıf"/"2. Sınıf" geciriyor; serbest birakilinca bu
            # kayitlar ilkokul etkinlikleriyle ayni hafta'ya dusup
            # cakisiyordu. Belge hangi kademeye aitse kademe odur.
            SINIR = {
                'okuloncesi': (0, 0),
                'ilkokul': (1, 4),
                'ortaokul': (5, 8),
                'ortaogretim': (9, 12),
            }[kademe]
            if grade is None or not (SINIR[0] <= grade <= SINIR[1]):
                grade = SINIR[0] if kademe == 'okuloncesi' else grade
                if grade is None or not (SINIR[0] <= grade <= SINIR[1]):
                    continue

            kh = kes(bt, 'Kazanım/Hafta', ETIKET)
            mh = (re.search(r'[/(]\s*(\d{1,2})\s*\.?\s*[Hh]afta', kh)
                  or re.search(r'\n\s*(\d{1,2})\s*\.\s*HAFTA', bt))
            hafta = int(mh.group(1)) if mh else None
            kazanim = tek(re.sub(r'[/(]\s*\d{1,2}\s*\.?\s*[Hh]afta.*$', '', kh))
            # Kazanim metninin basinda gelisim alani kaliyor
            gelisim = ''
            for g in ('Sosyal Duygusal', 'Akademik', 'Kariyer'):
                if kazanim.startswith(g):
                    gelisim = g
                    kazanim = kazanim[len(g):].strip()
                    break

            # Ozel gereksinim uyarlamalari — BEP baglantisi burada.
            ozel = ''
            mo = re.search(r'Özel gereksinimli öğrenciler için[;:]?', blok)
            if mo:
                kalan = blok[mo.end():]
                kes_i = len(kalan)
                for s in ('Süreç (Uygulama', 'Çalışma Yaprağı', 'Etkinliği Geliştiren'):
                    k = kalan.find(s)
                    if 0 <= k < kes_i:
                        kes_i = k
                ozel = kalan[:kes_i]

            # Arac-gerec ile surec ayni metin blogunda; numaralandirma
            # basa dondugu yerde ayrilir.
            ag_ham = (kes(blok, 'Araç-Gereçler', ['Kazanımın', 'Uygulayıcıya Not', 'Etkinliği Geliştiren'])
                      or kes(blok, 'Araç- Gereçler', ['Kazanımın', 'Uygulayıcıya Not', 'Etkinliği Geliştiren']))
            arac, surec = maddeKes(ag_ham)
            if not surec:
                surec = madde(kes(blok, 'Süreç',
                                  ['Kazanımın', 'Uygulayıcıya Not', 'Etkinliği Geliştiren']))

            not_ham = kes(blok, 'Uygulayıcıya Not', ['Özel gereksinimli', 'Çalışma Yaprağı', 'Etkinliği Geliştiren'])

            cikti.append({
                'kademe': kademe,
                'gradeLevel': grade,
                'hafta': hafta,
                'etkinlikAdi': basligiBul(bt),
                'gelisimAlani': gelisim,
                'yeterlikAlani': tek(kes(bt, 'Yeterlik Alanı', ['Sınıf Düzeyi'])),
                'kazanim': kazanim,
                'sure': tek(kes(bt, 'Süre', ['Uygulayıcı İçin', 'Ön Hazırlık', 'Araç']))[:60],
                'onHazirlik': madde(kes(bt, 'Ön Hazırlık', ['Araç-Gereçler', 'Araç- Gereçler', 'Süreç'])),
                'aracGerecler': arac,
                'surec': surec,
                'degerlendirme': tek(kes(blok, 'Değerlendirilmesi', ['Uygulayıcıya Not', 'Etkinliği Geliştiren', 'Özel gereksinimli'])),
                'uygulayiciyaNot': tek(not_ham)[:1200],
                'ozelGereksinimUyarlamalari': madde(ozel),
                'kaynakSayfa': i + 1,
            })
    return cikti

# --------------------------------------------------------------- birlestir

# -------------------------------- 3) ozel egitim programlari (pdf)

# Ozel egitim okullari icin ORGM'nin AYRI belgeleri.
#
# Yapisi genel etkinlik setinden FARKLI: hafta yok, "Etkinlik NN"
# numarasi var; kazanimin altinda GOSTERGELER bulunuyor. Bu belgeler
# ozel egitim sinifi ogretmeni icin asil kaynak — genel plan o
# siniflarda uygulanamiyor.
OZEL_PDF = [
    ('ozelAnaokulu', 'oe_anaokulu.pdf', 'Özel Eğitim Anaokulu'),
    ('ozelIlkokul', 'oe_ilkokul.pdf', 'Özel Eğitim İlkokulu'),
    ('ozelOrtaokul', 'oe_ortaokul.pdf', 'Özel Eğitim Ortaokulu'),
    ('ozelMeslek', 'oe_meslek.pdf', 'Özel Eğitim Meslek Okulu'),
]

OZEL_ETIKET = [
    'Kazanım', 'Göstergeler', 'Yöntem ve Teknik', 'Kaynak Araç ve Gereçler',
    'Kaynak Araç', 'Süre', 'Süreç', 'Giriş', 'Geliştirme', 'Sonuç',
    'Değerlendirme', 'Aile Katılımı', 'Çalışma Yaprağı', 'Ek-',
]


def ustbilgisiz(t):
    """Sayfa ustbilgisini metinden ayiklar.

    Ozel egitim belgelerinde her sayfanin ustunde
    "22 ÖZEL EĞİTİM ORTAOKULU ÖZELLEŞTİRİLMİŞ SINIF REHBERLİĞİ
    PROGRAMI" tekrar ediyor; pypdf bunu govdeye karistiriyor.
    """
    if not t:
        return ''
    t = re.sub(
        r'\s*\d*\s*ÖZEL EĞİTİM [A-ZÇĞİÖŞÜ ]+'
        r'ÖZELLEŞTİRİLMİŞ SINIF REHBERLİĞİ\s*PROGRAMI\s*',
        ' ', t)
    return re.sub(r'\s+', ' ', t).strip()


def madeler(t):
    """'• ...' bicimli maddeleri ayirir."""
    if not t:
        return []
    t = re.sub(r'(\w)\s*-\s*\n\s*(\w)', r'\1\2', t)
    parcalar = [tek(x) for x in re.split(r'[•]', t)]
    return [x for x in parcalar if len(x) > 2]


def ozelEgitimAyristir():
    cikti = []
    for kod, dosya, baslik in OZEL_PDF:
        yol = os.path.join(INDIRILEN, dosya)
        if not os.path.exists(yol):
            print(f'! ozel egitim yok: {dosya}')
            continue
        r = pypdf.PdfReader(yol)
        sayfalar = [nrm(p.extract_text()) for p in r.pages]

        # Etkinlik basi: "Etkinlik NN" + Kazanim ayni sayfada.
        bas = [i for i, t in enumerate(sayfalar)
               if re.search(r'Etkinlik\s*\n?\s*\d{2}', t) and 'Kazanım' in t]

        for n, i in enumerate(bas):
            bitis = bas[n + 1] if n + 1 < len(bas) else len(sayfalar)
            blok = '\n'.join(sayfalar[i:bitis])
            bt = sayfalar[i]

            # Icindekiler sayfasi da "Etkinlik" ve "Kazanım" kelimelerini
            # iceriyor ama gercek etkinlik degil; GOSTERGELER bolumu
            # yoksa atlanir.
            if 'Göstergeler' not in bt:
                continue

            mno = re.search(r'Etkinlik\s*\n?\s*(\d{2})', bt)
            no = int(mno.group(1)) if mno else None

            # Gelisim alani "Etkinlik NN" satirindan HEMEN SONRA gelir.
            gelisim = ''
            if mno:
                sonrasi = bt[mno.end():mno.end() + 200]
                mg = re.search(
                    r'(Akademik|Sosyal Duygusal|Kariyer)[^\n]*', sonrasi)
                if mg:
                    gelisim = tek(mg.group(0))

            cikti.append({
                'programKodu': kod,
                'programAdi': baslik,
                'etkinlikNo': no,
                'gelisimAlani': gelisim,
                # Kazanim "• " madde imiyle basliyor; ustbilgi
                # ("22 ÖZEL EĞİTİM ORTAOKULU...") her sayfada tekrar
                # ettigi icin ayiklanir.
                'kazanim': ustbilgisiz(
                    tek(kes(bt, 'Kazanım', OZEL_ETIKET)).lstrip('• ').strip()
                )[:400],
                'gostergeler': madeler(kes(bt, 'Göstergeler', OZEL_ETIKET)),
                'yontemTeknik': madeler(kes(bt, 'Yöntem ve Teknik', OZEL_ETIKET)),
                'aracGerecler': madeler(
                    kes(bt, 'Kaynak Araç ve Gereçler', OZEL_ETIKET)
                    or kes(bt, 'Kaynak Araç', OZEL_ETIKET)),
                'sure': ustbilgisiz(
                    tek(kes(bt, 'Süre', ['Süreç', 'Giriş', 'Kazanım'])))[:60],
                'surec': madde(kes(blok, 'Giriş',
                                   ['Çalışma Yaprağı', 'Ek-', 'Değerlendirme'])),
                'kaynakSayfa': i + 1,
            })

        ok = sum(1 for x in cikti if x['programKodu'] == kod)
        print(f'{baslik:26s} etkinlik={ok}')
    return cikti


def main():
    planlar = []
    for grade, yol in planKaynaklari():
        if not os.path.exists(yol):
            print(f'! plan yok: {grade}'); continue
        for k in planAyristir(yol):
            k['gradeLevel'] = grade
            planlar.append(k)
    print(f'plan satiri : {len(planlar)}')

    etkinlikler = etkinlikAyristir()
    ozelEgitim = ozelEgitimAyristir()
    print(f'etkinlik    : {len(etkinlikler)}')

    # Etkinligi plana bagla: (sinif, hafta) anahtari
    dizin = {}
    for e in etkinlikler:
        dizin.setdefault((e['gradeLevel'], e['hafta']), []).append(e)

    eslesen = 0
    for p in planlar:
        if p['siraNo'] is None or p['hafta'] is None:
            continue
        aday = dizin.get((p['gradeLevel'], p['hafta']), [])
        if aday:
            p['etkinlikKaynakSayfa'] = aday[0]['kaynakSayfa']
            eslesen += 1
    print(f'eslesen     : {eslesen} / {sum(1 for p in planlar if p["siraNo"])}')

    paket = {
        'surum': 1,
        'ogretimYili': '2026-2027',
        'plan': planlar,
        'etkinlikler': etkinlikler,
        'ozelEgitim': ozelEgitim,
    }
    ham = json.dumps(paket, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    hedef = os.path.join(PROJE, 'assets', 'data', 'sinif_rehberlik_plani.json.gz')
    with gzip.open(hedef, 'wb', compresslevel=9) as f:
        f.write(ham)
    print(f'\nham {len(ham)/1048576:.1f} MB -> gzip {os.path.getsize(hedef)/1048576:.2f} MB')
    print(hedef)

    # ornek
    o = [e for e in etkinlikler if e['gradeLevel'] == 5 and e['hafta'] == 1][0]
    print('\nORNEK:', o['etkinlikAdi'])
    print('  surec adimi   :', len(o['surec']))
    print('  arac-gerec    :', o['aracGerecler'])
    print('  ozel uyarlama :', len(o['ozelGereksinimUyarlamalari']))
    for u in o['ozelGereksinimUyarlamalari'][:3]:
        print('     -', u[:90])

if __name__ == '__main__':
    main()
