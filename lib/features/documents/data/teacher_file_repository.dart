import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import 'teacher_file_model.dart';

/// Öğretmen dosyası özlük bilgileri deposu.
///
/// ## Neden yeni tablo açılmadı
/// `sistem_ayarlari` zaten anahtar-değer tablosu ve cihazda duruyor.
/// Dokuz alan için ayrı tablo açmak bir şema sürümü daha demekti;
/// 30.000 öğretmenin veritabanını dokuz metin alanı uğruna
/// yükseltmenin karşılığı yok.
///
/// Anahtarlar `ogretmen_dosyasi_` önekiyle yazılır, böylece
/// takvim/başlangıç gibi mevcut ayarlarla karışmaz.
class TeacherFileRepository {
  final DatabaseHelper _db;

  TeacherFileRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  static const _onEk = 'ogretmen_dosyasi_';

  /// Özlük bilgilerini okur. Kayıt yoksa boş model döner.
  Future<TeacherFileInfo> read() async {
    final db = await _db.database;
    final rows = await db.query(
      'sistem_ayarlari',
      where: 'anahtar LIKE ?',
      whereArgs: ['$_onEk%'],
    );

    final map = <String, dynamic>{};
    for (final r in rows) {
      final anahtar = (r['anahtar'] as String?) ?? '';
      if (!anahtar.startsWith(_onEk)) continue;
      map[anahtar.substring(_onEk.length)] = r['deger'] as String? ?? '';
    }
    return TeacherFileInfo.fromMap(map);
  }

  /// Özlük bilgilerini yazar.
  ///
  /// Boş alanlar da yazılır: öğretmen bir alanı silmek istediğinde
  /// eski değerin kalmaması gerekir.
  Future<void> write(TeacherFileInfo bilgi) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final giris in bilgi.toMap().entries) {
      batch.insert(
        'sistem_ayarlari',
        {'anahtar': '$_onEk${giris.key}', 'deger': giris.value.trim()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
