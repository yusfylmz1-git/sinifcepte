# 🎛️ SınıfCepte Web Admin Portalı (Admin Portal)

SınıfCepte uygulamasının **MEB Çalışma Takvimi**, **36 Haftalık Müfredat Kazanımları**, **Sistem Duyuruları** ve **Versiyon Senkronizasyon Manifesti**ni masaüstü tarayıcınızdan yönetmek için geliştirilmiş bağımsız web yönetim merkezidir.

---

## 🚀 Nasıl Çalıştırılır?

### 1. Yerel Olarak Açma (Sıfır Kurulum)
- [index.html](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/admin_portal/index.html) dosyasına çift tıklayarak herhangi bir tarayıcıda (Chrome, Edge, Safari, Brave) hemen kullanmaya başlayabilirsiniz.
- Tüm veriler tarayıcınızın yerel hafızasında (`LocalStorage`) güvenle saklanır.

### 2. Buluta (Firebase Hosting) Yayınlama
Bu paneli `admin.sinifcepte.app` veya Firebase Hosting alan adınıza yayınlamak için:
```bash
# Firebase CLI yüklü ise:
firebase init hosting
# Public directory olarak "admin_portal" seçin
firebase deploy --only hosting
```

---

## 🌟 Temel Özellikler

1. **📅 MEB Akademik Takvim Yöneticisi:**
   - Yeni resmî tatiller, dönem açılış/kapanış tarihleri, ara tatiller veya ortak sınav haftaları ekleme, düzenleme ve silme.
   - Otomatik süre hesaplama ve kategori rozetleri.
   - Tek tıkla `academic_calendar_2025_2026.json` indirme.

2. **📚 36 Haftalık Kazanım Kütüphanesi & Excel İçe Aktarma:**
   - 1'den 12'ye tüm sınıf kademeleri ve 13 ana branş (Matematik, Türkçe, Fen, Fizik, Kimya vb.).
   - Excel veya tablolardan kopyalanan satırları doğrudan yapıştırarak 36 haftalık müfredatı saniyeler içinde otomatik ayrıştırma (Parse).
   - Tekil düzenleme ve JSON dışa aktarma.

3. **📢 Sistem Duyuru Merkezi:**
   - Öğretmenlerin mobil ekranlarında göreceği genel duyurular ve MEB sınav kılavuzu yayınları.

4. **⚙️ Versiyon Manifest & Bakım Modu:**
   - Takvim veya kazanım güncellediğinizde `+1 Artır (Yayınla)` butonuna basarak mobil cihazların otomatik senkronizasyon yapmasını sağlama.
   - Bakım modunu açıp kullanıcılara nazik bir bakım mesajı gösterme.
