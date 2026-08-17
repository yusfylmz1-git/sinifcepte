# 🏫 SınıfCepte — Okul Yöneticisi Seçimi ve Doğrulama Mekanizması

**Kapsam:** Bu rapor, VeliModül & SchoolNetwork ana planındaki "Okul Yöneticisi" (RBAC) rolünün *kim tarafından, nasıl, hangi güvenlik önlemleriyle* atanacağını detaylandırır. Ana plandaki diğer bölümlere (okul eşleştirme, veli-öğretmen eşleşmesi, KVKK vb.) dokunmaz — sadece admin atama sürecine odaklanır.

---

## 1. Neden Bu Ayrı Bir Problem?

Öğretmen rolü kendi sınıfıyla sınırlı bir yetki taşıdığı için görece düşük risklidir — bir öğretmen sadece kendi öğrencilerinin velileriyle ilgili veri görür. Okul Yöneticisi rolü ise **okul geneline** yayılan bir görünürlük taşır: tüm sınıfların meta verisi, moderasyon kuyrukları, limit ayarları. Bu farkı yönetmenin tek yolu, admin rolünü "ilk giren kazanır" mantığıyla değil, **kimlik/görev doğrulamasına dayalı** bir süreçle vermektir. Aksi halde:

- Kötü niyetli biri kendini sahte müdür olarak tanıtıp bir okulun tüm öğretmen-veli ağının üst düzey görünürlüğünü ele geçirebilir.
- Gerçek müdür/müdür yardımcısı sistemden habersizken biri "okul yöneticisi" sıfatını üstlenip okul geneli duyuru yayınlayabilir.

Bu yüzden admin ataması, uygulamanın geri kalanından farklı olarak **insan onaylı bir moderasyon adımı** içerir.

---

## 2. Admin Rolünün Yetki Sınırları (hatırlatma)

Admin şunları yapabilir: okul geneli duyuru yayınlama, `maxLinkedParents` limitini değiştirme, `school_merge_queue`'daki manuel okul eşleştirme taleplerini onaylama, şüpheli kod deneme loglarını görüntüleme, okula yeni admin davet etme.

Admin şunları **yapamaz**: öğrenci/veli'nin kişisel iletişim bilgilerine (telefon, e-posta) erişmek, veli-öğretmen özel yazışmalarının içeriğini okumak, öğrenci silme (bu yetki sadece ilgili sınıf öğretmeninde kalır). Bu sınır, admin yetkisinin "süper kullanıcı" haline gelmesini engellemek için kasıtlıdır.

---

## 3. Soğuk Başlangıç: Bir Okulun İlk Admini

Bir okul sisteme eklendiğinde (öğretmen tarafından seçilmiş veya manuel eklenmiş fark etmez) **otomatik admin atanmaz**. Okul, admin doğrulaması yapılana kadar "adminsiz" durumda kalır ve bu durum sistemin temel işleyişini engellemez (bkz. Bölüm 7).

### 3.1 Başvuru Akışı

1. Admin olmak isteyen kişi (genelde müdür/müdür yardımcısı) uygulamada "Okul Yöneticisi Ol" seçeneğine girer.
2. Formda: ad-soyad, okuldaki unvan, T.C. kimlik numarasının son 4 hanesi (tam KEP gerekmez, sadece eşleşme kontrolü için), okulla ilişkisini kanıtlayan bir belge yüklemesi istenir:
   - Resmi görevlendirme yazısı fotoğrafı, **veya**
   - Okul mühürlü/imzalı bir yazı, **veya**
   - (İleri faz, opsiyonel) e-Devlet/MEBBİS üzerinden kurumsal kimlik doğrulama entegrasyonu — bu entegrasyonun teknik ve hukuki fizibilitesi ayrıca araştırılmalı, bu raporda varsayım olarak bırakılmıştır.
3. Talep `admin_verification_requests` koleksiyonuna `status: "pending"` ile düşer.
4. Moderasyon ekibi (başlangıçta muhtemelen tek kişilik bir operasyon) belgeyi inceler; okul adı/ilçe bilgisiyle belge içeriği tutarlıysa onaylar.
5. Onaylanınca kullanıcının `users/{userId}.roles` alanına `{ schoolId, role: "admin" }` eklenir ve kendisine bildirim gider.
6. Reddedilirse başvurana gerekçe gösterilir (örn. "belge okunaklı değil") ve yeniden başvuru hakkı tanınır — sınırsız deneme yerine 24 saatlik bekleme süresiyle spam önlenir.

### 3.2 Neden Otomatik Doğrulama Değil?

Belge sahteciliğini otomatik tespit etmek (OCR + resmi veritabanı çapraz kontrolü) hem teknik olarak karmaşık hem de MEB'in resmi personel veritabanına programatik erişim gerektirir ki bu erken fazda muhtemelen mümkün değil. Bu yüzden ilk sürümde **insan onaylı manuel inceleme** öneriliyor; ölçek büyüdükçe (yüzlerce okul) bu süreç kısmi otomasyona (örn. e-Devlet entegrasyonu) taşınabilir.

---

## 4. Zincir Güveni: Sonraki Adminlerin Eklenmesi

Bir okulda zaten en az bir onaylı admin varsa, ikinci/üçüncü admin eklemek dış doğrulama gerektirmez:

1. Mevcut admin "Yönetici Ekle" ile ikinci bir kişiyi (e-posta/telefon ile) davet eder.
2. Davet edilen kişi zaten uygulamada kayıtlı bir öğretmen hesabına sahipse daveti kabul eder ve admin olur.
3. Bu işlem `audit_logs`'a `"admin_invited_by": actorId` olarak yazılır.

Bu, her akademik yıl başında değişen müdür yardımcısı atamalarında moderasyon yükünü sıfıra indirir — sadece okulun *ilk* admini dış doğrulamadan geçer, sonrakiler mevcut admin zincirine güvenir.

---

## 5. Admin Boşalması ve Devir Senaryoları

| Durum | Kural |
|---|---|
| Tek admin okuldan ayrılıyor, yerine birini davet etmeden | Rol `inactive` olur, okul "adminsiz" duruma döner; `maxLinkedParents` gibi ayarlar son değerinde kilitli kalır, yeni admin doğrulaması Bölüm 3'teki soğuk başlangıç sürecini tekrar gerektirir. |
| Admin, görevi bilerek başka birine devrediyor (emeklilik, tayin) | Devir sırasında hem eski hem yeni admin uygulama içinden onay verir (çift taraflı teyit); dış doğrulama tekrar istenmez. |
| İki admin arasında yetki anlaşmazlığı (örn. kim gerçek müdür belirsiz) | Uygulama hakemlik yapmaz; her iki taraf da destek ekibine yönlendirilir, ihtilaf çözülene kadar okulun admin ayarları dondurulur (mevcut ayarlar geçerli kalır, değiştirilemez). |

---

## 6. Veri Şeması Eklentisi

```
users/{userId}
  - roles: [ { schoolId, role: "teacher" | "admin", grantedAt, grantedBy } ]

admin_verification_requests/{requestId}
  - userId, schoolId
  - fullName, titleClaimed: "müdür" | "müdür_yardımcısı" | "diğer"
  - documentRef (storage path, sadece moderasyon ekibi erişebilir, KVKK gereği sınırlı saklama süresiyle)
  - status: "pending" | "approved" | "rejected"
  - reviewedBy, reviewedAt, rejectionReason

admin_invites/{inviteId}
  - schoolId, invitedUserId, invitedBy
  - status: "pending" | "accepted" | "declined"
```

`documentRef` alanındaki kimlik/görevlendirme belgeleri hassas veri olduğu için ayrı bir storage bucket'ta, sadece moderasyon rolüne sahip hesapların erişebileceği kurallarla tutulmalı ve onay/red sonrası makul bir süre (öneri: 90 gün) sonunda otomatik silinmelidir — süresiz saklama KVKK'ya aykırı olur.

---

## 7. MVP'de Admin Rolünün Zorunlu Olmaması

Öğretmen-veli-öğrenci eşleşmesi, duyuru, randevu ve hızlı durum kartları gibi tüm temel akışlar **sınıf/öğretmen seviyesinde bağımsız çalışır** ve admin rolüne ihtiyaç duymaz. Bir okul hiç admin doğrulaması yapmasa bile öğretmenler ve veliler sistemi sorunsuz kullanmaya devam eder — admin sadece ek kolaylık (okul geneli duyuru, merge queue onayı, limit ayarı) sağlar. Bu, "sıfır sunucu maliyeti / hızlı başlangıç" ilkesiyle uyumludur ve moderasyon ekibinin başlangıçta küçük kalabilmesini sağlar.

---

## 8. Açık Kalan ve Ayrıca Araştırılması Gereken Noktalar

- **e-Devlet/MEBBİS entegrasyonu** teknik ve hukuki olarak mümkün mü, mümkünse hangi API/izin süreci gerekiyor — bu raporun kapsamı dışında, ayrıca araştırılmalı.
- **Belge sahteciliği tespiti**: ilk fazda tamamen insan onayına dayanıyor; ölçek büyüdükçe bu tek kişilik moderasyon operasyonu darboğaz olabilir, bu noktada otomasyon veya üçüncü taraf kimlik doğrulama servisi değerlendirilmeli.
- **Hukuki sorumluluk**: sahte belge ile admin olan biri okul geneli yanlış bilgi yayınlarsa sorumluluk zinciri (kullanıcı sözleşmesi/KVKK metni içinde) netleştirilmeli — bu bir hukuk danışmanına danışılması gereken bir konu, bu raporda teknik akış dışında bir görüş belirtilmemiştir.
