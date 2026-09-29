import 'package:sqflite/sqflite.dart';

/// e-Okul fotoğraf modülünün SQLite şeması.
///
/// ## Neden tek fonksiyon
/// `DatabaseHelper` bunu üç yerden çağırır: yeni kurulum (`_createDB`),
/// sürüm 28 göçü (`_onUpgrade`) ve her açılış (`_onOpen`). Testler de
/// AYNI fonksiyonu çağırır; şemanın test dosyasında elle kopyalanması
/// (devamsızlık testindeki gibi) kopya ile gerçeğin ayrışmasına yol
/// açıyordu. Hepsi `IF NOT EXISTS` — tekrar çağrı zararsız.
///
/// ## Tablo yeni, ALTER yok
/// `students` tablosuna sütun EKLENMEDİ. Sonradan eklenen sütun eski
/// cihazlarda NULL kalıyor (ALTER TABLE tuzağı); ayrı tablo bu riski
/// taşımaz ve revizyon/temizlik/yedek için zaten gerekiyor.
///
/// ## Silme zinciri
/// Sınıf silinir → öğrenci silinir (CASCADE) → fotoğraf kaydı silinir
/// (CASCADE) → tetikleyici dosya yollarını `photo_cleanup_queue`'ya
/// yazar. Böylece fotoğraf dosyası hangi yoldan silinirse silinsin
/// (öğrenci ekranı, sınıf silme, ileride başka bir ekran) diskte sahipsiz
/// kalmaz; kuyruk bir sonraki temizlikte işlenir. Dosya silmek SQLite
/// işleminin parçası olamadığı için kuyruk şart.
Future<void> ogrenciFotoTablolariniKur(DatabaseExecutor db) async {
  // Kimlik METİN: dosya klasör adı da bu. Dosya veritabanından ÖNCE
  // yazıldığı için kimlik önceden bilinmeli (güvenli kayıt protokolü).
  await db.execute('''
    CREATE TABLE IF NOT EXISTS student_photos (
      id TEXT PRIMARY KEY,
      student_id INTEGER NOT NULL,
      revision INTEGER NOT NULL,
      is_current INTEGER NOT NULL DEFAULT 1,
      status TEXT NOT NULL DEFAULT 'hazir',
      standard_relative_path TEXT NOT NULL,
      album_relative_path TEXT,
      original_background_relative_path TEXT,
      background_mode TEXT NOT NULL DEFAULT 'ozgun',
      background_processing_version INTEGER,
      background_quality_flags TEXT,
      width INTEGER NOT NULL,
      height INTEGER NOT NULL,
      byte_size INTEGER NOT NULL,
      mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
      checksum TEXT NOT NULL,
      source_type TEXT NOT NULL,
      captured_school_number INTEGER NOT NULL,
      captured_full_name TEXT NOT NULL,
      identity_confirmed_at TEXT NOT NULL,
      captured_at TEXT NOT NULL,
      approved_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      quality_flags TEXT,
      processing_profile_version INTEGER NOT NULL DEFAULT 1,
      manual_quality_override INTEGER NOT NULL DEFAULT 0,
      UNIQUE (student_id, revision),
      FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
    )
  ''');

  // Öğrenci başına EN FAZLA BİR güncel fotoğraf — veritabanı düzeyinde.
  // Depo katmanı da korur ama iki ekran aynı anda kaydederse son söz
  // burada.
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS ux_student_photos_current '
    'ON student_photos (student_id) WHERE is_current = 1',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS photo_cleanup_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      relative_path TEXT NOT NULL,
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      completed_at TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_photo_cleanup_pending '
    'ON photo_cleanup_queue (completed_at)',
  );

  // Üç ayrı INSERT: boş olan yol kuyruğa girmesin.
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS trg_student_photos_cleanup
    AFTER DELETE ON student_photos
    BEGIN
      INSERT INTO photo_cleanup_queue (relative_path, reason, created_at)
        SELECT OLD.standard_relative_path, 'kayit_silindi',
               strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
        WHERE OLD.standard_relative_path IS NOT NULL
          AND OLD.standard_relative_path <> '';
      INSERT INTO photo_cleanup_queue (relative_path, reason, created_at)
        SELECT OLD.album_relative_path, 'kayit_silindi',
               strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
        WHERE OLD.album_relative_path IS NOT NULL
          AND OLD.album_relative_path <> '';
      INSERT INTO photo_cleanup_queue (relative_path, reason, created_at)
        SELECT OLD.original_background_relative_path, 'kayit_silindi',
               strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
        WHERE OLD.original_background_relative_path IS NOT NULL
          AND OLD.original_background_relative_path <> '';
    END
  ''');

  // Seri çekim oturumu: uygulama kapanırsa kaldığı yerden sürsün.
  // Sıra JSON (öğrenci kimlikleri); öğrenci silinir ya da sınıf
  // değiştirirse oturum açılırken yeniden doğrulanır.
  await db.execute('''
    CREATE TABLE IF NOT EXISTS photo_capture_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      class_id INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'suruyor',
      student_order TEXT NOT NULL,
      position INTEGER NOT NULL DEFAULT 0,
      completed TEXT NOT NULL DEFAULT '[]',
      skipped TEXT NOT NULL DEFAULT '[]',
      started_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
    )
  ''');
}
