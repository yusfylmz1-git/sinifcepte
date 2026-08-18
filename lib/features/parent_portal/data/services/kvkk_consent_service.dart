import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/storage/prefs_service.dart';
import '../models/content_report_model.dart';

/// KVKK Açık Rıza ve İzin Kaydı Modeli
class ConsentLogModel {
  final String id;
  final String userId;
  final String consentVersion; // Örn: "v2.0"
  final DateTime consentedAt;
  final String deviceLocale;
  final List<String> scope; // ['veli_aydinlatma_metni', 'bildirim_izni', 'mesru_menfaat_egitim']

  const ConsentLogModel({
    required this.id,
    required this.userId,
    required this.consentVersion,
    required this.consentedAt,
    required this.deviceLocale,
    required this.scope,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'consent_version': consentVersion,
      'consented_at': consentedAt.toIso8601String(),
      'device_locale': deviceLocale,
      'scope': scope,
    };
  }

  factory ConsentLogModel.fromMap(Map<String, dynamic> map) {
    return ConsentLogModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      consentVersion: map['consent_version']?.toString() ?? 'v1.0',
      consentedAt: map['consented_at'] != null ? DateTime.parse(map['consented_at'].toString()) : DateTime.now(),
      deviceLocale: map['device_locale']?.toString() ?? 'tr_TR',
      scope: (map['scope'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Sistem Denetim Logu Modeli (Audit Log)
class AuditLogModel {
  final String id;
  final String actorId;
  final String actorRole; // 'teacher', 'parent', 'admin'
  final String action;    // 'token_generated', 'parent_linked', 'content_reported', etc.
  final String targetId;  // studentId, reportId, etc.
  final String? schoolId;
  final String? details;
  final DateTime timestamp;

  const AuditLogModel({
    required this.id,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.targetId,
    this.schoolId,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'actor_id': actorId,
      'actor_role': actorRole,
      'action': action,
      'target_id': targetId,
      'school_id': schoolId,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map) {
    return AuditLogModel(
      id: map['id']?.toString() ?? '',
      actorId: map['actor_id']?.toString() ?? '',
      actorRole: map['actor_role']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      targetId: map['target_id']?.toString() ?? '',
      schoolId: map['school_id']?.toString(),
      details: map['details']?.toString(),
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp'].toString()) : DateTime.now(),
    );
  }
}

/// SınıfCepte - KVKK, Açık Rıza ve Denetim Kayıt Servisi (Audit Logging)
class KvkkConsentService {
  static const String _consentPrefKey = 'sinifcepte_kvkk_consents';
  static const String _auditPrefKey = 'sinifcepte_audit_logs';
  static const String _reportsPrefKey = 'sinifcepte_content_reports';
  static const String _verifiedTeachersPrefKey = 'sinifcepte_verified_teachers';
  static const String currentConsentVersion = 'v2.0';

  /// 1. Veli Açık Rıza Onayını Kaydetme (KVKK Madde 5/2-c & 5/2-f Uyumlu)
  static Future<ConsentLogModel> recordConsent({
    required String userId,
    String consentVersion = currentConsentVersion,
    List<String> scope = const ['veli_aydinlatma_metni', 'bildirim_izni', 'mesru_menfaat_egitim'],
    String deviceLocale = 'tr_TR',
  }) async {
    try {
      final prefs = await PrefsService.instance();
      final rawList = prefs?.getStringList(_consentPrefKey) ?? [];

      final log = ConsentLogModel(
        id: 'consent_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        consentVersion: consentVersion,
        consentedAt: DateTime.now(),
        deviceLocale: deviceLocale,
        scope: scope,
      );

      rawList.add(jsonEncode(log.toMap()));
      if (prefs != null) {
        await prefs.setStringList(_consentPrefKey, rawList);
      }
      return log;
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService recordConsent hatası: $e\n$stackTrace');
      return ConsentLogModel(
        id: 'fallback_consent',
        userId: userId,
        consentVersion: consentVersion,
        consentedAt: DateTime.now(),
        deviceLocale: deviceLocale,
        scope: scope,
      );
    }
  }

  /// 2. Kullanıcının Güncel Rıza Verip Vermediğini Kontrol Etme
  static Future<bool> hasValidConsent(String userId) async {
    try {
      final prefs = await PrefsService.instance();
      final rawList = prefs?.getStringList(_consentPrefKey) ?? [];

      for (final raw in rawList.reversed) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final log = ConsentLogModel.fromMap(decoded);
          if (log.userId == userId && log.consentVersion == currentConsentVersion) {
            return true;
          }
        }
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService hasValidConsent hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// 3. Denetim Logu (Audit Log) Yazma
  static Future<void> logAudit({
    required String actorId,
    required String actorRole,
    required String action,
    required String targetId,
    String? schoolId,
    String? details,
  }) async {
    try {
      final prefs = await PrefsService.instance();
      final rawList = prefs?.getStringList(_auditPrefKey) ?? [];

      final audit = AuditLogModel(
        id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
        actorId: actorId,
        actorRole: actorRole,
        action: action,
        targetId: targetId,
        schoolId: schoolId,
        details: details,
        timestamp: DateTime.now(),
      );

      rawList.add(jsonEncode(audit.toMap()));
      if (prefs != null) {
        await prefs.setStringList(_auditPrefKey, rawList);
      }
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService logAudit hatası: $e\n$stackTrace');
    }
  }

  /// 4. Denetim Loglarını Getirme
  static Future<List<AuditLogModel>> getAuditLogs({int limit = 100}) async {
    try {
      final prefs = await PrefsService.instance();
      final rawList = prefs?.getStringList(_auditPrefKey) ?? [];
      final logs = <AuditLogModel>[];

      for (final raw in rawList.reversed) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            logs.add(AuditLogModel.fromMap(decoded));
            if (logs.length >= limit) break;
          }
        } catch (_) {}
      }
      return logs;
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService getAuditLogs hatası: $e\n$stackTrace');
      return [];
    }
  }

  /// 5. İçerik Şikayeti Kaydetme (Content Moderation)
  static Future<bool> reportContent({
    required String reportedByUserId,
    required String reportedRole,
    required String contentId,
    required String contentType,
    required String contentSnippet,
    required String reason,
  }) async {
    try {
      final prefs = await PrefsService.instance();
      final rawList = prefs?.getStringList(_reportsPrefKey) ?? [];

      final report = ContentReportModel(
        id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
        reportedByUserId: reportedByUserId,
        reportedRole: reportedRole,
        contentId: contentId,
        contentType: contentType,
        contentSnippet: contentSnippet,
        reason: reason,
        reportedAt: DateTime.now(),
        status: 'pending',
      );

      rawList.add(jsonEncode(report.toMap()));
      if (prefs != null) {
        await prefs.setStringList(_reportsPrefKey, rawList);
      }

      await logAudit(
        actorId: reportedByUserId,
        actorRole: reportedRole,
        action: 'content_reported',
        targetId: contentId,
        details: 'İçerik şikayet edildi: $reason ($contentType)',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService reportContent hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// 6. İçerik Şikayetlerini Listeleme
  static Future<List<ContentReportModel>> getContentReports() async {
    try {
      final prefs = await PrefsService.instance();
      final rawList = prefs?.getStringList(_reportsPrefKey) ?? [];
      final list = <ContentReportModel>[];

      for (final raw in rawList.reversed) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(ContentReportModel.fromMap(decoded));
          }
        } catch (_) {}
      }
      return list;
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService getContentReports hatası: $e\n$stackTrace');
      return [];
    }
  }

  /// 7. Öğretmen Doğrulama / Mavi Rozet Verme (Admin Onayı)
  static Future<bool> verifyTeacher({
    required String teacherId,
    required String teacherName,
    required String adminId,
    required String schoolName,
  }) async {
    try {
      final prefs = await PrefsService.instance();
      final verifiedList = prefs?.getStringList(_verifiedTeachersPrefKey) ?? [];

      if (!verifiedList.contains(teacherId)) {
        verifiedList.add(teacherId);
        if (prefs != null) {
          await prefs.setStringList(_verifiedTeachersPrefKey, verifiedList);
        }
      }

      await logAudit(
        actorId: adminId,
        actorRole: 'admin',
        action: 'teacher_verified',
        targetId: teacherId,
        details: '$teacherName isimli öğretmene $schoolName okul yönetimi tarafından Mavi Onay Rozeti verildi.',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService verifyTeacher hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// 8. Öğretmenin Doğrulanmış Olup Olmadığını Kontrol Etme
  static Future<bool> isTeacherVerified(String teacherId) async {
    try {
      final prefs = await PrefsService.instance();
      final verifiedList = prefs?.getStringList(_verifiedTeachersPrefKey) ?? [];
      return verifiedList.contains(teacherId);
    } catch (e, stackTrace) {
      debugPrint('KvkkConsentService isTeacherVerified hatası: $e\n$stackTrace');
      return false;
    }
  }
}
