import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/cloud/firestore_client.dart';
import '../models/school_admin_request_model.dart';
import '../../providers/user_role_provider.dart';

/// Veli şikâyetinin bulut kaydı.
///
/// Okul yöneticisi ve moderatörler görür; veli kendi şikâyetini bile
/// sonradan okuyamaz (denetim izi bütünlüğü).
class CloudContentReport {
  final String id;
  final String reporterUid;
  final String reporterRole;
  final String schoolId;
  final String contentId;
  final String contentType;
  final String contentSnippet;
  final String reason;
  final DateTime reportedAt;

  /// 'open' | 'reviewed' | 'dismissed'
  final String status;
  final String? reviewNote;

  const CloudContentReport({
    required this.id,
    required this.reporterUid,
    this.reporterRole = 'parent',
    this.schoolId = '',
    required this.contentId,
    required this.contentType,
    required this.contentSnippet,
    required this.reason,
    required this.reportedAt,
    this.status = 'open',
    this.reviewNote,
  });

  bool get isOpen => status == 'open';
}

/// Okul yöneticiliği başvuruları ve şikâyet kayıtlarının bulut erişimi.
///
/// ## Rol kurgusu
/// Bir okulun yöneticisi "ilk gelen" değil, **başvurup süper admin
/// tarafından onaylanan** kişidir. Yönetici rolü **opsiyoneldir**:
/// yöneticisi olmayan okullarda uygulamanın tamamı normal çalışır.
///
/// ## Yetki kaynağı
/// Onay kararı Firestore'da tutulur ama **yetkiyi veren şey custom
/// claim'dir**. Claim yalnızca sunucu tarafından (Admin SDK betiği)
/// yazılabilir; istemci hiçbir koşulda kendine yönetici diyemez.
/// `firestore.rules` bunu ayrıca doğrular: başvuran kendi kaydını
/// `approved` yapamaz.
class SchoolAdminRepository {
  SchoolAdminRepository({FirestoreClient? client})
      : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const String _requests = 'school_admin_requests';
  static const String _reports = 'content_reports';

  /// Öğretmen okul yöneticiliği için başvurur.
  ///
  /// Durum her zaman `pending` yazılır; kural motoru başka bir değeri
  /// reddeder (yetki yükseltme koruması).
  Future<bool> submitRequest(SchoolAdminRequestModel request) async {
    final map = request.toMap();
    // Kural motoru bu iki alanı özellikle denetler.
    map['teacherUid'] = request.teacherUid;
    map['status'] = 'pending';
    return _client.setDoc('$_requests/${request.id}', map, merge: false);
  }

  /// Öğretmenin kendi başvurusunu okur (varsa).
  ///
  /// Deterministik kimlik kullanıldığı için sorgu değil tek `get()`.
  Future<SchoolAdminRequestModel?> myRequest(String teacherUid) async {
    final data = await _client.getDoc('$_requests/${requestIdFor(teacherUid)}');
    if (data == null) return null;
    return SchoolAdminRequestModel.fromMap(data);
  }

  /// Başvuru doküman kimliği: her öğretmenin tek başvurusu olur.
  ///
  /// Böylece aynı kişi kuyruğu birden fazla kayıtla dolduramaz ve
  /// başvuru durumu tek okumayla getirilebilir.
  static String requestIdFor(String teacherUid) => 'req_$teacherUid';

  /// Bir okuldaki öğretmenlerin doğrulanma durumunu okur.
  ///
  /// Yönetici panelinde "kimler onay bekliyor" listesini besler.
  Future<List<SchoolAdminRequestModel>> pendingRequestsForSchool(
    String schoolId,
  ) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      final snap = await db
          .collection(_requests)
          .where('school_id', isEqualTo: schoolId)
          .where('status', isEqualTo: 'pending')
          .limit(50)
          .get().timeout(const Duration(seconds: 8));

      return snap.docs
          .map((d) => SchoolAdminRequestModel.fromMap(d.data()))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('pendingRequestsForSchool hatası: $e\n$stackTrace');
      return const [];
    }
  }

  // --- Şikâyetler ---

  /// Veli uygunsuz içerik bildirir.
  ///
  /// Kayıt oluşturulduktan sonra **değiştirilemez ve silinemez**
  /// (denetim izi). Yalnızca yönetim okuyabilir.
  Future<bool> submitContentReport({
    required String reportId,
    required String reporterUid,
    required String schoolId,
    required String contentId,
    required String contentType,
    required String contentSnippet,
    required String reason,
    String reporterRole = 'parent',
  }) {
    return _client.setDoc(
      '$_reports/$reportId',
      {
        // Kural motoru bu alanın kendi uid'imiz olmasını şart koşar.
        'reporterUid': reporterUid,
        'reporterRole': reporterRole,
        'schoolId': schoolId,
        'contentId': contentId,
        'contentType': contentType,
        'contentSnippet': contentSnippet,
        'reason': reason,
        'status': 'open',
        'reportedAt': DateTime.now().toIso8601String(),
      },
      merge: false,
    );
  }

  /// Yönetim şikâyetleri listeler.
  ///
  /// [schoolId] verilirse yalnızca o okulunkiler (okul yöneticisi görünümü);
  /// verilmezse tümü (moderatör görünümü).
  Future<List<CloudContentReport>> fetchReports({
    String? schoolId,
    int limit = 50,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      Query<Map<String, dynamic>> query = db.collection(_reports);
      if (schoolId != null && schoolId.isNotEmpty) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }

      final snap = await query
          .orderBy('reportedAt', descending: true)
          .limit(limit)
          .get().timeout(const Duration(seconds: 8));

      return snap.docs.map((d) {
        final data = d.data();
        return CloudContentReport(
          id: d.id,
          reporterUid: data['reporterUid'] as String? ?? '',
          reporterRole: data['reporterRole'] as String? ?? 'parent',
          schoolId: data['schoolId'] as String? ?? '',
          contentId: data['contentId'] as String? ?? '',
          contentType: data['contentType'] as String? ?? '',
          contentSnippet: data['contentSnippet'] as String? ?? '',
          reason: data['reason'] as String? ?? '',
          reportedAt: DateTime.tryParse(data['reportedAt'] as String? ?? '') ??
              DateTime.now(),
          status: data['status'] as String? ?? 'open',
          reviewNote: data['reviewNote'] as String?,
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('fetchReports hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Başvuru durumundan kullanıcı rol durumunu türetir.
  ///
  /// Not: Bu yalnızca **gösterim** içindir. Gerçek yetki custom claim'den
  /// gelir ([AuthClaimsService]); başvuru kaydının `approved` olması tek
  /// başına yönetici paneli açmaz.
  static SchoolAdminStatus statusOf(SchoolAdminRequestModel? request) {
    if (request == null) return SchoolAdminStatus.none;
    return request.status;
  }
}
