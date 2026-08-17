/// SınıfCepte - Müfredat Kazanım Modeli
class OutcomeModel {
  final String id;
  final int gradeLevel; // 1 - 12
  final String subject;
  final int weekNumber; // 1 - 37
  final String topic;
  final String outcomeDescription;
  final bool isHoliday;
  final String holidayTitle;
  final bool isFavorite;

  const OutcomeModel({
    required this.id,
    required this.gradeLevel,
    required this.subject,
    required this.weekNumber,
    required this.topic,
    required this.outcomeDescription,
    this.isHoliday = false,
    this.holidayTitle = '',
    this.isFavorite = false,
  });

  OutcomeModel copyWith({
    String? id,
    int? gradeLevel,
    String? subject,
    int? weekNumber,
    String? topic,
    String? outcomeDescription,
    bool? isHoliday,
    String? holidayTitle,
    bool? isFavorite,
  }) {
    return OutcomeModel(
      id: id ?? this.id,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      subject: subject ?? this.subject,
      weekNumber: weekNumber ?? this.weekNumber,
      topic: topic ?? this.topic,
      outcomeDescription: outcomeDescription ?? this.outcomeDescription,
      isHoliday: isHoliday ?? this.isHoliday,
      holidayTitle: holidayTitle ?? this.holidayTitle,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
