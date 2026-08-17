import 'package:flutter/material.dart';

/// Okundu Onaylı Sınıf Duyurusu Modeli
class ClassAnnouncementModel {
  final String id;
  final int classId;
  final String className;
  final String authorTeacherId;
  final String authorTeacherName;
  final String title;
  final String content;
  final String priority; // 'normal', 'urgent' (Acil), 'event' (Etkinlik/Toplantı)
  final DateTime? eventDate;
  final DateTime createdAt;
  final List<String> readByParentUserIds;

  const ClassAnnouncementModel({
    required this.id,
    required this.classId,
    required this.className,
    required this.authorTeacherId,
    required this.authorTeacherName,
    required this.title,
    required this.content,
    this.priority = 'normal',
    this.eventDate,
    required this.createdAt,
    this.readByParentUserIds = const [],
  });

  bool get isUrgent => priority == 'urgent';
  bool get isEvent => priority == 'event';
  int get readCount => readByParentUserIds.length;

  bool isReadBy(String parentUserId) => readByParentUserIds.contains(parentUserId);

  IconData get priorityIcon {
    switch (priority) {
      case 'urgent':
        return Icons.notification_important_rounded;
      case 'event':
        return Icons.event_available_rounded;
      case 'normal':
      default:
        return Icons.campaign_rounded;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'event':
        return const Color(0xFF8B5CF6);
      case 'normal':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  ClassAnnouncementModel copyWith({
    String? id,
    int? classId,
    String? className,
    String? authorTeacherId,
    String? authorTeacherName,
    String? title,
    String? content,
    String? priority,
    DateTime? eventDate,
    DateTime? createdAt,
    List<String>? readByParentUserIds,
  }) {
    return ClassAnnouncementModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      authorTeacherId: authorTeacherId ?? this.authorTeacherId,
      authorTeacherName: authorTeacherName ?? this.authorTeacherName,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt ?? this.createdAt,
      readByParentUserIds: readByParentUserIds ?? this.readByParentUserIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'class_name': className,
      'author_teacher_id': authorTeacherId,
      'author_teacher_name': authorTeacherName,
      'title': title,
      'content': content,
      'priority': priority,
      'event_date': eventDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'read_by_parent_user_ids': readByParentUserIds,
    };
  }

  factory ClassAnnouncementModel.fromMap(Map<String, dynamic> map) {
    return ClassAnnouncementModel(
      id: map['id']?.toString() ?? '',
      classId: int.tryParse(map['class_id']?.toString() ?? '') ?? 0,
      className: map['class_name']?.toString() ?? '',
      authorTeacherId: map['author_teacher_id']?.toString() ?? '',
      authorTeacherName: map['author_teacher_name']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      priority: map['priority']?.toString() ?? 'normal',
      eventDate: map['event_date'] != null ? DateTime.tryParse(map['event_date'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
      readByParentUserIds: (map['read_by_parent_user_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
