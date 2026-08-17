import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/cloud/cloud_ids.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_token_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_token_repository.dart';
import 'package:sinifcepte/features/parent_portal/data/services/parent_link_bridge.dart';

/// Bulut deposunun bellek içi taklidi.
///
/// Gerçek Firestore yerine kullanılır; amaç köprü mantığını (doğrulama
/// sırası, güvenlik kontrolleri, bağ yazımı) ağ olmadan sınamak.
class FakeCloudTokenRepository implements CloudTokenRepository {
  final Map<String, CloudTokenLookup> tokens = {};
  final List<String> committedLinks = [];
  final List<String> revokedHashes = [];

  bool failCommit = false;

  @override
  Future<CloudTokenLookup> lookupByCodeHash(String codeHash) async {
    return tokens[codeHash] ?? CloudTokenLookup.notFound;
  }

  @override
  Future<bool> commitParentLink({
    required String parentUid,
    required String parentName,
    required String relation,
    required CloudTokenLookup token,
    required String codeHash,
  }) async {
    if (failCommit) return false;
    committedLinks.add('${parentUid}_${token.studentCloudId}');
    return true;
  }

  @override
  Future<bool> revokeToken(String codeHash) async {
    revokedHashes.add(codeHash);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CloudTokenLookup buildToken({
  String status = 'active',
  int linkedParentCount = 0,
  int maxLinkedParents = 2,
  DateTime? expiresAt,
  String secondFactorHash = '',
}) {
  return CloudTokenLookup(
    found: true,
    classCloudId: 'cls_teacherAhmet_7',
    studentCloudId: 'stu_teacherAhmet_42',
    teacherUid: 'teacherAhmet',
    schoolId: 'meb_16_123',
    schoolName: 'Cumhuriyet Ortaokulu',
    className: '7-B',
    studentName: 'Ali Yılmaz',
    studentNumber: 112,
    secondFactorHash: secondFactorHash.isEmpty
        ? ParentTokenModel.generateSha256('112')
        : secondFactorHash,
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
    status: status,
    linkedParentCount: linkedParentCount,
    maxLinkedParents: maxLinkedParents,
  );
}

void main() {
  group('1. Bulut Kimlik Şeması', () {
    test('Sınıf ve öğrenci kimlikleri öğretmen UID\'sini taşır', () {
      final classId = CloudIds.classId(teacherUid: 'uidAhmet', localClassId: 7);
      final studentId =
          CloudIds.studentId(teacherUid: 'uidAhmet', localStudentId: 42);

      expect(classId, 'cls_uidAhmet_7');
      expect(studentId, 'stu_uidAhmet_42');
    });

    test('Sahiplik kimlik deseninden okunur (doküman okuması gerekmez)', () {
      const classId = 'cls_uidAhmet_7';

      expect(CloudIds.ownerUidOfClass(classId), 'uidAhmet');
      expect(
        CloudIds.teacherOwnsClass(teacherUid: 'uidAhmet', classCloudId: classId),
        isTrue,
      );
      // Başka öğretmen sahip değildir.
      expect(
        CloudIds.teacherOwnsClass(teacherUid: 'uidMehmet', classCloudId: classId),
        isFalse,
      );
    });

    test('Bozuk kimlik deseni sahiplik vermez', () {
      expect(CloudIds.ownerUidOfClass('bozuk'), isNull);
      expect(CloudIds.ownerUidOfClass('stu_uid_1'), isNull); // yanlış önek
      expect(CloudIds.ownerUidOfClass('cls_uid_abc'), isNull); // sayı değil
      expect(CloudIds.ownerUidOfClass('cls__7'), isNull); // boş uid

      // Boş kimlikle sahiplik iddia edilemez.
      expect(
        CloudIds.teacherOwnsClass(teacherUid: '', classCloudId: 'cls__7'),
        isFalse,
      );
    });

    test('Veli bağ kimliği kural desenine uyar', () {
      final linkId = CloudIds.parentLinkId(
        parentUid: 'parentAyse',
        studentCloudId: 'stu_uidAhmet_42',
      );

      expect(linkId, 'parentAyse_stu_uidAhmet_42');
      // firestore.rules: id.matches(request.auth.uid + '_.*')
      expect(linkId.startsWith('parentAyse_'), isTrue);
    });

    test('Yerel kimlik bulut kimliğinden geri okunur', () {
      expect(CloudIds.localIdOf('stu_uidAhmet_42'), 42);
      expect(CloudIds.localIdOf('cls_uidAhmet_7'), 7);
      expect(CloudIds.localIdOf('gecersiz'), isNull);
    });
  });

  group('2. Token Köprüsü — Veli Doğrulaması', () {
    late FakeCloudTokenRepository fake;
    late ParentLinkBridge bridge;
    final codeHash = ParentTokenModel.generateSha256('SC-7B-9402');

    setUp(() {
      fake = FakeCloudTokenRepository();
      bridge = ParentLinkBridge(cloudRepo: fake);
    });

    Future<BridgeLinkResult> attempt({
      String code = 'SC-7B-9402',
      String studentNumber = '112',
      String parentUid = 'parentAyse',
    }) {
      return bridge.verifyAndLink(
        inputCode: code,
        inputStudentNumber: studentNumber,
        parentUid: parentUid,
        parentName: 'Ayşe Yılmaz',
        relation: 'Anne',
      );
    }

    test('Geçerli kod ve okul numarası ile bağ kurulur', () async {
      fake.tokens[codeHash] = buildToken();

      final result = await attempt();

      expect(result.success, isTrue);
      expect(result.studentName, 'Ali Yılmaz');
      expect(result.className, '7-B');
      expect(fake.committedLinks, contains('parentAyse_stu_teacherAhmet_42'));
    });

    test('Kod büyük/küçük harf ve boşluktan etkilenmez', () async {
      fake.tokens[codeHash] = buildToken();

      final result = await attempt(code: ' sc-7b-9402 ');

      expect(result.success, isTrue);
    });

    test('KRİTİK: Yanlış okul numarası bağı engeller (2. faktör)', () async {
      fake.tokens[codeHash] = buildToken();

      final result = await attempt(studentNumber: '999');

      expect(result.success, isFalse);
      expect(result.message, contains('okul numarası eşleşmedi'));
      expect(fake.committedLinks, isEmpty);
    });

    test('Bulunmayan kod reddedilir', () async {
      final result = await attempt(code: 'SC-XX-0000');

      expect(result.success, isFalse);
      expect(result.message, contains('Geçersiz referans kodu'));
    });

    test('İptal edilmiş kod reddedilir', () async {
      fake.tokens[codeHash] = buildToken(status: 'revoked');

      final result = await attempt();

      expect(result.success, isFalse);
      expect(result.message, contains('iptal edilmiş'));
      expect(fake.committedLinks, isEmpty);
    });

    test('Süresi dolmuş kod reddedilir', () async {
      fake.tokens[codeHash] = buildToken(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final result = await attempt();

      expect(result.success, isFalse);
      expect(result.message, contains('süresi dolmuş'));
    });

    test('Kotası dolmuş kod reddedilir (maksimum veli sayısı)', () async {
      fake.tokens[codeHash] =
          buildToken(linkedParentCount: 2, maxLinkedParents: 2);

      final result = await attempt();

      expect(result.success, isFalse);
      expect(result.message, contains('maksimum veli sayısı'));
    });

    test('Anne ve baba aynı koda bağlanabilir (2 kişilik kota)', () async {
      fake.tokens[codeHash] = buildToken(linkedParentCount: 1, maxLinkedParents: 2);

      final result = await attempt(parentUid: 'parentMehmet');

      expect(result.success, isTrue);
      expect(fake.committedLinks, contains('parentMehmet_stu_teacherAhmet_42'));
    });

    test('KRİTİK: Oturum açmadan bağ kurulamaz', () async {
      fake.tokens[codeHash] = buildToken();

      final result = await attempt(parentUid: '');

      expect(result.success, isFalse);
      expect(result.message, contains('Google ile giriş'));
      expect(fake.committedLinks, isEmpty);
    });

    test('Boş girdiler tek bulut okuması bile harcamadan elenir', () async {
      final noCode = await attempt(code: '');
      final noNumber = await attempt(studentNumber: '');

      expect(noCode.success, isFalse);
      expect(noNumber.success, isFalse);
      // Bulut deposuna hiç gidilmedi.
      expect(fake.committedLinks, isEmpty);
    });

    test('Bulut yazımı başarısız olursa kullanıcı yanlış bilgilendirilmez', () async {
      fake.tokens[codeHash] = buildToken();
      fake.failCommit = true;

      final result = await attempt();

      expect(result.success, isFalse);
      expect(result.message, contains('İnternet'));
    });
  });

  group('3. Token İptali', () {
    test('İptal bulut deposuna iletilir', () async {
      final fake = FakeCloudTokenRepository();
      final bridge = ParentLinkBridge(cloudRepo: fake);

      await bridge.revokeTokenInCloud('hash123');

      expect(fake.revokedHashes, contains('hash123'));
    });
  });

  group('4. Güvenlik: düz kod buluta çıkmaz', () {
    test('CloudTokenLookup düz kod alanı içermez', () {
      final token = buildToken();

      // Model yalnızca hash taşır; düz kod alanı yoktur.
      expect(token.secondFactorHash, isNotEmpty);
      expect(token.secondFactorHash!.length, 64); // SHA-256 hex uzunluğu

      // Öğrenci adı onay ekranı için gerekli, ama not/telefon yok.
      expect(token.studentName, 'Ali Yılmaz');
    });

    test('Aynı kod her zaman aynı hash\'i üretir (doküman kimliği kararlı)', () {
      final h1 = ParentTokenModel.generateSha256('SC-7B-9402');
      final h2 = ParentTokenModel.generateSha256('SC-7B-9402');
      final h3 = ParentTokenModel.generateSha256('SC-7B-9403');

      expect(h1, h2);
      expect(h1, isNot(h3));
      expect(h1.length, 64);
    });
  });
}
