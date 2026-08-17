/// Sınıf Model Sınıfı (ClassModel)
class ClassModel {
  final int? id;
  final String name; // Örn: 10-A
  final String subject; // Örn: Matematik
  final String academicYear; // Örn: 2024-2025
  final String? description;

  const ClassModel({
    this.id,
    required this.name,
    required this.subject,
    required this.academicYear,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'academic_year': academicYear,
      'description': description,
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      subject: map['subject'] as String,
      academicYear: map['academic_year'] as String,
      description: map['description'] as String?,
    );
  }

  ClassModel copyWith({
    int? id,
    String? name,
    String? subject,
    String? academicYear,
    String? description,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      academicYear: academicYear ?? this.academicYear,
      description: description ?? this.description,
    );
  }
}
