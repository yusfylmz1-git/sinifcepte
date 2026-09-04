import '../../core/utils/name_formatter.dart';

/// Öğrenci Model Sınıfı (StudentModel)
class StudentModel {
  final int? id;
  final int classId;
  final int schoolNumber; // Örn: 452
  final String firstName;
  final String lastName;
  final String gender; // 'Erkek', 'Kız'
  final String? parentName; // Örn: Fatma Yılmaz (Anne)
  final String? parentPhone; // Örn: 0532 123 45 67
  final String? notes; // Ekstra notlar veya acil durum bilgisi

  const StudentModel({
    this.id,
    required this.classId,
    required this.schoolNumber,
    required this.firstName,
    required this.lastName,
    this.gender = 'Erkek',
    this.parentName,
    this.parentPhone,
    this.notes,
  });

  /// Standart yazım: **Yusuf YILMAZ**.
  ///
  /// Ham birleştirme yapılıyordu; kullanıcı "yusuf yılmaz" yazınca öyle
  /// kalıyor, listede, PDF'te ve veli ekranında böyle görünüyordu.
  String get fullName =>
      NameFormatter.format(firstName: firstName, lastName: lastName);

  /// Dar alanlar için: **Yusuf Y.**
  String get shortName =>
      NameFormatter.formatShort(firstName: firstName, lastName: lastName);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'school_number': schoolNumber,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'notes': notes,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'] as int?,
      classId: map['class_id'] as int,
      schoolNumber: map['school_number'] as int? ?? 0,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      gender: map['gender'] as String? ?? 'Erkek',
      parentName: map['parent_name'] as String?,
      parentPhone: map['parent_phone'] as String?,
      notes: map['notes'] as String?,
    );
  }

  StudentModel copyWith({
    int? id,
    int? classId,
    int? schoolNumber,
    String? firstName,
    String? lastName,
    String? gender,
    String? parentName,
    String? parentPhone,
    String? notes,
  }) {
    return StudentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      schoolNumber: schoolNumber ?? this.schoolNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      notes: notes ?? this.notes,
    );
  }
}
