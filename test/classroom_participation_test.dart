import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/attendance/data/models/classroom_participation_model.dart';
import 'package:sinifcepte/features/attendance/utils/participation_whatsapp_helper.dart';
import 'package:sinifcepte/features/analytics/providers/smart_comment_generator_provider.dart';

void main() {
  group('1. Ders İçi Katılım & Ödev Modelleri ve İstatistik Testleri', () {
    test('Enum fromCode dönüşümleri doğru çalışmalı', () {
      expect(HomeworkStatus.fromCode('yapti'), HomeworkStatus.done);
      expect(HomeworkStatus.fromCode('eksik'), HomeworkStatus.partial);
      expect(HomeworkStatus.fromCode('yapmadi'), HomeworkStatus.none);
      expect(HomeworkStatus.fromCode('verilmedi'), HomeworkStatus.notGiven);

      expect(MaterialsStatus.fromCode('tam'), MaterialsStatus.ready);
      expect(MaterialsStatus.fromCode('eksik'), MaterialsStatus.missing);

      expect(ArrivalStatus.fromCode('zamaninda'), ArrivalStatus.onTime);
      expect(ArrivalStatus.fromCode('gec'), ArrivalStatus.late);
    });

    test('StudentParticipationEvaluation toMap ve fromMap doğru dönüşüm yapmalı', () {
      const eval = StudentParticipationEvaluation(
        studentId: 101,
        studentName: 'Ahmet Yılmaz',
        studentNumber: 15,
        homeworkStatus: HomeworkStatus.done,
        materialsStatus: MaterialsStatus.ready,
        arrivalStatus: ArrivalStatus.onTime,
        starsCount: 3,
        customTags: ['Soru Çözdü', 'Örnek Davranış'],
        note: 'Çok iyiydi',
      );

      final map = eval.toMap(1);
      expect(map['session_id'], 1);
      expect(map['student_id'], 101);
      expect(map['homework_status'], 'yapti');
      expect(map['materials_status'], 'tam');
      expect(map['stars_count'], 3);
      expect(map['score'], 30);

      final fromMap = StudentParticipationEvaluation.fromMap(
        map,
        studentNameFallback: 'Ahmet Yılmaz',
        studentNumberFallback: 15,
      );
      expect(fromMap.studentId, 101);
      expect(fromMap.studentName, 'Ahmet Yılmaz');
      expect(fromMap.studentNumber, 15);
      expect(fromMap.starsCount, 3);
      expect(fromMap.customTags.contains('Soru Çözdü'), isTrue);
    });

    test('ClassroomParticipationSession KPI oranlarını ve özetlerini doğru hesaplamalı', () {
      final session = ClassroomParticipationSession(
        id: 1,
        classId: 10,
        className: '10-A',
        date: '2026-08-15',
        lessonHour: 3,
        subjectName: 'Matematik',
        topicName: 'Fonksiyonlar',
        evaluations: const [
          StudentParticipationEvaluation(
            studentId: 1,
            studentName: 'Öğrenci 1',
            studentNumber: 101,
            homeworkStatus: HomeworkStatus.done,
            materialsStatus: MaterialsStatus.ready,
            starsCount: 2,
          ),
          StudentParticipationEvaluation(
            studentId: 2,
            studentName: 'Öğrenci 2',
            studentNumber: 102,
            homeworkStatus: HomeworkStatus.partial,
            materialsStatus: MaterialsStatus.ready,
            starsCount: 1,
          ),
          StudentParticipationEvaluation(
            studentId: 3,
            studentName: 'Öğrenci 3',
            studentNumber: 103,
            homeworkStatus: HomeworkStatus.none,
            materialsStatus: MaterialsStatus.missing,
            starsCount: 0,
          ),
        ],
      );

      expect(session.totalStudents, 3);
      expect(session.homeworkDoneCount, 1);
      expect(session.homeworkPartialCount, 1);
      expect(session.homeworkNoneCount, 1);

      // Ödev Tamamlama: (1*1.0 + 1*0.5 + 0) / 3 = 1.5 / 3 = %50.0
      expect(session.homeworkCompletionRate, closeTo(50.0, 0.01));

      // Araç Gereç: 2 / 3 = %66.66
      expect(session.materialsReadinessRate, closeTo(66.66, 0.1));

      // Yıldızlar: 2 + 1 + 0 = 3
      expect(session.totalStarsAwarded, 3);
      expect(session.starStudentNames.length, 2);
      expect(session.needsHomeworkStudentNames.length, 1);
    });

    test('StudentParticipationSummaryStats kümülatif başarı oranlarını hesaplamalı', () {
      const stats = StudentParticipationSummaryStats(
        studentId: 101,
        studentName: 'Mehmet Kaya',
        studentNumber: 42,
        totalSessions: 10,
        homeworkDoneCount: 8,
        homeworkPartialCount: 2,
        homeworkNoneCount: 0,
        materialsReadyCount: 10,
        totalStars: 15,
      );

      // Ödev oranı: (8 + 1) / 10 = %90.0
      expect(stats.homeworkCompletionRate, closeTo(90.0, 0.01));
      expect(stats.materialsRate, 100.0);
    });
  });

  group('2. WhatsApp ve Akıllı Karne Görüşü Entegrasyon Testleri', () {
    test('ParticipationWhatsAppHelper sınıf özeti metnini doğru formatlamalı', () {
      final session = ClassroomParticipationSession(
        classId: 1,
        className: '10-A',
        date: '2026-08-15',
        lessonHour: 2,
        subjectName: 'Fizik',
        topicName: 'Vektörler',
        evaluations: const [
          StudentParticipationEvaluation(
            studentId: 1,
            studentName: 'Ali Yılmaz',
            studentNumber: 101,
            homeworkStatus: HomeworkStatus.done,
            starsCount: 2,
          ),
        ],
      );

      final msg = ParticipationWhatsAppHelper.generateDailyClassSummary(
        session: session,
        teacherName: 'Ahmet Öğretmen',
        schoolName: 'Atatürk Anadolu Lisesi',
      );

      expect(msg.contains('10-A - DERS GÜNLÜĞÜ'), isTrue);
      expect(msg.contains('Atatürk Anadolu Lisesi'), isTrue);
      expect(msg.contains('Vektörler'), isTrue);
      expect(msg.contains('Ali Yılmaz (2 ⭐)'), isTrue);
    });

    test('ParticipationWhatsAppHelper bireysel veli mesajını doğru formatlamalı', () {
      const eval = StudentParticipationEvaluation(
        studentId: 1,
        studentName: 'Zeynep Çelik',
        studentNumber: 105,
        homeworkStatus: HomeworkStatus.done,
        starsCount: 3,
        customTags: ['Örnek Davranış'],
      );

      final msg = ParticipationWhatsAppHelper.generateIndividualStudentMessage(
        eval: eval,
        subjectName: 'Matematik',
        date: '2026-08-15',
        teacherName: 'Mustafa Öğretmen',
      );

      expect(msg.contains('Zeynep Çelik'), isTrue);
      expect(msg.contains('3 Başarı Yıldızı'), isTrue);
      expect(msg.contains('Ev ödevini eksiksiz'), isTrue);
      expect(msg.contains('Örnek Davranış'), isTrue);
    });

    test('SmartCommentGenerator katılım verilerine göre zenginleştirilmiş karne görüşü üretmeli', () {
      final generator = SmartCommentGenerator();
      final comment = generator.generateReportCardComment(
        studentName: 'Ali',
        averageGrade: 92.0,
        positiveStarsCount: 8,
        homeworkCompletionRate: 95.0,
      );

      expect(comment.isNotEmpty, isTrue);
      expect(comment.contains('örnek') || comment.contains('tebrik') || comment.contains('gayret'), isTrue);
    });
  });
}
