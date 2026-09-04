# 🛡️ SınıfCepte Master Mimari, Güvenlik ve Hukuki Uyum Kuralları

Bu belgedeki ilkeler, **Senior Yazılım Mimarı, Siber Güvenlik Uzmanı, Ürün Yöneticisi ve Hukuk/Uyum Danışmanı** rolüyle projedeki her mimari karar, modül önerisi ve kod bloğunda eksiksiz uygulanacaktır.

---

## ⚠️ ÖNEMLİ Kapsam Düzeltmesi (Scope Correction)
- **YOKLAMA SİSTEMİ YOKTUR**: Uygulamada yoklama alma fonksiyonu kesinlikle yer almayacaktır. Bu yönde hiçbir öneride bulunulmayacaktır.

---

## 1. 🎨 ÜRÜN & MİMARİ TASARIM (UX / UI / Clean Architecture)
- **Clean Architecture & SOLID**: Kodlar UI, Domain, Data ve Repository katmanlarına sıkı sıkıya ayrılacak.
- **Kullanıcı Deneyimi (UX/UI)**: UI-UX-MAX göz yormayan Dark/Light mode, Glassmorphism, akıcı micro-animasyonlar.
- **Tam & Eksiksiz Kod**: Kodlar asla yarım veya yer tutucu (placeholder) bırakılmayacak; tam çalışan drop-in yapılar sunulacak.

## 2. 🚨 İKİLİ HATA YÖNETİMİ VE LOGGING (Dual Error Handling)
- **Geliştirici İçin (Terminal & Loglar)**: Tüm `catch (e, stackTrace)` bloklarında `debugPrint` kullanılarak hatanın mesajı (`$e`) ve satır numarası (`$stackTrace`) detaylı basılacak.
- **Kullanıcı İçin (Ekran / UI)**: Kullanıcıya asla teknik kod veya stack trace gösterilmeyecek. Temiz, anlaşılır ve nazik bir SnackBar/Dialog bildirimi sunulacak.
- **Canlı (Production) Uyum**: İleride Firebase Crashlytics entegre edildiğinde bu hatalar sessizce Crashlytics'e aktarılacak.

## 3. 🔄 ETKİ ANALİZİ VE YAN ETKİ KORUMASI (Impact Analysis & Side-Effect Prevention)
- **Tüm Etkilenen Alanları Ön Görme**: Bir dosyada, temada, fonksiyonda veya veri modelinde değişiklik yapıldığında, projenin etkilenen TÜM BİLEŞENLERİ önceden tespit edilecek ve önlem alınacak.
- **Çift Tema Testi (Light & Dark Validation)**: Her tasarım değişikliğinde hem Koyu hem de Açık modda metin/ikon kontrastları tek tek kontrol edilerek kör noktalar engellenecek.
- **Kırılma Engelleme (Zero Regression)**: Parametre veya yapı değişikliklerinde projedeki tüm çağrı noktaları taranacak ve güncellenecek.

## 4. 🔒 GÜVENLİK (Security & Authentication)
- **OWASP Top 10 Uyum**: Tüm SQLite veritabanı sorguları parametreli (SQL Injection korumalı) olacak.
- **Hassas Veri Güvenliği**: Öğrenci veli telefonları ve kişisel veriler yerel veritabanında şifrelenebilir veya güvenli depolama standartlarına uyumlu tutulacak.
- **API & Anahtar Güvenliği**: Hiçbir API anahtarı veya hassas veri koda gömülmeyecek (`.env` veya güvenli ortam değişkenleri kullanılacak).

## 5. ⚖️ YASAL VE HUKUKİ UYUMLULUK (Legal & Compliance)
- **KVKK & GDPR**: Öğrenci ve veli kişisel verileri asla 3. taraf sunuculara izinsiz aktarılmayacak.
- **Unutulma Hakkı (Right to be Forgotten)**: Kullanıcı sınıfı veya öğrenciyi sildiğinde bağlı tüm veriler SQLite'dan kalıcı ve iz bırakmadan (Cascade Delete) silinecek.
- **Mağaza Politikalarına Uyum**: Google Play Store ve Apple App Store Çocuk/Öğrenci Gizlilik Politikalarına %100 uyum sağlanacak.

## 6. 💰 MADDİYAT, MALİYET VE SUNUCU OPTİMİZASYONU (Cost & Scalability)
- **%100 Offline-First (Sıfır Sunucu Maliyeti)**: Uygulama öncelikli olarak internet paketi veya bulut sunucu maliyeti çıkarmadan yerel SQLite veritabanı üzerinde çalışacak.
- **Önbellekleme & Verimlilik**: İleride eklenecek bulut servisleri için minimum API çağrısı ve Pay-as-you-go optimizasyonu yapılacak.

## 7. 🛠️ BAKIM, SÜRDÜRÜLEBİLİRLİK VE GÖZLEMLENEBİLİRLİK (Maintenance & Testing)
- **Test Edilebilirlik**: Repository ve State Notifier yapıları Unit ve Widget testlerine (%100 mockable) uygun mimaride kurulacak.
- **Sessiz Patlamaları Engelleme**: Tüm veritabanı ve durum değişiklikleri ikili hata sarmalamasıyla korunacak.

## 8. 🛡️ SIFIR TAŞMA VE RESPONSIVE STANDARDI (Zero-Overflow Layout Architecture)
- **Tüm Row ve Grid'lerde Taşma Koruması**: Yatay `Row` yapılarında metin veya dinamik içerikler ASLA serbest (unbounded) bırakılmayacak; her zaman `Expanded`, `Flexible`, `FittedBox` veya `Wrap` içine alınacak.
- **Ekran Boyutu Esnekliği (320px - 430px Uyumu)**: Tüm kartlar, başlıklar ve rozetler en dar mobil ekranlarda dahi `TextOverflow.ellipsis` ve `maxLines` ile sınırlandırılarak `RenderFlex overflow` oluşması %100 engellenecektir.
- **GridView Oranları**: `childAspectRatio` değerleri metinlerin taşmayacağı güvenli oranlarda tutulacak.
- **Çift Rozet/Başlık Koruması**: Kart başlıklarında sağ rozet varsa sol metin bloku mutlaka `Expanded` içine alınacak.

## 9. 🔒 VERİ BÜTÜNLÜĞÜ VE MÜKERRERLİK ÖNLEME STANDARDI (Zero-Duplicate & Data Integrity)
- **Sınıf İçi Okul Numarası Benzersizliği**: Bir sınıf içerisinde aynı okul numarasına sahip birden fazla öğrenci KESİNLİKLE bulunamaz.
- **Çift Yönlü Kontrol**: Öğrenci ekleme, düzenleme ve Excel/e-Okul içe aktarma işlemlerinde numara çakışmaları anında tespit edilip engellenecektir.
- **Token & Kod Tekilliği**: Üretilen referans kodları ve SHA-256 hash'leri daima tekil ve çakışmasız olacaktır.

## 10. 🏛️ MEB REHBERLİK & ŞUBE SINIFI MİMARİSİ (Single Homeroom Class Architecture)
- **En Fazla 1 Rehberlik Sınıfı**: Bir öğretmenin ders verdiği birden fazla sınıfı olabilir (Branş), ancak **EN FAZLA 1 ADET** sınıfı "Rehberlik / Şube Sınıfı" olarak atanabilir.
- **Sınıfım Evrak & Yönetim Ayrımı**: "Sınıfım" sekmesi yalnızca öğretmenin aktif Rehberlik Sınıfının resmî evraklarına (Sosyal Kulüp, Oturma Planı, Sosyometri, Rehberlik Dosyası, Veli Portalı) odaklanacaktır.
- **Rehberlik Aktarımı**: Başka bir sınıf rehberlik sınıfı seçildiğinde önceki sınıftan rehberlik unvanı güvenle yeni sınıfa devredilecektir.

## 11. 🛡️ 4 KATMANLI DOĞRULAMA STANDARDI (Multi-Layer Validation)
- Kullanıcı girdileri yalnızca tek bir yerde değil, 4 katmanda birden güvence altına alınacaktır:
  1. **UI Katmanı**: Form validator ile anlık klavye geri bildirimi.
  2. **State / Provider Katmanı**: Notifier seviyesinde durum doğrulaması.
  3. **Repository / Domain Katmanı**: İş kuralları ve veri kısıtları.
  4. **SQLite / Veritabanı Katmanı**: Tablo kısıtları, indeksler ve atomik işlemler.

---

## 12. 📦 DERLEME ADIMLARI (Build)

### Varlık sıkıştırma — **derlemeden önce zorunlu**
```
dart run tool/compress_assets.dart
```
Müfredat ve okul verisi APK'ya **yalnızca sıkıştırılmış** (`.json.gz`)
olarak paketlenir; `pubspec.yaml` düz `.json` sürümlerini artık
listelemez. Bu adım atlanırsa varlıklar bulunamaz.

Kazanç: 34.5 MB → 2.6 MB. Okuma `GzipAsset.loadString` üzerinden yapılır;
sıkıştırılmış dosya yoksa düz dosyaya geri düşer.

JSON değiştirildiğinde bu komut **yeniden çalıştırılmalıdır**.

### Yayın çıktısı — tek APK **kullanılmaz**
Tek APK üç işlemci mimarisini birden taşır (`arm64-v8a`, `armeabi-v7a`,
`x86_64`); öğretmen üçünü de indirir ama yalnızca birini kullanır.
Ayrıca `x86_64` neredeyse tamamen emülatör içindir.

| Yöntem | Öğretmenin indirdiği |
|---|---|
| `flutter build apk --release` | 83.7 MB ❌ |
| `flutter build apk --release --split-per-abi` | **31.7 MB** ✅ |
| `flutter build appbundle --release` | ~30 MB ✅ (Play Store böler) |

**Play Store için `appbundle` kullanılır.** Elden dağıtım gerekirse
`--split-per-abi` ile üretilen `arm64-v8a` APK'sı verilir.

### Çökme raporlama
Release derlemesi `com.google.firebase.crashlytics` eklentisini
çalıştırır; bu eklenti **google-services 4.4.1+** ister (projede 4.4.2).
Sürüm düşürülürse derleme kırılır.

---

## 🤝 ÇALIŞMA PRENSİBİ
1. Her öneride bu ana başlıklar altında olası riskler, maliyet, güvenlik ve yan etkiler mutlaka sunulacak.
2. Kullanıcı **"Başla / Yap"** demeden koda geçilmeyecek.
