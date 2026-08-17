import '../models/class_model.dart';
import '../../core/database/database_helper.dart';

/// Sınıf Veritabanı Erişim Katmanı (ClassRepository)
class ClassRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertClass(ClassModel classModel) async {
    final db = await _dbHelper.database;
    return await db.insert('classes', classModel.toMap());
  }

  Future<List<ClassModel>> getAllClasses() async {
    final db = await _dbHelper.database;
    final maps = await db.query('classes', orderBy: 'name ASC');
    return maps.map((map) => ClassModel.fromMap(map)).toList();
  }

  Future<ClassModel?> getClassById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('classes', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return ClassModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateClass(ClassModel classModel) async {
    final db = await _dbHelper.database;
    return await db.update(
      'classes',
      classModel.toMap(),
      where: 'id = ?',
      whereArgs: [classModel.id],
    );
  }

  Future<int> deleteClass(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('classes', where: 'id = ?', whereArgs: [id]);
  }
}
