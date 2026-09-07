/// Devamsizlik nedeni.
///
/// Bakanligin devamsizlik calismasinda sinif rehber ogretmeninden
/// istenen ilk bilgi "neden": rapor sagliktan mi, ailevi bir
/// zorunluluktan mi kaynaklaniyor. Serbest metne birakilsaydi her
/// ogretmen baska sozcuk yazar, cizelge gruplanamazdi.
enum AbsenceReason {
  bilinmiyor('bilinmiyor', 'Bilinmiyor'),
  saglik('saglik', 'Sağlık'),
  ailevi('ailevi', 'Ailevi'),
  ekonomik('ekonomik', 'Ekonomik'),
  okulUyumu('okul_uyumu', 'Okul Uyumu'),
  mevsimlikIs('mevsimlik_is', 'Mevsimlik İş / Göç'),
  diger('diger', 'Diğer');

  final String code;
  final String label;

  const AbsenceReason(this.code, this.label);

  static AbsenceReason fromCode(String? code) {
    if (code == null) return AbsenceReason.bilinmiyor;
    return AbsenceReason.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AbsenceReason.bilinmiyor,
    );
  }
}

/// Devamsiz ogrenci takip kaydi (AbsenceFollowupModel).
///
/// Ogretmenin "bu ogrenci devamsiz" isareti; gunluk yoklama DEGIL.
/// Uygulamada yoklama alinmiyor, ogretmen e-Okul'daki devamsizliga
/// bakip listeden isaretliyor.
///
/// Kayit DERS YILINA bagli: yil degisince liste temiz baslar, gecen
/// yilin kaydi arsivde durur. Yil alani olmasaydi ogretmen her eylulde
/// listeyi elle temizlemek zorunda kalirdi.
class AbsenceFollowupModel {
  final int? id;
  final int studentId;
  final int classId;
  final String academicYear; // Örn: 2025-2026
  final AbsenceReason reason;

  /// Ogretmenin serbest notu. Ornegin "Veli 12.09'da arandi,
  /// ulasilamadi." Cizelgede "AÇIKLAMA" sutununa basilir.
  final String? note;

  /// Ogrencinin devamsiz olarak isaretlendigi an.
  final DateTime markedAt;
  final DateTime updatedAt;

  const AbsenceFollowupModel({
    this.id,
    required this.studentId,
    required this.classId,
    required this.academicYear,
    this.reason = AbsenceReason.bilinmiyor,
    this.note,
    required this.markedAt,
    required this.updatedAt,
  });

  bool get hasNote => (note ?? '').trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'class_id': classId,
      'academic_year': academicYear,
      'reason': reason.code,
      // `note` SQLite'ta ayrilmis sozcuk degil ama `not` oyle; guidance_logs
      // ayni tuzaga dusmustu. Yine de acik olsun diye `note` kullaniliyor.
      'note': note,
      'marked_at': markedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AbsenceFollowupModel.fromMap(Map<String, dynamic> map) {
    return AbsenceFollowupModel(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      classId: map['class_id'] as int,
      academicYear: map['academic_year'] as String? ?? '',
      reason: AbsenceReason.fromCode(map['reason'] as String?),
      note: map['note'] as String?,
      markedAt: DateTime.tryParse(map['marked_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  AbsenceFollowupModel copyWith({
    int? id,
    int? studentId,
    int? classId,
    String? academicYear,
    AbsenceReason? reason,
    String? note,
    DateTime? markedAt,
    DateTime? updatedAt,
  }) {
    return AbsenceFollowupModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      classId: classId ?? this.classId,
      academicYear: academicYear ?? this.academicYear,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      markedAt: markedAt ?? this.markedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Cizelgede ve listede gosterilen birlesik satir.
///
/// Ogrenci bilgisi `students` tablosunda, takip kaydi ayri tabloda.
/// Ekranin ikisini de ayri ayri okuyup eslemesi gerekiyordu; bu tip
/// eslemeyi tek yerde yapar.
class AbsenceFollowupEntry {
  final AbsenceFollowupModel followup;
  final int schoolNumber;
  final String fullName;
  final String? parentName;
  final String? parentPhone;

  const AbsenceFollowupEntry({
    required this.followup,
    required this.schoolNumber,
    required this.fullName,
    this.parentName,
    this.parentPhone,
  });

  bool get hasPhone => (parentPhone ?? '').trim().isNotEmpty;
}
