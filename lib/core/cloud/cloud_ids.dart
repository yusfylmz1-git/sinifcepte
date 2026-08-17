/// SınıfCepte bulut kimlik şeması.
///
/// Yerel SQLite kimlikleri (`int id`) yalnızca tek cihazda anlamlıdır: iki
/// farklı öğretmenin veritabanında da `student.id = 5` bulunur. Bulutta
/// çakışmayan, sahibi kimliğinden okunabilen dizeler gerekir.
///
/// ## Şema
/// ```text
/// cls_{teacherUid}_{yerelSinifId}     → /class_rooms/{classCloudId}
/// stu_{teacherUid}_{yerelOgrenciId}   → parent_links içindeki studentCloudId
/// ```
///
/// ## Neden öğretmen UID'si kimliğin içinde
/// `firestore.rules` sahiplik denetimini desen eşlemesiyle yapıyor:
/// ```
/// function ownsClassRoom(classCloudId) {
///   return classCloudId.matches('cls_' + request.auth.uid + '_.*');
/// }
/// ```
/// Böylece sahiplik kontrolü için ekstra doküman okuması gerekmez —
/// kural motoru kimliğin kendisinden karar verir. Bu, hem maliyet hem
/// gecikme açısından en ucuz sahiplik modelidir.
///
/// ## Kararlılık uyarısı
/// Bu şema **geri dönüşü zordur**: bulutta veri oluştuktan sonra desen
/// değişirse mevcut tüm bağlantılar kırılır. Değiştirmeden önce göç
/// (migration) planı gerekir.
class CloudIds {
  CloudIds._();

  static const String classPrefix = 'cls';
  static const String studentPrefix = 'stu';

  /// Sınıfın bulut kimliği: `cls_{teacherUid}_{localClassId}`
  static String classId({
    required String teacherUid,
    required int localClassId,
  }) {
    _assertUid(teacherUid);
    return '${classPrefix}_${teacherUid}_$localClassId';
  }

  /// Öğrencinin bulut kimliği: `stu_{teacherUid}_{localStudentId}`
  ///
  /// Öğrenci sınıf öğretmeninin ağacında yaşar. Branş öğretmenleri aynı
  /// öğrenciye mesaj gönderebilir ancak öğrenci kaydının sahibi değildir.
  static String studentId({
    required String teacherUid,
    required int localStudentId,
  }) {
    _assertUid(teacherUid);
    return '${studentPrefix}_${teacherUid}_$localStudentId';
  }

  /// Veli–öğrenci bağı doküman kimliği: `{parentUid}_{studentCloudId}`
  ///
  /// Kural dosyası `id.matches(request.auth.uid + '_.*')` ile velinin
  /// yalnızca kendi bağlarını okumasını sağlar. Deterministik olduğu için
  /// sorgu değil doğrudan `get()` yapılabilir — tek doküman okuması.
  static String parentLinkId({
    required String parentUid,
    required String studentCloudId,
  }) {
    _assertUid(parentUid);
    return '${parentUid}_$studentCloudId';
  }

  /// Velinin sınıf erişim kaydı: `{parentUid}_{classCloudId}`
  static String parentClassAccessId({
    required String parentUid,
    required String classCloudId,
  }) {
    _assertUid(parentUid);
    return '${parentUid}_$classCloudId';
  }

  /// Bulut sınıf kimliğinden sahibi öğretmenin UID'sini çıkarır.
  ///
  /// Desen bozuksa `null` döner — çağıran taraf bunu erişim reddi
  /// olarak değerlendirmelidir.
  static String? ownerUidOfClass(String classCloudId) =>
      _ownerUid(classCloudId, classPrefix);

  /// Bulut öğrenci kimliğinden sahibi öğretmenin UID'sini çıkarır.
  static String? ownerUidOfStudent(String studentCloudId) =>
      _ownerUid(studentCloudId, studentPrefix);

  /// Verilen öğretmen bu sınıfın sahibi mi?
  static bool teacherOwnsClass({
    required String teacherUid,
    required String classCloudId,
  }) =>
      teacherUid.isNotEmpty && ownerUidOfClass(classCloudId) == teacherUid;

  /// Yerel kimliği bulut kimliğinden geri okur (yalnızca sahibi cihazda anlamlı).
  static int? localIdOf(String cloudId) {
    final parts = cloudId.split('_');
    if (parts.length < 3) return null;
    return int.tryParse(parts.last);
  }

  static String? _ownerUid(String cloudId, String expectedPrefix) {
    final parts = cloudId.split('_');
    // Beklenen: [prefix, uid, localId] — UID'de alt çizgi bulunmaz.
    if (parts.length != 3) return null;
    if (parts[0] != expectedPrefix) return null;
    if (parts[1].isEmpty) return null;
    if (int.tryParse(parts[2]) == null) return null;
    return parts[1];
  }

  /// Firebase UID'leri alt çizgi içermez; içerirse kimlik şeması bozulur
  /// ve sahiplik kontrolü sessizce yanlış sonuç verir.
  static void _assertUid(String uid) {
    assert(uid.isNotEmpty, 'Bulut kimliği için UID boş olamaz.');
    assert(!uid.contains('_'), 'Firebase UID alt çizgi içeremez: $uid');
  }
}
