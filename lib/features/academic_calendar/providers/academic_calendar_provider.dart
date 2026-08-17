import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../data/models/academic_calendar_event_model.dart';

/// SınıfCepte - MEB Akademik Takvim Sağlayıcısı
final academicCalendarProvider = StateNotifierProvider<
    AcademicCalendarNotifier, List<AcademicCalendarEventModel>>((ref) {
  return AcademicCalendarNotifier();
});

/// Sıradaki En Yakın Tatil / Olay Sağlayıcısı
final nextUpcomingCalendarEventProvider =
    Provider<AcademicCalendarEventModel?>((ref) {
  final events = ref.watch(academicCalendarProvider);
  final upcoming = events.where((e) => e.daysRemaining >= 0).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  return upcoming.isNotEmpty ? upcoming.first : null;
});

/// Bugün bir resmî tatil / ara tatil / takvim olayı var mı?
final todayCalendarEventProvider = Provider<AcademicCalendarEventModel?>((ref) {
  final events = ref.watch(academicCalendarProvider);
  final todays = events.where((e) => e.isToday).toList();
  return todays.isNotEmpty ? todays.first : null;
});


class AcademicCalendarNotifier
    extends StateNotifier<List<AcademicCalendarEventModel>> {
  AcademicCalendarNotifier() : super([]) {
    loadEvents();
  }

  Future<void> loadEvents({String academicYear = '2025-2026'}) async {
    try {
      final rawList = await DatabaseHelper.instance
          .academicCalendarGetir(academicYear: academicYear);

      if (rawList.isNotEmpty) {
        state = rawList
            .map((map) => AcademicCalendarEventModel.fromMap(map))
            .toList();
      } else {
        state = [];
      }
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AcademicCalendarNotifier.loadEvents) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------');
      state = [];
    }
  }

  Future<bool> addEvent(AcademicCalendarEventModel event) async {
    try {
      final id = await DatabaseHelper.instance.academicCalendarEkle(event.toMap());
      if (id > 0) {
        state = [...state, event.copyWith(id: id)];
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AcademicCalendarNotifier.addEvent) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('--------------------------------------------------------------------------------');
      return false;
    }
  }

  Future<void> syncFromCloud(List<AcademicCalendarEventModel> cloudEvents) async {
    try {
      final maps = cloudEvents.map((e) => e.toMap()).toList();
      await DatabaseHelper.instance.academicCalendarTopluGuncelle(maps);
      state = cloudEvents;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AcademicCalendarNotifier.syncFromCloud) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('------------------------------------------------------------------------------------');
    }
  }
}
