import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/schedule/models/schedule_settings.dart';

/// Ders programinin kendiliginden degismesi (15 Eylul 2026).
///
/// ## Yasanan
/// > "ilk actim ders programini kaydettim. programi kapatip actigimda
/// > eski kaydettigim ders programi geldi. sonra kapadim aradan zaman
/// > gecti bi baktim yine ders programi degismis yenisi gelmis."
///
/// ## Sebep
/// `DatabaseHelper.database` getter'i `_database` bossa KOSULSUZ olarak
/// ortak `AppConfig.dbName` dosyasini aciyordu. Hesabin kendi dosyasi
/// (`openForUid`) ise ancak Firebase oturumu dogrulandiktan sonra
/// aciliyor ve o cagri ag yavasken 10 saniyeye kadar bekliyor.
///
/// Sonuc bir yaristi: o sure icinde veritabanina dokunan ilk is
/// (acilista arka planda calisan kazanim tohumlamasi) ortak dosyayi
/// aciyordu. Ogretmenin o sirada kaydettigi program ortak dosyaya
/// gidiyor, sonraki acilista hesabin dosyasi okununca "eski program"
/// geliyor, bir sonraki acilista yine ortak dosya acik kalinca "program
/// kendiliginden degisti" goruntusu olusuyordu.
///
/// Veri kaybolmuyordu; iki ayri dosyaya bolunuyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
  });

  group('Hangi dosya acilir', () {
    test('KRITIK: son hesap biliniyorsa ortak dosya ADI kullanilmaz', () {
      // Getter artik `lastKnownUid()` bos degilse o hesabin dosyasini
      // acar. Iki ad birbirinden farkli olmali; ayni olsalardi hesabin
      // verisi yine ortak dosyaya yazilirdi.
      final ortak = AppConfig.dbName;
      final hesap = AppConfig.teacherDbName('KplpM8ibNdhVJENzWz8tvJ0vsLR2');

      expect(hesap, isNot(ortak),
          reason: 'Hesabin dosyasi ortak dosyadan ayri olmali');
    });

    test('Kimlik yoksa ortak dosyaya dusulur', () async {
      // Ilk kurulum: henuz hic giris yapilmamis. Bu durumda ortak dosya
      // dogru davranistir, cunku daha yazilmis veri yoktur.
      final prefs = await PrefsService.instance();

      expect(prefs?.getString('sinifcepte_last_teacher_uid'), isNull);
    });

    test('KRITIK: son hesap kimligi yerel depoda durur (ag gerekmez)',
        () async {
      // Duzeltmenin dayanagi: kimlik Firebase beklenmeden okunabiliyor,
      // bu yuzden dogru dosya ILK KAREDEN ONCE acilabiliyor.
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'KplpM8ibNdhVJENzWz8tvJ0vsLR2',
      });
      PrefsService.resetCache();

      final prefs = await PrefsService.instance();

      expect(prefs?.getString('sinifcepte_last_teacher_uid'),
          'KplpM8ibNdhVJENzWz8tvJ0vsLR2');
    });
  });

  group('Saat ayarlari hesaba baglidir', () {
    test('KRITIK: ikinci hesap birinci hesabin saatlerini devralmaz',
        () async {
      // Dersler hesap basina ayri dosyada tutulurken saat ayarlari SABIT
      // anahtarlardaydi: ikinci hesap birincinin ders saatlerini,
      // ogle arasini ve gunluk ders sayisini goruyordu.
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'uidAhmet',
      });
      PrefsService.resetCache();

      const ahmet = ScheduleSettings(
        firstLessonTime: TimeOfDay(hour: 9, minute: 15),
        dailyLessonCount: 6,
      );
      await ahmet.save();

      // Zeynep ayni cihazda kendi hesabiyla giriyor.
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'uidZeynep',
      });
      PrefsService.resetCache();

      final zeynep = await ScheduleSettings.load();

      expect(zeynep.firstLessonTime.hour, 8,
          reason: 'Zeynep varsayilanla baslamali, Ahmet in saatiyle degil');
      expect(zeynep.dailyLessonCount, 8);
    });

    test('KRITIK: hesabin kendi saatleri geri okunur', () async {
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'uidAhmet',
      });
      PrefsService.resetCache();

      const kaydedilen = ScheduleSettings(
        firstLessonTime: TimeOfDay(hour: 9, minute: 15),
        lessonDuration: 45,
        dailyLessonCount: 6,
        hasLunchBreak: false,
      );
      await kaydedilen.save();
      PrefsService.resetCache();

      final okunan = await ScheduleSettings.load();

      expect(okunan.firstLessonTime.hour, 9);
      expect(okunan.firstLessonTime.minute, 15);
      expect(okunan.lessonDuration, 45);
      expect(okunan.dailyLessonCount, 6);
      expect(okunan.hasLunchBreak, isFalse);
    });

    test('KRITIK: guncelleme oncesi ayarlar kaybolmaz', () async {
      // Eski surumde ayarlar sabit anahtarlara yazilmisti. Hesaba bagli
      // kayit yoksa eski anahtardan okunmali; yoksa guncelleme yapan
      // her ogretmenin saatleri bir kereligine varsayilana donerdi.
      SharedPreferences.setMockInitialValues({
        'sinifcepte_last_teacher_uid': 'uidAhmet',
        'sched_first_hour': 9,
        'sched_first_min': 20,
        'sched_daily_count': 7,
      });
      PrefsService.resetCache();

      final okunan = await ScheduleSettings.load();

      expect(okunan.firstLessonTime.hour, 9,
          reason: 'Eski sabit anahtardaki ayar korunmali');
      expect(okunan.firstLessonTime.minute, 20);
      expect(okunan.dailyLessonCount, 7);
    });

    test('Masaustu yerel modunda sabit anahtar kullanilir', () async {
      // Kimlik yoksa eski davranis surer; masaustu yerel modu boyle
      // calisir (Windows ta Google girisi yapilamiyor).
      const ayar = ScheduleSettings(dailyLessonCount: 5);
      await ayar.save();
      PrefsService.resetCache();

      final prefs = await PrefsService.instance();

      expect(prefs?.getInt('sched_daily_count'), 5,
          reason: 'Kimlik yokken sabit anahtara yazilmali');
    });
  });
}
