# -*- coding: utf-8 -*-
"""Panelin tohum listesini APK verisinden URETIR.

SORUN: Panel 20 sinavlik listeyi koda gomulu tutuyordu, APK ise
assets/data/official_exams.json'dan 35 sinav okuyordu. Iki kaynak
kaymisti; "Orijinal Takvimi Yukle" eski listeye donuyordu.

COZUM: Liste tek kaynaktan (JSON dosyasi) URETILIYOR. `async` yapmak
yapiciyi ve uc cagirani bozardi; bunun yerine bu script calistirilinca
kod yeniden yaziliyor. Veri degisince script tekrar calistirilir.
"""
import io, json

KOK = r'c:\Users\Okul\Desktop\Projelerim\sinifcepte'

sinavlar = json.load(io.open(KOK + r'\assets\data\official_exams.json',
                             encoding='utf-8'))

P = KOK + r'\admin_portal\js\exams_manager.js'
s = io.open(P, encoding='utf-8').read()

bas = s.index('  getDefaultSeeds() {')
son_isaret = s.index('];', bas)
son = s.index('\n  }', son_isaret) + len('\n  }')

# JS nesne dizisi uret
satirlar = []
for x in sinavlar:
    alanlar = []
    for k in ('doc_id', 'title', 'institution', 'examDate',
              'applicationDeadline', 'applicationUrl', 'description',
              'category'):
        v = x.get(k)
        if v is None:
            continue
        kacisli = (str(v).replace('\\', '\\\\')
                          .replace("'", "\\'")
                          .replace('\n', ' '))
        alanlar.append(f"        {k}: '{kacisli}',")
    satirlar.append('      {\n' + '\n'.join(alanlar) + '\n      },')

govde = '\n'.join(satirlar)

YENI = f"""  /**
   * Varsayilan sinav takvimi — {len(sinavlar)} sinav.
   *
   * ## Bu liste ELLE DUZENLENMEZ
   * `assets/data/official_exams.json` dosyasindan uretiliyor; APK ile
   * ayni kaynak. Eskiden panel kendi kopyasini tutuyordu ve iki taraf
   * kaymisti (panelde 20, APK'da 35) — "Orijinal Takvimi Yukle" eski
   * listeye donuyordu.
   *
   * Veri degisince `tool/panel_tohum_uret.py` calistirilir.
   */
  getDefaultSeeds() {{
    return [
{govde}
    ];
  }}"""

s = s[:bas] + YENI + s[son:]
io.open(P, 'w', encoding='utf-8', newline='\n').write(s)
print(f'panel tohum listesi guncellendi: {len(sinavlar)} sinav')
