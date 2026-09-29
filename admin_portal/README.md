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

---

## Güvenlik başlığı (CSP) — satır içi betik YOK

`firebase.json` panele `Content-Security-Policy` başlığı koyuyor:
`script-src 'self'` satır içi betiği ve `onclick="..."` gibi işleyicileri
engelliyor. Enjekte edilen bir betiğin süper admin oturumunda
çalışmaması bu kurala dayanıyor.

**Düğme eklerken `onclick` YAZMAYIN.** `data-eylem` kullanın
(`js/eylemler.js`):

```html
<button data-eylem="openAddExamModal">Sınav ekle</button>
<button data-eylem="closeModal" data-arg="modal-exam">Kapat</button>
<select data-degisim="handleCalendarYearChange" data-deger>…</select>
```

`functions/test/csp.test.js` satır içi işleyiciyi ve var olmayan bir
yöntemi gösteren `data-eylem`'i yakalıyor.

### Yayın planı (karar, 28 Eylül 2026)

1. Başlık şimdi **raporlayan kipte** (`Content-Security-Policy-Report-Only`):
   hiçbir şeyi engellemiyor, yalnızca tarayıcı konsoluna yazıyor.
2. Bir hafta paneli kullanırken konsolu (F12 → Console) açık tutun.
   "Content Security Policy" geçen bir satır görürseniz not alın.
3. Hiç görünmezse `firebase.json`'daki anahtarı
   `Content-Security-Policy` yapın ve `csp.test.js`'teki "RAPORLAYAN
   kipte" testini buna göre değiştirin.

Doğrulama (29 Eylül 2026): panel yerelde başlık **zorunlu** hâlde
Chrome'da açıldı. 180 düğmenin hepsi doğru eylemi çağırdı, ihlal çıkmadı.
Eski (onclick'li) panelde aynı deneme 174 ihlal verdi. Google ile giriş
açılır penceresi bu denemede sınanamadı (hesap yok). Raporlayan kipteki
hafta asıl bunu gösterecek.
