/// Sınıf Ders Öğretmeni ve Veli Görüşme Saati Modeli
class ClassTeacherContactModel {
  final String id;
  final int classId;
  final String className;
  final String teacherName;
  final String branch; // Matematik, Türkçe, Fen Bilimleri, vb.
  final bool isHomeroomTeacher; // Sınıf Rehber Öğretmeni mi?
  final String meetingDay; // Pazartesi, Salı, Çarşamba, Perşembe, Cuma
  final String meetingTime; // Örn: 13:30 - 14:15
  final String location; // Örn: Veli Görüşme Odası, Öğretmenler Odası
  final String? phone;
  final String? email;
  final bool isVerified; // Okul İdaresi / Admin Tarafından Doğrulanmış mı?

  const ClassTeacherContactModel({
    required this.id,
    required this.classId,
    required this.className,
    required this.teacherName,
    required this.branch,
    this.isHomeroomTeacher = false,
    required this.meetingDay,
    required this.meetingTime,
    this.location = 'Veli Görüşme Odası',
    this.phone,
    this.email,
    this.isVerified = true,
  });

  ClassTeacherContactModel copyWith({
    String? id,
    int? classId,
    String? className,
    String? teacherName,
    String? branch,
    bool? isHomeroomTeacher,
    String? meetingDay,
    String? meetingTime,
    String? location,
    String? phone,
    String? email,
    bool? isVerified,
  }) {
    return ClassTeacherContactModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      teacherName: teacherName ?? this.teacherName,
      branch: branch ?? this.branch,
      isHomeroomTeacher: isHomeroomTeacher ?? this.isHomeroomTeacher,
      meetingDay: meetingDay ?? this.meetingDay,
      meetingTime: meetingTime ?? this.meetingTime,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'class_name': className,
      'teacher_name': teacherName,
      'branch': branch,
      'is_homeroom_teacher': isHomeroomTeacher,
      'meeting_day': meetingDay,
      'meeting_time': meetingTime,
      'location': location,
      'phone': phone,
      'email': email,
      'is_verified': isVerified,
    };
  }

  factory ClassTeacherContactModel.fromMap(Map<String, dynamic> map) {
    return ClassTeacherContactModel(
      id: map['id']?.toString() ?? '',
      classId: map['class_id'] is int ? map['class_id'] as int : int.tryParse(map['class_id']?.toString() ?? '') ?? 0,
      className: map['class_name']?.toString() ?? '',
      teacherName: map['teacher_name']?.toString() ?? '',
      branch: map['branch']?.toString() ?? '',
      isHomeroomTeacher: map['is_homeroom_teacher'] == true || map['is_homeroom_teacher'] == 1,
      meetingDay: map['meeting_day']?.toString() ?? 'Pazartesi',
      meetingTime: map['meeting_time']?.toString() ?? '13:30 - 14:15',
      location: map['location']?.toString() ?? 'Veli Görüşme Odası',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      isVerified: map['is_verified'] == true || map['is_verified'] == 1 || map['is_verified'] == null,
    );
  }
}
