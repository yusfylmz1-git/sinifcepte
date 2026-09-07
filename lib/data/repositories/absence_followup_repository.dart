import 'package:sqflite/sqflite.dart';

import '../models/absence_followup_model.dart';
import '../models/student_model.dart';
import '../../core/database/database_helper.dart';

/// Devamsiz ogrenci takip erisim katmani (AbsenceFollowupRepository).
///
/// Tum sorgular SINIF + DERS YILI ikilisiyle daraltilir. Yil filtresi
/// olmasaydi gecen yilin devamsiz ogrencileri bu yilin cizelgesine
/// dusardi.
class AbsenceFollowupRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static const String _table = 'absence_followups';

  /// Bu sinifin bu ders yilindaki takip kayitlari.
  Future<List<AbsenceFollowupModel>> getFollowups({
    required int classId,
    required String academicYear,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      _table,
      where: 'class_id = ? AND academic_year = ?',
      whereArgs: [classId, academicYear],
    );
    return maps.map(AbsenceFollowupModel.fromMap).toList();
  }

  /// Ogrenci bilgisiyle birlestirilmis, okul numarasina gore sirali liste.
  ///
  /// Ekran ve PDF ayni siralamayi kullanir; cizelgede sira karisirsa
  /// ogretmen imzaladigi listeyle uygulamadakini eslestiremez.
  Future<List<AbsenceFollowupEntry>> getEntries({
    required int classId,
    required String academicYear,
    required List<StudentModel> students,
  }) async {
    final followups = await getFollowups(
      classId: classId,
      academicYear: academicYear,
    );
    if (followups.isEmpty) return const [];

    final byId = {for (final s in students) s.id: s};
    final entries = <AbsenceFollowupEntry>[];

    for (final f in followups) {
      final student = byId[f.studentId];
      // Ogrenci silinmisse CASCADE kaydi da siler; yine de yaris
      // durumunda (liste onbellekte eski) satir uydurulmasin.
      if (student == null) continue;
      entries.add(
        AbsenceFollowupEntry(
          followup: f,
          schoolNumber: student.schoolNumber,
          fullName: student.fullName,
          parentName: student.parentName,
          parentPhone: student.parentPhone,
        ),
      );
    }

    entries.sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));
    return entries;
  }

  /// Devamsiz olarak isaretle. Zaten isaretliyse kayda dokunmaz.
  ///
  /// `ignore` catismasi bilincli: ogretmen toplu secimde daha once
  /// isaretledigi bir ogrenciyi tekrar isaretlerse yazdigi not ve
  /// nedeni SIFIRLANMAMALI.
  Future<void> mark({
    required int studentId,
    required int classId,
    required String academicYear,
    AbsenceReason reason = AbsenceReason.bilinmiyor,
    String? note,
  }) async {
    final db = await _dbHelper.database;
    await _markInternal(
      db,
      studentId: studentId,
      classId: classId,
      academicYear: academicYear,
      reason: reason,
      note: note,
    );
  }

  /// Birden fazla ogrenciyi isaretler (toplu secim modu).
  ///
  /// Tek islemde: yarim kalirsa liste ile cizelge birbirini tutmazdi.
  Future<void> markBatch({
    required List<int> studentIds,
    required int classId,
    required String academicYear,
  }) async {
    if (studentIds.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final id in studentIds) {
        await _markInternal(
          txn,
          studentId: id,
          classId: classId,
          academicYear: academicYear,
        );
      }
    });
  }

  /// Isaretlemenin ortak govdesi.
  ///
  /// SUBE DEGISIKLIGI TUZAGI: tabloda `UNIQUE(student_id,
  /// academic_year)` var. Ogrenci yil icinde 5-A'dan 5-B'ye
  /// gectiginde eski satir hâlâ eski `class_id` ile duruyor. Duz bir
  /// `insert ... ignore` o satiri gormezden gelir; yeni sube listesi
  /// BOS kalir ama ogretmene "eklendi" denir. Ogrenci ne listede
  /// gorunur ne de yeniden eklenebilir.
  ///
  /// Bu yuzden once mevcut kayit aranir ve varsa yeni subeye TASINIR
  /// — projenin veli kodu kuralindaki gibi: sube degisikliginde bag
  /// kopmaz, tasinir. Ogretmenin yazdigi not ve neden korunur.
  Future<void> _markInternal(
    DatabaseExecutor db, {
    required int studentId,
    required int classId,
    required String academicYear,
    AbsenceReason reason = AbsenceReason.bilinmiyor,
    String? note,
  }) async {
    final now = DateTime.now();

    final mevcut = await db.query(
      _table,
      columns: ['id', 'class_id'],
      where: 'student_id = ? AND academic_year = ?',
      whereArgs: [studentId, academicYear],
      limit: 1,
    );

    if (mevcut.isNotEmpty) {
      // Ayni subedeyse dokunma: yazilmis not ve neden korunmali.
      if (mevcut.first['class_id'] == classId) return;

      await db.update(
        _table,
        {
          'class_id': classId,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [mevcut.first['id']],
      );
      return;
    }

    await db.insert(
      _table,
      AbsenceFollowupModel(
        studentId: studentId,
        classId: classId,
        academicYear: academicYear,
        reason: reason,
        note: note,
        markedAt: now,
        updatedAt: now,
      ).toMap()
        ..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Neden ve notu gunceller.
  ///
  /// `class_id` kosulu SART: ogrenci yil icinde sube degistirirse
  /// (moveStudent) eski subenin kaydi da ayni student_id'yi tasir.
  /// Kosul olmadan bir subeden yapilan duzenleme otekinin notunu da
  /// ezerdi.
  Future<void> updateDetails({
    required int studentId,
    required int classId,
    required String academicYear,
    required AbsenceReason reason,
    String? note,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      _table,
      {
        'reason': reason.code,
        'note': note,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'student_id = ? AND class_id = ? AND academic_year = ?',
      whereArgs: [studentId, classId, academicYear],
    );
  }

  /// Takipten cikar (ogrenci artik devamsiz degil).
  ///
  /// Ogrenciyi SILMEZ; yalnizca devamsizlik kaydini kaldirir.
  /// [updateDetails] ile ayni sinif kosulu gecerli.
  Future<void> unmark({
    required int studentId,
    required int classId,
    required String academicYear,
  }) async {
    final db = await _dbHelper.database;
    await db.delete(
      _table,
      where: 'student_id = ? AND class_id = ? AND academic_year = ?',
      whereArgs: [studentId, classId, academicYear],
    );
  }
}
