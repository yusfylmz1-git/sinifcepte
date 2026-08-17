/// SınıfCepte - Müfredat Haftalık Konu ve Kazanım Veri Modeli
class CurriculumOutcomeModel {
  final int? id;
  final String docId;
  final int gradeLevel; // 1 to 12
  final String subjectCode; // Örn: "BILISIM", "MAT", "FEN", "TURKCE"
  final String subjectName; // Örn: "Bilişim Teknolojileri ve Yazılım", "Matematik"
  final String publisher; // Örn: "TYMM (Maarif Modeli)", "MEB Yayınları"
  final String fullTitle; // Örn: "5. Sınıf - Bilişim Teknolojileri ve Yazılım - TYMM (Maarif Modeli)"
  final int weekNumber; // 1 to 39 (Takvim Sırası)
  final int? teachingWeekNumber; // 1 to 36 (Ders Sırası)
  final String unitTitle; // Örn: "Bilişim Teknolojilerinin Sınıflandırılması"
  final String topicTitle; // Örn: "Bilişim Teknolojilerinin Sınıflandırılması"
  final String? outcomeCode; // Örn: "BTY.5.1.1"
  final String outcomeDescription; // Kazanım açıklaması
  final String academicYear; // "2026-2027"
  final bool isHolidayWeek;
  final String? holidayNote;
  final bool isFavorite;

  const CurriculumOutcomeModel({
    this.id,
    required this.docId,
    required this.gradeLevel,
    required this.subjectCode,
    required this.subjectName,
    this.publisher = 'MEB Yayınları',
    this.fullTitle = '',
    required this.weekNumber,
    this.teachingWeekNumber,
    required this.unitTitle,
    required this.topicTitle,
    this.outcomeCode,
    required this.outcomeDescription,
    this.academicYear = '2026-2027',
    this.isHolidayWeek = false,
    this.holidayNote,
    this.isFavorite = false,
  });

  CurriculumOutcomeModel copyWith({
    int? id,
    String? docId,
    int? gradeLevel,
    String? subjectCode,
    String? subjectName,
    String? publisher,
    String? fullTitle,
    int? weekNumber,
    int? teachingWeekNumber,
    String? unitTitle,
    String? topicTitle,
    String? outcomeCode,
    String? outcomeDescription,
    String? academicYear,
    bool? isHolidayWeek,
    String? holidayNote,
    bool? isFavorite,
  }) {
    return CurriculumOutcomeModel(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      publisher: publisher ?? this.publisher,
      fullTitle: fullTitle ?? this.fullTitle,
      weekNumber: weekNumber ?? this.weekNumber,
      teachingWeekNumber: teachingWeekNumber ?? this.teachingWeekNumber,
      unitTitle: unitTitle ?? this.unitTitle,
      topicTitle: topicTitle ?? this.topicTitle,
      outcomeCode: outcomeCode ?? this.outcomeCode,
      outcomeDescription: outcomeDescription ?? this.outcomeDescription,
      academicYear: academicYear ?? this.academicYear,
      isHolidayWeek: isHolidayWeek ?? this.isHolidayWeek,
      holidayNote: holidayNote ?? this.holidayNote,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory CurriculumOutcomeModel.fromMap(Map<String, dynamic> map) {
    return CurriculumOutcomeModel(
      id: map['id'] as int?,
      docId: map['doc_id'] as String? ?? '',
      gradeLevel: map['grade_level'] as int? ?? 5,
      subjectCode: map['subject_code'] as String? ?? 'GENEL',
      subjectName: map['subject_name'] as String? ?? 'Genel Ders',
      publisher: map['publisher'] as String? ?? 'MEB Yayınları',
      fullTitle: map['full_title'] as String? ?? '',
      weekNumber: map['week_number'] as int? ?? 1,
      teachingWeekNumber: map['teaching_week_number'] as int?,
      unitTitle: map['unit_title'] as String? ?? '',
      topicTitle: map['topic_title'] as String? ?? '',
      outcomeCode: map['outcome_code'] as String?,
      outcomeDescription: map['outcome_description'] as String? ?? '',
      academicYear: map['academic_year'] as String? ?? '2026-2027',
      isHolidayWeek: (map['is_holiday_week'] as int? ?? 0) == 1,
      holidayNote: map['holiday_note'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doc_id': docId,
      'grade_level': gradeLevel,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'publisher': publisher,
      'full_title': fullTitle,
      'week_number': weekNumber,
      'teaching_week_number': teachingWeekNumber,
      'unit_title': unitTitle,
      'topic_title': topicTitle,
      'outcome_code': outcomeCode,
      'outcome_description': outcomeDescription,
      'academic_year': academicYear,
      'is_holiday_week': isHolidayWeek ? 1 : 0,
      'holiday_note': holidayNote,
    };
  }

  factory CurriculumOutcomeModel.fromJson(Map<String, dynamic> json) {
    return CurriculumOutcomeModel(
      docId: json['id'] as String? ?? '',
      gradeLevel: json['gradeLevel'] as int? ?? 5,
      subjectCode: json['subjectCode'] as String? ?? 'GENEL',
      subjectName: json['subjectName'] as String? ?? 'Genel Ders',
      publisher: json['publisher'] as String? ?? 'MEB Yayınları',
      fullTitle: json['fullTitle'] as String? ?? '',
      weekNumber: json['weekNumber'] as int? ?? 1,
      teachingWeekNumber: json['teachingWeekNumber'] as int?,
      unitTitle: json['unitTitle'] as String? ?? '',
      topicTitle: json['topicTitle'] as String? ?? '',
      outcomeCode: json['outcomeCode'] as String?,
      outcomeDescription: json['outcomeDescription'] as String? ?? '',
      academicYear: json['academicYear'] as String? ?? '2026-2027',
      isHolidayWeek: json['isHolidayWeek'] as bool? ?? false,
      holidayNote: json['holidayNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': docId,
      'gradeLevel': gradeLevel,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'publisher': publisher,
      'fullTitle': fullTitle,
      'weekNumber': weekNumber,
      'teachingWeekNumber': teachingWeekNumber,
      'unitTitle': unitTitle,
      'topicTitle': topicTitle,
      'outcomeCode': outcomeCode,
      'outcomeDescription': outcomeDescription,
      'academicYear': academicYear,
      'isHolidayWeek': isHolidayWeek,
      'holidayNote': holidayNote,
    };
  }
}

