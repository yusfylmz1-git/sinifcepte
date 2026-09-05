import 'dart:convert';

/// BEP değerlendirme durumu. Geçmiş silinmez; her kayıt ayrı satırdır.
enum BepEvalStatus {
  achieved('achieved', 'Yeterli (+)'),
  ongoing('ongoing', 'Devam'),
  needsSupport('needs_support', 'Geliştirilmeli (-)');

  const BepEvalStatus(this.id, this.label);
  final String id;
  final String label;

  String get compactLabel => switch (this) {
        BepEvalStatus.achieved => 'Yeterli',
        BepEvalStatus.ongoing => 'Devam',
        BepEvalStatus.needsSupport => 'Geliştir',
      };

  static BepEvalStatus fromId(String raw) {
    return BepEvalStatus.values.firstWhere(
      (s) => s.id == raw,
      orElse: () => BepEvalStatus.ongoing,
    );
  }
}

/// Öğrencinin yerleştirme türü. Sınıf adından uydurulmaz; öğretmene sorulur.
enum BepPlacement {
  inclusion('inclusion', 'Kaynaştırma / bütünleştirme'),
  specialClass('special_class', 'Özel eğitim sınıfı'),
  specialSchool('special_school', 'Özel eğitim okulu / uygulama'),
  supportRoom('support_room', 'Destek eğitim odası'),
  itinerant('itinerant', 'Gezerek özel eğitim');

  const BepPlacement(this.id, this.label);
  final String id;
  final String label;

  static BepPlacement fromId(String raw) {
    return BepPlacement.values.firstWhere(
      (s) => s.id == raw,
      orElse: () => BepPlacement.inclusion,
    );
  }

  static BepPlacement guess({required String className, required String branch}) {
    final t = '${className.toLowerCase()} ${branch.toLowerCase()}';
    if (t.contains('gezerek')) return BepPlacement.itinerant;
    if (t.contains('destek')) return BepPlacement.supportRoom;
    if (t.contains('uygulama')) return BepPlacement.specialSchool;
    if (t.contains('özel') || t.contains('ozel')) return BepPlacement.specialClass;
    return BepPlacement.inclusion;
  }
}

/// Kazanım bankasının kaynağı.
enum BepProgramKind {
  general('general', 'Genel öğretim (Maarif ders kazanımı)'),
  developmental('developmental', 'Gelişim alanı (özel eğitim)');

  const BepProgramKind(this.id, this.label);
  final String id;
  final String label;

  static BepProgramKind fromId(String raw) {
    return BepProgramKind.values.firstWhere(
      (s) => s.id == raw,
      orElse: () => BepProgramKind.general,
    );
  }
}

/// ErbaaBEP / ORGM tarzı kademe: 1-12 rakamı değil, program ailesi.
enum BepTrack {
  primary(
    'primary',
    'İlköğretim',
    'Kaynaştırma, hafif düzey zihin/otizm, görme ve işitme sınıfları.',
    [1, 2, 3, 4, 5, 6, 7, 8],
  ),
  high(
    'high',
    'Lise',
    'Ortaöğretim genel program.',
    [9, 10, 11, 12],
  ),
  special(
    'special',
    'Özel eğitim',
    'Uygulama okulları, orta/ağır özel eğitim sınıfları.',
    [],
  );

  const BepTrack(this.id, this.label, this.hint, this.grades);
  final String id;
  final String label;
  final String hint;
  final List<int> grades;

  bool get usesCurriculum => grades.isNotEmpty;

  BepProgramKind get programKind =>
      this == BepTrack.special ? BepProgramKind.developmental : BepProgramKind.general;

  BepPlacement get defaultPlacement =>
      this == BepTrack.special ? BepPlacement.specialSchool : BepPlacement.inclusion;

  static const months = [
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
  ];

  static BepTrack fromId(String raw) {
    return BepTrack.values.firstWhere(
      (s) => s.id == raw,
      orElse: () => BepTrack.primary,
    );
  }

  static BepTrack guess({
    required String className,
    required String branch,
    int classGrade = 0,
  }) {
    final placement = BepPlacement.guess(className: className, branch: branch);
    if (placement == BepPlacement.specialClass ||
        placement == BepPlacement.specialSchool) {
      return BepTrack.special;
    }
    if (classGrade >= 9) return BepTrack.high;
    return BepTrack.primary;
  }

  static BepTrack infer({
    required BepProgramKind programKind,
    required int gradeLevel,
  }) {
    if (programKind == BepProgramKind.developmental) return BepTrack.special;
    if (gradeLevel >= 9) return BepTrack.high;
    return BepTrack.primary;
  }
}

class BepCommitteeMember {
  final String role;
  final String name;

  const BepCommitteeMember({required this.role, required this.name});

  Map<String, dynamic> toMap() => {'role': role, 'name': name};

  factory BepCommitteeMember.fromMap(Map<String, dynamic> map) {
    return BepCommitteeMember(
      role: map['role'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }
}

/// MEB kazanımından BEP kısa amacına *tohum*. Kazanım olduğu gibi BEP değildir.
class BepOutcomeSeed {
  final String code;
  final String description;
  final String unitTitle;
  final String subjectCode;
  final String subjectName;

  const BepOutcomeSeed({
    required this.code,
    required this.description,
    required this.unitTitle,
    required this.subjectCode,
    required this.subjectName,
  });
}

class BepPlan {
  final int? id;
  final int studentId;
  final int classId;
  final String academicYear;
  final String subject;
  final String subjectCode;
  final int gradeLevel;
  final BepPlacement placement;
  final BepProgramKind programKind;
  final BepTrack track;
  final String startMonth;

  /// Ogretmenin kendi girdigi plan tarihleri (gg.aa.yyyy).
  ///
  /// Bos birakilirsa [planDateRange] eski davranisi surdurur:
  /// ogretim yili ve baslangic ayindan hesaplar. Once tarih SADECE
  /// hesaplaniyordu ve bitis her zaman 31 Mayis'ti; RAM kararina gore
  /// erken baslayan veya donem ortasinda biten planlar yazilamiyordu.
  final String startDate;
  final String endDate;

  /// Tum satirlar icin varsayilan olcut ("%80" gibi).
  ///
  /// Kisa amacin kendi olcutu bossa tabloda bu kullanilir. Once her
  /// satira "4/5 (%80)" sabiti basiliyordu; ogretmen sinifin duzeyine
  /// gore toplu degistiremiyordu.
  final String defaultCriterion;

  final String schoolName;
  final String diagnosis;
  final String ramDecision;
  final String performanceLevel;

  /// Egitim ortami duzenlemeleri — PDF'in alt blogundaki uc kutu.
  ///
  /// Onceden bu kutular SADECE BASLIK basiyordu; icerik alani hic
  /// yoktu. Ogretmen "one oturtma", "akran destegi" gibi asil BEP
  /// tedbirlerini belgeye yazamiyordu.
  final String physicalArrangements;
  final String socialArrangements;
  final String digitalSupports;
  final List<BepCommitteeMember> committee;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BepPlan({
    this.id,
    required this.studentId,
    required this.classId,
    required this.academicYear,
    required this.subject,
    this.subjectCode = '',
    this.gradeLevel = 0,
    this.placement = BepPlacement.inclusion,
    this.programKind = BepProgramKind.general,
    this.track = BepTrack.primary,
    this.startMonth = 'Eylül',
    this.startDate = '',
    this.endDate = '',
    this.defaultCriterion = '',
    this.schoolName = '',
    this.diagnosis = '',
    this.ramDecision = '',
    this.performanceLevel = '',
    this.physicalArrangements = '',
    this.socialArrangements = '',
    this.digitalSupports = '',
    this.committee = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String get gradeLabel =>
      gradeLevel <= 0 ? 'Gelişim / okul öncesi' : '$gradeLevel. sınıf';

  BepPlan copyWith({
    int? id,
    String? startDate,
    String? endDate,
    String? defaultCriterion,
    String? ramDecision,
    String? performanceLevel,
    String? physicalArrangements,
    String? socialArrangements,
    String? digitalSupports,
    String? schoolName,
    String? diagnosis,
    List<BepCommitteeMember>? committee,
    DateTime? updatedAt,
  }) {
    return BepPlan(
      id: id ?? this.id,
      studentId: studentId,
      classId: classId,
      academicYear: academicYear,
      subject: subject,
      subjectCode: subjectCode,
      gradeLevel: gradeLevel,
      placement: placement,
      programKind: programKind,
      track: track,
      startMonth: startMonth,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      defaultCriterion: defaultCriterion ?? this.defaultCriterion,
      schoolName: schoolName ?? this.schoolName,
      diagnosis: diagnosis ?? this.diagnosis,
      ramDecision: ramDecision ?? this.ramDecision,
      performanceLevel: performanceLevel ?? this.performanceLevel,
      physicalArrangements:
          physicalArrangements ?? this.physicalArrangements,
      socialArrangements: socialArrangements ?? this.socialArrangements,
      digitalSupports: digitalSupports ?? this.digitalSupports,
      committee: committee ?? this.committee,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'class_id': classId,
      'academic_year': academicYear,
      'subject': subject,
      'subject_code': subjectCode,
      'grade_level': gradeLevel,
      'placement': placement.id,
      'program_kind': programKind.id,
      'track': track.id,
      'start_month': startMonth,
      'start_date': startDate,
      'end_date': endDate,
      'default_criterion': defaultCriterion,
      'school_name': schoolName,
      'diagnosis': diagnosis,
      'ram_decision': ramDecision,
      'performance_level': performanceLevel,
      'physical_arrangements': physicalArrangements,
      'social_arrangements': socialArrangements,
      'digital_supports': digitalSupports,
      'committee_json': jsonEncode(committee.map((m) => m.toMap()).toList()),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BepPlan.fromMap(Map<String, dynamic> map) {
    List<BepCommitteeMember> members = const [];
    final raw = map['committee_json'] as String?;
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        members = decoded
            .whereType<Map>()
            .map((e) => BepCommitteeMember.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return BepPlan(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      classId: map['class_id'] as int,
      academicYear: map['academic_year'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      subjectCode: map['subject_code'] as String? ?? '',
      gradeLevel: map['grade_level'] as int? ?? 0,
      placement: BepPlacement.fromId(map['placement'] as String? ?? ''),
      programKind: BepProgramKind.fromId(map['program_kind'] as String? ?? ''),
      track: () {
        final raw = map['track'] as String? ?? '';
        if (raw.isNotEmpty) return BepTrack.fromId(raw);
        return BepTrack.infer(
          programKind: BepProgramKind.fromId(map['program_kind'] as String? ?? ''),
          gradeLevel: map['grade_level'] as int? ?? 0,
        );
      }(),
      startMonth: map['start_month'] as String? ?? 'Eylül',
      startDate: map['start_date'] as String? ?? '',
      endDate: map['end_date'] as String? ?? '',
      defaultCriterion: map['default_criterion'] as String? ?? '',
      schoolName: map['school_name'] as String? ?? '',
      diagnosis: map['diagnosis'] as String? ?? '',
      ramDecision: map['ram_decision'] as String? ?? '',
      performanceLevel: map['performance_level'] as String? ?? '',
      physicalArrangements: map['physical_arrangements'] as String? ?? '',
      socialArrangements: map['social_arrangements'] as String? ?? '',
      digitalSupports: map['digital_supports'] as String? ?? '',
      committee: members,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class BepLongGoal {
  final int? id;
  final int planId;
  final String title;
  final int orderIndex;
  final List<BepShortGoal> shorts;

  const BepLongGoal({
    this.id,
    required this.planId,
    required this.title,
    this.orderIndex = 0,
    this.shorts = const [],
  });

  BepLongGoal copyWith({int? id, String? title, List<BepShortGoal>? shorts}) {
    return BepLongGoal(
      id: id ?? this.id,
      planId: planId,
      title: title ?? this.title,
      orderIndex: orderIndex,
      shorts: shorts ?? this.shorts,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'plan_id': planId,
        'title': title,
        'order_index': orderIndex,
      };

  factory BepLongGoal.fromMap(Map<String, dynamic> map) {
    return BepLongGoal(
      id: map['id'] as int?,
      planId: map['plan_id'] as int,
      title: map['title'] as String? ?? '',
      orderIndex: map['order_index'] as int? ?? 0,
    );
  }
}

class BepShortGoal {
  final int? id;
  final int longGoalId;
  final String condition;
  final String behavior;
  final String criterion;
  final String method;

  /// Kullanilacak materyaller — PDF'te AYRI sutun.
  ///
  /// Onceden yoktu: PDF bu sutuna `_defaultMaterials` sabitini
  /// basiyordu, yani Bilisim dersi icin yazilmis "Akilli Tahta,
  /// Projeksiyon" listesi oz bakim BEP'inde de aynen cikiyordu.
  /// Ogretmen degistiremiyordu.
  final String materials;

  /// Olcme-degerlendirme araclari — PDF'te AYRI sutun.
  ///
  /// Bu da sabitti (`_defaultAssess`). Ayni gerekce.
  final String assessment;

  final String? outcomeCode;
  final String? outcomeDescription;
  final int orderIndex;
  final BepEvalStatus? latestStatus;

  const BepShortGoal({
    this.id,
    required this.longGoalId,
    required this.condition,
    required this.behavior,
    required this.criterion,
    this.method = '',
    this.materials = '',
    this.assessment = '',
    this.outcomeCode,
    this.outcomeDescription,
    this.orderIndex = 0,
    this.latestStatus,
  });

  /// Kaydedilebilir mi?
  ///
  /// Olcut BURADA ARANMAZ. Once araniyordu ve ogretmen otuz amacin
  /// her birine ayni olcutu elle yazmak zorunda kaliyordu. Artik
  /// olcut bos birakilirsa plandaki varsayilan
  /// ([BepPlan.defaultCriterion]) belgeye basiliyor; yani amac yine
  /// olculebilir kaliyor, tekrar eden yazim kalkiyor.
  ///
  /// Kosul ve davranis zorunlu kalir: onlarin yerine gececek plan
  /// duzeyinde bir varsayilan yok.
  bool get isComplete =>
      condition.trim().isNotEmpty && behavior.trim().isNotEmpty;

  /// Erbaram tarzı: kazanımı işaretleyince hazır amaç cümlesi.
  factory BepShortGoal.fromOutcomeSeed({
    required int longGoalId,
    required String studentFirstName,
    required String outcomeCode,
    required String outcomeDescription,
    int orderIndex = 0,
  }) {
    final name = studentFirstName.trim().isEmpty ? 'Öğrenci' : studentFirstName.trim();
    var behavior = outcomeDescription.trim();
    if (behavior.endsWith('.')) behavior = behavior.substring(0, behavior.length - 1);
    return BepShortGoal(
      longGoalId: longGoalId,
      condition: 'Sınıf ortamında',
      behavior: '$name $behavior',
      // Olcut BOS: plandaki varsayilan kullanilsin. Once burada
      // '4/5 (%80)' sabiti vardi ve tohumlanan her amac onu tasidigi
      // icin plan olcutu hicbir zaman devreye girmiyordu.
      criterion: '',
      method: 'Görsel destek ve adım adım pekiştirme',
      materials: 'Çalışma Yaprağı, Görsel Kartlar',
      assessment: 'Ölçüt Bağımlı Ölçü Aracı, Gözlem Formu',
      outcomeCode: outcomeCode,
      outcomeDescription: outcomeDescription,
      orderIndex: orderIndex,
    );
  }

  /// Amac cumlesi: kosul + davranis (+ olcut).
  ///
  /// Olcut ARTIK BOS OLABILIYOR (plan varsayilani devreye giriyor).
  /// Once her durumda ', ' + olcut + '.' ekleniyordu; olcut bosken
  /// belgede "... sayilari okur, ." diye bir artik cikiyordu.
  String get composed {
    final govde = '${condition.trim()} ${behavior.trim()}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final o = criterion.trim();
    if (govde.isEmpty) return o;
    return o.isEmpty ? '$govde.' : '$govde, $o.';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'long_goal_id': longGoalId,
        'condition_text': condition,
        'behavior_text': behavior,
        'criterion_text': criterion,
        'method': method,
        'materials': materials,
        'assessment': assessment,
        'outcome_code': outcomeCode,
        'outcome_description': outcomeDescription,
        'order_index': orderIndex,
      };

  factory BepShortGoal.fromMap(Map<String, dynamic> map) {
    final statusRaw = map['latest_status'] as String?;
    return BepShortGoal(
      id: map['id'] as int?,
      longGoalId: map['long_goal_id'] as int,
      condition: map['condition_text'] as String? ?? '',
      behavior: map['behavior_text'] as String? ?? '',
      criterion: map['criterion_text'] as String? ?? '',
      method: map['method'] as String? ?? '',
      materials: map['materials'] as String? ?? '',
      assessment: map['assessment'] as String? ?? '',
      outcomeCode: map['outcome_code'] as String?,
      outcomeDescription: map['outcome_description'] as String?,
      orderIndex: map['order_index'] as int? ?? 0,
      latestStatus:
          statusRaw == null ? null : BepEvalStatus.fromId(statusRaw),
    );
  }
}

class BepCoarseMark {
  final String code;
  final String description;
  final String unitTitle;
  final bool canDo;

  const BepCoarseMark({
    required this.code,
    required this.description,
    required this.unitTitle,
    required this.canDo,
  });
}

class BepEvaluation {
  final int? id;
  final int shortGoalId;
  final BepEvalStatus status;
  final String note;
  final DateTime evaluatedAt;

  const BepEvaluation({
    this.id,
    required this.shortGoalId,
    required this.status,
    this.note = '',
    required this.evaluatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'short_goal_id': shortGoalId,
        'status': status.id,
        'note': note,
        'evaluated_at': evaluatedAt.toIso8601String(),
      };
}

class BepPlanListItem {
  final int planId;
  final String subject;
  final String subjectCode;
  final int gradeLevel;
  final int shortGoalCount;
  final int achievedCount;

  const BepPlanListItem({
    required this.planId,
    required this.subject,
    required this.subjectCode,
    required this.gradeLevel,
    required this.shortGoalCount,
    required this.achievedCount,
  });
}

class BepStudentSummary {
  final int studentId;
  final String studentName;
  final int schoolNumber;
  final int planCount;
  final int shortGoalCount;
  final int achievedCount;
  final List<String> subjects;
  final List<BepPlanListItem> plans;

  const BepStudentSummary({
    required this.studentId,
    required this.studentName,
    required this.schoolNumber,
    required this.planCount,
    required this.shortGoalCount,
    required this.achievedCount,
    this.subjects = const [],
    this.plans = const [],
  });
}
