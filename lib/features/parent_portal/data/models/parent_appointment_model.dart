import 'package:flutter/material.dart';

/// Veli - Öğretmen Görüşme Randevusu Modeli
class ParentAppointmentModel {
  final String id;
  final int classId;
  final String className;
  final int studentId;
  final String studentName;
  final int studentNumber;
  final String parentUserId;
  final String parentName;
  final String relation;
  final String teacherName;
  final String branch;
  final DateTime appointmentDate;
  final String timeSlot; // Örn: 13:30 - 14:00
  final String topic; // Örn: "Ders içi katılım ve sınav değerlendirmesi"
  final String status; // 'pending', 'confirmed', 'rejected', 'completed', 'cancelled'
  final DateTime createdAt;
  final String? responseNote;

  const ParentAppointmentModel({
    required this.id,
    required this.classId,
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.parentUserId,
    required this.parentName,
    required this.relation,
    required this.teacherName,
    required this.branch,
    required this.appointmentDate,
    required this.timeSlot,
    required this.topic,
    this.status = 'pending',
    required this.createdAt,
    this.responseNote,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => status == 'completed';

  Color get statusColor {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF8B5CF6);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String get statusTitleTr {
    switch (status) {
      case 'confirmed':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'completed':
        return 'Görüşme Yapıldı';
      case 'cancelled':
        return 'İptal Edildi';
      case 'pending':
      default:
        return 'Onay Bekliyor';
    }
  }

  ParentAppointmentModel copyWith({
    String? id,
    int? classId,
    String? className,
    int? studentId,
    String? studentName,
    int? studentNumber,
    String? parentUserId,
    String? parentName,
    String? relation,
    String? teacherName,
    String? branch,
    DateTime? appointmentDate,
    String? timeSlot,
    String? topic,
    String? status,
    DateTime? createdAt,
    String? responseNote,
  }) {
    return ParentAppointmentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumber: studentNumber ?? this.studentNumber,
      parentUserId: parentUserId ?? this.parentUserId,
      parentName: parentName ?? this.parentName,
      relation: relation ?? this.relation,
      teacherName: teacherName ?? this.teacherName,
      branch: branch ?? this.branch,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      timeSlot: timeSlot ?? this.timeSlot,
      topic: topic ?? this.topic,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      responseNote: responseNote ?? this.responseNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'class_name': className,
      'student_id': studentId,
      'student_name': studentName,
      'student_number': studentNumber,
      'parent_user_id': parentUserId,
      'parent_name': parentName,
      'relation': relation,
      'teacher_name': teacherName,
      'branch': branch,
      'appointment_date': appointmentDate.toIso8601String(),
      'time_slot': timeSlot,
      'topic': topic,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'response_note': responseNote,
    };
  }

  factory ParentAppointmentModel.fromMap(Map<String, dynamic> map) {
    return ParentAppointmentModel(
      id: map['id']?.toString() ?? '',
      classId: int.tryParse(map['class_id']?.toString() ?? '') ?? 0,
      className: map['class_name']?.toString() ?? '',
      studentId: int.tryParse(map['student_id']?.toString() ?? '') ?? 0,
      studentName: map['student_name']?.toString() ?? '',
      studentNumber: int.tryParse(map['student_number']?.toString() ?? '') ?? 0,
      parentUserId: map['parent_user_id']?.toString() ?? '',
      parentName: map['parent_name']?.toString() ?? '',
      relation: map['relation']?.toString() ?? 'Veli',
      teacherName: map['teacher_name']?.toString() ?? '',
      branch: map['branch']?.toString() ?? '',
      appointmentDate: map['appointment_date'] != null
          ? DateTime.parse(map['appointment_date'].toString())
          : DateTime.now(),
      timeSlot: map['time_slot']?.toString() ?? '13:30 - 14:00',
      topic: map['topic']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
      responseNote: map['response_note']?.toString(),
    );
  }
}
