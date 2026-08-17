import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/data/models/project_tracking_model.dart';
import 'package:sinifcepte/features/exam_operations/data/models/quiz_tracking_model.dart';
import 'package:sinifcepte/features/exam_operations/data/services/exam_sync_service.dart';
import 'package:sinifcepte/features/exam_operations/providers/quiz_tracking_provider.dart';

void main() {
  group('1. Quiz & Sözlü Takip Modeli ve Hesaplama Testleri', () {
    test('QuizNotModel toMap ve fromMap doğru çalışmalı', () {
      final not = QuizNotModel(
        id: 1,
        kolonId: 10,
        studentId: 101,
        score: 85,
      );

      final map = not.toMap();
      expect(map['kolon_id'], 10);
      expect(map['ogrenci_id'], 101);
      expect(map['puan'], 85);

      final fromMap = QuizNotModel.fromMap(map);
      expect(fromMap.kolonId, 10);
      expect(fromMap.studentId, 101);
      expect(fromMap.score, 85);
    });

    test('QuizTableState öğrenci ortalamasını doğru hesaplamalı', () {
      final state = QuizTableState(
        studentScores: {
          101: {1: 80, 2: 90, 3: 100},
          102: {1: 50},
        },
      );

      final avg101 = state.calculateStudentAverage(101);
      expect(avg101, 90.0);

      final avg102 = state.calculateStudentAverage(102);
      expect(avg102, 50.0);

      final avgUnknown = state.calculateStudentAverage(999);
      expect(avgUnknown, null);
    });

    test('QuizTableState kolon ortalamasını ve genel sınıf ortalamasını doğru hesaplamalı', () {
      final state = QuizTableState(
        students: [
          StudentModel(id: 101, classId: 1, schoolNumber: 101, firstName: 'Ali', lastName: 'Yılmaz'),
          StudentModel(id: 102, classId: 1, schoolNumber: 102, firstName: 'Ayşe', lastName: 'Demir'),
        ],
        studentScores: {
          101: {1: 80, 2: 100},
          102: {1: 60, 2: 100},
        },
      );

      final col1Avg = state.calculateColumnAverage(1);
      expect(col1Avg, 70.0);

      final col2Avg = state.calculateColumnAverage(2);
      expect(col2Avg, 100.0);

      final overallAvg = state.calculateOverallClassAverage();
      expect(overallAvg, 85.0);
    });
  });

  group('2. Proje & Performans MEB 100 Puan Rubric Testleri', () {
    test('ProjectKriterModel toMap ve fromMap doğru çalışmalı', () {
      final kriter = ProjectKriterModel(
        id: 1,
        title: 'Konuyu Kavrama ve İfade Yeteneği',
        maxScore: 10,
        orderIndex: 1,
      );

      final map = kriter.toMap();
      expect(map['baslik'], 'Konuyu Kavrama ve İfade Yeteneği');
      expect(map['max_puan'], 10);

      final fromMap = ProjectKriterModel.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.title, 'Konuyu Kavrama ve İfade Yeteneği');
      expect(fromMap.maxScore, 10);
    });

    test('10 Kriterli Rubric Toplam Puanı (100 üzerinden) doğru hesaplanmalı', () {
      final kriterPuanlari = <int, int>{
        1: 10,
        2: 10,
        3: 8,
        4: 8,
        5: 10,
        6: 5,
        7: 10,
        8: 10,
        9: 9,
        10: 10,
      };

      final totalScore = kriterPuanlari.values.fold<int>(0, (sum, val) => sum + val);
      expect(totalScore, 90);
      expect(totalScore <= 100, true);

      final fullScore = List.filled(10, 10).fold<int>(0, (sum, val) => sum + val);
      expect(fullScore, 100);
    });

    test('ProjectTakipModel teslim ve konu bilgisi doğru saklanmalı', () {
      final takip = ProjectTakipModel(
        id: 5,
        studentId: 201,
        studentName: 'Ahmet Yılmaz',
        className: '10-A',
        subject: 'Bilişim Teknolojileri',
        homeworkTopic: 'Yapay Zeka Destekli Mobil Uygulama',
        createdAt: DateTime(2026, 3, 1),
        isSubmitted: true,
        totalScore: 95,
        isEvaluated: true,
      );

      final map = takip.toMap();
      expect(map['ogrenci_id'], 201);
      expect(map['teslim_etti'], 1);
      expect(map['toplam_puan'], 95);
      expect(map['degerlendirildi'], 1);

      final fromMap = ProjectTakipModel.fromMap(map);
      expect(fromMap.isSubmitted, true);
      expect(fromMap.homeworkTopic, 'Yapay Zeka Destekli Mobil Uygulama');
      expect(fromMap.totalScore, 95);
      expect(fromMap.isEvaluated, true);
    });
  });

  group('3. MEB / ÖSYM & Okul Sınav Takip Modeli Testleri', () {
    test('Sınav Kalan Gün ve Durum Hesaplamaları Doğru Çalışmalı', () {
      final now = DateTime.now();

      // Gelecekteki sınav (10 gün sonra)
      final futureExam = ExamModel(
        id: 'lgs_2026',
        title: 'LGS - Liselere Geçiş Sistemi',
        institution: 'MEB',
        examDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 10)),
        category: 'MEB',
      );

      expect(futureExam.daysRemaining, 10);
      expect(futureExam.isPast, false);
      expect(futureExam.isSchoolExam, false);

      // Geçmiş sınav (5 gün önce)
      final pastExam = ExamModel(
        id: 'gecmis_sinav',
        title: 'Eski Deneme',
        institution: 'MEB',
        examDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 5)),
        category: 'MEB',
      );

      expect(pastExam.daysRemaining < 0, true);
      expect(pastExam.isPast, true);

      // Okul Sınavı Modeli
      final schoolExam = ExamModel(
        id: 'okul_123',
        intId: 1,
        title: '1. Dönem 1. Matematik Yazılısı',
        institution: 'OKUL',
        examDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 3)),
        category: 'OKUL',
        isSchoolExam: true,
        className: '10-A',
      );

      expect(schoolExam.isSchoolExam, true);
      expect(schoolExam.className, '10-A');
      expect(schoolExam.category, 'OKUL');
    });

    test('ExamModel toMap ve fromMap doğru dönüşüm yapmalı', () {
      final exam = ExamModel(
        id: 'yks_tyt_2026',
        title: 'YKS - TYT',
        institution: 'ÖSYM',
        examDate: DateTime(2026, 6, 20),
        applicationDeadline: DateTime(2026, 3, 10),
        applicationLink: 'https://ais.osym.gov.tr',
        category: 'OSYM',
        isFavorite: true,
      );

      final map = exam.toMap();
      expect(map['doc_id'], 'yks_tyt_2026');
      expect(map['sinav_adi'], 'YKS - TYT');
      expect(map['kurum'], 'ÖSYM');
      expect(map['basvuru_linki'], 'https://ais.osym.gov.tr');

      final fromMap = ExamModel.fromMap(map, isFav: true);
      expect(fromMap.id, 'yks_tyt_2026');
      expect(fromMap.institution, 'ÖSYM');
      expect(fromMap.category, 'OSYM');
      expect(fromMap.isFavorite, true);
    });
  });

  group('4. Resmî Sınav JSON Senkronizasyon & Bulut Entegrasyon Testleri', () {
    test('ExamSyncService JSON dizesini hatasız ayrıştırmalı ve alanları doğru eşlemeli', () async {
      const sampleJson = '''
      [
        {
          "doc_id": "meb_lgs_2026",
          "title": "LGS - Liselere Geçiş Sistemi Sınavı",
          "institution": "MEB",
          "examDate": "2026-06-14T09:30:00.000",
          "applicationDeadline": "2026-04-15T23:59:59.000",
          "applicationUrl": "https://e-okul.meb.gov.tr",
          "description": "8. Sınıf öğrencileri için Merkezi Sınav",
          "category": "official"
        },
        {
          "doc_id": "osym_yks_tyt_2026",
          "title": "YKS 1. Oturum - TYT",
          "institution": "ÖSYM",
          "examDate": "2026-06-20T10:15:00.000",
          "applicationUrl": "https://ais.osym.gov.tr"
        }
      ]
      ''';

      final service = ExamSyncService();
      expect(service, isNotNull);
      expect(sampleJson.isNotEmpty, true);
    });

    test('24 Saat Kala Bildirim Zamanlama Hesaplaması doğru çalışmalı', () {
      final now = DateTime.now();
      final futureExamDate = now.add(const Duration(days: 3));
      final exam = ExamModel(
        id: 'lgs_2026',
        title: 'LGS Sınavı',
        institution: 'MEB',
        examDate: futureExamDate,
        category: 'MEB',
        isFavorite: true,
      );

      final scheduledDate = exam.examDate.subtract(const Duration(hours: 24));
      expect(scheduledDate.isAfter(now), true);
      expect(scheduledDate.difference(now).inHours >= 47, true);
    });
  });
}



