import 'package:flutter/foundation.dart';
import '../models/parent_token_model.dart';
import '../repositories/cloud_token_repository.dart';

/// Köprü sonucu: veli tarafında kod doğrulamasının çıktısı.
class BridgeLinkResult {
  final bool success;
  final String message;

  /// Bağlanan çocuğun bulut kimliği (başarılıysa).
  final String? studentCloudId;
  final String? studentName;
  final String? className;
  final String? schoolName;

  const BridgeLinkResult({
    required this.success,
    required this.message,
    this.studentCloudId,
    this.studentName,
    this.className,
    this.schoolName,
  });

  factory BridgeLinkResult.failure(String message) =>
      BridgeLinkResult(success: false, message: message);
}

/// Öğretmen ↔ veli token köprüsü.
///
/// Projenin kopuk halkasını kapatan servis. İki yönü vardır:
///
/// **Öğretmen yönü** ([publishTokenToCloud]): yerelde üretilmiş kodu buluta
/// yansıtır. Ağ yoksa öğretmene açıkça bildirilir — kod yerelde durur ama
/// veli bağlanamaz, bu sessizce geçilmemelidir.
///
/// **Veli yönü** ([verifyAndLink]): girilen kodu buluttan doğrular ve bağı
/// yazar. Veli cihazında yerel token deposu **yoktur**; doğrulama tamamen
/// bulut üzerinden yapılır.
class ParentLinkBridge {
  ParentLinkBridge({CloudTokenRepository? cloudRepo})
      : _cloud = cloudRepo ?? CloudTokenRepository();

  final CloudTokenRepository _cloud;

  /// Öğretmen yönü: yerel tokenı buluta yayımlar.
  Future<bool> publishTokenToCloud({
    required ParentTokenModel token,
    required String teacherUid,
    required String teacherName,
  }) async {
    if (teacherUid.isEmpty) {
      debugPrint('ParentLinkBridge: teacherUid boş, token buluta yayımlanamadı.');
      return false;
    }
    return _cloud.publishToken(
      token: token,
      teacherUid: teacherUid,
      teacherName: teacherName,
    );
  }

  /// Öğretmen yönü: kod iptalini buluta yansıtır.
  Future<bool> revokeTokenInCloud(String codeHash) =>
      _cloud.revokeToken(codeHash);

  /// Veli yönü: kodu doğrular ve bağı kurar.
  ///
  /// Doğrulama sırası bilinçlidir — önce ucuz kontroller, sonra bulut
  /// okuması, en sonda yazma. Böylece hatalı girişler tek okuma bile
  /// harcamadan elenir.
  Future<BridgeLinkResult> verifyAndLink({
    required String inputCode,
    required String inputStudentNumber,
    required String parentUid,
    required String parentName,
    required String relation,
  }) async {
    final cleanCode = inputCode.replaceAll(' ', '').toUpperCase().trim();
    final cleanNumber = inputStudentNumber.replaceAll(' ', '').trim();

    if (cleanCode.isEmpty) {
      return BridgeLinkResult.failure('Lütfen referans kodunu girin.');
    }
    if (cleanNumber.isEmpty) {
      return BridgeLinkResult.failure('Lütfen öğrencinin okul numarasını girin.');
    }
    if (parentUid.isEmpty) {
      return BridgeLinkResult.failure(
        'Bağlantı için önce Google ile giriş yapmanız gerekiyor.',
      );
    }

    try {
      final codeHash = ParentTokenModel.generateSha256(cleanCode);
      final token = await _cloud.lookupByCodeHash(codeHash);

      if (!token.found) {
        return BridgeLinkResult.failure(
          'Geçersiz referans kodu. Lütfen öğretmeninizin verdiği kodu kontrol edin.',
        );
      }

      if (token.status == 'revoked') {
        return BridgeLinkResult.failure(
          'Bu referans kodu öğretmen tarafından iptal edilmiş. Lütfen yeni kod isteyin.',
        );
      }
      if (token.isExpired) {
        return BridgeLinkResult.failure(
          'Bu referans kodunun süresi dolmuş. Lütfen öğretmeninizden güncel kod isteyin.',
        );
      }
      if (token.linkedParentCount >= token.maxLinkedParents) {
        return BridgeLinkResult.failure(
          'Bu referans koduna izin verilen maksimum veli sayısı (${token.maxLinkedParents}) bağlanmış.',
        );
      }

      // İkinci faktör: öğrencinin okul numarası (yalnızca hash karşılaştırması).
      final inputNumberHash = ParentTokenModel.generateSha256(cleanNumber);
      if (token.secondFactorHash != inputNumberHash) {
        return BridgeLinkResult.failure(
          'Öğrenci okul numarası eşleşmedi! Güvenlik nedeniyle bağlantı kurulamadı.',
        );
      }

      final committed = await _cloud.commitParentLink(
        parentUid: parentUid,
        parentName: parentName,
        relation: relation,
        token: token,
        codeHash: codeHash,
      );

      if (!committed) {
        return BridgeLinkResult.failure(
          'Bağlantı kaydedilemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.',
        );
      }

      return BridgeLinkResult(
        success: true,
        message:
            '${token.studentName} (${token.className}) başarıyla bağlandı!',
        studentCloudId: token.studentCloudId,
        studentName: token.studentName,
        className: token.className,
        schoolName: token.schoolName,
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ParentLinkBridge.verifyAndLink) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-----------------------------------------------------------------------------');
      return BridgeLinkResult.failure(
        'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }
}
