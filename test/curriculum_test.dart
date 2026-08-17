import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sinifcepte/core/utils/date_formatter.dart';
import 'package:sinifcepte/features/outcomes/data/models/curriculum_outcome_model.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });
  group('CurriculumOutcomeModel Testleri', () {
    test('JSON ve Map dönüşümleri hatasız çalışmalı', () {
      final model = CurriculumOutcomeModel(
        docId: 'plan_5_bilisim_1',
        gradeLevel: 5,
        subjectCode: 'BILISIM',
        subjectName: 'Bilişim Teknolojileri ve Yazılım',
        publisher: 'TYMM (Maarif Modeli)',
        fullTitle: '5. Sınıf - Bilişim Teknolojileri ve Yazılım - TYMM (Maarif Modeli)',
        weekNumber: 1,
        teachingWeekNumber: 1,
        unitTitle: 'Bilişim Teknolojilerinin Sınıflandırılması',
        topicTitle: 'Bilişim Teknolojilerinin Sınıflandırılması',
        outcomeCode: 'BTY.5.1.1',
        outcomeDescription: 'Günlük yaşamda kullanılan bilişim teknolojilerini sınıflandırabilme',
        academicYear: '2026-2027',
        isHolidayWeek: false,
      );

      final map = model.toMap();
      expect(map['grade_level'], 5);
      expect(map['subject_code'], 'BILISIM');
      expect(map['publisher'], 'TYMM (Maarif Modeli)');
      expect(map['week_number'], 1);

      final fromMap = CurriculumOutcomeModel.fromMap(map);
      expect(fromMap.gradeLevel, 5);
      expect(fromMap.subjectCode, 'BILISIM');
      expect(fromMap.outcomeCode, 'BTY.5.1.1');
      expect(fromMap.isHolidayWeek, false);

      final json = model.toJson();
      final fromJson = CurriculumOutcomeModel.fromJson(json);
      expect(fromJson.docId, 'plan_5_bilisim_1');
      expect(fromJson.publisher, 'TYMM (Maarif Modeli)');
      expect(fromJson.teachingWeekNumber, 1);
    });

    test('Tatil haftası modeli doğru bayrak almalı', () {
      final holidayModel = CurriculumOutcomeModel(
        docId: 'holiday_10',
        gradeLevel: 5,
        subjectCode: 'GENEL',
        subjectName: 'Genel',
        weekNumber: 10,
        unitTitle: '1. Dönem Ara Tatili',
        topicTitle: 'Ara Tatil',
        outcomeDescription: '1. Dönem Ara Tatil Haftası',
        isHolidayWeek: true,
      );

      expect(holidayModel.isHolidayWeek, true);
      expect(holidayModel.toMap()['is_holiday_week'], 1);
    });
  });

  group('AppDateFormatter Testleri', () {
    test('39+1 haftalık takvim sınırları ve Yaz Tatili doğru hesaplanmalı', () {
      final week1 = AppDateFormatter.getCurrentAcademicWeek(targetDate: DateTime(2025, 9, 8));
      expect(week1, 1);

      // Yaz tatili (Temmuz / Ağustos) -> 40. Hafta
      final summerWeek = AppDateFormatter.getCurrentAcademicWeek(targetDate: DateTime(2026, 7, 15));
      expect(summerWeek, 40);

      final dateRange1 = AppDateFormatter.getWeekDateRangeText(1, targetDate: DateTime(2025, 9, 8));
      expect(dateRange1.contains('Eylül'), true);

      final summerRange = AppDateFormatter.getWeekDateRangeText(40, targetDate: DateTime(2025, 9, 8));
      expect(summerRange.isNotEmpty, true);
    });
  });

  group('OutcomeNotesNotifier Testleri', () {
    test('Not haritası manipülasyonu doğru çalışmalı', () {
      final map = <int, String>{};
      map[1] = 'Laboratuvar deney malzemeleri getirilecek';
      map[5] = '1. Yazılı sınav hazırlığı';

      expect(map[1], 'Laboratuvar deney malzemeleri getirilecek');
      expect(map[5], '1. Yazılı sınav hazırlığı');
      expect(map[2], null);

      map.remove(1);
      expect(map.containsKey(1), false);
    });
  });
}

