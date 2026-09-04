# BEP Modülü — Araştırma ve Tasarım Önerisi

**Tarih:** 31 Ağustos 2026
**Durum:** Tasarım önerisi — henüz kod yazılmadı

---

## MEVCUT DURUM

`classroom_documents_pdf_generator.dart:992` içinde bir BEP formu var ama
**boş şablon**: `goalsList` parametresi verilmezse sabit dört örnek hedef
basılıyor.

```dart
final defaultGoals = goalsList ?? [
  {'goal': 'Ders kazanımlarına uygun temel kavramları tanır...', ...},
  {'goal': 'Verilen basit yönergeleri adım adım takip ederek...', ...},
  // ...
];
```

Çağıran hiçbir yer `goalsList` geçmiyor. Yani **her öğrenci için aynı
dört örnek hedef** basılıyor; öğrenci bazında hedef, ilerleme kaydı ve
değerlendirme yok.

---

## ARAŞTIRMA BULGULARI

### Yasal dayanak
- 573 sayılı KHK (1997) ile BEP hazırlamak **zorunlu**
- Özel Eğitim Hizmetleri Yönetmeliği — BEP geliştirme birimi ve
  hazırlama/değerlendirme esasları

### BEP geliştirme birimi
Okul müdürü (veya görevlendirdiği müdür yardımcısı) **başkanlığında**:
- Rehber öğretmen
- Öğrencinin sınıf öğretmeni
- Dersine giren alan öğretmenleri
- Gezerek özel eğitim görevi yapan öğretmen (varsa)
- **Veli**
- **Öğrenci** (uygun durumda)

> **Bu, uygulama için kritik:** BEP tek bir öğretmenin ürünü değil,
> kurulun ortak kararı. Uygulama bunu "tek öğretmen doldurur" gibi
> kurgularsa mevzuata aykırı bir belge üretir.

### Amaç yapısı
```
UZUN DÖNEMLİ AMAÇ  (yıllık / dönemlik)
   └── KISA DÖNEMLİ AMAÇ 1   ← ölçülebilir, koşullu
   └── KISA DÖNEMLİ AMAÇ 2
   └── KISA DÖNEMLİ AMAÇ 3
```

**Kısa dönemli amaç yazım kalıbı:** `koşul + davranış + ölçüt`

> "Öğrenci, **sınıf ortamında** (koşul) **sözel yönergeleri yerine
> getirir** (davranış), **4 denemenin 3'ünde** (ölçüt)."

### Değerlendirme ve gözden geçirme
- Eğitim planı **her yıl** BEP geliştirme birimince yenilenir
- Gelişim raporu **en az yılda bir**; daha sık aralık serbest
- Uygulamada yaygın: **dönem sonu** (2 kez/yıl)

### BEP dosyası
MEB yol haritasında dosya **EK-1 … EK-7** olarak yedi ek içeriyor.
Tek bir "BEP formu" değil, bir dosya.

---

## TASARIM ÖNERİSİ

### Kapsam kararı: sadece hedef takibi

Tam rehberlik modülü (bireyi tanıma fişi, görüşme kayıtları, risk
takibi) ayrı bir iş. **Önce BEP hedef takibi** yapılmalı çünkü:
- Yasal zorunluluk taşıyan tek kısım bu
- Öğretmenin en çok zaman harcadığı yer
- Diğerleri BEP'e bağlı, tersi değil

### Veri modeli

```
bep_plans                      (öğrenci + yıl + ders kodu tektir)
  id, student_id, academic_year, subject, subject_code, grade_level
  ram_decision                 (RAM kararı metni)
  performance_level            (mevcut performans düzeyi)
  created_at, updated_at
  UNIQUE(student_id, academic_year, subject_code)

bep_long_goals                 (uzun dönemli amaçlar)
  id, plan_id, title, order_index

bep_short_goals                (kısa dönemli amaçlar)
  id, long_goal_id
  condition, behavior, criterion   ← üç parça AYRI tutulur
  method                       (öğretim yöntemi/materyal)
  order_index

bep_evaluations                (dönemlik değerlendirme)
  id, short_goal_id
  status                       (başarıldı / devam / desteklenmeli)
  evaluated_at, note
```

**Neden üç parça ayrı:** Öğretmen tek kutuya yazarsa ölçüt unutuluyor
ve amaç ölçülemez hale geliyor. Ayrı alanlar doğru kalıbı zorluyor.

**Neden değerlendirme ayrı tablo:** Aynı amaç yıl içinde birden çok kez
değerlendirilir; tek alan olsaydı geçmiş silinirdi. İlerlemeyi görmek
BEP'in asıl amacı.

### Ekran akışı

```
Sınıfım → Rehberlik → BEP
─────────────────────────────────
 BEP'li öğrenciler          [+ Ekle]
 ─────────────────────────────────
  Ahmet YILMAZ   5-A   3/7 amaç ✓
  Elif KAYA      5-A   5/9 amaç ✓
```

Öğrenciye dokununca:

```
BEP · Ahmet YILMAZ · Matematik   [PDF]
──────────────────────────────────────
 RAM Kararı: Hafif düzey/kaynaştırma
 Performans: 2 basamaklı sayıları okur

 UZUN DÖNEMLİ AMAÇ
 4 basamaklı doğal sayıları okur ve yazar

   ✓ 1-100 arası ritmik sayar        [Başarıldı]
   ◐ 2 basamaklı sayıları okur       [Devam]
   ○ 3 basamaklı sayıları okur       [—]

 [+ Kısa Dönemli Amaç Ekle]
```

### Nerede duracak

**Cihazda.** BEP verisi RAM kararı ve performans düzeyi içeriyor —
sağlık verisiyle sınırdaş, KVKK açısından en hassas veri türü. Buluta
çıkarılmamalı; veliye de uygulama üzerinden gösterilmemeli.

*(Veli BEP'i zaten kurul toplantısında imzalayarak görüyor.)*

### PDF çıktısı

Mevcut `classroom_documents_pdf_generator.dart` içindeki form
**korunur**, sadece `goalsList` gerçek veriyle doldurulur. Ek olarak:
- BEP geliştirme birimi üyeleri ve imza satırları
- Değerlendirme tarihleri

---

## PROJE YÖNETİCİSİ KARARLARI (1 Eylül 2026)

Claude belgesi eksik bıraktı. Aşağıdaki kararlar kodda uygulanır.

### Öğretmen nasıl kullanır? (Erbaram dersi)

Hazır amaç yazdırmak öğretmenin işi değildir. Akış:

1. Öğrenciyi seç
2. **Kademe** (İlköğretim / Lise / Özel eğitim) + sınıf seviyesi + ders
3. Kaba değerlendirme: **Yapıyor / Yapamıyor**
4. Yapamıyor olanlar plana alınır → PDF
3. Koşul + davranış + ölçüt otomatik dolar (`Sınıf ortamında` / öğrenci adı + kazanım / `4 denemenin 3'ünde`)
4. Durum çipine bas: Devam → Başarıldı → Desteklenmeli
5. PDF

Özel cümle isteyen nadir durum için "listede yoksa özel amaç yaz" durur. Varsayılan yol işaretlemektir.

### Kazanımlar nereden gelir? Gerçek veri mi?

**Evet, gerçek MEB Maarif verisi.** Kaynak `assets/data/official_maarif_kazanimlar.json.gz`
→ SQLite `curriculum_outcomes`. Admin paneli yılı güncelleyince paket yenilenir.

**Ama kazanım ≠ BEP.** Haftalık kazanım sınıf düzeyindedir. BEP öğrenci
düzeyinde uyarlamadır. Uygulama kazanımı *tohum* olarak sunar (kod +
metin kısa amacın davranış kutusuna kopyalanır). Koşul ve ölçüt boş
kalır; öğretmen doldurmadan kayıt olmaz.

Aynı kazanım 3 hafta sürebilir; seçicide **kod tekilleştirilir**,
hafta tekrarı gösterilmez.

### Her yıl aynı mı kalır?

| Katman | Ne olur |
|---|---|
| MEB kazanım paketi | MEB plan yayımlayınca admin yeniden üretir. Eski yıl BEP'ine
  dokunulmaz. |
| BEP planı | `öğrenci + öğretim yılı + ders` tektir. 2026-2027 planı 2027-2028
  olmaz. |
| Yeni yıl | Öğretmen yeni plan açar. İsterse **geçen yıldaki amaçları kopyalar**;
  değerlendirme **kopyalanmaz**. |

Ağustos'tan itibaren yeni öğretim yılı (`AppDateFormatter.academicYearLabel`).

### Ders bazlı mı? Kademe ayrı mı? Özel eğitim?

ORGM yol haritası: *öğrencinin takip ettiği program esas alınır.*
Sınıf adı `5-A` olsa bile BEP o öğrencinin program kademesinden çıkar.

Özel eğitim öğretmeni, aynı listede 2 öğrenci varsa:

| Öğrenci | Yerleştirme | Program | Kademe | Alan |
|---|---|---|---|---|
| Ahmet | Özel eğitim sınıfı | Gelişim alanı | okul öncesi / gelişim | Öz bakım |
| Elif | Özel eğitim sınıfı | Genel öğretim | 2. sınıf | Matematik |

Kademe sınıf adından **kilitlenmez**; plan açılırken seçilir.
Yerleştirme (kaynaştırma, özel sınıf, uygulama okulu, destek odası,
gezerek) ve okul da planda durur.

İki banka:
- **Genel öğretim:** paketteki MEB Maarif ders kazanımları (1–12).
- **Gelişim alanı:** öz bakım, günlük/toplumsal yaşam, iletişim, sosyal,
  motor, bilişsel, işlevsel okuma-yazma/matematik, güvenlik.
  Bu ikinci banka resmi özel eğitim Excel'i değildir; sahada yazılan
  ölçülebilir amaçlardır. PDF taslak takip formudur, EK-1 dosyasının
  yerini tutmaz.

Değerlendirme ORGM biçimi: **Yeterli (+) / Devam / Geliştirilmeli (-)**.

### Kurul üyeleri

Plan açılınca varsayılan satırlar: müdür (profilden), rehber (boş),
sınıf öğretmeni, ders öğretmeni, veli (`parentName` varsa), öğrenci.
Adlar elde düzenlenir. Kadro otomatik dayatılmaz — kurul imzası kâğıtta
tamamlanır.

### Hatırlatma (v1 yok)

Liste `başarıldı / toplam` gösterir. Dönem sonu push yok.

### KVKK

RAM kararı ve performans **yalnızca cihazda**. Veli portalına çıkmaz.
PDF "taslak takip formu"dur; EK-1…EK-7 dosyasının yerini tutmaz.

### Uygulama yeri

Sınıfım → Rehberlik → BEP hedef takibi. Eski boş şablon PDF yolu kapatıldı.

---

## UYARI

Bu belgedeki mevzuat özeti **web araştırmasına** dayanıyor ve hukuki
tavsiye değildir. Yayına çıkmadan önce güncel Özel Eğitim Hizmetleri
Yönetmeliği'nden doğrulanmalı; PDF çıktısının okul idaresince kabul
edilip edilmediği de sahada test edilmeli.

**Kaynaklar:**
- [MEB ÖRGM — BEP sayfası](https://orgm.meb.gov.tr/www/bireysellestirilmis-egitim-programi/icerik/2097)
- [MEB — BEP Yol Haritası (PDF)](https://orgm.meb.gov.tr/meb_iys_dosyalar/2025_02/06165410_20140845_byreyselleytyrylmyy_eyytym_programi_tum_oyretmenler_ycyn_yol_haritasi.pdf)
- [Özel Eğitim Hizmetleri Yönetmeliği](https://orgm.meb.gov.tr/meb_iys_dosyalar/2021_09/13145613_Ozel_EYitim_Hizmetleri_YonetmeliYi_son.pdf)
