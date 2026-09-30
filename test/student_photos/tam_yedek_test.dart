import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/backup/tam_yedek.dart';
import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/student_photos/data/foto_depolama.dart';
import 'package:sinifcepte/features/student_photos/data/ogrenci_foto_deposu.dart';
import 'package:sinifcepte/features/student_photos/domain/ogrenci_foto.dart';

/// Faz 6: fotoğraflı tam yedek ve güvenli geri yükleme (plan §16).
///
/// Üretimdeki `DatabaseHelper` ve depolar kullanılıyor; şema kopyası yok.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'tam_yedek_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory kok;
  late FotoDepolama depolama;
  late OgrenciFotoDeposu depo;
  late int sinifId;
  late int ogrenciId;

  Future<Database> db() => DatabaseHelper.instance.database;

  Uint8List jpeg(int renk) {
    final r = img.Image(width: 133, height: 171);
    img.fill(r, color: img.ColorRgb8(renk, 80, 80));
    return Uint8List.fromList(img.encodeJpg(r));
  }

  Future<OgrenciFoto> fotoKaydet(int ogrenci, int renk) => depo.kaydet(
        ogrenciId: ogrenci,
        standartJpeg: jpeg(renk),
        kaynak: FotoKaynagi.dosya,
        kimlikOnaylandi: DateTime.now(),
      );

  Future<File> yedekAl() async =>
      TamYedek.olustur(db: await db(), depolama: depolama, hedefDizin: Directory(p.join(kok.path, 'yedekler')));

  Future<HazirYedek> incele(File f) async => TamYedek.incele(
        dosya: f,
        calismaDizini: Directory(p.join(kok.path, 'calisma_${DateTime.now().microsecondsSinceEpoch}')),
        mevcutHesap: FotoDepolama.hesapAlani((await db()).path),
      );

  Future<void> uygula(HazirYedek y, {Future<void> Function(String)? kanca}) => TamYedek.uygula(
        yedek: y,
        depolama: depolama,
        veritabani: db,
        baglantiyiKapat: DatabaseHelper.instance.closeConnection,
        asamaKancasi: kanca,
      );

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    kok = await Directory.systemTemp.createTemp('tam_yedek');
    depolama = FotoDepolama(Directory(p.join(kok.path, 'student_photos')));
    depo = OgrenciFotoDeposu(veritabani: db, depolama: depolama);
    sinifId = await ClassRepository().insertClass(const ClassModel(
      name: '5-A',
      subject: 'Türkçe',
      academicYear: '2026-2027',
    ));
    ogrenciId = await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 1234, firstName: 'Ayşe', lastName: 'YILMAZ'));
  });

  tearDown(() async {
    try {
      await kok.delete(recursive: true);
    } catch (_) {}
  });

  group('gidiş-dönüş', () {
    test('KRITIK: veri ve fotoğraflar birebir geri geliyor', () async {
      final f = await fotoKaydet(ogrenciId, 30);
      final yedek = await yedekAl();

      // Öğretmen sonra her şeyi kaybediyor.
      await ClassRepository().deleteClass(sinifId);
      await depo.temizle();
      expect(await depo.guncel(ogrenciId), isNull);

      final hazir = await incele(yedek);
      expect((hazir.sinif, hazir.ogrenci, hazir.fotograf, hazir.fotoKaydi), (1, 1, 1, 1));
      expect(hazir.fotografli, isTrue);
      expect(hazir.baskaHesap, isFalse);
      await uygula(hazir);

      final geri = await depo.guncel(ogrenciId);
      expect(geri?.id, f.id);
      expect(await depo.butunlukTamam(geri!), isTrue, reason: 'fotoğraf dosyası da döndü');
      expect((await StudentRepository().getStudentsByClassId(sinifId)).single.firstName, 'Ayşe');
    });

    test('KRITIK: yedekten sonra eklenen veri geri yüklemede kalmıyor (tam yerine koyma)', () async {
      await fotoKaydet(ogrenciId, 30);
      final yedek = await yedekAl();
      final yeni = await StudentRepository().insertStudent(
          StudentModel(classId: sinifId, schoolNumber: 5, firstName: 'Yeni', lastName: 'ÖĞRENCİ'));
      final yeniFoto = await fotoKaydet(yeni, 200);

      await uygula(await incele(yedek));
      expect((await StudentRepository().getStudentsByClassId(sinifId)).length, 1);
      expect(await depolama.dosya(yeniFoto.standardPath).exists(), isFalse,
          reason: 'yedekte olmayan fotoğraf dosyası sahipsiz kalmasın');
    });

    test('KRITIK: başka hesap alanından gelen yollar bu cihazın alanına çevriliyor', () async {
      await fotoKaydet(ogrenciId, 30);
      final hazir = await incele(await yedekAl());
      // Yedeğin veritabanını başka hesabın yedeğiymiş gibi değiştir.
      final kopya = await databaseFactory.openDatabase(hazir.veritabani.path);
      await kopya.rawUpdate(
          "UPDATE student_photos SET standard_relative_path = 'sinifcepte_baskaHesap' || substr(standard_relative_path, instr(standard_relative_path, '/'))");
      await kopya.close();

      await uygula(hazir);
      final f = (await depo.guncel(ogrenciId))!;
      expect(f.standardPath.startsWith('${FotoDepolama.hesapAlani((await db()).path)}/'), isTrue);
      expect(await depo.butunlukTamam(f), isTrue);
    });

    test('dosyası kayıp kayıt yedeğe dosyasız girer, geri gelince "dosya yok"', () async {
      final f = await fotoKaydet(ogrenciId, 30);
      await depolama.dosya(f.standardPath).delete();
      final hazir = await incele(await yedekAl());
      expect((hazir.fotograf, hazir.fotoKaydi), (0, 1));
      await uygula(hazir);
      await depo.uzlastir();
      expect((await depo.guncel(ogrenciId))!.status, FotoDurumu.dosyaYok);
    });

    test('manifestte hesap kimliği açık yazılmıyor', () async {
      final yedek = await yedekAl();
      final arsiv = ZipDecoder().decodeBytes(await yedek.readAsBytes());
      final m = utf8.decode(arsiv.findFile(TamYedek.manifestAdi)!.content as List<int>);
      expect(m.contains(FotoDepolama.hesapAlani((await db()).path)), isFalse);
      expect(m, contains('"hesapOzeti"'));
    });
  });

  group('kötü dosyalar', () {
    Future<File> zipYaz(Map<String, List<int>> dosyalar) async {
      final a = Archive();
      for (final e in dosyalar.entries) {
        a.addFile(ArchiveFile(e.key, e.value.length, e.value));
      }
      final f = File(p.join(kok.path, 'kotu_${DateTime.now().microsecondsSinceEpoch}.sinifcepte'));
      await f.writeAsBytes(ZipEncoder().encode(a)!);
      return f;
    }

    Future<Map<String, List<int>>> gecerliIcerik() async {
      await fotoKaydet(ogrenciId, 30);
      final arsiv = ZipDecoder().decodeBytes(await (await yedekAl()).readAsBytes());
      return {for (final f in arsiv.files) f.name: f.content as List<int>};
    }

    Matcher hata(String parca) => throwsA(isA<YedekHatasi>().having((e) => e.mesaj, 'mesaj', contains(parca)));

    test('KRITIK: yol taşması (../) reddediliyor', () async {
      final c = await gecerliIcerik();
      c['../../disari.jpg'] = [1, 2, 3];
      await expectLater(incele(await zipYaz(c)), hata('beklenmeyen dosya'));
      expect(File(p.join(kok.path, '..', 'disari.jpg')).existsSync(), isFalse);
    });

    test('KRITIK: listede olmayan fotoğraf reddediliyor', () async {
      final c = await gecerliIcerik();
      c['student_photos/1/${'a' * 32}/standard.jpg'] = jpeg(1);
      await expectLater(incele(await zipYaz(c)), hata('uyuşmuyor'));
    });

    test('KRITIK: fotoğraf özeti tutmuyorsa reddediliyor', () async {
      final c = await gecerliIcerik();
      final ad = c.keys.firstWhere((k) => k.startsWith('student_photos/'));
      c[ad] = jpeg(99);
      await expectLater(incele(await zipYaz(c)), hata('bozuk fotoğraf'));
    });

    test('KRITIK: veritabanı özeti tutmuyorsa reddediliyor', () async {
      final c = await gecerliIcerik();
      final db2 = [...c[TamYedek.veritabaniAdi]!];
      db2[db2.length - 1] ^= 0xFF;
      c[TamYedek.veritabaniAdi] = db2;
      await expectLater(incele(await zipYaz(c)), hata('özet tutmuyor'));
    });

    test('daha yeni biçimin yedeği anlaşılır hatayla reddediliyor', () async {
      final c = await gecerliIcerik();
      final m = jsonDecode(utf8.decode(c[TamYedek.manifestAdi]!)) as Map<String, dynamic>;
      m['bicim'] = TamYedek.bicim + 1;
      c[TamYedek.manifestAdi] = utf8.encode(jsonEncode(m));
      await expectLater(incele(await zipYaz(c)), hata('daha yeni bir sürümüyle'));
    });

    test('KRITIK: daha yeni ŞEMA sürümlü veritabanı reddediliyor', () async {
      // Eski biçim (düz SQLite) üzerinden: user_version ileride.
      final d = await db();
      await d.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      final kopya = File(p.join(kok.path, 'ileri.db'));
      await File(d.path).copy(kopya.path);
      final k = await databaseFactory.openDatabase(kopya.path);
      await k.setVersion(DatabaseHelper.veritabaniSurumu + 1);
      await k.close();
      await expectLater(incele(kopya), hata('daha yeni bir sürümüyle'));
    });

    test('SınıfCepte yedeği olmayan dosya', () async {
      final f = File(p.join(kok.path, 'not.txt'))..writeAsStringSync('merhaba');
      await expectLater(incele(f), hata('yedeği değil'));
      final z = await zipYaz({'baska.txt': utf8.encode('x')});
      await expectLater(incele(z), hata('beklenmeyen dosya'));
    });

    test('bozuk (kesik) ZIP', () async {
      final y = await yedekAl();
      final b = await y.readAsBytes();
      await y.writeAsBytes(b.sublist(0, b.length ~/ 2));
      await expectLater(incele(y), throwsA(isA<YedekHatasi>()));
    });
  });

  group('eski biçim ve güvenlik', () {
    test('KRITIK: eski biçim (düz SQLite) yedek açılıyor, fotoğrafsız olduğu belli', () async {
      final d = await db();
      await d.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      final eski = File(p.join(kok.path, 'eski.sinifcepte'));
      await File(d.path).copy(eski.path);
      final hazir = await incele(eski);
      expect(hazir.fotografli, isFalse);
      expect(hazir.baskaHesap, isFalse, reason: 'manifest yok, hesap bilinmez; uyarı fotoğraflı yedekte');
      expect((hazir.sinif, hazir.ogrenci), (1, 1));
    });

    test('KRITIK: başka hesabın yedeği işaretleniyor', () async {
      final yedek = await yedekAl();
      final h = await TamYedek.incele(
        dosya: yedek,
        calismaDizini: Directory(p.join(kok.path, 'c2')),
        mevcutHesap: 'sinifcepte_baskaOgretmen',
      );
      expect(h.baskaHesap, isTrue);
    });

    test('KRITIK: yarıda kalan geri yüklemede önceki veri ve fotoğraflar aynen geri geliyor', () async {
      await fotoKaydet(ogrenciId, 30);
      final yedek = await yedekAl();
      // Yedekten SONRAKİ durum: yeni öğrenci ve fotoğrafı.
      final yeni = await StudentRepository().insertStudent(
          StudentModel(classId: sinifId, schoolNumber: 5, firstName: 'Yeni', lastName: 'ÖĞRENCİ'));
      final yeniFoto = await fotoKaydet(yeni, 200);
      final hazir = await incele(yedek);

      for (final asama in ['veritabani', 'fotograflar', 'yollar']) {
        await expectLater(
          uygula(hazir, kanca: (a) async {
            if (a == asama) throw StateError('test: $a');
          }),
          throwsA(isA<StateError>()),
          reason: asama,
        );
        final ogr = await StudentRepository().getStudentsByClassId(sinifId);
        expect(ogr.length, 2, reason: '$asama: önceki veri geri gelmeli');
        expect(await depo.butunlukTamam(yeniFoto), isTrue, reason: '$asama: önceki fotoğraf geri gelmeli');
      }
      final artik = kok.listSync(recursive: true).where((e) => e.path.contains('geri_yukleme_oncesi'));
      expect(artik, isEmpty, reason: 'güvenlik kopyaları temizlenmeli');
    });

    test('KRITIK: diske bozuk yazılan yedek "alındı" sayılmıyor, siliniyor', () async {
      await fotoKaydet(ogrenciId, 30);
      final hedef = Directory(p.join(kok.path, 'bozuk_yedek'));
      await expectLater(
        TamYedek.olustur(
          db: await db(),
          depolama: depolama,
          hedefDizin: hedef,
          yazildiktanSonra: (f) async {
            final b = await f.readAsBytes();
            await f.writeAsBytes(b.sublist(0, b.length - 30));
          },
        ),
        throwsA(isA<YedekHatasi>().having((e) => e.mesaj, 'mesaj', contains('doğrulanamadı'))),
      );
      expect(hedef.listSync(), isEmpty);
    });

    test('yedek dosyası doğrulanmış olarak üretiliyor, fotoğraflar sıkıştırılmıyor', () async {
      await fotoKaydet(ogrenciId, 30);
      final y = await yedekAl();
      expect(p.basename(y.path), startsWith('sinifcepte_yedek_'));
      expect(p.extension(y.path), '.sinifcepte');
      final ham = ZipDecoder().decodeBytes(await y.readAsBytes());
      final foto = ham.files.firstWhere((f) => f.name.startsWith('student_photos/'));
      expect(foto.compressionType, ArchiveFile.STORE);
      expect(foto.name, isNot(contains('tam_yedek_test')), reason: 'hesap alanı yolda yok');
    });
  });
}
