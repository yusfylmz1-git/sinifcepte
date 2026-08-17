/// SınıfCepte - Proje & Ödev Değerlendirme (Rubric) Modelleri
class ProjectKriterModel {
  final int? id;
  final String title;
  final int maxScore;
  final int orderIndex;

  const ProjectKriterModel({
    this.id,
    required this.title,
    this.maxScore = 10,
    this.orderIndex = 0,
  });

  factory ProjectKriterModel.fromMap(Map<String, dynamic> map) {
    return ProjectKriterModel(
      id: map['id'] as int?,
      title: map['baslik'] as String? ?? '',
      maxScore: map['max_puan'] as int? ?? 10,
      orderIndex: map['sira'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'baslik': title,
      'max_puan': maxScore,
      'sira': orderIndex,
    };
  }
}

class ProjectTakipModel {
  final int? id;
  final String className;
  final int studentId;
  final String studentName;
  final String subject;
  final String homeworkTopic;
  final DateTime createdAt;
  final bool isSubmitted;
  final int? totalScore;
  final bool isEvaluated;

  const ProjectTakipModel({
    this.id,
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.subject,
    required this.homeworkTopic,
    required this.createdAt,
    this.isSubmitted = false,
    this.totalScore,
    this.isEvaluated = false,
  });

  factory ProjectTakipModel.fromMap(Map<String, dynamic> map) {
    return ProjectTakipModel(
      id: map['id'] as int?,
      className: map['sinif'] as String? ?? '',
      studentId: map['ogrenci_id'] as int? ?? 0,
      studentName: map['ogrenci_ad'] as String? ?? '',
      subject: map['ders'] as String? ?? '',
      homeworkTopic: map['odev_konusu'] as String? ?? '',
      createdAt: map['olusturulma_tarihi'] != null
          ? DateTime.tryParse(map['olusturulma_tarihi'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSubmitted: (map['teslim_etti'] as int? ?? 0) == 1,
      totalScore: map['toplam_puan'] as int?,
      isEvaluated: (map['degerlendirildi'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sinif': className,
      'ogrenci_id': studentId,
      'ogrenci_ad': studentName,
      'ders': subject,
      'odev_konusu': homeworkTopic,
      'olusturulma_tarihi': createdAt.toIso8601String(),
      'teslim_etti': isSubmitted ? 1 : 0,
      'toplam_puan': totalScore,
      'degerlendirildi': isEvaluated ? 1 : 0,
    };
  }

  ProjectTakipModel copyWith({
    int? id,
    String? className,
    int? studentId,
    String? studentName,
    String? subject,
    String? homeworkTopic,
    DateTime? createdAt,
    bool? isSubmitted,
    int? totalScore,
    bool? isEvaluated,
  }) {
    return ProjectTakipModel(
      id: id ?? this.id,
      className: className ?? this.className,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      subject: subject ?? this.subject,
      homeworkTopic: homeworkTopic ?? this.homeworkTopic,
      createdAt: createdAt ?? this.createdAt,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      totalScore: totalScore ?? this.totalScore,
      isEvaluated: isEvaluated ?? this.isEvaluated,
    );
  }
}

class ProjectPuanModel {
  final int? id;
  final int projectId;
  final int kriterId;
  final int score;

  const ProjectPuanModel({
    this.id,
    required this.projectId,
    required this.kriterId,
    required this.score,
  });

  factory ProjectPuanModel.fromMap(Map<String, dynamic> map) {
    return ProjectPuanModel(
      id: map['id'] as int?,
      projectId: map['proje_id'] as int? ?? 0,
      kriterId: map['kriter_id'] as int? ?? 0,
      score: map['puan'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'proje_id': projectId,
      'kriter_id': kriterId,
      'puan': score,
    };
  }
}
