import '../../providers/user_role_provider.dart';

/// Okul yöneticiliği başvurusu.
///
/// Kurgu: bir okulun yöneticisi "ilk gelen" değil, **başvurup süper admin
/// tarafından onaylanan** kişidir. Yönetici rolü opsiyoneldir; yöneticisi
/// olmayan okullarda uygulamanın tamamı normal çalışmaya devam eder.
///
/// Bulut yolu: `/school_admin_requests/{id}`
class SchoolAdminRequestModel {
  final String id;

  /// Başvuran öğretmenin Firebase UID'si.
  final String teacherUid;
  final String teacherName;
  final String teacherEmail;

  /// Kanonik okul kimliği (meb_ / man_ / pending_ ile başlar).
  final String schoolId;
  final String schoolName;
  final String city;
  final String district;

  /// Öğretmenin başvuruda yazdığı gerekçe / görev bilgisi.
  /// Örn: "Okul müdür yardımcısıyım, 2019'dan beri görevdeyim."
  final String note;

  final SchoolAdminStatus status;
  final DateTime requestedAt;

  /// Karar veren süper admin ve zamanı (henüz karar yoksa null).
  final String? decidedByUid;
  final DateTime? decidedAt;

  /// Reddedilme gerekçesi (yalnızca [SchoolAdminStatus.rejected] durumunda).
  final String? rejectionReason;

  const SchoolAdminRequestModel({
    required this.id,
    required this.teacherUid,
    required this.teacherName,
    required this.teacherEmail,
    required this.schoolId,
    required this.schoolName,
    this.city = '',
    this.district = '',
    this.note = '',
    this.status = SchoolAdminStatus.pending,
    required this.requestedAt,
    this.decidedByUid,
    this.decidedAt,
    this.rejectionReason,
  });

  bool get isPending => status == SchoolAdminStatus.pending;
  bool get isApproved => status == SchoolAdminStatus.approved;

  /// Okul başlığı: "Bursa / Nilüfer — Cumhuriyet Ortaokulu"
  String get fullSchoolTitle {
    final location = [city, district].where((p) => p.isNotEmpty).join(' / ');
    return location.isEmpty ? schoolName : '$location — $schoolName';
  }

  SchoolAdminRequestModel copyWith({
    String? id,
    String? teacherUid,
    String? teacherName,
    String? teacherEmail,
    String? schoolId,
    String? schoolName,
    String? city,
    String? district,
    String? note,
    SchoolAdminStatus? status,
    DateTime? requestedAt,
    String? decidedByUid,
    DateTime? decidedAt,
    String? rejectionReason,
  }) {
    return SchoolAdminRequestModel(
      id: id ?? this.id,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName ?? this.teacherName,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      city: city ?? this.city,
      district: district ?? this.district,
      note: note ?? this.note,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      decidedByUid: decidedByUid ?? this.decidedByUid,
      decidedAt: decidedAt ?? this.decidedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacher_uid': teacherUid,
      'teacher_name': teacherName,
      'teacher_email': teacherEmail,
      'school_id': schoolId,
      'school_name': schoolName,
      'city': city,
      'district': district,
      'note': note,
      'status': statusLabel,
      'requested_at': requestedAt.toIso8601String(),
      'decided_by_uid': decidedByUid,
      'decided_at': decidedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  factory SchoolAdminRequestModel.fromMap(Map<String, dynamic> map) {
    return SchoolAdminRequestModel(
      id: map['id'] as String? ?? '',
      teacherUid: map['teacher_uid'] as String? ?? '',
      teacherName: map['teacher_name'] as String? ?? '',
      teacherEmail: map['teacher_email'] as String? ?? '',
      schoolId: map['school_id'] as String? ?? '',
      schoolName: map['school_name'] as String? ?? '',
      city: map['city'] as String? ?? '',
      district: map['district'] as String? ?? '',
      note: map['note'] as String? ?? '',
      status: parseStatus(map['status'] as String?),
      requestedAt:
          DateTime.tryParse(map['requested_at'] as String? ?? '') ?? DateTime.now(),
      decidedByUid: map['decided_by_uid'] as String?,
      decidedAt: DateTime.tryParse(map['decided_at'] as String? ?? ''),
      rejectionReason: map['rejection_reason'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case SchoolAdminStatus.approved:
        return 'approved';
      case SchoolAdminStatus.pending:
        return 'pending';
      case SchoolAdminStatus.rejected:
        return 'rejected';
      case SchoolAdminStatus.none:
        return 'none';
    }
  }

  /// Kullanıcıya gösterilecek Türkçe durum metni.
  String get statusText {
    switch (status) {
      case SchoolAdminStatus.approved:
        return 'Onaylandı';
      case SchoolAdminStatus.pending:
        return 'Onay bekliyor';
      case SchoolAdminStatus.rejected:
        return 'Reddedildi';
      case SchoolAdminStatus.none:
        return 'Başvuru yok';
    }
  }

  static SchoolAdminStatus parseStatus(String? raw) {
    switch (raw ?? '') {
      case 'approved':
        return SchoolAdminStatus.approved;
      case 'pending':
        return SchoolAdminStatus.pending;
      case 'rejected':
        return SchoolAdminStatus.rejected;
      default:
        return SchoolAdminStatus.none;
    }
  }
}
