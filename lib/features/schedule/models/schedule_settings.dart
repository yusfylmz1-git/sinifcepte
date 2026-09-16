import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/storage/prefs_service.dart';

/// SınıfCepte - Ders Programı Ayarları Modeli ve Kalıcı Depolama Yöneticisi
class ScheduleSettings {
  final TimeOfDay firstLessonTime;
  final int lessonDuration; // dakika (varsayılan: 40)
  final int breakDuration; // dakika (varsayılan: 10)
  final int dailyLessonCount; // varsayılan: 8
  final bool hasLunchBreak; // varsayılan: true
  final int lunchBreakDuration; // dakika (varsayılan: 45)
  final int lunchBreakAfterLesson; // kaçıncı dersten sonra (varsayılan: 4)

  const ScheduleSettings({
    this.firstLessonTime = const TimeOfDay(hour: 8, minute: 30),
    this.lessonDuration = 40,
    this.breakDuration = 10,
    this.dailyLessonCount = 8,
    this.hasLunchBreak = true,
    this.lunchBreakDuration = 45,
    this.lunchBreakAfterLesson = 4,
  });

  ScheduleSettings copyWith({
    TimeOfDay? firstLessonTime,
    int? lessonDuration,
    int? breakDuration,
    int? dailyLessonCount,
    bool? hasLunchBreak,
    int? lunchBreakDuration,
    int? lunchBreakAfterLesson,
  }) {
    return ScheduleSettings(
      firstLessonTime: firstLessonTime ?? this.firstLessonTime,
      lessonDuration: lessonDuration ?? this.lessonDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      dailyLessonCount: dailyLessonCount ?? this.dailyLessonCount,
      hasLunchBreak: hasLunchBreak ?? this.hasLunchBreak,
      lunchBreakDuration: lunchBreakDuration ?? this.lunchBreakDuration,
      lunchBreakAfterLesson: lunchBreakAfterLesson ?? this.lunchBreakAfterLesson,
    );
  }

  /// Belirli bir ders saati index'i için (0 = 1. Ders, 1 = 2. Ders...) başlangıç ve bitiş saatini dinamik hesaplar
  String calculateTimeRange(int lessonIndex) {
    final int startMinutes = firstLessonTime.hour * 60 + firstLessonTime.minute;

    int passedMinutes = lessonIndex * (lessonDuration + breakDuration);

    // Eğer öğle arası varsa ve ders öğle arasından sonraysa
    if (hasLunchBreak && lessonIndex >= lunchBreakAfterLesson) {
      passedMinutes += (lunchBreakDuration - breakDuration);
    }

    final int lessonStartMin = startMinutes + passedMinutes;
    final int lessonEndMin = lessonStartMin + lessonDuration;

    String formatMin(int totalMin) {
      final int hour = (totalMin ~/ 60) % 24;
      final int min = totalMin % 60;
      return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }

    return '${formatMin(lessonStartMin)} - ${formatMin(lessonEndMin)}';
  }

  /// Öğle arası saat aralığını hesaplar (Örn: "11:40 - 12:25")
  String calculateLunchTimeRange() {
    if (!hasLunchBreak) return '';
    final int startMinutes = firstLessonTime.hour * 60 + firstLessonTime.minute;
    final int beforeLunchMinutes = lunchBreakAfterLesson * (lessonDuration + breakDuration) - breakDuration;
    
    final int lunchStartMin = startMinutes + beforeLunchMinutes;
    final int lunchEndMin = lunchStartMin + lunchBreakDuration;

    String formatMin(int totalMin) {
      final int hour = (totalMin ~/ 60) % 24;
      final int min = totalMin % 60;
      return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }

    return '${formatMin(lunchStartMin)} - ${formatMin(lunchEndMin)}';
  }

  // --- Kalıcı Depolama Anahtarları (PrefsService) ---
  static const _kFirstLessonHour = 'sched_first_hour';
  static const _kFirstLessonMin = 'sched_first_min';
  static const _kLessonDuration = 'sched_lesson_dur';
  static const _kBreakDuration = 'sched_break_dur';
  static const _kDailyLessonCount = 'sched_daily_count';
  static const _kHasLunchBreak = 'sched_has_lunch';
  static const _kLunchDuration = 'sched_lunch_dur';
  static const _kLunchAfter = 'sched_lunch_after';

  /// Saat ayarlarını hesaba bağlar.
  ///
  /// Dersler hesap başına ayrı veritabanı dosyasında tutulurken saat
  /// ayarları SABİT anahtarlarda duruyordu: aynı cihazda ikinci bir
  /// hesapla girildiğinde birinci hesabın ders saatleri, öğle arası ve
  /// günlük ders sayısı devralınıyordu. Program hesaba özelse saatleri
  /// de öyle olmalı.
  ///
  /// Kimlik yoksa (masaüstü yerel modu, henüz giriş yapılmamış) eski
  /// sabit anahtar kullanılır — o kurulumlarda mevcut ayarlar olduğu
  /// gibi okunmaya devam eder.
  static String _key(String base, String uid) =>
      uid.isEmpty ? base : '${base}__$uid';

  static Future<String> _activeUid() async {
    try {
      return await DatabaseHelper.lastKnownUid();
    } catch (_) {
      return '';
    }
  }

  static Future<ScheduleSettings> load() async {
    try {
      final prefs = await PrefsService.instance();
      final uid = await _activeUid();

      /// Hesabın kendi kaydı yoksa eski sabit anahtardan okur.
      ///
      /// Bu geri düşüş olmadan, güncellemeden önce ayar yapmış her
      /// öğretmenin saatleri bir kereliğine varsayılana dönerdi.
      int? okuInt(String base) =>
          prefs?.getInt(_key(base, uid)) ?? prefs?.getInt(base);
      bool? okuBool(String base) =>
          prefs?.getBool(_key(base, uid)) ?? prefs?.getBool(base);

      final hour = okuInt(_kFirstLessonHour) ?? 8;
      final min = okuInt(_kFirstLessonMin) ?? 30;
      final lessonDur = okuInt(_kLessonDuration) ?? 40;
      final breakDur = okuInt(_kBreakDuration) ?? 10;
      final dailyCount = okuInt(_kDailyLessonCount) ?? 8;
      final hasLunch = okuBool(_kHasLunchBreak) ?? true;
      final lunchDur = okuInt(_kLunchDuration) ?? 45;
      final lunchAfter = okuInt(_kLunchAfter) ?? 4;

      return ScheduleSettings(
        firstLessonTime: TimeOfDay(hour: hour, minute: min),
        lessonDuration: lessonDur,
        breakDuration: breakDur,
        dailyLessonCount: dailyCount,
        hasLunchBreak: hasLunch,
        lunchBreakDuration: lunchDur,
        lunchBreakAfterLesson: lunchAfter,
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleSettings.load) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------');
      return const ScheduleSettings();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      final uid = await _activeUid();
      await prefs.setInt(_key(_kFirstLessonHour, uid), firstLessonTime.hour);
      await prefs.setInt(_key(_kFirstLessonMin, uid), firstLessonTime.minute);
      await prefs.setInt(_key(_kLessonDuration, uid), lessonDuration);
      await prefs.setInt(_key(_kBreakDuration, uid), breakDuration);
      await prefs.setInt(_key(_kDailyLessonCount, uid), dailyLessonCount);
      await prefs.setBool(_key(_kHasLunchBreak, uid), hasLunchBreak);
      await prefs.setInt(_key(_kLunchDuration, uid), lunchBreakDuration);
      await prefs.setInt(_key(_kLunchAfter, uid), lunchBreakAfterLesson);
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleSettings.save) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------');
    }
  }
}
