import 'package:sqflite/sqflite.dart';

import '../domain/cekim_sirasi.dart';

/// Seri çekim oturumu (`photo_capture_sessions`). Her adımdan sonra
/// yazılır: uygulama kapanırsa ya da telefon kamera açıkken uygulamayı
/// bellekten atarsa oturum kaldığı öğrenciden sürer (plan Faz 3 çıkış
/// ölçütü).
class CekimOturumuDeposu {
  CekimOturumuDeposu(this._veritabani, {DateTime Function()? saat}) : _saat = saat ?? DateTime.now;

  final Future<Database> Function() _veritabani;
  final DateTime Function() _saat;

  String _zaman() => _saat().toUtc().toIso8601String();

  /// Sınıfın süren oturumu (varsa).
  Future<(int, CekimSirasi)?> aktif(int sinifId) async {
    final db = await _veritabani();
    final r = await db.query(
      'photo_capture_sessions',
      where: "class_id = ? AND status = 'suruyor'",
      whereArgs: [sinifId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (r.first['id']! as int, CekimSirasi.satirdan(r.first));
  }

  /// Yeni oturum; sınıfın süren oturumu varsa kapatılır (sınıf başına
  /// tek süren oturum).
  Future<(int, CekimSirasi)> baslat(int sinifId, List<int> sira) async {
    final db = await _veritabani();
    final s = CekimSirasi(sira: sira);
    late int id;
    await db.transaction((tx) async {
      await tx.update('photo_capture_sessions', {'status': 'bitti', 'updated_at': _zaman()},
          where: "class_id = ? AND status = 'suruyor'", whereArgs: [sinifId]);
      id = await tx.insert('photo_capture_sessions', {
        'class_id': sinifId,
        'status': 'suruyor',
        'student_order': s.siraJson,
        'position': 0,
        'completed': s.tamamlananJson,
        'skipped': s.atlananJson,
        'started_at': _zaman(),
        'updated_at': _zaman(),
      });
    });
    return (id, s);
  }

  Future<void> yaz(int oturumId, CekimSirasi s) async {
    final db = await _veritabani();
    await db.update(
      'photo_capture_sessions',
      {
        'student_order': s.siraJson,
        'position': s.konum,
        'completed': s.tamamlananJson,
        'skipped': s.atlananJson,
        'updated_at': _zaman(),
      },
      where: 'id = ?',
      whereArgs: [oturumId],
    );
  }

  Future<void> bitir(int oturumId) async {
    final db = await _veritabani();
    await db.update('photo_capture_sessions', {'status': 'bitti', 'updated_at': _zaman()},
        where: 'id = ?', whereArgs: [oturumId]);
  }
}
