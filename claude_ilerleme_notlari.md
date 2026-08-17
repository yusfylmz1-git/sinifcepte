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

---

## 🎯 SIRADAKİ ADIM

**Faz 2 — Token köprüsü.** Projenin kilidini açan faz: öğretmenin ürettiği kod bulut üzerinden başka bir telefonda çocuğu bağlayacak.

Uygulanacak maliyet kararları: token TTL + bağlantı sonrası silme (#6), toplu yazma (#7).
Güvenlik: buluta **yalnızca `codeHash`** yazılacak, düz kod asla.

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
