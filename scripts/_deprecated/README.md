# Kullanımdan kaldırılan müfredat scriptleri

Bu klasördeki dosyalar **çalıştırılmamalıdır**. Yerlerini `scripts/maarif/`
altındaki boru hattı aldı. Ders içeriği (lise tema/kazanım listeleri) referans
olarak durması için silinmedi.

## Neden kaldırıldılar

| Dosya | Sorun |
|---|---|
| `export_presets_js.py` | `curriculum_presets.js` dosyasını `const CurriculumPresets = { OFFICIAL_DATABASE: [...] }` biçiminde yazıyordu. Panel ise `CurriculumPresets.getAllOfficialPresets()` çağırıyor. Çalıştırıldığında panel **sessizce 0 kazanım** yüklüyordu. |
| `lise_maarif_pipeline.py` | JS dosyasına `applyPreset` metodunu yazmıyordu; "Hazır Paket" modalı `TypeError` ile çöküyordu. Ayrıca 39 haftalık takvimi elle kopyalanmış hâlde içeriyordu. |
| `curriculum_normalizer_pipeline.py` | `detect_subject_code` içinde `str.lower()` kullanıyordu. Türkçe `İ` harfi `i`+U+0307 olarak küçüldüğü için `"ingilizce" in ad.lower()` **False** dönüyor; İngilizce ve İnkılap Tarihi `GENEL` koduna düşüp **234 doküman kimliği çakışması** yaratıyordu. Takvimi de 2026-2027 için sabit içeriyordu. |
| `tymm_web_crawler.py` | `ssl.CERT_NONE` ile sertifika doğrulamasını kapatıyordu. Ayrıca yalnızca ders adı/URL topluyor, kazanım çıkarmıyordu; adı "crawler" olmasına rağmen müfredat verisi üretmiyordu. |

## Yerine ne kullanılmalı

```bash
# Yıllık müfredat paketi üretimi (JSON + admin panel JS)
python scripts/maarif/build_curriculum.py --year 2027-2028

# Yazmadan doğrulama
python scripts/maarif/build_curriculum.py --year 2027-2028 --check

# TYMM resmî program kataloğu (yalnızca katalog; kazanım üretmez)
python scripts/maarif/fetch_tymm_catalog.py

# Testler
python scripts/maarif/test_pipeline.py
```

Lise tema/kazanım listeleri (`lise_maarif_pipeline.py` içindeki
`HIGH_SCHOOL_COURSES`) hâlâ değerli referans içerir; gerçek yıllık planlar
girilene kadar kaynak olarak kullanılabilir.
