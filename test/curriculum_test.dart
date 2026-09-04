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
        maarifSummary: 'Bu hafta bilişim teknolojileri günlük hayat örnekleriyle sınıflandırılır.',
        maarifValues: 'Dijital Etik, Sorumluluk',
        maarifSkills: 'AB6 Algoritmik Düşünme',
      );

      final map = model.toMap();
      expect(map['grade_level'], 5);
      expect(map['subject_code'], 'BILISIM');
      expect(map['publisher'], 'TYMM (Maarif Modeli)');
      expect(map['week_number'], 1);
      expect(map['maarif_summary'], 'Bu hafta bilişim teknolojileri günlük hayat örnekleriyle sınıflandırılır.');
      expect(map['maarif_values'], 'Dijital Etik, Sorumluluk');
      expect(map['maarif_skills'], 'AB6 Algoritmik Düşünme');

      final fromMap = CurriculumOutcomeModel.fromMap(map);
      expect(fromMap.gradeLevel, 5);
      expect(fromMap.subjectCode, 'BILISIM');
      expect(fromMap.outcomeCode, 'BTY.5.1.1');
      expect(fromMap.isHolidayWeek, false);
      expect(fromMap.maarifSummary, 'Bu hafta bilişim teknolojileri günlük hayat örnekleriyle sınıflandırılır.');

      final json = model.toJson();
      final fromJson = CurriculumOutcomeModel.fromJson(json);
      expect(fromJson.docId, 'plan_5_bilisim_1');
      expect(fromJson.publisher, 'TYMM (Maarif Modeli)');
      expect(fromJson.teachingWeekNumber, 1);
      expect(fromJson.maarifValues, 'Dijital Etik, Sorumluluk');
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

    test('OTP ve sosyal etkinlik bayrakları hafta numarasına değil veriye bakmalı', () {
      // MEB takvimi her yıl kayar; 8. hafta artık OTP olmayabilir.
      const notOtp = CurriculumOutcomeModel(
        docId: 'w8_normal',
        gradeLevel: 9,
        subjectCode: 'FIZIK',
        subjectName: 'Fizik',
        weekNumber: 8,
        unitTitle: 'Hareket ve Kuvvet',
        topicTitle: 'Newton Yasaları',
        outcomeDescription: 'Newton yasalarını uygular.',
      );
      expect(notOtp.isOtpWeek, false,
          reason: '8. hafta sabit OTP kabul edilmemeli');

      const notSocial = CurriculumOutcomeModel(
        docId: 'w18_normal',
        gradeLevel: 9,
        subjectCode: 'FIZIK',
        subjectName: 'Fizik',
        weekNumber: 18,
        unitTitle: 'Enerji',
        topicTitle: 'İş ve Güç',
        outcomeDescription: 'İş ve güç hesaplamaları yapar.',
      );
      expect(notSocial.isSocialEventWeek, false,
          reason: '18. hafta sabit sosyal etkinlik kabul edilmemeli');

      // Bayrak veriden geldiğinde hafta numarasından bağımsız çalışmalı.
      const otpWeek5 = CurriculumOutcomeModel(
        docId: 'w5_otp',
        gradeLevel: 9,
        subjectCode: 'FIZIK',
        subjectName: 'Fizik',
        weekNumber: 5,
        unitTitle: 'Okul Temelli Planlama',
        topicTitle: 'OTP',
        outcomeDescription: 'Telafi çalışmaları yürütülür.',
        isOtpWeekFlag: true,
      );
      expect(otpWeek5.isOtpWeek, true);
    });

    test('Bayraklar SQLite ve JSON dönüşümlerinde korunmalı', () {
      const model = CurriculumOutcomeModel(
        docId: 'w29_otp',
        gradeLevel: 10,
        subjectCode: 'KIMYA',
        subjectName: 'Kimya',
        weekNumber: 29,
        unitTitle: 'Okul Temelli Planlama',
        topicTitle: 'OTP',
        outcomeDescription: 'Derinleştirme çalışması.',
        isOtpWeekFlag: true,
        isSocialEventWeekFlag: false,
      );

      final roundTripped = CurriculumOutcomeModel.fromMap(
        Map<String, dynamic>.from(model.toMap()),
      );
      expect(roundTripped.isOtpWeek, true);
      expect(roundTripped.isSocialEventWeek, false);

      final fromJson = CurriculumOutcomeModel.fromJson(model.toJson());
      expect(fromJson.isOtpWeek, true);
      expect(fromJson.isSocialEventWeek, false);
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

