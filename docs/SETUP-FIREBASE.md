# Firebase — `sinifcepte` projesi

Kod bu projeye bağlandı: `projectId = sinifcepte`.

## Bizim yaptıklarımız

- Android / iOS / Web / Windows uygulamaları kaydedildi (`com.sinifcepte.sinifcepte`)
- Debug SHA-1 / SHA-256 Android’e eklendi
- Firestore `(default)` oluşturuldu (`eur3`) ve `firestore.rules` yayınlandı
- Flutter: `firebase_core`, `firebase_auth`, `google_sign_in`, `cloud_firestore`
- Öğretmen kartı Google ile giriş yapıyor; sonra okul seçimi zorunlu

## Senden kalan tek tıklama (Google girişi için şart)

Konsolda Authentication henüz ilk kez açılmadığı için Google sağlayıcısını senin açman gerekiyor:

1. Aç: https://console.firebase.google.com/project/sinifcepte/authentication/providers
2. **Get started** (ilk kez ise)
3. **Google** → Enable → proje destek e-postası olarak Gmail’ini seç → Save

Sonra telefonda öğretmen girişine bas. İlk seferde Google hesap seçici çıkar.

## Yönetim paneli — tek tıkla yayın (bir kerelik kurulum)

Panel artık Remote Config'i doğrudan yayınlıyor: dosya indirme ve
terminal komutu yok. Bunun için dört adım gerekiyor.

### 1. Blaze planına geç

Cloud Functions Blaze ister. Ücretsiz katman aynen duruyor (ayda 2M
çağrı); yayın işlevi yılda birkaç kez çağrılacağı için fiilen ücretsiz.

Console → ⚙️ → Usage and billing → Modify plan → Blaze

Bütçe alarmı kurun: Usage and billing → Budget alerts.

### 2. Servis hesabı anahtarı (yalnızca claim vermek için)

Console → ⚙️ Project Settings → Service accounts → Generate new private
key. İnen dosyayı `C:\secrets\sinifcepte-sa.json` gibi bir yere koyun —
**asla depoya eklemeyin**.

### 3. Kendine süper yönetici yetkisi ver

Önce panele Google ile bir kez giriş yapın (yetki hatası alacaksınız,
normal — hesabınız böylece Authentication'da oluşur). Console →
Authentication → Users listesinden UID'nizi kopyalayın:

```
set GOOGLE_APPLICATION_CREDENTIALS=C:\secrets\sinifcepte-sa.json
node scripts/admin/bootstrap_super_admin.mjs --email SENIN_GMAIL --uid UID
```

Panel `getIdTokenResult(true)` ile token'ı zorla tazeliyor; çıkıp
yeniden girmeniz yeterli.

### 4. Alan adlarını yetkilendir

Console → Authentication → Settings → Authorized domains:

- `localhost` — panel yerelde açılırken
- `sinifcepte.web.app` — Hosting'e yayınlanınca

### 5. İşlevi yayına al

```
cd functions && npm install
firebase deploy --only functions
```

Paneli de yayınlamak isterseniz: `firebase deploy --only hosting`

---

## Panel nasıl kullanılıyor

1. Paneli aç (yerelde `localhost` üzerinden ya da `sinifcepte.web.app`)
2. Google ile giriş yap
3. Sınav Takvimi → tarihi düzenle → **🚀 Mobil Uygulamaya Yayınla**

Öğretmenler en geç 6 saatte alır; "yenile" derlerse anında.

> **Yerelde açarken:** `file://` ile açılan sayfada Google girişi
> çalışmaz (tarayıcı kısıtı). Küçük bir sunucu gerekir:
> `npx serve admin_portal` ya da
> `python -m http.server 8080 -d admin_portal`

---


## İsteğe bağlı sonra

- Blaze: Cloud Functions (veli kod çözme, okul paketi yayın) için
- İlk süper admin: `node scripts/admin/bootstrap_super_admin.mjs --email SENIN_GMAIL --uid UID`
- Play Store imzası için release SHA-1’i de Android uygulamaya ekle
