import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/analytics/data/models/exam_analysis_model.dart';
import 'package:sinifcepte/core/utils/input_sanitizer.dart';

void main() {
  group('Soru Bazlı Sınav Analizi Modeli ve İstatistik Testleri', () {
    test('InputSanitizer boşluk, virgül veya noktalı virgülle ayrılmış soru puanlarını doğru ayrıştırmalı ve toplamını doğrulamalı', () {
      final scores = InputSanitizer.parseSpaceSeparatedScores('10 15 25 20 15 15');
      expect(scores, [10.0, 15.0, 25.0, 20.0, 15.0, 15.0]);
      expect(InputSanitizer.validateTotalHundred(scores), isTrue);

      // Virgül ve noktalı virgüllü giriş testi
      final commaScores = InputSanitizer.parseSpaceSeparatedScores('10, 15, 25, 20, 15, 15');
      expect(commaScores, [10.0, 15.0, 25.0, 20.0, 15.0, 15.0]);
      expect(InputSanitizer.validateTotalHundred(commaScores), isTrue);

      final semiColonScores = InputSanitizer.parseSpaceSeparatedScores('10; 15; 25; 20; 15; 15');
      expect(semiColonScores, [10.0, 15.0, 25.0, 20.0, 15.0, 15.0]);

      final invalidScores = InputSanitizer.parseSpaceSeparatedScores('10 20 30');
      expect(InputSanitizer.validateTotalHundred(invalidScores), isFalse);
    });

    test('ExamAnalysisModel ortalama, en yüksek, en düşük ve başarı oranını doğru hesaplamalı', () {
      final exam = ExamAnalysisModel(
        id: 1,
        examTitle: '1. Dönem 1. Yazılı',
        className: '10-A',
        subjectName: 'Matematik',
        examDate: '2025-11-15',
        examType: 'soru_bazli',
        questionMaxScores: [20.0, 20.0, 20.0, 20.0, 20.0],
        studentScores: [
          const StudentExamScore(
            studentId: 1,
            studentName: 'Ali Yılmaz',
            studentNumber: 101,
            questionScores: [20.0, 20.0, 20.0, 20.0, 20.0],
            totalScore: 100.0,
          ),
          const StudentExamScore(
            studentId: 2,
            studentName: 'Ayşe Demir',
            studentNumber: 102,
            questionScores: [10.0, 10.0, 10.0, 10.0, 10.0],
            totalScore: 50.0,
          ),
          const StudentExamScore(
            studentId: 3,
            studentName: 'Mehmet Kaya',
            studentNumber: 103,
            questionScores: [0.0, 10.0, 10.0, 0.0, 10.0],
            totalScore: 30.0,
          ),
        ],
      );

      expect(exam.studentCount, 3);
      expect(exam.questionCount, 5);
      expect(exam.isValidTotalHundred, isTrue);

      // Sınıf ortalaması: (100 + 50 + 30) / 3 = 60.0
      expect(exam.classAverage, closeTo(60.0, 0.01));
      expect(exam.highestScore, 100.0);
      expect(exam.lowestScore, 30.0);
      expect(exam.medianScore, 50.0);

      // Başarı oranı (>=50 puan alan 2/3 kişi): %66.66
      expect(exam.passRate, closeTo(66.66, 0.1));
    });

    test('ExamAnalysisModel soru bazında başarı oranlarını ve ortalamalarını doğru hesaplamalı', () {
      final exam = ExamAnalysisModel(
        examTitle: 'Bilişim Sınavı',
        className: '11-B',
        subjectName: 'Bilişim Teknolojileri',
        examDate: '2025-11-20',
        questionMaxScores: [50.0, 50.0],
        studentScores: [
          const StudentExamScore(
            studentName: 'Öğrenci 1',
            studentNumber: 1,
            questionScores: [50.0, 25.0],
            totalScore: 75.0,
          ),
          const StudentExamScore(
            studentName: 'Öğrenci 2',
            studentNumber: 2,
            questionScores: [50.0, 0.0],
            totalScore: 50.0,
          ),
        ],
      );

      final qRates = exam.questionSuccessRates;
      // S1: (50 + 50) / 100 = %100
      expect(qRates[0], 100.0);
      // S2: (25 + 0) / 100 = %25
      expect(qRates[1], 25.0);

      final qAvgs = exam.questionAverages;
      expect(qAvgs[0], 50.0);
      expect(qAvgs[1], 12.5);
    });

    test('ExamAnalysisModel not dağılım histogramını doğru gruplamalı', () {
      final exam = ExamAnalysisModel(
        examTitle: 'Tarih Sınavı',
        className: '9-C',
        subjectName: 'Tarih',
        examDate: '2025-11-22',
        questionMaxScores: [100.0],
        studentScores: [
          const StudentExamScore(studentName: 'A', studentNumber: 1, questionScores: [95], totalScore: 95),
          const StudentExamScore(studentName: 'B', studentNumber: 2, questionScores: [88], totalScore: 88),
          const StudentExamScore(studentName: 'C', studentNumber: 3, questionScores: [75], totalScore: 75),
          const StudentExamScore(studentName: 'D', studentNumber: 4, questionScores: [60], totalScore: 60),
          const StudentExamScore(studentName: 'E', studentNumber: 5, questionScores: [40], totalScore: 40),
        ],
      );

      final dist = exam.gradeDistribution;
      expect(dist['85-100 (Pekiyi)'], 2);
      expect(dist['70-84 (İyi)'], 1);
      expect(dist['50-69 (Orta)'], 1);
      expect(dist['0-49 (Geçersiz)'], 1);
    });
  });
}
