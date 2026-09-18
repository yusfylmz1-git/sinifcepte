# Öğretmen Tahta Yetkisi — Otomatik Kayıt Planı

**Durum:** taslak, onay bekliyor
**Tarih:** 18 Eylül 2026

---

## Neden bu değişiklik

Mevcut akışta idareci her öğretmeni tek tek ekliyor, QR üretiyor,
öğretmen o QR'ı okutuyor. 40 öğretmenli bir okulda bu **saatler**
sürer ve tek seferlik de değildir: telefon değiştiren, uygulamayı
silen, yeni gelen öğretmen için tekrar gerekir.

Kullanıcı tespiti: *"her öğretmen müdürün yanına gelecek ve telefonunu
kayıt edecek, bu uzun bir iş."*

---

## Kullanıcı kararları (bu plan bunları uygular)

| # | Karar |
|---|---|
| 1 | Öğretmen kendi isteğini gönderir; **müdür onaylar** |
| 2 | Okul eşleşmesi **kurum kodu** üzerinden (başka okulda geçersiz) |
| 3 | Müdür tayini çıkan öğretmeni listeden çıkarabilir |
| 4 | Secret bulutta durur; KVKK metnine bir satır eklenir |
| 5 | Öğretmen **kendi** kodunu, müdür **okulunun tümünü** görür |
| 6 | Silme yalnızca telefonu keser; tahtadaki dosya işi ayrı (aşağıda) |

---

## Kabul edilmiş risk — yazıya dökülmüş hâli

Müdür bir öğretmeni listeden çıkardığında:

- ✅ Öğretmenin **telefonu** kod üretmeyi bırakır (internete bağlanınca)
- ❌ **Tahtadaki dosya** onu tanımaya devam eder

Sebep: tahta ağa çıkmıyor (temel mimari karar). Tahtaya ancak flash
bellekle yeni dosya götürülünce yetki kapanır.

Yani secret'ı not almış veya telefonu uçak modunda tutan biri tahtayı
açmaya devam edebilir. **Kullanıcı bu riski bilerek kabul etti**
(18 Eylül 2026): "yalnızca telefonu keselim, dosya işini boş verelim."

Bu, kilidin zaten "caydırıcı katman" olarak konumlandırılmasıyla
tutarlı — panelin kaynak düğmesi kilidi zaten atlıyor.

> **Arayüzde gizlenmeyecek:** silme onay ekranı bunu açıkça yazar.

---

## Ölçülen gerçek: `school_teachers` onaysız

`firestore.rules:185` — öğretmen kendi kaydını **kendisi** oluşturuyor:

```
allow create, update: if request.auth != null
  && request.resource.data.teacherUid == request.auth.uid
  && id == request.resource.data.schoolId + '_' + request.auth.uid;
```

Yani Google hesabı olan herkes `775214` kurum kodunu seçip "Mimar
Sinan Ortaokulu öğretmeni" olarak kaydolabiliyor. Şu an zararsız
(dizinde görünmek dışında yetki vermiyor).

**Ama tahta yetkisini doğrudan buna bağlarsak okul dışından biri istek
gönderebilir.** Müdür onayı tam olarak bu boşluğu kapatıyor — yani
kullanıcının eklediği onay şartı gerekliydi, süs değil.

Mevcut "Öğretmen Onayı" sekmesi **yöneticilik başvurularını**
gösteriyor (`pendingRequestsForSchool`), tahta yetkisini değil. Yeni
bir onay akışı gerekiyor.

---

## Yeni şema

```
school_boards/{schoolId}/
├── duty/{dutyId}          (mevcut)
├── notices/{noticeId}     (mevcut)
└── teachers/{teacherUid}  ← YENİ
```

Doküman içeriği:

```json
{
  "teacherUid": "KplpM8ib...",
  "ad": "Yusuf YILMAZ",
  "kod": "YYILMAZ",
  "totpSecret": "45O6OJ5S...",
  "durum": "bekliyor",
  "istekZamani": "2026-09-18T14:00:00+03:00",
  "onayZamani": "",
  "onaylayanUid": ""
}
```

**Doküman kimliği = `teacherUid`.** Sebep: her öğretmenin tek kaydı
olur, sorgu yerine tek `get()` yeter (maliyet kararı #2 ile tutarlı)
ve aynı kişi kuyruğu dolduramaz.

### Secret'ı kim üretiyor

**Öğretmenin telefonu.** Gerekçe: secret üretimi zaten cihazda
(`TahtaTotp.secretUret()`), ve öğretmen isteği gönderirken üretmek
ek tur gerektirmiyor. İdareci onayladığında secret zaten orada.

Alternatif (müdür onaylayınca üretsin) reddedildi: onay anında ikinci
bir yazma turu gerekirdi ve müdürün telefonu offline'sa onay askıda
kalırdı.

### Firestore kuralı

```
match /school_boards/{schoolId}/teachers/{teacherUid} {
  // Öğretmen KENDİ kaydını okur ve oluşturur.
  allow read: if request.auth != null
    && (request.auth.uid == teacherUid || isSchoolAdminOf(schoolId));

  // İstek gönderme: yalnızca kendi adına, yalnızca "bekliyor".
  // Kendini onaylayamaz — yetki yükseltme koruması.
  allow create: if request.auth != null
    && request.auth.uid == teacherUid
    && request.resource.data.teacherUid == request.auth.uid
    && request.resource.data.durum == 'bekliyor';

  // Onay/ret ve silme: yalnızca o okulun onaylı yöneticisi.
  allow update, delete: if isSchoolAdminOf(schoolId);
}
```

Kritik nokta: `allow create` **`durum == 'bekliyor'`** şartı taşıyor.
Bu olmadan öğretmen kendi kaydını `onayli` yazıp kendini yetkilendirir.

---

## Akış

### Öğretmen tarafı

```
Profil > Tahta Kilidi
  └─ (kayıtlı değilse) [Tahta yetkisi iste]
       → telefon secret üretir
       → school_boards/{okul}/teachers/{uid} yazılır
          durum: "bekliyor"
       → "İsteğiniz müdüre iletildi"

  └─ (onaylandıysa) 6 haneli kod ekranı (mevcut)
```

Okul kimliği profilden geliyor (`meb_775214`), yani öğretmen
okulunu zaten seçmiş durumda. Ayrı bir kurum kodu girişi gerekmiyor.

### Müdür tarafı

```
Okul Yönetim Paneli > Tahta Yönetimi > Öğretmenler
  ├─ Bekleyen istekler (N)
  │    Yusuf YILMAZ        [Onayla] [Reddet]
  └─ Yetkili öğretmenler (M)
       Ayşe DEMİR          [Çıkar]
```

`[Çıkar]` basıldığında onay penceresi:

> **Ayşe DEMİR çıkarılsın mı?**
>
> Telefonu kod üretmeyi bırakacak.
>
> ⚠️ Tahtalardaki mevcut dosya onu tanımaya devam eder. Yetkisi
> tamamen kapanması için yeni kurulum dosyasını tahtalara götürün.

### Kurulum dosyası üretimi

`ogretmenler` listesi artık **cihazdaki depodan değil**, buluttaki
`teachers` koleksiyonundan geliyor — yalnızca `durum == "onayli"`
olanlar.

---

## Mevcut yapıya ne olacak

| Parça | Karar |
|---|---|
| `TahtaOgretmenDeposu` (cihaz) | **Kalıyor** — çevrimdışı yedek ve elle ekleme için |
| Elle "Öğretmen Ekle" + QR | **Kalıyor** — telefonu olmayan/eski telefonlu öğretmen için |
| `SecretSatiri` (bugün eklendi) | Kalıyor |
| Nöbetçi, duyuru, USB anahtar, kurulum | Değişmiyor |

Kullanıcı kararı: *"müdür yönetim panelinde okul bilgileri, tahtalara
duyuru ve usb anahtarı oluşturma seçenekleri yine kalsa."*

Yani otomatik kayıt **ek bir yol**, mevcut yolun yerini almıyor.

---

## Maliyet

Firestore ücretsiz katman: 50K okuma / 20K yazma / gün.

| İşlem | Sıklık | Yazma | Okuma |
|---|---|---|---|
| Öğretmen istek gönderir | bir kez | 1 | 0 |
| Müdür onaylar | bir kez | 1 | 0 |
| Müdür listeyi açar | ara sıra | 0 | ~40 |
| Kurulum dosyası üretimi | dönemde birkaç | 0 | ~40 |
| Öğretmen kendi durumunu okur | uygulama açılışı | 0 | 1 |

40 öğretmenli okul, ilk kurulum: **80 yazma, ~80 okuma**. Sonrası
neredeyse sıfır. Bütçe freni (günlük 1500 yazma) için önemsiz.

---

## KVKK

Secret bulutta duruyor. Değerlendirme:

- **Öğretmen verisi ≠ öğrenci verisi.** Hafızadaki "Seçenek A" kararı
  öğrenci verisi içindi; bu personel verisi.
- Zaten `school_teachers` koleksiyonunda öğretmenin adı, e-postası,
  okulu duruyor. Secret onlardan **daha az** kişisel — rastgele dize.
- **Aydınlatma metnine bir satır eklenecek**: "tahta açma yetkisi
  kullanıyorsanız, cihazınızın ürettiği bir erişim kodu okulunuzun
  kaydında saklanır."

**Buluta çıkmayacak olan:** "kim hangi tahtayı ne zaman açtı"
günlüğü. O, Fiziksel Mekan Güvenliği kapsamında ve MEB ile sözleşme
gerektirir. Günlükler tahtada kalmaya devam ediyor.

---

## Aşamalar

### Aşama 1 — Veri katmanı ve kural
- `school_boards/{schoolId}/teachers/{uid}` kuralı
- `TahtaYetkiDeposu` (istek gönder, durum oku, onayla, çıkar)
- Kural testleri: kendini onaylayamaz, başka okulu göremez, veli hiç

### Aşama 2 — Öğretmen tarafı
- `tahta_kilidi_screen`'e "Tahta yetkisi iste" düğmesi
- Durum gösterimi: bekliyor / onaylı / reddedildi
- Onaysızsa kod üretilmez

### Aşama 3 — Müdür tarafı
- `tahta_yonetimi_screen`'de bekleyen istekler bölümü
- Onayla / reddet / çıkar
- Çıkarma uyarısı (yukarıdaki metin)

### Aşama 4 — Kurulum dosyası
- `ogretmenler` listesi buluttan, `durum == "onayli"` süzgeciyle
- Cihazdaki elle eklenenlerle **birleştirme**
- Boş listeyle dosya üretimi engelli (mevcut davranış korunuyor)

### Aşama 5 — Doğrulama
- Kural testleri (Java 21 gerekiyor — açık borç)
- Gerçek cihazda uçtan uca: istek → onay → kod → tahta açılıyor

---

## Açık sorular

1. **Reddedilen öğretmen tekrar isteyebilir mi?** Öneri: evet, ama
   müdür "reddedildi" durumunu görsün ki aynı kişiyi tekrar tekrar
   değerlendirmesin.

2. **Okul yöneticisi yokken kim onaylar?** (18 Eylül, kullanıcı sordu)

   Not: "müdür" şart değil — mevcut mekanizmada **okul yöneticisi**
   unvanı kimde olursa o onaylıyor. BTR öğretmeni de yöneticilik
   başvurusu yapıp onaylanabilir; ek geliştirme gerekmez.

   Kullanıcı ayrıca sordu: *"masaüstü uygulamadan daha geniş
   yetkilerle BTR öğretmeni isterse yetki verebilecek mi?"*

   **Ölçüm:** Ana Program şu an **tamamen çevrimdışı** tasarlandı
   (`ana_program/__init__.py`) — hiç bulut bağlantısı yok, imzalı
   dosya üretiyor. Oradan bulut onayı vermek için Firebase kimlik
   doğrulama + Google girişi eklemek gerekir. Hafızadaki not:
   *Windows'ta Google girişi paket sınırı nedeniyle imkânsız.*

   **Karar ertelendi** — kullanıcı: "önce şu elimizdeki işi bitirip
   sonra masaüstü uygulamasını daha detaylı konuşalım." Ana Program
   tasarımıyla birlikte ele alınacak.

3. **İki okulda çalışan öğretmen?** (18 Eylül, kullanıcı itiraz etti)

   İlk taslakta "kapsam dışı" yazmıştım; kullanıcı haklı olarak
   sordu. Türkiye'de ikinci okulda görevlendirme yaygın.

   Şu anki engel: profil **tek okul** tutuyor
   (`profil_okul_id__{uid}`), yani öğretmen ikinci okulu seçtiğinde
   birincisinin yerine geçiyor.

   Yeni şema bunu kendiliğinden destekliyor: kayıt
   `school_boards/{schoolId}/teachers/{uid}` yolunda, yani **okul
   başına ayrı doküman**. Aynı öğretmen iki okulda ayrı secret'la
   kayıtlı olabilir.

   Eksik olan **arayüz**: öğretmenin hangi okul için istek
   gönderdiğini seçebilmesi ve iki kaydı birden görebilmesi.
   Aşama 2'de ele alınacak; şema değişikliği gerektirmiyor.
