import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/arti_eksi_model.dart';

/// Artı-eksi kayıtları. Veri cihazda kalır, buluta gitmez.
class ArtiEksiRepository {
  ArtiEksiRepository({Future<Database> Function()? veritabani})
      : _veritabani = veritabani ?? (() => DatabaseHelper.instance.database);

  final Future<Database> Function() _veritabani;

  static const _tablo = 'arti_eksi_kayitlari';

  /// Artı (`deger: 1`) ya da eksi (`deger: -1`) ekler; kaydın kimliğini
  /// döndürür ("Geri al" için).
  Future<int> ekle({
    required int classId,
    required int studentId,
    required int deger,
    required String tarih,
  }) async {
    if (deger != 1 && deger != -1) {
      throw ArgumentError.value(deger, 'deger', 'yalnız 1 ya da -1');
    }
    final db = await _veritabani();
    return db.insert(_tablo, {
      'class_id': classId,
      'student_id': studentId,
      'deger': deger,
      'tarih': tarih,
      'olusturma': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sil(int id) async {
    final db = await _veritabani();
    await db.delete(_tablo, where: 'id = ?', whereArgs: [id]);
  }

  /// Sınıfın aralıktaki kayıtları, eklenme sırasıyla.
  Future<List<ArtiEksiKaydi>> kayitlar({
    required int classId,
    required ArtiEksiAraligi aralik,
  }) async {
    final db = await _veritabani();
    final satirlar = await db.query(
      _tablo,
      where: 'class_id = ? AND tarih >= ? AND tarih <= ?',
      whereArgs: [classId, aralik.baslangic, aralik.bitis],
      orderBy: 'id ASC',
    );
    return satirlar.map(ArtiEksiKaydi.fromMap).toList();
  }
}
