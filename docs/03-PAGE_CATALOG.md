# 📱 SınıfCepte - Sayfa ve Bileşen Kataloğu

Bu belgede projedeki mevcut ve yapılması planlanan tüm sayfalar, bileşenler ve işlevleri adım adım listelenmiştir.

---

## 🟢 Mevcut Sayfalar & Bileşenler

### 1. Başlangıç Ekranı (`BaslangicEkrani`)
- **Dosya**: [main.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/main.dart)
- **Görevi**: Uygulamanın karılama/splash ekranı. Proje logosu, gradient arka plan ve altyapı hazır bildirim kartını gösterir.
- **Bileşenler**:
  - `LinearGradient` arka plan katmanı
  - Indigo Moru dairesel logo ikonu (`Icons.school_rounded`)
  - Google Fonts `Outfit` başlık ve alt metin
  - Cam Kart (`GlassCard`) bilgi paneli

### 2. Cam Kart Bileşeni (`GlassCard`)
- **Dosya**: [glass_card.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/shared/widgets/glass_card.dart)
- **Görevi**: Uygulamanın tüm modüllerinde kullanılacak şeffaf, buzlu cam efektli (Glassmorphism) kart bileşeni.
- **Özellikler**:
  - `BackdropFilter` ile anlık arka plan bulanıklaştırma (sigma: 10).
  - Dark Mode ve Light Mode için dinamik sınır (`glassBorder`) ve dolgu renkleri.
  - Tıklanabilirlik desteği (`onTap` callback).

### 3. Tema ve Renk Paleti (`AppColors` & `AppTheme`)
- **Dosyalar**:
  - [app_colors.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/core/theme/app_colors.dart)
  - [app_theme.dart](file:///c:/Users/Okul/Desktop/Projelerim/sinifcepte/lib/core/theme/app_theme.dart)
- **Görevi**: UI-UX-MAX tasarım sisteminin tüm renk sabitlerini, Material 3 tema kurallarını, AppBar, Card, FloatingActionButton ve NavigationBar stillerini yönetir.

---

## 🟡 Planlanan Sayfalar & Ekranlar

### 4. Ana Kontrol Paneli (`DashboardScreen`)
- **Konum**: `lib/features/dashboard/screens/dashboard_screen.dart`
- **Görevi**: Öğretmenin günün özetini gördüğü ana ekran.
- **İçerik**:
  - Bugünün ders programı (Hangi saat hangi sınıfta?).
  - Hızlı yoklama başlat butonu.
  - Toplam sınıf ve öğrenci sayısı istatistik kartları.
  - Son alınan yoklamaların özet grafik/kartları.

### 5. Sınıf & Öğrenci Yönetim Ekranı (`ClassListScreen` / `StudentListScreen`)
- **Konum**: `lib/features/classes/screens/`
- **Görevi**: Sınıfları listeleme, yeni sınıf ekleme, sınıf içine öğrenci ekleme/silme ve Excel'den toplu içe aktarma (`.xlsx` aktarımı).

### 6. Hızlı Yoklama Alma Ekranı (`AttendanceScreen`)
- **Konum**: `lib/features/attendance/screens/attendance_screen.dart`
- **Görevi**: Öğretmenin derste yoklama aldığı dinamik ekran.
- **Özellikler**:
  - Öğrenci kartları üzerinden kaydırma (swipe) veya tek tıkla durum seçimi (Var 🟢, Yok 🔴, Geç 🟡, İzinli 🔵).
  - Tümünü Var İşaretle hızlı aksiyon butonu.
  - Tamamla ve Kaydet butonu.

### 7. Yoklama Geçmişi & Detay Ekranı (`AttendanceHistoryScreen`)
- **Konum**: `lib/features/attendance/screens/attendance_history_screen.dart`
- **Görevi**: Geçmiş tarihlerde alınan yoklamaları inceleme, hatalı kayıtları düzeltme ve devam istatistiklerini görüntüleme.

### 8. Performans & Not Değerlendirme Ekranı (`PerformanceScreen`)
- **Konum**: `lib/features/performance/screens/performance_screen.dart`
- **Görevi**: Öğrencilere ders içi etkinlik, artı/eksi, ödev takibi ve performans notu verme ekranı.

### 9. Rapor Oluşturucu & Yazdırma Ekranı (`ReportExportScreen`)
- **Konum**: `lib/features/reports/screens/report_export_screen.dart`
- **Görevi**: Seçilen sınıf ve tarih aralığı için PDF/Excel yoklama listesi oluşturma ve direkt yazıcıya gönderme.

### 10. Ayarlar Ekranı (`SettingsScreen`)
- **Konum**: `lib/features/settings/screens/settings_screen.dart`
- **Görevi**: Tema seçimi (Açık/Koyu/Sistem), Veritabanı Yedekle/Yükle, Okul Bilgileri girme.
