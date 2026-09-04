# SınıfCepte — Proje Denetimi ve Eksikler

**Tarih:** 30 Ağustos 2026
**Kapsam:** 17 modül · 205 Dart dosyası · ~70.500 satır · 449 test
**Hedef:** Türkiye geneli kullanım

Bu dosya eleştirel bir denetimin sonucudur. Her madde "bu neden var, gerçekten
çalışıyor mu, risk taşıyor mu" sorularıyla incelendi. Öncelik sırası:
**A (yayın öncesi zorunlu) · B (ilk sürümde olmalı) · C (sonraya bırakılabilir)**

---

## 0. ÖZET — En kritik beş bulgu

| # | Bulgu | Öncelik |
|---|---|---|
| 1 | 52 metin alanının 14'ünde uzunluk sınırı var (kritik olanlar eklendi) | **A** |
| 2 | Yardım/destek ekranı yazılmış ama hiçbir yerden açılmıyor | **A** |
| 3 | Öğrenci adı buluta gidiyor — KVKK metninde açıkça yazılmalı | **A** |
| 4 | 1500+ satırlık 8 dosya (bakım ve çökme riski) | **B** |
| 5 | Öğretmen profilinde gereksiz "Veli Moduna Geç" düğmesi | **B** |

---

## 1. GİRİŞ VE KİMLİK (auth, auth_profile)

### 1.1 Çözülmüş (bu oturumda)
- Profil anahtarlarında yazma/okuma asimetrisi → kurulum her açılışta soruluyordu
- Veli çıkışında rol sıfırlanmıyordu → öğretmen/veli seçimi çıkmıyordu
- Hesap başına veritabanı (`openForUid`) yazılmış ama çağrılmıyordu
- Okul adı boş kaydediliyordu → MEB listesinden tamamlanıyor

### 1.2 A — Yayın öncesi zorunlu
- [ ] **Öğretmen profilindeki "Veli Moduna Geç" kaldırılacak.**
  Karışıklık yaratıyor: öğretmen kendi hesabıyla veli portalına giriyor ve boş
  ekran görüyor. Veli ayrı hesapla girmeli.
  `lib/features/profile/screens/profile_screen.dart:412`

- [ ] **Hesap silme akışı yok.** KVKK Madde 7 (silme hakkı) gereği kullanıcı
  hesabını ve verilerini silebilmeli. Şu an yalnızca çıkış var.

- [ ] **Google girişi başarısız olursa ne olacağı belirsiz.** Ağ yoksa,
  hesap seçilmezse veya iptal edilirse akışın nereye döndüğü test edilmemiş.

### 1.3 B
- [ ] Masaüstü yerel modda (`local_teacher`) hangi özelliklerin kapalı olduğu
  kullanıcıya tek yerde anlatılmıyor; her ekranda ayrı uyarı çıkıyor.
- [ ] Aynı cihazda 3+ hesap kullanıldığında hesap değiştirme ekranı yok.

---

## 2. VELİ PORTALI (parent_portal — 45 dosya, 15.644 satır)

### 2.1 Çözülmüş (bu oturumda)
- Bulut kimlikleri boş kalıyordu → veli hiçbir şey göremiyordu
- `isParent()` custom claim arıyordu, claim hiç yazılmıyordu → tüm yazmalar reddediliyordu
- Öğretmen tarafında mesaj kutusu yoktu
- Kadro satırı yazılmıyordu → sınıf öğretmeni görünmüyordu
- Bütçe freni 100 yazma/gün idi, tek sınıf ~50 tüketiyordu

### 2.2 A — Yayın öncesi zorunlu
- [ ] **Yardım/Destek ekranı erişilemez.** `help_support_modal.dart` yazılmış
  ama **hiçbir yerden çağrılmıyor**. Veli takıldığında gidecek yeri yok.
  Eklenecek: SSS, "nasıl bağlanırım", "kod çalışmıyor" senaryoları.

- [ ] **Destek talebi hiçbir yere ulaşmıyor.** `HelpSupportModal` içinde
  "Destek Talebini Gönder" düğmesi var ama talep yalnızca **yerel denetim
  günlüğüne** yazılıyor (`KvkkConsentService.logAudit`). Kullanıcı
  gönderdiğini sanıyor, kimse görmüyor. Ya Firestore'a yazılmalı ya da
  e-posta ile açılmalı (`mailto:`).
  `lib/features/parent_portal/presentation/widgets/help_support_modal.dart:209`

- [ ] **Destek e-postası / iletişim adresi tanımlı değil.**
  Türkiye geneli kullanımda destek kanalı olmadan yayına çıkılamaz.

- [ ] **Veli ilk girişte hiçbir yönlendirme almıyor.** Kod nereden gelir,
  ne işe yarar, kaç çocuk eklenebilir — hiçbiri anlatılmıyor.
  Öneri: 3 adımlık tanıtım (onboarding) ekranı.

- [ ] **Mesaj gönderiminde uzunluk sınırı var (4000) ama kullanıcıya
  gösterilmiyor.** Sessizce kırpılıyor.

### 2.3 B
- [ ] Veli telefon numarası isteniyor ama **hiçbir yerde kullanılmıyor**.
  Ya öğrencinin `parentPhone` alanına yazılmalı ya da sorulmamalı.
- [ ] Bildirimler uygulama içi; telefon kapalıyken gelmiyor. Bu sınır
  kullanıcıya açıkça söylenmiyor.
- [ ] Veli aynı çocuğa iki kez bağlanmaya çalışırsa ne olacağı test edilmemiş.
- [ ] Mesaj gönderilirken ağ koparsa mesaj kayboluyor; kuyruk yok.

### 2.4 C
- [ ] Veli birden fazla okulda çocuğu varsa okul bazlı gruplama yok.
- [ ] Mesaj arama yok.

---

## 3. GÜVENLİK VE KVKK

### 3.1 A — Yayın öncesi zorunlu
- [ ] **Öğrenci adı buluta gidiyor.** `parent_tokens`, `parent_links`,
  `class_rooms/*/messages` içinde `studentName` var. Bu bilinçli bir taviz
  (veli kendi çocuğunu görmeli) ama **KVKK aydınlatma metninde açıkça
  yazılmalı**. Şu anki metin "öğrenci verisi buluta aktarılmaz" diyor —
  bu ifade yanıltıcı, düzeltilmeli.
  `lib/features/parent_portal/presentation/views/parent_profile_view.dart:121`

- [ ] **Veri saklama süresi belirsiz.** Durum bildirimleri 30 gün, randevular
  90 gün siliniyor — ama mesajlar ve duyurular **süresiz** duruyor.
  Politika belirlenmeli ve metne yazılmalı.

- [ ] **Açık rıza kaydı var ama gösterilmiyor.** `KvkkConsentService` çalışıyor,
  kullanıcı kendi rıza geçmişini göremiyor.

### 3.2 B
- [ ] `sync/manifest` herkese açık okunabilir (`allow read: if true`).
  İçeriği hassas değil ama gerekçe koda yazılmalı.
- [ ] `parent_tokens` her giriş yapmış kullanıcıya `get` açık. Kodu bilmek
  gerektiği için kabul edilebilir, ama kaba kuvvet koruması yok
  (aynı kullanıcı saniyede 100 kod deneyebilir).
- [ ] Öğretmen dizini artık "aynı okulda kayıtlı olma" kanıtına dayanıyor —
  ama bir öğretmen sahte okul seçip dizini okuyabilir.

---

## 4. VERİ GİRİŞİ VE DOĞRULAMA

### 4.1 A — Yayın öncesi zorunlu
- [x] **Kritik alanlara sınır eklendi** (kurulum, sınıf, duyuru, mesaj).
  DÜZELTME: ilk sayım hatalıydı — `maxLength` aranmıştı ama
  `LengthLimitingTextInputFormatter` sayılmamıştı. Gerçek durum: 52 alandan
  14'ünde sınır vardı, şimdi kritik olanların hepsinde var.

- [ ] **Kalan alanlar** (profil düzenleme, notlar, arama kutuları).
  Kullanıcı 10.000 karakterlik metin yapıştırabilir:
  - Firestore doküman sınırı (1 MiB) aşılabilir
  - Arayüz taşar
  - PDF üretimi bozulur

  Sınır konulacak alanlar: sınıf adı (50), öğrenci adı (60), duyuru başlığı
  (100), duyuru metni (2000), not/açıklama (500), branş (60).

- [ ] **Okul numarası doğrulaması zayıf.** Negatif veya 7 haneli numara
  kabul ediliyor. Sınır: 1–9999.

- [ ] **Telefon doğrulaması yalnızca WhatsApp yolunda var.** Elle girişte
  "abc" kabul ediliyor.

### 4.2 B
- [ ] Türkçe büyük/küçük harf tuzağı: arama alanlarında `toLowerCase()`
  kullanılıyor. `İ` harfi bozuluyor — "İbrahim" araması "ibrahim" bulmuyor.
  `normalizeTr` var ama her yerde kullanılmıyor.
- [ ] Boş sınıf adı, boş öğrenci adı kaydedilebiliyor.
- [ ] Tarih alanlarında geçmiş tarih kontrolü yok (sınav tarihi dün olabilir).

---

## 5. ARAYÜZ, TAŞMA VE UYUMLULUK

### 5.1 A
- [ ] **1517 `Text` bileşeni, yalnızca 185'inde taşma koruması.**
  Uzun isimlerde (özellikle çift soyadlı öğrenciler, uzun okul adları)
  taşma riski. Kullanıcının gördüğü "RIGHT OVERFLOWED BY 4.4 PIXELS"
  hatası bunun kanıtı.

- [ ] **Küçük ekran testi yapılmamış.** 320dp genişlikte (eski Android)
  alt bar 5 sekmeyle sıkışıyor.

### 5.2 B
- [ ] Yatay (landscape) modda hiçbir ekran test edilmemiş.
- [ ] Tablet düzeni yalnızca veli mesajlar ekranında var (720dp kırılımı).
- [ ] Koyu/açık tema geçişinde bazı sabit renkler var
  (`Color(0xFF...)` doğrudan yazılmış yerler).
- [ ] Yazı tipi ölçeği (accessibility) test edilmemiş; büyük yazıda taşma olur.

### 5.3 C
- [ ] Ekran okuyucu (TalkBack) etiketleri yok.
- [ ] Animasyonlar azaltılmış hareket ayarını dinlemiyor.

---

## 6. PERFORMANS

### 6.1 Çözülmüş (bu oturumda)
- `MediaQuery.of(context)` → hedefli izleyiciler (25 kullanım, 14 dosya).
  Klavye açılışında ekranın 60 kez yeniden çizilmesi engellendi.

### 6.2 A
- [ ] **Arama alanları her tuşta `setState` çağırıyor.**
  `SearchDebouncer` yazıldı ama **hiçbir alana bağlanmadı**.
  Bağlanacak: öğrenci listesi, veli rehberi, referans kodları, okul seçimi.

### 6.3 B
- [ ] **8 dosya 1200 satırın üzerinde** (en büyüğü 1787). Bunlar hem bakım
  riski hem de yeniden çizim maliyeti:
  - `classroom_documents_pdf_generator.dart` (1787)
  - `database_helper.dart` (1787)
  - `dashboard_screen.dart` (1728)
  - `my_class_hub_screen.dart` (1643)
  - `participation_cumulative_reports_modal.dart` (1611)
  - `outcome_carousel_card.dart` (1610)
  - `weekly_outcomes_view.dart` (1507)
  - `class_list_screen.dart` (1257)

- [ ] Uzun listelerde `ListView.builder` kullanılıyor mu, kontrol edilmeli.
  110 öğrencilik sınıfta kaydırma performansı ölçülmedi.

---

## 7. MALİYET (Firestore)

### 7.1 İyi durumda
- Canlı dinleyici (`snapshots()`) **hiç kullanılmıyor** — maliyet kararı korunmuş
- Delta senkronizasyonu var (`DeltaSyncTracker`)
- Bildirimler mevcut veriden hesaplanıyor, ek okuma yok
- Bütçe freni var (1500 yazma/gün)

### 7.2 B
- [ ] **Bütçe freni sessizce çalışıyor.** Sınır dolunca yazma reddediliyor
  ama kullanıcı bunu görmüyor. Uyarı gösterilmeli.
- [ ] Okuma sayacı yalnızca logda; sınır aşımında engelleme yok.
- [ ] Bir öğretmenin 10 sınıfı varsa panel açılışında 10× sorgu yapılıyor.
  Toplu sorgu (batch) değerlendirilmeli.

### 7.3 C
- [ ] Firestore ücretsiz katman sınırları (20k yazma/gün) izlenmiyor.
  1000 öğretmen × 50 yazma = 50k/gün → **ücretsiz katman aşılır.**
  Yayın öncesi maliyet projeksiyonu yapılmalı.

---

## 8. MODÜL MODÜL DURUM

### 8.1 Kazanımlar (outcomes — 4272 satır)
**Durum:** Çalışıyor, veri tam (9087 kayıt, 233 ders grubu)
- [ ] B: `outcome_carousel_card.dart` 1610 satır — bölünmeli
- [ ] B: Kazanım arama yok
- [ ] C: Kazanım notları yalnızca yerel; cihaz değişince kayboluyor

### 8.2 Sınıf (classes — 13.483 satır)
**Durum:** Temel akışlar çalışıyor
- [ ] A: Öğrenci silmede veli erişimi kapatılıyor ✓ (bu oturumda eklendi)
- [ ] B: Toplu öğrenci düzenleme yok
- [ ] B: Sınıf silindiğinde öğrencilere ne olduğu belirsiz (cascade var mı?)
- [ ] C: Öğrenci fotoğrafı yok

### 8.3 Ders Programı (schedule — 2878 satır)
- [ ] **İnceleme yapılmadı.** Ayrı bir tur gerekiyor.
- [ ] Çakışma kontrolü var mı?
- [ ] Buluta gidiyor mu, veli görüyor mu?

### 8.4 Ders İçi Katılım (attendance — 7960 satır)
- [ ] **İnceleme yapılmadı.**
- [ ] `seating_participation_grid.dart` ve `quick_attendance_view.dart`
  **hiçbir yerden çağrılmıyor** (yetim dosya)
- [ ] Katılım verisi veliye gösteriliyor mu? Gösterilmeli mi? (KVKK)

### 8.5 Sınav İşlemleri (exam_operations — 5317 satır)
- [ ] **İnceleme yapılmadı.**
- [ ] Sınav notları buluta gidiyor mu? Gitmemeli (KVKK).
- [ ] Not girişinde doğrulama var mı? (0–100 sınırı)

### 8.6 Raporlar (analytics — 4384 satır)
- [ ] **İnceleme yapılmadı.**
- [ ] `exam_analysis_view.dart` yetim dosya

### 8.7 Ana Sayfa (dashboard — 1728 satır)
- [ ] **İnceleme yapılmadı.**
- [ ] 1728 satır tek dosyada — bölünmeli

### 8.8 Admin Paneli (admin_portal)
**Durum:** Çalışıyor (kazanım üretimi, takvim)
- [ ] A: `file://` ile açılıyor — kimlik doğrulama yok, herkes açabilir
- [ ] B: Değişiklikler doğrudan üretim verisine yazılıyor; önizleme yok
- [ ] C: Sürüm geçmişi / geri alma yok

### 8.9 Evraklarım (documents — 164 satır)
- [ ] **Kullanıcı kararı: en sona bırakıldı.** Şu an yalnızca model var.

---

## 9. TEST DURUMU

**449 Flutter testi + 108 kural testi geçiyor.**

### 9.1 Bu oturumda öğrenilen ders
Kural testleri veliye **sahte custom claim** veriyordu; gerçek uygulamada o
claim hiç yazılmıyordu. 108 test geçiyor ama gerçek cihaz `PERMISSION_DENIED`
alıyordu. **Test ortamı gerçekten farklıysa test yalan söyler.**

### 9.2 A
- [ ] Widget testi neredeyse yok — yalnızca `widget_test.dart` (smoke test)
- [ ] Uçtan uca (integration) test yok
- [ ] Taşma testleri yalnızca 2 ekran için var

### 9.3 B
- [ ] `schedule`, `attendance`, `exam_operations`, `analytics` modüllerinde
  test yok denecek kadar az

---

## 10. YAYIN ÖNCESİ KONTROL LİSTESİ

- [ ] Gizlilik politikası ve KVKK metni (hukuki inceleme)
- [ ] Play Store veri güvenliği formu (öğrenci adının buluta gittiği beyan edilmeli)
- [ ] Firestore maliyet projeksiyonu (1000 / 10.000 öğretmen senaryosu)
- [ ] Yedekleme stratejisi (öğretmen telefonunu kaybederse veri gider)
- [ ] Sürüm güncelleme akışı (zorunlu güncelleme mekanizması yok)
- [ ] Çökme raporlama (Crashlytics kurulu değil)
- [ ] `flutter build apk --release` ile test (şu ana kadar hep debug)

---

## 11. ÖNERİLEN SIRA

1. **Bu hafta:** Bölüm 4 (doğrulama) + Bölüm 2.2 (yardım/iletişim) + 5.1 (taşma)
2. **Sonraki:** Bölüm 3 (KVKK metni düzeltmesi) + 6.2 (arama gecikmesi)
3. **Sonra:** İncelenmemiş modüller (schedule, attendance, exam, analytics, dashboard)
4. **En son:** Evraklarım (kullanıcı kararı)
