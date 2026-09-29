import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/foto_isleme.dart';
import '../domain/ogrenci_foto.dart';
import 'foto_depolama.dart';

/// Kimliği doğrulanmamış kayıt denemesi, silinmiş öğrenci vb.
class FotoKayitHatasi implements Exception {
  FotoKayitHatasi(this.mesaj);
  final String mesaj;
  @override
  String toString() => mesaj;
}

/// Fotoğraf merkezindeki sınıf kartı: "28/32 hazır".
class SinifFotoOzeti {
  const SinifFotoOzeti({
    required this.toplam,
    required this.hazir,
    required this.inceleme,
    required this.dosyaYok,
  });
  final int toplam;
  final int hazir;
  final int inceleme;
  final int dosyaYok;

  /// Fotoğrafı hiç olmayan öğrenci.
  int get eksik => toplam - hazir - inceleme - dosyaYok;

  /// e-Okul'a yüklenebilir (onaylı) fotoğraf sayısı.
  int get kullanilabilir => hazir + inceleme;

  static const bos = SinifFotoOzeti(toplam: 0, hazir: 0, inceleme: 0, dosyaYok: 0);
}

class UzlastirmaSonucu {
  const UzlastirmaSonucu({
    required this.eksikIsaretlenen,
    required this.geriGelen,
    required this.sahipsizSilinen,
    required this.geciciSilinen,
  });
  final int eksikIsaretlenen;
  final int geriGelen;
  final int sahipsizSilinen;
  final int geciciSilinen;
}

/// Öğrenci fotoğrafı kayıtları: SQLite + disk birlikte.
///
/// ## Güvenli kayıt protokolü (plan §9.2)
/// Dosya sistemi ile SQLite ortak işlem paylaşmadığı için sıra:
/// 1. Dosya YENİ bir klasöre geçici adla yazılır, geri okunup ölçüsü ve
///    özeti doğrulanır, yerine taşınır ([FotoDepolama.atomikYaz]).
/// 2. Tek veritabanı işleminde eski güncel kayıt silinir (tetikleyici
///    dosyasını temizlik kuyruğuna yazar), yeni kayıt güncel olur.
/// 3. İşlem başarısızsa yeni dosya silinir; ESKİ FOTOĞRAF YERİNDE KALIR.
/// Uygulama 1 ile 2 arasında kapanırsa sahipsiz klasör kalır;
/// [uzlastir] onu yaşına bakarak toplar.
///
/// ## Eski sürüm tutulmuyor (bilinçli sapma)
/// Plan eski revizyonu "güncel değil" olarak saklamayı öneriyor. Ama
/// eski dosya zaten temizleniyor; dosyasız satır yalnızca eski ad/numara
/// kopyasını tutar. Veri en aza indirme (KVKK) gereği eski satır da
/// siliniyor; revizyon numarası yine artmaya devam ediyor.
class OgrenciFotoDeposu {
  OgrenciFotoDeposu({
    required Future<Database> Function() veritabani,
    required this.depolama,
    DateTime Function()? saat,
  })  : _veritabani = veritabani,
        _saat = saat ?? DateTime.now;

  final Future<Database> Function() _veritabani;
  final FotoDepolama depolama;
  final DateTime Function() _saat;

  /// Yarım kalmış kayıtla yarışmamak için: bundan genç sahipsiz dosya
  /// ve geçici artık silinmez.
  static const Duration artikYasi = Duration(minutes: 10);

  static const int _temizlikDenemeSiniri = 5;

  String _zaman(DateTime t) => t.toUtc().toIso8601String();

  Future<String> _hesap(Database db) async => FotoDepolama.hesapAlani(db.path);

  /// Standart fotoğrafı öğrencinin güncel fotoğrafı yapar.
  ///
  /// [kimlikOnaylandi] zorunlu: öğretmenin "fotoğraftaki öğrenci bu"
  /// onayı (plan §4.3). Numara ve ad bu anda veritabanından okunup
  /// denetim kopyası olarak yazılır — ekranın elindeki eski nesneden
  /// değil.
  Future<OgrenciFoto> kaydet({
    required int ogrenciId,
    required Uint8List standartJpeg,
    required String kaynak,
    required DateTime kimlikOnaylandi,
    DateTime? cekimZamani,
    List<String> kaliteUyarilari = const [],
    bool elleOnay = false,
  }) async {
    if (kaynak != FotoKaynagi.kamera && kaynak != FotoKaynagi.dosya) {
      throw ArgumentError.value(kaynak, 'kaynak');
    }
    if (kaliteUyarilari.isNotEmpty && !elleOnay) {
      throw FotoKayitHatasi('Kalite uyarısı olan fotoğraf öğretmen onayı olmadan kaydedilmez.');
    }
    dogrula(standartJpeg);

    final db = await _veritabani();
    final hesap = await _hesap(db);
    final fotoId = FotoDepolama.yeniFotoKimligi();
    final yol = FotoDepolama.standartYol(hesap, ogrenciId, fotoId);

    // Öğrenci yoksa diske hiç yazma.
    if ((await db.query('students', columns: ['id'], where: 'id = ?', whereArgs: [ogrenciId]))
        .isEmpty) {
      throw FotoKayitHatasi('Öğrenci bulunamadı; silinmiş olabilir.');
    }

    final ozet = await depolama.atomikYaz(yol, standartJpeg);
    final simdi = _saat();

    try {
      await db.transaction((tx) async {
        final ogr = await tx.query(
          'students',
          columns: ['school_number', 'first_name', 'last_name'],
          where: 'id = ?',
          whereArgs: [ogrenciId],
        );
        if (ogr.isEmpty) {
          throw FotoKayitHatasi('Öğrenci bulunamadı; silinmiş olabilir.');
        }
        final o = ogr.first;
        final sonRevizyon = Sqflite.firstIntValue(await tx.rawQuery(
              'SELECT MAX(revision) FROM student_photos WHERE student_id = ?',
              [ogrenciId],
            )) ??
            0;

        // Önce eskiler: kısmi tekil indeks aynı anda iki güncel
        // kayda izin vermez. Tetikleyici eski dosyaları kuyruğa yazar.
        await tx.delete('student_photos', where: 'student_id = ?', whereArgs: [ogrenciId]);

        await tx.insert('student_photos', {
          'id': fotoId,
          'student_id': ogrenciId,
          'revision': sonRevizyon + 1,
          'is_current': 1,
          'status': kaliteUyarilari.isEmpty ? FotoDurumu.hazir : FotoDurumu.inceleme,
          'standard_relative_path': yol,
          'width': eokulGenislik,
          'height': eokulYukseklik,
          'byte_size': standartJpeg.length,
          'mime_type': 'image/jpeg',
          'checksum': ozet,
          'source_type': kaynak,
          'captured_school_number': o['school_number'],
          'captured_full_name': '${o['first_name']} ${o['last_name']}',
          'identity_confirmed_at': _zaman(kimlikOnaylandi),
          'captured_at': _zaman(cekimZamani ?? simdi),
          'approved_at': _zaman(simdi),
          'created_at': _zaman(simdi),
          'updated_at': _zaman(simdi),
          'quality_flags': kaliteUyarilari.isEmpty ? null : kaliteUyarilari.join(','),
          'manual_quality_override': elleOnay && kaliteUyarilari.isNotEmpty ? 1 : 0,
        });
      });
    } catch (_) {
      // Yeni dosya sahipsiz kalmasın; eski fotoğrafa dokunulmadı.
      try {
        await depolama.sil(yol);
      } catch (e) {
        debugPrint('Foto geri alma silmesi: $e');
      }
      rethrow;
    }

    await _sessizTemizle();
    return (await guncel(ogrenciId))!;
  }

  Future<OgrenciFoto?> guncel(int ogrenciId) async {
    final db = await _veritabani();
    final r = await db.query(
      'student_photos',
      where: 'student_id = ? AND is_current = 1',
      whereArgs: [ogrenciId],
      limit: 1,
    );
    return r.isEmpty ? null : OgrenciFoto.fromMap(r.first);
  }

  /// Sınıfın bütün güncel fotoğrafları TEK sorguda (plan §7: katılım
  /// ızgarasında öğrenci başına sorgu yapılmaz).
  Future<Map<int, OgrenciFoto>> sinifFotolari(int sinifId) async {
    final db = await _veritabani();
    final r = await db.rawQuery(
      'SELECT p.* FROM student_photos p '
      'JOIN students s ON s.id = p.student_id '
      'WHERE s.class_id = ? AND p.is_current = 1',
      [sinifId],
    );
    return {for (final m in r) m['student_id']! as int: OgrenciFoto.fromMap(m)};
  }

  /// Rastgele öğrenci listesi gibi karışık kimlikler için; SQLite
  /// değişken sınırına takılmamak için 500'lük dilimler.
  Future<Map<int, OgrenciFoto>> guncelFotolar(Iterable<int> ogrenciIdleri) async {
    final idler = ogrenciIdleri.toSet().toList();
    final sonuc = <int, OgrenciFoto>{};
    if (idler.isEmpty) return sonuc;
    final db = await _veritabani();
    for (var i = 0; i < idler.length; i += 500) {
      final dilim = idler.sublist(i, i + 500 > idler.length ? idler.length : i + 500);
      final yer = List.filled(dilim.length, '?').join(',');
      final r = await db.rawQuery(
        'SELECT * FROM student_photos WHERE is_current = 1 AND student_id IN ($yer)',
        dilim,
      );
      for (final m in r) {
        sonuc[m['student_id']! as int] = OgrenciFoto.fromMap(m);
      }
    }
    return sonuc;
  }

  /// Gösterim için dosya; kayıt hazır değilse ya da dosya yoksa `null`.
  Future<File?> dosya(OgrenciFoto f) async {
    if (!f.hazirMi) return null;
    final d = depolama.dosya(f.standardPath);
    return await d.exists() ? d : null;
  }

  /// Dosyanın kayıttaki özetle aynı olduğunu doğrular (dışa aktarma
  /// öncesi). Açılışta toplu tarama YOK (plan §9.3).
  Future<bool> butunlukTamam(OgrenciFoto f) async {
    final d = depolama.dosya(f.standardPath);
    if (!await d.exists()) return false;
    final bayt = await d.readAsBytes();
    return bayt.length == f.byteSize && FotoDepolama.ozet(bayt) == f.checksum;
  }

  /// Sınıf başına sayım, TEK sorgu. Öğrencisi olmayan sınıf haritada
  /// yer almaz (çağıran [SinifFotoOzeti.bos] kullanır).
  Future<Map<int, SinifFotoOzeti>> sinifOzetleri() async {
    final db = await _veritabani();
    final r = await db.rawQuery(
      'SELECT s.class_id AS sinif, COUNT(*) AS toplam, '
      "SUM(CASE WHEN p.status = 'hazir' THEN 1 ELSE 0 END) AS hazir, "
      "SUM(CASE WHEN p.status = 'inceleme' THEN 1 ELSE 0 END) AS inceleme, "
      "SUM(CASE WHEN p.status = 'dosya_yok' THEN 1 ELSE 0 END) AS dosya_yok "
      'FROM students s '
      'LEFT JOIN student_photos p ON p.student_id = s.id AND p.is_current = 1 '
      'GROUP BY s.class_id',
    );
    return {
      for (final m in r)
        m['sinif']! as int: SinifFotoOzeti(
          toplam: m['toplam']! as int,
          hazir: (m['hazir'] as int?) ?? 0,
          inceleme: (m['inceleme'] as int?) ?? 0,
          dosyaYok: (m['dosya_yok'] as int?) ?? 0,
        ),
    };
  }

  /// Yanlış öğrenciye bağlanmış fotoğrafı doğru öğrenciye aktarır.
  ///
  /// Plan §4.10: işlem "düzenleme" değil YENİDEN EŞLEŞTİRME; ekran eski
  /// ve yeni kimliği birlikte gösterip ayrıca onay alır ([kimlikOnaylandi]).
  /// Hedefin mevcut fotoğrafı varsa değiştirilir (temizlik kuyruğuna).
  ///
  /// Dosya hedef öğrencinin klasörüne KOPYALANIR (yolda eski öğrencinin
  /// kimliği kalmasın); kopya doğrulanmadan kayda dokunulmaz, işlem
  /// düşerse kaynak fotoğraf olduğu gibi kalır.
  Future<OgrenciFoto> yenidenEsle({
    required int kaynakOgrenciId,
    required int hedefOgrenciId,
    required DateTime kimlikOnaylandi,
  }) async {
    if (kaynakOgrenciId == hedefOgrenciId) {
      throw FotoKayitHatasi('Fotoğraf zaten bu öğrenciye ait.');
    }
    final kaynak = await guncel(kaynakOgrenciId);
    if (kaynak == null || !kaynak.hazirMi) {
      throw FotoKayitHatasi('Aktarılacak fotoğraf bulunamadı.');
    }
    final db = await _veritabani();
    final hesap = await _hesap(db);
    final bayt = await depolama.dosya(kaynak.standardPath).readAsBytes();
    if (FotoDepolama.ozet(bayt) != kaynak.checksum) {
      throw FotoKayitHatasi('Fotoğraf dosyası bozuk; aktarılamaz. Yeniden çekin.');
    }
    final yeniYol = FotoDepolama.standartYol(hesap, hedefOgrenciId, kaynak.id);
    await depolama.atomikYaz(yeniYol, bayt);
    final simdi = _zaman(_saat());

    try {
      await db.transaction((tx) async {
        final hedef = await tx.query(
          'students',
          columns: ['school_number', 'first_name', 'last_name'],
          where: 'id = ?',
          whereArgs: [hedefOgrenciId],
        );
        if (hedef.isEmpty) {
          throw FotoKayitHatasi('Hedef öğrenci bulunamadı; silinmiş olabilir.');
        }
        final halaAyni = await tx.query('student_photos',
            columns: ['id'], where: 'id = ? AND student_id = ? AND is_current = 1',
            whereArgs: [kaynak.id, kaynakOgrenciId]);
        if (halaAyni.isEmpty) {
          throw FotoKayitHatasi('Fotoğraf bu arada değişti; yeniden deneyin.');
        }
        final sonRevizyon = Sqflite.firstIntValue(await tx.rawQuery(
              'SELECT MAX(revision) FROM student_photos WHERE student_id = ?',
              [hedefOgrenciId],
            )) ??
            0;
        await tx.delete('student_photos', where: 'student_id = ?', whereArgs: [hedefOgrenciId]);
        final h = hedef.first;
        await tx.update(
          'student_photos',
          {
            'student_id': hedefOgrenciId,
            'revision': sonRevizyon + 1,
            'standard_relative_path': yeniYol,
            'captured_school_number': h['school_number'],
            'captured_full_name': '${h['first_name']} ${h['last_name']}',
            'identity_confirmed_at': _zaman(kimlikOnaylandi),
            'updated_at': simdi,
          },
          where: 'id = ?',
          whereArgs: [kaynak.id],
        );
        // Güncelleme tetikleyiciyi çalıştırmaz; eski yol elle kuyruğa.
        await tx.insert('photo_cleanup_queue', {
          'relative_path': kaynak.standardPath,
          'reason': 'yeniden_eslendi',
          'created_at': simdi,
        });
      });
    } catch (_) {
      try {
        await depolama.sil(yeniYol);
      } catch (e) {
        debugPrint('Foto aktarma geri alma silmesi: $e');
      }
      rethrow;
    }

    await _sessizTemizle();
    return (await guncel(hedefOgrenciId))!;
  }

  /// Öğrencinin fotoğrafını siler. Dosya temizlik kuyruğundan silinir.
  Future<void> sil(int ogrenciId) async {
    final db = await _veritabani();
    await db.delete('student_photos', where: 'student_id = ?', whereArgs: [ogrenciId]);
    await _sessizTemizle();
  }

  Future<void> _sessizTemizle() async {
    try {
      await temizle();
    } catch (e) {
      debugPrint('Foto temizligi ertelendi: $e');
    }
  }

  /// Temizlik kuyruğunu işler; silinen dosya sayısını döndürür.
  ///
  /// - Kalıba uymayan yol ASLA silinmez, hatalı olarak işaretlenir.
  /// - Hâlâ bir kaydın kullandığı yol silinmez (savunma; kimlikler
  ///   rastgele olduğu için olmaması gerekir).
  /// - Başarılı görev kuyruktan düşer; başarısız olan
  ///   [_temizlikDenemeSiniri] kez yeniden denenir.
  Future<int> temizle() async {
    final db = await _veritabani();
    final bekleyen = await db.query(
      'photo_cleanup_queue',
      where: 'completed_at IS NULL AND attempts < ?',
      whereArgs: [_temizlikDenemeSiniri],
      orderBy: 'id',
      limit: 200,
    );
    var silinen = 0;
    for (final g in bekleyen) {
      final id = g['id']! as int;
      final yol = g['relative_path']! as String;
      if (!FotoDepolama.gecerliMi(yol)) {
        await db.update(
          'photo_cleanup_queue',
          {'completed_at': _zaman(_saat()), 'last_error': 'gecersiz_yol'},
          where: 'id = ?',
          whereArgs: [id],
        );
        continue;
      }
      final kullanan = await db.query(
        'student_photos',
        columns: ['id'],
        where: 'standard_relative_path = ? OR album_relative_path = ? '
            'OR original_background_relative_path = ?',
        whereArgs: [yol, yol, yol],
        limit: 1,
      );
      if (kullanan.isNotEmpty) {
        await db.delete('photo_cleanup_queue', where: 'id = ?', whereArgs: [id]);
        continue;
      }
      try {
        await depolama.sil(yol);
        await db.delete('photo_cleanup_queue', where: 'id = ?', whereArgs: [id]);
        silinen++;
      } catch (e) {
        await db.rawUpdate(
          'UPDATE photo_cleanup_queue SET attempts = attempts + 1, last_error = ? WHERE id = ?',
          ['$e'.length > 300 ? '$e'.substring(0, 300) : '$e', id],
        );
      }
    }
    return silinen;
  }

  /// Disk ile veritabanını uzlaştırır (fotoğraf merkezi açılırken).
  ///
  /// - Dosyası olmayan kayıt `dosya_yok` olur; dosya geri gelirse
  ///   (yedekten dönüş) yeniden `hazir`/`inceleme` olur. Kayıt SİLİNMEZ
  ///   (plan §9.3): öğretmen yeniden çeksin ya da yedeği geri yüklesin.
  /// - Hiçbir kayda ait olmayan foto klasörü ve geçici artık,
  ///   [artikYasi]'ndan yaşlıysa silinir. Yalnızca BU hesabın alanı
  ///   taranır; başka hesabın klasörüne dokunulmaz.
  Future<UzlastirmaSonucu> uzlastir() async {
    final db = await _veritabani();
    final hesap = await _hesap(db);
    final simdi = _saat();

    var eksik = 0;
    var geriGelen = 0;
    final kayitlar = await db.query(
      'student_photos',
      columns: ['id', 'status', 'standard_relative_path', 'quality_flags'],
    );
    final bilinenIdler = <String>{};
    for (final k in kayitlar) {
      bilinenIdler.add(k['id']! as String);
      final yol = k['standard_relative_path']! as String;
      final durum = k['status']! as String;
      final var_ = FotoDepolama.gecerliMi(yol) && await depolama.dosya(yol).exists();
      if (!var_ && durum != FotoDurumu.dosyaYok) {
        await db.update('student_photos', {'status': FotoDurumu.dosyaYok, 'updated_at': _zaman(simdi)},
            where: 'id = ?', whereArgs: [k['id']]);
        eksik++;
      } else if (var_ && durum == FotoDurumu.dosyaYok) {
        final uyarili = ((k['quality_flags'] as String?) ?? '').isNotEmpty;
        await db.update(
          'student_photos',
          {'status': uyarili ? FotoDurumu.inceleme : FotoDurumu.hazir, 'updated_at': _zaman(simdi)},
          where: 'id = ?',
          whereArgs: [k['id']],
        );
        geriGelen++;
      }
    }

    var sahipsiz = 0;
    var gecici = 0;
    final alan = depolama.hesapDizini(hesap);
    if (await alan.exists()) {
      await for (final ogrDizini in alan.list(followLinks: false)) {
        if (ogrDizini is! Directory) continue;
        await for (final fotoDizini in ogrDizini.list(followLinks: false)) {
          if (fotoDizini is! Directory) continue;
          final fotoId = fotoDizini.uri.pathSegments.where((s) => s.isNotEmpty).last;
          final yas = simdi.difference((await fotoDizini.stat()).modified);
          if (yas < artikYasi) continue;
          if (!bilinenIdler.contains(fotoId)) {
            await fotoDizini.delete(recursive: true);
            sahipsiz++;
            continue;
          }
          await for (final f in fotoDizini.list(followLinks: false)) {
            if (f is File && f.path.endsWith(FotoDepolama.geciciUzanti)) {
              if (simdi.difference((await f.stat()).modified) >= artikYasi) {
                await f.delete();
                gecici++;
              }
            }
          }
        }
        try {
          if (await ogrDizini.list().isEmpty) await ogrDizini.delete();
        } on FileSystemException {
          // boş değil
        }
      }
    }

    return UzlastirmaSonucu(
      eksikIsaretlenen: eksik,
      geriGelen: geriGelen,
      sahipsizSilinen: sahipsiz,
      geciciSilinen: gecici,
    );
  }
}
