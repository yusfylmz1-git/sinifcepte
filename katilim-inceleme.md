# Ders İçi Katılım — Kullanılabilirlik İncelemesi

**Tarih:** 31 Ağustos 2026
**Modül:** `lib/features/attendance` — 7.393 satır, 11 dosya

---

## EN GÜÇLÜ BULGU: MODÜL HİÇ KULLANILMAMIŞ

Cihazdaki veritabanı çekildi:

```
participation_sessions    0 kayıt
participation_records     0 kayıt
```

7.393 satır kod yazılmış, tek bir ders bile değerlendirilmemiş.
Kullanıcının *"istediğim gibi değil"* demesi bu veriyle örtüşüyor.

Bu, "biraz iyileştirelim" değil **"baştan kurgulayalım"** işareti.

---

## KÖK SORUN: DERS AKIŞINA UYMUYOR

### Şu anki akış
```
Öğrenciye dokun
  → 962 satırlık diyalog açılır
    → Ödev durumu seç      (4 seçenek)
    → Materyal durumu seç  (2 seçenek)
    → Geliş durumu seç     (2 seçenek)
    → Yıldız seç           (3 seçenek)
    → Etiket seç           (isteğe bağlı)
    → Not yaz              (isteğe bağlı)
  → Kapat
Sonraki öğrenci → tekrar
```

**30 öğrenci = 30 diyalog aç-kapa, en az 120 dokunuş.**

Ders 40 dakika ve öğretmen aynı anda **ders anlatıyor**. Bu akış
öğretmenin telefona gömülmesini gerektiriyor.

### Gerçekte olan
Öğretmen derste şunu yapar: birine söz verir, cevabı iyiyse aklında
tutar, sonra devam eder. Elinde en fazla **iki saniye** vardır.

Uygulama iki saniyelik bir işi iki dakikalık hale getiriyor.

---

## BULGU 2: VARSAYILANLAR YANLIŞ VERİ ÜRETİYOR

`classroom_participation_model.dart` içinde:

```dart
this.homeworkStatus  = HomeworkStatus.done,      // "Yaptı"
this.materialsStatus = MaterialsStatus.ready,    // "Tam"
this.arrivalStatus   = ArrivalStatus.onTime,     // "Vaktinde"
this.starsCount      = 0,                        // "Değerlendirilmedi"
```

Öğretmen hiçbir şey yapmadan kaydederse sistem **"30 öğrencinin hepsi
ödevini yaptı, materyali tam, vaktinde geldi"** diyor.

Bu veri yanlış. Üstelik "Tümüne Tam Puan" düğmesiyle birleşince
(ana sayfada) tek dokunuşla üretiliyor.

**Doğrusu:** varsayılan "bilinmiyor" olmalı. Öğretmen işaretlemediyse
veri yok demektir; "olumlu" demek değil.

---

## BULGU 3: "ADALETLİ KURA" ADALETLİ DEĞİL

`random_student_picker_modal.dart` kendini şöyle tanıtıyor:

> Rastgele Öğrenci Seçici / **Adaletli** Kura Çekme Modalı

Ama kod saf rastgele:

```dart
_selectedStudent = list[_rnd.nextInt(list.length)];
```

Aynı öğrenci üst üste üç kez çıkabilir; bir öğrenci hiç çıkmayabilir.
Bu adalet değil, sadece rastgelelik.

**Oysa bu modülün en değerli fikri bu.** Öğretmenin gerçek derdi
"kime söz verdim, kime vermedim" — ama şu an bunu çözmüyor.

---

## BULGU 4: DEĞERLENDİRME İLE SÖZ HAKKI KARIŞMIŞ

Modül iki ayrı işi tek ekranda yapmaya çalışıyor:

| İş | Ne zaman | Sıklık |
|---|---|---|
| **Söz hakkı takibi** | Ders sırasında | Dakikada birkaç kez |
| **Davranış değerlendirme** | Ders sonunda | Derste bir kez |

Birincisi **anlık ve hızlı** olmalı. İkincisi **sakin ve detaylı**.
İkisini aynı diyaloga koymak ikisini de bozuyor.

---

## BULGU 5: RAPOR MODALI 1.613 SATIR

`participation_cumulative_reports_modal.dart` modülün en büyük dosyası.
Ama hiç veri olmadığı için ne ürettiği belirsiz.

Veri toplanmadan rapor yazmak, ters sıra.

---

## ÖNERİ: İKİYE AYIR

### A. Ders sırasında — "Söz Hakkı" ekranı

Tek amaç: kime söz verdiğini kaydetmek. **Diyalog yok.**

```
5-A · Matematik · 3. ders          [Bitir]
─────────────────────────────────────────
  1  Ahmet Y.         ⭐⭐⭐    (3)
  2  Ayşe K.          ⭐        (1)
  3  Burak T.         ·
  4  Cansu M.         ⭐⭐      (2)
  5  Deniz A.         ·
─────────────────────────────────────────
  Dokun     → +1 söz hakkı
  Uzun bas  → detay (ödev, not)

  [🎲 Sırada kim?]        [✓ Kaydet]
```

- **Tek dokunuş = +1 söz hakkı.** Diyalog açılmaz.
- Uzun basınca mevcut detaylı diyalog açılır (nadiren gerekir)
- Hiç konuşmayan öğrenci **gri nokta** ile görünür — öğretmen
  bir bakışta "kimi atladım" görür

### B. "Sırada kim?" — gerçekten adaletli

`_rnd.nextInt` yerine **en az söz almış** öğrenciler arasından seç:

```
En az söz hakkı olanları bul → aralarından rastgele seç
```

Böylece:
- Kimse üst üste çıkmaz
- Sessiz öğrenci mutlaka sıraya girer
- "Adaletli" iddiası gerçek olur

Bu, öğretmenin en çok işine yarayacak şey: *"bugün kimlerle
konuşmadım?"*

### C. Ders sonu — değerlendirme

Ders bitince tek ekran:
- Söz hakkı sayıları zaten dolu
- Öğretmen yalnızca **istisnaları** işaretler
  (ödevini yapmayan 3 kişi, geç gelen 1 kişi)
- Varsayılan **"bilinmiyor"**, "olumlu" değil

---

## VELİYE GÖSTERME KARARI

Bu haliyle **gösterilmemeli** — modül hiç kullanılmıyor, veri yok.

Yeniden kurgulandıktan ve gerçekten kullanılmaya başladıktan sonra
"bu hafta çocuğunuz 4 kez söz aldı" gibi **basit ve olumlu** bir
gösterim düşünülebilir. Davranış notu ve yıldız veliye gitmemeli:
KVKK açısından hassas, pedagojik olarak da tartışmalı.

---

## MALİYET NOTU

Katılım verisi buluta çıkarsa: 30.000 öğretmen × 25 öğrenci × 5 ders
= **3.75 milyon yazma/gün**, aylık **~+$200**.

Engel değil ama **veri toplanmadan bu maliyeti üstlenmek anlamsız.**

---

## UYGULANDI (31 Ağustos 2026)

Kullanıcı kararı: **A + B + C birlikte.**

### A — Söz hakkı sayacı ✅
- [x] Modele `speakingTurns` alanı eklendi (şema sürüm 15)
- [x] **Tek dokunuş = +1 söz hakkı.** Diyalog artık açılmıyor
- [x] Çift dokunuş = geri al (yanlış öğrenciye basıldığında)
- [x] Uzun bas = eski detaylı diyalog (silinmedi, nadiren gerekiyor)
- [x] Hiç konuşmayan öğrenci **gri nokta** ile görünüyor
- [x] 1–3 arası yıldız, fazlası `⭐×5` biçiminde

**30 öğrenci için ~120 dokunuş → ~15 dokunuş.**

### B — "Sırada kim?" gerçekten adaletli ✅
- [x] `_rnd.nextInt(list.length)` yerine **en az söz almış** havuzdan seçim
- [x] Modal başlığı "Rastgele Öğrenci Seçimi" → **"Sırada Kim Var?"**
- [x] Sınıf yorumundaki "Adaletli Kura" yalanı düzeltildi

Artık sessiz öğrenci mutlaka sıraya giriyor; aynı öğrenci üst üste çıkamıyor.

### C — Ders sonu ✅
- [x] Varsayılanlar `unknown` oldu: işaretlenmemiş alan artık
      "yaptı/tam/vaktinde" değil **"bilinmiyor"**
- [x] PDF'te işaretlenmemiş alan `-` görünüyor
- [x] **Materyal hatası düzeltildi:** `!= ready` yazılıydı, işaretlenmemiş
      öğrenci raporda "Eksik" görünüyordu — haksız suçlama
- [x] Kaydet mesajı ders özeti veriyor:
      *"5-A kaydedildi · 12 öğrenci söz aldı, 18 öğrenci hiç konuşmadı"*

### Doğrulama
- [x] 17 test (`participation_redesign_test.dart`)
- [x] Derleyici üç yerde eksik `switch` yakaladı (grid, provider, PDF)
- [x] Gerçek cihazda şema sürüm 15 ve `speaking_turns` sütunu doğrulandı

### Kalan
- [ ] Gerçek derste deneme — asıl sınav bu
- [ ] `participation_cumulative_reports_modal.dart` (1.613 satır) hâlâ
      veri toplanmadan yazılmış; söz hakkı verisi birikince bakılmalı

---

## SIRADAKİ ADIM

Karar sizin:

1. **Yeniden kurgula** — A + B + C yukarıdaki gibi
2. **Sadece "Sırada kim?" düzelt** — en küçük dokunuş, en çok fayda
3. **Şimdilik dokunma** — başka öncelikler varsa
