# 🧠 SınıfCepte - Proje Bilgi Ağı (Master Index / MOC)

Bu dizin, **SınıfCepte** projesinin canlı hafızasını, mimarisini, PRD dokümantasyonunu ve çalışma oturumlarının takibini otomatikleştirmek için kurulmuş **Obsidian Uyumlu Bilgi Ağı**dır.

---

## 📌 Hızlı Erişim Dokümanları

- [[01-PRD|📄 01-PRD.md - Ürün Gereksinim Dokümanı (PRD)]](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/docs/01-PRD.md)
  - Projenin vizyonu, hedef kitlesi, modül detayları, kullanıcı senaryoları ve gelecek planı.
- [[02-ARCHITECTURE|🏗️ 02-ARCHITECTURE.md - Mimarisi & Kod Yapısı]](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/docs/02-ARCHITECTURE.md)
  - Klasör yapısı, tema sistemi, Riverpod state yönetimi ve SQLite veritabanı şeması.
- [[03-PAGE_CATALOG|📱 03-PAGE_CATALOG.md - Sayfa & Bileşen Kataloğu]](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/docs/03-PAGE_CATALOG.md)
  - Mevcut ve planlanan ekranlar, bileşenler ve hangi sayfanın ne işe yaradığı.
- [[04-SESSION_LOG|📝 04-SESSION_LOG.md - Oturum Takip Günlüğü]](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/docs/04-SESSION_LOG.md)
  - Hangi oturumda ne yapıldı, son durum nedir, bir sonraki adımda ne yapılacak?
- [[ILERLEME_NOTLARI|🤖 gemini/ILERLEME_NOTLARI.md - Yapay Zeka Canlı Hafıza Notları]](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/gemini/ILERLEME_NOTLARI.md)
  - Yapay zekalar arası proje kimlik kartı, kurallar ve tamamlanan işler dökümü.

---

## 🚀 Proje Özet Kartı

| Alan | Detay |
| :--- | :--- |
| **Proje Adı** | SınıfCepte |
| **Hedef Platform** | Mobil (Android / iOS) & Tablet |
| **Hedef Kitle** | Öğretmenler, Eğitmenler, Okul Yönetimleri |
| **Teknoloji Yığını** | Flutter 3.x + Riverpod + Sqflite + Glassmorphism UI |
| **Tasarım Dili** | UI-UX-MAX (Deep Slate, Glassmorphism, Modern Tipografi) |
| **Mevcut Durum** | Temel tema, altyapı, cam kart bileşeni ve giriş ekranı hazır. |

---

## 🔄 Oturum Takip Kuralı (AI & Developer Synchronizer)
Her yeni chat oturumuna başlarken:
1. `docs/04-SESSION_LOG.md` okunur ve **Son Durum** tespit edilir.
2. Yapılan değişiklikler ve yeni özellikler oturum sonunda `04-SESSION_LOG.md` dosyasına kaydedilir.
3. İlgili modül değişiklikleri `01-PRD.md` ve `03-PAGE_CATALOG.md` belgelerinde güncellenir.
