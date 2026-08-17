/// SınıfCepte - Ders İçi Katılım ve Davranış Rozet Modeli (Yoklama Değildir)
enum ParticipationStatus {
  neutral, // Varsayılan İyi/Nötr
  positive, // 1 Tık: Olumlu / Yıldız ⭐
  needsImprovement, // 2 Tık: Geliştirilmeli ✍️
}

class ParticipationBadgeModel {
  final String studentId;
  final String studentName;
  final int studentNumber;
  final ParticipationStatus status;
  final List<String> customBadges; // Ödev Yapmadı, Defter Eksik vb.

  const ParticipationBadgeModel({
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    this.status = ParticipationStatus.neutral,
    this.customBadges = const [],
  });

  ParticipationBadgeModel copyWith({
    String? studentId,
    String? studentName,
    int? studentNumber,
    ParticipationStatus? status,
    List<String>? customBadges,
  }) {
    return ParticipationBadgeModel(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumber: studentNumber ?? this.studentNumber,
      status: status ?? this.status,
      customBadges: customBadges ?? this.customBadges,
    );
  }
}
