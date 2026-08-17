import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../models/seating_plan_model.dart';

final seatingPlanServiceProvider = Provider((ref) => SeatingPlanService());

class SeatingPlanService {
  final dbHelper = DatabaseHelper.instance;

  Future<SeatingPlanModel?> getSeatingPlan(int classId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'seating_plans',
      where: 'class_id = ?',
      whereArgs: [classId],
    );

    if (result.isNotEmpty) {
      return SeatingPlanModel.fromMap(result.first);
    }
    return null;
  }

  Future<void> saveSeatingPlan(SeatingPlanModel plan) async {
    final db = await dbHelper.database;
    await db.insert(
      'seating_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSeatingPlan(int classId) async {
    final db = await dbHelper.database;
    await db.delete(
      'seating_plans',
      where: 'class_id = ?',
      whereArgs: [classId],
    );
  }
}
