/// SınıfCepte - Quiz & Sözlü Takip Tablosu Modelleri
class QuizCizelgeModel {
  final int? id;
  final String className;
  final String subject;
  final DateTime createdAt;
  final String category;

  const QuizCizelgeModel({
    this.id,
    required this.className,
    required this.subject,
    required this.createdAt,
    this.category = 'quiz',
  });

  factory QuizCizelgeModel.fromMap(Map<String, dynamic> map) {
    return QuizCizelgeModel(
      id: map['id'] as int?,
      className: map['sinif'] as String? ?? '',
      subject: map['ders'] as String? ?? '',
      createdAt: map['olusturulma_tarihi'] != null
          ? DateTime.tryParse(map['olusturulma_tarihi'] as String) ?? DateTime.now()
          : DateTime.now(),
      category: map['kategori'] as String? ?? 'quiz',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sinif': className,
      'ders': subject,
      'olusturulma_tarihi': createdAt.toIso8601String(),
      'kategori': category,
    };
  }

  QuizCizelgeModel copyWith({
    int? id,
    String? className,
    String? subject,
    DateTime? createdAt,
    String? category,
  }) {
    return QuizCizelgeModel(
      id: id ?? this.id,
      className: className ?? this.className,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
    );
  }
}

class QuizKolonModel {
  final int? id;
  final int cizelgeId;
  final String title;
  final String tip; // 'quiz', 'sozlu', 'dinleme', 'diger'
  final int orderIndex;
  final DateTime? date;

  const QuizKolonModel({
    this.id,
    required this.cizelgeId,
    required this.title,
    this.tip = 'quiz',
    this.orderIndex = 0,
    this.date,
  });

  factory QuizKolonModel.fromMap(Map<String, dynamic> map) {
    return QuizKolonModel(
      id: map['id'] as int?,
      cizelgeId: map['cizelge_id'] as int? ?? 0,
      title: map['baslik'] as String? ?? '',
      tip: map['tip'] as String? ?? 'quiz',
      orderIndex: map['sira'] as int? ?? 0,
      date: map['tarih'] != null ? DateTime.tryParse(map['tarih'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cizelge_id': cizelgeId,
      'baslik': title,
      'tip': tip,
      'sira': orderIndex,
      if (date != null) 'tarih': date!.toIso8601String(),
    };
  }

  QuizKolonModel copyWith({
    int? id,
    int? cizelgeId,
    String? title,
    String? tip,
    int? orderIndex,
    DateTime? date,
  }) {
    return QuizKolonModel(
      id: id ?? this.id,
      cizelgeId: cizelgeId ?? this.cizelgeId,
      title: title ?? this.title,
      tip: tip ?? this.tip,
      orderIndex: orderIndex ?? this.orderIndex,
      date: date ?? this.date,
    );
  }
}

class QuizNotModel {
  final int? id;
  final int kolonId;
  final int studentId;
  final int? score; // 0 - 100

  const QuizNotModel({
    this.id,
    required this.kolonId,
    required this.studentId,
    this.score,
  });

  factory QuizNotModel.fromMap(Map<String, dynamic> map) {
    return QuizNotModel(
      id: map['id'] as int?,
      kolonId: map['kolon_id'] as int? ?? 0,
      studentId: map['ogrenci_id'] as int? ?? 0,
      score: map['puan'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'kolon_id': kolonId,
      'ogrenci_id': studentId,
      'puan': score,
    };
  }
}
