# Admin paneli yayını — kontrol listesi

28–30 Eylül 2026'da yapılan panel ve sunucu işleri **yayımlanmadı**.
Bu liste, yayın onaylandığında sırayla yapılacakları tutuyor.

## Neler gidiyor

| Commit | İş |
|---|---|
| `08e598e` | Panel CSP uyumu (satır içi `onclick` yok), başlık raporlayan kipte |
| `e1553d8` | K8: panel yalnızca değiştirilen ayarı yayınlıyor |
| `04dee68` | Y17: okul yöneticiliği başvurusuna panelden karar |
| `94864f9` | Okullar ve Kişiler sekmesi |
| `012ae7b` | Ana Program parolası için destek kodu |

Yeni sunucu fonksiyonları: `readRemoteConfig`, `listSchoolAdminRequests`,
`decideSchoolAdmin`, `schoolOverview`, `findPerson`,
`removeFromSchoolDirectory`, `issueSupportCode`.
Değişen: `publishRemoteConfig` (artık önceki değeri istiyor).

## Sıra

1. **Gizli anahtarı yükle** (bir kez):

   ```
   firebase functions:secrets:set DESTEK_IMZA_TOHUMU --data-file "C:\Users\Okul\sinifcepte-gizli\destek_imza_tohumu.b64"
   ```

   Yüklenmezse `issueSupportCode` yayımlanamaz. Dosyanın bir yedeğini
   parola yöneticisine koy; ayrıntı aynı klasördeki `BENIOKU.txt`'te.

2. **Fonksiyonlar ve panel AYNI ANDA:**

   ```
   firebase deploy --only functions,hosting
   ```

   Ayrı ayrı yayınlanırsa: yeni fonksiyon, tarayıcıdaki eski panelin
   ayar kaydını reddeder ("Paneliniz eski sürüm…"). Zararsız ama
   kafa karıştırır.

3. **Firestore kuralları ve dizinleri DEĞİŞMEDİ** — bu yayında
   `firestore` gerekmiyor. Yeni sorguların hepsi tek alanlı eşitlik;
   Firestore bunlar için dizini kendiliğinden tutuyor.

## Yayından sonra (bilgisayardan, 5 dakika)

- Paneli **Ctrl+F5** ile aç (eski JS önbellekte kalmasın).
- Google ile giriş yap. Konsol (F12) açık olsun.
- **Versiyon & Senkronizasyon** sekmesi: "Canlı değerler gösteriliyor
  (Remote Config sürüm …)" yazmalı; bakım modu ve en düşük sürüm
  canlıdakiyle aynı olmalı.
- **Okul Yöneticileri**: bekleyen başvurular listeleniyor mu.
- **Okullar ve Kişiler**: kendi okulunu (kurum kodu) ara.

Değişiklik yapmadan bakmak yeterli; ilk gerçek işlemde zaten görünür.

## Bir hafta boyunca

Başlık yalnızca **raporlayan** kipte: hiçbir şeyi engellemiyor, yalnızca
konsola yazıyor. Konsolda "Content Security Policy" geçen bir satır
görürsen not al. Görmezsen `firebase.json`'daki anahtarı
`Content-Security-Policy` yap, `functions/test/csp.test.js`'teki
"RAPORLAYAN kipte" testini buna göre değiştir, hosting'i yeniden yayınla.

## Geri alma

Panel ve fonksiyonlar kendi başına geri alınabilir:

- Hosting: Firebase Console → Hosting → önceki sürümü "Rollback".
- Fonksiyonlar: önceki commit'e dönüp `firebase deploy --only functions`.

Veri şeması değişmedi; geri almak veri bozmaz. Tek istisna: bu arada
panelden verilen yöneticilik kararları ve destek kodları geçerli kalır
(istenen de bu).
