import 'dart:convert';
import 'dart:math';
import '../../../../core/utils/input_sanitizer.dart';

/// Sınavda bir öğrencinin aldığı soru puanları ve toplam notu
class StudentExamScore {
  final int? studentId;
  final String studentName;
  final int studentNumber;
  final List<double> questionScores;
  final double totalScore;
  final bool isAbsent;

  const StudentExamScore({
    this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.questionScores,
    required this.totalScore,
    this.isAbsent = false,
  });

  StudentExamScore copyWith({
    int? studentId,
    String? studentName,
    int? studentNumber,
    List<double>? questionScores,
    double? totalScore,
    bool? isAbsent,
  }) {
    return StudentExamScore(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumber: studentNumber ?? this.studentNumber,
      questionScores: questionScores ?? this.questionScores,
      totalScore: totalScore ?? this.totalScore,
      isAbsent: isAbsent ?? this.isAbsent,
    );
  }

  /// Sinava girmeyen ogrenci icin diske yazilan isaret degeri.
  ///
  /// Ayri bir `girmedi` sutunu eklemek yerine negatif puan kullaniliyor:
  /// `fromMap` zaten `total < 0` kosulunu okuyordu, sema degisikligi
  /// gerektirmiyor ve gecerli puanlar hicbir zaman negatif olamaz.
  static const double absentMarker = -1.0;

  Map<String, dynamic> toMap({required int sinavId}) {
    // Girmeyen ogrenci 0 olarak yazilirsa GERCEK bir 0 gibi geri okunur ve
    // ortalamayi, basari yuzdesini, sapmayi bozar. Negatif isaretle yazilir.
    final double kayitliPuan = isAbsent ? absentMarker : totalScore;

    return {
      'sinav_id': sinavId,
      'ogrenci_id': studentId,
      'ogrenci_ad_soyad': studentName,
      'notu': kayitliPuan.round(),
      'toplam_not': kayitliPuan,
      'soru_bazli_notlar': jsonEncode(questionScores),
    };
  }

  factory StudentExamScore.fromMap(Map<String, dynamic> map) {
    List<double> qScores = [];
    final rawScores = map['soru_bazli_notlar'];
    if (rawScores != null && rawScores is String && rawScores.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawScores);
        if (decoded is List) {
          qScores = decoded.map((e) => (e as num).toDouble()).toList();
        }
      } catch (_) {
        // Fallback for space separated strings
        qScores = InputSanitizer.parseSpaceSeparatedScores(rawScores);
      }
    }

    final double total = (map['toplam_not'] as num?)?.toDouble() ??
        (map['notu'] as num?)?.toDouble() ??
        (qScores.isNotEmpty ? qScores.fold<double>(0.0, (double a, double b) => a + b) : 0.0);

    final bool girmedi = total < 0;

    return StudentExamScore(
      studentId: map['ogrenci_id'] as int?,
      studentName: map['ogrenci_ad_soyad'] as String? ?? 'İsimsiz Öğrenci',
      studentNumber: (map['numara'] ?? map['school_number'] ?? map['student_number'] ?? 0) as int,
      questionScores: qScores,
      // Isaret degeri disariya sizmasin: girmeyen ogrencinin puani 0
      // gorunur ama `isAbsent` sayesinde hicbir istatistige katilmaz.
      totalScore: girmedi ? 0.0 : total,
      isAbsent: girmedi,
    );
  }
}

/// SınıfCepte - Sınav Analizi Ana Modeli (Soru Bazlı & Klasik)
class ExamAnalysisModel {
  final int? id;
  final String examTitle; // Örn: 1. Dönem 1. Yazılı
  final String className; // Örn: 10-A
  final String subjectName; // Örn: Matematik
  final String examDate; // Örn: 2025-11-15
  final String examType; // 'soru_bazli' veya 'klasik'
  final List<double> questionMaxScores; // Örn: [10, 10, 15, 15, 25, 25] -> Toplam 100
  final List<String> questionDescriptions; // Örn: ["Kazanım 1", "Kazanım 2", ...]
  final List<StudentExamScore> studentScores;

  const ExamAnalysisModel({
    this.id,
    required this.examTitle,
    required this.className,
    required this.subjectName,
    required this.examDate,
    this.examType = 'soru_bazli',
    required this.questionMaxScores,
    this.questionDescriptions = const [],
    required this.studentScores,
  });

  bool get isQuestionBased => examType == 'soru_bazli';

  int get questionCount => questionMaxScores.isNotEmpty ? questionMaxScores.length : 0;

  int get studentCount => studentScores.where((s) => !s.isAbsent).length;

  bool get isValidTotalHundred {
    return InputSanitizer.validateTotalHundred(questionMaxScores);
  }

  double get maxPossibleScore {
    if (questionMaxScores.isEmpty) return 100.0;
    return questionMaxScores.fold(0.0, (sum, score) => sum + score);
  }

  /// Sınıfın Genel Not Ortalaması
  double get classAverage {
    final activeStudents = studentScores.where((s) => !s.isAbsent).toList();
    if (activeStudents.isEmpty) return 0.0;
    final totalSum = activeStudents.fold(0.0, (sum, s) => sum + s.totalScore);
    return totalSum / activeStudents.length;
  }

  /// En Yüksek Puan
  double get highestScore {
    final activeStudents = studentScores.where((s) => !s.isAbsent).toList();
    if (activeStudents.isEmpty) return 0.0;
    return activeStudents.map((s) => s.totalScore).reduce(max);
  }

  /// En Düşük Puan
  double get lowestScore {
    final activeStudents = studentScores.where((s) => !s.isAbsent).toList();
    if (activeStudents.isEmpty) return 0.0;
    return activeStudents.map((s) => s.totalScore).reduce(min);
  }

  /// Medyan (Ortanca Değer)
  double get medianScore {
    final active = studentScores.where((s) => !s.isAbsent).map((s) => s.totalScore).toList()..sort();
    if (active.isEmpty) return 0.0;
    final middle = active.length ~/ 2;
    if (active.length % 2 == 1) {
      return active[middle];
    } else {
      return (active[middle - 1] + active[middle]) / 2.0;
    }
  }

  /// Standart Sapma
  double get standardDeviation {
    final active = studentScores.where((s) => !s.isAbsent).toList();
    if (active.length <= 1) return 0.0;
    final avg = classAverage;
    final sumSquaredDiff = active.fold(0.0, (sum, s) => sum + pow(s.totalScore - avg, 2));
    return sqrt(sumSquaredDiff / (active.length - 1));
  }

  /// Başarı Yüzdesi (50 ve Üzeri Alanların Oranı)
  double get passRate {
    final active = studentScores.where((s) => !s.isAbsent).toList();
    if (active.isEmpty) return 0.0;
    final passedCount = active.where((s) => s.totalScore >= 50.0).length;
    return (passedCount / active.length) * 100.0;
  }

  /// Soru Bazında Sınıf Başarı Oranları (%)
  /// Örn: {0: 85.0, 1: 62.5, 2: 40.0 ...}
  Map<int, double> get questionSuccessRates {
    if (!isQuestionBased || questionMaxScores.isEmpty) return {};
    final activeStudents = studentScores.where((s) => !s.isAbsent).toList();
    if (activeStudents.isEmpty) return {};

    final Map<int, double> rates = {};

    for (int i = 0; i < questionMaxScores.length; i++) {
      final maxPuan = questionMaxScores[i];
      if (maxPuan <= 0) {
        rates[i] = 0.0;
        continue;
      }

      double totalEarned = 0.0;
      for (final student in activeStudents) {
        if (i < student.questionScores.length) {
          totalEarned += student.questionScores[i];
        }
      }

      final maxPossibleEarned = maxPuan * activeStudents.length;
      final percentage = maxPossibleEarned > 0 ? (totalEarned / maxPossibleEarned) * 100.0 : 0.0;
      rates[i] = percentage.clamp(0.0, 100.0);
    }

    return rates;
  }

  /// Soru Bazında Sınıf Ortalama Puanları
  Map<int, double> get questionAverages {
    if (!isQuestionBased || questionMaxScores.isEmpty) return {};
    final activeStudents = studentScores.where((s) => !s.isAbsent).toList();
    if (activeStudents.isEmpty) return {};

    final Map<int, double> avgs = {};

    for (int i = 0; i < questionMaxScores.length; i++) {
      double totalEarned = 0.0;
      for (final student in activeStudents) {
        if (i < student.questionScores.length) {
          totalEarned += student.questionScores[i];
        }
      }
      avgs[i] = totalEarned / activeStudents.length;
    }

    return avgs;
  }

  /// Not Dağılım Aralıkları (0-49, 50-69, 70-84, 85-100)
  Map<String, int> get gradeDistribution {
    final dist = {
      '0-49 (Geçersiz)': 0,
      '50-69 (Orta)': 0,
      '70-84 (İyi)': 0,
      '85-100 (Pekiyi)': 0,
    };

    for (final student in studentScores) {
      if (student.isAbsent) continue;
      final score = student.totalScore;
      if (score >= 85) {
        dist['85-100 (Pekiyi)'] = (dist['85-100 (Pekiyi)'] ?? 0) + 1;
      } else if (score >= 70) {
        dist['70-84 (İyi)'] = (dist['70-84 (İyi)'] ?? 0) + 1;
      } else if (score >= 50) {
        dist['50-69 (Orta)'] = (dist['50-69 (Orta)'] ?? 0) + 1;
      } else {
        dist['0-49 (Geçersiz)'] = (dist['0-49 (Geçersiz)'] ?? 0) + 1;
      }
    }

    return dist;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sinav_adi': examTitle,
      'sinif': className,
      'ders': subjectName,
      'tarih': examDate,
      'ortalama': classAverage,
      'not_sayisi': studentCount,
      'sinav_tipi': examType,
      'soru_sayisi': questionCount,
      'soru_puanlari': jsonEncode(questionMaxScores),
    };
  }

  factory ExamAnalysisModel.fromMap(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> studentRows,
  ) {
    List<double> maxScores = [];
    final rawScores = map['soru_puanlari'];
    if (rawScores != null && rawScores is String && rawScores.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawScores);
        if (decoded is List) {
          maxScores = decoded.map((e) => (e as num).toDouble()).toList();
        }
      } catch (_) {
        maxScores = InputSanitizer.parseSpaceSeparatedScores(rawScores);
      }
    }

    final students = studentRows.map((r) => StudentExamScore.fromMap(r)).toList()
      ..sort((a, b) => a.studentNumber.compareTo(b.studentNumber));

    return ExamAnalysisModel(
      id: map['id'] as int?,
      examTitle: map['sinav_adi'] as String? ?? 'Sınav',
      className: map['sinif'] as String? ?? '',
      subjectName: map['ders'] as String? ?? '',
      examDate: map['tarih'] as String? ?? '',
      examType: map['sinav_tipi'] as String? ?? 'soru_bazli',
      questionMaxScores: maxScores,
      studentScores: students,
    );
  }

  ExamAnalysisModel copyWith({
    int? id,
    String? examTitle,
    String? className,
    String? subjectName,
    String? examDate,
    String? examType,
    List<double>? questionMaxScores,
    List<String>? questionDescriptions,
    List<StudentExamScore>? studentScores,
  }) {
    return ExamAnalysisModel(
      id: id ?? this.id,
      examTitle: examTitle ?? this.examTitle,
      className: className ?? this.className,
      subjectName: subjectName ?? this.subjectName,
      examDate: examDate ?? this.examDate,
      examType: examType ?? this.examType,
      questionMaxScores: questionMaxScores ?? this.questionMaxScores,
      questionDescriptions: questionDescriptions ?? this.questionDescriptions,
      studentScores: studentScores ?? this.studentScores,
    );
  }
}
