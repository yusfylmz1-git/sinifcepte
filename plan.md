# SınıfCepte — Yol Haritası

**Tarih:** 30 Ağustos 2026
**Dayanak:** `eksikler.md` (denetim bulguları)
**Hedef:** Türkiye geneli yayına hazır sürüm

Bu dosya "ne yapılacak" değil, **"hangi sırayla, nasıl ve neden"** anlatır.
Her madde bitince kutusu işaretlenir ve altına ne yapıldığı yazılır.

---

## KURAL: Her değişiklikte

1. Önce hatayı kanıtlayan test yaz
2. Düzelt
3. Düzeltmeyi geri alıp testin kırmızıya döndüğünü doğrula
4. Gerçek cihazda dene (`adb install`)

Bu oturumda öğrenilen ders: **test ortamı gerçekten farklıysa test yalan
söyler.** Kural testleri veliye sahte custom claim veriyordu; 108 test
geçiyordu ama gerçek cihaz `PERMISSION_DENIED` alıyordu.

---

## FAZ 1 — Yayın engelleyiciler (1–2 hafta)

Bunlar bitmeden yayına çıkılmaz.

### 1.1 Veri girişi güvenliği ✅ TAMAM
**Sayım düzeltmesi:** Denetimde "52 alanın 2'sinde sınır var" yazmıştım;
doğrusu **87 alan, 27'sinde sınır** (iki ayrı yöntem kullanılıyor:
`maxLength` ve `LengthLimitingTextInputFormatter`). Kalan 60 alanın çoğu
arama kutusu — hiçbir yere kaydedilmiyor, risk taşımıyor.

Kaydedilen ya da PDF'e/buluta giden **tüm** alanlar artık sınırlı:
- [x] Duyuru başlığı (100), duyuru metni (2000), mesaj (4000 + sayaç)
- [x] Sınıf adı (50), ders (60), yıl (12), açıklama (300) — zaten vardı
- [x] Öğrenci ad/soyad (30+30), okul no (5 hane) — zaten vardı
- [x] Öğretmen profili: ad (40), soyad (40), branş (60), müdür adı (80),
      e-posta (120)
- [x] Veli davetiyesi: tarih (20), saat (10), yer (80), gündem (200),
      alt not (300)
- [x] Veli toplantısı: tarih (20), saat (10), yer (80)
- [x] Gezi/görüşme formu: etkinlik adı (100), yer (80), tarih (20)
- [x] Sınıf kuralları (120 — PDF'te satır satır basılıyor)
- [x] Sınav işlemleri: sınav adı (80), sınıf (20), kolon başlığı (40),
      ödev konusu (100), not alanı (3 hane)
- [x] 13 test (`input_limits_test.dart`)

**Okul numarası notu:** Plandaki "1–9999" fazla dar. MEB numaraları 4
haneyi aşabiliyor; 5 hane sınırı korundu. Boş/sıfır/mükerrer kontrolü
zaten vardı.

**Kalan (karar gerektiriyor):**
- [ ] Telefon: elle girişte biçim doğrulaması (`PhoneFormatter` var,
      bağlanacak) — **veli telefonu kararına bağlı** (6 numaralı karar)

### 1.2 Destek kanalı ✅ TAMAM
**Karar: destek e-postası `sinifcepte@gmail.com`**

**Sorun neydi:** `HelpSupportModal` "Destek Talebini Gönder" diyor,
ardından "Talepleriniz en geç 24 saat içinde incelenir ve yanıtlanır"
vaat ediyordu. Gerçekte talep **yalnızca cihazdaki yerel denetim
günlüğüne** yazılıyordu — kimse görmüyordu. Kullanıcı yardım istediğini
sanıyor, karşılığında hiçbir şey olmuyordu.

- [x] Yardım ekranı öğretmen ve veli profillerine bağlandı
- [x] `support_request.dart` + `support_repository.dart`: talep artık
      Firestore'daki `support_requests` koleksiyonuna yazılıyor
- [x] Kimlik `CommunicationIds.supportRequest` ile üretiliyor — aynı anda
      gönderen iki kullanıcı birbirinin talebini ezmiyor
- [x] Giriş sınırları: başlık 120, açıklama 2000 karakter
- [x] Cihaz/platform bilgisi kayda ekleniyor (hatayı tekrar üretmek için)
- [x] **Yanlış vaat kaldırıldı.** "24 saat içinde yanıtlanır" yerine
      gerçek e-posta adresi gösteriliyor.
- [x] **E-posta yedek yolu.** Bulut yazımı başarısız olursa (ağ yok,
      bütçe freni) kullanıcıya "gönderildi" denmiyor; ön doldurulmuş
      bir `mailto:` taslağı sunuluyor. E-posta uygulaması yoksa adres
      kopyalanabilir şekilde gösteriliyor.
- [x] 21 test (`support_request_test.dart`)

**Güvenlik kuralları (`support_requests`) — canlıya dağıtıldı:**
- Okuma **yalnızca kendi talebi için**. Kullanıcı "Taleplerim"
  ekranında gönderdiği talebi ve cevabı görür; başkasınınkini göremez.
  *(İlk yazımda okumayı tamamen kapatmıştım — o zaman "Taleplerim"
  ekranı hiç çalışmazdı. KazanımCEP'te böyle bir ekran olduğunu görünce
  düzelttim.)*
- Herkes yalnızca **kendi adına** talep açabilir (`userId == auth.uid`)
- `status` istemciden `open` dışında gelemez — kullanıcı kendi talebini
  "çözüldü" işaretleyemez
- Gönderilmiş talep **değiştirilemez ve silinemez**: yanıtlanmış bir
  talep sonradan değiştirilirse yazışma anlamsızlaşır
- Uzunluk sınırları kural katmanında da zorunlu (istemci atlanabilir)
- [x] 11 kural testi eklendi (toplam **119/119 geçiyor**)

**Test altyapısı düzeltmesi:** `run-tests.ps1` JDK'yı bulamıyordu —
eski bir Claude oturumunun geçici klasöründeki yolu hatırlıyordu ve o
klasör silinmişti. Artık **Android Studio'nun paketlediği JDK** da
aranıyor (Flutter'ın kullandığı JDK; klasör adı "Android Studio1"
olabildiği için desenle aranıyor) ve geçici klasör **en sona** bırakıldı.
Ayrıca yalnızca `java.exe` varlığı yetmiyor; `lib/jvm.cfg` de kontrol
ediliyor — yarım inen bir JDK'da `java.exe` durur ama çalışmaz ve
emülatör "Java kurulu değil" gibi yanıltıcı hata verirdi.

**Kalan:**
- [ ] SSS içeriği yazılsın: "kod çalışmıyor", "öğretmenimi göremiyorum",
      "mesajım gitmiyor", "çocuğumu nasıl eklerim"
- [ ] Talepleri okumak için yönetici arayüzü (şu an Firebase konsolundan
      okunuyor — başlangıç için yeterli)

### 1.3 KVKK metni düzeltmesi ✅ BÜYÜK ÖLÇÜDE TAMAM

**Yanlış beyan düzeltildi.** Veli profilindeki metin *"öğrenci
bilgilerini öğretmenin cihazında saklar; bu veriler buluta aktarılmaz"*
diyordu. **Bu doğru değildi:** `studentName` en az üç koleksiyonda buluta
gidiyor (veli bağlantıları, mesajlar, durum bildirimleri). Yanlış beyan
hukuki risk taşır.

- [x] Metin kodla doğrulanarak yeniden yazıldı; hangi verinin nereye
      gittiği tek tek sayıldı
- [x] **Cihazda kalanlar:** notlar, katılım, devamsızlık, quiz/proje
      puanları, veli telefonu, öğrenci numarası, ders programı,
      oturma planı
- [x] **Buluta gidenler:** öğrenci adı-soyadı, sınıf/okul adı, öğretmen
      bilgisi, veli adı ve yakınlık, mesaj/duyuru içerikleri, randevu ve
      durum bildirimleri, destek talepleri
- [x] Saklama süreleri yazıldı (bildirim 30, randevu 90 gün)
- [x] KVKK md. 11 hakları ve hesap silme yolu eklendi
      (`sinifcepte@gmail.com`, 30 gün içinde)
- [x] MEB ile kurumsal bağı olmadığı açıkça belirtildi
- [x] 13 test (`legal_documents_test.dart`) — biri "buluta aktarılmaz"
      ifadesinin geri gelmesini engelleyen bekçi

**Kalan:**
- [ ] **Mesaj ve duyuru saklama süresi** (karar bekliyor). Metinde şu an
      "belirlenme aşamasındadır" yazıyor; karar verilince güncellenecek.
- [ ] Hukuki inceleme (avukat okuması)

### 1.4 Taşma koruması ✅ BÜYÜK ÖLÇÜDE TAMAM
**Yöntem:** Ham `Text` sayısı yanıltıcıydı. Bunun yerine **kullanıcının
yazdığı veriyi** (öğrenci/veli/öğretmen/sınıf/okul/ders adı) gösteren
`Text` çağrıları tarandı: 50 aday bulundu.

Bunların çoğu **diyalog gövdesi, SnackBar ve PDF metni** — bunlar serbestçe
satır kaydırıyor, taşma riski yok. Gerçek risk taşıyan, yani dar bir
`Row`/kart düzeninde iki kullanıcı metnini yan yana koyanlar düzeltildi:
- [x] Veli: çocuk kartı (sınıf + no), bağlı çocuk listesi (ad + sınıf),
      randevu satırı (öğretmen adı)
- [x] Öğretmen: randevu kartı (öğrenci + veli + yakınlık), referans kodu
      başlığı (öğrenci adı)
- [x] Evraklarım: öğretmen adı + branş, **okul adı + müdür adı**
      (uzun MEB adları en riskli durumdu)
- [x] Sınav analizi başlığı (sınıf + ders)
- [x] Ana sayfa canlı ders kartı (sınıf + ders) — Faz 2.5'te bulundu
- [x] 9 test (`overflow_source_guard_test.dart`), regresyon doğrulandı

**Kalan:**
- [ ] 320dp genişlikte gerçek cihaz testi (eski Android)
- [ ] Büyük yazı tipi ölçeğinde test (erişilebilirlik)
      → ikisi de telefon bağlanınca

### 1.5 Maliyet projeksiyonu ✅ TAMAM
Tahmin yerine **koddaki gerçek işlem sayılarını** okuyan bir hesaplayıcı
yazıldı (`lib/core/cloud/cost_model.dart`). Mimaride bir şey bozulup
okuma/yazma patlarsa testler kırılır.

**Sonuç — ücretsiz katman ~250 öğretmene kadar yetiyor:**

| Öğretmen | Veli | Yazma/gün | Okuma/gün | Durum |
|---|---|---|---|---|
| 100 | 2.500 | 6.500 | 19.700 | ✅ rahat |
| 100 (yoğun gün) | 2.500 | 11.100 | 26.100 | ✅ hâlâ sığıyor |
| 1.000 | 25.000 | 65.000 | 197.000 | ❌ aşıyor |
| 10.000 | 250.000 | 650.000 | 1.970.000 | ❌ Blaze şart |

Ücretsiz katman sınırları: 20.000 yazma / 50.000 okuma (gün).

- [x] **Blaze eşiği: ~250 öğretmen.** Yazma 307'de, okuma 253'te doluyor —
      ikisi dengeli, yani hiçbir taraf optimize edilmeden kalmamış.
- [x] 9 test (`cost_model_test.dart`)

**İlk hesabım yanlıştı, düzeltildi:** Önce her tazelemenin 70 doküman
okuduğunu varsayıp "5 öğretmende dolar" sonucuna varmıştım. Ama
`DeltaSyncTracker` son çekim damgasını kalıcı tutuyor ve sorgulara `since`
olarak geçiriyor — **yeni bir şey yoksa sorgu sıfır doküman okuyor.**
Doğru sayı 250. Bu, projedeki en değerli maliyet kararı; testte de
işaretlendi ki biri `since`'i kaldırırsa fark edilsin.

- [x] **Bütçe freni artık sessiz değil:** fren devredeyken kullanıcıya
      "İnternet bağlantınızı kontrol edin" deniyordu — yanlış ve
      kullanıcıyı boşuna uğraştıran bir mesaj. Artık "Günlük mesaj
      sınırına ulaşıldı, yarın tekrar deneyin" diyor.

---

## FAZ 2 — İncelenmemiş modüller (2–3 hafta)

Her biri ayrı tur. Denetim sırasında yalnızca yüzeysel bakıldı.

### 2.1 Ders Programı (schedule — 2.878 satır) ✅ İNCELENDİ
**Bulgular:** Çakışma kontrolü var ✓ · Buluta gitmiyor ✓ · Hesap ayrımı sorunsuz ✓
- [x] **BUG DÜZELTİLDİ:** Günlük ders sayısı azaltılınca sınır dışı dersler
      veritabanında kalıyor ama tabloda görünmüyordu — öğretmen için
      "kayboluyor", sayı geri artırılınca aniden geri geliyordu.
      Artık uyarı gösteriliyor (silinmiyor, haber veriliyor).
- [x] 6 test eklendi (`schedule_test.dart`)
- [ ] PDF üretimi test edilsin
- [ ] Veli programı görmeli mi? (karar gerekiyor)

### 2.2 Ders İçi Katılım (attendance — 7.960 satır) ✅ İNCELENDİ
**EN CİDDİ BULGU DÜZELTİLDİ:** Değerlendirme yalnızca "Kaydet" düğmesiyle
yazılıyordu ve **çıkış koruması yoktu**. Öğretmen 30 öğrenciyi değerlendirip
geri tuşuna basınca hepsi SESSİZCE kayboluyordu.
- [x] Kirli durum takibi eklendi (16 değişiklik noktası işaretleniyor)
- [x] `PopScope` ile çıkış koruması + onay diyalogu
- [x] Kayıt başarılı olunca bayrak temizleniyor
- [x] 6 test eklendi (`attendance_guard_test.dart`)

**Ön bulgu:** Buluta gitmiyor ✓ · **4 yetim dosya var (1440 satır ölü kod)**
- [ ] `seating_participation_grid.dart` — hiçbir yerden çağrılmıyor
- [ ] `quick_attendance_view.dart` — hiçbir yerden çağrılmıyor
- [ ] `compact_participation_roster.dart` — hiçbir yerden çağrılmıyor
- [ ] `daily_stars_celebration_dialog.dart` — hiçbir yerden çağrılmıyor
- [ ] Karar: bunlar bağlanacak mı, silinecek mi?
- [x] Katılım verisi veliye gösterilmeli mi? → **HAYIR** (gelir gelene
      kadar). Yerine toplu duyuru geldi; bkz. Karar 3.

### 2.3 Sınav İşlemleri (exam_operations — 5.317 satır) ✅ İNCELENDİ
**Bulgular:** Notlar buluta gitmiyor ✓ (KVKK açısından doğru).
`exam_sync_service.dart` adına rağmen **tek yönlü**: resmî MEB sınav
takvimini yerel asset'ten SQLite'a alıyor, dışarı veri göndermiyor.

**BULGU 1 — Not girişinde iki sessiz veri kaybı (DÜZELTİLDİ):**
Not `int.tryParse` + `clamp(0, 100)` ile okunuyordu. Bu ikili üç ayrı
durumu tek sonuca indirgiyordu ve ikisi **sessizce yanlış** sonuç üretiyordu:
- `"abc"` → null → mevcut not **hiçbir uyarı olmadan siliniyordu**.
  Öğretmen 85'lik notu düzeltmek için açıp yanlış tuşa basınca not gidiyordu.
- `"955"` → 100 olarak kaydediliyordu. 95 yazmak isteyen öğretmen 100
  verdiğini fark etmiyordu — yanlış not doğruymuş gibi duruyordu.
- [x] `score_input.dart`: üç durumu ayıran çözümleyici (boş / geçerli /
      aralık dışı / sayı değil)
- [x] Kırpma kaldırıldı: aralık dışı giriş **reddedilir**, diyalog açık kalır
- [x] Sayı olmayan giriş artık notu silmiyor, "Notu Sil" düğmesine yönlendiriyor
- [x] `digitsOnly` süzgeç (Android klavyesi sayı modunda bile `-` gösteriyor)
- [x] Sağlayıcıdaki `clamp` → reddetme (bozuk değer artık görünür)
- [x] 12 test (`score_input_test.dart`)

**BULGU 2 — Okul sınavının sınıfı yanlış sütuna yazılıyordu (DÜZELTİLDİ):**
`addSchoolExam` sınıf adını `basvuru_linki` sütununa yazıyordu ama model
onu `sinif` sütunundan okuyordu — tabloda `sinif` sütunu **hiç yoktu**.
- Kartın üzerinde öğretmenin seçtiği sınıf yerine hep "Okul" yazıyordu
- Ekran dolu bir "başvuru linki" görüp tıklanabilir bağlantı çiziyor,
  dokununca "5-A"yı adres olarak açmaya çalışıyordu
- [x] Şema sürüm 13: `kisisel_sinavlar.sinif` sütunu eklendi
- [x] Göç: eski kayıtlarda yanlış sütundaki sınıf adı taşınıyor;
      `http` ile başlayan gerçek linkler korunuyor
- [x] 5 test (`school_exam_class_test.dart`)

**BULGU 3 — Kolon silinince notlara ne oluyor? (DOĞRULANDI):**
`ON DELETE CASCADE` çalışıyor — sqflite'ta yabancı anahtarlar varsayılan
olarak KAPALI ama `_onConfigure` pragmayı açıyor. Öksüz not kalmıyor.
- [x] 3 test (`quiz_cascade_test.dart`) — biri pragma unutulursa ne olacağını
      gösteren regresyon bekçisi
- [x] Silme onayı artık **kaç not** gideceğini yazıyor ("tüm notlar" yerine)

**Giriş sınırları (Faz 1.1'e sayılır):** sınav adı 80, sınıf 20 (iki alan),
kolon başlığı 40, ödev konusu 100, not alanı 3 hane.

**Kalan (acil değil):**
- [ ] `quiz_list_view.dart` 1217 satır — bölünmeli
- [ ] Rubric ekranı `/10` ve `[10, 8, 5, 0]` değerlerini sabit kodluyor ama
      `kriter.maxScore` gerçek bir alan. Şu an tüm kriterler 10 puan olduğu
      için sorun çıkmıyor; özel kriter eklenirse "20/10" gibi görünür.

### 2.4 Raporlar (analytics — 4.384 satır) ✅ İNCELENDİ
**Bulgular:** Buluta gitmiyor ✓ · İstatistik formülleri (ortalama, medyan,
standart sapma, başarı yüzdesi, soru oranları) **doğru yazılmış** —
hepsi tutarlı biçimde `!isAbsent` süzgecini kullanıyor.

**BULGU 1 — Sınava girmeyen öğrenci raporları bozuyordu (DÜZELTİLDİ):**
`isAbsent` modelde **10 yerde okunuyordu** ama öğretmenin onu
işaretleyebileceği **hiçbir arayüz yoktu**. Düzenleyici her öğrenciyi
`totalScore: 0.0` ile başlatıyor, boş alan `?? 0.0` ile 0 oluyordu.
Sınava girmeyen öğrenci **gerçek bir 0 gibi** sayılıyordu.

30 kişilik sınıfta 2 girmeyen öğrencinin ölçülen etkisi:
| Değer | Doğru | Rapordaki |
|---|---|---|
| Ortalama | 70.00 | **65.33** (4.67 puan sapma) |
| Başarı yüzdesi | %100 | **%93.3** |

Ayrıca en düşük puan 0 görünüyor, standart sapma şişiyor, not
dağılımında "Geçersiz" kutusu doluyor ve **her soru olduğundan zor
görünüyordu** (soru başarı oranları girmeyenin 0'larıyla hesaplanıyordu).
- [x] Her öğrenci satırına "sınava girmedi" düğmesi eklendi
- [x] İşaretlenince puan alanı kilitleniyor ve girilmiş puan temizleniyor
- [x] Kalıcılık: negatif işaret değeriyle diske yazılıyor (şema değişmedi;
      `fromMap` zaten `total < 0` okuyordu, geçerli puan negatif olamaz)
- [x] İşaret arayüze sızmıyor: girmeyenin puanı 0 görünür ama hiçbir
      istatistiğe katılmaz
- [x] Detay ekranı: "0 Puan / kırmızı" yerine "Girmedi / gri"
- [x] Puana göre sıralamada girmeyenler en sona (gerçekten düşük alanlarla
      karışmıyorlar)
- [x] **PDF:** idareye verilen belgede artık "0 / KALDI" yerine "- / GİRMEDİ"
- [x] 14 test (`exam_absence_test.dart` 11 + `exam_absence_roundtrip_test.dart` 3)
- [x] Düzeltme geri alınıp testlerin kırmızıya döndüğü doğrulandı (4 test)

**BULGU 2 — Yayında "Örnek Not" düğmesi (DÜZELTİLDİ):**
Not giriş ekranında, gerçek not alanlarının hemen yanında duran bu düğme
**tek dokunuşla 30 öğrencinin gerçek notunu uydurma puanlarla eziyordu** —
onay yok, geri alma yok, `kDebugMode` koruması yok.
- [x] Yalnızca geliştirme derlemesinde görünür

**Not:** `sinavlar.ortalama` sütunu diske yazılıyor ama hiçbir yerde
okunmuyor (`fromMap` her zaman öğrenci satırlarından yeniden hesaplıyor).
Zararsız; şema değiştirmeye değmez.

**Kalan:**
- [ ] PDF çıktısı gerçek cihazda gözle kontrol edilsin
- [ ] `exam_analysis_view.dart` (378 satır, `exam_operations` altında) yetim —
      gerçek analiz `analytics` modülünde. Silinsin mi? (karar bekliyor)

### 2.5 Ana Sayfa (dashboard — 1.728 satır) ✅ İNCELENDİ
**Açılış performansı sorunsuz:** İzlenen 6 sağlayıcının hepsi boş
durumla başlayıp veriyi arka planda yüklüyor — ana sayfa hemen çiziliyor,
hiçbir şey ilk boyamayı bloke etmiyor. Doğru desen.

**BULGU 1 — "Şu an bu derstesiniz" kartı hiç tazelenmiyordu (DÜZELTİLDİ):**
Aktif ders tespiti düz bir `FutureProvider` idi ve **hiçbir zaman
yeniden hesaplanmıyordu**. Ana sayfa `IndexedStack` içinde oturum boyunca
ekranda kaldığı için sabah hesaplanan ders akşama kadar öyle kalıyordu:
- 08:30'da açan öğretmen "1. ders · 5-A Matematik" kartını görüyor
- 11:00'de başka sınıftayken kart **hâlâ 5-A / 1. ders** diyor
- Kartın üzerindeki **"Tümüne Tam Puan (3 ⭐)"** düğmesi o eski sınıf ve
  ders saatine yazıyor — tek dokunuş, onay yok, geri alma yok

Bu ikisi birleşinceki sonuç: öğretmen kendi sınıfını değerlendirdiğini
sanırken **başka bir sınıfın sabahki dersine** tam puan yazıyordu.
- [x] `lesson_clock.dart`: zamanla ilerleyen 5 dakikalık dilim anahtarı
- [x] Sağlayıcı dilimi izliyor — dilim değişince kendiliğinden yenileniyor
- [x] Gün de anahtara katılıyor (gece yarısını geçen oturumda dünkü ders kalmaz)
- [x] Ekranda saniyelik zamanlayıcı **yok**: 1728 satırlık ağaç günde ~96 kez
      yeniden çiziliyor, saniyede bir değil
- [x] 12 test (`lesson_clock_test.dart` 9 + `lesson_clock_stream_test.dart` 3)
- [x] Gün anahtarı kaldırılıp testlerin kırmızıya döndüğü doğrulandı (2 test)

**BULGU 2 — "Tümüne Tam Puan" onaysiz yazıyordu (DÜZELTİLDİ):**
- [x] Onay diyalogu eklendi; hangi sınıfa ve kaçıncı derse yazılacağı yazıyor

**BULGU 3 — Taşma (DÜZELTİLDİ):**
- [x] Canlı ders kartındaki `'$className • $subjectName'` korumasızdı;
      ikisi de öğretmenin yazdığı serbest metin, uzun ders adı dar ekranda
      taşıyordu. `maxLines` + `ellipsis` eklendi.
- Zaman çizelgesi ve öğretmen adı zaten korumalıydı ✓

**Kalan (acil değil):**
- [ ] Tek dosya 1728 satır, 11 `_build*` metodu — bölünmeli. Metotlar ayrı
      widget sınıfı olmadığı için her sağlayıcı değişimi tüm ağacı yeniden
      çizdiriyor. Şu anki tazeleme sıklığında sorun değil.

---

## FAZ 3 — Kullanım kolaylığı (1–2 hafta)

### 3.1 Veli ilk kullanım ⬜
- [ ] 3 adımlık tanıtım: "kod nereden gelir", "ne görebilirim", "nasıl yazarım"
- [ ] Boş durumlarda yönlendirme (şu an bazıları sessiz)
- [ ] Veli telefonu: ya kullanılsın (öğrencinin `parentPhone`'una yazılsın)
      ya da sorulmasın

### 3.2 Öğretmen kullanım kolaylığı ✅ BÜYÜK ÖLÇÜDE TAMAM
- [x] Sınıfım sayfası bölümlere ayrıldı (Veli İletişimi · Sınıf Yönetimi)
- [x] "Veli Moduna Geç" kaldırıldı

**Arama gecikmesi bağlandı.** `SearchDebouncer` yazılmıştı ama **hiçbir
yere bağlanmamıştı** — yani klavye yavaşlığı düzeltilmiş görünüyordu,
aslında düzeltilmemişti. Dört büyük ekrana bağlandı:
- [x] Öğrenci listesi (1114 satır), Veli rehberi (1173 satır),
      Referans kodları modalı (1111 satır), Karne yorumları modalı (974 satır)
- [x] Hepsinde `dispose()` de eklendi — bekleyen zamanlayıcı ekran
      kapandıktan sonra `setState` çağırırsa hata düşerdi. (Bu eksiği
      testin kendisi yakaladı: veli rehberinde `dispose` unutulmuştu.)
- [x] 8 test (`search_debounce_test.dart`)

**BULGU — Türkçe arama öğrenciyi bulamıyordu (DÜZELTİLDİ):**
Tüm arama kutuları `toLowerCase()` kullanıyordu. Öğretmen telefon
klavyesinde **Türkçe karakter yazmadan** aradığında öğrenci bulunamıyordu:
- "Isil" yazınca **"Işıl Demir" çıkmıyordu**
- "Gulsah" yazınca "Gülşah Yılmaz" çıkmıyordu
- "Cagri" yazınca "Çağrı Öztürk" çıkmıyordu

Bu, hızlıca arama yapan öğretmen için "öğrenci kayıp" demek.
- [x] `turkish_text.dart`: `trFold` + `trContains` (tek kaynak)
- [x] Aynı katlama `teacher_branches.dart` içinde özel kopya olarak
      duruyordu; ortak yardımcıya taşındı
- [x] Bağlandığı yerler: öğrenci listesi, veli rehberi, referans kodları,
      karne yorumları, oturma planı, katılım kümülatif raporu, kompakt
      katılım ızgarası, **okul seçimi** (uzun MEB adları)
- [x] 16 test (`turkish_search_test.dart`), regresyon doğrulandı (5 test kırmızı)

**Not:** Sınav analizi listesi ve analitik panosu hâlâ `toLowerCase`
kullanıyor ama orada aranan şey sınav/ders adı (öğrenci değil) ve
öğretmenin kendi yazdığı metin — risk düşük, dokunulmadı.

**Profil menüsü düzenlendi (31 Ağustos 2026):**
Kullanıcı, KazanımCEP'in yan menüsünü örnek göstererek bizimkinin
dağınık olduğunu söyledi. Karşılaştırma yapıldı; iki gerçek eksik
bulundu ve ikisi de **yayın engelleyiciydi**:
- [x] **Hakkında ekranı** eklendi: Puan Ver · Kullanım Koşulları ·
      Gizlilik Politikası · Sıkça Sorulan Sorular
- [x] Kullanım Koşulları ve Gizlilik Politikası **hiçbir yerde
      görünmüyordu** — Play Store bunları zorunlu tutuyor
- [x] SSS yazıldı: denetimde belirlenen dört soru ("kod çalışmıyor",
      "öğretmenimi göremiyorum", "mesajım gitmiyor", "çocuğumu nasıl
      eklerim") + notların neden görünmediği + hesap silme

**Ölü kod temizlendi:** 4 yetim dosya silindi (1.228 satır). Dördü de
eski sürümdü; aynı iş için daha gelişmiş dosyalar zaten kullanılıyordu.
`daily_stars_celebration_dialog.dart` (212 satır) **bırakıldı** — o bir
eski sürüm değil, hiç bağlanmamış bir özellik (ders sonu "günün
yıldızları" tebriği); ileride bağlanabilir.

**Kalan:**
- [ ] İlk açılışta kısa tanıtım

### 3.3 Erişilebilirlik ⬜
- [ ] Yatay mod testi
- [ ] Tablet düzeni (şu an yalnızca veli mesajlarda)
- [ ] Ekran okuyucu etiketleri

---

## FAZ 4 — Altyapı ve yayın (1 hafta)

### 4.1 Çökme raporlama ✅ TAMAM
Uygulama çökünce **hiçbir kaydı kalmıyordu**: öğretmen "kapandı" diyor,
elimizde ne yığın izi ne hangi ekranda olduğu bilgisi vardı.

- [x] `firebase_crashlytics` eklendi + Gradle eklentisi
- [x] `crash_reporter.dart`: `FlutterError.onError` (çatı içi) ve
      `PlatformDispatcher.onError` (asenkron) yakalanıyor
- [x] **Tampon mekanizması.** `main()` hızlı açılış için Firebase'i
      `runApp`'ten SONRA başlatıyor; ilk anlarda Crashlytics hazır değil.
      Ama en kritik hatalar tam orada oluyor (açılışta çökme). Hatalar
      Firebase hazır olana kadar tamponlanıyor, sonra gönderiliyor.
- [x] Tampon 20 kayıtla sınırlı — hata döngüsüne giren kod belleği şişirmesin
- [x] `kDebugMode`'da rapor gönderilmiyor (geliştirme hataları üretim
      istatistiğini kirletmesin)
- [x] Raporlayıcı hiçbir durumda uygulamayı düşürmüyor
- [x] 7 test (`crash_reporter_test.dart`)

### 4.2 Release derlemesi ✅ ÇALIŞIYOR
- [x] `flutter build apk --release` başarılı (83.8 MB)
- [x] **Karşılaşılan hata çözüldü:** Crashlytics Gradle eklentisi 3,
      google-services **4.4.1+** istiyor; projede 4.3.15 vardı.
      4.4.2'ye yükseltildi.
- [x] Crashlytics'in APK'ya gerçekten girdiği doğrulandı (classes.dex
      içinde 112 referans)

**⚠ Yayın engeli:** `android/app/build.gradle.kts` release derlemesini
hâlâ **debug anahtarıyla** imzalıyor (`signingConfig = debug`). Play
Store'a bu hâliyle yüklenemez. Gerçek imzalama anahtarı sizin
oluşturmanız gereken bir şey (parola içeriyor, repoya girmemeli).

### 4.3 APK boyutu ve Maarif icerigi ✅ TAMAM

**KARAR: icerik kullanilsin.** Uygulandi.

**Maarif icerigi artik kartlara ulasiyor:**
Kazanim JSON'u 34 alan tasiyordu ama `curriculum_outcomes` tablosunda 15
sutun vardi ve tohumlama elle esleme yapiyordu. Ders ozeti, resmi
etkinlik, degerler, beceriler, farklilastirma ve kazanim parcalari APK
ile tasiniyor, acilista ayristiriliyor ve **atiliyordu**.
`outcome_carousel_card.dart` icindeki "MAARIF DERS OZETI" paneli
uygulamanin **ilk gununden beri bos** goruntuleniyordu (git gecmisi
dogrulandi: `maarif_summary` sutunu hicbir commit'te olmamis).

- [x] Sema surum 14: 14 yeni sutun eklendi
- [x] Goc mevcut satirlari temizliyor ki yeni alanlarla yeniden tohumlansin
- [x] Tohumlama artik elle esleme yapmiyor: `fromJson` -> `toMap`
      (modelin kendi serilestirmesi kullaniliyor)
- [x] **`category` sutunu da eksikmis** — `toMap()` onu yaziyordu ama
      tabloda yoktu; her insert hata verecekti. Test yakaladi (8 test kirmizi).
- [x] 9 test (`maarif_content_test.dart`)

**Varlik sikistirma:**
- [x] `tool/compress_assets.dart` + `GzipAsset.loadString`
- [x] `pubspec.yaml` artik klasor jokeri kullanmiyor; yalnizca `.json.gz`
      paketleniyor (joker kullanilsaydi her iki surum de APK'ya girer,
      kazanc sifirlanirdi)
- [x] **34.5 MB → 2.6 MB**
- [x] 9 test (`gzip_asset_test.dart`) — Turkce karakter bozulmasi dahil

**⚠ TESHISIM YANLISTI, DUZELTILDI:**
"APK 83.8 MB cunku assets 36 MB" demistim. Sikistirmadan sonra APK
**yine 83.7 MB** cikti. Gercek sebep:

| Bolum | Boyut |
|---|---|
| **`lib/` (native .so)** | **77.8 MB** |
| dex | 5.0 MB |
| assets/data | 2.7 MB (artik) |

Tek APK **uc islemci mimarisini birden** tasiyor (`arm64-v8a`,
`armeabi-v7a`, `x86_64`); ogretmen ucunu de indiriyor ama birini
kullaniyor. Ustelik `x86_64` neredeyse tamamen emulator icin.

| Yontem | Ogretmenin indirdigi |
|---|---|
| `flutter build apk --release` | 83.7 MB ❌ |
| `flutter build apk --release --split-per-abi` | **31.7 MB** ✅ |
| `flutter build appbundle --release` | ~30 MB ✅ (Play boler) |

- [x] Her iki cikti da uretilip dogrulandi
- [x] Derleme adimlari `.agents/AGENTS.md` bölüm 12'ye yazildi
      (sikistirma adimi atlanirsa varliklar bulunamaz)

**Sonuc: 83.7 MB → 31.7 MB.** Sikistirma tek basina APK'yi kucultmedi
ama veriyi 32 MB'dan 2.6 MB'a indirdigi icin App Bundle ciktisini de
o kadar kucultuyor.

### 4.5 Gercek cihaz dogrulamasi ✅ YAPILDI (31 Agustos 2026)

**Maarif icerigi cihazda dogrulandi.** Debug APK kuruldu, uygulama
acildi, veritabani cekilip incelendi:

| Kontrol | Sonuc |
|---|---|
| Sema surumu | **14** ✓ |
| `curriculum_outcomes` sutun sayisi | 30 ✓ |
| Toplam kazanim | 9.087 |
| `maarif_summary` dolu | **9.087 (%100)** ✓ |
| `maarif_values` / `maarif_skills` / `differentiation` | %100 ✓ |
| `outcome_parts` | %100 ✓ |
| `official_activity` | %38 (JSON'da zaten her kayitta yok) |
| `suggested_activities` | %13 (ayni sebep) |

Ornek kayit (1. sinif Matematik, 4. hafta) — kartta gorunecek icerik:
> Bu hafta 'SAYILAR VE NICELIKLER (1)' konusu; somut materyaller,
> gorsellestirmeler ve gercek hayat problemleriyle modellenir.
> 💎 Sabir, Akil Yurutme, Caliskanlik  🧠 KB2.10 Matematiksel Modelleme

**Goc zinciri dogrulandi.** Cihazda uc hesap veritabani bulundu; biri
v14'e yukseldi, ikisi v12'de bekliyor (o hesaplar henuz acilmadi — bu
dogru davranis). v12 → v14 atlamali gocun tek seferde calistigi
`migration_chain_test.dart` ile kanitlandi (4 test).

**Acilis performansi olculdu — sorun YOK:**

Debug derlemesinde "DONMA: 1475 ms" gorundu ve bir an benim
degisikliklerimden supheledim. Olcerek dogruladim:

1. Degisikliklerimi `git stash` ile geri alip olctum → **ayni donma
   vardi (1427 ms)**. Yani bu mevcut bir durum, ben yaratmadim.
2. Asamalari olctum: `runApp` oncesi tum hazirlik yalnizca **95 ms**
   (prefs 60 ms + tarih bicimlendirme 25 ms). `openForUid` 478 ms
   ama icindeki is 26 ms — kalani dosya acmanin kendisi.
3. **Release'de olctum: soguk acilis 827–918 ms.** Debug'daki donma
   JIT derlemesinden geliyormus; gercek kullanicida yok.

Android'de 1 saniyenin alti "hizli" kabul edilir. Olcum kodu temizlendi.

**Release APK: 31.7 MB** (arm64-v8a) — cihaza kurulup calistirildi.

---

### 4.4 Kalanlar ⬜
- [ ] Gerçek imzalama anahtarı (yayın engeli — sizin oluşturmanız gerekiyor)
- [ ] Zorunlu güncelleme mekanizması
- [ ] Yedekleme: öğretmen telefonunu kaybederse veri gidiyor
- [ ] Play Store veri güvenliği formu
- [ ] Gizlilik politikası (hukuki inceleme)

---

## FAZ 5 — Evraklarım (en son)

**Kullanıcı kararı: en sona bırakıldı.** Şu an yalnızca model var (164 satır).

---

## KARAR BEKLEYENLER

Bunlar sizin cevabınızı bekliyor:

1. ~~**Destek e-postası**~~ → **KARAR: `sinifcepte@gmail.com`** ✓ uygulandı
2. ~~**Mesaj ve duyurular saklama**~~ → **KARAR: 1 öğretim yılı (365 gün)** ✓
   Uygulandı; gizlilik metni de güncellendi.
3. ~~**Katılım verisi veliye**~~ → **KARAR: gelir gelene kadar HAYIR** ✓
   *(31 Ağustos 2026)*

   **Karar:** "gelir elde etmeye başlayınca ders içi katılımları
   programa dahil ederiz. şimdilik toplu bildirimler ve bireysel
   mesajlar yeterli."

   **Yerine yapılan:** Duyuru yazma yetkisi kadroya açıldı; branş
   öğretmeni artık girdiği tüm sınıflara toplu duyuru gönderebiliyor
   (`bulk_announcement_screen.dart`). Veli ihtiyacı buradan karşılanıyor:
   ödev, sınav ve etkinlik duyuruları öğretmenden doğrudan gidiyor.

   **Hazır olan altyapı** (ileride açılırsa kullanılacak):
   - `speakingTurns` alanı modelde ve şemada var (sürüm 15)
   - Katılım verisi cihazda birikiyor; buluta çıkarmak tek adım
   - Maliyet hesaplandı → aşağıdaki tablo

   | Yaklaşım | Günlük yazma | Aylık (1000 okul) |
   |---|---|---|
   | Her öğrenci, her ders | 3.750.000 | ~$201 |
   | Öğrenci başına günlük özet | 750.000 | ~$39 |
   | **Haftalık söz hakkı özeti** | 107.000 | **~$8** |
   | Veli okuma (hepsinde) | 7.500.000 | ~$134 |

   **Açılırsa önerilen biçim:** günlük puan tablosu DEĞİL, haftalık ve
   yalnızca söz hakkı — *"Bu hafta çocuğunuz 7 kez söz aldı"*. Yıldız,
   ödev ve davranış notu veliye gitmemeli: KVKK açısından hassas,
   pedagojik olarak tartışmalı ve öğretmeni "hep olumlu işaretleme"
   baskısına sokar.
4. ~~**Ders programı veliye**~~ → **KARAR: gösterilmeyecek** ✓ (mantıksız)
   Bunun yerine mesaj saati 19:00 → **22:00** yapıldı: ikili öğretimde
   ders akşam 19:00'da bitiyor, veli okul çıkışında yazamıyordu.
5. ~~**Yetim dosyalar**~~ → **4'ü silindi** (1.228 satır).
   `daily_stars_celebration_dialog` bırakıldı: bağlanmamış bir
   özellik, eski sürüm değil.
6. ~~**Veli telefonu**~~ → **KARAR: sorulmayacak** ✓ *(31 Ağustos 2026)*

   **Bulgu:** Veli bağlanırken telefon isteniyordu ama **hiçbir yerde
   kullanılmıyordu** — girilen numara bağ kaydında kalıyor, öğretmen
   hiçbir ekranda göremiyordu (telefon velinin cihazında, öğretmeninkinde
   değil). Toplanan ama kullanılmayan kişisel veri KVKK açısından
   savunulamaz.

   **Karar:** *"veli girişte telefon numarası girmesine gerek yok.
   kaldıralım zaten mesajlaşma var öğretmen sadece kendisi isterse
   girer."*

   **Yapılan:** Alan, denetleyicisi ve telefon biçimlendiricisi
   kaldırıldı. Veli Rehberi (öğretmenin kendi girdiği numaralar)
   **aynen çalışmaya devam ediyor** — o özellik kaldırılmadı.
7. ~~**Maarif içeriği**~~ → **KARAR VERİLDİ: içerik kullanılsın.**
   Uygulandı; kartlar artık doluyor.

---

## FAZ 6 — Kullanıcı kararlarıyla gelen işler (31 Ağustos 2026)

### 6.1 Mesajlaşma saati düzeltildi ✅
Sessiz saat 19:00 idi. **İkili öğretim yapan okullarda ders akşam
19:00'da bitiyor**; veli okul çıkışında öğretmene yazamıyordu.
- [x] 22:00'ye çekildi (gece mesajı hâlâ engelleniyor)
- [x] Testler sabit saat yerine **sabite bağlandı** — bir sonraki
      değişiklikte de doğru kalsın

### 6.2 İçerik denetimi eklendi ✅
**Mesajlarda hiçbir denetim yoktu:** ne argo filtresi ne hız sınırı.
Hakaret ve mesaj bombardımanı doğrudan gidiyordu.

`content_guard.dart` — üç katman, hepsi **cihazda** (sıfır bulut maliyeti):
- [x] **Argo filtresi:** Türkçe karakter duyarsız (`trFold` kullanıyor),
      "serefsiz" de "şerefsiz" de yakalanıyor
- [x] **Hız sınırı:** dakikada 5, saatte 30 mesaj
- [x] **Tekrar kontrolü:** aynı mesaj art arda gönderilemiyor
- [x] 19 test (`content_guard_test.dart`)

**Önemli tasarım kararı — argo ENGELLEMİYOR, uyarıyor.** Türkçede bağlama
göre masum kelimeler var; kullanıcıyı yanlış alarmda kilitlemek filtrenin
hiç olmamasından kötü olurdu. Kullanıcı "Yine de Gönder" diyebiliyor.

**Test bir yanlış alarm yakaladı:** `top` kelimesi listedeydi ve
*"Beden dersine top getirsin mi?"* mesajı uyarılıyordu. Kelime listeden
çıkarıldı — okul bağlamında çok yaygın, kazancı zararından az.

Sayaç yalnızca **gönderilen** mesaj için ilerliyor: uyarıyı görüp
vazgeçen kullanıcı hız sınırını doldurmuyor.

### 6.3 Veli tanıtımı eklendi ✅
Kullanıcı sordu: *"randevu sisteminin tanıtımı veli tarafında var mı?"*
Cevap: **hayır, hiç yoktu.** Veli hiçbir yönlendirme almadan uygulamaya
giriyordu; çalışan özellikler görünmez kalıyordu.

- [x] 5 adımlık tanıtım (`parent_onboarding_screen.dart`): çocuk ekleme,
      duyurular, mesajlaşma, **randevu**, veri güvenliği
- [x] İlk açılışta bir kez gösterilir, "Atla" ile geçilebilir
- [x] Randevunun mesajlaşmadan farkı anlatılıyor: "onaylanan randevu
      Takvim'de durur, *ne zaman görüşecektik* diye aramanıza gerek yok"

### 6.4 Randevu sistemi — İNCELENDİ, KALDI
Kullanıcı gerekliliğini sorguladı. Kod incelendi: **uçtan uca çalışıyor.**
Veli talep açıyor → öğretmen panelinde "bekleyen" olarak görünüyor →
öğretmen onaylıyor/reddediyor.

Sorun özellikte değil **görünürlüktedir**; 6.3 ile çözüldü.

### 6.5 Saklama süresi uygulandı ✅
- [x] `messageRetention` ve `announcementRetention` = **365 gün**
- [x] `purgeExpiredMessages` / `purgeExpiredAnnouncements` eklendi
      (mevcut fırsatçı temizleme altyapısı kullanıldı)
- [x] Gizlilik metni güncellendi

### 6.6 Veli telefonu — maliyet endişesi YOK ✅
Kullanıcı maliyet açısından endişelendi. Kod doğrulandı:
**veli telefonu buluta hiç gitmiyor**, yalnızca cihazda (`SharedPreferences`)
duruyor. `cloud_token_repository.dart` içinde `parentPhone` geçmiyor.

Yani telefon kullanmanın **bulut maliyeti sıfır**. Karar 6 bu açıdan
serbest.

---

## DURUM ÖZETİ

| Faz | Durum |
|---|---|
| Faz 1 — Yayın engelleyiciler | 1.1 ✓ · 1.2 ✓ · 1.3 ✓ · 1.4 ✓ · 1.5 ✓ |
| Faz 2 — İncelenmemiş modüller | **5/5 modül ✓ TAMAM** |
| Faz 3 — Kullanım kolaylığı | 3.2 ✓ · (3.1 karar bekliyor, 3.3 cihaz gerekiyor) |
| Faz 4 — Altyapı | 4.1 ✓ · 4.2 ✓ · 4.3 ✓ · 4.5 ✓ cihazda doğrulandı · (imzalama sizde) |
| Faz 5 — Evraklarım | Ertelendi |

**Test durumu:** 645 Flutter + 121 kural testi geçiyor
**Analiz:** temiz
