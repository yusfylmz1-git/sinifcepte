# 📱 SınıfCepte VeliModül & SchoolNetwork — Kesinleşmiş Mimari Plan (v2)

Bu doküman, ilk taslak plan üzerine yapılan inceleme sonucunda ortaya çıkan boşlukları (okul eşleştirme mantığı, kod güvenliği, çoklu veli/velayet senaryosu, yaşam döngüsü akışları, KVKK somutlaştırması, ölçeklenebilirlik) kapatarak hazırlanmış, uygulamaya doğrudan geçilebilecek netlikte bir revizyondur. Her bölüm "kim, ne zaman, hangi veriyle, hangi kural altında" sorularına cevap verecek şekilde yazılmıştır.

---

## 1. Genel Mimari Vizyon (değişmedi, referans için)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ÖĞRETMEN UYGULAMASI                              │
│  - Yerel SQLite (Offline-First: Sınıflarım, Notlar, Planlar)                 │
│  - Okul Seçimi / Manuel Okul Ekleme + Eşleştirme Kuyruğu                     │
│  - Veli Referans Kodu Üreteci (süreli, tek kullanımlık)                      │
│  - Sınıf & Okul Duyuruları / Veli Randevu Yönetimi                           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                        │ (Delta Sync & Cloud Firestore)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                   GÜVENLİ BULUT KATMANI (Firebase / Supabase)               │
│  - schools/{schoolId} — kanonik okul kaydı (MEB kurum kodu ile eşleşmiş)     │
│  - school_merge_queue/{requestId} — moderasyon bekleyen manuel okullar       │
│  - student_tokens/{tokenHash} — süreli, tek kullanımlık eşleşme kodları      │
│  - parent_links/{linkId} — veli↔öğrenci çoklu bağlantı kayıtları            │
│  - consent_logs/{consentId} — KVKK açık rıza + aydınlatma metni kayıtları    │
│  - audit_logs/{logId} — kim, ne zaman, hangi veriye eriştiği                 │
│  - classes/{classId}/announcements, appointments, quick_cards                │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                        │ (Realtime & Push Notification)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VELİ UYGULAMASI                                │
│  - QR / Kod ile Öğrenci Ekleme (Birden fazla çocuk + birden fazla veli)      │
│  - Ders Öğretmenleri Kadrosu & Görüşme Talebi                               │
│  - Duyuru Akışı (Okundu Onayı) + Bildirim Özet Modu                         │
│  - Hızlı Durum Kartları (İlaç, Randevu Talebi, Bilgilendirme Notu)          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Okul Seçim & Eşleştirme Sistemi (Netleştirilmiş)

### 2.1 Kanonik Okul Kimliği

Her okulun `schoolId`'si **rastgele üretilmez**; MEB'in resmi **Kurum Kodu**'na dayanır (örn. `meb_734513`). Bu, aynı fiziksel okulun iki farklı kayda bölünmesini kökten engeller. Resmi listedeki her okul için:

```
schools/{schoolId}
  - meb_kurum_kodu: "734513"
  - il: "16", ilce: "Nilüfer", ad: "Cumhuriyet Ortaokulu"
  - kaynak: "resmi_liste" | "manuel_onayli"
  - status: "active" | "pending_review" | "merged_into:<schoolId>"
```

### 2.2 Lazy-Load İl Paketleri (değişmedi)

81 il hafif indeksi (`provinces.json`), il seçilince ilgili ilin sıkıştırılmış okul paketinin indirilmesi, 150ms debounced Türkçe-duyarlı arama — ilk taslaktaki yaklaşım korunuyor.

### 2.3 Manuel Okul Ekleme → Eşleştirme Kuyruğu (yeni)

Listede bulunamayan bir okul manuel eklendiğinde bu kayıt **doğrudan `schools` koleksiyonuna yazılmaz**. Önce `school_merge_queue`'ya düşer:

1. Öğretmen okul adı + il/ilçe + (varsa) adres girer.
2. Sistem, resmi listeyle **fuzzy match** (Levenshtein + il/ilçe filtresi) dener. Skor > 0.85 ise öğretmene "Bunu mu demek istediniz: X Okulu?" önerisi sunulur — çoğu durum burada otomatik çözülür.
3. Eşleşme bulunamazsa kayıt `pending_review` statüsüyle kuyruğa girer ve **geçici bir schoolId** ile öğretmen çalışmaya devam edebilir (offline-first ilkesi bozulmaz).
4. Haftalık/aylık bir arka plan işi (Cloud Function) kuyruktaki kayıtları gözden geçirir: aynı il/ilçede, adı %90+ benzer birden fazla manuel kayıt varsa otomatik birleştirir; belirsiz kalanlar için basit bir yönetim paneli üzerinden manuel onay yapılır.
5. Birleştirme olduğunda eski `schoolId`'ye bağlı tüm `classes`, `teachers`, `parent_links` kayıtları yeni `schoolId`'ye **kademeli olarak (batch) taşınır** ve eski kayıt `merged_into` işaretiyle arşivlenir — hiçbir veri kaybolmaz, sadece referans güncellenir.

### 2.4 Veli Tarafında Okul Seçimi Yok

Veli hiçbir zaman okul aramaz/seçmez. Eşleşme kodu zaten hangi `schoolId` + `classId`'ye ait olduğunu taşır; veli sadece kodu girer (bkz. Bölüm 3). Bu, ilk tasarımla tutarlı ve doğru bir karar — değiştirilmedi, sadece netleştirildi.

---

## 3. Veli-Öğretmen-Öğrenci Eşleşme Mekanizması (Güvenlik Sertleştirilmiş)

### 3.1 Kod Yapısı ve Yaşam Süresi

```
student_tokens/{tokenHash}
  - schoolId, classId, studentId
  - code: "SC-7B-8492"          // 4 haneli sınıf kodu + 4 haneli rastgele sayı, ~10.000 ihtimal DEĞİL
  - codeHash: sha256(code + salt)   // düz metin asla saklanmaz
  - createdAt, expiresAt: createdAt + 7 gün
  - status: "active" | "used" | "expired" | "revoked"
  - maxAttempts: 5
  - failedAttempts: 0
  - secondFactorHash: sha256(ogrenci_no veya dogum_yili)
```

Kurallar:
- **Tek kullanımlık değil, ama sınırlı kullanımlık**: aynı koda birden fazla veli (anne + baba) bağlanabilmeli (bkz. 3.3), bu yüzden "used" değil `linkedParentCount` sayacı tutulur, `maxLinkedParents: 2` (varsayılan) sınırı olur.
- **7 gün sonra otomatik expire** — öğretmen istediği an kodu `revoked` yapıp yenisini üretebilir.
- **Rate limiting**: aynı IP/cihazdan dakikada 5, saatte 20 kod deneme denemesi sonrası 15 dakikalık soğuma (Cloud Function + Firestore sayaç veya App Check).
- **5 yanlış ikinci-doğrulama denemesi** sonrası kod otomatik `revoked` olur ve öğretmene bildirim gider ("SC-7B-8492 kodunda şüpheli deneme tespit edildi").
- Kod alanı yalnızca insan tarafından okunur biçimde kısa tutulur (paylaşım kolaylığı), ama **gerçek doğrulama düz koddan değil, sunucu tarafı hash + ikinci faktör kombinasyonundan** geçer.

### 3.2 QR Kod Desteği (yeni, onboarding sürtünmesini azaltır)

Öğretmenin ürettiği kart hem metin kod hem QR içerir. QR, `code` + kısa bir imzayı (HMAC) encode eder; veli tarafında kamera ile taratma kod yazmaktan daha hızlı ve hatasız bir giriş sağlar. QR de aynı süre/deneme kurallarına tabidir.

### 3.3 Çoklu Veli / Velayet Senaryosu (yeni — ilk taslakta yoktu)

```
parent_links/{linkId}
  - parentUserId, studentId, schoolId, classId
  - relation: "anne" | "baba" | "vasi" | "diger"
  - linkedAt, linkedViaTokenHash
  - visibility: "full" | "restricted"   // ileride vasilik kısıtlaması için
```

- Bir öğrenciye **`maxLinkedParents` (varsayılan 2, okul yöneticisi artırabilir)** kadar veli bağlanabilir; her biri aynı kodla ayrı ayrı ikinci doğrulamadan geçer.
- İki veli de birbirinin telefon/e-posta bilgisini göremez — sadece kendi bağlantısını yönetir.
- Bir veli hesabını kaldırmak (örn. velayet değişikliği) **yalnızca öğretmen/okul yöneticisi** tarafından yapılabilir, veli kendi kendine başka bir veliyi silemez. Bu işlem `audit_logs`'a yazılır (bkz. Bölüm 5).
- Vasilik/velayet ihtilafı durumları için uygulama bir hakem rolü üstlenmez; sistemde sadece "kim ekledi, ne zaman eklendi, kim kaldırdı" şeffaf şekilde kayıt altında tutulur — hukuki ihtilaf okul idaresine yönlendirilir.

### 3.4 Akış Özeti

1. Öğretmen → Veli Bağlantı Kartı oluşturur (kod + QR, 7 gün geçerli).
2. Veli → "Veli Girişi" → kod/QR → ikinci doğrulama (öğrenci no veya doğum yılı, sunucu tarafında hash karşılaştırması, düz metin server'a gitmez ideal olarak client-side hash).
3. Başarılı → `parent_links` kaydı oluşur, `student_tokens.linkedParentCount += 1`.
4. `linkedParentCount == maxLinkedParents` olduğunda kod otomatik `used`'a döner (yeni veli eklenemez, öğretmen isterse limiti artırır).

---

## 4. Veli Modülü Ana Özellikleri (bildirim yorgunluğu eklendi)

Bölüm A (Ders Öğretmenleri Kadrosu), B (Hızlı Durum Kartları), C (Duyuru Panosu) ilk taslaktaki gibi korunuyor. Eklenen tek katman:

### D. Bildirim Önceliklendirme & Özet Modu (yeni)

- Bildirimler iki kategoriye ayrılır: **Acil** (sağlık/ilaç bildirimi, aynı gün görüşme talebi — anında push) ve **Rutin** (genel duyuru, ödev hatırlatması — varsayılan olarak günlük özet halinde, veli isterse anlık bildirime çevirebilir).
- Ayarlar ekranında veli "Anlık Bildir / Günde 1 Özet / Haftalık Özet" seçeneklerinden birini seçer.
- Push izni reddedilirse in-app bildirim kutusu (inbox) fallback olarak devreye girer — hiçbir bildirim tamamen kaybolmaz, sadece push yerine uygulama içi rozet ile görünür.

---

## 5. Yaşam Döngüsü Senaryoları (yeni bölüm)

İlk taslakta hiç ele alınmamış, ama üretimde en çok soruna yol açan kısım budur:

| Senaryo | Kural |
|---|---|
| **Yıl sonu / sınıf geçişi** | Öğrenci bir üst sınıfa geçtiğinde eski `classId` bağlantısı `archived` olur, yeni sınıf ataması yapılınca öğretmen yeni bir eşleşme kodu üretmek **zorunda değildir** — mevcut `parent_links` `studentId` üzerinden korunur, sadece `classId` ve o sınıfa giren yeni öğretmen listesi güncellenir. Veli tekrar kod girmez. |
| **Mezuniyet** | Öğrenci son sınıftan mezun olduğunda `parent_links.status = "graduated"` olur; veri KVKK saklama süresi kadar (öneri: 1 akademik yıl) `read-only` erişimde tutulup sonra anonimleştirilir/silinir. |
| **Öğretmen okuldan ayrılması** | Öğretmenin `teacherId` kaydı `inactive` olur; geçmiş duyuru/randevu kayıtları **silinmez** (veli tarafında geçmişe dönük görünürlük KVKK'ya aykırı değil, çünkü veli zaten kendi çocuğuna ait geçmiş yazışmaları görme hakkına sahip), ama yeni randevu/duyuru oluşturamaz. |
| **Öğrenci nakli (başka okula)** | Eski okuldaki `parent_links` `transferred` statüsüne düşer ve **cascade olarak** o okula özel randevu/duyuru erişimi kapanır; yeni okulda öğretmen yeni bir eşleşme kodu üretir (çünkü yeni okulun `schoolId`'si farklıdır, KVKK açısından da okullar arası veri taşınmaması doğrudur). |
| **Öğrenci kaydı silindiği** | İlk taslaktaki kural korunuyor: cascade delete — tüm `student_tokens`, `parent_links`, `appointments`, `quick_cards` kalıcı silinir. Bu işlem `audit_logs`'a "kim sildi, ne zaman" olarak yazılır. |

---

## 6. KVKK / GDPR Uyumluluk Akışı (somutlaştırıldı)

### 6.1 Açık Rıza & Aydınlatma Metni

Veli ilk kayıt ekranında (kod girmeden önce) bir **Aydınlatma Metni** onay ekranı görür. Onay şu şekilde kaydedilir:

```
consent_logs/{consentId}
  - userId, consentVersion: "v1.2"
  - consentedAt, ipHash, deviceLocale
  - scope: ["veli_uygulamasi_kvkk_aydinlatma", "bildirim_izni"]
```

Metin sürümü değiştiğinde (`consentVersion` artınca) kullanıcı bir sonraki girişte yeniden onay ekranı görür. Bu konudaki metnin hukuki içeriğini bir hukuk danışmanına onaylatmanızı öneririm — burada sadece teknik akış tanımlanıyor.

### 6.2 Audit Log (hesap verebilirlik)

```
audit_logs/{logId}
  - actorId, actorRole: "teacher" | "parent" | "admin"
  - action: "parent_link_created" | "parent_link_removed" | "token_generated" | "student_deleted" | ...
  - targetId, schoolId
  - timestamp
```

KVKK madde 12 kapsamında "hangi veriye kim ne zaman eriştiği" sorusuna cevap verebilmek için zorunlu; ayrıca kötüye kullanım şüphesinde (örn. 3.1'deki şüpheli kod denemesi) geriye dönük inceleme imkânı sağlar.

### 6.3 Veri Saklama & İhlal Bildirimi

- Mezuniyet/ayrılık sonrası veri saklama süresi net tanımlanmalı (öneri: 1 yıl, sonrasında anonimleştirme).
- Olası bir veri ihlalinde KVKK'nın öngördüğü bildirim sürecine uyum için `audit_logs` + `consent_logs` birlikte "hangi veli/öğrenci verisi etkilendi" sorgusuna hızlı cevap verecek şekilde indekslenmeli.
- Firebase/Supabase gibi üçüncü taraf altyapı sağlayıcılarıyla **veri işleyen sözleşmesi (DPA)** imzalanmış olmalı; bu genelde sağlayıcının standart sözleşmesine taraf olmakla çözülür ama teyit edilmeli.

### 6.4 Mağaza Uyumluluğu

Çocuklara ait veri işlendiği için Google Play ve App Store'un "families/children data" politikaları ek beyan gerektirebilir. Bu politikalar zaman içinde değişebildiği için başvuru öncesi güncel metinleri ayrıca kontrol etmenizi öneririm — bu bir hukuki tavsiye değildir.

---

## 7. Rol Yönetimi (RBAC) — yeni

İlk taslakta sadece "Öğretmen / Veli" ayrımı vardı. Gerçek okul ortamında üçüncü bir rol kaçınılmaz:

| Rol | Yetkiler |
|---|---|
| **Öğretmen** | Kendi sınıfı/dersi için duyuru, randevu saatleri, veli bağlantı kodu üretme |
| **Okul Yöneticisi (Müdür/Müdür Yrd.)** | Okul genelinde duyuru, `maxLinkedParents` limiti ayarlama, `school_merge_queue` onayı, şüpheli kod denemesi loglarını görme |
| **Veli** | Sadece kendi çocuğuna ait veri, duyuru okuma/onaylama, randevu talebi |

Okul yöneticisi rolü Faz 5'ten sonraki bir Faz 6 olarak planlanabilir (bkz. Bölüm 9) — ilk sürümde zorunlu değil ama veri modeli (`role` alanı `users` koleksiyonunda) baştan bu genişlemeye izin verecek şekilde tasarlanmalı.

---

## 8. Veri Şeması ve Ölçeklenebilirlik

### 8.1 Firestore Koleksiyon Özeti

```
/schools/{schoolId}
/schools/{schoolId}/teachers/{teacherId}
/schools/{schoolId}/classes/{classId}
/classes/{classId}/announcements/{announcementId}
/classes/{classId}/appointments/{appointmentId}
/classes/{classId}/quick_cards/{cardId}
/student_tokens/{tokenHash}
/parent_links/{linkId}
/consent_logs/{consentId}
/audit_logs/{logId}
/school_merge_queue/{requestId}
```

### 8.2 Randevu Çakışma Kontrolü (yeni)

İki velinin aynı boş saat dilimini aynı anda seçmesi ihtimaline karşı `appointments` yazma işlemi bir **Firestore transaction** içinde yapılır: slot `status: "available"` değilse yazma reddedilir ve veliye "Bu saat az önce doldu, lütfen başka bir saat seçin" mesajı gösterilir (dual error handling kuralına uygun nazik Türkçe mesaj).

### 8.3 Kota / Maliyet Eşiği

- Spark (ücretsiz) plan okunacak/yazılacak doküman sayısına göre sınırlıdır. Öneri: okul öğrenci sayısı **500'ü** veya günlük bildirim hacmi **10.000 read/write'ı** geçtiğinde Blaze (kullandıkça öde) planına otomatik geçiş uyarısı tetiklensin.
- Duyuru "okundu" tikleri her veli için ayrı doküman yerine `announcement` dokümanı içinde bir `readBy: {parentId: timestamp}` map alanında tutularak read/write sayısı azaltılabilir (n doküman yerine 1 doküman güncellemesi).

---

## 9. Güncellenmiş Geliştirme Fazları

| Faz | Kapsam | Detaylar |
|---|---|---|
| **Faz 1** | Okul Seçim & Eşleştirme Altyapısı | 81 İl/Okul veri seti + **MEB kurum kodu ile kanonik schoolId**, manuel ekleme → **eşleştirme kuyruğu & fuzzy-match birleştirme** |
| **Faz 2** | Veli Referans Kodu & Güvenlik | Token motoru + **süre/deneme limiti/rate limiting**, **QR kod desteği**, SQLite + Cloud veri şeması |
| **Faz 3** | Veli Arayüzü & Rol Yönetimi | Giriş ekranı Öğretmen/Veli ayrımı, Veli Dashboard, **çoklu veli/velayet desteği (`parent_links`)** |
| **Faz 4** | İletişim & Duyuru Modülü | Hızlı bilgi kartları, okundu onaylı duyurular, **bildirim önceliklendirme & özet modu** |
| **Faz 5** | Ders Öğretmenleri Kadrosu | Sınıf bazlı branş öğretmeni eşleşmesi, **transaction tabanlı randevu çakışma kontrolü** |
| **Faz 6 (yeni)** | KVKK & Yaşam Döngüsü | Açık rıza akışı, `audit_logs`, **yıl sonu/mezuniyet/nakil senaryoları**, veri saklama politikası |
| **Faz 7 (yeni, opsiyonel)** | Okul Yöneticisi Rolü | RBAC genişlemesi, `school_merge_queue` onay paneli, okul geneli duyuru yetkisi |

---

## 10. Değişmeyen Temel Kurallar (ilk taslaktan korunan)

Sıfır yoklama prensibi, çift taraflı gizlilik (veli↔veli, telefon numarası gizliliği), sıfır taşma/responsive standardı, çift tema uyumu, %100 offline-first öğretmen deneyimi ve Clean Architecture katman ayrımı ilk taslakta tanımlandığı gibi geçerliliğini koruyor — bu revizyon bunlara dokunmadan üzerine inşa edildi.
