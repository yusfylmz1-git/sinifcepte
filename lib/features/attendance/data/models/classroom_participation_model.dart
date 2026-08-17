import 'dart:convert';

/// SınıfCepte - Ödev Değerlendirme Durumu
enum HomeworkStatus {
  done('yapti', 'Yaptı', '✓'),
  partial('eksik', 'Eksik', '±'),
  none('yapmadi', 'Yapmadı', '✗'),
  notGiven('verilmedi', 'Verilmedi', '-');

  final String code;
  final String label;
  final String symbol;

  const HomeworkStatus(this.code, this.label, this.symbol);

  static HomeworkStatus fromCode(String? code) {
    return HomeworkStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => HomeworkStatus.done,
    );
  }
}

/// SınıfCepte - Araç-Gereç (Kitap/Defter) Durumu
enum MaterialsStatus {
  ready('tam', 'Tam', '📚'),
  missing('eksik', 'Eksik', '❌');

  final String code;
  final String label;
  final String symbol;

  const MaterialsStatus(this.code, this.label, this.symbol);

  static MaterialsStatus fromCode(String? code) {
    return MaterialsStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => MaterialsStatus.ready,
    );
  }
}

/// SınıfCepte - Derse Giriş / Zamanlama Durumu (Yoklama Değildir)
enum ArrivalStatus {
  onTime('zamaninda', 'Zamanında', '⏰'),
  late('gec', 'Geç Geldi', '⌛'),
  excused('izinli', 'İzinli/Raporlu', '📝');

  final String code;
  final String label;
  final String symbol;

  const ArrivalStatus(this.code, this.label, this.symbol);

  static ArrivalStatus fromCode(String? code) {
    return ArrivalStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ArrivalStatus.onTime,
    );
  }
}

/// SınıfCepte - Tekil Öğrenci Ders İçi Değerlendirme Modeli
class StudentParticipationEvaluation {
  final int studentId;
  final String studentName;
  final int studentNumber;
  final String gender; // 'Erkek', 'Kız'
  final HomeworkStatus homeworkStatus;
  final MaterialsStatus materialsStatus;
  final ArrivalStatus arrivalStatus;
  final int starsCount; // 3: Çok İyi, 2: İyi, 1: Geliştirilmeli, 0: Değerlendirilmedi
  final List<String> customTags; // Örn: ["Soru Çözdü", "Örnek Davranış", "Odaklanamadı"]
  final String? note;

  const StudentParticipationEvaluation({
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    this.gender = 'Erkek',
    this.homeworkStatus = HomeworkStatus.done,
    this.materialsStatus = MaterialsStatus.ready,
    this.arrivalStatus = ArrivalStatus.onTime,
    this.starsCount = 0,
    this.customTags = const [],
    this.note,
  });

  bool get isFemale =>
      gender.toLowerCase().contains('kız') ||
      gender.toLowerCase().contains('kadin') ||
      gender.toLowerCase().contains('female');

  /// Örn: "Ahmet Yılmaz" -> "Ahmet Y."
  String get shortName {
    final trimmed = studentName.trim();
    if (trimmed.isEmpty) return 'Öğrenci';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final firstPart = parts.sublist(0, parts.length - 1).join(' ');
      final lastInitial = parts.last.isNotEmpty ? '${parts.last[0].toUpperCase()}.' : '';
      return '$firstPart $lastInitial'.trim();
    }
    return trimmed;
  }

  /// Net 3 Yıldız Seviye Metni
  String get starLabel {
    switch (starsCount) {
      case 3:
        return 'Çok İyi';
      case 2:
        return 'İyi';
      case 1:
        return 'Geliştirilmeli';
      default:
        return 'Değerlendirilmedi';
    }
  }

  /// Yıldız Emoji Karşılığı
  String get starEmoji {
    switch (starsCount) {
      case 3:
        return '⭐⭐⭐';
      case 2:
        return '⭐⭐';
      case 1:
        return '⭐';
      default:
        return '-';
    }
  }

  StudentParticipationEvaluation copyWith({
    int? studentId,
    String? studentName,
    int? studentNumber,
    String? gender,
    HomeworkStatus? homeworkStatus,
    MaterialsStatus? materialsStatus,
    ArrivalStatus? arrivalStatus,
    int? starsCount,
    List<String>? customTags,
    String? note,
  }) {
    return StudentParticipationEvaluation(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumber: studentNumber ?? this.studentNumber,
      gender: gender ?? this.gender,
      homeworkStatus: homeworkStatus ?? this.homeworkStatus,
      materialsStatus: materialsStatus ?? this.materialsStatus,
      arrivalStatus: arrivalStatus ?? this.arrivalStatus,
      starsCount: starsCount ?? this.starsCount,
      customTags: customTags ?? this.customTags,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap(int sessionId) {
    return {
      'session_id': sessionId,
      'student_id': studentId,
      'homework_status': homeworkStatus.code,
      'materials_status': materialsStatus.code,
      'arrival_status': arrivalStatus.code,
      'stars_count': starsCount,
      'custom_tags': jsonEncode(customTags),
      'badge_name': customTags.isNotEmpty ? customTags.first : null,
      'score': starsCount * 10,
      'note': note,
    };
  }

  factory StudentParticipationEvaluation.fromMap(
    Map<String, dynamic> map, {
    String? studentNameFallback,
    int? studentNumberFallback,
    String? genderFallback,
  }) {
    List<String> parsedTags = [];
    if (map['custom_tags'] != null && map['custom_tags'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['custom_tags'].toString());
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (map['badge_name'] != null && map['badge_name'].toString().isNotEmpty) {
      parsedTags = [map['badge_name'].toString()];
    }

    final sName = map['first_name'] != null
        ? '${map['first_name']} ${map['last_name'] ?? ''}'.trim()
        : (map['student_name'] as String? ?? studentNameFallback ?? 'Öğrenci');

    final sNum = (map['school_number'] ?? map['student_number'] ?? studentNumberFallback ?? 0) as int;
    final sGender = (map['gender'] as String?) ?? genderFallback ?? 'Erkek';

    return StudentParticipationEvaluation(
      studentId: (map['student_id'] ?? map['id'] ?? 0) as int,
      studentName: sName,
      studentNumber: sNum,
      gender: sGender,
      homeworkStatus: HomeworkStatus.fromCode(map['homework_status'] as String?),
      materialsStatus: MaterialsStatus.fromCode(map['materials_status'] as String?),
      arrivalStatus: ArrivalStatus.fromCode(map['arrival_status'] as String?),
      starsCount: (map['stars_count'] as int?) ?? ((map['score'] as int?) != null ? (map['score'] as int) ~/ 10 : 0),
      customTags: parsedTags,
      note: map['note'] as String?,
    );
  }
}

/// SınıfCepte - Ders İçi Katılım Oturumu Ana Modeli
class ClassroomParticipationSession {
  final int? id;
  final int classId;
  final String className;
  final String date; // YYYY-MM-DD
  final int lessonHour; // 1..8
  final String subjectName;
  final String? topicName;
  final String? note;
  final List<StudentParticipationEvaluation> evaluations;

  ClassroomParticipationSession({
    this.id,
    required this.classId,
    required this.className,
    required this.date,
    required this.lessonHour,
    required this.subjectName,
    this.topicName,
    this.note,
    List<StudentParticipationEvaluation> evaluations = const [],
  }) : evaluations = List<StudentParticipationEvaluation>.from(evaluations)
          ..sort((a, b) {
            final numCmp = a.studentNumber.compareTo(b.studentNumber);
            if (numCmp != 0) return numCmp;
            return a.studentName.compareTo(b.studentName);
          });

  int get totalStudents => evaluations.length;

  int get homeworkDoneCount => evaluations.where((e) => e.homeworkStatus == HomeworkStatus.done).length;
  int get homeworkPartialCount => evaluations.where((e) => e.homeworkStatus == HomeworkStatus.partial).length;
  int get homeworkNoneCount => evaluations.where((e) => e.homeworkStatus == HomeworkStatus.none).length;

  double get homeworkCompletionRate {
    if (evaluations.isEmpty) return 0.0;
    final totalEligible = evaluations.where((e) => e.homeworkStatus != HomeworkStatus.notGiven).length;
    if (totalEligible == 0) return 100.0;
    final donePoints = homeworkDoneCount * 1.0 + homeworkPartialCount * 0.5;
    return (donePoints / totalEligible) * 100.0;
  }

  int get materialsReadyCount => evaluations.where((e) => e.materialsStatus == MaterialsStatus.ready).length;
  double get materialsReadinessRate {
    if (evaluations.isEmpty) return 0.0;
    return (materialsReadyCount / evaluations.length) * 100.0;
  }

  int get totalStarsAwarded => evaluations.fold<int>(0, (sum, e) => sum + e.starsCount);

  List<String> get starStudentNames => evaluations
      .where((e) => e.starsCount > 0)
      .map((e) => '${e.studentName} (${e.starsCount} ⭐)')
      .toList();

  List<String> get needsHomeworkStudentNames => evaluations
      .where((e) => e.homeworkStatus == HomeworkStatus.none)
      .map((e) => e.studentName)
      .toList();

  ClassroomParticipationSession copyWith({
    int? id,
    int? classId,
    String? className,
    String? date,
    int? lessonHour,
    String? subjectName,
    String? topicName,
    String? note,
    List<StudentParticipationEvaluation>? evaluations,
  }) {
    return ClassroomParticipationSession(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      date: date ?? this.date,
      lessonHour: lessonHour ?? this.lessonHour,
      subjectName: subjectName ?? this.subjectName,
      topicName: topicName ?? this.topicName,
      note: note ?? this.note,
      evaluations: evaluations ?? this.evaluations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'class_id': classId,
      'date': date,
      'lesson_hour': lessonHour,
      'subject_name': subjectName,
      'topic_name': topicName,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory ClassroomParticipationSession.fromMap(
    Map<String, dynamic> map, {
    String? classNameFallback,
    List<StudentParticipationEvaluation> evaluations = const [],
  }) {
    return ClassroomParticipationSession(
      id: map['id'] as int?,
      classId: (map['class_id'] ?? 0) as int,
      className: map['class_name'] as String? ?? classNameFallback ?? 'Sınıf',
      date: map['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
      lessonHour: (map['lesson_hour'] as int?) ?? 1,
      subjectName: map['subject_name'] as String? ?? 'Ders',
      topicName: map['topic_name'] as String?,
      note: map['note'] as String?,
      evaluations: evaluations,
    );
  }
}

/// SınıfCepte - Öğrenci Kümülatif Katılım & Gelişim İstatistikleri
class StudentParticipationSummaryStats {
  final int studentId;
  final String studentName;
  final int studentNumber;
  final int totalSessions;
  final int homeworkDoneCount;
  final int homeworkPartialCount;
  final int homeworkNoneCount;
  final int materialsReadyCount;
  final int totalStars;
  final List<String> topTags;
  final List<String> recentNotes;

  const StudentParticipationSummaryStats({
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.totalSessions,
    required this.homeworkDoneCount,
    required this.homeworkPartialCount,
    required this.homeworkNoneCount,
    required this.materialsReadyCount,
    required this.totalStars,
    this.topTags = const [],
    this.recentNotes = const [],
  });

  double get homeworkCompletionRate {
    final total = homeworkDoneCount + homeworkPartialCount + homeworkNoneCount;
    if (total == 0) return 100.0;
    return ((homeworkDoneCount * 1.0 + homeworkPartialCount * 0.5) / total) * 100.0;
  }

  double get materialsRate {
    if (totalSessions == 0) return 100.0;
    return (materialsReadyCount / totalSessions) * 100.0;
  }
}
