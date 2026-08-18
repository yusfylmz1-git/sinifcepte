import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/storage/prefs_keys.dart';
import '../../../../core/storage/prefs_migrator.dart';
import '../../../../core/storage/prefs_service.dart';
import '../models/parent_link_model.dart';
import '../models/parent_token_model.dart';
import 'kvkk_consent_service.dart';

/// SınıfCepte - Öğrenci & Veli Yaşam Döngüsü Yöneticisi (ParentLifecycleService)
class ParentLifecycleService {
  static const String _tokensPrefKey = PrefsKeys.parentTokens;
  static const String _linksPrefKey = PrefsKeys.parentLinks;
  static const String _statusReportsPrefKey = PrefsKeys.statusReports;
  static const String _appointmentsPrefKey = PrefsKeys.appointments;

  static Future<void> _ensureMigrated() => PrefsMigrator.migrateParentStores();

  /// 1. Yıl Sonu Sınıf Geçişi (Promote Class / Sınıf Atlatma)
  /// Mevcut veli bağlantıları korunur, sadece yeni sınıf ID ve adı güncellenir. Veli tekrar kod girmez!
  static Future<int> promoteStudentsToNextClass({
    required int oldClassId,
    required int newClassId,
    required String newClassName,
    required String actorId,
  }) async {
    try {
      await _ensureMigrated();
      final prefs = await PrefsService.instance();
      final rawLinks = prefs?.getStringList(_linksPrefKey) ?? [];
      final updatedList = <ParentLinkModel>[];
      var affectedCount = 0;

      for (final raw in rawLinks) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            var link = ParentLinkModel.fromMap(decoded);
            if (link.classId == oldClassId && link.status == 'active') {
              link = link.copyWith(
                classId: newClassId,
                className: newClassName,
              );
              affectedCount++;
            }
            updatedList.add(link);
          }
        } catch (_) {}
      }

      if (prefs != null) {
        await prefs.setStringList(_linksPrefKey, updatedList.map((l) => jsonEncode(l.toMap())).toList());
      }

      await KvkkConsentService.logAudit(
        actorId: actorId,
        actorRole: 'teacher',
        action: 'students_promoted',
        targetId: 'class_$newClassId',
        details: '$affectedCount veli bağlantısı $newClassName sınıfına başarıyla aktarıldı.',
      );

      return affectedCount;
    } catch (e, stackTrace) {
      debugPrint('ParentLifecycleService promoteStudentsToNextClass hatası: $e\n$stackTrace');
      return 0;
    }
  }

  /// 2. Mezuniyet (Graduation)
  /// Öğrenci mezun olduğunda bağlantı statüsü 'graduated' (arşiv/salt okunur) yapılır.
  static Future<bool> graduateStudent({
    required int studentId,
    required String actorId,
  }) async {
    try {
      await _ensureMigrated();
      final prefs = await PrefsService.instance();
      final rawLinks = prefs?.getStringList(_linksPrefKey) ?? [];
      final updatedList = <ParentLinkModel>[];

      for (final raw in rawLinks) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            var link = ParentLinkModel.fromMap(decoded);
            if (link.studentId == studentId && link.status == 'active') {
              link = link.copyWith(status: 'graduated');
            }
            updatedList.add(link);
          }
        } catch (_) {}
      }

      if (prefs != null) {
        await prefs.setStringList(_linksPrefKey, updatedList.map((l) => jsonEncode(l.toMap())).toList());
      }

      await KvkkConsentService.logAudit(
        actorId: actorId,
        actorRole: 'teacher',
        action: 'student_graduated',
        targetId: 'student_$studentId',
        details: 'Öğrenci mezun statüsüne alındı (bağlantılar arşive taşındı).',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('ParentLifecycleService graduateStudent hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// 3. Başka Okula Nakil (Transfer to Another School)
  /// Eski okuldaki bağlantılar 'transferred' statüsüne düşer, yeni okulda yeni kod üretilir.
  static Future<bool> transferStudent({
    required int studentId,
    required String actorId,
    String? reason,
  }) async {
    try {
      await _ensureMigrated();
      final prefs = await PrefsService.instance();
      final rawLinks = prefs?.getStringList(_linksPrefKey) ?? [];
      final updatedList = <ParentLinkModel>[];

      for (final raw in rawLinks) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            var link = ParentLinkModel.fromMap(decoded);
            if (link.studentId == studentId && link.status == 'active') {
              link = link.copyWith(status: 'transferred');
            }
            updatedList.add(link);
          }
        } catch (_) {}
      }

      if (prefs != null) {
        await prefs.setStringList(_linksPrefKey, updatedList.map((l) => jsonEncode(l.toMap())).toList());
      }

      // Aktif tokenları da iptal et
      final rawTokens = prefs?.getStringList(_tokensPrefKey) ?? [];
      final updatedTokens = <ParentTokenModel>[];
      for (final raw in rawTokens) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            var tok = ParentTokenModel.fromMap(decoded);
            if (tok.studentId == studentId && tok.status == 'active') {
              tok = tok.copyWith(status: 'revoked');
            }
            updatedTokens.add(tok);
          }
        } catch (_) {}
      }
      if (prefs != null) {
        await prefs.setStringList(_tokensPrefKey, updatedTokens.map((t) => jsonEncode(t.toMap())).toList());
      }

      await KvkkConsentService.logAudit(
        actorId: actorId,
        actorRole: 'teacher',
        action: 'student_transferred',
        targetId: 'student_$studentId',
        details: 'Öğrenci nakil gitti: $reason (Erişimler kapatıldı).',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('ParentLifecycleService transferStudent hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// 4. Öğrenci Silindiğinde Unutulma Hakkı & Kalıcı Cascade Silme (Right to be Forgotten)
  /// Öğrenci silindiğinde ona bağlı tüm referans tokenları, veli bağlantıları, durum bildirimleri ve randevular silinir.
  static Future<void> cascadeDeleteStudentParentData({
    required int studentId,
    required String actorId,
  }) async {
    try {
      await _ensureMigrated();
      final prefs = await PrefsService.instance();
      if (prefs == null) return;

      // 1. Tokenları Sil
      final rawTokens = prefs.getStringList(_tokensPrefKey) ?? [];
      final cleanedTokens = rawTokens.where((raw) {
        try {
          final d = jsonDecode(raw);
          return d['student_id'] != studentId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_tokensPrefKey, cleanedTokens);

      // 2. Veli Bağlantılarını Sil
      final rawLinks = prefs.getStringList(_linksPrefKey) ?? [];
      final cleanedLinks = rawLinks.where((raw) {
        try {
          final d = jsonDecode(raw);
          return d['student_id'] != studentId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_linksPrefKey, cleanedLinks);

      // 3. Durum Bildirimlerini Sil
      final rawReports = prefs.getStringList(_statusReportsPrefKey) ?? [];
      final cleanedReports = rawReports.where((raw) {
        try {
          final d = jsonDecode(raw);
          return d['student_id'] != studentId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_statusReportsPrefKey, cleanedReports);

      // 4. Randevuları Sil
      final rawApps = prefs.getStringList(_appointmentsPrefKey) ?? [];
      final cleanedApps = rawApps.where((raw) {
        try {
          final d = jsonDecode(raw);
          return d['student_id'] != studentId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_appointmentsPrefKey, cleanedApps);

      // 5. KVKK Denetim Kaydı
      await KvkkConsentService.logAudit(
        actorId: actorId,
        actorRole: 'teacher',
        action: 'student_cascade_deleted',
        targetId: 'student_$studentId',
        details: 'Öğrenciye bağlı tüm veli, token, randevu ve bildirim verileri KVKK uyarınca kalıcı olarak silindi.',
      );
    } catch (e, stackTrace) {
      debugPrint('ParentLifecycleService cascadeDeleteStudentParentData hatası: $e\n$stackTrace');
    }
  }

  /// 5. Veli Self-Service: Tüm Verilerimi İndir / Dışa Aktar (KVKK Madde 11)
  static Future<Map<String, dynamic>> exportParentDataAsJson(String parentUserId) async {
    try {
      await _ensureMigrated();
      final prefs = await PrefsService.instance();

      final rawLinks = prefs?.getStringList(_linksPrefKey) ?? [];
      final myChildren = <Map<String, dynamic>>[];
      for (final raw in rawLinks) {
        try {
          final d = jsonDecode(raw);
          if (d['parent_user_id'] == parentUserId) myChildren.add(d);
        } catch (_) {}
      }

      final rawReports = prefs?.getStringList(_statusReportsPrefKey) ?? [];
      final myReports = <Map<String, dynamic>>[];
      for (final raw in rawReports) {
        try {
          final d = jsonDecode(raw);
          if (d['parent_user_id'] == parentUserId) myReports.add(d);
        } catch (_) {}
      }

      final rawApps = prefs?.getStringList(_appointmentsPrefKey) ?? [];
      final myApps = <Map<String, dynamic>>[];
      for (final raw in rawApps) {
        try {
          final d = jsonDecode(raw);
          if (d['parent_user_id'] == parentUserId) myApps.add(d);
        } catch (_) {}
      }

      final exportPayload = {
        'export_date': DateTime.now().toIso8601String(),
        'parent_user_id': parentUserId,
        'kvkk_compliance': 'KVKK Madde 11 Veri Taşınabilirliği',
        'connected_children': myChildren,
        'status_reports': myReports,
        'appointments': myApps,
      };

      await KvkkConsentService.logAudit(
        actorId: parentUserId,
        actorRole: 'parent',
        action: 'parent_data_exported',
        targetId: parentUserId,
        details: 'Veli tüm kişisel ve öğrenci bağlantı verilerini JSON olarak indirdi.',
      );

      return exportPayload;
    } catch (e, stackTrace) {
      debugPrint('ParentLifecycleService exportParentDataAsJson hatası: $e\n$stackTrace');
      return {'error': e.toString()};
    }
  }

  /// 6. Veli Self-Service: Hesabımı ve Bağlantılarımı Kalıcı Olarak Sil (Unutulma Hakkı)
  static Future<bool> deleteParentSelfAccount(String parentUserId) async {
    try {
      await _ensureMigrated();
      final prefs = await PrefsService.instance();
      if (prefs == null) return false;

      // Veli bağlantılarını temizle
      final rawLinks = prefs.getStringList(_linksPrefKey) ?? [];
      final remainingLinks = rawLinks.where((raw) {
        try {
          final d = jsonDecode(raw);
          return d['parent_user_id'] != parentUserId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_linksPrefKey, remainingLinks);

      // Bildirimleri temizle
      final rawReports = prefs.getStringList(_statusReportsPrefKey) ?? [];
      final remainingReports = rawReports.where((raw) {
        try {
          final d = jsonDecode(raw);
          return d['parent_user_id'] != parentUserId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_statusReportsPrefKey, remainingReports);

      // Randevuları temizle
      final rawApps = prefs.getStringList(_appointmentsPrefKey) ?? [];
      final remainingApps = rawApps.where((raw) {
        try {
          final d = jsonDecode(raw);
          return d['parent_user_id'] != parentUserId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_appointmentsPrefKey, remainingApps);

      await KvkkConsentService.logAudit(
        actorId: parentUserId,
        actorRole: 'parent',
        action: 'parent_account_deleted',
        targetId: parentUserId,
        details: 'Veli kendi isteğiyle hesabını ve tüm çocuk bağlantılarını kalıcı olarak sildi.',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('ParentLifecycleService deleteParentSelfAccount hatası: $e\n$stackTrace');
      return false;
    }
  }
}
