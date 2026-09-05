# SınıfCepte Müfredat Boru Hattı

Kazanım verisi MEB'in **iki resmî sitesinden** iniyor ve APK ile
dağıtılıyor. Yılda bir kez, ağustos sonunda yenilenir.

## Tek komut

```bash
python scripts/maarif/yillik_guncelle.py --year 2027-2028
```

İndirir, işler, birleştirir ve yayın paketini üretir. Öncesinde
`overrides/<yıl>.json` hazır olmalı (aşağıda).

Sonrasında:

```bash
python scripts/maarif/test_pipeline.py     # boru hattı testleri
dart run tool/compress_assets.dart         # gzip paketi
flutter test                               # uygulama tarafı
flutter build apk --release                # yayın
```

## Ne zaman yenilenir

MEB planları **ağustos sonunda** yayımlıyor. Ölçüm: 2026-2027
planları 31 Ağustos – 3 Eylül tarihlerinde yüklenmişti.

MEB yıl içinde de yeni ders ekleyebiliyor — Eylül 2026'da ilkokul ve
ortaokul planları yayımlandı ve o ana kadar uygulamada yalnızca lise
planı vardı. Site listesi sabitlenmediği için betik yeni dersleri
kendiliğinden alır.

## Kaynaklar

| Kaynak | Ne yayımlıyor |
|---|---|
| `tymm.meb.gov.tr/taslak-cerceve-planlari` | Genel dersler, 1-12. sınıf |
| `dogm.meb.gov.tr` | İmam hatip ve din dersleri — TYMM'de **yok** |

İkisi de resmî MEB, farklı genel müdürlük. Okulun kendi zümre
Excel'i **kaynak değildir**: bir önceki yıla ait oluyordu ve resmî
veriyle karıştırmak öğretmene güncel olmayan içerik göstermek
demekti.

MEB'in yıllık plan yayımlamadığı seçmeliler (Bilim Uygulamaları,
Görgü Kuralları, Yazarlık, Trafik Güvenliği…) ders listesinde kalır
ama haftalık içerikleri **uydurulmaz** ve Maarif rozeti almazlar.

## MEB çalışma takvimi (elle girilir)

Ara tatil haftaları bir kuraldan türetilemez; MEB tebliğinden
girilmesi gerekir. Bir önceki yılın dosyasını kopyalayın:

```bash
cp scripts/maarif/overrides/2026-2027.json scripts/maarif/overrides/2027-2028.json
```

```jsonc
{
  "startDate": "2027-09-13",        // Okulların açıldığı PAZARTESİ
  "secondTermStartWeek": 21,        // 2. dönemin başladığı hafta
  "holidayWeeks": {                 // Eğitim yapılmayan haftalar
    "10": "1. Dönem Ara Tatili",
    "19": "Yarıyıl Tatili (1. Hafta)",
    "20": "Yarıyıl Tatili (2. Hafta)",
    "28": "2. Dönem Ara Tatili"
  },
  "otpWeeks": [8, 17, 29],          // Okul Temelli Planlama haftaları
  "socialEventWeeks": [18, 37]      // Sosyal etkinlik haftaları
}
```

Admin panelindeki **MEB Takvimi → 🪄 Takvim Sihirbazı** bu dosyayı
üretebiliyor; **🔍 Kazanım Kartlarıyla Karşılaştır** düğmesi
takvimdeki tatil haftalarıyla karttakileri karşılaştırıp uyuşmazlık
varsa dosyayı indiriyor.

Takvimi gözden geçirmek için:

```bash
python scripts/maarif/academic_calendar.py 2027-2028
```

## Neden APK ile dağıtılıyor

Müfredat yılda bir değişiyor. 30.000 öğretmene bulut üzerinden
dağıtmak ölçüldüğünde yılda ~$11-23 tutuyor (paket 2,1 MB); mağaza
güncellemesi bunu sıfıra indiriyor.

Uygulama, varlık parmak izi değiştiği için yeni paketi kendiliğinden
yeniden tohumluyor — ek bir işlem gerekmez.

Sınav takvimi bundan **farklı**: yıl içinde değişiyor (ertelenen bir
LGS, açıklanan başvuru tarihi) ve Remote Config yükünde gerçekten
iniyor. Kazanım paketi oraya sığmıyor: ölçüm, proje geneli 1.000.000
karakter sınırına karşılık base64'te 2.331.528 karakter.

## Kaynak ve Maarif rozeti

Her kayıt iki alan taşır:

| Alan | Değerler |
|---|---|
| `sourcePortal` | `tymm` / `dogm` / boş |
| `sourceProgram` | `maarif` / `legacy` / boş |

Yeşil "Maarif" rozeti `sourceProgram == 'maarif'` ise basılır.

**Program türü Excel sütun başlığından ölçülür, tahmin edilmez:**

```
"ÖĞRENME ÇIKTILARI VE SÜREÇ BİLEŞENLERİ"  -> maarif
"KAZANIM" + "KAZANIM AÇIKLAMASI"          -> legacy
```

MEB aynı dosyada iki programı birden yayımlıyor (Fen Bilimleri 3
Maarif, 4 eski program), bu yüzden kademeden çıkarım yetmez. Sayfa
adındaki "(TYMM)" işareti de yetmez: lise dosyalarında hiç yok, oysa
içerikleri Maarif düzeninde.

`publisher` alanı **yalnızca okul türüdür** (Anadolu / Fen / Sosyal
Bilimler Lisesi) ve boş kalabilir. Önce üç işi birden yapıyordu ve
rozetin yanlış basılmasına yol açıyordu.

## Dosyalar

| Dosya | Görevi |
|---|---|
| `yillik_guncelle.py` | **Tek komut**: indir → işle → birleştir → üret |
| `fetch_tymm_plans.py` | TYMM taslak yıllık planlarını indirir |
| `fetch_dogm_plans.py` | DÖGM çerçeve planlarını indirir (imam hatip) |
| `import_tymm_plans.py` | Excel planlarını ham kayda çevirir (iki kaynak da) |
| `merge_sources.py` | Kaynakları birleştirir; öncelik DÖGM > TYMM |
| `build_curriculum.py` | Normalize eder, doğrular, yayın paketini yazar |
| `academic_calendar.py` | 39 haftalık takvim; sapmalar `overrides/` içinde |
| `turkish_text.py` | Türkçe metin katlama ve branş kodu tespiti |
| `pedagogy.py` | Maarif pedagojik alanları |
| `test_pipeline.py` | Boru hattı testleri |

Panel tarafı:

| Dosya | Görevi |
|---|---|
| `admin_portal/js/calendar_wizard.js` | MEB standart takvim şablonu |
| `admin_portal/js/calendar_to_weeks.js` | Takvimi 39 haftaya çevirir |
| `admin_portal/js/test_calendar.js` | Takvim testleri (`node`) |
| `admin_portal/js/test_outcomes.js` | Kazanım ve kota testleri |

## Bilinen sınırlar

**1. TYMM sitesinde iki ayrı sayfa var — karıştırmayın.**

| Sayfa | İçerik | Haftalık dağılım |
|---|---|---|
| `/ogretim-programlari` | Öğretim programı PDF'leri | **Yok** |
| `/taslak-cerceve-planlari` | Taslak yıllık plan arşivleri | **Var** |

Haftalık plan yalnızca ikincisinden gelir.

**2. MEB beş farklı dosya düzeni kullanıyor.** İçe aktarıcı hepsini
tanıyor ama yenisi çıkarsa sessizce boş kayıt üretmemeli:

- Maarif düzeni (çoğunluk)
- Eski program düzeni (KAZANIM sütunlu)
- Türkçe: kazanımlar dört beceri sütununa dağılmış
- ÇYDEM: sütun başlıkları İngilizce veya Almanca
- Eski `.xls` biçimi (Görsel Sanatlar)

Kademe okunamayan sayfa artık **uyarı üretir**. Önce sessizce
düşüyordu ve Fen Bilimleri'nin tamamı böyle kaybolmuştu.

**3. Bazı derslerde kazanım tekrarı normaldir.** Resmî planda bir
kazanım birden çok haftaya yayılabilir (Beden Eğitimi'nde altı hafta
sürebilir). `--check` uyarısı bunu gösterir ama artık "uydurma"
değil, MEB'in kendi dağılımıdır.

**4. Planlanmamış haftalar.** Resmî plan 34-36 ders haftası içerir;
39 haftaya tamamlama `build_curriculum.py` içinde yapılır.
Tatil/OTP/sosyal etkinlik haftaları takvimden doldurulur, kalan
boşluklar `isPlaceholder: true` ile işaretlenir.
