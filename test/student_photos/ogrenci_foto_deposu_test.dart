import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/student_photos/data/foto_depolama.dart';
import 'package:sinifcepte/features/student_photos/data/ogrenci_foto_deposu.dart';
import 'package:sinifcepte/features/student_photos/domain/foto_isleme.dart';
import 'package:sinifcepte/features/student_photos/domain/ogrenci_foto.dart';

/// e-Okul fotoğrafı — veri ve güvenli saklama (Faz 1).
///
/// Şema KOPYALANMADI: üretimdeki `DatabaseHelper` açılıyor, sınıf ve
/// öğrenci üretimdeki depolarla ekleniyor/siliniyor. Kademeli silme
/// zinciri (sınıf → öğrenci → fotoğraf → temizlik kuyruğu) böylece
/// gerçek yabancı anahtarlarla sınanıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test dosyaları paralel koşuyor; ayrı sqlite dosyası şart.
  AppConfig.testDbNameOverride = 'ogrenci_foto_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory kok;
  late FotoDepolama depolama;
  late OgrenciFotoDeposu depo;
  late int sinifId;
  late int ogrenciId;

  Uint8List jpeg([int g = 133, int y = 171, int renk = 90]) {
    final r = img.Image(width: g, height: y);
    img.fill(r, color: img.ColorRgb8(renk, 100, 140));
    return Uint8List.fromList(img.encodeJpg(r));
  }

  Future<Database> db() => DatabaseHelper.instance.database;

  OgrenciFotoDeposu depoKur({DateTime Function()? saat}) => OgrenciFotoDeposu(
        veritabani: db,
        depolama: depolama,
        saat: saat,
      );

  Future<OgrenciFoto> kaydet({int? ogrenci, int renk = 90}) => depo.kaydet(
        ogrenciId: ogrenci ?? ogrenciId,
        standartJpeg: jpeg(133, 171, renk),
        kaynak: FotoKaynagi.dosya,
        kimlikOnaylandi: DateTime.now(),
      );

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    kok = await Directory.systemTemp.createTemp('ogrenci_foto');
    depolama = FotoDepolama(Directory(p.join(kok.path, 'student_photos')));
    depo = depoKur();
    sinifId = await ClassRepository().insertClass(const ClassModel(
      name: '5-A',
      subject: 'Türkçe',
      academicYear: '2026-2027',
    ));
    ogrenciId = await StudentRepository().insertStudent(StudentModel(
      classId: sinifId,
      schoolNumber: 1234,
      firstName: 'İsmail',
      lastName: 'Işık',
    ));
  });

  tearDown(() async {
    if (await kok.exists()) await kok.delete(recursive: true);
  });

  Future<List<File>> diskteki() async {
    if (!await kok.exists()) return [];
    return kok
        .list(recursive: true)
        .where((e) => e is File)
        .cast<File>()
        .toList();
  }

  group('şema', () {
    test('KRITIK: veritabanı sürümü 28 ve tablolar kurulu', () async {
      final d = await db();
      final v = (await d.rawQuery('PRAGMA user_version')).first.values.first;
      expect(v, 28, reason: 'yeni tablo sürüm artmadan cihaza inmez');
      final adlar = (await d.rawQuery(
              "SELECT name FROM sqlite_master WHERE type IN ('table','trigger','index')"))
          .map((r) => r['name'])
          .toSet();
      expect(adlar, containsAll([
        'student_photos',
        'photo_cleanup_queue',
        'photo_capture_sessions',
        'trg_student_photos_cleanup',
        'ux_student_photos_current',
      ]));
    });

    test('KRITIK: sürüm 28 göçü ve her açılış şemayı kuruyor', () {
      final s = File('lib/core/database/database_helper.dart').readAsStringSync();
      final gocu = RegExp(r'if \(oldVersion < 28\) \{[^}]*ogrenciFotoTablolariniKur\(db\)');
      expect(gocu.hasMatch(s), isTrue, reason: 'eski cihaz tabloyu alamaz');
      final acilis = RegExp(r'Future<void> _onOpen\(Database db\) async \{[^}]*ogrenciFotoTablolariniKur\(db\)');
      expect(acilis.hasMatch(s), isTrue);
    });

    test('KRITIK: öğrenci başına iki güncel fotoğraf veritabanında reddediliyor', () async {
      await kaydet();
      final d = await db();
      final satir = (await d.query('student_photos')).first;
      final kopya = Map<String, Object?>.from(satir)
        ..['id'] = 'f' * 32
        ..['revision'] = 99;
      expect(() => d.insert('student_photos', kopya), throwsA(isA<DatabaseException>()));
      // Güncel olmayan ikinci satır kabul edilir (indeks kısmi).
      kopya['is_current'] = 0;
      await d.insert('student_photos', kopya);
    });

    test('KRITIK: hesap değişince fotoğraf listeleri tazeleniyor (iki giriş yolu)', () {
      // İkinci hesap birincinin fotoğraflarını görmesin (31 Ağustos
      // hesap izolasyonu hatasının aynısı).
      final s = File('lib/core/database/account_switch.dart').readAsStringSync();
      expect('ref.invalidate(sinifFotolariProvider);'.allMatches(s).length, 2);
      expect('ref.invalidate(sinifFotoOzetleriProvider);'.allMatches(s).length, 2);
    });

    test('şema fonksiyonu tekrar çağrılınca bozulmuyor', () async {
      await kaydet();
      final d = await db();
      await DatabaseHelper.instance.closeConnection();
      final yeniden = await db(); // _onOpen yine kurar
      expect(identical(d, yeniden), isFalse);
      expect((await yeniden.query('student_photos')).length, 1);
    });
  });

  group('kaydetme', () {
    test('KRITIK: dosya diskte, 133×171, özet ve kimlik kopyası doğru', () async {
      final f = await kaydet();
      final dosya = await depo.dosya(f);
      expect(dosya, isNotNull);
      final c = img.decodeJpg(await dosya!.readAsBytes())!;
      expect((c.width, c.height), (133, 171));
      expect(await depo.butunlukTamam(f), isTrue);
      expect(f.revision, 1);
      expect(f.status, FotoDurumu.hazir);
      expect(f.capturedSchoolNumber, 1234);
      expect(f.capturedFullName, 'İsmail Işık');
    });

    test('KRITIK: uygulama içi yolda ad ve numara YOK', () async {
      final f = await kaydet();
      expect(f.standardPath, isNot(contains('1234')));
      expect(f.standardPath.toLowerCase(), isNot(contains('ismail')));
      expect(f.standardPath, matches(RegExp(r'^ogrenci_foto_test/\d+/[0-9a-f]{32}/standard\.jpg$')));
    });

    test('KRITIK: kimlik kopyası ekrandaki nesneden değil veritabanından', () async {
      // Ekran eski adı tutuyor olabilir; kayıt anındaki gerçek ad yazılmalı.
      await StudentRepository().updateStudent(StudentModel(
        id: ogrenciId,
        classId: sinifId,
        schoolNumber: 77,
        firstName: 'Ayşe',
        lastName: 'Kaya',
      ));
      final f = await kaydet();
      expect((f.capturedSchoolNumber, f.capturedFullName), (77, 'Ayşe Kaya'));
    });

    test('KRITIK: yanlış ölçülü fotoğraf kaydedilmiyor, diske hiçbir şey yazılmıyor', () async {
      await expectLater(
        depo.kaydet(
          ogrenciId: ogrenciId,
          standartJpeg: jpeg(200, 200),
          kaynak: FotoKaynagi.kamera,
          kimlikOnaylandi: DateTime.now(),
        ),
        throwsA(anything),
      );
      expect(await diskteki(), isEmpty);
      expect(await depo.guncel(ogrenciId), isNull);
    });

    test('KRITIK: kalite uyarısı öğretmen onayı olmadan kaydedilmiyor', () async {
      await expectLater(
        depo.kaydet(
          ogrenciId: ogrenciId,
          standartJpeg: jpeg(),
          kaynak: FotoKaynagi.kamera,
          kimlikOnaylandi: DateTime.now(),
          kaliteUyarilari: ['bulanik'],
        ),
        throwsA(isA<FotoKayitHatasi>()),
      );
      final f = await depo.kaydet(
        ogrenciId: ogrenciId,
        standartJpeg: jpeg(),
        kaynak: FotoKaynagi.kamera,
        kimlikOnaylandi: DateTime.now(),
        kaliteUyarilari: ['bulanik'],
        elleOnay: true,
      );
      expect(f.status, FotoDurumu.inceleme);
      expect(f.qualityFlags, ['bulanik']);
      expect(f.manualQualityOverride, isTrue);
    });

    test('silinmiş öğrenciye kayıt yok, dosya yazılmıyor', () async {
      await StudentRepository().deleteStudent(ogrenciId);
      await expectLater(kaydet(), throwsA(isA<FotoKayitHatasi>()));
      expect(await diskteki(), isEmpty);
    });

    test('KRITIK: yeni fotoğraf eskisinin yerini alıyor, eski dosya siliniyor', () async {
      final eski = await kaydet(renk: 10);
      final eskiDosya = depolama.dosya(eski.standardPath);
      expect(await eskiDosya.exists(), isTrue);

      final yeni = await kaydet(renk: 200);
      expect(yeni.revision, 2);
      expect(yeni.id, isNot(eski.id));
      expect(await eskiDosya.exists(), isFalse, reason: 'eski dosya sahipsiz kalmamalı');
      expect(await eskiDosya.parent.exists(), isFalse, reason: 'boş klasör de gitmeli');
      final d = await db();
      expect((await d.query('student_photos')).length, 1,
          reason: 'eski revizyon satırı tutulmuyor (veri en aza indirme)');
      expect((await d.query('photo_cleanup_queue')).length, 0);
      expect((await diskteki()).length, 1);
    });

    test('KRITIK: veritabanı işlemi düşerse eski fotoğraf yerinde, yeni dosya kalmıyor', () async {
      final eski = await kaydet(renk: 10);
      final d = await db();
      await d.execute('''
        CREATE TEMP TRIGGER test_bozucu BEFORE INSERT ON student_photos
        BEGIN SELECT RAISE(ABORT, 'test'); END
      ''');
      try {
        await expectLater(kaydet(renk: 200), throwsA(isA<DatabaseException>()));
      } finally {
        await d.execute('DROP TRIGGER test_bozucu');
      }
      final hala = await depo.guncel(ogrenciId);
      expect(hala?.id, eski.id);
      expect(await depo.butunlukTamam(hala!), isTrue);
      expect((await diskteki()).length, 1, reason: 'yarım kalan yeni dosya silinmeli');
    });

    test('atomik yazma geçici artık bırakmıyor', () async {
      await kaydet();
      final artik = (await diskteki()).where((f) => f.path.endsWith(FotoDepolama.geciciUzanti));
      expect(artik, isEmpty);
    });
  });

  group('silme zinciri', () {
    test('KRITIK: öğrenci silinince fotoğraf dosyası da temizleniyor', () async {
      final f = await kaydet();
      await StudentRepository().deleteStudent(ogrenciId);
      final d = await db();
      expect((await d.query('student_photos')).length, 0);
      expect((await d.query('photo_cleanup_queue')).single['relative_path'], f.standardPath,
          reason: 'tetikleyici kademeli silmede de çalışmalı');
      expect(await depo.temizle(), 1);
      expect(await diskteki(), isEmpty);
      expect((await d.query('photo_cleanup_queue')), isEmpty);
    });

    test('KRITIK: sınıf silinince (sınıf → öğrenci → fotoğraf) dosya temizleniyor', () async {
      final ikinci = await StudentRepository().insertStudent(StudentModel(
        classId: sinifId,
        schoolNumber: 5,
        firstName: 'Ali',
        lastName: 'Can',
      ));
      await kaydet();
      await kaydet(ogrenci: ikinci);
      await ClassRepository().deleteClass(sinifId);
      expect(await depo.temizle(), 2);
      expect(await diskteki(), isEmpty);
    });

    test('fotoğrafı silmek öğrenciye dokunmuyor', () async {
      await kaydet();
      await depo.sil(ogrenciId);
      expect(await depo.guncel(ogrenciId), isNull);
      expect(await diskteki(), isEmpty);
      final d = await db();
      expect((await d.query('students', where: 'id = ?', whereArgs: [ogrenciId])).length, 1);
    });

    test('KRITIK: kuyruktaki kök dışı yol ASLA silinmiyor', () async {
      final kurban = File(p.join(kok.path, 'kurban.txt'))..writeAsStringSync('dokunma');
      final d = await db();
      for (final yol in [
        '../kurban.txt',
        'hesap/1/${'a' * 32}/../../../kurban.txt',
        kurban.path,
        'hesap/1/${'a' * 32}/standard.png',
      ]) {
        await d.insert('photo_cleanup_queue', {
          'relative_path': yol,
          'reason': 'test',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await depo.temizle();
      expect(kurban.existsSync(), isTrue);
      final kalan = await d.query('photo_cleanup_queue');
      expect(kalan.every((r) => r['last_error'] == 'gecersiz_yol'), isTrue);
      expect(kalan.every((r) => r['completed_at'] != null), isTrue,
          reason: 'her temizlikte yeniden denenmesin');
    });

    test('hâlâ kullanılan yol kuyruğa düşse de silinmiyor', () async {
      final f = await kaydet();
      final d = await db();
      await d.insert('photo_cleanup_queue', {
        'relative_path': f.standardPath,
        'reason': 'test',
        'created_at': DateTime.now().toIso8601String(),
      });
      await depo.temizle();
      expect(await depo.butunlukTamam(f), isTrue);
    });
  });

  group('sınıf ve toplu okuma', () {
    test('KRITIK: öğrenci başka sınıfa taşınınca fotoğraf onunla gidiyor', () async {
      await kaydet();
      final yeniSinif = await ClassRepository().insertClass(const ClassModel(
        name: '5-B',
        subject: 'Türkçe',
        academicYear: '2026-2027',
      ));
      await StudentRepository().moveStudentsBatch([ogrenciId], yeniSinif);
      expect(await depo.sinifFotolari(sinifId), isEmpty);
      expect((await depo.sinifFotolari(yeniSinif)).keys, [ogrenciId]);
      expect((await diskteki()).length, 1, reason: 'dosya taşınmaz');
    });

    test('toplu okuma 500 değişken sınırını aşan listede çalışıyor', () async {
      await kaydet();
      final idler = [for (var i = 100000; i < 101200; i++) i, ogrenciId];
      final r = await depo.guncelFotolar(idler);
      expect(r.keys, [ogrenciId]);
    });
  });

  group('sınıf özeti', () {
    test('KRITIK: sayım durumlara göre doğru, fotoğrafsız öğrenci "eksik"', () async {
      final r = StudentRepository();
      final b = await r.insertStudent(StudentModel(classId: sinifId, schoolNumber: 2, firstName: 'B', lastName: 'B'));
      await r.insertStudent(StudentModel(classId: sinifId, schoolNumber: 3, firstName: 'C', lastName: 'C'));
      final bosSinif = await ClassRepository().insertClass(const ClassModel(
        name: '6-A',
        subject: 'Türkçe',
        academicYear: '2026-2027',
      ));
      await kaydet();
      await depo.kaydet(
        ogrenciId: b,
        standartJpeg: jpeg(),
        kaynak: FotoKaynagi.dosya,
        kimlikOnaylandi: DateTime.now(),
        kaliteUyarilari: [kaliteDusukCozunurluk],
        elleOnay: true,
      );
      final o = (await depo.sinifOzetleri())[sinifId]!;
      expect((o.toplam, o.hazir, o.inceleme, o.dosyaYok, o.eksik), (3, 1, 1, 0, 1));
      expect(o.kullanilabilir, 2);
      expect((await depo.sinifOzetleri())[bosSinif], isNull, reason: 'öğrencisiz sınıf');
    });
  });

  group('başka öğrenciye aktarma', () {
    late int hedef;
    setUp(() async {
      hedef = await StudentRepository().insertStudent(StudentModel(
        classId: sinifId,
        schoolNumber: 1250,
        firstName: 'Ayşe',
        lastName: 'KAYA',
      ));
    });

    test('KRITIK: fotoğraf doğru öğrenciye geçiyor, kimlik kopyası hedefin', () async {
      final f = await kaydet();
      final t = await depo.yenidenEsle(
        kaynakOgrenciId: ogrenciId,
        hedefOgrenciId: hedef,
        kimlikOnaylandi: DateTime.now(),
      );
      expect(t.id, f.id);
      expect(t.studentId, hedef);
      expect((t.capturedSchoolNumber, t.capturedFullName), (1250, 'Ayşe KAYA'));
      expect(t.standardPath, contains('/$hedef/'), reason: 'yolda eski öğrencinin kimliği kalmasın');
      expect(await depo.guncel(ogrenciId), isNull);
      expect(await depo.butunlukTamam(t), isTrue);
      expect((await diskteki()).length, 1, reason: 'eski yol temizlendi');
    });

    test('KRITIK: hedefin eski fotoğrafı değiştiriliyor ve dosyası temizleniyor', () async {
      final hedefinEskisi = await kaydet(ogrenci: hedef, renk: 10);
      await kaydet(renk: 200);
      final t = await depo.yenidenEsle(
        kaynakOgrenciId: ogrenciId,
        hedefOgrenciId: hedef,
        kimlikOnaylandi: DateTime.now(),
      );
      expect(t.revision, 2, reason: 'hedefin revizyonu sürer');
      expect(await depolama.dosya(hedefinEskisi.standardPath).exists(), isFalse);
      expect((await diskteki()).length, 1);
      final d = await db();
      expect((await d.query('student_photos')).length, 1);
    });

    test('KRITIK: hedef silinmişse kaynak fotoğraf yerinde, artık dosya yok', () async {
      final f = await kaydet();
      await StudentRepository().deleteStudent(hedef);
      await expectLater(
        depo.yenidenEsle(kaynakOgrenciId: ogrenciId, hedefOgrenciId: hedef, kimlikOnaylandi: DateTime.now()),
        throwsA(isA<FotoKayitHatasi>()),
      );
      expect((await depo.guncel(ogrenciId))?.id, f.id);
      expect(await depo.butunlukTamam(f), isTrue);
      expect((await diskteki()).length, 1);
    });

    test('bozuk dosya aktarılmıyor', () async {
      final f = await kaydet();
      await depolama.dosya(f.standardPath).writeAsBytes([1, 2, 3]);
      await expectLater(
        depo.yenidenEsle(kaynakOgrenciId: ogrenciId, hedefOgrenciId: hedef, kimlikOnaylandi: DateTime.now()),
        throwsA(isA<FotoKayitHatasi>()),
      );
      expect(await depo.guncel(hedef), isNull);
    });
  });

  group('kimliği yeniden onaylama', () {
    test('KRITIK: kimlik farkı onayla güncel bilgiye çekiliyor', () async {
      final f = await kaydet();
      await StudentRepository().updateStudent(StudentModel(
        id: ogrenciId,
        classId: sinifId,
        schoolNumber: 1300,
        firstName: 'İsmail',
        lastName: 'IŞIK',
      ));
      expect(f.kimlikFarkli(okulNo: 1300, adSoyad: 'İsmail IŞIK'), isTrue);
      final t = await depo.kimligiYenidenOnayla(
        ogrenciId: ogrenciId,
        beklenenFotoId: f.id,
        kimlikOnaylandi: DateTime.now(),
      );
      expect(t.capturedSchoolNumber, 1300);
      expect(t.kimlikFarkli(okulNo: 1300, adSoyad: 'İsmail IŞIK'), isFalse);
      expect(t.checksum, f.checksum, reason: 'fotoğraf değişmez');
    });

    test('KRITIK: bu arada fotoğraf değiştiyse onay eski fotoğrafa gitmiyor', () async {
      final eski = await kaydet(renk: 10);
      await kaydet(renk: 200);
      await expectLater(
        depo.kimligiYenidenOnayla(ogrenciId: ogrenciId, beklenenFotoId: eski.id, kimlikOnaylandi: DateTime.now()),
        throwsA(isA<FotoKayitHatasi>()),
      );
    });
  });

  group('uzlaştırma', () {
    test('KRITIK: dosyası kaybolan kayıt "hazır" sayılmıyor, geri gelince düzeliyor', () async {
      final f = await kaydet();
      final dosya = depolama.dosya(f.standardPath);
      final yedek = await dosya.readAsBytes();
      await dosya.delete();

      final s1 = await depo.uzlastir();
      expect(s1.eksikIsaretlenen, 1);
      final eksik = (await depo.guncel(ogrenciId))!;
      expect(eksik.status, FotoDurumu.dosyaYok);
      expect(eksik.hazirMi, isFalse);
      expect(await depo.dosya(eksik), isNull);

      await dosya.writeAsBytes(yedek);
      final s2 = await depo.uzlastir();
      expect(s2.geriGelen, 1);
      expect((await depo.guncel(ogrenciId))!.status, FotoDurumu.hazir);
    });

    test('KRITIK: sahipsiz eski klasör siliniyor, yenisi (yazılıyor olabilir) kalıyor', () async {
      await kaydet();
      final sahipsiz = depolama.dosya(FotoDepolama.standartYol('ogrenci_foto_test', 999, 'b' * 32));
      await sahipsiz.parent.create(recursive: true);
      await sahipsiz.writeAsBytes([1, 2, 3]);

      expect((await depo.uzlastir()).sahipsizSilinen, 0, reason: 'genç klasör yarışta olabilir');
      expect(await sahipsiz.exists(), isTrue);

      final ileride = depoKur(saat: () => DateTime.now().add(const Duration(hours: 1)));
      expect((await ileride.uzlastir()).sahipsizSilinen, 1);
      expect(await sahipsiz.exists(), isFalse);
      expect((await depo.guncel(ogrenciId))!.hazirMi, isTrue, reason: 'kayıtlı olan dokunulmaz');
      expect((await diskteki()).length, 1);
    });

    test('eski geçici artık siliniyor', () async {
      final f = await kaydet();
      final artik = File('${depolama.dosya(f.standardPath).path}${FotoDepolama.geciciUzanti}');
      await artik.writeAsBytes([0]);
      final ileride = depoKur(saat: () => DateTime.now().add(const Duration(hours: 1)));
      expect((await ileride.uzlastir()).geciciSilinen, 1);
      expect(await artik.exists(), isFalse);
    });

    test('KRITIK: başka hesabın fotoğraf klasörüne dokunulmuyor', () async {
      final baskasi = depolama.dosya(FotoDepolama.standartYol('sinifcepte_baskaHesap', 1, 'c' * 32));
      await baskasi.parent.create(recursive: true);
      await baskasi.writeAsBytes([1]);
      final ileride = depoKur(saat: () => DateTime.now().add(const Duration(days: 30)));
      await ileride.uzlastir();
      expect(await baskasi.exists(), isTrue);
    });
  });

  group('depolama ve kimlik', () {
    test('hesap alanı veritabanı dosyasından', () {
      expect(FotoDepolama.hesapAlani('/x/y/sinifcepte_Ab1-_z.db'), 'sinifcepte_Ab1-_z');
      expect(FotoDepolama.hesapAlani('/x/sinifcepte.db'), 'sinifcepte');
      expect(FotoDepolama.hesapAlani(':memory:'), '_memory_');
    });

    test('foto kimliği 32 onaltılık hane ve her seferinde farklı', () {
      final a = FotoDepolama.yeniFotoKimligi();
      expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(FotoDepolama.yeniFotoKimligi(), isNot(a));
    });

    test('geçersiz yol dosyaya çevrilmiyor', () {
      expect(() => depolama.dosya('../x/1/${'a' * 32}/standard.jpg'), throwsArgumentError);
      expect(() => depolama.dosya('h/1/${'A' * 32}/standard.jpg'), throwsArgumentError);
      expect(() => depolama.hesapDizini('..'), throwsArgumentError);
    });

    test('KRITIK: kimlik farkı Türkçe harf ve boşlukta yanılmıyor', () {
      final f = OgrenciFoto(
        id: 'a' * 32,
        studentId: 1,
        revision: 1,
        status: FotoDurumu.hazir,
        standardPath: 'x',
        width: 133,
        height: 171,
        byteSize: 1,
        checksum: '',
        sourceType: FotoKaynagi.dosya,
        capturedSchoolNumber: 1234,
        capturedFullName: 'İsmail IŞIK',
        identityConfirmedAt: DateTime(2026),
        capturedAt: DateTime(2026),
        approvedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(f.kimlikFarkli(okulNo: 1234, adSoyad: 'ismail  ışık'), isFalse);
      expect(f.kimlikFarkli(okulNo: 1234, adSoyad: 'İsmail Işık'), isFalse);
      expect(f.kimlikFarkli(okulNo: 1234, adSoyad: 'Ismail Isik'), isTrue,
          reason: 'I/ı ile İ/i farklı harfler');
      expect(f.kimlikFarkli(okulNo: 1235, adSoyad: 'İsmail Işık'), isTrue);
    });
  });
}
