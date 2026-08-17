# 📱 SınıfCepte Veli & Okul Ekosistemi Mimari Planı (VeliModul & SchoolNetwork)

Bu plan; **SınıfCepte** uygulamasını yalnızca öğretmenlerin kullandığı yerel bir asistan olmaktan çıkarıp, Avrupa standartlarında (**Avusturya SchoolFox / EduPage** modeli) **Öğretmen - Okul - Veli** üçgenini birbirine bağlayan modern, güvenli ve yüksek performanslı bir eğitim ekosistemine dönüştürmek için hazırlanmıştır.

---

## 🏛️ 1. GENEL MİMARİ VİZYON (Hybrid Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ÖĞRETMEN UYGULAMASI                              │
│  - Yerel SQLite (Hızlı, Offline-First, Sınıflarım, Notlar, Planlar)         │
│  - Okul Seçimi (81 İl -> İlçe -> Okul Arama Dizini)                          │
│  - Veli Referans Kodu Üreteci (Örn: SC-8A-9402)                             │
│  - Sınıf & Okul Duyuruları / Veli Randevu Yönetimi                          │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ (Delta Sync & Cloud Firestore)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                   GÜVENLİ BULUT KATMANI (Firebase / Supabase)               │
│  - Okul & Öğretmen Ağaçları (/schools/{schoolId}/teachers)                  │
│  - Eşleşme Token Havuzu (/student_tokens/{tokenHash})                       │
│  - Sınıf Duyuruları (/classes/{classId}/announcements)                      │
│  - Veli Hızlı İletişim & Randevular (/appointments & /quick_cards)          │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ (Realtime & Push Notification)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VELİ UYGULAMASI                                │
│  - Referans Koduyla Öğrenci Ekleme (Birden fazla çocuk desteği)              │
│  - Çocuğun Dersine Giren Öğretmenler Listesi & Görüşme Saatleri             │
│  - Okul / Sınıf Duyuru Akışı (Okundu & Onay Bildirimi)                      │
│  - Hızlı Durum Kartları (İlaç, Randevu Talebi, Bilgilendirme Notu)          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## ⚡ 2. TÜRKİYE 81 İL VE OKUL SEÇİM SİSTEMİ (Sıfır Kasma & Ultra Hızlı Arama)

### 🚨 Problem & Risk:
Türkiye'de MEB'e bağlı **~55.000'den fazla okul** bulunmaktadır. 55 bin kaydın tamamını tek bir JSON olarak RAM'e yüklemek uygulamada 15-20 MB bellek tüketimine ve açılışta kasmalara yol açar.

### 💡 Mimari Çözüm (Shard / İl Bazlı Bölme & SQLite FTS Index):
1. **81 İl Hafif İndeksi (`provinces.json` ~5 KB):**
   * Öğretmen profilinde önce 81 ilden birini seçer (Örn: `16 - Bursa`).
2. **Lazy-Load İl Okul Paketleri:**
   * Bursa seçildiği anda sadece Bursa'ya ait okullar (~1.200 okul) yerel SQLite önbelleğine alınır veya sıkıştırılmış JSON'dan 0.01 milisaniyede okunur.
3. **Akıllı Türkçe Karakter Arama (Fuzzy & Debounced Search):**
   * Öğretmen okulun adını yazmaya başladığı anda (`Örn: "Cumhuriyet"`, `"Atatürk"`), 150ms gecikmeli debounced arama ile filtrelenir.
4. **Kullanıcı Tanımlı Okul Ekleme (Fallback):**
   * Listede bulunamayan yeni açılmış veya özel kurumlar için öğretmen "Okulumu Manuel Ekle" seçeneğiyle okulunu anında tanımlayabilir.

---

## 🔐 3. ÖĞRETMEN - ÖĞRENCİ - VELİ EŞLEŞME MEKANİZMASI (Avusturya Modeli)

### Adım Adım Akış:
1. **Öğretmen Tarafı:**
   * Öğretmen, sınıfındaki Ali Yılmaz için tek tıkla **Veli Bağlantı Kartı** oluşturur:
     * Kod: `SC-7B-8492`
     * İster tek tek PDF/WhatsApp olarak veliye gönderir, ister tüm sınıf için toplu "Veli Giriş Kodları Listesi" çıktısı alır.
2. **Veli Tarafı (İlk Giriş):**
   * Veli uygulamayı açtığında **"Veli Girişi"** seçeneğini tıklar (Google ile veya Telefonla giriş).
   * **`SC-7B-8492`** kodunu girer.
   * **İkinci Doğrulama (Güvenlik Kalkanı):** Çocuğun okul numarasını veya doğum yılını sorar.
3. **Eşleşme Tamamlandı:**
   * Veli artık o çocuğun profiline bağlanır. 
   * Birden fazla çocuğu olan veliler aynı hesaba 2., 3. çocuklarını da farklı kodlarla ekleyebilir.

---

## 📬 4. VELİ MODÜLÜ ANA ÖZELLİKLERİ

### A. Çocuğun Dersine Giren Öğretmenler Kadrosu
* Veli, çocuğun sınıfına giren tüm öğretmenleri görür:
  * 👨‍🏫 *Ahmet Yılmaz* - Matematik (Görüşme Günü: Salı 13:30 - 14:15)
  * 👩‍🏫 *Ayşe Demir* - Türkçe / Sınıf Rehber Öğretmeni
  * 👨‍🏫 *Mehmet Kaya* - Fen Bilimleri
* Veliler doğrudan öğretmenin belirlediği boş ders saatlerine **"Görüşme Talebi"** oluşturabilir.

### B. Hızlı Bilgi & Bildirim Kartları (Quick Status Cards)
Veli tek tıkla hazır şablonlarla öğretmeni bilgilendirir:
* 💊 **İlaç & Sağlık Bildirimi:** "Öğle saatinde alerji ilacı alması gerekiyor."
* ⏱️ **Geç Kalma / Erken Alma:** "Bugün diş randevusu nedeniyle 14:00'te alınacak."
* 🤝 **Öğretmen Görüşme Talebi:** "Ders durumu hakkında 10 dk görüşmek istiyorum."

### C. Sınıf & Okul Duyuru Panosu
* Öğretmenin paylaştığı duyurular (Gezi, Veli Toplantısı, Proje Ödevi Duyurusu, Kitap Okuma Takvimi).
* Veli altına **"Okudum / Onaylıyorum"** butonuna basarak teyit verir. Öğretmen hangi velinin okuyup hangisinin okumadığını yeşil/gri tiklerle anında görür.

---

## 🛡️ 5. KVKK, GÜVENLİK VE MAĞAZA UYUMLULUĞU

1. **Öğrenci Gizliliği:**
   * Veliler ASLA sınıftaki diğer öğrencilerin veya velilerin isimlerini/telefonlarını göremez. Yalnızca kendi çocuklarının verisini görür.
2. **Telefon Numarası Gizliliği:**
   * Öğretmen ve veli birbirlerinin şahsi telefon numaralarını görmeden uygulama içi bildirim ve randevu sistemiyle haberleşir (Öğretmenin özel hayatı korunur).
3. **Sıfır Sunucu Maliyeti (Spark / Free Tier Optimizasyonu):**
   * Firestore koleksiyon yapısı optimize edilerek her veri parçası sadece gerektiğinde dinlenir (No polling, delta cache).

---

## 📋 6. GELİŞTİRME FAZLARI VE YOL HARİTASI

| Faz | Kapsam | Detaylar |
|---|---|---|
| **Faz 1** | **Okul Seçim Altyapısı** | 81 İl ve Okul Veri Setinin hazırlanması, Profilde optimize okul arama/seçme ekranı. |
| **Faz 2** | **Veli Referans Kodu & Model** | Öğrenciye özel eşleşme token motoru, SQLite + Cloud veri şeması, kod paylaşım kartı. |
| **Faz 3** | **Veli Arayüzü & Rol Yönetimi** | Giriş ekranında Öğretmen / Veli ayrımı, Veli Dashboard, Çocuklarım paneli. |
| **Faz 4** | **İletişim & Duyuru Modülü** | Hızlı bilgi kartları (İlaç, randevu, not), Okundu onaylı sınıf duyuruları. |
| **Faz 5** | **Ders Öğretmenleri Kadrosu** | Sınıf bazlı branş öğretmeni eşleşmesi, randevu takvimi. |

---

## ⚠️ KURAL VE SINIRLAMALAR
* **YOKLAMA KESİNLİKLE YOKTUR**: Bu modülde yoklama alma veya devamsızlık işleme özelliği asla yer almayacaktır.
* **OFFLINE-FIRST**: Öğretmen interneti olmasa bile sınıf ve yerel kayıtlarını kesintisiz kullanmaya devam edecektir.
