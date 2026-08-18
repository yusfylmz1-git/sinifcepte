# 🟣 Claude İlerleme Notları

> **Bu dosya yalnızca Claude (Anthropic) tarafından tutulur.**
> Gemini/Antigravity → `gemini_ilerleme_notlari.md`
> Grok / diğer AI → `docs/04-SESSION_LOG.md` ve `yeni_plan.md`
> **Kural:** Diğer AI'ların notlarına dokunulmaz. Claude her oturum sonunda SADECE bu dosyayı günceller.

---

## 📅 17 Ağustos 2026 — Oturum 1: Sıfırdan Proje Analizi

Bu oturumda kod yazılmadı. Projenin gerçek (kod üzerinden doğrulanmış) durumu çıkarıldı.

---

## 🧭 1. PROJE KİMLİK KARTI

| Alan | Değer |
| :--- | :--- |
| **Proje** | SınıfCepte — Öğretmen + Veli dijital eğitim köprüsü |
| **Framework** | Flutter (Dart SDK `^3.10.7`) |
| **State** | `flutter_riverpod ^2.6.1` |
| **Yerel DB** | `sqflite` + `sqflite_common_ffi` (masaüstü) — **şema sürümü: 11** |
| **Bulut** | Firebase (proje id: `sinifcepte`) — *kısmen bağlı, aşağıya bakınız* |
| **Tasarım** | UI-UX-MAX / Glassmorphism, Google Fonts `Outfit`, Dark+Light |
| **Dil** | Türkçe (`tr_TR` locale, kod içi Türkçe metod adları yaygın) |
| **Kod hacmi** | `lib/` altında **150 Dart dosyası** |
| **Git** | Tek commit (`775bba7`), branch `main`. Aşağıdaki her şey **commit edilmemiş** durumda. |

### ⛔ Değişmez Proje Kuralları (`.agents/AGENTS.md`)
1. **YOKLAMA SİSTEMİ YOKTUR.** Devamsızlık/yoklama özelliği asla önerilmez, eklenmez.
   *(Not: `lib/data/models/attendance_*` ve `lib/features/attendance/` klasör adları eski isimlendirmedir; içerik "Ders İçi Katılım & Davranış"tır.)*
2. **İkili hata yönetimi:** `catch (e, stackTrace)` → geliştiriciye `debugPrint`, kullanıcıya sade SnackBar. Stack trace asla UI'da gösterilmez.
3. **Sıfır taşma (Madde 8):** Row/Grid içinde serbest metin yok — `Expanded` / `Flexible` / `FittedBox` / `Wrap` + `maxLines` + `ellipsis`. 320–430px arası test edilir.
4. **Çift tema doğrulaması:** her UI değişikliği hem Dark hem Light modda kontrast açısından kontrol edilir.
5. **Offline-First & sıfır sunucu maliyeti** (Firebase Spark/free tier'ı aşmamak esas).
6. **KVKK / Cascade Delete:** öğrenci veya sınıf silindiğinde bağlı tüm veri iz bırakmadan silinir.
7. **Kullanıcı "Başla / Yap" demeden koda geçilmez.**

---

## ✅ 2. DOĞRULANMIŞ SAĞLIK DURUMU (bu oturumda bizzat çalıştırıldı)

```
flutter analyze  →  No issues found!  (0 hata / 0 uyarı, 47.4s)
flutter test     →  All tests passed! (48/48 test)
```

Test dosyaları (9 adet):
`analytics_exam_analysis_test` · `classroom_participation_test` · `curriculum_test` ·
`exam_operations_test` · `parent_extended_features_test` · `parent_lifecycle_and_kvkk_test` ·
`parent_portal_test` · `parent_token_test` · `schools/school_directory_test` · `widget_test`

Kodda gerçek `TODO` / `FIXME` borcu **yok**. Tarama sonucu çıkan "Henüz…" ifadelerinin tamamı normal boş-durum (empty state) UI metinleridir.

---

## 🗂️ 3. MİMARİ HARİTA (gerçek klasör yapısı)

```
lib/
├── main.dart                  → Firebase bootstrap + intl tr_TR + bildirim + FFI, home: WelcomeScreen
├── app_router.dart            → İsimli rota sabitleri (home/attendance/analytics/examOperations)
├── firebase_options.dart      → FlutterFire üretimi (android/ios/web/windows)
├── core/
│   ├── config/                → app_config
│   ├── database/              → database_helper (1657 satır, v11) + legacy_crud_methods
│   ├── firebase/              → firebase_bootstrap (çökmeye dayanıklı, hatada yerel devam)
│   ├── services/              → notification_service, whatsapp_share_service
│   ├── storage/               → prefs_keys (tek kaynak anahtarlar) + prefs_migrator
│   ├── theme/                 → app_colors, app_theme, app_design_tokens, theme_provider
│   ├── utils/                 → date_formatter, input_sanitizer
│   └── widgets/               → responsive_bottom_sheet
├── data/                      → models + repositories (class/student/attendance)
├── features/                  → 16 modül (aşağıdaki tabloya bakınız)
└── shared/widgets/            → glass_card, app_drawer, custom_app_bar, custom_bottom_nav_bar
```

### Feature modülleri ve durumları

| Modül | Durum | Not |
| :--- | :--- | :--- |
| `auth` | ✅ | WelcomeScreen — Öğretmen (Google) / Veli rol seçimi |
| `auth_profile` | ✅ | TeacherProfile, `SchoolBindGate`, Google sign-in servisi |
| `schools` | ✅ | 81 il shard sistemi, fuzzy arama (Normalized Levenshtein) |
| `classes` | ✅ | Sınıf/öğrenci CRUD, Excel+PDF öğrenci içe aktarma, oturma planı, veli iletişim listesi |
| `outcomes` | ✅ | 39+1 haftalık Maarif kazanımları, öğretmen sticky-note'ları, tatil kartı |
| `schedule` | ✅ | Haftalık ders programı + PDF çıktısı |
| `attendance` | ✅ | **Ders İçi Katılım** (yoklama değil): 3 yıldız, ödev döngüsü, PDF, WhatsApp |
| `exam_operations` | ✅ | Quiz/sözlü çizelgesi, MEB 10 kriterli rubric, LGS/YKS/KPSS takvimi |
| `analytics` | ✅ | Sınav analizi editörü/detayı, akıllı karne yorumu üreteci, PDF |
| `academic_calendar` | ✅ | MEB tatil/dönem olayları, `todayCalendarEventProvider` |
| `documents` | ✅ | Belge şablonları merkezi |
| `parent_portal` | 🟡 | Model/repo/test tam — **depolama SQLite değil SharedPreferences** (bkz. §4) |
| `dashboard` | ✅ | Bento grid, tatil/hafta sonu duyarlı günün akışı |
| `navigation` | ✅ | 4 sekme: Sınıflar, Kazanımlar, Program, Profil |
| `profile` / `settings` | ✅ | Tema modu, ayarlar |
| `sync` | 🔴 | **Simülasyon** — gerçek ağ çağrısı yok (bkz. §4) |

### SQLite tabloları (v11, 26 tablo)
`classes` `students` `dersler` `sinavlar` `sinav_notlari` `performans`
`participation_sessions` `participation_records` `seating_plans`
`curriculum_outcomes` `kazanimlar` `outcome_notes` `academic_calendar_events`
`quiz_cizelgeleri` `quiz_kolonlari` `quiz_notlari`
`proje_kriterleri` `proje_takip` `proje_puanlari`
`degerlendirme_kriterleri` `degerlendirme_detaylari` `ogrenci_degerlendirmeleri`
`genel_sinavlar` `favori_sinavlar` `kisisel_sinavlar`
`sistem_ayarlari` `sync_metadata`

---

## 🚨 4. KRİTİK TESPİTLER (kod okunarak bulundu, dokümanlarda yazmıyor)

Bunlar **hata değil**, henüz tamamlanmamış bağlantılardır. Sonraki oturumda buradan devam edilir.

### 🔴 K1 — `cloud_firestore` bağımlılığı hiç kullanılmıyor
`pubspec.yaml` içinde `cloud_firestore: ^5.6.12` var, ancak `lib/` altında **tek bir `import 'package:cloud_firestore/...'` satırı yok.**
`lib/` içinde gerçekten Firebase kullanan yalnızca 3 dosya:
- [firebase_bootstrap.dart](lib/core/firebase/firebase_bootstrap.dart) → `firebase_core`
- [welcome_screen.dart](lib/features/auth/screens/welcome_screen.dart) → `firebase_auth`
- [teacher_auth_service.dart](lib/features/auth_profile/data/services/teacher_auth_service.dart) → `firebase_auth` + `google_sign_in`

**Sonuç:** `firestore.rules` (kapsamlı, admin/veli/öğretmen rolleriyle yazılmış) **hiçbir istemci kodu tarafından kullanılmıyor.** Yani "Hibrit bulut mimarisi" şu an sadece kimlik doğrulama (Auth) seviyesinde. Veri katmanı %100 yerel.

### 🔴 K2 — `SyncService` gerçek senkronizasyon yapmıyor
[sync_service.dart:39-45](lib/features/sync/services/sync_service.dart#L39-L45) içinde bulut manifesti **kod içinde sabit üretiliyor**:
```dart
// Şimdilik varsayılan manifest simülasyonu
final cloudManifest = SyncManifestModel(academicCalendarVersion: 1, ...);
```
Ağ çağrısı yok. Yerel sürüm de 1 olduğu için sonuç her zaman "Verileriniz zaten güncel". Admin portalının "+1 Artır (Yayınla)" butonu bu yüzden mobil tarafa **hiçbir etki etmiyor**.

### 🟡 K3 — Veli Portalı SQLite'ta değil, SharedPreferences'ta
`parent_tokens`, `parent_links`, `announcements`, `appointments`, `audit_logs`, `consent_logs`, `content_reports` — hepsi JSON string olarak `SharedPreferences`'ta tutuluyor ([prefs_keys.dart](lib/core/storage/prefs_keys.dart)).
- ✅ Artısı: `PrefsMigrator` ile legacy anahtar birleştirme düzgün yapılmış, testleri geçiyor.
- ⚠️ Riski: İlişkisel sorgu yok, cascade delete elle yürütülüyor, veri büyüdükçe her okuma tüm listeyi JSON parse ediyor. KVKK "unutulma hakkı" garantisi SQLite `FOREIGN KEY ... ON DELETE CASCADE` yerine servis koduna bağımlı.

### 🟡 K4 — `app_router.dart` fiilen kullanılmıyor
`main.dart` doğrudan `home: const WelcomeScreen()` veriyor; `onGenerateRoute: AppRouter.generateRoute` **bağlanmamış**. Rota sabitleri tanımlı ama gezinme her yerde `Navigator.push(MaterialPageRoute(...))` ile yapılıyor.

### 🟡 K5 — Her şey commit edilmemiş
Git'te tek bir başlangıç commit'i var. 150 Dart dosyası, `admin_portal/`, `assets/` (54.968 okul kaydı), `docs/`, `test/` hepsi untracked/modified. **Tek bir kaza tüm işi silebilir.**

### 🔵 K6 — Küçük notlar
- [custom_app_bar.dart:222](lib/shared/widgets/custom_app_bar.dart#L222) → "Mesaj Kutusu (Yakında)" placeholder butonu.
- `docs/02-ARCHITECTURE.md` içindeki ER şeması hâlâ `ATTENDANCE_SESSIONS`/`ATTENDANCE_RECORDS` "yoklaması alınır" diyor — **Kural 1 ile çelişiyor**, güncellenmeli.
- Kök dizinde 94 KB'lık `firebase-debug.log` var; `.gitignore`'a eklenmeli.

---

## 📚 5. VERİ VARLIKLARI

| Varlık | Detay |
| :--- | :--- |
| `assets/data/schools/` | 81 il shard'ı (`tr_01.json`…`tr_81.json`) + manifest. **54.968 okul**, 22 eşleşmeyen satır. PII yok. |
| `assets/data/official_maarif_kazanimlar.json` | 59 ders, 2.301 resmî kazanım satırı |
| `assets/data/official_exams.json` | LGS, YKS TYT/AYT, MEB Ortak Sınavlar, KPSS |
| `assets/data/provinces_districts.json` | 81 il + ilçe indeksi |
| `admin_portal/` | Bağımsız vanilla JS web paneli (takvim, kazanım, sınav, manifest yöneticisi) |
| `scripts/schools/build_shards.py` | Okul shard'larını yeniden üretme aracı |

---

## 🎯 6. SIRADAKİ ADIM ÖNERİLERİ (öncelik sırasıyla)

Kullanıcı onayı beklemektedir — hiçbiri başlatılmadı.

| # | İş | Neden | Efor |
| :-- | :--- | :--- | :--- |
| **1** | **Git commit / branch** | K5 — 150 dosyalık iş tek commit'te korumasız duruyor | 5 dk |
| **2** | **SyncService'i gerçek Firestore'a bağlamak** | K1 + K2 — admin portal ile mobil arasındaki kopukluğu kapatır, `firestore.rules`'u anlamlı kılar | Orta |
| **3** | **Veli Portalını SQLite'a taşımak** | K3 — KVKK cascade delete'i şema seviyesinde garanti eder | Yüksek |
| **4** | **`app_router`'ı `main.dart`'a bağlamak** | K4 — deep-link ve veli/öğretmen guard'ı için ön koşul | Düşük |
| **5** | **`docs/02-ARCHITECTURE.md` yoklama şemasını temizlemek** | K6 — proje anayasasının 1. maddesiyle çelişki | 10 dk |

---

## 📝 OTURUM GEÇMİŞİ

### Oturum 1 — 17 Ağustos 2026
- **Yapılan:** Salt-okunur tam proje analizi. Kod değişikliği yapılmadı.
- **Doğrulandı:** `flutter analyze` (0 issue) ve `flutter test` (48/48) bizzat çalıştırıldı.
- **Çıktı:** Bu dosya oluşturuldu; K1–K6 kritik tespitleri kayda geçirildi.

### Oturum 2 — 17 Ağustos 2026 (aynı gün, devam)

#### A. Git tabanı alındı ✅
- `feat/full-project-baseline` dalı açıldı, **343 dosya** tek commit'te sürüm kontrolüne alındı (`7896bb5`).
- Sızmış kimlik bilgisi yok; 283 MB'lık `windows/flutter/ephemeral/` doğru şekilde dışarıda. Repo 4.3 MB.
- **K5 kapandı.**

#### B. Bulut mimarisi planlandı (kod yazılmadan)
İki belge üretildi:
- **Bulut Köprüsü planı:** https://claude.ai/code/artifact/f2d2dde5-7ada-4047-92c7-3e2a27af1896
- **Ölçek ve Maliyet planı:** https://claude.ai/code/artifact/c021b533-2a1a-4114-85e4-ee636e549f83

**En kritik tespit:** Veli portalı `SharedPreferences`'ta olduğu için öğretmenin ürettiği kod velinin telefonunda **yok**. Testlerin geçmesi bunu yakalamıyor (tek hafızada iki rol simüle ediliyor). Kod doğru, **taşıyıcı yok**. Bu yüzden Firestore bir iyileştirme değil, **ön koşul**.

**Maliyet düzeltmesi:** Oturum 1'deki "15-20 okul" hesabı tek okul içindi, 10M kullanıcı hedefini yansıtmıyordu. Gerçek: ham fatura ~$2.400/ay; yedi şema kararıyla **~$260/ay (%89 azalma)**. Spark'ta okul sayısı ~20 → **~190**.

#### C. Faz 1 tamamlandı ✅ (`b3d48bc`)
- `ParentAuthService` — veli Google girişi (yalnızca Google kararı uygulandı).
- `SchoolAdminStatus` + `AuthClaimsService` — yetki artık **custom claim**'den okunuyor, yerelden değil.
- `SchoolAdminRequestModel` — yönetici başvuru → süper admin onayı akışının modeli.
- `AdGate` + `AdSlotWidget` — reklam altyapısı kuruldu, **kapalı**. SDK bilinçli olarak eklenmedi (~2 MB yük, kapalıyken boşa gider); çağrı yüzeyi sabit, Faz 7'de tek dosya doldurulacak.
- `test/auth_roles_and_ads_test.dart` (15 test) eklendi.

**Bu fazda bulunan ve düzeltilen iki gerçek hata:**
1. `welcome_screen.dart`: Firebase oturumu olan **herkes öğretmen sayılıyordu** — veli Google ile girince öğretmen paneline düşerdi.
2. `user_role_provider.dart`: Yapıcıdaki `loadRole()`, sonradan yapılan rol seçimini **eziyordu**. Uygulama açılır açılmaz rol seçen kullanıcının seçimi kayboluyordu. (Yazdığım testin başarısız olmasıyla yakalandı.)

**Doğrulama:** `flutter analyze` 0 issue · `flutter test` **63/63** başarılı.

#### D. Faz 2 tamamlandı ✅ (`8e6922c`) — **zincirin kopuk halkası kapandı**

**Yeni dosyalar:**
- `lib/core/cloud/cloud_ids.dart` — `cls_{uid}_{id}` / `stu_{uid}_{id}` şeması. Sahiplik kimlik deseninden okunur, kural motoru `get()` yapmaz (maliyet kararı).
- `lib/core/cloud/firestore_client.dart` — kalıcı önbellek açık, **snapshot listener yok**, `WriteBatch` desteği.
- `.../repositories/cloud_token_repository.dart` — doküman kimliği **`SHA-256(kod)`'un kendisi**. Düz kod buluta asla yazılmaz; doğrulama sorgu değil tek `get()`.
- `.../services/parent_link_bridge.dart` — doğrulama sırası ucuzdan pahalıya; hatalı girişler tek bulut okuması bile harcamadan elenir.

**Uygulanan maliyet kararları:** #6 (bağlantı sonrası token silme), #7 (toplu yazma).

**Güvenlik düzeltmesi:** `parent_token_repository.dart`'ta kod ve okul numarası doğrulamasında **düz metin yedek karşılaştırmaları** vardı (satır 302-307 ve 325-326). Bulutta düz kod saklanmadığı için bu yollar iki depoyu farklı güvenlik seviyesinde bırakıyordu — kaldırıldı. Ayrıca veli telefonu artık buluta gönderilmiyor.

**`firestore.rules` düzeltildi:** `parent_links`, `parent_class_access` ve `class_rooms` kurallarında **`allow write: if false`** vardı — yani istemci hiç yazamıyordu. Kurallar Cloud Functions ile yazımı varsayıyordu ama Spark planında Functions kısıtlı. Güvenli koşullarla istemci yazımına açıldı. Ayrıca `parent_tokens`, `school_admin_requests`, `content_reports` kuralları eklendi ve **yetki yükseltme koruması** kondu (öğretmen kendi başvurusunu onaylayamaz).

**Doğrulama:** `flutter analyze` 0 issue · `flutter test` **82/82** başarılı.

---

#### E. Kural testleri çalıştırıldı ✅ (`6cb0b20`) — **33/33 geçiyor**

Faz 2'de yazılıp çalıştırılamayan güvenlik kuralı testleri artık **gerçek kural motoruna karşı** doğrulandı.

**Engel:** Emülatör JDK 21+ istiyor, makinede Java 8 kurulu. Üstelik Oracle'ın `java8path` kısayolu `PATH`'in başına sabitlenmiş, bu yüzden `JAVA_HOME` ayarlamak tek başına yetmiyor. (Android Studio'nun `jbr`'si de eksik kurulmuş — `lib/jvm.cfg` yok.)

**Çözüm:** `test_rules/run-tests.ps1` — JDK 21'i otomatik bulur, Java 8 girdilerini `PATH`'ten geçici ayıklar, **sisteme dokunmaz**. Tek komut: `.\run-tests.ps1`

**Doğrulanan kritik senaryolar:**
- Veli başka velinin çocuğunun bağını **okuyamıyor**
- Veli başkası adına bağ **kuramıyor**, kendi kimliğiyle başka uid **yazamıyor**
- Öğretmen kendi yönetici başvurusunu **onaylayamıyor** (yetki yükseltme koruması)
- Başka öğretmen sınıf odasını **değiştiremiyor**, kod **yazamıyor**
- Veli şikâyet kaydını **okuyamıyor ve silemiyor** (denetim izi bütünlüğü)
- Manifesti **hiçbir istemci yazamıyor** (süper admin dahil)

> ⚠️ Kullanılan JDK geçici klasörde (`scratchpad/jdk`) ve silinebilir. Kalıcı çözüm için [Temurin JDK 21](https://adoptium.net/temurin/releases/?version=21) kurulmalı ("Set JAVA_HOME" işaretli). Betik kalıcı kurulumu da otomatik bulur.

**Düzeltme:** Önceki notta "34 test" yazmıştım; gerçek sayı **33**.

---

#### F. Faz 3 — 1. yarı tamamlandı ✅ (`e5cfa7c`)

**Mesajlaşma yetki ekseni çözüldü.** Kararınız gereği duyuru ile mesajlaşma ayrıldı:
- Duyuru → **yalnızca sınıf öğretmeni** (mevcut `cls_{uid}_{id}` sahipliği yeterli)
- Mesajlaşma → yeni **`class_rooms/{id}/staff/{teacherUid}`** kadrosu + `isClassStaff()` kural yardımcısı. Veli, çocuğunun dersine giren branş öğretmenleriyle yazışabiliyor; kadroda olmayan öğretmen giremiyor.

**Yeni dosyalar:**
- `lib/core/cloud/delta_sync_tracker.dart` — 5 dk saat kayması payı, 30 günlük bayatlama sınırı, hata durumunda tam çekime düşer.
- `.../repositories/cloud_communication_repository.dart` — duyuru, mesaj, kadro erişimi.

**Uygulanan maliyet kararları:** #1 (okundu alt dokümana), #2 (delta sorgu), #4 (dinleyici yok).

**Kural sıkılaştırmaları:** Mesaj gönderildikten sonra değiştirilemiyor; veli `'teacher'` rolüyle mesaj gönderemiyor (kimlik taklidi koruması); branş öğretmeni kendini kadroya ekleyemiyor.

**Doğrulama:** `flutter analyze` 0 issue · `flutter test` **90/90** · kural testleri **51/51** (33'ten yükseldi).

---

#### G. Faz 3 — 2. yarı tamamlandı ✅ (`164c68c`)

**Duyurular artık gerçekten iki cihaz arasında akıyor.**

**Bulunan eksik halka:** `ParentLinkModel` bulut kimliklerini taşımıyordu — veli ekranı hangi bulut sınıfından okuyacağını bilemiyordu. `classCloudId`, `studentCloudId`, `teacherUid` eklendi; Faz 2 öncesi kayıtlarla geriye uyumlu (`hasCloudBinding` false döner).

**Veli tarafı:** Duyuru listesi buluta bağlandı (delta senkron). Okundu işaretleme kendi `reads/{uid}` dokümanını yazıyor. Bağ kurulunca yerele önbellekleniyor — ağ yokken de çocuk listesi görünüyor. `myConnectedChildrenProvider` artık Firebase UID kullanıyor, yani **veli cihaz değiştirse de çocuklarına ulaşıyor**.

**Öğretmen tarafı:** Duyuru yayımlama buluta yazıyor; başarısız olursa **açıkça uyarıyor** (yerelde görünüp velilere ulaşmama durumu sessiz geçilmiyor). `ensureClassRoom` eklendi.

**Doğrulama:** `flutter analyze` 0 issue · Dart **97/97** · kural testleri **51/51**.

---

#### H. Kadro yönetimi tamamlandı ✅ (`d0691d7`)

Kararınızın ("veli dersine giren diğer öğretmenlerle de etkileşim kursun") uçtan uca karşılığı.

**Katılım kodu akışı:** Mesajlaşma yetkisi UID'ye bağlı, isme değil. Sınıf öğretmeni branş öğretmeninin UID'sini bilemeyeceği için iki aşama:
1. Sınıf öğretmeni `pending_{kod}` satırı açar → veli öğretmeni listede görür, mesajlaşma kapalı
2. Branş öğretmeni kodu girer → kayıt kendi UID'siyle yazılır, mesajlaşma açılır

**Yeni ekranlar:** `ClassStaffManagerModal` (kadro yönetimi), `StaffJoinModal` (kod girme), iletişim modaline **👥 Kadro** sekmesi.

> 🔴 **Kural testleri iki gerçek güvenlik açığı yakaladı.** İlk yazdığım kural `staffId == uid && teacherUid == uid` ile yetiniyordu — bu, **giriş yapmış herkesin (veli dahil) kendini kadroya ekleyip mesajlaşma yetkisi kazanmasına** izin veriyordu; katılım kodu hiç doğrulanmıyordu. Kural gerçek bir `pending_` davetinin varlığına bağlandı (`joinedVia` + `exists`). Bu, kural testlerinin neden şart olduğunun somut kanıtı: Dart testleri bunu asla yakalayamazdı.

**Doğrulama:** `flutter analyze` 0 issue · Dart **107/107** · kurallar **55/55**.

---

#### I. Sohbet ekranı tamamlandı ✅ (`fe1cdf9`)

**Veli ve öğretmen artık uygulama içinde birebir yazışabiliyor** — telefon numarası hiçbir yöne paylaşılmadan.

- `ParentTeacherChatModal` — tek bileşen iki taraftan da açılıyor; `asTeacher` bayrağı `authorRole`'ü belirliyor ve kural motoru doğruluyor.
- Canlı dinleyici yok: açılışta tek okuma, elle yenileme. Gönderim sonrası liste **yerel olarak** büyüyor — içeriğini bildiğimiz mesaj için sunucuya ikinci kez gidilmiyor.
- Veli tarafında öğretmen listesi artık **bulut kadrosundan** besleniyor; kadroya katılmamış öğretmenin mesaj butonu kapalı ve gerekçesi yazılı (sessiz hata yok).
- Öğretmen tarafında bağlı veli satırlarına mesaj butonu; profil ekranına **"Sınıf Kadrosuna Katıl"** kartı.

**Doğrulama:** `flutter analyze` 0 issue · Dart **115/115** · kurallar **55/55**.

---

#### J. Faz 3 TAMAMLANDI ✅ (`08450dc`) — randevu ve durum bildirimleri

- **Durum bildirimleri:** Veli gönderir (ilaç, erken çıkış, not), öğretmen ve kadrodaki branş öğretmeni görüp "görüldü" işaretler.
- **Randevular:** Veli talep eder, öğretmen onaylar/reddeder, veli iptal edebilir. Çakışma denetimi buluttan yapılıyor.

**Kural sıkılaştırmaları:** Veli bildirimi `acknowledged` durumuyla oluşturamıyor; gönderdiği bildirimin **içeriğini değiştiremiyor** (öğretmen "ilaç 12:30" diye okuduktan sonra metin değişirse sorumluluk belirsizleşir); randevuyu kendisi onaylayamıyor.

> 🔴 **Sessiz veri tutarsızlığı bulundu ve düzeltildi.** Öğretmen tarafındaki duyuru silme, randevu onay/red ve bildirim işaretleme butonları hâlâ **yerel depoya** yazıyordu. `flutter analyze` bunu yakalamıyordu çünkü kod geçerliydi — ama öğretmen duyuruyu sildiğinde **velilerde görünmeye devam ederdi**, randevu yanıtı veliye hiç ulaşmazdı. Bu tür hatalar ancak veri akışını uçtan uca takip ederek bulunuyor.

**Doğrulama:** `flutter analyze` 0 issue · Dart **125/125** · kurallar **68/68**.

---

#### K. Faz 4 TAMAMLANDI ✅ (`1ae199a`) — okul yöneticisi

Kurgunun son ana parçası. **Yönetici rolü opsiyonel kaldı** — yöneticisi olmayan okullarda her şey normal çalışıyor.

- `SchoolAdminRepository` — başvuru kimliği deterministik (`req_{uid}`): aynı kişi kuyruğu dolduramıyor, durum tek `get()` ile okunuyor.
- `SchoolAdminRequestView` — başvuru ekranı; yöneticiliğin opsiyonel olduğunu açıkça yazıyor.
- `SchoolAdminPanelView` — öğretmen onay listesi + şikâyet listesi.
- `scripts/admin/approve_school_admin.mjs` — `--list` / `--approve` / `--reject`. **Claim yazımı burada olur**; istemci kendine yönetici diyemez.

**K6 kapandı:** `isVerifiedBySchoolAdmin` alanı ilk analizde "var ama hiç kullanılmıyor" diye işaretlenmişti. Artık profilde **mavi doğrulama rozeti** — bir kapı değil, rozet.

> 🔴 **Kural boşluğu bulundu ve kapatıldı.** `content_reports` kuralı yalnızca `isAdmin()` (süper/moderatör) izni veriyordu — yani **okul yöneticisi şikâyetleri okuyamıyordu**, oysa kurgunuzda yöneticinin işi tam olarak bu. `isSchoolAdminOf()` eklendi ve yetki **kendi okuluyla sınırlandı**: bir okulun yöneticisi başka okulun şikâyetini göremiyor.

> 🔴 **İkinci sessiz hata:** Veli şikâyeti yalnızca `SharedPreferences`'a yazılıyordu ama arayüz **"okul idaresine iletildi"** diyordu. Artık buluta gidiyor; başarısız olursa kullanıcı doğru bilgilendiriliyor.

**Doğrulama:** `flutter analyze` 0 issue · Dart **139/139** · kurallar **78/78**.

---

#### L. Faz 5 TAMAMLANDI ✅ (`c53f63a`) — **K2 ve K4 kapandı**

İlk analizdeki en büyük iki teknik borç kapandı.

**K2 — `SyncService` bir simülasyondu.** Bulut manifestini kod içinde **sabit üretiyordu**; ağa hiç çıkmıyor, sonuç her zaman "verileriniz güncel" oluyordu. Admin portalınızın **"+1 Artır (Yayınla)" butonu bu yüzden mobil tarafı hiç etkilemiyordu.** Artık gerçek okuma yapıyor.

**Neden Firestore değil Remote Config:** Sürüm/bakım kontrolü her açılışta yapılır. Firestore'dan okunsaydı 10M kullanıcıda **aylık ~$180** maliyet oluşurdu — üstelik veri tek küçük dokümandı. **Remote Config ücretsizdir ve okuma kotası yoktur** (maliyet kararı #3 uygulandı).

**K4'ün kalanı** — "Okulum listede yok" önerileri yalnızca yerelde birikiyordu, artık `school_merge_queue`'ya gidiyor.

**Yeni bileşenler:**
- `RemoteManifestService` — 6 saatlik önbellek; ağ yoksa **güvenli varsayılana** düşer (bakım modu kapalı, hiçbir şey engellenmez).
- `scripts/admin/publish_remote_config.mjs` — panelden indirilen JSON'u yayınlar. `validateTemplate` ile hatalı şablonun uygulamayı bozması engellenir.
- Admin paneline "Remote Config JSON indir" işlevi.

**Ölü kod:** `SyncManifestModel` kaldırıldı (yerini `RemoteManifest` aldı).

**Doğrulama:** `flutter analyze` 0 issue · Dart **149/149** · kurallar **78/78**.

---

## 🎯 SIRADAKİ ADIM

**Faz 6 — Bütçe koruması.** Blaze'e geçildiğinde Firebase **varsayılan harcama tavanı koymaz**; tek bir kod hatası dört haneli faturaya yol açabilir.
- Google Cloud bütçe alarmı kurulum rehberi
- Kota aşımında yazmayı durduran koruma
- Maliyet izleme notları

Sonra: **Faz 7** reklam açılışı (AdMob SDK + kişiselleştirilmemiş reklam yapılandırması).

---

## 📤 MANİFEST YAYINLAMA (admin akışı)

```bash
# 1. Admin panelinde sürümü artır → "Remote Config JSON indir"
# 2. Yayınla
set GOOGLE_APPLICATION_CREDENTIALS=C:\secrets\sinifcepte-sa.json
node scripts/admin/publish_remote_config.mjs remote_config_params.json

# Mevcut değerleri görmek için
node scripts/admin/publish_remote_config.mjs --show
```
Mobil cihazlar en geç **6 saat** içinde alır; kullanıcı "senkronize et" derse **anında** çeker.

**Ertelenen:** Maliyet kararı **#5** (son 20 duyuruyu sınıf dokümanında toplama) — mevcut delta senkron zaten okumaların çoğunu sıfırlıyor; bu ek optimizasyon gerçek kullanım verisi görülmeden yapılmamalı.

---

## ✅ ÇALIŞAN UÇTAN UCA AKIŞ

Bugün itibarıyla iki ayrı cihazda şunlar çalışıyor:

1. Öğretmen Google ile girer → okul seçer (zorunlu)
2. Öğrenci için veli kodu üretir → kod **buluta** yazılır
3. Veli kendi telefonunda Google ile girer → kodu + okul numarasını girer
4. Bağ kurulur; veli çocuğunu görür (cihaz değiştirse de korunur)
5. Öğretmen duyuru yayımlar → **veli kendi telefonunda görür**, okundu işaretler
6. Öğretmen kadroya branş öğretmeni ekler → katılım kodu üretilir
7. Branş öğretmeni kodu girer → **velilerle yazışma yetkisi açılır**
8. Veli ↔ öğretmen birebir mesajlaşır
9. Veli durum bildirimi gönderir (ilaç/erken çıkış) → **öğretmen görür ve onaylar**
10. Veli randevu talep eder → **öğretmen onaylar/reddeder**, veli yanıtı görür
11. Öğretmen yöneticilik başvurusu yapar → süper admin betikle onaylar → **yönetici paneli açılır**
12. Veli şikâyet bildirir → **okul yöneticisi kendi okulunun şikâyetlerini görür**

---

## 🧪 TEST DURUMU ÖZETİ

| Takım | Sayı | Komut |
| :--- | :--: | :--- |
| Dart birim testleri | **149** | `flutter test` |
| Firestore kural testleri | **78** | `cd test_rules && .\run-tests.ps1` |
| Statik analiz | 0 issue | `flutter analyze` |

## 🔑 SÜPER ADMİN KURULUMU (bir kez yapılmalı)

Yönetici onaylarını verebilmek için:
```bash
# 1. Firebase Console > Project Settings > Service accounts > Generate new private key
set GOOGLE_APPLICATION_CREDENTIALS=C:\secrets\sinifcepte-sa.json

# 2. Bağımlılık
cd scripts/admin && npm i firebase-admin

# 3. Bekleyen başvuruları gör
node scripts/admin/approve_school_admin.mjs --list

# 4. Onayla
node scripts/admin/approve_school_admin.mjs --uid <ogretmenUid> --approve
```
Onay sonrası öğretmenin çıkış/giriş yapması veya panelde **"Yetkiyi yenile"** düğmesine basması gerekir: claim'ler ID token içinde taşınır ve token saatte bir yenilenir.

### Kesinleşen kararlar (tekrar sorulmayacak)
| Konu | Karar |
| :--- | :--- |
| Veli girişi | Yalnızca Google |
| Duyuru yetkisi | Yalnızca sınıf öğretmeni |
| Mesajlaşma yetkisi | Veli, dersine giren **tüm** öğretmenlerle konuşabilir (ayrı yetki ekseni) |
| Öğretmen doğrulaması | Rozet, kapı değil — onaysız da veli bağlanabilir |
| Reklam | Altyapı Faz 1'de kuruldu (kapalı), açılışı Faz 7 |

### Açık riskler
- `firestore.rules` hiç test edilmedi. Faz 2 ile birlikte emülatör tabanlı kural testi eklenmeli — yanlış kural sessizce veri sızdırır.
- Yerel `int studentId` → bulut `stu_{uid}_{yerelId}` eşlemesi Faz 2'de kurulacak; **geri dönüşü zor**, baştan doğru yapılmalı.
- Blaze'e geçilirse Firebase varsayılan harcama tavanı koymaz; bütçe alarmı Faz 6.
