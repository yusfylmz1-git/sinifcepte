/// Öğretmen ↔ veli 1:1 mesajı (Faz A yerel, Faz B class_rooms/.../messages).
class ClassMessageModel {
  final String id;
  final int classId;
  final String classCloudId;
  final int studentId;
  final String studentCloudId;
  final String studentName;
  final String parentUserId;
  final String parentName;
  final String authorRole; // teacher | parent
  final String authorName;
  final String body;
  final DateTime createdAt;

  const ClassMessageModel({
    required this.id,
    required this.classId,
    this.classCloudId = '',
    required this.studentId,
    this.studentCloudId = '',
    required this.studentName,
    required this.parentUserId,
    required this.parentName,
    required this.authorRole,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'class_cloud_id': classCloudId,
      'student_id': studentId,
      'student_cloud_id': studentCloudId,
      'student_name': studentName,
      'parent_user_id': parentUserId,
      'parent_name': parentName,
      'author_role': authorRole,
      'author_name': authorName,
      'body': body,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ClassMessageModel.fromMap(Map<String, dynamic> map) {
    return ClassMessageModel(
      id: map['id'] as String? ?? '',
      classId: map['class_id'] as int? ?? 0,
      classCloudId: map['class_cloud_id'] as String? ?? '',
      studentId: map['student_id'] as int? ?? 0,
      studentCloudId: map['student_cloud_id'] as String? ?? '',
      studentName: map['student_name'] as String? ?? '',
      parentUserId: map['parent_user_id'] as String? ?? '',
      parentName: map['parent_name'] as String? ?? '',
      authorRole: map['author_role'] as String? ?? 'parent',
      authorName: map['author_name'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
