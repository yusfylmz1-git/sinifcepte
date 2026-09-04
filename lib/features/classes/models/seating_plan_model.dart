import 'dart:convert';

/// Oturma Planı Modeli
class SeatingPlanModel {
  final int classId;
  final int columns;
  final int rows;
  
  /// Öğrenci ID'si ile "[row],[col]" formatındaki koordinatı eşleştirir.
  /// Örneğin: { 1: "0,0", 2: "0,1" }
  final Map<int, String> assignments;

  /// Varsayilan blok (sutun) sayisi.
  ///
  /// Kurucu 3x5, `fromMap` ise 4x6 diyordu; NULL sutunlu bir satirdan
  /// okunan plan sessizce buyuyordu. Tek kaynak olsun diye sabitlendi.
  static const int defaultColumns = 3;

  /// Varsayilan sira sayisi.
  static const int defaultRows = 5;

  const SeatingPlanModel({
    required this.classId,
    this.columns = defaultColumns,
    this.rows = defaultRows,
    this.assignments = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'class_id': classId,
      'columns': columns,
      'rows': rows,
      'assignments': jsonEncode(assignments.map((key, value) => MapEntry(key.toString(), value))),
    };
  }

  factory SeatingPlanModel.fromMap(Map<String, dynamic> map) {
    Map<int, String> parsedAssignments = {};
    if (map['assignments'] != null) {
      try {
        final decoded = jsonDecode(map['assignments'] as String) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          parsedAssignments[int.parse(key)] = value.toString();
        });
      } catch (e) {
        // Hata durumunda boş bırak
      }
    }

    return SeatingPlanModel(
      classId: map['class_id'] as int,
      columns: map['columns'] as int? ?? defaultColumns,
      rows: map['rows'] as int? ?? defaultRows,
      assignments: parsedAssignments,
    );
  }

  SeatingPlanModel copyWith({
    int? classId,
    int? columns,
    int? rows,
    Map<int, String>? assignments,
  }) {
    return SeatingPlanModel(
      classId: classId ?? this.classId,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      assignments: assignments ?? this.assignments,
    );
  }
}
