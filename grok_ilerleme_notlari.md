# Grok İlerleme Notları

Bu dosya, **SınıfCepte** projesinde **Grok** tarafından yapılan değişiklikleri tutar.
Claude → `claude_ilerleme_notlari.md` · Gemini → `gemini_ilerleme_notlari.md`
Diğer AI notlarına dokunulmaz.

---

## Grok güncelleme yaptı — 11 Eylül 2026

Oturum iki konuydu: (1) Google ile kayıt olan öğretmen internetsiz ikinci açılışta girebilir mi, (2) okulun WhatsApp’tan attığı sınıf listesi PDF’i uygulamada bulunamıyor.

Kod yazılan kısım yalnızca WhatsApp / sınıf listesi yükleme. Auth tarafı incelendi, davranış zaten doğruydu; koda dokunulmadı.

---

### 1. Öğretmen Google girişi ve offline (sadece netleştirme, kod yok)

**Soru:** İlk girişte Google ile kayıt olan öğretmen, ikinci açılışta internet yoksa uygulamaya giremez mi? Uygulama veli dışında tamamen local mi?

**Cevap (koddan doğrulandı):**

- İlk Google kaydı **internet ister** (`TeacherAuthService.signInWithGoogle`).
- Çıkış yapılmadıysa sonraki açılış **internetsiz girer**: Firebase Auth oturumu diskte, rol `SharedPreferences`’ta, sınıf/öğrenci `sinifcepte_{uid}.db` içinde.
- `WelcomeScreen._checkAutoLogin` kayıtlı öğretmen rolünü görünce `SchoolBindGate` → ana ekran. Google seçici yeniden açılmaz.
- Çıkış yapılıp tekrar Google’a basılırsa internet **şart**.
- Veli her açılışta oturum ister; çocuk verisi buluttan gelir.
- Günlük öğretmen işi (sınıf, katılım, sınav, BEP, program, belgeler, kazanım) yerel. Ağ: veli mesajı, duyuru, randevu, okul dizini, yönetici claim, müfredat güncellemesi.

Windows masaüstü zaten Google’suz yerel mod (`local_desktop`).

---

### 2. WhatsApp sınıf listesi PDF — asıl kod değişikliği

**Sorun:** Okul WhatsApp’tan PDF atıyor. Uygulamada “PDF yükle” sistem seçicisinin **Son dosyalar** sekmesini açıyor. WhatsApp belgesi oraya yazılmıyor; öğretmen dosyayı bulamıyor.

Bu Android kısıtı: WhatsApp PDF’i `Android/media/com.whatsapp/.../WhatsApp Documents` altında durur, MediaStore “Recent” indeksine düşmez.

**İki turda çözüldü.**

#### Tur 1 — Paylaş → SınıfCepte (doğrulandı: çalıştı)

WhatsApp’taki PDF’ye basıp **Paylaş → SınıfCepte** deyince liste içe aktarma ekranına düşer.

- Android `ACTION_SEND` / `ACTION_VIEW` intent (pdf, xls, xlsx, octet-stream).
- iOS `CFBundleDocumentTypes` + `AppDelegate` dosya kopyası.
- `IncomingShareService` (`sinifcepte/incoming_share`) paylaşımı öğretmen kromuna taşır.
- `StudentFileImporter`: `withData: true` (content URI’de path null oluyordu), uzantısız dosyada **magic bytes** (`%PDF`, OLE, ZIP).
- Kaynak sheet: WhatsApp’tan paylaş vs dosya.

#### Tur 2 — “Son dosyalarda yine yok” (paylaşım çalıştıktan sonra)

Öğretmen paylaşımı kullandı ama dosya seçicide hâlâ Son listesini arıyordu. **Son dosyalar asla göstermez.** Bundan sonra “Dosyalardan seç” Son’a gitmez.

- Native seçici `DocumentsContract.EXTRA_INITIAL_URI` ile **WhatsApp Documents** klasörünü açmayı dener (Son sekmesi değil).
- Uygulama içi liste: WhatsApp klasörü + indirme + daha önce paylaşılan cache kopyaları. WhatsApp kaynaklı dosyalar en üstte.
- Bir kez **klasöre izin ver** (SAF tree, kalıcı URI) → sonraki açılışlarda liste dolu gelir.
- Açılmadan önce uyarı: üstteki **“Son”** yazısına basma; `WhatsApp → Media → WhatsApp Documents` veya `Android/media/com.whatsapp/...`.
- Drive / başka konum yedek yolu: `FileType.any` (uzantı filtresi Samsung/Xiaomi’de WhatsApp belgelerini gizliyordu).

---

### Dokunulan dosyalar

**Yeni**

- `lib/core/share/incoming_share_service.dart`
- `lib/features/classes/data/services/recent_student_documents.dart`
- `lib/features/classes/presentation/widgets/student_import_source_sheet.dart`
- `lib/features/classes/presentation/widgets/student_document_browser_sheet.dart`
- `android/app/src/main/kotlin/com/sinifcepte/sinifcepte/WhatsAppDocuments.kt`
- `test/incoming_share_service_test.dart`
- `test/recent_student_documents_test.dart`

**Güncellenen**

- `android/app/src/main/kotlin/com/sinifcepte/sinifcepte/MainActivity.kt` — paylaşım + klasör seçici kanalı
- `android/app/src/main/AndroidManifest.xml` — SEND/VIEW intent, WhatsApp queries
- `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist` — Open In
- `lib/features/classes/data/services/student_file_importer.dart`
- `lib/features/classes/presentation/views/student_import_preview_view.dart`
- `lib/features/navigation/screens/main_navigation_screen.dart`
- `lib/main.dart` — `IncomingShareService.attach()`
- Sınıf/öğrenci boş durum metinleri (`class_list_screen`, `student_list_screen`, `my_class_hub_screen`)
- `test/student_file_importer_test.dart`

---

### Öğretmene hatırlatma (sahada)

1. En kolayı: WhatsApp’ta PDF → Paylaş → SınıfCepte.
2. Klasörden seçecekse: uygulamada **WhatsApp klasöründen seç** → **WhatsApp klasörünü aç**. Üstte “Son” varsa ona basıp WhatsApp Documents’e geç.
3. Bu intent/klasör yolu **yeniden derlenmiş APK** ister; eski yüklü sürümde Paylaş menüsünde SınıfCepte çıkmaz.

---

### Bilerek değişmeyenler

- Öğretmen verisi hâlâ cihazda SQLite; veli köprüsü hâlâ Firestore.
- Offline Google oturumu zaten vardı; ekstra “internetsiz Google login” yazılmadı.
- BEP tasarımı (`bep-tasarim.md`) bu oturumda koda geçirilmedi.
