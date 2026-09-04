# SınıfCepte Müfredat Boru Hattı

Yeni eğitim öğretim yılına geçmek için tek akış.

## Yeni yıla geçiş (örn. 2027-2028)

### 0. (Kolay yol) Takvimi panelden üret

Admin panelinde **MEB Takvimi** sekmesinde:

1. **🪄 Takvim Sihirbazı** ile okulun açılış pazartesisini girin. Sihirbaz MEB
   standart yapısını kurar (10. hafta 1. ara tatil, 19-20. hafta yarıyıl,
   21. hafta 2. dönem, 28. hafta 2. ara tatil, 39. hafta kapanış). Tarihleri
   tebliğe göre elle düzeltebilirsiniz.
2. **🔍 Kazanım Kartlarıyla Karşılaştır** düğmesine basın. Takvimdeki tatil
   haftalarıyla kartlardaki tatil haftaları karşılaştırılır. Uyuşmuyorsa
   `<yıl>.json` dosyası indirilir — bu dosya doğrudan `overrides/` klasörüne
   konur ve 1. adımı atlayabilirsiniz.

Elle yazmayı tercih ederseniz aşağıdaki adım aynı dosyayı oluşturur.

### 1. MEB çalışma takvimini gir

MEB her yıl çalışma takvimini tebliğle duyurur. Ara tatil haftaları bir
kuraldan türetilemez; **elle girilmesi gerekir**. Bir önceki yılın dosyasını
kopyalayıp güncelleyin:

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

`startDate` verilmezse Eylül'ün ikinci pazartesisi varsayılır. Bu yalnızca
varsayılandır — MEB bu kuraldan sapabilir, tebliğdeki tarihi girin.

Takvimi gözden geçirmek için:

```bash
python scripts/maarif/academic_calendar.py 2027-2028
```

### 1b. Lise (9-12) için MEB resmî planlarını çek

MEB, `tymm.meb.gov.tr/taslak-cerceve-planlari` adresinde **taslak yıllık
planları** Excel olarak yayımlıyor. Öğretim programı PDF'lerinin aksine bu
dosyalar kazanımları haftalara dağıtılmış hâlde içerir:

```bash
python scripts/maarif/fetch_tymm_plans.py      # indir + aç
python scripts/maarif/import_tymm_plans.py     # ham kayda çevir
```

Çıktı: `assets/data/tymm_plan_raw.json`

Planlar okul türüne göre ayrışır (Anadolu / Fen / Sosyal Bilimler Lisesi) ve
bazı derslerde ders saati varyantı vardır (Coğrafya 11: 2 saat / 4 saat).
Bunlar `publisher` alanında ayrı tutulur, birbirini ezmez.

### 1c. (1-8 planı değiştiyse) Zümre Excel'inden içeriği al

```bash
python scripts/maarif/import_excel.py --excel "C:\...\TUM_DERSLER.xlsx"
```

Excel'de eksik hafta varsa **boş bırakılır, uydurulmaz** ve rapor edilir.

### 2. Veriyi doğrula (dosya yazmadan)

```bash
python scripts/maarif/build_curriculum.py --year 2027-2028 --check
```

Kimlik çakışması, eksik hafta veya boş kazanım varsa burada durur.

### 3. Üret

```bash
python scripts/maarif/build_curriculum.py --year 2027-2028
```

İki dosya yazılır:

| Dosya | Kullanan |
|---|---|
| `assets/data/official_maarif_kazanimlar.json` | Flutter uygulaması (SQLite'a tohumlanır) |
| `admin_portal/js/curriculum_presets.js` | Web admin paneli |

### 4. Doğrula ve yayınla

```bash
python scripts/maarif/test_pipeline.py       # boru hattı testleri
node admin_portal/js/test_calendar.js        # panel takvim testleri
node admin_portal/js/test_outcomes.js        # panel kazanım/kota testleri
flutter test test/curriculum_test.dart       # uygulama tarafı
```

Uygulama açıldığında varlık dosyasının parmak izi değiştiği için müfredatı
kendiliğinden yeniden tohumlar; ek bir işlem gerekmez.

Admin panelinde **"MEB Maarif'i Çevrimiçi Güncelle"** düğmesi yeni paketi
yükler. Panel, `localStorage`'daki kayıtların eğitim yılını paketle
karşılaştırır; yıl farklıysa eski kayıtları kullanmaz.

## Dosyalar

| Dosya | Görevi |
|---|---|
| `academic_calendar.py` | 39 haftalık takvimi üretir; yıla özgü sapmalar `overrides/` içinden okunur |
| `turkish_text.py` | Türkçe metin katlama ve branş kodu tespiti |
| `pedagogy.py` | Maarif pedagojik alanları (özet, değer, beceri, farklılaştırma) |
| `build_curriculum.py` | Ana boru hattı: normalize eder, doğrular, yazar |
| `import_excel.py` | Zümre/MEB Excel yıllık planlarını ham kayda çevirir |
| `fetch_tymm_plans.py` | **MEB resmî taslak yıllık planlarını indirir (9-12)** |
| `import_tymm_plans.py` | İndirilen resmî planları ham kayda çevirir |
| `fetch_tymm_catalog.py` | TYMM program kataloğu (yalnızca katalog listesi) |
| `test_pipeline.py` | Boru hattı testleri |

Panel tarafı:

| Dosya | Görevi |
|---|---|
| `admin_portal/js/calendar_wizard.js` | MEB standart takvim şablonunu üretir |
| `admin_portal/js/calendar_to_weeks.js` | Takvim olaylarını 39 haftalık yapıya çevirir; `overrides/` JSON'u üretir |
| `admin_portal/js/test_calendar.js` | Takvim testleri (`node` ile çalışır) |
| `admin_portal/js/test_outcomes.js` | Kazanım yöneticisi ve localStorage kotası testleri |

## Bilinen sınırlar

**1. TYMM sitesinde iki ayrı kaynak var — karıştırmayın.**

| Sayfa | İçerik | Haftalık dağılım |
|---|---|---|
| `/ogretim-programlari` | Öğretim programı PDF'leri (72 ders) | **Yok** |
| `/taslak-cerceve-planlari` | Taslak yıllık plan Excel'leri (11 ders) | **Var** |

Haftalık plan yalnızca ikinci sayfadan gelir ve şu an **sadece 11 lise dersi**
için yayımlanmıştır. Ders listesi `/Ders/GetProgramList` JSON ucundan
sayfalanarak okunur (`?page=N&seed=...`); tek sayfa çekmek yalnızca rastgele
20 ders döndürür.

**2. Bazı derslerde kazanım tekrarı normaldir.**
Resmî planda da bir kazanım birden çok haftaya yayılabilir (Beden Eğitimi'nde
bir kazanım 6 hafta sürebilir). `--check` uyarısı bunu gösterir ama artık
"uydurma" değil, MEB'in kendi dağılımıdır. Uyarıyı kaynakla karşılaştırarak
değerlendirin.

**3. Resmî planı olmayan dersler.**
MEB henüz şu dersler için taslak plan yayımlamadı: İngilizce (9-12), Din
Kültürü, Bilişim/Yazay Zekâ, seçmeliler ve İHO branşları (Kur'an-ı Kerim,
Siyer, Arapça). Bu derslerde hafta, "Planlanmamış Hafta" olarak işaretlenir —
içerik uydurulmaz. MEB yayımladıkça `fetch_tymm_plans.py` bunları da alır.

**4. Planlanmamış haftalar.**
Resmî plan 34-36 ders haftası içerir; 39 takvim haftasına tamamlama
`build_curriculum.py` içinde yapılır. Tatil/OTP/sosyal etkinlik haftaları
takvimden doldurulur, kalan boşluklar `isPlaceholder: true` ile işaretlenir.
