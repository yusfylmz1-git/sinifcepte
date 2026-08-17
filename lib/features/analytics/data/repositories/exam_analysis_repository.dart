import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../models/exam_analysis_model.dart';

/// SınıfCepte - Sınav Analizi Veritabanı Deposu (ExamAnalysisRepository)
class ExamAnalysisRepository {
  final DatabaseHelper _dbHelper;

  ExamAnalysisRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Kayıtlı tüm sınavların özet listesini getirir
  Future<List<ExamAnalysisModel>> getAllExams() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('sinavlar', orderBy: 'tarih DESC');

      final List<ExamAnalysisModel> exams = [];
      for (final map in maps) {
        final sinavId = map['id'] as int;
        // Notları çek
        final studentRows = await db.rawQuery(
          '''
          SELECT sinav_notlari.*, students.school_number as numara
          FROM sinav_notlari
          LEFT JOIN students ON sinav_notlari.ogrenci_id = students.id
          WHERE sinav_notlari.sinav_id = ?
          ORDER BY students.school_number ASC, sinav_notlari.id ASC
          ''',
          [sinavId],
        );
        exams.add(ExamAnalysisModel.fromMap(map, studentRows));
      }
      return exams;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisRepo.getAllExams) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------');
      rethrow;
    }
  }

  /// Belirli bir sınavın tüm detaylarını ve öğrenci notlarını getirir
  Future<ExamAnalysisModel?> getExamById(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('sinavlar', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;

      final studentRows = await db.rawQuery(
        '''
        SELECT sinav_notlari.*, students.school_number as numara
        FROM sinav_notlari
        LEFT JOIN students ON sinav_notlari.ogrenci_id = students.id
        WHERE sinav_notlari.sinav_id = ?
        ORDER BY students.school_number ASC, sinav_notlari.id ASC
        ''',
        [id],
      );

      return ExamAnalysisModel.fromMap(maps.first, studentRows);
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisRepo.getExamById) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------');
      rethrow;
    }
  }

  /// Sınav Analizini kaydeder veya günceller (Transaction ile güvenli)
  Future<int> saveExam(ExamAnalysisModel exam) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        final examMap = exam.toMap();
        int sinavId;

        if (exam.id == null) {
          // Yeni Sınav Ekle
          examMap.remove('id');
          sinavId = await txn.insert('sinavlar', examMap);
        } else {
          // Mevcut Sınavı Güncelle
          sinavId = exam.id!;
          await txn.update(
            'sinavlar',
            examMap,
            where: 'id = ?',
            whereArgs: [sinavId],
          );
          // Eski notları sil
          await txn.delete(
            'sinav_notlari',
            where: 'sinav_id = ?',
            whereArgs: [sinavId],
          );
        }

        // Öğrenci notlarını ekle
        for (final student in exam.studentScores) {
          final notMap = student.toMap(sinavId: sinavId);
          await txn.insert('sinav_notlari', notMap);
        }

        return sinavId;
      });
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisRepo.saveExam) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-------------------------------------------------------------------------');
      rethrow;
    }
  }

  /// Sınavı ve ilişkili notlarını siler (Cascade Delete)
  Future<bool> deleteExam(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('sinav_notlari', where: 'sinav_id = ?', whereArgs: [id]);
        await txn.delete('sinavlar', where: 'id = ?', whereArgs: [id]);
      });
      return true;
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisRepo.deleteExam) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------------');
      rethrow;
    }
  }

  /// Sınıf adına göre öğrencileri veritabanından getirir (Sınav oluşturma ekranı için)
  Future<List<Map<String, dynamic>>> getStudentsForClass(String className) async {
    try {
      final db = await _dbHelper.database;
      // Önce sınıf id'sini bul
      final classRows = await db.query('classes', where: 'name = ?', whereArgs: [className]);
      if (classRows.isEmpty) return [];

      final classId = classRows.first['id'] as int;
      return await db.query(
        'students',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'school_number ASC',
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ExamAnalysisRepo.getStudentsForClass) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------');
      return [];
    }
  }
}
