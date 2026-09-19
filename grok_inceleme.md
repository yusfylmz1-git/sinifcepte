# SınıfCepte — Sert Denetim Raporu

**Dosya:** `grok_inceleme.md`  
**Tarih:** 19 Eylül 2026  
**Denetçi:** Grok (salt okunur, kod değiştirilmedi)  
**Kapsam:** Flutter istemci, Firestore kuralları, Cloud Functions, web admin paneli, okul yöneticisi paneli, e-kilit / tahta kilidi, Android/iOS yapılandırması, maliyet modeli, ürün/pazar iddiaları  
**Yöntem:** Kaynak kod + kurallar + paneller satır satır; önceki iki denetim (`grok_analiz.md` 31 Ağu, `codex-inceleme.md` 17 Eyl) mevcut koda karşı yeniden doğrulandı  
**Cihazda çalıştırılmayanlar:** Firestore emülatör saldırı senaryosu, gerçek FATİH ağı, tahta Python (`sinifcepte-tahta` bu workspace’te yok), Play Console, iPhone kamera izni

Bu belge bir özet değil. Her madde, ileride hangi somut felaketi üreteceğini de yazar. Tahmin olan yer “ölçülmedi” veya “pazar yorumu” diye işaretlidir.

---

## Karar

| Rol | Kullanır mıydım? | Tek cümle |
|---|---|---|
| **Proje yöneticisi** | **Hayır — Türkiye geneli yayın.** | Öğretmen asistanı çekirdeği olgunlaşıyor; veli köprüsü, e-kilit ve yayın hattı üretime çıkamaz. |
| **Öğretmen** | **Kendi sınıfı, kendi telefonu, veli kapalıysa temkinli evet.** | Plan PDF, katılım, sınıf listesi, offline iş gerçek. Yedek almak var; yedeği uygulamaya geri yüklemek yok. |
| **Veli** | **Hayır.** | Meşru bağ yolu kurallarla çelişiyor; sahte bağ yolu açık; Google + düşük entropili kod; push yok. |
| **Okul müdürü** | **Hayır.** | Panel “Öğretmen Onayı” gösteriyor, onaylayamıyor; tahta “kaydettim” diyor, USB’ye nöbetçi girmiyor; imza anahtarı bulutta düz. |
| **MEB / ilçe koordinatörü** | **Kesinlikle hayır.** | Paralel veli kanalı, resmî dil, KVKK TTL yalanı, IDOR, debug imza. |

**Yayın eşiği:** Aşağıdaki K1–K9 kapanmadan tek bir gerçek veli davet edilmemeli, tek bir tahta okula bırakılmamalı, Play’e AAB yüklenmemelidir. Öğretmenin kendi cihazındaki offline iş (sınıf, katılım, plan PDF) bu eşiğin dışındadır — o çekirdek ayrı ve daha sağlıklıdır.

---

## Önceki denetimlere karşı dürüstlük

31 Ağustos ve 17 Eylül raporlarındaki bazı iddialar **kapanmış**. Bunu gizlemek denetimi zayıflatır. Kapananlar:

| Eski iddia | Bugün |
|---|---|
| Yedek düğmesi dosya yazmıyor | **Kapandı.** `BackupService` WAL checkpoint + kopya + paylaşım. |
| “5 saniyede PDF” snackbar yalanı | **Kapandı.** Hub “Kurul Tutanakları”; gerçek üreticiler var. |
| Senkron “başarıyla güncellendi” deyip bayt indirmiyor | **Kısmen.** Sınav gerçekten iner; takvim/kazanım dürüstçe “uygulamayı güncelleyin” der. `force: true` sayacı yine yakar. |
| KVKK “öğrenci numarası telefondan çıkmaz” | **Kapandı.** Metin numarayı buluta koyduğunu söylüyor. |
| Destek talebini yönetici okuyamaz | **Kısmen.** Kural `isAdmin()` açtı; panelde kuyruk UI’si yok. |
| Admin `localStorage` rol seçici | **Kapandı.** Google + custom claim. |
| Cloud Functions yok | **Eskidi.** `publishRemoteConfig` + `fetchOsymTakvim` var. Veli redeem / TTL / FCM yok. |
| Android `POST_NOTIFICATIONS` yok | **Kapandı.** |
| `tokenGecerli` hiç yoktu | **Dar saldırı kapandı.** Token’sız bağ yazılamıyor. Asıl IDOR (kimlik ≠ içerik) duruyor. |

**Kapanmayanlar bu raporun gövdesidir.** “Yorum yazdık, kural ekledik, test yeşil” ile “saldırı kapandı” aynı şey değildir. Testler, yol–içerik uyuşmazlığını ve öğretmen kolundan sınıf spoof’unu hâlâ yeşil saymıyor çünkü o senaryoları yazmamış.

---

# A. Kritik (P0) — yayın durdurucu

Bunlar “sprint sonuna” maddesi değildir. Her biri tek başına ürünü, okulu veya faturayı yakar.

---

### K1. Başka öğrencinin özel verisine erişim (veli IDOR)

**Risk:** Kritik  
**Yüzey:** Güvenlik / KVKK / çocuk verisi  
**Kanıt:** `firestore.rules:63-71, 108-110, 240-246` · `lib/core/cloud/cloud_ids.dart:62-67`

`parentHasStudent` belge **yolunun varlığına** bakar. `create` kuralı belgenin kimliğinin `studentCloudId` ile aynı olmasını **zorunlu tutmaz**. Yalnızca:

1. yol `request.auth.uid_` ile başlar,
2. gövdedeki `parentUid` çağıranın kendisidir,
3. gövdedeki `codeHash` + `studentCloudId` bir token ile eşleşir.

**Saldırı:** Saldırgan kendi çocuğu için geçerli bir kod alır (veya K4 ile tarar). Sonra:

- yol: `parent_links/{saldırganUid}_{stu_kurbanÖğretmen_42}`
- gövde: `studentCloudId` = **kendi** öğrencisi, `codeHash` = o token

Kural geçer. Bundan sonra `parentHasStudent(kurban)` true olur. Mesaj, randevu, sağlık/durum bildirimi okunur; sahte kayıt yazılır.

İstemci kanonik kimlik üretir (`CloudIds.parentLinkId`). **Güvenlik istemcide değildir.** Özel APK, emülatör, script yeter.

**İleride nasıl felaket olur**

1. Pilot okulda bir veli “yanlış çocuğun mesajını gördüm” der. Bu, teknik destek değil; savcılık + KVKK Kurulu dosyasıdır.
2. Basın “uygulama başka velinin çocuğunu açtı” cümlesini ürünün bütününe yapıştırır. Öğretmen asistanı da ölür.
3. `exists(yol)` modeli durdukça her yeni koleksiyon (ödev, not, yoklama) aynı delikten akar. Bugün “veli not görmesin” kararı sizi kurtarmaz; yarın o kararı değiştirirseniz sızıntı otomatik büyür.

**Ne kapanmış sayılmaz:** Token kanıtı eklendi. Token, **hangi yolun** yazıldığını kilitlemiyor.

---

### K2. Herhangi bir sınıfın duyurusu, bağ bile olmadan

**Risk:** Kritik  
**Yüzey:** Güvenlik  
**Kanıt:** `firestore.rules:63-66, 258-271`

```
allow create: if (veli kolu: kendi bağı + exists(parent_links/...))
  || ownsStudent(request.resource.data.studentCloudId);
```

`ownsStudent` = kimlik `stu_{benimUid}_` ile başlıyor mu. Gerçek öğrenci belgesi, öğretmen rolü, sınıf sahipliği yok.

**Saldırı A (öğretmen kolu):** Oturum açmış herhangi biri `studentCloudId: stu_{kendiUid}_1` yazıp `parent_class_access/{kendiUid}_{cls_kurbanUid_N}` oluşturur. `parentHasClass` yine `exists(yol)` olduğu için hedef sınıfın duyuruları açılır.

**Saldırı B (veli kolu):** Gerçek bir bağ varken `studentCloudId` kendi çocuğu, belge kimliği hedef sınıftır. Çocuğun o sınıfta olduğu doğrulanmaz.

Sınıf kimliği `cls_{öğretmenUid}_{yerelId}` desenindedir. Öğretmen UID’si okul dizininden (Y8) okunur; yerel id 1..n taranır.

**İleride**

1. Sınav tarihi, veli toplantısı, “X öğrencisi revirde” türü duyuru başka sınıfa sızar.
2. Kadro `allow read: if request.auth != null` (`firestore.rules:497`) ile birleşince: duyuru + öğretmen adı + branş + görüşme saati. Okul içi istihbarat aracı olur.
3. “Duyuru zararsız” diye ertelenirse, aynı `parentHasClass` yarın not/ödev kapısı yapılır. Delik mimariye gömülüdür.

---

### K3. Meşru veli bağı kurulamaz — ürün kendi kuralını geçemez

**Risk:** Kritik  
**Yüzey:** Bug + güvenlik onarımının yan etkisi  
**Kanıt:** `cloud_token_repository.dart:236-264` · `parent_link_bridge.dart:184-195` · `firestore.rules:90-96, 205-207, 240-246`

Üç bağımsız red:

1. `commitParentLink` bağ belgesine **`codeHash` yazmıyor.** Kural `tokenGecerli(request.resource.data.codeHash, ...)` istiyor. Alan yok → red.
2. Aynı batch, veli olarak token sayacını artırıyor veya tokenı siliyor. Token yazma kuralı yalnız `ownsStudent` öğretmenine açık. Veli öğretmen değildir → red.
3. `parent_class_access` `exists()` kullanır, `existsAfter()` değil. Aynı batch’te yeni oluşan bağ görünmeyebilir → red.

Kullanıcıya giden cümle: *“İnternet bağlantınızı kontrol edin.”* (`parent_link_bridge.dart:193-195`)

Kabuk onarımı `ensureParentAccess` `codeHash` yazar ama asıl yol boş `linkedViaTokenCode` bırakır; `sha256('')` ile onarım da düşer.

**İleride**

1. Öğretmen kod üretir, veli girer, “çalışmıyor” der. Öğretmen “internetin yok” der. İki taraf da ürünü bırakır.
2. Ekip “bağlanamıyorlar” diye kuralı gevşetir (tarihte oldu: token’sız create). K1/K2 yeniden açılır.
3. Yerel (aynı cihaz) yol çalıştığı için testler yeşil kalır. Sahada iki cihazlı gerçek veli hiç bağlanamaz. Bu, “test var” yalanının klasik halidir.

**Kök neden:** Güvenlik yaması istemci sözleşmesine bağlanmadan kurala yazıldı. Kural doğru niyet, istemci eski sözleşme. İkisi birden “doğru” görünüp birlikte ölü.

---

### K4. Referans kodu taranır; ikinci faktör aynı cevapta çözülür

**Risk:** Kritik  
**Yüzey:** Güvenlik / PII / fatura  
**Kanıt:** `parent_token_repository.dart:54-58, 249-254` · `parent_token_model.dart:155-158` · `cloud_token_repository.dart:141-157, 168-192` · `firestore.rules:197-207` · `parent_link_bridge.dart:127-157`

| Parça | Gerçek |
|---|---|
| Entropi | `Random()` (kriptografik değil), `1000+nextInt(9000)` → sınıf etiketi başına **9.000** |
| Biçim | `SC-{sınıf}-{4 hane}` — sınıf adı kamuya açık |
| Tuz | Kaynakta sabit: `sinifcepte_salt_2026` |
| Okuma | `parent_tokens/{hash}` **get her oturuma açık**, list kapalı |
| Rate limit | Yok |
| App Check | Yok |
| Token gövdesi | `studentName` + **`studentNumber` düz** |
| 2FA sırası | Lookup **önce**, numara karşılaştırması **sonra** |

Saldırgan 9.000 hash’i önceden hesaplar, oturumla `get` dener. Token bulununca yanıtta okul numarası gelir. “İkinci faktör” aynı pakettedir.

`tokenGecerli` status, `expiresAt`, `linkedParentCount`, `secondFactorHash` **kontrol etmez**. İstemci kontrol eder; özel istemci atlar.

Token `update` eski sahibi doğrulamaz: aynı kodu üreten ikinci öğretmen birincinin kaydını ezer.

**İleride**

1. Bir script, popüler etiketler (`5A`, `8B`) için gece tarar. Çocuk adı + numara + sınıf elinde olur. K1 ile birleşince başka çocukların kutusu da açılır.
2. App Check yok + Blaze + kaba kuvvet `get` = **fatura saldırısı**. İstemci 1500 yazma freni okumayı durdurmaz; saldırgan sizin uygulamanızı kullanmak zorunda değildir.
3. “Kod kısa olsun, öğretmen tahtaya yazar” UX kararı, güvenlik kararını ezmiş. Kısa kod + sunucusuz doğrulama birlikte yaşayamaz.

---

### K5. Release, debug anahtarıyla imzalanıyor

**Risk:** Kritik (yayın)  
**Yüzey:** Dağıtım / sahte APK  
**Kanıt:** `android/app/build.gradle.kts:38-43`

```
signingConfig = signingConfigs.getByName("debug")
```

TODO yorumu duruyor. `google-services.json` SHA-1 debug hash’ine bağlı.

**İleride**

1. Play’e bu AAB giderse sonraki yükleme imza çatışmasına düşer. Kullanıcı güncelleyemez; iki “resmî” APK oluşur.
2. Debug keystore her geliştirici makinesinde aynı ailedendir. Sahte “SınıfCepte” APK, aynı imza ailesiyle dağıtılabilir; veli köprüsü ve tahta secret’ı o APK’ya iner.
3. İmza bir kez mağazaya yazıldıktan sonra değiştirmek, tüm kurulumları yeniden indirtir. Erken hata ucuz, geç hata okul yılı kaybıdır.

---

### K6. E-kilit: okulun imzalama özel anahtarı Firestore’da düz metin

**Risk:** Kritik  
**Yüzey:** E-kilit / hesap ele geçirme  
**Kanıt:** `tahta_anahtar_bulut_yedegi.dart:17-30, 80-87` · `firestore.rules:701-703`

Ed25519 **özel** anahtarı `school_boards/{schoolId}/gizli/imzalama_anahtari` belgesinde base64. Parola yok. Cihazda yoksa açılışta buradan geri yüklenir.

Kod bunu “kabul edilen risk” diye yazıyor. Kabul, etkiyi küçültmez.

Kural: yalnız o okulun onaylı yöneticisi okur/yazar. Yani:

- o müdürün Google hesabı,
- veya Firebase Admin SDK / proje sızıntısı,

anahtarı verir. Yorumdaki “tüm okullar” cümlesi proje sızıntısı içindir; tek müdür hesabı kendi okulunu yakar.

**İleride**

1. Müdür telefonunu kaybeder, Google oturumu açık kalır. Saldırgan geçerli `okul_config` üretir: sahte nöbetçi, sahte duyuru, sahte öğretmen listesi (içinde TOTP secret’ları).
2. “Kilit zaten caydırıcı, panel kaynak düğmesi atlıyor” gerekçesi, **imza katmanını** da boşaltır. İki katman birden “tiyatro” olunca üründe güvenlik iddiası kalmaz.
3. Okul “tahtalarımız kilitli” diye veliye/idareye anlatır. Anahtar buluttayken bu cümle yanıltıcı ticari beyandır.

Karşı argüman (adil): anahtar kaybı sahada gerçek ve sık; müdür yedek almıyor. Doğru. Çözüm parolasız düz yedek değildir; müdür parolalı şifreli yedek veya donanım yedeğidir. “Müdür anlamaz” diye kriptografiyi kaldırmak, müdürü korumaz.

---

### K7. E-kilit: sahte QR, canlı TOTP’yi saldırganın sunucusuna gönderir

**Risk:** Kritik  
**Yüzey:** E-kilit / sınıf içi saldırı  
**Kanıt:** `tahta_totp.dart:205-214, 285` · `tahta_ag_acici.dart:65-70` · `tahta_kilidi_screen.dart:554-589`

SC2 yükü: `SC2:{okulId}:{tahtaId}:{nonce}:{unixDakika}:{ip}:{port}`

Telefon:

1. okul eşleşmesini kontrol eder,
2. TOTP üretir,
3. `http://{ip}:{port}/ac` adresine `{"kod":"<6 hane>"}` POST eder.

IP denetimi yalnız IPv4 biçimi. **Özel ağ şartı yok.** `8.8.8.8` de, saldırganın VPS’i de geçer. HTTPS yok. HMAC yok. `nonce` ve `unixDakika` ayrıştırılıyor, **kullanılmıyor.**

**Sınıf içi saldırı (gerçekçi):** Öğrenci kendi telefonunda sahte SC2 QR gösterir (`okulId` gerçek kurum kodu). Öğretmen “tahtadaki QR” sanıp okutur. 6 hane 30 saniye içinde saldırgana gider. Saldırgan aynı kodu gerçek tahtaya yazar veya LAN’da `/ac` dener.

Plan (`docs/plan-qr-ile-acma.md`) “HMAC gerekmez, TOTP yeter” diyor. TOTP düz HTTP ile **karşı tarafa** gidince TOTP’nin sırrı 30 saniyeliğe sızmış olur. Tahta tarafı bu repoda yok; `/ac` ve `DenemeHizi` **ölçülmedi**. Telefon tarafı tek başına yeter.

**İleride**

1. İlk hafta “QR çalışmıyor” (AP izolasyonu — planın kendi uyarısı, ölçüm yok). Öğretmen 6 haneye döner. Ürün vaadi düşer.
2. AP izolasyonu kapalı bir okulda sahte QR bir kez çalışır. “Öğrenciler tahtayı açtı” idare krizidir. MEB etkileşimli tahta şartnamesi (kaynak düğmesi) zaten kilidi atlar; üzerine sizin kilidiniz de öğrencinin QR’ı ile aşılırsa ürün alay konusu olur.
3. `HttpClient` varsayılanı yönlendirmeyi izler (**ölçülmedi**). Açık yönlendirme, TOTP’yi başka origin’e taşır.

---

### K8. Admin sınav yayını, canlı sistemi geri sarar ve ezer

**Risk:** Kritik  
**Yüzey:** Admin / 30.000 cihaz  
**Kanıt:** `functions/index.js:75-80` · `admin_app.js:1327-1333` · `manifest_manager.js:6-15, 102-127` · `sync_service.dart:207`

Sunucu mevcut Remote Config şablonunu okur, **gelen anahtarları karşılaştırma yapmadan** üzerine yazar. `exams_version` monoton artmak zorunda değildir.

Panel sınav yayınında yerel manifestin **hepsini** gönderir: `exams_version`, `exams_payload`, `min_app_version`, `maintenance_mode`, `calendar_version`, …

Yeni tarayıcıda localStorage boşsa varsayılan: `examsVersion: 1`, `maintenanceMode: false`, `minRequiredAppVersion: '1.0.0'`.

**Senaryo:** A, v10 + bakım açık + min 1.2.0 yayınlar. B yeni tarayıcıdan “sınav yayınla” der → canlı v2, bakım kapanır, min sürüm düşer. Cihazlar `uzakSurum <= yerelSurum` ile **yeni sınavı yok sayar**. Öğretmenler eski LGS tarihiyle kalır.

**İleride**

1. Ertelenen bir LGS tarihi yanlış kalır. Öğretmen velilere yanlış son başvuru söyler. Bu, ürün hatası değil okul skandalıdır.
2. Bakım modu “açtım” sanılır; başka tarayıcı kapatır. Kırık sürüm sahada kalır (K9 ve Y14 ile birleşir).
3. Tek callable, tek onay kutusu, bütün filoyu yönetir. Undo, taslak, staging, monoton sayaç yok. İnsan hatası kaçınılmazdır; sistem hatayı yayar.

---

### K9. Admin panelinde XSS → Remote Config

**Risk:** Kritik  
**Yüzey:** Admin / tedarik zinciri  
**Kanıt:** `admin_app.js:1168-1184, 1794-1811` · `calendar_manager.js:149-156` · `manifest_manager.js:179-188` · `index.html:14` · `firebase.json:62-70`

`kacisliMetin` bazı ÖSYM/MEB önizlemelerinde var. Sınav tablosu kullanmıyor:

- `exam.title`, `description`, `applicationUrl`, `doc_id` kaçışsız `innerHTML`
- `onclick="window.adminApp.editExam('${exam.doc_id}')"`
- JSON import şemasız
- `applicationUrl` protokol sınırı yok → `javascript:`
- CSP yok; header yalnız `X-Robots-Tag`
- SheetJS `cdn.jsdelivr.net`, SRI yok

Süper admin oturumunda `publishRemoteConfig` callable’ı vardır. XSS, K8’i tetikler.

**İleride**

1. “MEB genelgesini yapıştır” / “JSON içe aktar” günlük iştir. Kötü dosya bir kez yeter.
2. jsdelivr bozulursa Excel yolu da bozulur; panel üretim hattıdır, blog değildir.
3. Hosting herkese açık (`firebase.json` `public: admin_portal`). Claim’siz kullanıcı JS’i indirir; XSS için oturum gerekir ama yüzey herkese görünür.

---

# B. Yüksek (P1) — ilk gerçek kullanıcıdan önce

---

### Y1. “Kodu yenile” eski bulut kodunu iptal etmiyor

**Kanıt:** `parent_token_repository.dart:218-234, 265` · `class_reference_codes_modal.dart:278-318`

Ayrı “iptal” düğmesi buluttan siler. Yenileme yalnız yerel listeden çıkarır, yeni hash yayımlar. Eski hash `noExpiry` (2099-12-31) ile durur. Yerelde olmadığı için mezuniyet taraması da onu bulamaz.

**İleride:** Öğretmen “eski kodu yaktım” der. WhatsApp’ta kalan ekran görüntüsü sonsuza dek bağ kurar. Veli sayısı 2’ye kilitli sanılır; eski kod ayrı kotadır.

---

### Y2. Öğrenci silme / mezuniyet / nakil, veli erişimini kapatmıyor

**Kanıt:** `student_lifecycle_coordinator.dart:81-107` · `parent_token_repository.dart:882-884` · `parent_token_provider.dart:96-124`

Koordinatör bağlı velileri **öğretmen cihazındaki Prefs** listesinden alır. Asıl bağ veli cihazında ve `parent_links` koleksiyonundadır. Mesaj kutusu buluttan çeker; silme yolu çekmez.

`parentHasStudent` token’a ve `status` alanına bakmaz. Token silinse, bağ `archived` olsa bile `exists(yol)` true kalır.

**İleride:** Nakil olan çocuğun velisi eski sınıfın duyurusunu görür. KVKK “bağ kopunca erişim anında biter” (`legal_document_screen.dart:158-159`) yalan olur. Unutulma talebi teknik olarak teslim edilemez.

---

### Y3. Şube taşıma kurallarca reddediliyor

**Kanıt:** `cloud_token_repository.dart:494-507` · `firestore.rules:248-250`

İstemci öğretmen adına `parent_links.classCloudId` günceller. Kural update’i yalnız veliye ve yalnız `status` için açar. Batch düşer; yerel taşıma devam eder.

**İleride:** Yerel/bulut ayrışır. Veli eski şubede kalır veya hiç sınıf görmez. Öğretmen “taşıdım” der. Destek çözülemez; veri iki gerçeklidir.

---

### Y4. TOTP secret’ları bulutta ve USB’de düz metin

**Kanıt:** `tahta_yetki_deposu.dart:112-123` · `okul_config_model.dart:109-114` · `firestore.rules:714-716`

Öğretmen isteğinde secret belgeye yazılır. Yönetici okulun tümünü okur (`okulunKayitlari`). USB `okul_config.json` içinde `totpSecret` açık. İmza dosyanın **bütünlüğünü** korur, **gizliliğini** korumaz.

Kurulum QR: `SCT1:{okul}:{kod}:{ad}:{secret}` — fotoğraf = kalıcı yetki.

**İleride:** Flash bellek öğrenci dolabında bulunur. Listedeki her öğretmenin tahtası açılır. Aydınlatma metninde tahta/TOTP/imza **yok** (`legal_document_screen.dart`). Plan “bir satır eklenecek” diyor; eklenmemiş. Bu, KVKK md. 10 eksik aydınlatmadır.

---

### Y5. Müdür “öğretmeni çıkar” diyor; telefon kod üretmeye devam ediyor

**Kanıt:** `tahta_yetki_deposu.dart:244-263` · `tahta_kilidi_screen.dart:81-91` · `tahta_yonetimi_screen.dart` onay metni

Onay: “Telefonu kod üretmeyi bırakacak.” Gerçek: `cikar()` yalnız bulut belgesini siler. Öğretmen ekranı yerel kayıt varken buluta **hiç bakmaz**.

Air-gap (tahtadaki dosya kalır) yazılı ve dürüst. Telefonun kesileceği iddiası kodla yalan.

**İleride:** Tayini çıkan öğretmen, uçak modunda veya eski kayıtla tahtayı açar. İdare “sildim” der. Güvenlik olayı “ürün yalan söyledi” diye yazılır. USB yenileme unutulursa (20 tahta, flash bellek) yetki haftalarca açık kalır — bu kısım kabul edilmişti; telefon kısmı kabul edilmemişti.

---

### Y6. iOS kamera kullanım açıklaması yok

**Kanıt:** `ios/Runner/Info.plist` (NSCameraUsageDescription yok) · `tahta_kilidi_screen.dart` `MobileScanner`

iOS, açıklamasız kamera API’sinde uygulamayı öldürür. Flutter `errorBuilder` native kill’i yakalamaz. E-kilit ve veli QR’si iPhone’da açılışta çöker.

**İleride:** İlk iOS TestFlight kullanıcısı “uygulama kapandı” der. App Store review reddi. Tahta kilidi iOS’ta ölü doğar.

---

### Y7. App Check yok; istemci freni fatura koruması değil

**Kanıt:** `pubspec.yaml` (firebase_app_check yok) · `functions/index.js` (`enforceAppCheck` yok) · `firestore_budget_guard.dart:44` · `docs/BUDGET.md`

Günlük 1500 yazma **cihaz başına, SharedPreferences**. Kötü istemci yok sayar. Okuma durmaz.

API anahtarı istemcide (`firebase_options.dart`, `auth_gate.js`). Bu normaldir; koruma App Check + kural + kota olmalıdır. Üçüncüsü GCP konsolunda “yapılacak”; ikincisi K1–K4 ile delik; birincisi yok.

**İleride:** K4 taraması veya unutulmuş döngü Blaze faturasını şişirir. Alarm yoksa ilk haber kredi kartı ekstresidir. `BUDGET.md` $25 alarmı dokümandadır, kodda/konsolda kanıtı bu repoda yoktur.

---

### Y8. Nöbetçi ve idare duyurusu USB’ye girmiyor

**Kanıt:** `tahta_yonetimi_screen.dart:1159-1186, 1366-1377` · `okul_config_model.dart`

Nöbetçi/duyuru Firestore’a yazılıyor. `_configUret` `OkulConfigModel` kurarken `nobetciler` / `duyurular` vermiyor (boş varsayılan). Tahta ağa çıkmıyor. Pano içeriği tahtaya **hiç gitmiyor**.

Ekran “kaydedildi” diyor. Kullanıcı tahtada nöbetçi bekliyor.

**İleride:** E-kilitin tek somut okul vaadi (nöbetçi panosu) sahada boş ekrandır. Müdür “çalışmıyor” der, kilidi bırakır, kaynak düğmesine döner. Modülün varlık sebebi biter. Kod yorumu “rakipte yok, ayırt edici parça” diyor (`okul_config_model.dart:16-18`) — ayırt edici parça bağlı değil.

---

### Y9. Google hesabı olan herkes istediği okulun öğretmeni olur

**Kanıt:** `firestore.rules:166-191, 668-671`

`school_teachers/{schoolId}_{uid}` create: kendi uid + kanonik id. İstihdam kanıtı yok. Veli de (parent claim yazılmadığı için) kendi kaydını yazıp o okulun ad/branş/e-posta dizinini okur.

Müdür bu kaydı silemez (yalnız sahibi siler).

**İleride:** Sahte “öğretmen” kadro seçiminde çıkar, veli ona yazar. Okul dizinindeki e-postalar taranır. Tahta yetkisi müdür onayına bağlanmış (doğru); dizin üyeliği bağlanmamış. İki model çelişir.

---

### Y10. Excel ile eklenen kazanımlar yenilemede kayboluyor

**Kanıt:** `outcomes_manager.js:75-83, 110-129` · `admin_app.js:985-1026`

`save()` yeni ID’leri overrides’a yazar. `applySavedOverrides()` yalnız pakette **zaten var olan** ID’ye yama vurur. Excel her satıra `Date.now()` id üretir; paket silinen satırlar F5’te geri gelir.

Toast: “canlıya alındı.” Remote Config’e yazılmaz; mobil APK tohumunu değiştirmez.

**İleride:** Yaz tatili işi (36 haftalık Excel) bir yenilemede uçar. Yönetici “yükledim” sanır. Öğretmen yanlış ünite işler. Müfredat, ürünün en çok satılan vaadidir.

---

### Y11. “Tüm Veriyi İndir” sınavları indirmiyor

**Kanıt:** `admin_portal/index.html:108` · `cloud_exporter.js:45-56`

Düğme `examsManager` göndermiyor → `official_exams: []`. Takvim yalnız seçili yılı verir; dosya adı sabit `2025_2026`.

**İleride:** Felaket kurtarma boş sınav listesiyle yapılır. K8 ile birleşince yanlış yayın + boş yedek = geri dönüş yok.

---

### Y12. Gizlilik metni “otomatik silinir” diyor; sunucuda TTL yok

**Kanıt:** `legal_document_screen.dart:152-157` · `functions/index.js` (scheduled yok)

Durum 30 gün, randevu 90, mesaj/duyuru 365 — “otomatik silinir.” Cloud Functions’ta zamanlayıcı yok. İstemci temizlik, öğretmen uygulamayı açmazsa işlemez.

Numara yalanı kapanmış; yerini **TTL yalanı** almış.

**İleride:** KVKK denetiminde “saklama süresi politikada var, sistemde yok” bulunur. Rıza geçersiz sayılabilir. VERBIS / veri sorumlusu kimliği metinde hâlâ yok.

---

### Y13. Çekmece hâlâ “veri yalnız cihazda, şifreli SQLite” diyor

**Kanıt:** `app_drawer.dart:107, 464` · `pubspec.yaml` (sqlcipher yok)

Rozet: “Verileriniz yalnızca bu cihazda saklanır (KVKK Uyumlu).”  
Diyalog: “şifrelenmiş yerel SQLite.”

SQLite düz metindir. Veli adı, öğrenci numarası, mesaj, token, tahta anahtarı buluta çıkar.

**İleride:** Ekran görüntüsü, dava delilidir. “KVKK Uyumlu” rozeti 6502 / reklam mevzuatı açısından yanıltıcı ticari uygulamadır. Telefon köklenmiş veya yedeklenmişse sınıf listesi + veli telefonları açık dosyadır.

---

### Y14. Zorunlu güncelleme ve bakım, snackbar’dır

**Kanıt:** `academic_calendar_screen.dart:40-59` · `sync_service.dart:74-78` · `remote_manifest_service.dart:218`

`min_app_version` uygulamayı kilitlemez. Bakım mesajı da öyle. Kırık sürüm sahada kalır.

**İleride:** K8 ile birleşince: min sürümü yayınlarsınız, cihazlar almaz; alsa da kullanmaya devam eder. Force-update kapısı yokken Remote Config’te force-update alanı bulundurmak, operatörü yanıltır.

---

### Y15. Android exact alarm / boot receiver yok

**Kanıt:** `notification_service.dart:116-125, 139-154` · `AndroidManifest.xml` (SCHEDULE_EXACT_ALARM, BootReceiver yok)

`exactAllowWhileIdle` kullanılıyor; izin, receiver, boot yeniden kurma yok. Hata `debugPrint`. Kullanıcı “hatırlatma kuruldu” sanır.

**İleride:** Favori LGS, sessizce bildirim göndermez. Öğretmen ürünü “sınav kaçtı” diye suçlar. Güven, K8’deki yanlış tarihten farksız erir.

---

### Y16. Push yok; veli ürünü uygulama açıkken yaşar

**Kanıt:** `pubspec.yaml` (`firebase_messaging` yok) · `app_notification.dart` yorumu

Bildirim, çekilmiş veriden uygulama içi listedir. Telefon cebindeyken duyuru ulaşmaz.

**İleride:** WhatsApp 3 saniyede titrer. SınıfCepte titremez. Veli uygulamayı siler. Öğretmen “veli bakmıyor” der, tekrar WhatsApp grubuna döner. Veli modülünün pazar vaadi biter. (Pazar yorumu, kod gerçeğiyle kilitli.)

---

### Y17. Okul yönetim paneli bakılır, iş yapılmaz

**Kanıt:** `school_admin_panel_view.dart:90-101, 176-274, 285-396` · `firestore.rules:326-337, 356-360` · `school_admin_repository.dart`

| Sekme | Gösterdiği | Yapabildiği |
|---|---|---|
| “Öğretmen Onayı” | Yöneticilik **başvuruları** | Hiç. Onay yalnız süper admin CLI. |
| “Şikâyetler” | Açık raporlar | Hiç. Kural `reviewed` yazmaya izin veriyor; UI/repo metodu yok. |

Hata yutuluyor: sorgu fail → boş liste → “bekleyen yok.”

Tahta öğretmen onayı ayrı ekranda (`TahtaYonetimiScreen`). İsim çakışması.

**İleride:** Müdür paneli açar, düğme arar, kapatır. “Yönetim sistemi” vaadi (`docs/ProjeDetayı.md`) sahada bir vitrindir. 1000 okul × CLI onay = tek kişi darboğazı; ölçek operasyonel olarak imkânsız.

---

### Y18. `bootstrap_super_admin.mjs` claim yazmıyor

**Kanıt:** `scripts/admin/bootstrap_super_admin.mjs:23-37`

`setCustomUserClaims` çağrılmaz; komut `console.log` edilir. Credentials yoksa “runbook” deyip çıkar.

**İleride:** İlk süper admin hiç oluşmaz. Portal “yetkiniz yok” der. Tersi: biri SDK’yı yanlış UID’ye bağlar, UI’dan geri alınamaz. Üretim hattının anahtarı bir print ifadesidir.

---

### Y19. Token her ekran açılışında yeniden yayımlanıyor

**Kanıt:** `parent_token_provider.dart:74-83`

Yorum “yalnızca bulutta olmayanlar” diyor. Kod tüm aktif tokenları yazar. Sayaç eskiyse bulut sayacı geri çekilir (K4’teki `update` kuralı eski sahibi doğrulamaz).

**İleride:** Dönem başı 30 öğrenci × 3 yazma × her açılış = bütçe freni + sayaç bozulması. “İkinci veli bağlanamıyor / fazla bağlanıyor” teşhisi imkânsızlaşır.

---

### Y20. Reddedilen öğretmen tekrar tahta yetkisi isteyemez

**Kanıt:** `tahta_yetki_deposu.dart:103-109, 221-241` · `tahta_kilidi_screen.dart` “Tekrar iste”

`reddet` belgeyi silmez. `istekGonder` mevcut kayda dokunmaz. Mesaj yine “onay bekleniyor.” UI düğme gösterir; kural öğretmen `update`’ini yasaklar.

**İleride:** Yanlışlıkla reddedilen öğretmen müdürün kapısına gider — tam da otomatik kaydın çözmek istediği sahne. Modül kendi UX vaadini iptal eder.

---

# C. Orta (P2)

| ID | Bulgu | Kanıt | İleride |
|---|---|---|---|
| O1 | Veli bağlanırken “kime bağlanıyorsun” onayı yok | `parent_student_connect_screen.dart:167-173` `confirm` vermez | Yanlış kod + aynı numara (okullar arası tekrar) → yanlış çocuk. |
| O2 | Randevu günü öğretmenin gününü yok sayar; çakışma `false` yutar | `parent_child_detail_screen.dart` · `cloud_communication_repository.dart:1008-1036` | Aynı saate yığılma; kural veliye tüm randevuları göstermez, catch “çakışma yok” der. |
| O3 | `school_boards` + nöbet/duyuru: oturumlu herkes okur | `firestore.rules:593, 615, 624` | `meb_*` tahmin; başka okulun nöbetçi adları. |
| O4 | Yetki isteği okul üyeliği istemez | `firestore.rules:710-719` | Spam kuyruğu; müdür her Google hesabını eler. |
| O5 | Anahtar yenilenince “yedek alındı” bayrağı kalır | `tahta_anahtar_deposu.dart:143-151` | Müdür eski 88 karakteri saklar; yeni anahtar kaybolur. |
| O6 | QR `nonce` / dakika / `tahtaId` telefonda yok | `tahta_kilidi_screen.dart:554-589` | Replay; 8/A kodu 8/B’de de üretilir. |
| O7 | `force: true` senkron sayacı, indirmeden ilerler | `sync_service.dart:143-156` | “Güncelleme var” bir kez görünür, APK eski kalır. |
| O8 | Takvim sihirbazı 2029+ dini bayram uyduruyor | `calendar_wizard.js` | Yanlış tatil, yanlış kazanım haftası. |
| O9 | Mesaj gövde uzunluğu kuralda yok | `firestore.rules` messages create | 1 MiB doküman, maliyet + DoS. |
| O10 | Destek kuyruğu admin portalda yok | `admin_portal/` grep boş | “24 saat yanıt” vaadi operasyonsuz. |
| O11 | Geri yükleme servisi var, ekran yok | `backup_service.dart` `restoreDatabase` | Yedek alınır, telefona geri konamaz. Telefon kaybı = yıl kaybı. |
| O12 | `isParent() = auth != null` | `firestore.rules:37-39` | Tek başına yetki vermez ama rol modeli yok; her yeni kural bu yoruma yaslanır. |
| O13 | Kadro her oturuma açık | `firestore.rules:497` | Sınıf yolu tahmininde öğretmen PII. |
| O14 | Windows/Linux school bind atlanır | `school_bind_gate.dart` | Masaüstü “yerel öğretmen” ile bulut kimliği sapması. |
| O15 | Secret exception string’ine girebilir | `tahta_totp.dart:68, 79` | Debug/Crashlytics sızıntısı (**ölçülmedi**). |
| O16 | `data-admin-only="super"` HTML’de yok | `auth_gate.js:67-69` | Moderatör yayın düğmesini görür, sunucu reddeder. |
| O17 | Hosting CSP / frame / referrer yok | `firebase.json:62-70` | K9’un zeminidir. |
| O18 | `commitBatch` merge:true ile token sayacı | yorum + `moveClassAccess` | Kısmi yazma, şema kirlenmesi. |
| O19 | `Random()` token, `Random.secure()` TOTP | iki dünya | Aynı üründe iki rastgelelik standardı; yanlış olan veli tarafı. |
| O20 | PRD / README / ProjeDetayı / walkthrough dört ayrı ürün | `docs/01-PRD.md`, `README.md`, `docs/ProjeDetayı.md` | Yeni ajan/geliştirici yanlış özelliği “tamam” işaretler. |

---

# D. Düşük (P3) — itibar ve sürtünme

- README hâlâ “A new Flutter project.”
- PRD hâlâ yoklama satıyor; kod yoklamayı yasaklıyor. Doğru ürün kararı, ölü belgeyle çelişiyor.
- `walkthrough.md` kesik; `flutter analyze 0 hata` iddiası bu oturumda koşulmadı.
- Android uygulama kimliği yorumu “TODO: Specify your own unique Application ID.”
- Sürüm `1.0.0+1` — mağaza olgunluğu iddiası yok, iyi; panel “30.000 öğretmen” dili var, kötü.
- Drawer profili “SınıfCepte Kullanıcısı” sabit.
- Veli hata mesajlarının çoğu hâlâ “internetinizi kontrol edin.”
- Cepte sohbet LLM değil (dürüst); “yoklama” kelimesi devamsızlık ekranına map’leniyor (tuzak).
- `BUDGET.md` yazma 500, kod 1500 — hangi rakam alarmı?
- Reklam geliri iki belgede iki dünya (`maliyet.md` ~$23k, `BUDGET.md` ~$3.5k); ikisi de SDK yokken Excel.
- iOS display name düzelmiş (`SınıfCepte`); Android label da `SınıfCepte`.

---

# E. E-kilit modülü — derin kesit

Bu bölüm K6, K7, Y4, Y5, Y6, Y8, Y20, O3–O6’yı bir ürün olarak okur.

## Ne olduğu

Okul etkileşimli tahtasını (FATİH / ETAP) “öğretmen kodu olmadan açılmasın” diye kilitlemek. Mimari karar: **tahta ağa çıkmaz.** USB ile imzalı `okul_config.json` + `.sig`. Açma: TOTP 6 hane veya (yeni) SC2 ile yerel HTTP.

Bu, Türkiye’de ClassDojo / WhatsApp / e-Okul’un vermediği **niş**. Doğru soru: niş, gerçek bir kilit mi, yoksa kaynak düğmesinin etrafında dolaşan bir tören mi?

## Dürüst olanlar

1. Ekranda “panelin kaynak düğmesi kilidi atlar” yazıyor. MEB şartnamesi md. 1.11.3. Caydırıcı katman iddiası gizlenmiyor.
2. TOTP elle yazılmış, RFC 6238 vektör testleri var, `Random.secure()` 160 bit.
3. Ed25519 asimetri: tahtada yalnız public key. Flash kopyası **yeni** geçerli dosya üretemez.
4. Secret ve anahtar cihazda Keystore/Keychain. `shared_preferences` bilinçli reddedilmiş.
5. Öğretmen self-onaylayamaz (`durum == 'bekliyor'`). Emülatör testleri bu kolu kapsıyor.
6. `gizli/` alt koleksiyonu pano okumasından ayrılmış.
7. Ağ hataları “yanlış kod” demiyor; 6 hane geri düşüşü var.
8. Boş öğretmen listesiyle USB üretilmiyor.
9. Kamera şart değil (elle SCT1, “QR olmadan kod”).
10. QR diyalog ANR’si testle kilitli.

## Törenin kırıldığı yer

```
Müdür paneli          Öğretmen telefonu         Tahta
     │                        │                    │
     │  secret Firestore düz   │                    │
     │  anahtar Firestore düz  │                    │
     │  “çıkardım” ────────────┼─ yerel secret durur │
     │  nöbetçi kaydettim ─────┼── USB’ye girmiyor ─┤ boş pano
     │                        │  sahte QR POST HTTP │
     │                        │                    │ kaynak düğmesi
```

Kilidin üç iddiası:

| İddia | Kod gerçeği |
|---|---|
| Yetkisiz öğretmen açamasın | USB’deki secret + 6 hane. USB kaybı = herkes. Secret bulutta = müdür hesabı = herkes. |
| Yetkiyi kestiğimde bitsin | Tahta air-gap: bitsin diye USB. Telefon: bitmiyor (Y5). |
| Nöbetçi/duyuru tahtada | Firestore’a yazılıyor, tahta okumuyor (Y8). |

QR ile açma, ölçülmemiş FATİH AP izolasyonu üzerine inşa edilmiş. Plan “önce ölç” diyor; kod yazılmış. İki olası saha sonucu:

- AP izolasyonu açık → SC2 hiç çalışmaz, 6 hane kalır (vaat düşer).
- Kapalı → K7 sınıf içi phishing çalışır (güvenlik düşer).

Saat kayması: tahta NTP’siz. Yorum doğru: TOTP şaşınca USB/PIN şart. Mobil ekleme `pinHash` yazmıyor. PIN yedek yolu fiilen boş.

## Kullanım kolaylığı (müdür)

40 öğretmenli okul:

1. Kendisi süper admin CLI ile okul yöneticisi olmalı (Y17, Y18).
2. Anahtar sessizce üretilir, parolasız buluta gider (K6). “Yedeğimi al” belki hiç görünmez.
3. Öğretmenler “Tahta yetkisi iste” der. Müdür ayrı ekranda onaylar.
4. USB üretir, 20 tahtaya elden götürür. Nöbetçi bu dosyada yoktur.
5. Yeni öğretmen / telefon değişimi / tayin: USB turu tekrar. “Otomatik kayıt” yalnız telefonu doldurur, tahtayı değil.
6. Reddedilen öğretmen takılır (Y20).

Bu, “saatler süren yüz yüze QR”den iyidir. Hâlâ bir **sistem yöneticisi işi**dir. Müdür yardımcısı bu ekranı anlamaz; anlamasın diye anahtar gizlendi, gizlenince anahtar buluta düz yazıldı. Sürtünme güvenlikle takas edilmiş, ikisi de kaybetmiş.

## Maliyet (e-kilit)

Plan A (tahta 5 sn Firestore poll, günde ~350k okuma) **yok** — doğru. SC2 yerel HTTP, Firestore’a dokunmaz.

Gerçek maliyet küçük: yetki belgesi, yönetim ekranında `limit(200)` okuma, anahtar 1 yazma. Asıl maliyet para değil **operasyon** (USB turu) ve **olay** (K6/K7).

## KVKK (e-kilit)

Öğrenci verisi tahtaya bilinçli sokulmuyor — doğru ve önemli.  
Öğretmen TOTP sırrı ve okul imza anahtarı buluta çıkıyor; aydınlatma susuyor. Personel verisi de KVKK’dır. “Öğrenci yok = sorun yok” hukuken yanlış.

---

# F. Admin panelleri — derin kesit

İki ayrı yüzey var. Kullanıcı “admin” deyince ikisini karıştırır; kod da isimle karıştırıyor.

## F1. Web `admin_portal/` — süper admin içerik hattı

**Kim:** `adminRole == super | moderator` (claim). Yayın yalnız super.  
**Ne işe yarıyor gerçekten:** ÖSYM/MEB sınav JSON’u düzenleyip Remote Config’e basmak.  
**Ne işe yaramıyor:** Takvim ve kazanım sayacı artsa bile cihaz APK baytını değiştirmez. README “+1 artır, mobil senkron” diyor — yanlış.

### Müdür bu paneli kullanmaz

Google hesabı + super claim. Okul müdürü buraya giremez, girmemelidir. Girse bile “kendi okulu” diye bir kapsam yok; bütün filoyu ezer.

### Kullanım felaketleri (operatör)

1. İki tarayıcı = iki gerçek (K8).
2. Excel yükle, F5, iş yok (Y10).
3. Tam yedek al, sınav yok (Y11).
4. Bakım aç = aslında sınav yayınla.
5. Moderatör yayın düğmesini görür, 403 yer (O16).
6. İlk super admin script’i çalışmaz (Y18).
7. Destek talepleri burada yok (O10). Isı haritası, ban, push, crash viewer (`ProjeDetayı.md`) yok.

Bu panel bir **CMS iskeleti**dir, operasyon konsolu değil. Tek tehlikeli düğmesi (sınav yayınla) hem en işe yarayan hem en yıkıcı parçadır.

### Güvenlik özeti (web)

| Katman | Durum |
|---|---|
| Auth | Düzgün (Google + claim) |
| Callable yetki | Düzgün (`yetkiKontrol` super) |
| Beyaz liste | Var, 800 KB sınır var |
| Monoton sürüm | Yok |
| Parametre izolasyonu | Yok (hepsi birden) |
| XSS | Açık |
| CSP | Yok |
| App Check | Yok |
| Hosting auth | Yok (JS herkese) |

Auth düzelmiş. Asıl risk artık “kim girdi” değil “giren neyi ezebilir ve hangi HTML çalışır.”

## F2. Uygulama içi okul yöneticisi paneli

**Kim:** `schoolAdminStatus == approved` + `token.schoolId`. Claim yalnız Admin SDK (`approve_school_admin.mjs`). Yetki yükseltme kapalı — bu kısım sağlam.

**Akış:** Öğretmen serbest notla başvurur → süper admin makinede script → çıkış/giriş. Belge, e-Devlet, TC yok. Tasarım raporu (`docs/sinifcepte-okul-yoneticisi-secimi-raporu.md`) kodda yok.

**Müdür günü:**

1. İki sekme, sıfır düğme (Y17).
2. Tahta Yönetimi ikonu — asıl iş orada.
3. Sahte `school_teachers` kaydını silemez (Y9).
4. Şikâyeti “incelendi” yapamaz.
5. İkinci yönetici davet edemez.

**Kullanım kolaylığı notu:** “Okul Yönetimi” adı, e-Okul idare paneli beklentisi yaratır. İçeride kuyruk vitrini vardır. İlk 10 saniye güveni yer.

Hata yutma (`catch → []`) 18 Eylül’de ölçülmüş bir PERMISSION_DENIED’ı “bekleyen yok”a çevirmişti. Kural düzelmiş; yutma duruyor. Bir sonraki kural sapmasında aynı körlük.

---

# G. Maliyet

## Kodun doğru içgüdüsü

- Öğrenci notu / katılım / devamsızlık / veli telefonu buluta gitmiyor.
- Snapshot listener yok (grep boş).
- Delta senkron, batch, Remote Config manifest, token-after-use silme niyeti.
- İstemci yazma freni 1500/gün/cihaz.
- E-kilit poll yok.

Bu yüzden **iletişim-only** projeksiyon ucuz çıkar. `cost_model.dart` + `maliyet.md`: 1000 okul ~$240/ay Firestore. Model kendi formülünü test eder; üretim çağrılarını saymaz.

## Modelin saymadıkları (kodda var)

Okul dizini her açılış, destek, kadro, randevu, durum, tahta yetki/pano/anahtar, saklama silmeleri (önce oku), `audit_logs`, token republish (Y19), `school_teachers` self-join.

“Tipik gün 15 yazma” dönem başı kod yağmurunda yanlış. Fren bunu kısmen keser; kesince veli “internet yok” görür (eski hastalık).

## Asıl maliyet parası değil

| Kalem | Neden büyük |
|---|---|
| K4 kaba kuvvet okuma | App Check yok, get açık |
| K8 tek yayın | Destek + itibar + yanlış sınav |
| USB turu | 20 tahta × her öğretmen değişimi |
| Super admin CLI | 1000 okul insan-saat |
| Reklam slaytı | SDK yok; iki belge çelişiyor; Play veri güvenliği formu henüz yok |

Blaze varsayılan harcama tavanı koymaz. `BUDGET.md` Katman 2 yapılmadan kredi kartı bağlamak, K7’nin HTTP’si kadar bilinçli bir deliktir.

**Katılımı veliye açmak:** `maliyet.md` yazmayı katlar. Asıl sebep maliyet değil: modül olgun değil, davranış verisi hassas, geri almak güven yıkar. Bu noktada belge haklı.

**Reklam:** `ad_gate.dart` kapalı, `google_mobile_ads` yok. 750k veli × eCPM hesabı testte çivilenmiş bir Excel’dir. Gelir değildir. Üzerine iş planı kurulmaz.

---

# H. Kullanım kolaylığı — öğretmen, veli, müdür

## Öğretmen (çekirdek) — göreli olarak en iyi yüzey

Çalışan: sınıf/öğrenci, Excel/PDF içe aktarma, katılım ızgarası, canlı ders algılama, plan PDF, BEP, kulüp, sınav/quiz/proje, WhatsApp metni, yedek **alma**, Google + okul bağlama kapısı.

Sürtünen:

- Yedeği **geri yükleme** ekranı yok (O11).
- Veli kodu üretilir; veli bağlanamaz (K3) veya bağlanırsa güvenlik delik (K1). Öğretmen teşhisi “internetin yok.”
- “Kodu yenile” eski kodu yakmaz (Y1).
- Çekmece KVKK yalanı (Y13).
- Cepte “belge hazırlarım” der, model değildir — kabul; “yoklama” yazınca devamsızlık açılır — tuzak.
- Masaüstünde bind gate yok (O14).

Öğretmen ürünü, veli/e-kilit/admin olmadan da değerlidir. Bu cümle pazarlama değil: offline SQLite + TYMM plan PDF, e-Okul’un vermediği iştir.

## Veli — sürtünme üstüne risk

Zorunlu: Google hesabı. SMS yok (bilinçli). Google’sız veli = dışarıda.

Sonra: 4 haneli kod + okul numarası. Kod çalışmazsa internet cümlesi. Çalışırsa (özel istemci) yanlış çocuk (K1) veya onay ekranı yok (O1).

Uygulama açıkken: duyuru, mesaj (saat penceresi), randevu, durum. Not yok, katılım yok, program vaadi belgelerde var kodda dar, push yok (Y16).

Bu, WhatsApp grubunun **daha sürtünmeli, daha riskli, daha sessiz** halidir. Veli neden indirsin?

## Müdür — görev ile ekran uyuşmuyor

Beklenti: öğretmenleri onayla, şikâyeti kapat, tahtayı yönet, ikinci müdürü davet et.  
Ekran: salt okunur kuyruk + ayrı tahta sayfası + CLI bağımlılığı.

Tahta sayfası teknik olarak zengin, operasyonel olarak yalan (Y5, Y8). Nöbetçi “ayırt edici özellik” tahtaya ulaşmaz.

---

# I. Pazar analizi

Kod gerçeği ile pazar yorumu ayrılır.

## Kodda gerçek ürün

**SınıfCepte bugün:** Türkiye’ye özgü, offline-first öğretmen defteri. TYMM/Maarif kazanım seti, yıllık/günlük plan PDF, katılım (yoklama değil), e-Okul PDF/Excel’den öğrenci listesi, BEP taslağı, kulüp, resmi sınav takvimi (Remote Config), Google kimlikli dar veli köprüsü, taslak e-kilit.

**SınıfCepte belgelerin sattığı:** e-Okul yanına yönetim sistemi, veliye not/yıldız, ısı haritası, ticket, push, reklam ekonomisi, biyometrik kilit, yoklama.

İkisi aynı ürün değildir. Satış cümlesi geniş, kod dar. Dar olan kısım daha doğru ve daha savunulabilir.

## Rakip haritası (pazar yorumu)

| Rakip | Öğretmenin gerçeği | SınıfCepte |
|---|---|---|
| **e-Okul** | Zorunlu yoklama, not, resmî evrak | Rakip değil. Paralel defter. “e-Okul uyumlu karne” şablon + seed; sorumluluk öğretmende. API yok — PDF/Excel içe aktarma yasal gri, teknik olarak öğretmenin dosyası. |
| **WhatsApp** | Fiilî veli kanalı, sıfır kurulum | 1:1 mesaj + şablon. Grup kaosunu bitirmez. Push yokluğu burada kaybettirir. |
| **K12NET / okul LIS** | İdare dayatır, lisanslı | Okul satışı yok; öğretmen bireysel. Müdür paneli K12NET ile kıyaslanamaz. |
| **Okulist / Sevgi Defteri** | Veli iletişim + okul | SınıfCepte veli yüzeyi daha ince. |
| **ClassDojo** | Yıldız + veli | Katılım benzer; TYMM/MEB evrakı yok. TR’de “yabancı uygulama / veri yurt dışı” direnci. SınıfCepte de Firebase/Google kullanıyor — aynı direnç sizi de vurur. |
| **Google Classroom** | Ödev, Drive | Classroom değil; Google yalnız kimlik. |
| **FATİH / ETAP kilit** | Kaynak düğmesi, yönetici şifresi kamuya yakın | E-kilit niş. Şartname kilidi atladığı sürece “güvenlik ürünü” satılamaz; “sınıf düzeni / caydırıcı” satılabilir — o zaman K6/K7 kabul edilemez. |

## Türkiye gerçeği (pazar yorumu, koda bağlı)

1. **MEB onayı olmadan okul genelgesi yok.** “MEB Takvimi”, “resmî A4”, “e-Okul uyumlu” arayüzde; hukuk metninde “MEB ürünü değil.” Öğretmen odası kullanım koşullarını okumaz. Bu, 6502 riski ve bakanlık “okulda resmî sandılar” krizidir.
2. **KVKK + çocuk.** Veri sorumlusu kim? Metin “çoğu verı öğretmende” der. Ad, numara, mesaj Google’da. Aydınlatma, açık rıza, VERBIS, yurt dışı aktarım belgelenmeden okul bahçesine girilmez. TTL yalanı (Y12) ve çekmece rozeti (Y13) rızayı zayıflatır.
3. **Öğretmen cihazı eski Android, veri paketi kısıtlı, Google’sız veli var.** Offline-first doğru. Veli köprüsü çevrimiçi Google — “her çocuk” ilkesiyle çelişir.
4. **FATİH ağı:** AP izolasyonu, proxy, Linux tahta. Ölçülmeden yazılan SC2, ya ölü ya tehlikeli.
5. **Dağıtım:** Debug imza (K5) = mağaza yok. iOS kamera (Y6) = Apple yok. README şablon = devir yok.

## Farklılaşma — ne kalır?

Savunulabilir üç cümle:

1. “e-Okul’un yanında, internetsiz, kazanımdan plan PDF’ine.”
2. “Yoklama değil katılım; resmî yoklama e-Okul’da kalır.”
3. “Tahta kilidi caydırıcı katmandır, güvenlik ürünü değildir” — ancak o zaman K6/K7/Y8 kapanmadan **bu cümle de kurulamaz**, çünkü ürün hem kilit satıyor hem tiyatro olduğunu küçük puntoyla söylüyor.

Savunulamayan cümleler: yönetim sistemi, veli notu, reklamle kârlı 1000 okul, resmî evrak, e-Okul aktarımı.

## Go-to-market

**Önerilen (pazar yorumu, kod kısıtıyla):**

- Faz 0: K1–K9. Veli kapalı veya “yakında.” E-kilit kapalı veya yalnız laboratuvar tahtası.
- Faz 1: 10 öğretmen, kendi cihazı, yedek alma **ve geri yükleme**, plan PDF, katılım. Play **yayın imzası**. Reklam kapalı.
- Faz 2: Veli, sunucu redeem + yüksek entropi + App Check + push olmadan “WhatsApp’tan iyi” iddiası kurulamaz. Push yoksa veli kanalı yan üründür.
- Okul lisansı: müdür paneli düğmesizken satılamaz.
- E-kilit: AP izolasyonu ölçümü + USB’ye pano içeriği + secret’ın buluttan çıkışı olmadan “okula kurduk” denemez.

**Gelir:** İlk gerçek para öğretmen Pro (PDF filigransız / çok sınıf) veya okul lisansı olabilir. Reklam, çocuk+eğitim+veli ekranında hem KVKK hem itibar hem Play beyanıdır; kapı bile yokken Excel kârı yazmak plan değil, kendini avutmadır.

---

# J. Sistemik kök nedenler

Tek tek bug’ların altında dört alışkanlık var. Bunlar durursa K1’in kardeşi yarın başka koleksiyonda doğar.

1. **İstemciye güven.** Kural, istemcinin kanonik id üreteceğini varsayıyor. Test, mutlu yolu yeşil sayıyor. Saldırı özel istemcidir.
2. **Yorumu kural sanmak.** “Token hâlâ kullanılabilir olmalı”, “yalnızca eksikler yayımlanır”, “telefon kesilir”, “nöbetçi tahtada”, “otomatik silinir.” Yorumlar doğru niyet; kod başka.
3. **İki sözleşmeli yama.** Güvenlik kuralı `codeHash` ister, istemci yazmaz (K3). Yayın fonksiyonu merge eder, panel tüm varsayılanı gönderir (K8). Her biri ayrı ayrı “düzgün.”
4. **Caydırıcılık gerekçesiyle kriptografiyi boşaltmak.** E-kilit “zaten atlanır” diye özel anahtarı buluta düz yazıyor. Bu gerekçe bir kez kabul edilince TOTP secret, SCT1 QR, HTTP POST da aynı torbaya girer. Caydırıcı katmanın da bir tabanı vardır; taban şu an kaynak düğmesinin altındadır.

Doküman fosili (PRD yoklama, ProjeDetayı veli yıldızı, README şablon) beşinci alışkanlıktır: ajanlar ve insanlar yanlış gerçeğe uyar.

---

# K. Düzeltme sırası (kod yazılmadan öneri)

Yapılmayacaklar bu oturumda yapılmadı. Sıra, riskin yayılma hızına göredir.

### Durdur (hemen)

1. Veli davetini kapatın veya yalnız güvenilir sunucu redeem’e alın.
2. E-kilit SC2’yi kapatın (SC1 + 6 hane kalsın) — tahta `/ac` ve AP izolasyonu ölçülmeden.
3. Play’e debug imzalı AAB yüklemeyin.
4. Admin’de ikinci tarayıcıdan sınav yayınlamayın; tek operatör, yayın öncesi mevcut RC sürümünü not edin.

### Aşama 1 — yetki modeli (K1 K2 K3 K4 Y1 Y2 Y3)

- Belge kimliği = `uid + '_' + *CloudId` kuralda zorunlu; içerik alanları `getAfter` ile kilitli.
- `parent_class_access` öğretmen kolundaki çıplak `ownsStudent` kalksın; sınıf sahipliği + gerçek bağ.
- `exists()` yerine status==active; `existsAfter()` batch’te.
- Redeem Callable + transaction + App Check + rate limit. 4 hane bitsin.
- `commitParentLink` kural sözleşmesiyle aynı alanları yazsın (veya istemci yolu kapansın).
- Yenileme eski hash’i silsin. Silme/mezun/nakil/şube bulut `teacherUid` sorgusu + sunucu.
- Negatif kural testleri: yol≠içerik, öğretmen kolu spoof, arşivlenmiş bağ.

### Aşama 2 — e-kilit (K6 K7 Y4 Y5 Y6 Y8 Y20)

- Özel anahtar parolasız bulutta durmasın.
- SC2: özel IP allowlist, HTTPS veya HMAC, nonce tek kullanımlık, tahtaId bağlama; sahte QR’da TOTP karşı tarafa gitmesin.
- `cikar()` yerel secret’ı da geçersiz kılsın (bulut durumunu her açılışta sorun).
- Nöbetçi/duyuru USB paketine girsin veya UI “yalnızca bulut, tahta görmez” desin.
- iOS `NSCameraUsageDescription`.
- Aydınlatma: TOTP, imza anahtarı, USB.
- FATİH AP izolasyonu **ölçülsün**; ölçülmeden SC2 vaat edilmesin.

### Aşama 3 — admin (K8 K9 Y10 Y11 Y18)

- Sunucuda monoton `exams_version`; yayın yalnız değişen anahtarlar.
- `innerHTML`/`onclick` bitsin; JSON şema; CSP; SRI.
- Overrides yeni ID eklesin; “canlıya alındı” yalanı kalksın.
- Tam yedek gerçekten tam olsun.
- `bootstrap_super_admin.mjs` claim yazsın veya “çalışmaz” desin.
- Okul paneli: ya düğme (şikâyet, dizin) ya isim değişsin.

### Aşama 4 — yayın ve hukuk (K5 Y7 Y12 Y13 Y14 Y15 Y16)

- Release keystore, Play App Signing.
- App Check monitoring → enforcement.
- GCP bütçe alarmı.
- TTL’i metinden silin veya scheduled function yazın.
- Çekmece rozetini doğru cümleyle değiştirin; SQLCipher veya “şifreli değil” deyin.
- Force-update gerçek kapı veya alanı kaldırın.
- Exact alarm / boot veya inexact’e düşün.
- FCM olmadan veli “anlık” demeyin.

### Aşama 5 — ürün dürüstlüğü

- PRD/README/ProjeDetayı/walkthrough tek gerçeğe çekilsin.
- Veli ve e-kilit, çekirdek öğretmen asistanından **ayrı olgunluk** ile satılsın.
- Reklam slaytı SDK’sız dosyadan çıksın.

---

# L. Olumlu — yok sayılmayacaklar

Sert rapor, emeği silerek güvenilir olmaz.

- Yoklama yasağı kodda gerçek; katılım ayrı. Hukuken doğru içgüdü.
- Offline-first, per-uid DB, runtime font indirmesinin kaldırılması.
- Yedek artık dosya yazıyor; PDF üreticileri gerçek; sınav senkronu gerçek.
- Auth gate localStorage rolünden çıktı; callable claim sunucuda.
- Destek kuralı yöneticiye açıldı.
- KVKK numara beyanı düzeltildi; `privacy_claims_test` kilidi var.
- Listener yasağı tutuluyor; maliyet içgüdüsü (Remote Config, delta, batch) doğru.
- TOTP RFC testleri, Ed25519 ayrı `.sig`, Keystore, self-onay yasağı, SC1/SCT1 ayrımı.
- Birçok “sessiz başarısızlık” bilinçli olarak mesaja çevrilmiş (tahta ağ durumları, yedek 88 karakter, token yayın sonucu bekleme).
- Test hacmi geniş. **Ama** yeşil test, yol–içerik IDOR’unu ve iki cihazlı veli batch’ini kapsamıyor; yeşil ≠ güvenli.

Bu liste, K1–K9’u “ama test var” diye ertelemek için kullanılamaz.

---

# M. Ölçülmeyenler

Aşağıdakiler bu turda **çalıştırılmadı / bu repoda yok**:

- Firestore emülatöründe K1/K2 exploit’inin canlı kanıtı (statik kural okuması yeterli görüldü; Codex 17 Eyl aynı saldırıyı tarif etmiş, kod kapanmamış).
- Tahta Python: `/ac`, `DenemeHizi`, saat kayması, PIN, `surum` geri sarma.
- Gerçek FATİH AP izolasyonu ve Firestore çıkışı.
- iPhone’da kamera kill.
- Android’de exact alarm’ın sessiz fail’i.
- Crashlytics’e TOTP secret düşüp düşmediği.
- `flutter analyze` / tam test suite bu oturumda koşulmadı.
- Play Console / Firebase App Check konsol durumu.
- GCP Billing alarmının gerçekten kurulu olup olmadığı.

---

## Kapanış

SınıfCepte, 31 Ağustos’taki “snackbar yalanı ürünü” değildir. Öğretmen defteri ciddiye alınmış, bazı yalanlar kapatılmış, claim’li admin auth gelmiş, tahta için gerçek kriptografi yazılmıştır.

Aynı kod tabanı hâlâ **üç ayrı olgunlukta üç ürün** taşır:

1. Öğretmen offline asistanı — kullanılabilir çekirdek.
2. Veli köprüsü — meşru yol kırık, sahte yol açık.
3. E-kilit + okul idaresi — niş doğru, teslimat tören.

Üçünü birden “üretime hazır” demek, 2 ve 3’ün deliklerini 1’in üzerine bulaştırır. İlk gerçek veli ve ilk gerçek tahta, bu raporun A bölümündeki dokuz maddeden herhangi biriyle ürünü bitirebilir.

Öncelik cümlesi: **yetkiyi sunucuya alın, e-kilitten TOTP’yi internete göndermeyi kesin, yayın düğmesini tek parametreye kilitleyin, debug imzayı bırakın.** Gerisi ürün tartışmasıdır. Bunlar tartışma değildir.
