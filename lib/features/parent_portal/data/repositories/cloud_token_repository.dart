import 'package:flutter/foundation.dart';
import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/cloud/firestore_client.dart';
import '../models/parent_link_model.dart';
import '../models/parent_token_model.dart';

/// Bulut token doğrulama sonucu.
class CloudTokenLookup {
  final bool found;
  final String? classCloudId;
  final String? studentCloudId;
  final String? teacherUid;
  final String? schoolId;
  final String? schoolName;
  final String? className;
  final String? studentName;
  final int studentNumber;
  final String? secondFactorHash;
  final DateTime? expiresAt;
  final String status;
  final int linkedParentCount;
  final int maxLinkedParents;

  const CloudTokenLookup({
    required this.found,
    this.classCloudId,
    this.studentCloudId,
    this.teacherUid,
    this.schoolId,
    this.schoolName,
    this.className,
    this.studentName,
    this.studentNumber = 0,
    this.secondFactorHash,
    this.expiresAt,
    this.status = 'active',
    this.linkedParentCount = 0,
    this.maxLinkedParents = 2,
  });

  static const CloudTokenLookup notFound = CloudTokenLookup(found: false);

  bool get isExpired =>
      expiresAt == null || DateTime.now().isAfter(expiresAt!);

  bool get isUsable =>
      found &&
      status == 'active' &&
      !isExpired &&
      linkedParentCount < maxLinkedParents;
}

/// Öğretmen ↔ veli arasındaki bulut köprüsü.
///
/// ## Zincirin kopuk halkası buradaydı
/// Token yalnızca öğretmenin cihazındaki `SharedPreferences`'ta tutulduğu
/// için veli başka bir telefondan kodu doğrulayamıyordu. Bu depo, kodu
/// iki cihazın da erişebildiği tek yere taşır.
///
/// ## Güvenlik: buluta düz kod yazılmaz
/// Doküman kimliği `SHA-256(kod)` değerinin kendisidir. Bunun iki faydası:
/// 1. Firestore'u ele geçiren biri bile kodları geri üretemez.
/// 2. Doğrulama sorgu (`where`) değil doğrudan `get()` olur — indeks
///    gerekmez ve **tek doküman okuması** eder (maliyet kararı).
///
/// Düz kod yalnızca öğretmenin cihazında ve paylaştığı kartta bulunur.
///
/// ## Öğrenci adı neden bulutta
/// Veli kodu girdiğinde "hangi çocuğu bağlıyorum?" onayını görmelidir.
/// Yalnızca ad ve sınıf yazılır; not, katılım, telefon gibi veriler
/// buluta **hiç çıkmaz** — onlar öğretmenin yerel SQLite'ında kalır.
class CloudTokenRepository {
  CloudTokenRepository({FirestoreClient? client})
      : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const String _tokensCollection = 'parent_tokens';
  static const String _linksCollection = 'parent_links';
  static const String _classAccessCollection = 'parent_class_access';
  static const String _classRoomsCollection = 'class_rooms';

  String _tokenPath(String codeHash) => '$_tokensCollection/$codeHash';

  /// Öğretmen kod ürettiğinde bulut kaydını yazar.
  ///
  /// Yerel token zaten üretilmiştir; bu metot onu buluta yansıtır. Ağ yoksa
  /// `false` döner ve öğretmen uyarılır — kod yerelde durur ama veli
  /// bağlanamaz, bu yüzden sessizce geçilmemelidir.
  Future<bool> publishToken({
    required ParentTokenModel token,
    required String teacherUid,
    required String teacherName,
  }) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return false;

    try {
      final classCloudId = CloudIds.classId(
        teacherUid: teacherUid,
        localClassId: token.classId,
      );
      final studentCloudId = CloudIds.studentId(
        teacherUid: teacherUid,
        localStudentId: token.studentId,
      );

      // Sınıf odası kaydı (veli duyuru/mesaj erişimi için gerekli).
      // Öğrenci listesi içermez — yalnızca sınıfın kimliği ve öğretmeni.
      final classRoomPath = '$_classRoomsCollection/$classCloudId';
      final tokenPath = _tokenPath(token.codeHash);

      // Sınıf öğretmeninin kadro satırı.
      //
      // Bu satır yazılmadığı için veli, sınıf öğretmenini kadroda
      // göremiyordu: kadro yalnızca `ensureClassRoom` çağrıldığında
      // (duyuru yayımlama veya branş öğretmeni ekleme) oluşuyordu.
      // Referans kodu üretmek tek başına yeterli olmalı — veli
      // bağlandığı anda en azından sınıf öğretmeniyle yazışabilmeli.
      final homeroomPath = '$classRoomPath/staff/$teacherUid';

      // Tek batch: sınıf odası + kadro + token birlikte yazılır
      // (maliyet kararı #7).
      return await _client.commitBatch({
        classRoomPath: {
          'classCloudId': classCloudId,
          'className': token.className,
          'schoolId': token.schoolId,
          'schoolName': token.schoolName,
          'teacherUid': teacherUid,
          'teacherName': teacherName,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        homeroomPath: {
          'teacherUid': teacherUid,
          'teacherName': teacherName,
          'branch': 'Sınıf Öğretmeni',
          'isHomeroom': true,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        tokenPath: {
          // DİKKAT: düz kod (token.code) buraya asla yazılmaz.
          'classCloudId': classCloudId,
          'studentCloudId': studentCloudId,
          'teacherUid': teacherUid,
          'schoolId': token.schoolId,
          'schoolName': token.schoolName,
          'className': token.className,
          'studentName': token.studentName,
          'studentNumber': token.studentNumber,
          'secondFactorHash': token.secondFactorHash,
          'expiresAt': token.expiresAt.toIso8601String(),
          'status': token.status,
          'linkedParentCount': token.linkedParentCount,
          'maxLinkedParents': token.maxLinkedParents,
          'createdAt': token.createdAt.toIso8601String(),
        },
      });
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (CloudTokenRepository.publishToken) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('--------------------------------------------------------------------------------');
      return false;
    }
  }

  /// Veli tarafı: kod hash'inden token kaydını okur (tek doküman okuması).
  Future<CloudTokenLookup> lookupByCodeHash(String codeHash) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return CloudTokenLookup.notFound;

    try {
      final data = await _client.getDoc(_tokenPath(codeHash));
      if (data == null) return CloudTokenLookup.notFound;

      return CloudTokenLookup(
        found: true,
        classCloudId: data['classCloudId'] as String?,
        studentCloudId: data['studentCloudId'] as String?,
        teacherUid: data['teacherUid'] as String?,
        schoolId: data['schoolId'] as String?,
        schoolName: data['schoolName'] as String?,
        className: data['className'] as String?,
        studentName: data['studentName'] as String?,
        studentNumber: (data['studentNumber'] as num?)?.toInt() ?? 0,
        secondFactorHash: data['secondFactorHash'] as String?,
        expiresAt: DateTime.tryParse(data['expiresAt'] as String? ?? ''),
        status: data['status'] as String? ?? 'active',
        linkedParentCount: (data['linkedParentCount'] as num?)?.toInt() ?? 0,
        maxLinkedParents: (data['maxLinkedParents'] as num?)?.toInt() ?? 2,
      );
    } catch (e, stackTrace) {
      debugPrint('CloudTokenRepository.lookupByCodeHash hatası: $e\n$stackTrace');
      return CloudTokenLookup.notFound;
    }
  }

  /// Doğrulama başarılı olduğunda veli–öğrenci bağını buluta yazar.
  ///
  /// Üç yazma tek batch'te yapılır:
  /// 1. `parent_links/{uid}_{studentCloudId}` — bağın kendisi
  /// 2. `parent_class_access/{uid}_{classCloudId}` — duyuru okuma izni
  /// 3. token sayacı +1 (veya son veliyse token silinir)
  ///
  /// Token bağlantı sonrası **silinir** (maliyet kararı #6): kullanılmış
  /// kod depolamada tutulmaz.
  Future<bool> commitParentLink({
    required String parentUid,
    required String parentName,
    required String relation,
    required CloudTokenLookup token,
    required String codeHash,
  }) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return false;

    final studentCloudId = token.studentCloudId;
    final classCloudId = token.classCloudId;
    if (studentCloudId == null || classCloudId == null) return false;

    try {
      final linkId = CloudIds.parentLinkId(
        parentUid: parentUid,
        studentCloudId: studentCloudId,
      );
      final accessId = CloudIds.parentClassAccessId(
        parentUid: parentUid,
        classCloudId: classCloudId,
      );

      final newCount = token.linkedParentCount + 1;
      final tokenExhausted = newCount >= token.maxLinkedParents;
      final now = DateTime.now().toIso8601String();

      final writes = <String, Map<String, dynamic>?>{
        '$_linksCollection/$linkId': {
          'parentUid': parentUid,
          'parentName': parentName,
          'relation': relation,
          'studentCloudId': studentCloudId,
          'studentName': token.studentName,
          'studentNumber': token.studentNumber,
          'classCloudId': classCloudId,
          'className': token.className,
          'schoolId': token.schoolId,
          'schoolName': token.schoolName,
          'teacherUid': token.teacherUid,
          'status': 'active',
          'linkedAt': now,
        },
        '$_classAccessCollection/$accessId': {
          'parentUid': parentUid,
          'classCloudId': classCloudId,
          'studentCloudId': studentCloudId,
          'grantedAt': now,
        },
        // Token tükendiyse sil (null = silme), değilse sayacı güncelle.
        _tokenPath(codeHash): tokenExhausted
            ? null
            : {
                'linkedParentCount': newCount,
                'updatedAt': now,
              },
      };

      return await _client.commitBatch(writes);
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (CloudTokenRepository.commitParentLink) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('------------------------------------------------------------------------------------');
      return false;
    }
  }

  /// Öğretmen kodu iptal ettiğinde bulut kaydını siler.
  Future<bool> revokeToken(String codeHash) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return false;
    return _client.deleteDoc(_tokenPath(codeHash));
  }

  /// Bir sınıfa bağlı velileri BULUTTAN getirir.
  ///
  /// Öğretmenin mesaj kutusu bunu kullanır. Yerel `parent_links` deposu
  /// yalnızca velinin kendi cihazında dolu olduğu için öğretmen kimin
  /// bağlandığını oradan göremez — veli mesaj gönderiyor ama öğretmende
  /// hiçbir yerde görünmüyordu.
  Future<List<ParentLinkModel>> fetchClassParentLinks({
    required String classCloudId,
    required String teacherUid,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null || classCloudId.isEmpty) return const [];

    try {
      final snap = await db
          .collection(_linksCollection)
          .where('classCloudId', isEqualTo: classCloudId)
          .where('teacherUid', isEqualTo: teacherUid)
          .limit(200)
          .get()
          .timeout(const Duration(seconds: 8));

      await _client.recordQueryReads(snap.docs.length);

      final result = snap.docs.map((d) {
        final data = d.data();
        final studentCloudId = data['studentCloudId'] as String? ?? '';
        return ParentLinkModel(
          id: d.id,
          parentUserId: data['parentUid'] as String? ?? '',
          parentName: data['parentName'] as String? ?? '',
          studentId: CloudIds.localIdOf(studentCloudId) ?? 0,
          studentName: data['studentName'] as String? ?? '',
          studentNumber: (data['studentNumber'] as num?)?.toInt() ?? 0,
          schoolId: data['schoolId'] as String? ?? '',
          schoolName: data['schoolName'] as String? ?? '',
          classId: CloudIds.localIdOf(classCloudId) ?? 0,
          className: data['className'] as String? ?? '',
          relation: data['relation'] as String? ?? 'Veli',
          linkedAt:
              DateTime.tryParse(data['linkedAt'] as String? ?? '') ??
                  DateTime.now(),
          linkedViaTokenCode: '',
          status: data['status'] as String? ?? 'active',
          classCloudId: classCloudId,
          studentCloudId: studentCloudId,
          teacherUid: data['teacherUid'] as String? ?? '',
        );
      }).where((l) => l.status == 'active').toList();

      result.sort((a, b) => a.studentName.compareTo(b.studentName));
      return result;
    } catch (e, stackTrace) {
      debugPrint('fetchClassParentLinks hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Velinin bulut erişim kayıtlarını garanti eder.
  ///
  /// Kural motoru duyuru ve mesaj okumasını `parent_links` ve
  /// `parent_class_access` dokümanlarının VARLIĞINA bağlar. Bağ yerel
  /// yoldan kurulduğunda (bulut doğrulaması atlandığında) bu kayıtlar
  /// hiç yazılmıyordu; sonuç PERMISSION_DENIED oluyor ve veli ekranı
  /// sessizce boş kalıyordu — hata yalnızca logda görünüyordu.
  ///
  /// Zaten varsa yeniden yazmak zararsızdır (merge).
  Future<bool> ensureParentAccess({
    required String parentUid,
    required String parentName,
    required String relation,
    required String studentCloudId,
    required String classCloudId,
    required String studentName,
    required int studentNumber,
    required String className,
    required String schoolId,
    required String schoolName,
    required String teacherUid,
    required String codeHash,
  }) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return false;
    if (parentUid.isEmpty || studentCloudId.isEmpty || classCloudId.isEmpty) {
      return false;
    }

    // Kural motoru bağın gerçek bir referans koduna dayandığını
    // doğruluyor. Kod hash'i olmadan yazma reddedilir; bu, kod bilmeyen
    // birinin sahte bağ kurup sınıf duyurularını okumasını engeller.
    if (codeHash.isEmpty) {
      debugPrint(
        'ensureParentAccess: codeHash boş — bağ yazılamaz. '
        'Eski kayıtlarda kod saklanmamış olabilir.',
      );
      return false;
    }

    try {
      final linkId = CloudIds.parentLinkId(
        parentUid: parentUid,
        studentCloudId: studentCloudId,
      );
      final accessId = CloudIds.parentClassAccessId(
        parentUid: parentUid,
        classCloudId: classCloudId,
      );
      final now = DateTime.now().toIso8601String();

      return await _client.commitBatch(<String, Map<String, dynamic>?>{
        '$_linksCollection/$linkId': {
          'parentUid': parentUid,
          'parentName': parentName,
          'relation': relation,
          'studentCloudId': studentCloudId,
          'studentName': studentName,
          'studentNumber': studentNumber,
          'classCloudId': classCloudId,
          'className': className,
          'schoolId': schoolId,
          'schoolName': schoolName,
          'teacherUid': teacherUid,
          'status': 'active',
          'linkedAt': now,
          // Kural motoru bunu `parent_tokens/{codeHash}` ile eşleştirir.
          'codeHash': codeHash,
        },
        '$_classAccessCollection/$accessId': {
          'parentUid': parentUid,
          'classCloudId': classCloudId,
          'studentCloudId': studentCloudId,
          'grantedAt': now,
        },
      });
    } catch (e, stackTrace) {
      debugPrint('ensureParentAccess hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Öğretmen yönü: veli bağını ve sınıf erişimini buluttan kaldırır.
  ///
  /// Öğrenci okuldan ayrıldığında (mezuniyet, başka okula nakil, kayıt
  /// silme) çağrılır. Yerel temizlik tek başına yetmez: bağ ve erişim
  /// kayıtları bulutta durduğu sürece veli duyuruları görmeye ve
  /// öğretmene yazmaya devam edebilirdi.
  ///
  /// İkisi tek batch'te silinir; yarım kalırsa veli sınıf duyurularını
  /// görmeye devam ederdi.
  Future<bool> unlinkParent({
    required String parentUid,
    required String studentCloudId,
    required String classCloudId,
  }) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return false;

    try {
      final linkId = CloudIds.parentLinkId(
        parentUid: parentUid,
        studentCloudId: studentCloudId,
      );
      final accessId = CloudIds.parentClassAccessId(
        parentUid: parentUid,
        classCloudId: classCloudId,
      );

      return await _client.commitBatch(<String, Map<String, dynamic>?>{
        '$_linksCollection/$linkId': null,
        '$_classAccessCollection/$accessId': null,
      });
    } catch (e, stackTrace) {
      debugPrint('unlinkParent hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Velinin yalnızca sınıf erişimini değiştirir (şube değişikliği).
  ///
  /// Bağ korunur — çocuk aynı çocuktur — ama eski şubenin duyuruları
  /// kapanıp yenisi açılır. Aksi hâlde her şube değişikliğinde veliye
  /// yeniden kod dağıtmak gerekirdi.
  Future<bool> moveClassAccess({
    required String parentUid,
    required String studentCloudId,
    required String oldClassCloudId,
    required String newClassCloudId,
    required String newClassName,
  }) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return false;
    if (oldClassCloudId == newClassCloudId) return true;

    try {
      final linkId = CloudIds.parentLinkId(
        parentUid: parentUid,
        studentCloudId: studentCloudId,
      );
      final oldAccessId = CloudIds.parentClassAccessId(
        parentUid: parentUid,
        classCloudId: oldClassCloudId,
      );
      final newAccessId = CloudIds.parentClassAccessId(
        parentUid: parentUid,
        classCloudId: newClassCloudId,
      );

      // commitBatch her yazmayı merge:true ile yapar; bu yüzden bağ
      // dokümanının yalnızca sınıf alanı güncellenir, diğerleri korunur.
      final writes = <String, Map<String, dynamic>?>{
        '$_classAccessCollection/$newAccessId': {
          'parentUid': parentUid,
          'classCloudId': newClassCloudId,
          'studentCloudId': studentCloudId,
          'grantedAt': DateTime.now().toIso8601String(),
        },
        '$_linksCollection/$linkId': <String, dynamic>{
          'classCloudId': newClassCloudId,
          'className': newClassName,
        },
      };
      if (oldAccessId != newAccessId) {
        writes['$_classAccessCollection/$oldAccessId'] = null;
      }
      return await _client.commitBatch(writes);
    } catch (e, stackTrace) {
      debugPrint('moveClassAccess hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Velinin bağlı olduğu çocuğun bulut kaydını okur (tek doküman).
  Future<ParentLinkModel?> readLink({
    required String parentUid,
    required String studentCloudId,
  }) async {
    await _client.ensureConfigured();
    if (!_client.isReady) return null;

    final linkId = CloudIds.parentLinkId(
      parentUid: parentUid,
      studentCloudId: studentCloudId,
    );
    final data = await _client.getDoc('$_linksCollection/$linkId');
    if (data == null) return null;

    return ParentLinkModel(
      id: linkId,
      parentUserId: parentUid,
      parentName: data['parentName'] as String? ?? '',
      studentId: CloudIds.localIdOf(studentCloudId) ?? 0,
      studentName: data['studentName'] as String? ?? '',
      studentNumber: (data['studentNumber'] as num?)?.toInt() ?? 0,
      schoolId: data['schoolId'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      classId: CloudIds.localIdOf(data['classCloudId'] as String? ?? '') ?? 0,
      className: data['className'] as String? ?? '',
      relation: data['relation'] as String? ?? 'Anne',
      linkedAt: DateTime.tryParse(data['linkedAt'] as String? ?? '') ?? DateTime.now(),
      linkedViaTokenCode: '',
      status: data['status'] as String? ?? 'active',
      classCloudId: data['classCloudId'] as String? ?? '',
      studentCloudId: studentCloudId,
      teacherUid: data['teacherUid'] as String? ?? '',
    );
  }
}
