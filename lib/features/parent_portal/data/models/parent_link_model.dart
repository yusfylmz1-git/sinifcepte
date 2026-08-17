/// SınıfCepte - Çoklu Veli-Öğrenci Bağlantı Modeli (parent_links)
class ParentLinkModel {
  final String id;
  final String parentUserId; // Veli kullanıcı ID
  final String parentName; // Veli Ad-Soyad
  final String? parentPhone; // Veli Telefon (Özel/Gizli tutulur)
  final int studentId;
  final String studentName;
  final int studentNumber;
  final String schoolId;
  final String schoolName;
  final int classId;
  final String className;
  final String relation; // 'Anne', 'Baba', 'Vasi', 'Diğer'
  final DateTime linkedAt;
  final String linkedViaTokenCode;
  final String status; // 'active', 'archived', 'graduated', 'transferred'

  const ParentLinkModel({
    required this.id,
    required this.parentUserId,
    required this.parentName,
    this.parentPhone,
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.schoolId,
    required this.schoolName,
    required this.classId,
    required this.className,
    this.relation = 'Anne',
    required this.linkedAt,
    required this.linkedViaTokenCode,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_user_id': parentUserId,
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'student_id': studentId,
      'student_name': studentName,
      'student_number': studentNumber,
      'school_id': schoolId,
      'school_name': schoolName,
      'class_id': classId,
      'class_name': className,
      'relation': relation,
      'linked_at': linkedAt.toIso8601String(),
      'linked_via_token_code': linkedViaTokenCode,
      'status': status,
    };
  }

  factory ParentLinkModel.fromMap(Map<String, dynamic> map) {
    return ParentLinkModel(
      id: map['id'] as String,
      parentUserId: map['parent_user_id'] as String,
      parentName: map['parent_name'] as String? ?? 'Veli',
      parentPhone: map['parent_phone'] as String?,
      studentId: map['student_id'] as int,
      studentName: map['student_name'] as String? ?? '',
      studentNumber: map['student_number'] as int? ?? 0,
      schoolId: map['school_id'] as String? ?? '',
      schoolName: map['school_name'] as String? ?? '',
      classId: map['class_id'] as int,
      className: map['class_name'] as String? ?? '',
      relation: map['relation'] as String? ?? 'Anne',
      linkedAt: DateTime.parse(map['linked_at'] as String),
      linkedViaTokenCode: map['linked_via_token_code'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }

  ParentLinkModel copyWith({
    String? id,
    String? parentUserId,
    String? parentName,
    String? parentPhone,
    int? studentId,
    String? studentName,
    int? studentNumber,
    String? schoolId,
    String? schoolName,
    int? classId,
    String? className,
    String? relation,
    DateTime? linkedAt,
    String? linkedViaTokenCode,
    String? status,
  }) {
    return ParentLinkModel(
      id: id ?? this.id,
      parentUserId: parentUserId ?? this.parentUserId,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumber: studentNumber ?? this.studentNumber,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      relation: relation ?? this.relation,
      linkedAt: linkedAt ?? this.linkedAt,
      linkedViaTokenCode: linkedViaTokenCode ?? this.linkedViaTokenCode,
      status: status ?? this.status,
    );
  }
}
