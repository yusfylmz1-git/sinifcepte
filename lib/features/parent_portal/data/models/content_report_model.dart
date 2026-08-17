/// SınıfCepte - İçerik Şikayeti / Moderasyon Modeli
class ContentReportModel {
  final String id;
  final String reportedByUserId;
  final String reportedRole; // 'parent', 'teacher'
  final String contentId;
  final String contentType; // 'announcement', 'status_report', 'appointment_note'
  final String contentSnippet;
  final String reason;
  final DateTime reportedAt;
  final String status; // 'pending', 'resolved', 'dismissed'

  const ContentReportModel({
    required this.id,
    required this.reportedByUserId,
    required this.reportedRole,
    required this.contentId,
    required this.contentType,
    required this.contentSnippet,
    required this.reason,
    required this.reportedAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reported_by_user_id': reportedByUserId,
      'reported_role': reportedRole,
      'content_id': contentId,
      'content_type': contentType,
      'content_snippet': contentSnippet,
      'reason': reason,
      'reported_at': reportedAt.toIso8601String(),
      'status': status,
    };
  }

  factory ContentReportModel.fromMap(Map<String, dynamic> map) {
    return ContentReportModel(
      id: map['id']?.toString() ?? '',
      reportedByUserId: map['reported_by_user_id']?.toString() ?? '',
      reportedRole: map['reported_role']?.toString() ?? 'parent',
      contentId: map['content_id']?.toString() ?? '',
      contentType: map['content_type']?.toString() ?? 'announcement',
      contentSnippet: map['content_snippet']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      reportedAt: map['reported_at'] != null ? DateTime.parse(map['reported_at'].toString()) : DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
