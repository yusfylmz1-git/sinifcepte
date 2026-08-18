# 🤖 Gemini İlerleme Notları

Bu dosya, **SınıfCepte** projesinde **Gemini (Antigravity)** tarafından yapılan değişiklikleri, analizleri ve planları takip etmek amacıyla oluşturulmuştur. Diğer AI (Claude, Grok vb.) araçlarıyla çalışırken yapılan değişikliklerin karışmaması ve projenin kaldığı yerin kolayca tespit edilebilmesi için her oturum sonunda güncellenir.

---

## 📅 18 Ağustos 2026

### 🔍 Kapsamlı Proje Analizi & Oturum 1
* **Mimari Hakimiyet:** 17 modül, 150+ Dart dosyası, 26 SQLite tablosu (v11) ve Claude tarafından kurulan 6 Fazlık Bulut/Hibrit altyapısı detaylıca incelendi.
* **Test Durumu:** 178/178 birim testi ve 78/78 Firestore kural testinin eksiksiz geçtiği doğrulandı.

### 🛠️ Veli & Öğretmen Giriş / Bağlantı / Navigasyon İyileştirmeleri
Kullanıcı testlerinde ortaya çıkan kritik akış ve UX sorunları çözüldü:

1. **Akıllı Kod Normalizasyonu (`ParentTokenModel.normalizeCode`):**
   * Velinin kodu tiresiz (`SC8A9402`), küçük harfle (`sc-8a-9402`), boşluklu (`sc 8a 9402`) veya ön eksiz (`8A-9402`) girmesi durumunda kodun otomatik olarak standart `SC-{classTag}-{digits}` formatına çevrilmesi ve hash'lenmesi sağlandı.
   * `parent_token_model.dart`, `parent_link_bridge.dart` ve `parent_token_repository.dart` güncellendi.
   * Birim testleri `test/parent_token_test.dart` içine eklendi.

2. **Google Hesap Seçici & Oturum Temizliği:**
   * `TeacherAuthService` ve `ParentAuthService` içinde `signInWithGoogle` çağrılmadan önce `_googleSignIn.signOut()` eklenerek, aynı cihazda hem öğretmen hem veli testi yapılırken Google Hesap Seçici penceresinin her defasında zorunlu açılması sağlandı.
   * Veli mailiyle öğretmene girip okul sorma karmaşası kökten engellendi.

3. **Öğretmen Okul Seçim Ekranı (`SchoolBindGate`) Çıkış ve Navigasyon:**
   * Yeni bir Google hesabıyla girildiğinde açılan `SchoolBindGate` ekranına:
     * Sol üstte geri tuşu (`←`), sağ üstte çarpı (`✕`) butonu eklendi.
     * Android donanım geri tuşu için `PopScope` entegre edildi.
     * Üst kısımda aktif giriş yapılan Google hesabı (adı, e-postası ve Öğretmen rozeti) gösterildi.
     * En altta **"🚪 Farklı Bir Hesapla Giriş Yap / Çıkış"** butonu eklendi.
     * Kullanıcı geri veya çıkış butonuna bastığında Google oturumu temizlenip güvenle karşılama ekranına (`WelcomeScreen`) döndürülmesi sağlandı.
     * Okul modalı (`SchoolSelectionModal`) dismissible yapılarak çarpıyla kapatılabilir hale getirildi.

4. **Veli Ekranında Geri Tuşu & Çıkış Butonları:**
   * `ParentDashboardScreen` ve `ParentStudentConnectScreen` ekranlarına `PopScope` entegre edildi.
   * Henüz çocuk eklenmemişken geri tuşuna basıldığında uygulama kapanması engellendi; giriş ekranına dönüş sağlandı.
   * Formun altına belirgin **"🚪 Çıkış Yap"** ve **"👨‍🏫 Öğretmen Modu"** butonları eklendi.

### 🚀 SharedPreferences.getInstance() Kilitlenme ve ANR Çözümü (Faz Tamamlama)
* **Kök Neden:** Android platform kanalında doğrudan yapılan 55 ayrı `SharedPreferences.getInstance()` çağrısının ağır eşzamanlı isteklerde kanalı kilitlemesi ve süresiz bekleyerek ANR / donma üretmesi tespit edildi.
* **Merkezi Çözüm (`PrefsService`):**
  * Tüm kod tabanındaki (14 dosya) doğrudan `SharedPreferences.getInstance()` çağrıları `PrefsService.instance()` yapısına geçirildi.
  * 3 saniyelik zaman aşımı (`Duration(seconds: 3)`), `_inFlight` tek istek birleştirme (deduplication) ve `_cached` tek örnek önbellekleme sağlandı.
  * `main.dart` içinde `PrefsService.warmUp()` ile uygulama açılışında depo ısıtması yapıldı.
  * `PrefsMigrator` ve `PrefsService` birim testleri için `@visibleForTesting resetCache()` ve `resetForTest()` fonksiyonlarıyla donatıldı.
* **Dönüştürülen Modüller:**
  1. `lib/core/theme/theme_provider.dart`
  2. `lib/features/auth_profile/providers/user_role_provider.dart`
  3. `lib/features/auth_profile/providers/teacher_profile_provider.dart`
  4. `lib/core/database/database_helper.dart`
  5. `lib/core/cloud/delta_sync_tracker.dart`
  6. `lib/core/cloud/firestore_budget_guard.dart`
  7. `lib/core/ads/ad_gate.dart`
  8. `lib/features/outcomes/data/repositories/curriculum_outcome_repository.dart`
  9. `lib/features/parent_portal/data/repositories/parent_portal_repository.dart`
  10. `lib/features/parent_portal/data/services/kvkk_consent_service.dart`
  11. `lib/features/parent_portal/data/services/parent_auth_service.dart`
  12. `lib/features/parent_portal/data/services/parent_lifecycle_service.dart`
  13. `lib/features/schedule/models/schedule_settings.dart`
  14. `lib/features/schools/data/repositories/school_repository.dart`

### ⚡ QR Kod & Referans Kodu Üretiminde Kilitlenme / Donma Çözümü
* **Kök Neden:**
  1. `TeacherProfileNotifier` yerel depoya `profil_id` kaydetmediği ve geri yüklemediği için uygulama yeniden açıldığında `teacher.id` `'local_teacher'` olarak kalıyordu.
  2. Firestore kurallarında `request.auth.uid == teacherUid` eşleşmesi `'local_teacher'` != `Firebase UID` olduğundan Firestore batch yazması reddediliyor ve 8-10 saniyelik ağ zaman aşımı süresince arayüzü kilitliyordu.
  3. `FirestoreClient.ensureConfigured()` içinde `db.settings` zaten uygulanmışken hata fırlatıp `_configured = false` bırakabiliyordu.
  4. `ParentStudentConnectScreen` bulut köprüsünü çağırmayıp yalnızca yerel depodan doğrulamaya çalışıyordu.
* **Uygulanan Çözüm:**
  1. `ParentTokenCardModal`: Kod yerelde anında (1 ms) üretilip arayüz (`studentActiveTokenProvider`) hemen tetiklenir; öğretmen QR kodu ve referans kodunu anında ekranda görür. Buluta yükleme işlemi arka planda 3 saniye zaman aşımı korumalı çalışır ve arayüzü asla dondurmaz.
  2. `TeacherProfileNotifier`: `profil_id` yerel depoya yazıldı, `loadProfileFromStorage` içinde aktif `FirebaseAuth.instance.currentUser?.uid` ile senkronize edildi.
  3. `FirestoreClient`: Zaman aşımı 3 saniyeye çekildi, `db.settings` korumalı hale getirildi.
  4. `ParentStudentConnectScreen`: `ParentLinkBridge.verifyAndLink` (bulut) ve `repo.verifyToken` (yerel/offline) ardışık fallback mimarisiyle birbirine bağlandı.

### 🧪 Test ve Analiz Durumu
* `flutter test` → **206/206 test EKSİKSİZ BAŞARILI**
* `flutter analyze` → **0 issue / Hata Yok**
* Çalışma ağacında tek bir doğrudan `SharedPreferences.getInstance()` çağrısı kalmadı (`PrefsService` korumalı wrapper hariç).
