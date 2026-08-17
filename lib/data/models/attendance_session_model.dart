/// Yoklama Oturumu Model Sınıfı (AttendanceSessionModel)
class AttendanceSessionModel {
  final int? id;
  final int classId;
  final String date; // YYYY-MM-DD
  final int lessonHour; // 1, 2, 3...
  final String? note;

  const AttendanceSessionModel({
    this.id,
    required this.classId,
    required this.date,
    required this.lessonHour,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'date': date,
      'lesson_hour': lessonHour,
      'note': note,
    };
  }

  factory AttendanceSessionModel.fromMap(Map<String, dynamic> map) {
    return AttendanceSessionModel(
      id: map['id'] as int?,
      classId: map['class_id'] as int,
      date: map['date'] as String,
      lessonHour: map['lesson_hour'] as int,
      note: map['note'] as String?,
    );
  }

  AttendanceSessionModel copyWith({
    int? id,
    int? classId,
    String? date,
    int? lessonHour,
    String? note,
  }) {
    return AttendanceSessionModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      date: date ?? this.date,
      lessonHour: lessonHour ?? this.lessonHour,
      note: note ?? this.note,
    );
  }
}
