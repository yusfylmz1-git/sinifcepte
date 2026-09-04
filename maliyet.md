# SınıfCepte — Maliyet ve Gelir Analizi

**Tarih:** 31 Ağustos 2026
**Kaynak:** `lib/core/cloud/cost_model.dart` (koddaki gerçek işlem sayıları)

Bu belge tahminle değil, **kodda ölçülen işlem sayılarıyla** hesaplanmıştır.
Mimaride bir şey değişip maliyet patlarsa `cost_model_test.dart` kırılır.

---

## KISA CEVAP

**Maliyet endişesi yersiz.** 1000 okulda aylık **~240 dolar**.
Aynı ölçekte reklam geliri kötümser tahminle bile **~23.000 dolar**.

Sebep: mimari zaten doğru kurulmuş. Öğrenci verisinin büyük bölümü
cihazda kalıyor, buluta yalnızca iletişim çıkıyor.

---

## 1. FIRESTORE MALİYETİ

### Ücretsiz katman (Spark) sınırları
| | Günlük |
|---|---|
| Okuma | 50.000 |
| Yazma | 20.000 |
| Silme | 20.000 |
| Depolama | 1 GB |

### Kademeler

| Öğretmen | Veli | Aylık maliyet |
|---|---|---|
| 300 | 7.500 | **$0.16** |
| 1.000 | 25.000 | **$5** |
| 5.000 | 125.000 | **$33** |
| 30.000 (≈1000 okul) | 750.000 | **$210** |

Depolama (1000 okul, 1 öğretim yılı): **+$31/ay**
→ **Toplam ~$240/ay**

**Ücretsiz katman ~250 öğretmene kadar yetiyor.** Onun üstünde Blaze
planına geçilir ama fatura yavaş büyür.

### Neden bu kadar ucuz

Üç mimari karar sayesinde:

**1. Öğrenci verisi buluta çıkmıyor.**
Notlar, katılım, devamsızlık, quiz/proje puanları, veli telefonu,
öğrenci numarası, ders programı — hepsi cihazda. Bunlar buluta gitseydi
maliyet 10–20 kat artardı.

**2. Delta senkronizasyonu.**
`DeltaSyncTracker` son çekim damgasını tutuyor; yeni mesaj yoksa sorgu
**sıfır doküman** okuyor. Bu olmasaydı her uygulama açılışı 70 okuma
yazardı ve ücretsiz katman **250 değil 5 öğretmende** dolardı.

**3. Snapshot listener kullanılmıyor.**
Açık kalan bir dinleyici her değişiklikte okuma yazar ve unutulunca
faturayı sessizce katlar. `firestore_client.dart` bunu yasaklıyor.

### Bütçe freni
`firestore_budget_guard.dart` günlük 1500 yazmada duruyor. Kaçak bir
döngü faturayı patlatamaz. Fren devreye girdiğinde kullanıcı doğru
mesajı görüyor ("günlük sınıra ulaşıldı"), yanıltıcı "internet yok"
mesajını değil.

---

## 2. VELİ SAYISI ARTINCA NE OLUR

Kullanıcı sorusu: *"veliye giden bilgi çoğaldıkça maliyet artar mı?"*

**Evet ama doğrusal değil, çok yavaş.** Sebep delta senkronizasyonu:
maliyet **veli sayısıyla değil, gerçekten gönderilen mesaj sayısıyla**
orantılı.

Bir veli uygulamayı günde 10 kez açsa bile yeni mesaj yoksa **sıfır**
okuma üretir. Uygulamayı hiç açmayan veli de sıfır maliyet.

| Senaryo | Etki |
|---|---|
| Veli sayısı 2× artar | Maliyet ~2× (ama tabandan) |
| Veli uygulamayı 5× daha sık açar | **Maliyet aynı** (delta) |
| Mesajlaşma 2× artar | Maliyet ~2× |

---

## 3. KATILIM VERİSİ VELİYE GÖSTERİLİRSE

Kullanıcı kararsız: *"ders içi katılım istediğim gibi değil, performans
ve kullanılabilirlik açısından."*

**Maliyet tarafı:** Katılım verisi buluta çıkarsa her ders için her
öğrenciye bir kayıt gerekir. 30.000 öğretmen × 25 öğrenci × günde 5 ders
= **3.75 milyon yazma/gün**. Bu, mevcut toplam yazmanın (1.95 milyon)
**iki katı**.

Aylık ek maliyet: **~$200** → toplam ~$440/ay.

Hâlâ reklam gelirinin çok altında ama:

**Öneri: şimdilik göstermeyin.** Gerekçe maliyet değil:
- Modül kullanıcının kendi deyimiyle "istediği gibi değil"
- Yarım bir özelliği veliye açmak, sonra geri almak güven kaybettirir
- KVKK açısından da davranış değerlendirmesi hassas veri

Modül olgunlaştığında tekrar bakılır.

---

## 4. REKLAM GELİRİ

### Altyapı durumu
`lib/core/ads/ad_gate.dart` **zaten yazılmış**, reklam yerleri
tanımlanmış ama **kapalı** ve paket bile eklenmemiş. Faz 7'ye
ertelenmişti.

### Tanımlı reklam yerleri
| Yer | Nerede |
|---|---|
| `parentDashboardBanner` | Veli ana ekranı altında sabit banner |
| `parentAnnouncementFeed` | Veli duyuru listesinde araya giren yerleşim |
| `teacherRewardedExport` | Öğretmen PDF ürettikten sonra **isteğe bağlı** ödüllü |

### Kural: öğrenci verisi görünen ekrana reklam KONULMAZ
Kodda yazılı. Not ekranı, katılım ekranı, öğrenci listesi — hiçbirine
reklam konulmaz. Reklam yalnızca veli tarafında ve öğretmenin isteğe
bağlı ödüllü izlemesinde.

### Gelir tahmini

Türkiye'de eğitim uygulamaları için AdMob banner eCPM aralığı:
**$0.30 – $1.20** (1000 gösterim başına).

Varsayım: veli günde ortalama 1.5 kez açıyor, açılış başına 2 gösterim.

**1000 okul (750.000 veli) — aylık 67.5 milyon gösterim:**

| eCPM | Aylık gelir |
|---|---|
| $0.35 (kötümser) | **$23.600** |
| $0.60 (orta) | **$40.500** |
| $1.00 (iyimser) | **$67.500** |

**50 okul (37.500 veli):**

| eCPM | Aylık gelir |
|---|---|
| $0.35 | **$1.180** |
| $0.60 | **$2.025** |

Maliyet bu ölçekte hâlâ **sıfır** (ücretsiz katman içinde).

### Uyarılar

Bu rakamlar **üst sınır**. Gerçekte:
- Reklam engelleyici kullanan olur
- Veli uygulamayı tahmin edilenden az açabilir
- AdMob doluluk oranı (%100 dolmaz, %70–90 tipik)
- Türkiye eCPM'i mevsimsel dalgalanır

Gerçekçi beklenti: **tablonun %50–70'i**.

Yine de sonuç değişmiyor: **reklam geliri Firestore maliyetini kat kat
karşılıyor.**

---

## 5. ÖNERİLEN YOL

**Faz 1 — İlk 250 öğretmen (~10 okul)**
- Ücretsiz katman yeter, maliyet **$0**
- Reklam **kapalı** kalsın: az kullanıcıda gelir anlamsız, kullanıcı
  deneyimini bozar
- Öncelik: uygulamanın oturması

**Faz 2 — 250–1.000 öğretmen**
- Blaze planına geçilir, aylık **$5–10**
- Kredi kartı bağlanır ama fatura sembolik
- Reklam hâlâ kapalı tutulabilir

**Faz 3 — 1.000+ öğretmen**
- Maliyet **$30–50/ay**
- Reklam açılır: bu ölçekte aylık $1.000+ gelir
- Gelir maliyeti **20 kat** aşar

**Not:** Reklam açmadan önce Play Store veri güvenliği formunda reklam
kimliği kullanımı beyan edilmeli.

---

## 6. FATURA SÜRPRİZİ NASIL ÖNLENİR

- [x] Bütçe freni kurulu (günlük 1500 yazma)
- [x] Tüm sorgular `.limit()` ile sınırlı
- [x] Snapshot listener yasak
- [x] Delta senkronizasyonu çalışıyor
- [x] 365 gün saklama → depolama her yıl sıfırlanır
- [ ] **Firebase konsolunda bütçe uyarısı kurulmalı** (aylık $50'de
      e-posta) — Blaze'e geçerken yapılacak

---

## KAYNAK

Hesaplar `lib/core/cloud/cost_model.dart` içindeki ölçülen değerlerden
üretildi. Blaze fiyatları (2026):
- Yazma: $0.18 / 100K
- Okuma: $0.06 / 100K
- Silme: $0.02 / 100K
- Depolama: $0.18 / GB / ay
