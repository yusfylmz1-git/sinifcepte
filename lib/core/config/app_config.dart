/// SınıfCepte - Ortam ve Konfigürasyon Yönetimi (AppConfig)
enum Environment { dev, staging, prod }

class AppConfig {
  static Environment environment = Environment.dev;

  static String get appName {
    switch (environment) {
      case Environment.dev:
        return 'SınıfCepte [DEV]';
      case Environment.staging:
        return 'SınıfCepte [BETA]';
      case Environment.prod:
        return 'SınıfCepte';
    }
  }

  static bool get isDebug => environment == Environment.dev;

  /// Testlerin veritabanı adını ayırmak için kullandığı geçersiz kılma.
  ///
  /// `flutter test` dosyaları PARALEL koşturuyor ve hepsi aynı sqlite
  /// yoluna yazınca "database is locked" hatası çıkıyor. Her test
  /// dosyası kendi adını verirse çakışma olmaz.
  ///
  /// Uygulamada hiçbir zaman set edilmez.
  static String? testDbNameOverride;

  // Veritabanı Adı
  static String get dbName {
    final o = testDbNameOverride;
    if (o != null && o.isNotEmpty) return o;
    switch (environment) {
      case Environment.dev:
        return 'sinifcepte_dev.db';
      case Environment.staging:
        return 'sinifcepte_beta.db';
      case Environment.prod:
        return 'sinifcepte.db';
    }
  }

  static String teacherDbName(String uid) {
    final safe = uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'sinifcepte_$safe.db';
  }
}
