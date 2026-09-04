/// Öğrencinin okuldan ayrılma sebebi.
enum DepartureReason {
  /// Mezun oldu (8. sınıf sonu, lise bitirme).
  graduated,

  /// Başka bir okula nakil gitti.
  transferredToAnotherSchool,

  /// Öğrenci kaydı silindi (yanlış giriş, veli talebi, KVKK).
  deleted,
}

/// Bir yaşam döngüsü olayında veli erişimine ne yapılacağı.
///
/// Kararı tek yerde toplar: aynı mantık hem öğrenci silme, hem nakil,
/// hem de dönem sonu akışından çağrılır. Kural tek yerde durduğu için
/// bir yolu düzeltip diğerini unutmak mümkün değildir.
class LifecycleDecision {
  /// Öğrencinin referans kodları kapatılsın mı?
  final bool revokeTokens;

  /// Veli–öğrenci bağı sonlandırılsın mı?
  final bool endParentLinks;

  /// Velinin sınıf duyurularına erişimi kaldırılsın mı?
  final bool removeClassAccess;

  /// Yeni sınıfın erişimi verilsin mi? (şube değişikliği)
  final bool grantNewClassAccess;

  /// Cihazdaki veriler kalıcı olarak silinsin mi? (KVKK unutulma hakkı)
  final bool purgeLocalData;

  /// Kodlara yazılacak yeni durum: 'revoked' | 'graduated' | 'transferred'.
  final String tokenStatus;

  /// Yapılacak bir şey yok (ör. aynı sınıfa taşıma).
  final bool isNoOp;

  const LifecycleDecision({
    this.revokeTokens = false,
    this.endParentLinks = false,
    this.removeClassAccess = false,
    this.grantNewClassAccess = false,
    this.purgeLocalData = false,
    this.tokenStatus = 'revoked',
    this.isNoOp = false,
  });
}

/// Öğrenci yaşam döngüsü olaylarında veli erişimi politikası.
///
/// Bu kurallar önce hiçbir yerden çağrılmıyordu: öğrenci silinse de
/// nakil gitse de veli bağı ve referans kodu ayakta kalıyordu — yani
/// okuldan ayrılmış bir öğrencinin velisi duyuruları görmeye ve öğretmene
/// yazmaya devam edebiliyordu.
class StudentLifecyclePolicy {
  const StudentLifecyclePolicy._();

  /// Öğrenci okuldan ayrıldığında (mezuniyet, nakil, silme).
  ///
  /// Üçünde de veli erişimi tamamen kapanır; fark yalnızca koda yazılan
  /// durum ve cihaz verisinin silinip silinmeyeceğidir.
  static LifecycleDecision forDeparture(DepartureReason reason) {
    switch (reason) {
      case DepartureReason.graduated:
        return const LifecycleDecision(
          revokeTokens: true,
          endParentLinks: true,
          removeClassAccess: true,
          tokenStatus: 'graduated',
        );
      case DepartureReason.transferredToAnotherSchool:
        return const LifecycleDecision(
          revokeTokens: true,
          endParentLinks: true,
          removeClassAccess: true,
          tokenStatus: 'transferred',
        );
      case DepartureReason.deleted:
        // KVKK unutulma hakkı: kayıt tamamen silinir.
        return const LifecycleDecision(
          revokeTokens: true,
          endParentLinks: true,
          removeClassAccess: true,
          purgeLocalData: true,
          tokenStatus: 'revoked',
        );
    }
  }

  /// Öğrenci aynı okulda başka bir şubeye geçtiğinde.
  ///
  /// Bağ KORUNUR: çocuk aynı çocuktur, veli aynı velidir. Yalnızca sınıf
  /// erişimi güncellenir — eski şubenin duyuruları kapanır, yenisi açılır.
  /// Aksi hâlde her şube değişikliğinde 30 veliye yeniden kod dağıtmak
  /// gerekirdi.
  static LifecycleDecision forClassChange({
    required int oldClassId,
    required int newClassId,
  }) {
    if (oldClassId == newClassId) {
      return const LifecycleDecision(isNoOp: true);
    }

    return const LifecycleDecision(
      revokeTokens: false,
      endParentLinks: false,
      removeClassAccess: true,
      grantNewClassAccess: true,
    );
  }
}
