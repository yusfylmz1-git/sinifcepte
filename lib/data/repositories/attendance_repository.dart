import 'package:flutter/foundation.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_record_model.dart';
import '../../core/database/database_helper.dart';

/// Ders İçi Katılım Veritabanı Erişim Katmanı (AttendanceRepository)
/// ⚠️ DB tablolarında participation_sessions / participation_records kullanılır.
class AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Oturum ve kayıtları tek bir transaction ile oluştur
  Future<int> createSessionWithRecords({
    required AttendanceSessionModel session,
    required List<AttendanceRecordModel> records,
  }) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        final sessionId = await txn.insert('participation_sessions', session.toMap());

        final batch = txn.batch();
        for (final record in records) {
          final recordWithSession = record.copyWith(sessionId: sessionId);
          batch.insert('participation_records', recordWithSession.toMap());
        }
        await batch.commit(noResult: true);

        return sessionId;
      });
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AttendanceRepository.createSessionWithRecords) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------------------------------');
      rethrow;
    }
  }

  /// Belirli bir sınıfa ait tüm katılım oturumlarını getir
  Future<List<AttendanceSessionModel>> getSessionsByClass(int classId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'participation_sessions',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'date DESC, lesson_hour DESC',
      );
      return maps.map((map) => AttendanceSessionModel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AttendanceRepository.getSessionsByClass) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------------');
      return [];
    }
  }

  /// Belirli bir oturuma ait tüm öğrenci katılım kayıtlarını getir
  Future<List<AttendanceRecordModel>> getRecordsBySession(int sessionId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'participation_records',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      return maps.map((map) => AttendanceRecordModel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AttendanceRepository.getRecordsBySession) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-----------------------------------------------------------------------------------------');
      return [];
    }
  }

  /// Belirli bir oturumu sil (Cascade ile kayıtlar da silinir)
  Future<int> deleteSession(int sessionId) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'participation_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (AttendanceRepository.deleteSession) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-----------------------------------------------------------------------------------');
      return 0;
    }
  }
}
