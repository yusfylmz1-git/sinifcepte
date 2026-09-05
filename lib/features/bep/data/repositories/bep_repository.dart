import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/student_model.dart';
import '../models/bep_models.dart';

class BepRepository {
  BepRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  static List<BepCommitteeMember> defaultCommittee({
    required String teacherName,
    required String principalName,
    required bool isHomeroom,
    required StudentModel student,
  }) {
    return [
      BepCommitteeMember(
        role: 'Kurul başkanı (müdür / md. yrd.)',
        name: principalName,
      ),
      const BepCommitteeMember(role: 'Rehber öğretmen', name: ''),
      BepCommitteeMember(
        role: 'Sınıf / şube rehber öğretmeni',
        name: isHomeroom ? teacherName : '',
      ),
      BepCommitteeMember(role: 'Ders öğretmeni', name: teacherName),
      BepCommitteeMember(
        role: 'Veli',
        name: student.parentName?.trim() ?? '',
      ),
      BepCommitteeMember(role: 'Öğrenci', name: student.fullName),
    ];
  }

  Future<BepPlan> createPlan({
    required StudentModel student,
    required int classId,
    required String subject,
    required String subjectCode,
    required int gradeLevel,
    required String teacherName,
    required String principalName,
    required bool isHomeroom,
    String? academicYear,
    bool copyFromPreviousYear = false,
    /// Gecen yildan kopyalarken "Yeterli" isaretli amaclari atla.
    /// Ogrenci o amaci kazandiysa yeni yil tekrar calisilmaz.
    bool yeterliHaricTut = true,
    BepPlacement placement = BepPlacement.inclusion,
    BepProgramKind programKind = BepProgramKind.general,
    String schoolName = '',
    String diagnosis = '',
    BepTrack? track,
    String startMonth = 'Eylül',
  }) async {
    sonDevir = null;
    final year = academicYear ?? AppDateFormatter.academicYearLabel();
    final subjectClean = subject.trim();
    final code = subjectCode.trim();
    if (student.id == null) {
      throw StateError('Öğrenci kaydı yok.');
    }
    if (subjectClean.isEmpty || code.isEmpty) {
      throw StateError('Ders veya gelişim alanı seçilmedi.');
    }
    if (gradeLevel < 0 || gradeLevel > 12) {
      throw StateError('Kademe 0-12 olmalı.');
    }
    final resolvedTrack = track ??
        BepTrack.infer(programKind: programKind, gradeLevel: gradeLevel);
    final resolvedKind = track?.programKind ?? programKind;
    if (resolvedKind == BepProgramKind.general && gradeLevel < 1) {
      throw StateError('İlköğretim/lise için sınıf seviyesi 1-12 seçin.');
    }

    final db = await _db.database;
    final existing = await db.query(
      'bep_plans',
      where: 'student_id = ? AND academic_year = ? AND subject_code = ?',
      whereArgs: [student.id, year, code],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return BepPlan.fromMap(existing.first);
    }

    final now = DateTime.now();
    final plan = BepPlan(
      studentId: student.id!,
      classId: classId,
      academicYear: year,
      subject: subjectClean,
      subjectCode: code,
      gradeLevel: gradeLevel,
      placement: placement,
      programKind: resolvedKind,
      track: resolvedTrack,
      startMonth: startMonth.trim().isEmpty ? 'Eylül' : startMonth.trim(),
      schoolName: schoolName.trim(),
      diagnosis: diagnosis.trim(),
      committee: defaultCommittee(
        teacherName: teacherName,
        principalName: principalName,
        isHomeroom: isHomeroom,
        student: student,
      ),
      createdAt: now,
      updatedAt: now,
    );

    final id = await db.insert('bep_plans', plan.toMap()..remove('id'));
    var created = plan.copyWith(id: id);

    if (copyFromPreviousYear) {
      final prev = await _previousPlan(
        studentId: student.id!,
        subjectCode: code,
        beforeYear: year,
      );
      if (prev?.id != null) {
        // KUNYE DE DEVREDILIR.
        //
        // Once yalnizca amaclar kopyalaniyordu; tani, RAM karari,
        // performans ve uc ortam duzenlemesi her yil sifirdan
        // dolduruluyordu. Bunlar yildan yila nadiren degisir.
        //
        // Cagride ACIKCA verilen deger ustundur: ogretmen dialogda
        // okul adi veya tani yazdiysa o korunur.
        created = created.copyWith(
          diagnosis: diagnosis.trim().isEmpty ? prev!.diagnosis : null,
          ramDecision: prev!.ramDecision,
          performanceLevel: prev.performanceLevel,
          physicalArrangements: prev.physicalArrangements,
          socialArrangements: prev.socialArrangements,
          digitalSupports: prev.digitalSupports,
          defaultCriterion: prev.defaultCriterion,
          schoolName: schoolName.trim().isEmpty ? prev.schoolName : null,
        );
        await updatePlan(created);

        // Sinif degistiyse kazanim bagi koparilir.
        final sinifDegisti = prev.gradeLevel != gradeLevel;
        sonDevir = await cloneGoals(
          fromPlanId: prev.id!,
          toPlanId: id,
          yeterliHaricTut: yeterliHaricTut,
          kazanimBagiKopsun: sinifDegisti,
        );
      }
    }

    return created;
  }

  /// Son [createPlan] cagrisinin devir sonucu.
  ///
  /// Ogretmene "kac amac geldi" diye bildirmek icin; kopyalama sessizce
  /// hicbir sey yapmadiysa bunu gormeli.
  ({int kopyalanan, int elenen})? sonDevir;

  Future<BepPlan?> _previousPlan({
    required int studentId,
    required String subjectCode,
    required String beforeYear,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'bep_plans',
      where: 'student_id = ? AND subject_code = ? AND academic_year < ?',
      whereArgs: [studentId, subjectCode, beforeYear],
      orderBy: 'academic_year DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BepPlan.fromMap(rows.first);
  }

  /// Bir plandan otekine amac kopyalar — yil devrinin govdesi.
  ///
  /// ## Neden bu kadar secenek var
  /// Once bu metot her seyi oldugu gibi kopyaliyordu ve uc kusuru
  /// vardi:
  ///
  /// 1. `materials` ve `assessment` **hic tasinmiyordu**. Bu iki alan
  ///    modele sonradan eklenmis, klona yazilmayi unutulmus; ogretmen
  ///    her yil ayni materyalleri yeniden seciyordu.
  /// 2. Ogrencinin **kazandigi** amaclar da kopyalaniyordu. Yeterli
  ///    isaretli bir amac yeni yil tekrar calisilmaz; ogretmen tek tek
  ///    silmek zorunda kaliyordu.
  /// 3. Ogrenci ust sinifa gecince **eski sinifin kazanim kodu**
  ///    tasiniyordu. Kod sinifa aittir (2153 kodun 1877'si tek bir
  ///    sinifa ait) ve yeni planin bankasi yalnizca kendi kademesini
  ///    yukluyor: eski kod hicbir seye eslesmez, yalnizca resmi
  ///    evrakta yanlis referans birakir.
  ///
  /// Degerlendirme gecmisi (`bep_evaluations`) KOPYALANMAZ: o gecen
  /// yilin kaydidir, yeni plan sifirdan baslar.
  ///
  /// Geriye kac amacin kopyalandigini ve kacinin elendigini doner.
  Future<({int kopyalanan, int elenen})> cloneGoals({
    required int fromPlanId,
    required int toPlanId,
    bool yeterliHaricTut = false,
    bool kazanimBagiKopsun = false,
  }) async {
    final longs = await longGoals(fromPlanId);
    var kopyalanan = 0;
    var elenen = 0;

    for (final long in longs) {
      final alinacak = <BepShortGoal>[];
      for (final short in long.shorts) {
        if (yeterliHaricTut &&
            short.latestStatus == BepEvalStatus.achieved) {
          elenen++;
          continue;
        }
        alinacak.add(short);
      }
      // Butun kisa amaclari elenen uzun amac ACILMAZ: bos baslik
      // resmi belgede eksik doldurulmus gibi duruyor.
      if (alinacak.isEmpty) continue;

      final newLongId = await insertLongGoal(
        BepLongGoal(
          planId: toPlanId,
          title: long.title,
          orderIndex: long.orderIndex,
        ),
      );
      for (final short in alinacak) {
        await insertShortGoal(
          BepShortGoal(
            longGoalId: newLongId,
            condition: short.condition,
            behavior: short.behavior,
            criterion: short.criterion,
            method: short.method,
            // Once bu ikisi dusuyordu.
            materials: short.materials,
            assessment: short.assessment,
            // Sinif degistiyse kazanim bagi kopar; amac METNI kalir.
            outcomeCode: kazanimBagiKopsun ? null : short.outcomeCode,
            outcomeDescription:
                kazanimBagiKopsun ? null : short.outcomeDescription,
            orderIndex: short.orderIndex,
          ),
        );
        kopyalanan++;
      }
    }
    return (kopyalanan: kopyalanan, elenen: elenen);
  }

  Future<List<BepPlan>> plansForStudent(int studentId, {String? year}) async {
    final db = await _db.database;
    final rows = await db.query(
      'bep_plans',
      where: year == null ? 'student_id = ?' : 'student_id = ? AND academic_year = ?',
      whereArgs: year == null ? [studentId] : [studentId, year],
      orderBy: 'subject ASC',
    );
    return rows.map(BepPlan.fromMap).toList();
  }

  Future<BepPlan?> getPlan(int id) async {
    final db = await _db.database;
    final rows = await db.query('bep_plans', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return BepPlan.fromMap(rows.first);
  }

  Future<void> updatePlan(BepPlan plan) async {
    if (plan.id == null) return;
    final db = await _db.database;
    await db.update(
      'bep_plans',
      plan.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> deletePlan(int id) async {
    final db = await _db.database;
    await db.delete('bep_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BepStudentSummary>> summariesForClass({
    required List<StudentModel> students,
    required String academicYear,
  }) async {
    if (students.isEmpty) return const [];
    final db = await _db.database;
    final out = <BepStudentSummary>[];
    for (final s in students) {
      if (s.id == null) continue;
      final plans = await db.query(
        'bep_plans',
        where: 'student_id = ? AND academic_year = ?',
        whereArgs: [s.id, academicYear],
      );
      var shorts = 0;
      var achieved = 0;
      final items = <BepPlanListItem>[];
      for (final p in plans) {
        final planId = p['id'] as int;
        var planShorts = 0;
        var planAchieved = 0;
        final longRows = await db.query(
          'bep_long_goals',
          where: 'plan_id = ?',
          whereArgs: [planId],
        );
        for (final l in longRows) {
          final shortRows = await db.query(
            'bep_short_goals',
            where: 'long_goal_id = ?',
            whereArgs: [l['id']],
          );
          planShorts += shortRows.length;
          for (final sh in shortRows) {
            final ev = await db.query(
              'bep_evaluations',
              where: 'short_goal_id = ?',
              whereArgs: [sh['id']],
              orderBy: 'evaluated_at DESC, id DESC',
              limit: 1,
            );
            if (ev.isNotEmpty && ev.first['status'] == BepEvalStatus.achieved.id) {
              planAchieved++;
            }
          }
        }
        shorts += planShorts;
        achieved += planAchieved;
        items.add(BepPlanListItem(
          planId: planId,
          subject: p['subject'] as String? ?? '',
          subjectCode: p['subject_code'] as String? ?? '',
          gradeLevel: p['grade_level'] as int? ?? 0,
          shortGoalCount: planShorts,
          achievedCount: planAchieved,
        ));
      }
      out.add(BepStudentSummary(
        studentId: s.id!,
        studentName: s.fullName,
        schoolNumber: s.schoolNumber,
        planCount: plans.length,
        shortGoalCount: shorts,
        achievedCount: achieved,
        subjects: items.map((e) => e.subject).where((n) => n.isNotEmpty).toList(),
        plans: items,
      ));
    }
    return out;
  }

  Future<List<BepLongGoal>> longGoals(int planId) async {
    final db = await _db.database;
    final longs = await db.query(
      'bep_long_goals',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'order_index ASC, id ASC',
    );
    final result = <BepLongGoal>[];
    for (final l in longs) {
      final goal = BepLongGoal.fromMap(l);
      final shorts = await db.rawQuery('''
        SELECT s.*, (
          SELECT e.status FROM bep_evaluations e
          WHERE e.short_goal_id = s.id
          -- `id DESC` ikincil sira: ayni milisaniyede iki
          -- degerlendirme yapilirsa `evaluated_at` hangisinin SON
          -- oldugunu ayirt edemiyor. Toplu isaretlemede bu sik
          -- oluyor (30 amac ayni anda yaziliyor).
          ORDER BY e.evaluated_at DESC, e.id DESC LIMIT 1
        ) AS latest_status
        FROM bep_short_goals s
        WHERE s.long_goal_id = ?
        ORDER BY s.order_index ASC, s.id ASC
      ''', [goal.id]);
      result.add(goal.copyWith(
        shorts: shorts.map(BepShortGoal.fromMap).toList(),
      ));
    }
    return result;
  }

  Future<int> insertLongGoal(BepLongGoal goal) async {
    final db = await _db.database;
    return db.insert('bep_long_goals', goal.toMap()..remove('id'));
  }

  Future<void> updateLongGoalTitle(int id, String title) async {
    final db = await _db.database;
    await db.update(
      'bep_long_goals',
      {'title': title.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteLongGoal(int id) async {
    final db = await _db.database;
    await db.delete('bep_long_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertShortGoal(BepShortGoal goal) async {
    if (!goal.isComplete) {
      throw StateError(
        'Kısa amaçta koşul ve davranış boş bırakılamaz.',
      );
    }
    final db = await _db.database;
    return db.insert('bep_short_goals', goal.toMap()..remove('id'));
  }

  Future<void> updateShortGoal(BepShortGoal goal) async {
    if (goal.id == null) return;
    if (!goal.isComplete) {
      throw StateError(
        'Kısa amaçta koşul ve davranış boş bırakılamaz.',
      );
    }
    final db = await _db.database;
    await db.update(
      'bep_short_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> deleteShortGoal(int id) async {
    final db = await _db.database;
    await db.delete('bep_short_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addEvaluation({
    required int shortGoalId,
    required BepEvalStatus status,
    String note = '',
  }) async {
    final db = await _db.database;
    await db.insert(
      'bep_evaluations',
      BepEvaluation(
        shortGoalId: shortGoalId,
        status: status,
        note: note,
        evaluatedAt: DateTime.now(),
      ).toMap()
        ..remove('id'),
    );
  }

  /// Kazanımı plana alır veya çıkarır. Öğretmen amaç yazmaz.
  Future<void> toggleOutcomeOnPlan({
    required int planId,
    required String unitTitle,
    required String outcomeCode,
    required String outcomeDescription,
    required String studentFirstName,
    required bool selected,
  }) async {
    final goals = await longGoals(planId);
    BepShortGoal? existing;
    BepLongGoal? parent;
    for (final g in goals) {
      for (final s in g.shorts) {
        final sameCode = outcomeCode.isNotEmpty && s.outcomeCode == outcomeCode;
        final sameText = outcomeCode.isEmpty &&
            (s.outcomeDescription ?? '') == outcomeDescription;
        if (sameCode || sameText) {
          existing = s;
          parent = g;
        }
      }
    }

    if (!selected) {
      if (existing?.id != null) {
        await deleteShortGoal(existing!.id!);
        if (parent?.id != null) {
          final leftover = await longGoals(planId);
          final still = leftover.where((g) => g.id == parent!.id).firstOrNull;
          if (still != null && still.shorts.isEmpty) {
            await deleteLongGoal(still.id!);
          }
        }
      }
      return;
    }

    if (existing != null) return;

    final longTitle = unitTitle.trim().isEmpty ? 'Bireysel amaçlar' : unitTitle.trim();
    var long = goals.where((g) => g.title == longTitle).firstOrNull;
    final longId = long?.id ??
        await insertLongGoal(BepLongGoal(
          planId: planId,
          title: longTitle,
          orderIndex: goals.length,
        ));

    await insertShortGoal(BepShortGoal.fromOutcomeSeed(
      longGoalId: longId,
      studentFirstName: studentFirstName,
      outcomeCode: outcomeCode,
      outcomeDescription: outcomeDescription,
      orderIndex: long?.shorts.length ?? 0,
    ));
  }

  String _coarseKey(String code, String description) {
    final c = code.trim();
    if (c.isNotEmpty) return c;
    return 'd:${description.trim()}';
  }

  Future<Map<String, bool>> coarseForPlan(int planId) async {
    final db = await _db.database;
    final rows = await db.query(
      'bep_coarse',
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
    return {
      for (final r in rows)
        r['outcome_code'] as String: (r['can_do'] as int? ?? 0) == 1,
    };
  }

  /// Kaba değerlendirme: [canDo] true = Yapıyor, false = Yapamıyor (plana alınır).
  Future<void> setCoarse({
    required int planId,
    required String unitTitle,
    required String outcomeCode,
    required String outcomeDescription,
    required String studentFirstName,
    required bool canDo,
  }) async {
    final db = await _db.database;
    final key = _coarseKey(outcomeCode, outcomeDescription);
    await db.insert(
      'bep_coarse',
      {
        'plan_id': planId,
        'outcome_code': key,
        'outcome_description': outcomeDescription,
        'unit_title': unitTitle,
        'can_do': canDo ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await toggleOutcomeOnPlan(
      planId: planId,
      unitTitle: unitTitle,
      outcomeCode: outcomeCode,
      outcomeDescription: outcomeDescription,
      studentFirstName: studentFirstName,
      selected: !canDo,
    );
  }

  Future<bool> hasPreviousYear({
    required int studentId,
    required String subjectCode,
    required String year,
  }) async {
    final prev = await _previousPlan(
      studentId: studentId,
      subjectCode: subjectCode,
      beforeYear: year,
    );
    return prev != null;
  }
}
