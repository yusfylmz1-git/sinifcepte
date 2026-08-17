import '../models/student_model.dart';
import '../../core/database/database_helper.dart';

/// Öğrenci Veritabanı Erişim Katmanı (StudentRepository)
class StudentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertStudent(StudentModel student) async {
    final db = await _dbHelper.database;
    return await db.insert('students', student.toMap());
  }

  Future<void> insertStudentsBatch(List<StudentModel> students) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final student in students) {
      batch.insert('students', student.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<StudentModel>> getStudentsByClassId(int classId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'students',
      where: 'class_id = ?',
      whereArgs: [classId],
      orderBy: 'school_number ASC',
    );
    return maps.map((map) => StudentModel.fromMap(map)).toList();
  }

  Future<int> updateStudent(StudentModel student) async {
    final db = await _dbHelper.database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteStudentsBatch(List<int> ids) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('students', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> moveStudentsBatch(List<int> studentIds, int newClassId) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final id in studentIds) {
      batch.update(
        'students',
        {'class_id': newClassId},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }
}
