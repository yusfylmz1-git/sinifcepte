import 'package:flutter/material.dart';
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

  static Future<ScheduleSettings> load() async {
    try {
      final prefs = await PrefsService.instance();
      final hour = prefs?.getInt(_kFirstLessonHour) ?? 8;
      final min = prefs?.getInt(_kFirstLessonMin) ?? 30;
      final lessonDur = prefs?.getInt(_kLessonDuration) ?? 40;
      final breakDur = prefs?.getInt(_kBreakDuration) ?? 10;
      final dailyCount = prefs?.getInt(_kDailyLessonCount) ?? 8;
      final hasLunch = prefs?.getBool(_kHasLunchBreak) ?? true;
      final lunchDur = prefs?.getInt(_kLunchDuration) ?? 45;
      final lunchAfter = prefs?.getInt(_kLunchAfter) ?? 4;

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
      await prefs.setInt(_kFirstLessonHour, firstLessonTime.hour);
      await prefs.setInt(_kFirstLessonMin, firstLessonTime.minute);
      await prefs.setInt(_kLessonDuration, lessonDuration);
      await prefs.setInt(_kBreakDuration, breakDuration);
      await prefs.setInt(_kDailyLessonCount, dailyLessonCount);
      await prefs.setBool(_kHasLunchBreak, hasLunchBreak);
      await prefs.setInt(_kLunchDuration, lunchBreakDuration);
      await prefs.setInt(_kLunchAfter, lunchBreakAfterLesson);
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleSettings.save) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------');
    }
  }
}
