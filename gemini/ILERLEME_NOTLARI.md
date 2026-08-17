# 🚀 SınıfCepte - Yapay Zeka İlerleme ve Canlı Hafıza Notları (AI Progress Notes)

> **Bu dosya, SınıfCepte projesinin yapay zeka (Gemini, Claude, GPT vb.) modelleri arasındaki canlı hafızasını, mimari kararlarını ve tamamlanan aşamalarını kaydeder.**

---

## 📌 1. Proje Kimlik Kartı & Anayasası

- **Proje Adı**: SınıfCepte
- **Hedef Kitle**: Öğretmenler ve Eğitmenler
- **Teknoloji Yığını**: Flutter 3.x (Dart)
- **Durum Yönetimi (State Management)**: Riverpod (`flutter_riverpod` ^2.6.1)
- **Veritabanı (Backend)**: %100 Offline-First Yerel SQLite (`sqflite` + `sqflite_common_ffi`)
- **Tasarım Dili**: UI-UX-MAX (Glassmorphism, Koyu/Açık Tema, Google Fonts Outfit)

---

## ⚠️ 2. Kritik Mimari ve Proje Kuralları (Project Rules)

1. **YOKLAMA SİSTEMİ YOKTUR**: Uygulamada yoklama alma fonksiyonu kesinlikle yer almayacaktır. Bu yönde hiçbir öneride bulunulmayacaktır.
2. **İkili Hata Yönetimi (Dual Error Handling)**:
   - **Geliştirici (Terminal)**: Tüm `catch (e, st)` bloklarında `debugPrint` ile hata mesajı (`$e`) ve satır numarası (`$st`) loglanır.
   - **Kullanıcı (Arayüz)**: Ekran kullanıcı dostu nazik bildirimler (SnackBar/Dialog) gösterir, teknik kod yansıtılmaz.
3. **Offline-First & Sıfır Maliyet**: Tüm veriler öncelikle yerel SQLite veritabanında saklanır. İnternet kotası harcamaz, bulut sunucu maliyeti çıkarmaz.
4. **KVKK & Yasal Uyum**: Öğrenci ve veli kişisel verileri cihaz dışına izinsiz aktarılmaz. Silinen veriler SQLite'dan kalıcı (Cascade Delete) silinir.
5. **Etki Analizi & Çift Tema Testi**: Yapılan her değişiklikte hem Koyu (Dark) hem Açık (Light) modlarda ikon/metin kontrastı kontrol edilir.
6. **Kullanıcı Onayı Kuralı**: Yapay zeka kullanıcı **"Başla / Yap"** demeden koda geçmez; önce önerisini sunar, onay alır.

---

## 🟢 3. Tamamlanan Dosyalar ve Modüller

### A. Tema ve Konfigürasyon
- [app_colors.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/core/theme/app_colors.dart) — Slate Navy, Ice White, Mor gradyanlar.
- [app_theme.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/core/theme/app_theme.dart) — Material 3 Açık ve Koyu tema kuralları.
- [theme_provider.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/core/theme/theme_provider.dart) — `SharedPreferences` entegreli dinamik tema seçici.
- [app_config.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/core/config/app_config.dart) — Ortam yönetimi (Dev / Staging / Prod).

### B. Veritabanı ve Modeller
- [database_helper.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/core/database/database_helper.dart) — Mobil & Masaüstü FFI destekli SQLite veritabanı sürücüsü.
- **Veri Modelleri**: `ClassModel`, `StudentModel`, `AttendanceStatus`, `AttendanceSessionModel`, `AttendanceRecordModel`.
- **Erişim Katmanları (DAO)**: `ClassRepository`, `StudentRepository`, `AttendanceRepository`.

### C. Ekranlar ve Bileşenler
- [main.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/main.dart) — `themeModeProvider` ve FFI başlatmalı uygulama giriş noktası.
- [welcome_screen.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/features/auth/screens/welcome_screen.dart) — "Hızlı Başla" ve "Google ile Yedekle & Başla" seçenekli Hoş Geldiniz ekranı.
- [class_list_screen.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/features/classes/screens/class_list_screen.dart) — Sınıf Listesi ve Ana Kontrol Paneli ekranı.
- [student_list_screen.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/features/classes/screens/student_list_screen.dart) — Sınıfa ait öğrenci liste ve ekleme ekranı.
- [app_drawer.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/shared/widgets/app_drawer.dart) — Sol üst 3 çizgi gezinme çekmecesi, KVKK bildirimi ve yerel yedekleme.
- [settings_screen.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/features/settings/screens/settings_screen.dart) — Koyu / Açık / Sistem teması seçici ekranı.
- [glass_card.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/shared/widgets/glass_card.dart) — Glassmorphism cam kart bileşeni.

---

## 🎯 4. Gelecek Adımlar ve Beklenen Düzen

- Kullanıcının ileteceği örnek klasör yapısına göre projenin hiyerarşisinin düzenlenmesi.
- Ana Ekran / Kontrol Paneli düzeninin yeni gereksinimlere göre şekillendirilmesi.
