import 'package:sqflite/sqflite.dart';

/// Artı-eksi listesinin SQLite şeması.
///
/// `DatabaseHelper` bunu üç yerden çağırır: yeni kurulum, sürüm 29 göçü ve
/// her açılış. Testler de aynı fonksiyonu çağırır (şema kopyalanmaz). Hepsi
/// `IF NOT EXISTS`; tekrar çağrı zararsız.
///
/// Tablo yeni, ALTER yok: sonradan eklenen sütun eski cihazlarda NULL
/// kalıyor (ALTER TABLE tuzağı).
///
/// Sınıf ya da öğrenci silinince kayıtları da silinir (CASCADE).
Future<void> artiEksiTablosunuKur(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS arti_eksi_kayitlari (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      class_id INTEGER NOT NULL,
      student_id INTEGER NOT NULL,
      deger INTEGER NOT NULL CHECK (deger IN (1, -1)),
      tarih TEXT NOT NULL,
      olusturma TEXT NOT NULL,
      FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
    )
  ''');
  // Liste her açılışta "bu sınıf + bu dönem" ile sorgulanıyor.
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_arti_eksi_sinif_tarih '
    'ON arti_eksi_kayitlari (class_id, tarih)',
  );
}
