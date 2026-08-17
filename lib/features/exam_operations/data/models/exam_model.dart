/// SınıfCepte - MEB / ÖSYM / Okul Sınav Takip Modeli
class ExamModel {
  final String id;
  final int? intId;
  final String title; // Örn: LGS, YKS, 10-A 1. Dönem 1. Yazılı
  final String institution; // MEB, ÖSYM, OKUL vb.
  final DateTime examDate;
  final DateTime? applicationDeadline;
  final String? applicationLink;
  final String category; // 'MEB', 'OSYM', 'OKUL'
  final bool isFavorite;
  final bool isSchoolExam;
  final String? className;

  const ExamModel({
    required this.id,
    this.intId,
    required this.title,
    this.institution = 'MEB',
    required this.examDate,
    this.applicationDeadline,
    this.applicationLink,
    required this.category,
    this.isFavorite = false,
    this.isSchoolExam = false,
    this.className,
  });

  bool get isLast24Hours {
    final now = DateTime.now();
    final diff = examDate.difference(now);
    return diff.inHours >= 0 && diff.inHours <= 24;
  }

  bool get isToday => daysRemaining == 0;

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(examDate.year, examDate.month, examDate.day);
    return target.difference(today).inDays;
  }

  bool get isPast => daysRemaining < 0;

  factory ExamModel.fromMap(Map<String, dynamic> map, {bool isFav = false, bool isSchool = false}) {
    final idVal = map['doc_id'] as String? ?? (map['id'] != null ? map['id'].toString() : '');
    final dateStr = map['sinav_tarihi'] as String? ?? '';
    final deadlineStr = map['son_basvuru_tarihi'] as String?;
    final inst = map['kurum'] as String? ?? (isSchool ? 'OKUL' : 'MEB');

    return ExamModel(
      id: idVal,
      intId: map['id'] as int?,
      title: map['sinav_adi'] as String? ?? '',
      institution: inst,
      examDate: DateTime.tryParse(dateStr) ?? DateTime.now(),
      applicationDeadline: deadlineStr != null ? DateTime.tryParse(deadlineStr) : null,
      applicationLink: map['basvuru_linki'] as String?,
      category: isSchool ? 'OKUL' : (inst.toUpperCase().contains('ÖSYM') ? 'OSYM' : 'MEB'),
      isFavorite: isFav,
      isSchoolExam: isSchool,
      className: map['sinif'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (intId != null) 'id': intId,
      'doc_id': id,
      'sinav_adi': title,
      'kurum': institution,
      'sinav_tarihi': examDate.toIso8601String(),
      if (applicationDeadline != null) 'son_basvuru_tarihi': applicationDeadline!.toIso8601String(),
      if (applicationLink != null) 'basvuru_linki': applicationLink,
    };
  }

  ExamModel copyWith({
    String? id,
    int? intId,
    String? title,
    String? institution,
    DateTime? examDate,
    DateTime? applicationDeadline,
    String? applicationLink,
    String? category,
    bool? isFavorite,
    bool? isSchoolExam,
    String? className,
  }) {
    return ExamModel(
      id: id ?? this.id,
      intId: intId ?? this.intId,
      title: title ?? this.title,
      institution: institution ?? this.institution,
      examDate: examDate ?? this.examDate,
      applicationDeadline: applicationDeadline ?? this.applicationDeadline,
      applicationLink: applicationLink ?? this.applicationLink,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      isSchoolExam: isSchoolExam ?? this.isSchoolExam,
      className: className ?? this.className,
    );
  }
}
