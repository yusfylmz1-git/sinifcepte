# SınıfCepte Kazanım Sistemi — Durum ve Yol Haritası

Bu belge "admin panelinden yılı güncelle deyince her şey otomatik hallolsun"
hedefinin nereye kadar geldiğini ve kalanı anlatır.

## Kısa cevap

**Otomasyon bitti, lise verisi de resmî kaynağa bağlandı.**

MEB, taslak yıllık planları `tymm.meb.gov.tr/taslak-cerceve-planlari`
adresinde Excel olarak yayımlıyor — öğretim programı PDF'lerinden **ayrı bir
sayfada**. Uydurma lise kazanımları bu resmî planlarla değiştirildi.

Otomatikleştirilemeyecek tek şey kaldı:

- **MEB çalışma takvimi** — tebliğle duyurulur, kuraldan türetilemez.
  Yılda bir kez ~5 dakikada panelden girilir.

Bunun dışındaki her adım otomatik.

### Kaynak sayfaları karıştırmayın

| Sayfa | Ders | İçerik | Haftalık dağılım |
|---|---|---|---|
| `/ogretim-programlari` | 72 | Program PDF'i | Yok |
| `/taslak-cerceve-planlari` | 11 | Taslak yıllık plan (Excel) | **Var** |

Ders listesi `/Ders/GetProgramList?page=N&seed=...` JSON ucundan sayfalanır.
Sayfa HTML'ini regex ile taramak her seferinde **rastgele 20 ders** döndürür;
gerçek sayı 72'dir.

## Bugünkü akış

```
Excel (zümre planı)                MEB Takvimi (panel)
        │                                  │
        │ import_excel.py                  │ "Karşılaştır" düğmesi
        ▼                                  ▼
  ham kayıt JSON  ────────────►  overrides/<yıl>.json
                          │
                          ▼
              build_curriculum.py --year <yıl>
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
  official_maarif_kazanimlar   curriculum_presets.js
  .json (Flutter/SQLite)       (admin panel)
```

Komutlar:

```bash
# 1) Excel'den ham veriyi çıkar (yılda bir, plan değişince)
python scripts/maarif/import_excel.py --excel "C:\...\TUM_DERSLER.xlsx"

# 2) Takvimi panelden al: MEB Takvimi > 🪄 Sihirbaz > 🔍 Karşılaştır
#    inen <yıl>.json dosyasını scripts/maarif/overrides/ altına koy

# 3) Üret
python scripts/maarif/build_curriculum.py --year 2027-2028

# 4) Doğrula
python scripts/maarif/test_pipeline.py
node admin_portal/js/test_calendar.js
flutter test
```

## Veri kalitesi — gerçek durum

149 ders grubunun kazanım zenginliği (33 ders haftasına karşılık kaç
benzersiz kazanım):

| Durum | Grup | Değerlendirme |
|---|---|---|
| Tam (≥%90) | 71 | Yayına hazır |
| Orta (%40-90) | 64 | Kullanılabilir |
| Zayıf (<%40) | 14 | Çoğu MEB'in kendi dağılımı |

9-12. sınıfta resmî plana geçişin etkisi:

| | Önce (uydurma) | Sonra (resmî MEB) |
|---|---|---|
| Ders grubu | 28 | **94** |
| Branş | 8 | **13** |
| Ortalama benzersizlik | %32 | **%71** |
| Hazır grup (≥%90) | 0 | **35** |

Kalan tekrarların çoğu gerçek: MEB planında da bir kazanım birden çok haftaya
yayılabiliyor (9. sınıf Beden Eğitimi'nde bir hareket becerisi altı hafta
sürüyor). Bu artık uydurma değil, kaynağın kendi dağılımı.

Zayıf grupların **tamamı 9-12. sınıf** (ve birkaç 1-2. sınıf Türkçe/Beden).
En kötüsü: 11. sınıf Felsefe — 33 haftada 7 benzersiz kazanım, yani her
kazanım ortalama 4-5 kez tekrar ediyor.

### Eski durum neden böyleydi

Zümre Excel'inde (`TÜM_DERSLER_MERKEZ_STANDART_GUNCEL.xlsx`) **59 sekme var
ve hepsi 1-8. sınıf**. Eski `lise_maarif_pipeline.py`, elle yazılmış kısa tema
listelerini 39 haftaya yaymak için döngüye sokuyordu
(`kazanim_list[i % len(kazanim_list)]`). Artık bu veri kullanılmıyor.

### Resmî planların yapısı

Her plan dosyası şu sütunları taşır — uygulamanın gösterdiği her alanın
kaynakta karşılığı var:

```
AY | HAFTA | DERS SAATİ | ÜNİTE/TEMA | KONU | ÖĞRENME ÇIKTILARI |
SÜREÇ BİLEŞENLERİ | ÖLÇME VE DEĞERLENDİRME | SOSYAL-DUYGUSAL BECERİLER |
DEĞERLER | OKURYAZARLIK BECERİLERİ | BELİRLİ GÜN VE HAFTALAR |
FARKLILAŞTIRMA | OKUL TEMELLİ PLANLAMA
```

Haftalar aynı kazanım kodunu paylaşsa da `SÜREÇ BİLEŞENLERİ` sütunu her hafta
farklıdır (a, b, c, ç…) — gerçek ilerleme buradan gelir.

**Okul türü ayrımı:** aynı ders için üç ayrı plan var (Anadolu / Fen / Sosyal
Bilimler Lisesi). Bazı derslerde ayrıca ders saati varyantı bulunuyor
(Coğrafya 11: 2 saat / 4 saat). Bunlar `publisher` alanında ayrı tutulur.

### Kaynak Excel hakkında iki bulgu

- Excel yalnızca **36 hafta** içeriyor; 37, 38, 39. haftalar tüm
  sekmelerde boş. İçe aktarıcı bunları boş bırakıyor, uydurmuyor.
- Bazı dersler iki kopya sekmeye sahip (`5-İngilizce-ÇYDEM` ve
  `..._2`). İçe aktarıcı dolu olanı seçip diğerini raporluyor.
- 8. sınıf İngilizce Excel'de vardı ama uygulamada yoktu — eski
  ayrıştırıcının Türkçe `İ` hatası yüzünden düşmüştü. **Kurtarıldı**:
  39 hafta, veri 3198 → 3237 kayda çıktı.

## Yol haritası

### Faz A — Veri boşluğu (TAMAMLANDI)

MEB'in resmî taslak planları bağlandı. Uydurma içerik kalmadı: her kayıt ya
gerçek zümre planından, ya MEB resmî planından geliyor, ya da açıkça
"Planlanmamış Hafta" diyor (410 hafta).

**Resmî planı henüz olmayan dersler** — MEB yayımladıkça
`fetch_tymm_plans.py` bunları da alır:

- İngilizce (9-12) ve Çoklu Yabancı Dil
- Din Kültürü ve Ahlak Bilgisi
- Bilişim / Yapay Zekâ Uygulamaları
- Seçmeli dersler, İHO branşları (Kur'an-ı Kerim, Siyer, Arapça)

### Kart görünümü ve panel (TAMAMLANDI)

Ekran görüntülerinden çıkan hatalar düzeltildi:

- **Değerler kırpılıyordu.** Kart `maarifValues.split(',').first` ile yalnızca
  ilk değeri alıp onu da tek satıra sığdırmaya çalışıyordu ("D4. Dostl…").
  Artık tüm liste sarmalanan rozetler hâlinde gösteriliyor.
- **Beceriler ve farklılaştırma hiç görünmüyordu.** `maarifSkills` ve
  `differentiation` alanları kartta yoktu; eklendi.
- **Birden fazla kazanım tek paragrafa yapışıyordu.** Kaynak planlarda bir
  hafta iki kazanım taşıyabiliyor ve `|` ile ayrılmış geliyor. Kod cümlenin
  ortasında kayboluyordu; artık parçalar ayrı satırlara açılıyor, baştaki
  konu etiketi üst başlık oluyor. (1218 kayıt etkileniyordu.)
- **Yanlış branş metinleri.** 5. sınıf Bilişim'e "Estetik / yaratıcı ifade"
  (Görsel Sanatlar metni), Matematik'e "Kinestetik" yazıyordu. Boru hattı
  eski üretilmiş değerleri koruyordu; artık yalnızca resmî MEB planından
  gelen kodlu değerler korunuyor, gerisi branşa göre yeniden hesaplanıyor.
- **Panelde XSS/bozulma riski.** MEB metinleri tırnak ve `<` içeriyor ve
  tabloya ham gömülüyordu; `escapeHtml` eklendi.
- **Panelde düzenleme kutusu.** Üç ardışık `prompt()` yerine, Maarif
  alanlarını da içeren düzenleme modalı eklendi.
- **Boş kategori sekmeleri.** Seçmeli/Kurs/İHO/Harezmi sekmeleri sebebini
  söylemeden boş kalıyordu; artık "MEB bu kategori için plan yayımladığında
  otomatik eklenecek" açıklaması gösteriliyor.

### Faz B — Otomasyonu tamamla (yapılabilir, küçük işler)

- [ ] `import_excel.py`'yi admin paneline bağla — şu an Excel yükleme
      modalı ayrı bir ayrıştırıcı (`smart_excel_importer.js`) kullanıyor;
      Python içe aktarıcıyla aynı kuralları paylaşmalı.
- [ ] Boş hafta (placeholder) kayıtlarını panelde işaretle; yönetici
      hangi haftanın doldurulması gerektiğini görsün.
- [ ] `--check` çıktısını panelde göster (şu an yalnızca konsolda).
- [ ] Dini bayram tarihlerini Diyanet takviminden doğrula
      (`calendar_wizard.js` içinde 2025-2028 elle yazılı, sonrası tahmin).

### Faz C — Kapsam genişletme

Şu an yok olan kategoriler (panelde filtre var, kayıt yok):

- Seçmeli dersler
- İHO branşları (Kur'an-ı Kerim, Siyer, Arapça, Temel Dini Bilgiler)
- Din Kültürü ve Ahlak Bilgisi
- Rehberlik / Kariyer

Bunlar için de Faz A'daki veri sorunu geçerli.

## "Tam otonom" ne demek olmalı

Kazanım Cepte gibi uygulamalar da MEB takvimini elle giriyor — çünkü
başka yolu yok. Gerçekçi hedef şu:

> Yılda bir kez, ~10 dakika: takvimi panelden gir, Excel'i güncelle,
> tek komut çalıştır. Gerisi otomatik.

Bu hedefe **ulaşıldı**. Eksik olan tek şey lise için besleyecek veri.

## Doğrulama durumu

| Test | Sayı | Durum |
|---|---|---|
| Python boru hattı | 36 | ✅ |
| Panel takvim | 16 | ✅ |
| Flutter | 247 | ✅ |

`flutter analyze` temiz. Yayın verisi: **5811 kayıt, 149 ders grubu**,
kimlik çakışması yok, 39 hafta tam.

## Karar bekleyen tek konu

**Okul türü seçimi.** Aynı ders için üç ayrı resmî plan var (Anadolu / Fen /
Sosyal Bilimler Lisesi). Şu an üçü de yüklü ve öğretmen yayınevi seçer gibi
seçiyor. Otomatik seçim istenirse öğretmenin okul türünü profile eklemek
gerekir.
