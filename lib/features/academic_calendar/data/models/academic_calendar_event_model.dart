import 'package:flutter/material.dart';

/// MEB Akademik Takvim Olayı Kategorisi
enum CalendarEventCategory {
  period('Dönem Başlangıç / Bitiş', Color(0xFF4F46E5), Icons.flag_rounded),
  breakHoliday('Ara Tatil / Sömestr', Color(0xFFD97706), Icons.beach_access_rounded),
  officialHoliday('Resmî Tatil', Color(0xFFDC2626), Icons.star_rounded),
  examPeriod('Ortak Sınav Haftası', Color(0xFF9333EA), Icons.edit_calendar_rounded),
  specialDay('Özel Gün ve Hafta', Color(0xFF0284C7), Icons.celebration_rounded);

  final String title;
  final Color color;
  final IconData icon;
  const CalendarEventCategory(this.title, this.color, this.icon);

  static CalendarEventCategory fromString(String? val) {
    return CalendarEventCategory.values.firstWhere(
      (e) => e.name == val,
      orElse: () => CalendarEventCategory.specialDay,
    );
  }
}

/// SınıfCepte - MEB Akademik Takvim Olay Modeli
class AcademicCalendarEventModel {
  final int? id;
  final String docId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final CalendarEventCategory category;
  final String academicYear; // Örn: "2025-2026"
  final bool isOfficialHoliday;

  const AcademicCalendarEventModel({
    this.id,
    required this.docId,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.category,
    this.academicYear = '2025-2026',
    this.isOfficialHoliday = false,
  });

  /// Kaç gün sürdüğünü hesaplar
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Olayın bugünden kaç gün sonra olduğunu veya geçip geçmediğini hesaplar
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventStart = DateTime(startDate.year, startDate.month, startDate.day);
    return eventStart.difference(today).inDays;
  }

  bool get isUpcoming => daysRemaining >= 0;
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  AcademicCalendarEventModel copyWith({
    int? id,
    String? docId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    CalendarEventCategory? category,
    String? academicYear,
    bool? isOfficialHoliday,
  }) {
    return AcademicCalendarEventModel(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category ?? this.category,
      academicYear: academicYear ?? this.academicYear,
      isOfficialHoliday: isOfficialHoliday ?? this.isOfficialHoliday,
    );
  }

  factory AcademicCalendarEventModel.fromMap(Map<String, dynamic> map) {
    return AcademicCalendarEventModel(
      id: map['id'] as int?,
      docId: map['doc_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      category: CalendarEventCategory.fromString(map['category'] as String?),
      academicYear: map['academic_year'] as String? ?? '2025-2026',
      isOfficialHoliday: (map['is_official_holiday'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doc_id': docId,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'category': category.name,
      'academic_year': academicYear,
      'is_official_holiday': isOfficialHoliday ? 1 : 0,
    };
  }
}
