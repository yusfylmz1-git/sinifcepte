/// Firestore maliyet projeksiyonu.
///
/// Yayın kararı için "kaç öğretmende ücretsiz katman aşılır" sorusunun
/// cevabı gerekiyordu. Bu dosya tahmini prozayla değil, **kodda ölçülen
/// gerçek işlem sayılarıyla** hesaplar; sayılar değişirse test kırılır.
///
/// Ölçüm kaynağı: `cloud_communication_repository.dart` ve
/// `cloud_token_repository.dart` içindeki yazma/okuma çağrıları.
/// Öğrenci notu, katılım, devamsızlık ve veli telefonu buluta hiç
/// gitmiyor — bu yüzden maliyet yalnızca iletişim trafiğinden geliyor.
library;

/// Firestore Spark (ücretsiz) katman günlük sınırları.
class FirestoreFreeTier {
  static const int dailyReads = 50000;
  static const int dailyWrites = 20000;
  static const int dailyDeletes = 20000;

  const FirestoreFreeTier._();
}

/// Tek bir öğretmenin günlük bulut işlem tahmini.
class TeacherDailyUsage {
  /// Duyuru yayımlama (sınıf odası + duyuru dokümanı).
  final int announcements;

  /// Veliye gönderilen mesaj.
  final int messages;

  /// Yeni veli kodu üretimi (sınıf odası + kadro + token).
  final int tokenPublishes;

  /// Uygulamayı açıp mesaj/duyuru listesini tazeleme sayısı.
  final int refreshes;

  const TeacherDailyUsage({
    this.announcements = 1,
    this.messages = 10,
    this.tokenPublishes = 1,
    this.refreshes = 8,
  });

  /// Tipik bir gün: birkaç mesaj, ara sıra duyuru.
  static const typical = TeacherDailyUsage();

  /// Yoğun gün: karne dönemi, veli toplantısı öncesi.
  static const heavy = TeacherDailyUsage(
    announcements: 3,
    messages: 40,
    tokenPublishes: 5,
    refreshes: 20,
  );

  /// Günlük yazma sayısı.
  ///
  /// `publishToken` tek toplu yazmada 3 doküman yazıyor (sınıf odası,
  /// kadro satırı, token). Duyuru da sınıf odasını tazelediği için 2.
  int get writes =>
      announcements * 2 + messages * 1 + tokenPublishes * 3;

  /// Günlük okuma sayısı.
  ///
  /// **Delta senkronizasyonu belirleyici.** `DeltaSyncTracker` son çekim
  /// damgasını kalıcı tutuyor ve sorgulara `since` olarak geçiriyor;
  /// yeni bir şey yoksa sorgu **sıfır doküman** okur. Sayfa sınırı (20/50)
  /// yalnızca ilk açılışta ya da uzun aradan sonra devreye girer.
  ///
  /// Bu yüzden okuma, tazeleme sayısıyla değil **gerçekten gelen yeni
  /// mesaj sayısıyla** orantılıdır. Öğretmen kendi yazdığı mesajları da
  /// geri okur, o yüzden mesaj sayısı iki kez sayılır.
  int get reads => messages * 2 + announcements * 2;
}

/// Bir veli hesabının günlük işlem tahmini.
///
/// Veli yalnızca okur ve ara sıra mesaj yazar; öğretmenden daha hafiftir.
class ParentDailyUsage {
  final int messages;
  final int refreshes;

  const ParentDailyUsage({this.messages = 2, this.refreshes = 5});

  static const typical = ParentDailyUsage();

  int get writes => messages;

  /// Delta damgası sayesinde tazeleme başına sabit maliyet yok; veli
  /// yalnızca kendisine gelen yeni mesajları ve duyuruları okur.
  /// Öğretmenin cevabı + sınıf duyurusu için küçük bir pay eklenir.
  int get reads => messages * 2 + 3;
}

/// Belirli bir kullanıcı sayısı için günlük toplam.
class CostProjection {
  final int teachers;
  final int parentsPerTeacher;
  final TeacherDailyUsage teacherUsage;
  final ParentDailyUsage parentUsage;

  const CostProjection({
    required this.teachers,
    this.parentsPerTeacher = 25,
    this.teacherUsage = TeacherDailyUsage.typical,
    this.parentUsage = ParentDailyUsage.typical,
  });

  int get parents => teachers * parentsPerTeacher;

  int get dailyWrites =>
      teachers * teacherUsage.writes + parents * parentUsage.writes;

  int get dailyReads =>
      teachers * teacherUsage.reads + parents * parentUsage.reads;

  bool get exceedsFreeWrites => dailyWrites > FirestoreFreeTier.dailyWrites;
  bool get exceedsFreeReads => dailyReads > FirestoreFreeTier.dailyReads;
  bool get exceedsFreeTier => exceedsFreeWrites || exceedsFreeReads;

  /// Ücretsiz katmanın yazma tarafında kaç öğretmende dolduğu.
  static int maxTeachersOnFreeWrites({
    int parentsPerTeacher = 25,
    TeacherDailyUsage teacherUsage = TeacherDailyUsage.typical,
    ParentDailyUsage parentUsage = ParentDailyUsage.typical,
  }) {
    final perTeacher =
        teacherUsage.writes + parentsPerTeacher * parentUsage.writes;
    return FirestoreFreeTier.dailyWrites ~/ perTeacher;
  }

  /// Okuma tarafında kaç öğretmende dolduğu.
  static int maxTeachersOnFreeReads({
    int parentsPerTeacher = 25,
    TeacherDailyUsage teacherUsage = TeacherDailyUsage.typical,
    ParentDailyUsage parentUsage = ParentDailyUsage.typical,
  }) {
    final perTeacher =
        teacherUsage.reads + parentsPerTeacher * parentUsage.reads;
    return FirestoreFreeTier.dailyReads ~/ perTeacher;
  }

  /// Blaze planına geçilmesi gereken öğretmen sayısı (hangisi önce dolarsa).
  static int blazeThreshold({int parentsPerTeacher = 25}) {
    final w = maxTeachersOnFreeWrites(parentsPerTeacher: parentsPerTeacher);
    final r = maxTeachersOnFreeReads(parentsPerTeacher: parentsPerTeacher);
    return w < r ? w : r;
  }
}
