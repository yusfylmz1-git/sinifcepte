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

---

## 🤝 ÇALIŞMA PRENSİBİ
1. Her öneride bu ana başlıklar altında olası riskler, maliyet, güvenlik ve yan etkiler mutlaka sunulacak.
2. Kullanıcı **"Başla / Yap"** demeden koda geçilmeyecek.
