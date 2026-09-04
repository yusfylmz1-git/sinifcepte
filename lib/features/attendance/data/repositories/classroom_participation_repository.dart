import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../schedule/models/schedule_settings.dart';
import '../models/classroom_participation_model.dart';

/// SınıfCepte - Ders İçi Katılım & Günlük Değerlendirme Veri Havuzu (Repository)
class ClassroomParticipationRepository {
  final DatabaseHelper _dbHelper;

  ClassroomParticipationRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Belirtilen sınıf, tarih ve ders saati için mevcut oturumu getirir veya yeni başlatır
  Future<ClassroomParticipationSession> getOrCreateSession({
    required int classId,
    required String date,
    required int lessonHour,
    String? subjectName,
    String? className,
  }) async {
    try {
      await _dbHelper.ensureParticipationTablesExist();
      final db = await _dbHelper.database;

      // 1. Sınıf adını ve branşını al
      String resolvedClassName = className ?? 'Sınıf';
      String resolvedSubject = subjectName ?? 'Ders';

      final classRows = await db.query(
        'classes',
        where: 'id = ?',
        whereArgs: [classId],
        limit: 1,
      );
      if (classRows.isNotEmpty) {
        resolvedClassName = classRows.first['name'] as String? ?? resolvedClassName;
        resolvedSubject = classRows.first['subject'] as String? ?? resolvedSubject;
      }

      // 2. Mevcut oturumu ara
      final sessionRows = await db.query(
        'participation_sessions',
        where: 'class_id = ? AND date = ? AND lesson_hour = ?',
        whereArgs: [classId, date, lessonHour],
        limit: 1,
      );

      // 3. Sınıftaki tüm aktif öğrencileri çek (okul numarasına göre küçükten büyüğe)
      final studentRows = await db.query(
        'students',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'school_number ASC, first_name ASC',
      );

      if (sessionRows.isNotEmpty) {
        final sessionMap = sessionRows.first;
        final sessionId = sessionMap['id'] as int;

        // Mevcut kayıtları çek
        final recordRows = await db.rawQuery('''
          SELECT pr.*, s.first_name, s.last_name, s.school_number, s.gender
          FROM participation_records pr
          JOIN students s ON pr.student_id = s.id
          WHERE pr.session_id = ?
          ORDER BY s.school_number ASC, s.first_name ASC
        ''', [sessionId]);

        final Map<int, Map<String, dynamic>> existingRecordByStudentId = {
          for (var r in recordRows) (r['student_id'] as int): r,
        };

        // Sınıftaki tüm öğrencileri kapsayacak şekilde birleştir
        final List<StudentParticipationEvaluation> evaluations = [];
        for (var s in studentRows) {
          final sId = s['id'] as int;
          final sName = '${s['first_name']} ${s['last_name'] ?? ''}'.trim();
          final sNum = (s['school_number'] as int?) ?? 0;
          final sGender = (s['gender'] as String?) ?? 'Erkek';

          if (existingRecordByStudentId.containsKey(sId)) {
            evaluations.add(StudentParticipationEvaluation.fromMap(
              existingRecordByStudentId[sId]!,
              studentNameFallback: sName,
              studentNumberFallback: sNum,
              genderFallback: sGender,
            ));
          } else {
            // Yeni eklenen öğrenci varsa varsayılan kayıt (3 Yıldız, Ödev Tam, Materyal Tam, Vaktinde)
            evaluations.add(StudentParticipationEvaluation(
              studentId: sId,
              studentName: sName,
              studentNumber: sNum,
              gender: sGender,
              homeworkStatus: HomeworkStatus.done,
              materialsStatus: MaterialsStatus.ready,
              arrivalStatus: ArrivalStatus.onTime,
              starsCount: 3,
            ));
          }
        }

        return ClassroomParticipationSession.fromMap(
          sessionMap,
          classNameFallback: resolvedClassName,
          evaluations: evaluations,
        );
      } else {
        // Yeni oturum: Sınıfın tüm öğrencilerini varsayılan değerlerle hazırla (Hepsi Seçili: 3 Yıldız, Ödev, Materyal, Zamanında)
        final List<StudentParticipationEvaluation> defaultEvals = studentRows.map((s) {
          final sId = s['id'] as int;
          final sName = '${s['first_name']} ${s['last_name'] ?? ''}'.trim();
          final sNum = (s['school_number'] as int?) ?? 0;
          final sGender = (s['gender'] as String?) ?? 'Erkek';
          return StudentParticipationEvaluation(
            studentId: sId,
            studentName: sName,
            studentNumber: sNum,
            gender: sGender,
            homeworkStatus: HomeworkStatus.done,
            materialsStatus: MaterialsStatus.ready,
            arrivalStatus: ArrivalStatus.onTime,
            starsCount: 3,
          );
        }).toList();

        return ClassroomParticipationSession(
          classId: classId,
          className: resolvedClassName,
          date: date,
          lessonHour: lessonHour,
          subjectName: resolvedSubject,
          evaluations: defaultEvals,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('ClassroomParticipationRepository.getOrCreateSession hatası: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Oturumu ve tüm öğrenci değerlendirmelerini tek bir atomik transaction ile kaydeder
  Future<int> saveSession(ClassroomParticipationSession session) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        int sessionId;

        if (session.id != null) {
          sessionId = session.id!;
          await txn.update(
            'participation_sessions',
            session.toMap(),
            where: 'id = ?',
            whereArgs: [sessionId],
          );
          // Eski kayıtları temizle
          await txn.delete(
            'participation_records',
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
        } else {
          sessionId = await txn.insert('participation_sessions', session.toMap());
        }

        // Öğrenci kayıtlarını toplu ekle
        final batch = txn.batch();
        for (var eval in session.evaluations) {
          batch.insert('participation_records', eval.toMap(sessionId));
        }
        await batch.commit(noResult: true);

        return sessionId;
      });
    } catch (e, stackTrace) {
      debugPrint('ClassroomParticipationRepository.saveSession hatası: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Tek bir öğrencinin dönemlik kümülatif katılım, ödev ve yıldız istatistiklerini hesaplar
  Future<StudentParticipationSummaryStats> getStudentSummaryStats(int studentId) async {
    try {
      final db = await _dbHelper.database;

      final studentRow = await db.query(
        'students',
        where: 'id = ?',
        whereArgs: [studentId],
        limit: 1,
      );

      String sName = 'Öğrenci';
      int sNum = 0;
      if (studentRow.isNotEmpty) {
        final s = studentRow.first;
        sName = '${s['first_name']} ${s['last_name'] ?? ''}'.trim();
        sNum = (s['school_number'] as int?) ?? 0;
      }

      final records = await db.query(
        'participation_records',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );

      int totalSessions = records.length;
      int hwDone = 0;
      int hwPartial = 0;
      int hwNone = 0;
      int matReady = 0;
      int totalStars = 0;
      int speakingTurns = 0;
      final List<String> tags = [];
      final List<String> notes = [];

      for (var r in records) {
        // Varsayilan 'yapti' idi: ISARETLENMEMIS kayit "odevini yapti"
        // sayiliyordu. Bu, sinif raporundaki hatanin tek ogrenci
        // ozetindeki kopyasiydi.
        final hw = r['homework_status'] as String? ?? 'bilinmiyor';
        if (hw == 'yapti') {
          hwDone++;
        } else if (hw == 'eksik') {
          hwPartial++;
        } else if (hw == 'yapmadi') {
          hwNone++;
        }

        final mat = r['materials_status'] as String? ?? 'bilinmiyor';
        if (mat == 'tam') {
          matReady++;
        }

        totalStars += (r['stars_count'] as int?) ?? 0;
        speakingTurns += (r['speaking_turns'] as int?) ?? 0;

        if (r['badge_name'] != null && r['badge_name'].toString().isNotEmpty) {
          tags.add(r['badge_name'].toString());
        }
        if (r['note'] != null && r['note'].toString().isNotEmpty) {
          notes.add(r['note'].toString());
        }
      }

      return StudentParticipationSummaryStats(
        studentId: studentId,
        studentName: sName,
        studentNumber: sNum,
        totalSessions: totalSessions,
        homeworkDoneCount: hwDone,
        homeworkPartialCount: hwPartial,
        homeworkNoneCount: hwNone,
        materialsReadyCount: matReady,
        totalStars: totalStars,
        totalSpeakingTurns: speakingTurns,
        topTags: tags,
        recentNotes: notes,
      );
    } catch (e, stackTrace) {
      debugPrint('ClassroomParticipationRepository.getStudentSummaryStats hatası: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Öğrencinin geçmiş derslerdeki katılım ve ödev kayıtlarını (son N ders) çeker
  Future<List<Map<String, dynamic>>> getStudentRecentHistory(int studentId, {int limit = 4}) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT pr.*, ps.date, ps.lesson_hour, ps.subject_name, ps.topic_name
        FROM participation_records pr
        JOIN participation_sessions ps ON pr.session_id = ps.id
        WHERE pr.student_id = ?
        ORDER BY ps.date DESC, ps.lesson_hour DESC
        LIMIT ?
      ''', [studentId, limit]);

      return rows;
    } catch (e, stackTrace) {
      debugPrint('getStudentRecentHistory hatası: $e\n$stackTrace');
      return [];
    }
  }

  /// Sınıfın tüm dönem/yıl boyunca kümülatif katılım, ödev ve yıldız raporunu hesaplar
  Future<Map<String, dynamic>> getClassCumulativeReportData(int classId, {String? startDate, String? endDate}) async {
    try {
      final db = await _dbHelper.database;

      // 1. Sınıf ve Öğrenci Bilgileri
      final classRows = await db.query('classes', where: 'id = ?', whereArgs: [classId], limit: 1);
      final className = classRows.isNotEmpty ? classRows.first['name'] as String : 'Sınıf';
      final subjectName = classRows.isNotEmpty ? classRows.first['subject'] as String? ?? 'Ders' : 'Ders';

      final studentRows = await db.query(
        'students',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'school_number ASC, first_name ASC',
      );

      // 2. Tarih filtresine göre oturumlar
      String sessionWhere = 'class_id = ?';
      List<dynamic> sessionArgs = [classId];
      if (startDate != null && endDate != null) {
        sessionWhere += ' AND date >= ? AND date <= ?';
        sessionArgs.addAll([startDate, endDate]);
      } else if (endDate != null) {
        sessionWhere += ' AND date <= ?';
        sessionArgs.add(endDate);
      } else if (startDate != null) {
        sessionWhere += ' AND date >= ?';
        sessionArgs.add(startDate);
      }

      final sessionRows = await db.query(
        'participation_sessions',
        where: sessionWhere,
        whereArgs: sessionArgs,
        orderBy: 'date ASC, lesson_hour ASC',
      );

      final int totalSessions = sessionRows.length;
      final sessionIds = sessionRows.map((s) => s['id'] as int).toList();

      // TÜM ÖĞRENCİ KAYITLARINI TEK BİR SQL SORGUSU İLE ÇEKİP MAP'LE GRUPLA (0 KASMA, 0 DONMA!)
      final Map<int, List<Map<String, dynamic>>> recordsByStudentId = {};
      if (sessionIds.isNotEmpty) {
        final placeholders = List.filled(sessionIds.length, '?').join(',');
        final allRecords = await db.rawQuery('''
          SELECT * FROM participation_records
          WHERE session_id IN ($placeholders)
        ''', sessionIds);

        for (var r in allRecords) {
          final sId = r['student_id'] as int;
          recordsByStudentId.putIfAbsent(sId, () => []).add(r);
        }
      }

      final List<Map<String, dynamic>> studentReports = [];
      double totalClassHwRateSum = 0;
      double totalClassMatRateSum = 0;
      int totalClassStars = 0;

      for (var s in studentRows) {
        final studentId = s['id'] as int;
        final sName = '${s['first_name']} ${s['last_name'] ?? ''}'.trim();
        final sNum = (s['school_number'] as int?) ?? 0;
        final isFemale = (s['gender'] as String?)?.toLowerCase() == 'kız' || (s['gender'] as String?)?.toLowerCase() == 'k';

        final records = recordsByStudentId[studentId] ?? [];
        int sSessions = records.length;
        int hwDone = 0;
        int hwPartial = 0;
        int hwNone = 0;
        int matReady = 0;
        int stars = 0;
        int speakingTurns = 0;

        // Kac derste ODEV isaretlendi, kac derste MATERYAL isaretlendi.
        //
        // Oranin paydasi bu olmali. Eskiden ders sayisi kullaniliyordu:
        // ogretmen 20 dersin 3'unde isaretlediyse oran %15 cikiyordu,
        // oysa isaretlenen 3 dersin hepsinde odev yapilmis olabilir.
        int hwMarked = 0;
        int matMarked = 0;

        final List<String> tags = [];
        final List<String> notes = [];

        for (var r in records) {
          // Varsayilan 'yapti' idi: ISARETLENMEMIS kayit "odevini yapti"
          // sayiliyordu. Model tarafinda `unknown` yapildi ama rapor
          // sorgusu eski varsayilani kullanmaya devam ediyordu.
          final hw = r['homework_status'] as String? ?? 'bilinmiyor';
          if (hw == 'yapti') {
            hwDone++;
            hwMarked++;
          } else if (hw == 'eksik') {
            hwPartial++;
            hwMarked++;
          } else if (hw == 'yapmadi') {
            hwNone++;
            hwMarked++;
          }

          final mat = r['materials_status'] as String? ?? 'bilinmiyor';
          if (mat == 'tam') {
            matReady++;
            matMarked++;
          } else if (mat == 'eksik') {
            matMarked++;
          }

          stars += (r['stars_count'] as int?) ?? 0;
          speakingTurns += (r['speaking_turns'] as int?) ?? 0;

          if (r['badge_name'] != null && r['badge_name'].toString().isNotEmpty) {
            tags.add(r['badge_name'].toString());
          }
          if (r['note'] != null && r['note'].toString().isNotEmpty) {
            notes.add(r['note'].toString());
          }
        }

        // Payda: ISARETLENEN ders sayisi (ders sayisi degil).
        //
        // Veri yoksa oran 0 doner, 100 DEGIL. Eskiden hic
        // degerlendirilmemis ogrenci raporda "Odev: %100, Yildiz: 3.0"
        // gorunuyordu: veri yoklugu mukemmellik olarak sunuluyordu.
        // Ogretmen bu raporu veli toplantisinda acsa, hic takip
        // etmedigi ogrenci icin "her sey harika" diyecekti.
        final hwRate = hwMarked > 0
            ? ((hwDone + (hwPartial * 0.5)) / hwMarked * 100).clamp(0.0, 100.0)
            : 0.0;
        final matRate =
            matMarked > 0 ? (matReady / matMarked * 100).clamp(0.0, 100.0) : 0.0;
        final avgStars =
            sSessions > 0 ? (stars / sSessions).clamp(0.0, 3.0) : 0.0;

        totalClassHwRateSum += hwRate;
        totalClassMatRateSum += matRate;
        totalClassStars += stars;

        studentReports.add({
          'studentId': studentId,
          'studentName': sName,
          'studentNumber': sNum,
          'isFemale': isFemale,
          'totalEvaluatedSessions': sSessions,
          'homeworkDone': hwDone,
          'homeworkPartial': hwPartial,
          'homeworkNone': hwNone,
          'homeworkRate': hwRate,
          'materialsReady': matReady,
          'materialsRate': matRate,
          'totalStars': stars,
          'averageStars': avgStars,
          // Soz hakki: modulun asil verisi. Raporda hic yoktu.
          'speakingTurns': speakingTurns,
          'isSilent': speakingTurns == 0,
          // Oranin KAC derse dayandigi: "%100 (3 ders)" ile
          // "%100 (20 ders)" ayni sey degil.
          'homeworkMarkedLessons': hwMarked,
          'materialsMarkedLessons': matMarked,
          'tags': tags,
          'notes': notes,
        });
      }

      final studentCount = studentRows.length;
      // Veri yoksa 0, 100 degil (bkz. ogrenci bazindaki aciklama).
      final classAverageHwRate =
          studentCount > 0 ? totalClassHwRateSum / studentCount : 0.0;
      final classAverageMatRate =
          studentCount > 0 ? totalClassMatRateSum / studentCount : 0.0;

      // Sinif geneli soz hakki ozeti.
      final classTotalSpeaking = studentReports.fold<int>(
        0,
        (sum, r) => sum + ((r['speakingTurns'] as int?) ?? 0),
      );
      final silentCount =
          studentReports.where((r) => r['isSilent'] == true).length;

      return {
        'classId': classId,
        'className': className,
        'subjectName': subjectName,
        'totalLessons': totalSessions,
        'studentCount': studentCount,
        'classAverageHwRate': classAverageHwRate,
        'classAverageMatRate': classAverageMatRate,
        'classTotalStars': totalClassStars,
        'classTotalSpeakingTurns': classTotalSpeaking,
        'silentStudentCount': silentCount,
        'students': studentReports,
      };
    } catch (e, stackTrace) {
      debugPrint('getClassCumulativeReportData hatası: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Sınıfın geçmiş değerlendirme oturumlarını listeler
  Future<List<ClassroomParticipationSession>> getClassRecentSessions(int classId, {int limit = 20}) async {
    try {
      final db = await _dbHelper.database;
      final sessionRows = await db.query(
        'participation_sessions',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'date DESC, lesson_hour DESC',
        limit: limit,
      );

      final List<ClassroomParticipationSession> sessions = [];
      for (var row in sessionRows) {
        final sessionId = row['id'] as int;
        final recordRows = await db.rawQuery('''
          SELECT pr.*, s.first_name, s.last_name, s.school_number, s.gender
          FROM participation_records pr
          JOIN students s ON pr.student_id = s.id
          WHERE pr.session_id = ?
          ORDER BY s.school_number ASC, s.first_name ASC
        ''', [sessionId]);

        final evals = recordRows.map((r) => StudentParticipationEvaluation.fromMap(r)).toList();
        sessions.add(ClassroomParticipationSession.fromMap(row, evaluations: evals));
      }

      return sessions;
    } catch (e, stackTrace) {
      debugPrint('ClassroomParticipationRepository.getClassRecentSessions hatası: $e\n$stackTrace');
      return [];
    }
  }

  /// Haftalık ders programından o anki aktif sınıfı ve dersi otomatik tespit eder
  Future<Map<String, dynamic>?> detectActiveLessonFromTimetable() async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      // Hafta sonu ise ders arama
      if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
        return null;
      }

      // Türkçe gün adı eşleme
      const turkishDays = {
        DateTime.monday: 'Pazartesi',
        DateTime.tuesday: 'Salı',
        DateTime.wednesday: 'Çarşamba',
        DateTime.thursday: 'Perşembe',
        DateTime.friday: 'Cuma',
      };

      final todayStr = turkishDays[now.weekday];
      if (todayStr == null) return null;

      final lessonRows = await db.query(
        'dersler',
        where: 'gun = ?',
        whereArgs: [todayStr],
        orderBy: 'ders_saati_index ASC',
      );

      if (lessonRows.isEmpty) return null;

      // 1. Ayarları yükle ve dakika bazlı kesin aralığı hesapla
      final settings = await ScheduleSettings.load();
      final nowMinutes = now.hour * 60 + now.minute;

      int? activeLessonIndex;
      int startMinutes = settings.firstLessonTime.hour * 60 + settings.firstLessonTime.minute;

      for (int i = 0; i < settings.dailyLessonCount; i++) {
        int passedMinutes = i * (settings.lessonDuration + settings.breakDuration);
        if (settings.hasLunchBreak && i >= settings.lunchBreakAfterLesson) {
          passedMinutes += (settings.lunchBreakDuration - settings.breakDuration);
        }
        final lessonStart = startMinutes + passedMinutes;
        final lessonEnd = lessonStart + settings.lessonDuration;

        // Ders sırasında veya ders bitimindeki 5 dakikalık teneffüs payında
        if (nowMinutes >= (lessonStart - 5) && nowMinutes <= (lessonEnd + 5)) {
          activeLessonIndex = i;
          break;
        }
      }

      // Eğer o an tam ders saatinde değilse ama günün ilk dersinden önceyse ilk dersi göster
      if (activeLessonIndex == null) {
        if (nowMinutes < startMinutes && lessonRows.isNotEmpty) {
          activeLessonIndex = (lessonRows.first['ders_saati_index'] as int?) ?? 0;
        }
      }

      if (activeLessonIndex == null) {
        // Gün içinde sonraki en yakın dersi bul
        for (int i = 0; i < settings.dailyLessonCount; i++) {
          int passedMinutes = i * (settings.lessonDuration + settings.breakDuration);
          if (settings.hasLunchBreak && i >= settings.lunchBreakAfterLesson) {
            passedMinutes += (settings.lunchBreakDuration - settings.breakDuration);
          }
          final lessonStart = startMinutes + passedMinutes;
          if (nowMinutes < lessonStart) {
            final hasLesson = lessonRows.any((l) => (l['ders_saati_index'] as int?) == i);
            if (hasLesson) {
              activeLessonIndex = i;
              break;
            }
          }
        }
      }

      // Eşleşen dersi bul
      final matched = lessonRows.where((l) => (l['ders_saati_index'] as int?) == (activeLessonIndex ?? 0)).firstOrNull;
      if (matched == null) return null;

      // Sınıf adından class_id'yi bul
      final className = matched['sinif'] as String? ?? '';
      if (className.isNotEmpty) {
        final classRows = await db.query(
          'classes',
          where: 'name = ?',
          whereArgs: [className],
          limit: 1,
        );
        if (classRows.isNotEmpty) {
          return {
            'class_id': classRows.first['id'] as int,
            'class_name': className,
            'subject_name': matched['ders_adi'] as String? ?? 'Ders',
            'lesson_hour': (matched['ders_saati_index'] as int? ?? 0) + 1,
            'is_live': activeLessonIndex != null,
          };
        }
      }

      return {
        'class_name': className,
        'subject_name': matched['ders_adi'] as String? ?? 'Ders',
        'lesson_hour': (matched['ders_saati_index'] as int? ?? 0) + 1,
        'is_live': activeLessonIndex != null,
      };
    } catch (e, stackTrace) {
      debugPrint('detectActiveLessonFromTimetable hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Akademik takvim boyunca (tatiller ve hafta sonları hariç) tüm sınıflar için
  /// henüz değerlendirilmemiş dersleri otomatik olarak 100% tam puanla (3 Yıldız, Ödev Tam, Materyal Tam, Vaktinde) doldurur
  Future<int> autoFillAcademicYearBaseline({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      // Varsayılan akademik yıl sınırları: 2025-09-08'den bugüne veya dönem sonuna (2026-06-19)
      final start = startDate ?? DateTime(2025, 9, 8);
      final end = endDate ?? (now.isAfter(DateTime(2026, 6, 19)) ? DateTime(2026, 6, 19) : now);

      if (start.isAfter(end)) return 0;

      // 1. Resmi Tatil ve Ara Tatil Tarihlerini Çek
      final holidayRows = await db.query('academic_calendar');
      final Set<String> holidayDates = {};
      for (var row in holidayRows) {
        final sStr = row['start_date'] as String?;
        final eStr = row['end_date'] as String?;
        if (sStr != null) {
          final sDate = DateTime.tryParse(sStr);
          final eDate = eStr != null ? DateTime.tryParse(eStr) : sDate;
          if (sDate != null && eDate != null) {
            var cur = sDate;
            while (!cur.isAfter(eDate)) {
              holidayDates.add(cur.toIso8601String().substring(0, 10));
              cur = cur.add(const Duration(days: 1));
            }
          }
        }
      }

      // 2. Tüm Sınıfları ve Öğrencileri Çek
      final classRows = await db.query('classes');
      if (classRows.isEmpty) return 0;

      int insertedSessionsCount = 0;

      for (var classRow in classRows) {
        final classId = classRow['id'] as int;
        final className = classRow['name'] as String? ?? 'Sınıf';
        final subjectName = classRow['subject'] as String? ?? 'Ders';

        final studentRows = await db.query(
          'students',
          where: 'class_id = ?',
          whereArgs: [classId],
        );
        if (studentRows.isEmpty) continue;

        // Mevcut oturumları çek (Üzerine yazmamak için)
        final existingSessionRows = await db.query(
          'participation_sessions',
          where: 'class_id = ?',
          whereArgs: [classId],
        );
        final Set<String> existingSessionKeys = {
          for (var s in existingSessionRows)
            '${s['date']}_${s['lesson_hour']}',
        };

        // Tarih aralığında hafta içi ve tatil olmayan günleri tara
        var currentDay = start;
        while (!currentDay.isAfter(end)) {
          final isWeekend = currentDay.weekday == DateTime.saturday || currentDay.weekday == DateTime.sunday;
          final dateStr = currentDay.toIso8601String().substring(0, 10);
          final isHoliday = holidayDates.contains(dateStr);

          if (!isWeekend && !isHoliday) {
            // Varsayılan olarak 1. ders saatini doldur
            const lessonHour = 1;
            final key = '${dateStr}_$lessonHour';

            if (!existingSessionKeys.contains(key)) {
              // Oturumu ve öğrencileri tam puanla ekle
              await db.transaction((txn) async {
                final sessionId = await txn.insert('participation_sessions', {
                  'class_id': classId,
                  'class_name': className,
                  'date': dateStr,
                  'lesson_hour': lessonHour,
                  'subject_name': subjectName,
                });

                final batch = txn.batch();
                for (var s in studentRows) {
                  batch.insert('participation_records', {
                    'session_id': sessionId,
                    'student_id': s['id'] as int,
                    'homework_status': 'yapti',
                    'materials_status': 'tam',
                    'arrival_status': 'vaktinde',
                    'stars_count': 3,
                    'badge_name': null,
                    'note': null,
                  });
                }
                await batch.commit(noResult: true);
              });
              existingSessionKeys.add(key);
              insertedSessionsCount++;
            }
          }
          currentDay = currentDay.add(const Duration(days: 1));
        }
      }

      return insertedSessionsCount;
    } catch (e, stackTrace) {
      debugPrint('autoFillAcademicYearBaseline hatası: $e\n$stackTrace');
      return 0;
    }
  }
}

