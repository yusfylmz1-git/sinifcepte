import 'package:flutter/foundation.dart';
import '../../../../core/cloud/firestore_client.dart';

/// Okulda kayıtlı bir öğretmen (kadro seçimi için).
class SchoolTeacher {
  final String uid;
  final String fullName;
  final String branch;
  final String email;

  const SchoolTeacher({
    required this.uid,
    required this.fullName,
    this.branch = '',
    this.email = '',
  });

  /// "Selin Demir — Fizik"
  String get displayTitle =>
      branch.isEmpty ? fullName : '$fullName — $branch';
}

/// Okul → öğretmen dizini.
///
/// ## Neden var
/// Öğretmen okulunu zaten seçiyor (zorunlu), ancak bu bağ yalnızca kendi
/// cihazında duruyordu. Sonuç: sistem "bu okulda kimler var?" sorusunu
/// yanıtlayamıyordu ve sınıf kadrosuna öğretmen eklerken UID bilinemediği
/// için katılım kodu üretmek gerekiyordu.
///
/// Bu depo, öğretmenin okul bağını buluta yazar. Böylece sınıf öğretmeni
/// kadroyu **aynı okuldaki meslektaşları arasından seçerek** kurar; kod
/// alışverişine gerek kalmaz.
///
/// ## Gizlilik sınırı
/// Yalnızca ad, branş ve e-posta yazılır — öğrencileri, sınıfları veya
/// notları asla. Aynı okuldaki öğretmenler birbirini görebilir; bu zaten
/// gerçek hayatta da böyledir (aynı öğretmenler odasını paylaşırlar).
/// Veli bu listeyi göremez.
class SchoolDirectoryRepository {
  SchoolDirectoryRepository({FirestoreClient? client})
      : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const String _collection = 'school_teachers';

  /// Doküman kimliği: `{schoolId}_{teacherUid}`.
  ///
  /// Deterministik olduğu için aynı öğretmen okul değiştirdiğinde eski
  /// kayıt kalır ve temizlenebilir; ayrıca sorgu yerine tek `get()` ile
  /// "bu öğretmen bu okulda mı?" sorulabilir.
  static String docId({required String schoolId, required String teacherUid}) =>
      '${schoolId}_$teacherUid';

  /// Öğretmenin okul bağını buluta yazar/günceller.
  ///
  /// Okul seçildiğinde ve profil güncellendiğinde çağrılır. Başarısız
  /// olması akışı bozmaz: öğretmen yerel olarak çalışmaya devam eder,
  /// yalnızca meslektaşlarının kadro listesinde görünmez.
  Future<bool> registerTeacher({
    required String teacherUid,
    required String schoolId,
    required String fullName,
    required String branch,
    required String email,
  }) async {
    if (teacherUid.isEmpty || schoolId.isEmpty) return false;

    return _client.setDoc(
      '$_collection/${docId(schoolId: schoolId, teacherUid: teacherUid)}',
      {
        'teacherUid': teacherUid,
        'schoolId': schoolId,
        'fullName': fullName,
        'branch': branch,
        'email': email,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Aynı okuldaki öğretmenleri listeler.
  ///
  /// Sınıf kadrosu kurulurken "kimi ekleyeyim?" listesini besler.
  Future<List<SchoolTeacher>> teachersOfSchool(String schoolId) async {
    if (schoolId.isEmpty) return const [];

    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      final snap = await db
          .collection(_collection)
          .where('schoolId', isEqualTo: schoolId)
          .limit(200)
          .get();

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final data = d.data();
        return SchoolTeacher(
          uid: data['teacherUid'] as String? ?? '',
          fullName: data['fullName'] as String? ?? '',
          branch: data['branch'] as String? ?? '',
          email: data['email'] as String? ?? '',
        );
      }).where((t) => t.uid.isNotEmpty).toList();
    } catch (e, stackTrace) {
      debugPrint('teachersOfSchool hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Öğretmen okuldan ayrıldığında kaydı siler.
  Future<bool> unregisterTeacher({
    required String teacherUid,
    required String schoolId,
  }) {
    return _client.deleteDoc(
      '$_collection/${docId(schoolId: schoolId, teacherUid: teacherUid)}',
    );
  }
}
