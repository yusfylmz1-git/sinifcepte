import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/student_photos/data/foto_depolama.dart';
import '../database/database_helper.dart';

/// Tam yedek: veritabanı + e-Okul fotoğrafları, tek dosya.
///
/// ```text
/// sinifcepte_yedek_20260930_1430.sinifcepte   (ZIP)
///   manifest.json
///   database.sqlite
///   student_photos/<öğrenci id>/<foto id>/standard.jpg
/// ```
///
/// ## Neden (plan §16)
/// Eski yedek yalnızca SQLite dosyasıydı; fotoğraflar girmiyordu.
/// Telefon değişince kayıtlar gelir, fotoğraflar "dosya kayıp" kalırdı.
///
/// ## Hesap alanı yedeğe yazılmaz
/// Fotoğraf yolları hesap alanı OLMADAN saklanır; geri yüklenen
/// cihazdaki alan kullanılır. Manifestte yalnızca alanın özeti durur:
/// başka hesabın yedeği yüklenirken ekran uyarsın diye (hesap kimliği
/// dosyaya açık yazılmaz).
///
/// Eski biçim (düz SQLite) geri yüklemede hâlâ kabul edilir.
class TamYedek {
  TamYedek._();

  static const String tur = 'sinifcepte-yedek';
  static const int bicim = 2;
  static const String manifestAdi = 'manifest.json';
  static const String veritabaniAdi = 'database.sqlite';
  static const String fotoKlasoru = 'student_photos';

  // Kötü niyetli ya da bozuk arşive karşı sınırlar.
  static const int enFazlaDosya = 50000;
  static const int enFazlaToplamBayt = 1024 * 1024 * 1024;

  static final RegExp _fotoYolu = RegExp(
    r'^student_photos/[0-9]{1,18}/[0-9a-f]{32}/(standard|album|original_background)\.jpg$',
  );

  static String hesapOzeti(String hesap) => sha256.convert(utf8.encode('sinifcepte-hesap|$hesap')).toString();

  static String _ozet(List<int> b) => sha256.convert(b).toString();

  /// Tam yedek üretir, GERİ OKUYUP doğrular.
  static Future<File> olustur({
    required Database db,
    required FotoDepolama depolama,
    required Directory hedefDizin,
    DateTime? zaman,
    @visibleForTesting Future<void> Function(File yedek)? yazildiktanSonra,
  }) async {
    final t = zaman ?? DateTime.now();
    // WAL modunda son yazmalar ayrı dosyada bekliyor olabilir.
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (e) {
      debugPrint('TamYedek: checkpoint alınamadı: $e');
    }
    final hesap = FotoDepolama.hesapAlani(db.path);
    final dbBayt = await File(db.path).readAsBytes();

    final sayilar = await _sayilar(db);
    final fotoSatirlari = await _fotoYollari(db);
    final fotolar = <Map<String, Object>>[];
    final fotoBaytlari = <String, List<int>>{};
    for (final yol in fotoSatirlari) {
      if (!FotoDepolama.gecerliMi(yol)) continue;
      final f = depolama.dosya(yol);
      if (!await f.exists()) continue; // "dosya kayıp" kayıt: yedeğe giremez
      final bayt = await f.readAsBytes();
      final icYol = '$fotoKlasoru/${yol.substring(yol.indexOf('/') + 1)}';
      fotolar.add({'yol': icYol, 'sha256': _ozet(bayt), 'boyut': bayt.length});
      fotoBaytlari[icYol] = bayt;
    }

    final manifest = {
      'tur': tur,
      'bicim': bicim,
      'veritabaniSurumu': DatabaseHelper.veritabaniSurumu,
      'olusturma': t.toUtc().toIso8601String(),
      'hesapOzeti': hesapOzeti(hesap),
      'veritabani': {'ad': veritabaniAdi, 'sha256': _ozet(dbBayt), 'boyut': dbBayt.length},
      'sayilar': {...sayilar, 'fotograf': fotolar.length},
      'fotograflar': fotolar,
    };

    await hedefDizin.create(recursive: true);
    String iki(int n) => n.toString().padLeft(2, '0');
    final ad = 'sinifcepte_yedek_${t.year}${iki(t.month)}${iki(t.day)}_${iki(t.hour)}${iki(t.minute)}.sinifcepte';
    final yol = p.join(hedefDizin.path, ad);
    final zip = ZipFileEncoder()..create(yol);
    try {
      final m = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
      zip.addArchiveFile(ArchiveFile(manifestAdi, m.length, m));
      zip.addArchiveFile(ArchiveFile(veritabaniAdi, dbBayt.length, dbBayt));
      for (final e in fotoBaytlari.entries) {
        zip.addArchiveFile(ArchiveFile.noCompress(e.key, e.value.length, e.value));
      }
      await zip.close();
    } catch (_) {
      try {
        await File(yol).delete();
      } catch (_) {}
      rethrow;
    }

    await yazildiktanSonra?.call(File(yol));

    // Geri oku: yedeğin açılamadığını geri yüklerken öğrenmek geç olur.
    try {
      await _dogrulaVeCikar(File(yol), null);
    } catch (e) {
      try {
        await File(yol).delete();
      } catch (_) {}
      throw YedekHatasi('Yedek doğrulanamadı: $e');
    }
    return File(yol);
  }

  static Future<Map<String, int>> _sayilar(DatabaseExecutor db) async {
    Future<int> say(String tablo) async {
      try {
        return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tablo')) ?? 0;
      } catch (_) {
        return 0; // eski yedekte tablo olmayabilir
      }
    }

    return {'sinif': await say('classes'), 'ogrenci': await say('students')};
  }

  static Future<List<String>> _fotoYollari(DatabaseExecutor db) async {
    try {
      final r = await db.query('student_photos',
          columns: ['standard_relative_path', 'album_relative_path', 'original_background_relative_path']);
      return [
        for (final m in r)
          for (final v in m.values)
            if (v is String && v.isNotEmpty) v,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Seçilen dosyayı inceler: biçim, güvenlik, bütünlük, kapsam. Hiçbir
  /// şeyin üzerine YAZMAZ; [calismaDizini]'ne çıkarır.
  static Future<HazirYedek> incele({
    required File dosya,
    required Directory calismaDizini,
    required String mevcutHesap,
  }) async {
    if (!await dosya.exists()) throw YedekHatasi('Dosya bulunamadı.');
    if (await dosya.length() > enFazlaToplamBayt) throw YedekHatasi('Dosya çok büyük.');
    final bas = await _bas(dosya, 16);
    await calismaDizini.create(recursive: true);
    final dbHedef = File(p.join(calismaDizini.path, veritabaniAdi));

    Map<String, dynamic>? manifest;
    var fotolar = <String, String>{}; // iç yol -> çıkarılmış dosya
    if (_sqliteMi(bas)) {
      await dosya.copy(dbHedef.path);
    } else if (bas.length >= 4 && bas[0] == 0x50 && bas[1] == 0x4B && bas[2] == 0x03 && bas[3] == 0x04) {
      final c = await _dogrulaVeCikar(dosya, calismaDizini);
      manifest = c.$1;
      fotolar = c.$2;
    } else {
      throw YedekHatasi('Bu dosya SınıfCepte yedeği değil.');
    }

    if (!_sqliteMi(await _bas(dbHedef, 16))) throw YedekHatasi('Yedekteki veritabanı bozuk.');

    // Kapsamı yedeğin KENDİ veritabanından oku (salt okunur).
    final kopya = await databaseFactory.openDatabase(dbHedef.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    int surum;
    Map<String, int> sayilar;
    int fotoKaydi;
    try {
      surum = Sqflite.firstIntValue(await kopya.rawQuery('PRAGMA user_version')) ?? 0;
      sayilar = await _sayilar(kopya);
      fotoKaydi = (await _fotoYollari(kopya)).length;
    } finally {
      await kopya.close();
    }
    if (surum > DatabaseHelper.veritabaniSurumu) {
      throw YedekHatasi('Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Önce uygulamayı güncelleyin.');
    }

    DateTime? tarih;
    final o = manifest?['olusturma'];
    if (o is String) tarih = DateTime.tryParse(o)?.toLocal();
    return HazirYedek._(
      calismaDizini: calismaDizini,
      veritabani: dbHedef,
      fotolar: fotolar,
      tarih: tarih ?? (await dosya.lastModified()),
      sinif: sayilar['sinif'] ?? 0,
      ogrenci: sayilar['ogrenci'] ?? 0,
      fotograf: fotolar.length,
      fotoKaydi: fotoKaydi,
      fotografli: manifest != null,
      baskaHesap: manifest != null && manifest['hesapOzeti'] != hesapOzeti(mevcutHesap),
    );
  }

  /// ZIP yedeği denetler; [hedef] verilirse içeriği oraya çıkarır.
  /// Dönüş: manifest ve (iç yol -> çıkarılmış foto yolu).
  static Future<(Map<String, dynamic>, Map<String, String>)> _dogrulaVeCikar(File zip, Directory? hedef) async {
    final giris = InputFileStream(zip.path);
    try {
      final Archive arsiv;
      try {
        arsiv = ZipDecoder().decodeBuffer(giris, verify: true);
      } catch (_) {
        throw YedekHatasi('Yedek dosyası bozuk ya da eksik indirilmiş.');
      }
      if (arsiv.files.length > enFazlaDosya) throw YedekHatasi('Yedekte beklenmeyen sayıda dosya var.');
      var toplam = 0;
      final dosyalar = <String, ArchiveFile>{};
      for (final f in arsiv.files) {
        if (!f.isFile) continue;
        final ad = f.name;
        // Yol taşması (../), mutlak yol ve beklenmeyen dosya reddedilir.
        if (ad != manifestAdi && ad != veritabaniAdi && !_fotoYolu.hasMatch(ad)) {
          throw YedekHatasi('Yedekte beklenmeyen dosya var: $ad');
        }
        if (dosyalar.containsKey(ad)) throw YedekHatasi('Yedekte aynı dosya iki kez var.');
        toplam += f.size;
        if (toplam > enFazlaToplamBayt) throw YedekHatasi('Yedek içeriği çok büyük.');
        dosyalar[ad] = f;
      }
      final mf = dosyalar[manifestAdi];
      final dbf = dosyalar[veritabaniAdi];
      if (mf == null || dbf == null) throw YedekHatasi('Yedek eksik: manifest ya da veritabanı yok.');

      final Map<String, dynamic> manifest;
      try {
        manifest = jsonDecode(utf8.decode(mf.content as List<int>)) as Map<String, dynamic>;
      } catch (_) {
        throw YedekHatasi('Yedeğin içerik listesi okunamadı.');
      }
      if (manifest['tur'] != tur) throw YedekHatasi('Bu dosya SınıfCepte yedeği değil.');
      final b = manifest['bicim'];
      if (b is! int || b > bicim) {
        throw YedekHatasi('Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Önce uygulamayı güncelleyin.');
      }

      final dbBayt = dbf.content as List<int>;
      final dbBilgi = manifest['veritabani'] as Map<String, dynamic>?;
      if (dbBilgi == null || dbBilgi['sha256'] != _ozet(dbBayt)) {
        throw YedekHatasi('Yedekteki veritabanı bozuk (özet tutmuyor).');
      }

      final liste = (manifest['fotograflar'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final beklenen = {for (final m in liste) m['yol'] as String: m['sha256'] as String};
      final arsivdeki = dosyalar.keys.where((k) => k.startsWith('$fotoKlasoru/')).toSet();
      if (!setEquals(arsivdeki, beklenen.keys.toSet())) {
        throw YedekHatasi('Yedekteki fotoğraflar içerik listesiyle uyuşmuyor.');
      }

      final cikan = <String, String>{};
      if (hedef != null) {
        await File(p.join(hedef.path, veritabaniAdi)).writeAsBytes(dbBayt, flush: true);
      }
      for (final ad in arsivdeki) {
        final bayt = dosyalar[ad]!.content as List<int>;
        if (_ozet(bayt) != beklenen[ad]) throw YedekHatasi('Yedekte bozuk fotoğraf var.');
        if (hedef != null) {
          final f = File(p.joinAll([hedef.path, ...ad.split('/')]));
          await f.parent.create(recursive: true);
          await f.writeAsBytes(bayt, flush: true);
          cikan[ad] = f.path;
        }
      }
      return (manifest, cikan);
    } finally {
      await giris.close();
    }
  }

  /// İncelenmiş yedeği uygular: mevcut veritabanı ve fotoğrafların
  /// üzerine yazar. Çağıran önce kapsamı gösterip ONAY almalıdır.
  ///
  /// Yarıda kalırsa önceki veri geri konur (plan §16: iki veri seti
  /// karışmasın).
  static Future<void> uygula({
    required HazirYedek yedek,
    required FotoDepolama depolama,
    required Future<Database> Function() veritabani,
    required Future<void> Function() baglantiyiKapat,
    @visibleForTesting Future<void> Function(String asama)? asamaKancasi,
  }) async {
    final db = await veritabani();
    final dbYolu = db.path;
    final hesap = FotoDepolama.hesapAlani(dbYolu);
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    await baglantiyiKapat();

    final damga = DateTime.now().microsecondsSinceEpoch;
    final dbOnceki = File('$dbYolu.geri_yukleme_oncesi_$damga');
    final alan = depolama.hesapDizini(hesap);
    final alanOnceki = Directory('${alan.path}.geri_yukleme_oncesi_$damga');
    await File(dbYolu).copy(dbOnceki.path);
    // Bu adım düşerse HİÇBİR ŞEYE dokunulmadı: aşağıdaki geri alma
    // bloğuna girilmemeli (o blok mevcut fotoğraf klasörünü siler).
    try {
      if (await alan.exists()) await alan.rename(alanOnceki.path);
    } catch (e) {
      try {
        await dbOnceki.delete();
      } catch (_) {}
      throw YedekHatasi('Fotoğraf klasörü taşınamadı; hiçbir şey değiştirilmedi. ($e)');
    }

    Future<void> yanDosyalariSil() async {
      for (final ek in ['-wal', '-shm', '-journal']) {
        final f = File('$dbYolu$ek');
        if (await f.exists()) await f.delete();
      }
    }

    try {
      await yanDosyalariSil();
      await yedek.veritabani.copy(dbYolu);
      await asamaKancasi?.call('veritabani');

      for (final e in yedek.fotolar.entries) {
        final ic = e.key.substring('$fotoKlasoru/'.length);
        final hedef = depolama.dosya('$hesap/$ic');
        await hedef.parent.create(recursive: true);
        await File(e.value).copy(hedef.path);
      }
      await asamaKancasi?.call('fotograflar');

      // Yolları bu cihazın hesap alanına çevir; eski cihazın temizlik
      // kuyruğu burada anlamsız.
      final yeni = await veritabani();
      await yeni.transaction((tx) async {
        for (final sutun in ['standard_relative_path', 'album_relative_path', 'original_background_relative_path']) {
          await tx.rawUpdate(
            'UPDATE student_photos SET $sutun = ? || substr($sutun, instr($sutun, \'/\')) '
            'WHERE $sutun IS NOT NULL AND instr($sutun, \'/\') > 0',
            [hesap],
          );
        }
        await tx.delete('photo_cleanup_queue');
      });
      await asamaKancasi?.call('yollar');
    } catch (e) {
      // Geri al: önceki veritabanı ve fotoğraflar.
      try {
        await baglantiyiKapat();
        await yanDosyalariSil();
        await dbOnceki.copy(dbYolu);
        if (await alan.exists()) await alan.delete(recursive: true);
        if (await alanOnceki.exists()) await alanOnceki.rename(alan.path);
      } catch (geriAlmaHatasi) {
        debugPrint('TamYedek geri alma hatası: $geriAlmaHatasi');
      }
      rethrow;
    } finally {
      try {
        if (await dbOnceki.exists()) await dbOnceki.delete();
      } catch (_) {}
    }
    try {
      if (await alanOnceki.exists()) await alanOnceki.delete(recursive: true);
    } catch (_) {}
  }

  static bool _sqliteMi(List<int> bas) {
    const imza = 'SQLite format 3';
    return bas.length >= imza.length && String.fromCharCodes(bas.take(imza.length)) == imza;
  }

  static Future<List<int>> _bas(File f, int n) async {
    try {
      final b = <int>[];
      await for (final parca in f.openRead(0, n)) {
        b.addAll(parca);
      }
      return b;
    } catch (_) {
      return const [];
    }
  }
}

class YedekHatasi implements Exception {
  YedekHatasi(this.mesaj);
  final String mesaj;
  @override
  String toString() => mesaj;
}

/// İncelenmiş, uygulanmaya hazır yedek ve kapsamı (onay ekranı için).
class HazirYedek {
  HazirYedek._({
    required this.calismaDizini,
    required this.veritabani,
    required this.fotolar,
    required this.tarih,
    required this.sinif,
    required this.ogrenci,
    required this.fotograf,
    required this.fotoKaydi,
    required this.fotografli,
    required this.baskaHesap,
  });

  @visibleForTesting
  factory HazirYedek.test({
    required Directory calismaDizini,
    DateTime? tarih,
    int sinif = 0,
    int ogrenci = 0,
    int fotograf = 0,
    int? fotoKaydi,
    bool fotografli = true,
    bool baskaHesap = false,
  }) =>
      HazirYedek._(
        calismaDizini: calismaDizini,
        veritabani: File('${calismaDizini.path}/database.sqlite'),
        fotolar: const {},
        tarih: tarih ?? DateTime(2026, 9, 30, 14, 30),
        sinif: sinif,
        ogrenci: ogrenci,
        fotograf: fotograf,
        fotoKaydi: fotoKaydi ?? fotograf,
        fotografli: fotografli,
        baskaHesap: baskaHesap,
      );

  final Directory calismaDizini;
  final File veritabani;
  final Map<String, String> fotolar;
  final DateTime tarih;
  final int sinif;
  final int ogrenci;

  /// Yedekteki fotoğraf dosyası sayısı.
  final int fotograf;

  /// Yedeğin veritabanındaki fotoğraf kaydı sayısı. [fotograf]'tan
  /// büyükse bazı kayıtlar "dosya kayıp" olarak gelir.
  final int fotoKaydi;

  /// Yeni biçim mi (eski biçim: yalnızca veritabanı, fotoğrafsız).
  final bool fotografli;

  /// Başka bir hesabın yedeği mi (ekran ayrıca uyarır).
  final bool baskaHesap;

  Future<void> temizle() async {
    try {
      if (await calismaDizini.exists()) await calismaDizini.delete(recursive: true);
    } catch (_) {}
  }
}
