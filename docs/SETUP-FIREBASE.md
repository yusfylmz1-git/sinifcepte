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

## İsteğe bağlı sonra

- Blaze: Cloud Functions (veli kod çözme, okul paketi yayın) için
- İlk süper admin: `node scripts/admin/bootstrap_super_admin.mjs --email SENIN_GMAIL --uid UID`
- Play Store imzası için release SHA-1’i de Android uygulamaya ekle
