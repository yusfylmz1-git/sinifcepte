import 'package:flutter/material.dart';

/// Veli Hızlı Durum Bildirimi Modeli (İlaç, Erken Çıkış, Not)
class ParentStatusReportModel {
  final String id;
  final int studentId;
  final String studentName;
  final int studentNumber;
  final int classId;
  final String className;
  final String parentUserId;
  final String parentName;
  final String relation; // 'Anne', 'Baba', 'Vasi', 'Diğer'
  final String type; // 'medication' (İlaç), 'early_leave' (Erken Çıkış/Randevu), 'note' (Özel Not)
  final String title;
  final String details;
  final String? timeInfo; // Örn: "Öğle Arası 12:30", "15:00"
  final DateTime createdAt;
  final String status; // 'pending' (Bekliyor), 'acknowledged' (Görüldü/Onaylandı), 'completed' (Tamamlandı)
  final DateTime? teacherAcknowledgedAt;
  final String? teacherNote;

  const ParentStatusReportModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.classId,
    required this.className,
    required this.parentUserId,
    required this.parentName,
    required this.relation,
    required this.type,
    required this.title,
    required this.details,
    this.timeInfo,
    required this.createdAt,
    this.status = 'pending',
    this.teacherAcknowledgedAt,
    this.teacherNote,
  });

  bool get isAcknowledged => status == 'acknowledged' || status == 'completed';
  bool get isMedication => type == 'medication';
  bool get isEarlyLeave => type == 'early_leave';
  bool get isNote => type == 'note';

  IconData get typeIcon {
    switch (type) {
      case 'medication':
        return Icons.medication_liquid_rounded;
      case 'early_leave':
        return Icons.timer_outlined;
      case 'note':
      default:
        return Icons.edit_note_rounded;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'medication':
        return const Color(0xFF10B981);
      case 'early_leave':
        return const Color(0xFFF59E0B);
      case 'note':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String get typeTitleTr {
    switch (type) {
      case 'medication':
        return 'İlaç Kullanımı';
      case 'early_leave':
        return 'Erken Çıkış / Randevu';
      case 'note':
      default:
        return 'Veli Notu';
    }
  }

  ParentStatusReportModel copyWith({
    String? id,
    int? studentId,
    String? studentName,
    int? studentNumber,
    int? classId,
    String? className,
    String? parentUserId,
    String? parentName,
    String? relation,
    String? type,
    String? title,
    String? details,
    String? timeInfo,
    DateTime? createdAt,
    String? status,
    DateTime? teacherAcknowledgedAt,
    String? teacherNote,
  }) {
    return ParentStatusReportModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumber: studentNumber ?? this.studentNumber,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      parentUserId: parentUserId ?? this.parentUserId,
      parentName: parentName ?? this.parentName,
      relation: relation ?? this.relation,
      type: type ?? this.type,
      title: title ?? this.title,
      details: details ?? this.details,
      timeInfo: timeInfo ?? this.timeInfo,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      teacherAcknowledgedAt: teacherAcknowledgedAt ?? this.teacherAcknowledgedAt,
      teacherNote: teacherNote ?? this.teacherNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'student_number': studentNumber,
      'class_id': classId,
      'class_name': className,
      'parent_user_id': parentUserId,
      'parent_name': parentName,
      'relation': relation,
      'type': type,
      'title': title,
      'details': details,
      'time_info': timeInfo,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'teacher_acknowledged_at': teacherAcknowledgedAt?.toIso8601String(),
      'teacher_note': teacherNote,
    };
  }

  factory ParentStatusReportModel.fromMap(Map<String, dynamic> map) {
    return ParentStatusReportModel(
      id: map['id']?.toString() ?? '',
      studentId: int.tryParse(map['student_id']?.toString() ?? '') ?? 0,
      studentName: map['student_name']?.toString() ?? '',
      studentNumber: int.tryParse(map['student_number']?.toString() ?? '') ?? 0,
      classId: int.tryParse(map['class_id']?.toString() ?? '') ?? 0,
      className: map['class_name']?.toString() ?? '',
      parentUserId: map['parent_user_id']?.toString() ?? '',
      parentName: map['parent_name']?.toString() ?? '',
      relation: map['relation']?.toString() ?? 'Veli',
      type: map['type']?.toString() ?? 'note',
      title: map['title']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      timeInfo: map['time_info']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
      teacherAcknowledgedAt: map['teacher_acknowledged_at'] != null
          ? DateTime.tryParse(map['teacher_acknowledged_at'].toString())
          : null,
      teacherNote: map['teacher_note']?.toString(),
    );
  }
}
