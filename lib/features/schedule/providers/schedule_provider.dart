import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/legacy_crud_methods.dart';
import '../models/lesson_model.dart';
import '../models/schedule_settings.dart';

// --- 1. DERS PROGRAMI AYARLARI PROVIDER'I ---

final scheduleSettingsProvider =
    StateNotifierProvider<ScheduleSettingsNotifier, ScheduleSettings>(
  (ref) => ScheduleSettingsNotifier(),
);

class ScheduleSettingsNotifier extends StateNotifier<ScheduleSettings> {
  ScheduleSettingsNotifier() : super(const ScheduleSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final loaded = await ScheduleSettings.load();
      state = loaded;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleSettingsNotifier.load) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-----------------------------------------------------------------------------');
    }
  }

  Future<void> updateSettings(ScheduleSettings newSettings) async {
    try {
      state = newSettings;
      await newSettings.save();
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleSettingsNotifier.update) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-------------------------------------------------------------------------------');
    }
  }
}

// --- 2. DERS LİSTESİ PROVIDER'I ---

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, List<LessonModel>>(
  (ref) => ScheduleNotifier(),
);

class ScheduleNotifier extends StateNotifier<List<LessonModel>> {
  ScheduleNotifier() : super([]) {
    loadLessons();
  }

  Future<void> loadLessons() async {
    try {
      final list = await DatabaseHelper.instance.dersleriGetir();
      if (list.isNotEmpty) {
        state = list.map((x) => LessonModel.fromMap(x)).toList();
      } else {
        state = [];
      }
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleNotifier.loadLessons) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------');
    }
  }

  Future<bool> addLesson(LessonModel lesson) async {
    try {
      // Eğer aynı gün ve saatte varsa önce eskiyi sil/üzerine yaz
      final existing = state.where((l) =>
          l.day == lesson.day && l.lessonHourIndex == lesson.lessonHourIndex).firstOrNull;

      if (existing != null && existing.id != null) {
        await DatabaseHelper.instance.dersSil(existing.id!);
        state = state.where((l) => l.id != existing.id).toList();
      }

      final int id = await DatabaseHelper.instance.dersEkle(lesson.toMap());
      final newLesson = lesson.copyWith(id: id);
      state = [...state, newLesson];
      return true;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleNotifier.addLesson) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('--------------------------------------------------------------------------');
      return false;
    }
  }

  Future<bool> deleteLesson(int id) async {
    try {
      await DatabaseHelper.instance.dersSil(id);
      state = state.where((d) => d.id != id).toList();
      return true;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleNotifier.deleteLesson) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-----------------------------------------------------------------------------');
      return false;
    }
  }

  Future<bool> updateLesson(LessonModel lesson) async {
    try {
      await DatabaseHelper.instance.dersGuncelle(lesson.toMap());
      state = [
        for (final d in state)
          if (d.id == lesson.id) lesson else d,
      ];
      return true;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ScheduleNotifier.updateLesson) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-----------------------------------------------------------------------------');
      return false;
    }
  }
}
