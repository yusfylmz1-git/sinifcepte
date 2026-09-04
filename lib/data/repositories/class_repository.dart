import '../models/class_model.dart';
import '../../core/database/database_helper.dart';

/// Sınıf Veritabanı Erişim Katmanı (ClassRepository)
///
/// ## Hesap ayrımı
/// Burada `teacher_uid` süzgeci YOKTUR ve olmasına gerek de yoktur:
/// her öğretmen kendi veritabanı dosyasında çalışır
/// (`DatabaseHelper.openForUid`). Sorgular zaten yalnızca o hesabın
/// verisini görür.
class ClassRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertClass(ClassModel classModel) async {
    final db = await _dbHelper.database;
    if (classModel.isHomeroom) {
      return await db.transaction<int>((txn) async {
        // Tek rehberlik sınıfı kuralı: diğer sınıfların unvanını kaldır.
        await txn.update('classes', {'is_homeroom': 0});
        return await txn.insert('classes', classModel.toMap());
      });
    }
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

  /// Aktif Rehberlik Sınıfını Getir (en fazla 1 adet olabilir)
  Future<ClassModel?> getHomeroomClass() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'classes',
      where: 'is_homeroom = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return ClassModel.fromMap(maps.first);
    }
    return null;
  }

  /// Bir sınıfı Rehberlik Sınıfı olarak ata (diğerlerinden devralır)
  Future<void> setHomeroomClass(int classId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('classes', {'is_homeroom': 0});
      await txn.update(
        'classes',
        {'is_homeroom': 1},
        where: 'id = ?',
        whereArgs: [classId],
      );
    });
  }

  /// Rehberlik sınıfı unvanını kaldır
  Future<void> clearHomeroomClass(int classId) async {
    final db = await _dbHelper.database;
    await db.update(
      'classes',
      {'is_homeroom': 0},
      where: 'id = ?',
      whereArgs: [classId],
    );
  }

  Future<int> updateClass(ClassModel classModel) async {
    final db = await _dbHelper.database;
    if (classModel.isHomeroom) {
      return await db.transaction<int>((txn) async {
        await txn.update(
          'classes',
          {'is_homeroom': 0},
          where: 'id != ?',
          whereArgs: [classModel.id],
        );
        return await txn.update(
          'classes',
          classModel.toMap(),
          where: 'id = ?',
          whereArgs: [classModel.id],
        );
      });
    }
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
