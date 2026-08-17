/// Ders İçi Katılım Kaydı Model Sınıfı (ParticipationRecordModel)
/// DB Tablosu: participation_records (badge_name, score)
class AttendanceRecordModel {
  final int? id;
  final int sessionId;
  final int studentId;
  final String? badgeName; // Rozet adı: 'Olumlu ⭐', 'Geliştirilmeli ✍️', 'Ödev Eksik 📑' vb.
  final int score; // Puan: +1 (olumlu), -1 (olumsuz), 0 (nötr)

  const AttendanceRecordModel({
    this.id,
    required this.sessionId,
    required this.studentId,
    this.badgeName,
    this.score = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'badge_name': badgeName,
      'score': score,
    };
  }

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    return AttendanceRecordModel(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      studentId: map['student_id'] as int,
      badgeName: map['badge_name'] as String?,
      score: map['score'] as int? ?? 0,
    );
  }

  AttendanceRecordModel copyWith({
    int? id,
    int? sessionId,
    int? studentId,
    String? badgeName,
    int? score,
  }) {
    return AttendanceRecordModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      badgeName: badgeName ?? this.badgeName,
      score: score ?? this.score,
    );
  }
}

