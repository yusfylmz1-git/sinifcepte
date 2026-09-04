# Pano çalışmaları — açık işler

## 1. Yirmi günün PDF'lerini tek tek gözden geçir

**Durum:** Yapıldı (2026-09-04). 220 PDF / 369 sayfa makineyle tarandı;
taşma ve "neredeyse boş sayfa" sayısı sıfır. Bulunan ve düzeltilen dört
sorun:

- **Merkez afiş başlığı kırpılıyordu.** 26 punto sabitti; 34 karakterden
  uzun başlıklar sayfadan taşıyordu. Dört gün etkileniyordu (23 Nisan,
  19 Mayıs, 18 Mart, 15 Temmuz). `_basligaGorePunto` ile kademeli
  küçültme eklendi.
- **Dev başlık harfleri kesiliyordu.** M ve W gibi geniş harfler 260
  puntoda hücreden taşıyordu ("ZAFER BAYRAMI"nın M'si yarım basılıyordu).
  `_harfPunto` ile harf genişliğine göre punto ayarlanıyor.
- **İçerik sessizce atılıyordu.** `biliyorMuydunuz` yedi, `siirDuvari`
  dört kartla sınırlıydı; fazlası hiç basılmadan kayboluyordu. İkisi de
  sayfalamaya çevrildi.
- **Sözlük kartı hiç çizilmiyordu.** `CrossAxisAlignment.stretch`, dış
  `Expanded` olmadan sonsuz yükseklik istiyordu; kart boş çıkıyordu.

**Nasıl tekrarlanır:** Geçici bir test dosyası PDF'leri diske döker
(`test/zz_pano_dok_test.dart`; iş bitince silindi). Sonra:

```bash
python -c "
import pymupdf, glob, os
for f in sorted(glob.glob('pano_ciktilari/*.pdf')):
    d = pymupdf.open(f)
    for i, pg in enumerate(d):
        r = pg.rect
        for b in pg.get_text('blocks'):
            if b[2] > r.x1-4 or b[0] < 4 or b[3] > r.y1-4 or b[1] < 4:
                print('TASMA', os.path.basename(f), i+1, b[4][:30])
    d.close()
"
```

---

## 2. Tamamlanmış işler (referans)

- 20 günün tamamı güne özel içerikle yazıldı (183 pano seçeneği)
- 21 palet, siyah-beyaz baskı için gri merdivene oturtuldu ve doğrulandı
- On pano kurgusu yazıldı, hepsi cihazda rasterize oluyor (en yavaşı 543 ms)
- Kurgu seçim ekranı bağlandı
- "Belge Hazırlanıyor" sonsuz takılması çözüldü
  (sebep: `onZoomChanged` içindeki `setState`; bkz. `pdf_preview_screen.dart`)
- İçerik zenginleştirildi (2026-09-04): 20 günün tamamına
  `panoParagraflar`, `sozluk` ve `oncesiSonrasi` eklendi. Artık her gün
  11 kurgunun hepsini üretebiliyor (önce 5-10 arası değişiyordu).
  Veri 29,9 KB → 44,5 KB (gzip).
- Üç düzey / üç ton şeması: öğrenci konuşması ve şiir `duzey` ('1-2',
  '3-4', '5-8', 'hepsi'), müdür konuşması `ton` ('resmî', 'samimi',
  'kısa') taşıyor. Tören planı havuzun tamamını basmaz; birini seçip
  "N seçenek daha var" notu düşer.
- Vektörel motifler (`pano_motifler.dart`): 16 SVG motif, güne değil
  *anlama* bağlı (sandık=oy, fidan=büyüme, meşale=aydınlanma). Motif
  kendi rengini seçmez, paletten alır — gri merdiven s/b baskıda korunur.
- 11. kurgu: Kavram Sözlüğü.
