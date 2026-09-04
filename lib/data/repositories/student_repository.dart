import '../models/student_model.dart';
import '../../core/database/database_helper.dart';

/// Öğrenci Veritabanı Erişim Katmanı (StudentRepository)
class StudentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Bu sınıfta verilen okul numarası daha önce kullanılmış mı?
  Future<bool> isSchoolNumberTaken({
    required int classId,
    required int schoolNumber,
    int? excludeStudentId,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = ['class_id = ?', 'school_number = ?'];
    final whereArgs = <dynamic>[classId, schoolNumber];

    if (excludeStudentId != null) {
      whereClauses.add('id != ?');
      whereArgs.add(excludeStudentId);
    }

    final result = await db.query(
      'students',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> insertStudent(StudentModel student) async {
    final isTaken = await isSchoolNumberTaken(
      classId: student.classId,
      schoolNumber: student.schoolNumber,
    );
    if (isTaken) {
      throw StateError('Bu sınıfta ${student.schoolNumber} numaralı bir öğrenci zaten mevcut.');
    }

    final db = await _dbHelper.database;
    return await db.insert('students', student.toMap());
  }

  Future<void> insertStudentsBatch(List<StudentModel> students) async {
    if (students.isEmpty) return;

    final db = await _dbHelper.database;
    final classId = students.first.classId;

    // 1. Liste içi mükerrer numara kontrolü
    final seenNumbers = <int>{};
    for (final s in students) {
      if (!seenNumbers.add(s.schoolNumber)) {
        throw StateError('Aktarılmak istenen listede mükerrer okul numarası var: #${s.schoolNumber}');
      }
    }

    // 2. Veritabanındaki mevcut numaralarla çakışma kontrolü
    final existingStudents = await getStudentsByClassId(classId);
    final existingNumbers = existingStudents.map((s) => s.schoolNumber).toSet();

    for (final s in students) {
      if (existingNumbers.contains(s.schoolNumber)) {
        throw StateError('Bu sınıfta #${s.schoolNumber} numaralı öğrenci zaten kayıtlı.');
      }
    }

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
    final isTaken = await isSchoolNumberTaken(
      classId: student.classId,
      schoolNumber: student.schoolNumber,
      excludeStudentId: student.id,
    );
    if (isTaken) {
      throw StateError('Bu sınıfta ${student.schoolNumber} numaralı başka bir öğrenci zaten mevcut.');
    }

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
