import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendance/providers/classroom_participation_provider.dart';
import '../../features/classes/providers/class_provider.dart';
import '../../features/navigation/providers/navigation_provider.dart';
import '../../features/classes/providers/student_provider.dart';
import '../../features/classes/providers/seating_plan_provider.dart';
import '../../features/exam_operations/providers/exam_tracking_provider.dart';
import '../../features/exam_operations/providers/project_tracking_provider.dart';
import '../../features/exam_operations/providers/quiz_tracking_provider.dart';
import '../../features/schedule/providers/schedule_provider.dart';

/// Hesap değişiminde yerel veri sağlayıcılarını tazeler.
///
/// ## Neden gerekli
/// Veri hesap başına ayrı SQLite dosyasında tutuluyor
/// (`DatabaseHelper.openForUid`). Ama Riverpod sağlayıcıları **hesap
/// değişince yeniden yüklenmiyordu**: ikinci hesapla giren öğretmen
/// birinci hesabın sınıflarını görüyordu.
///
/// Kullanıcı bildirimi (31 Ağustos 2026):
/// > "1. mailla girdim sınıf ekledim. 2. mailla girdiğimde yüklediğim
/// > sınıflar gözüküyordu ve sınıfı rehberlik sınıfım yap deyince
/// > sınıflar kayboldu."
///
/// İkinci kısım da bunun sonucu: ekranda **eski hesabın** sınıfı
/// görünüyor, "rehberlik sınıfım yap" denince yazma **yeni ve boş**
/// veritabanına gidiyor, ardından liste tazelenince gerçek (boş) durum
/// ortaya çıkıyordu. Yani sınıflar kaybolmuyordu; hiç orada değildi.
///
/// ## Neden tek yerde
/// Her giriş noktası kendi listesini tazelemeye kalksaydı biri mutlaka
/// unutulurdu. Yeni bir yerel sağlayıcı eklendiğinde **buraya da
/// eklenmelidir**.
class AccountSwitch {
  AccountSwitch._();

  /// Hesap değiştikten sonra çağrılır; tüm yerel veri sağlayıcılarını
  /// geçersiz kılar, böylece yeni hesabın veritabanından okunurlar.
  ///
  /// Bulut sağlayıcıları burada yer almaz: onlar zaten oturum kimliğine
  /// bağlı çalışır.
  static void invalidateLocalData(WidgetRef ref) {
    // Alt bar sekmesini Özet'e döndür.
    //
    // `navigationIndexProvider` bir `StateProvider`; çıkış yapılınca
    // sıfırlanmıyordu. Çıkış düğmesi PROFİL sekmesinde olduğu için
    // değer 4'te kalıyor ve tekrar girildiğinde uygulama doğrudan
    // profil ekranıyla açılıyordu.
    //
    // Kullanıcı bildirimi: "giriş yaptıktan sonra direk bu ekran
    // geliyor karşımıza" (ekran görüntüsü: Profilim, alt barda Profil
    // seçili).
    ref.invalidate(navigationIndexProvider);

    // Sınıf ve öğrenci
    ref.invalidate(classListProvider);
    ref.invalidate(studentListProvider);
    ref.invalidate(seatingPlanProvider);

    // Ders programı
    ref.invalidate(scheduleProvider);
    ref.invalidate(scheduleSettingsProvider);

    // Sınav işlemleri
    ref.invalidate(examTrackingProvider);
    ref.invalidate(quizTableProvider);
    ref.invalidate(projectTrackingProvider);

    // Ders içi katılım
    ref.invalidate(currentParticipationSessionProvider);
    ref.invalidate(activeTimetableLessonProvider);

    // Kazanımlar hesaba bağlı değil (APK ile gelen ortak veri);
    // tazelenmesi gerekmiyor.
  }

  /// `WidgetRef` yerine `Ref` ile çağrılabilen sürüm.
  static void invalidateLocalDataFromRef(Ref ref) {
    ref.invalidate(navigationIndexProvider);
    ref.invalidate(classListProvider);
    ref.invalidate(studentListProvider);
    ref.invalidate(seatingPlanProvider);
    ref.invalidate(scheduleProvider);
    ref.invalidate(scheduleSettingsProvider);
    ref.invalidate(examTrackingProvider);
    ref.invalidate(quizTableProvider);
    ref.invalidate(projectTrackingProvider);
    ref.invalidate(currentParticipationSessionProvider);
    ref.invalidate(activeTimetableLessonProvider);
  }
}
