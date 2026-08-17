import 'dart:convert';

/// Oturma Planı Modeli
class SeatingPlanModel {
  final int classId;
  final int columns;
  final int rows;
  
  /// Öğrenci ID'si ile "[row],[col]" formatındaki koordinatı eşleştirir.
  /// Örneğin: { 1: "0,0", 2: "0,1" }
  final Map<int, String> assignments;

  const SeatingPlanModel({
    required this.classId,
    this.columns = 3,
    this.rows = 5,
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
      columns: map['columns'] as int? ?? 4,
      rows: map['rows'] as int? ?? 6,
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
