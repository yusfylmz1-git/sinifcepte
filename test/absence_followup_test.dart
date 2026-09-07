import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/data/models/absence_followup_model.dart';
import 'package:sinifcepte/features/parent_portal/data/services/phone_formatter.dart';

/// Devamsiz ogrenci takibi (Bakanlik devamsizlik calismasi).
///
/// Kurgu: uygulamada GUNLUK YOKLAMA YOK. Ogretmen e-Okul'daki
/// devamsizliga bakip sinif listesinden ogrenci isaretliyor; kayit
/// ders yiliyla birlikte tutuluyor.
///
/// EN CIDDI RISK: not alani `students.notes` ile karistirilirsa
/// ogretmenin kalici ogrenci notu ("alerjisi var") ders yili sonunda
/// silinmesi gereken devamsizlik notuyla ayni yerde durur.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  String read(String path) => File(path).readAsStringSync();

  const repo = 'lib/data/repositories/absence_followup_repository.dart';
  const provider = 'lib/features/classes/providers/absence_followup_provider.dart';
  const ekran = 'lib/features/classes/screens/absence_followup_screen.dart';
  const liste = 'lib/features/classes/screens/student_list_screen.dart';
  const hub = 'lib/features/classes/screens/my_class_hub_screen.dart';
  const pdf = 'lib/features/classes/utils/classroom_documents_pdf_generator.dart';
  const dbHelper = 'lib/core/database/database_helper.dart';

  /// Uretimdeki v27 semasinin aynisi.
  Future<Database> semaKur() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 27),
    );
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subject TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        description TEXT,
        is_homeroom INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        school_number INTEGER NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        gender TEXT DEFAULT 'Erkek',
        parent_name TEXT,
        parent_phone TEXT,
        notes TEXT,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS absence_followups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        academic_year TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT 'bilinmiyor',
        note TEXT,
        marked_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        UNIQUE(student_id, academic_year)
      )
    ''');
    return db;
  }

  Future<int> ogrenciEkle(
    Database db, {
    required int classId,
    required int no,
    String ad = 'Yusuf',
    String soyad = 'Yılmaz',
    String? veliTel,
  }) {
    return db.insert('students', {
      'class_id': classId,
      'school_number': no,
      'first_name': ad,
      'last_name': soyad,
      'parent_phone': veliTel,
    });
  }

  Map<String, dynamic> kayit({
    required int studentId,
    required int classId,
    String yil = '2025-2026',
    String reason = 'bilinmiyor',
    String? note,
  }) {
    final now = DateTime.now().toIso8601String();
    return {
      'student_id': studentId,
      'class_id': classId,
      'academic_year': yil,
      'reason': reason,
      'note': note,
      'marked_at': now,
      'updated_at': now,
    };
  }

  group('Sema', () {
    test('KRITIK: veritabani surumu 27', () {
      expect(read(dbHelper).contains('version: 27,'), isTrue,
          reason: 'Yeni tablo surum artmadan cihaza inmez');
    });

    test('KRITIK: v27 gocu tabloyu olusturuyor', () {
      final s = read(dbHelper);
      expect(s.contains('if (oldVersion < 27)'), isTrue);
      expect(s.contains('_createAbsenceTables(db)'), isTrue);
    });

    test('KRITIK: tablo hem onCreate hem onUpgrade tarafindan kuruluyor', () {
      final s = read(dbHelper);
      // Yalnizca gocte olsaydi TEMIZ kurulumda tablo hic olusmazdi.
      expect('_createAbsenceTables(db)'.allMatches(s).length, greaterThan(1),
          reason: 'Yeni kurulumda da tablo olusmali');
    });

    test('Sinif + yil icin dizin var', () {
      expect(read(dbHelper).contains('idx_absence_class_year'), isTrue);
    });
  });

  group('Kayit yasam dongusu', () {
    test('KRITIK: ayni ogrenci ayni yil iki kez isaretlenemez', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final ogrenciId = await ogrenciEkle(db, classId: classId, no: 12);

      await db.insert(
        'absence_followups',
        kayit(studentId: ogrenciId, classId: classId, note: 'Veli arandı'),
      );

      // Toplu secimde ayni ogrenci tekrar isaretlenirse yazilan not
      // KAYBOLMAMALI; bu yuzden ignore.
      await db.insert(
        'absence_followups',
        kayit(studentId: ogrenciId, classId: classId),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final satirlar = await db.query('absence_followups');
      expect(satirlar.length, 1, reason: 'Mukerrer kayit olusmamali');
      expect(satirlar.first['note'], 'Veli arandı',
          reason: 'Ikinci isaretleme yazilan notu silmemeli');

      await db.close();
    });

    test('KRITIK: gecen yilin kaydi bu yilin listesine dusmez', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final ogrenciId = await ogrenciEkle(db, classId: classId, no: 7);

      await db.insert('absence_followups',
          kayit(studentId: ogrenciId, classId: classId, yil: '2024-2025'));
      await db.insert('absence_followups',
          kayit(studentId: ogrenciId, classId: classId, yil: '2025-2026'));

      final buYil = await db.query(
        'absence_followups',
        where: 'class_id = ? AND academic_year = ?',
        whereArgs: [classId, '2025-2026'],
      );
      expect(buYil.length, 1,
          reason: 'Yil filtresi olmadan liste her eylul elle temizlenirdi');

      // Ayni ogrenci iki AYRI yilda isaretlenebilmeli (arsiv).
      final hepsi = await db.query('absence_followups');
      expect(hepsi.length, 2);

      await db.close();
    });

    test('KRITIK: ogrenci silinince takip kaydi da silinir', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final ogrenciId = await ogrenciEkle(db, classId: classId, no: 3);
      await db.insert(
          'absence_followups', kayit(studentId: ogrenciId, classId: classId));

      await db.delete('students', where: 'id = ?', whereArgs: [ogrenciId]);

      final kalan = await db.query('absence_followups');
      expect(kalan, isEmpty,
          reason: 'Oksuz kayit cizelgede adsiz satir olarak basilirdi');

      await db.close();
    });

    test('Takipten cikarmak ogrenciyi SILMEZ', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final ogrenciId = await ogrenciEkle(db, classId: classId, no: 9);
      await db.insert(
          'absence_followups', kayit(studentId: ogrenciId, classId: classId));

      await db.delete(
        'absence_followups',
        where: 'student_id = ? AND academic_year = ?',
        whereArgs: [ogrenciId, '2025-2026'],
      );

      expect((await db.query('students')).length, 1,
          reason: 'Ogrenci sinif listesinde kalmali');
      expect((await db.query('absence_followups')), isEmpty);

      await db.close();
    });
  });

  group('Sube degisikligi (regresyon)', () {
    /// Uretimdeki _markInternal'in aynisi.
    ///
    /// TUZAK: tabloda UNIQUE(student_id, academic_year) var. Duz bir
    /// "insert ... ignore" ogrenci sube degistirdiginde eski satiri
    /// gormezden gelir: yeni sube listesi BOS kalir ama ogretmene
    /// "eklendi" denir. Ogrenci ne gorunur ne yeniden eklenebilir.
    Future<void> isaretle(
      Database db, {
      required int studentId,
      required int classId,
      String yil = '2025-2026',
    }) async {
      final mevcut = await db.query(
        'absence_followups',
        columns: ['id', 'class_id'],
        where: 'student_id = ? AND academic_year = ?',
        whereArgs: [studentId, yil],
        limit: 1,
      );
      if (mevcut.isNotEmpty) {
        if (mevcut.first['class_id'] == classId) return;
        await db.update(
          'absence_followups',
          {'class_id': classId, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [mevcut.first['id']],
        );
        return;
      }
      await db.insert(
        'absence_followups',
        kayit(studentId: studentId, classId: classId, yil: yil),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    test('KRITIK: sube degisince kayit hayalet olmuyor', () async {
      final db = await semaKur();
      final aSubesi = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final bSubesi = await db.insert('classes', {
        'name': '5-B',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final ogrenciId = await ogrenciEkle(db, classId: aSubesi, no: 42);

      await isaretle(db, studentId: ogrenciId, classId: aSubesi);
      await db.update('absence_followups', {'note': 'Veli arandı'},
          where: 'student_id = ?', whereArgs: [ogrenciId]);

      // Ogrenci 5-B'ye tasindi, orada da isaretleniyor.
      await db.update('students', {'class_id': bSubesi},
          where: 'id = ?', whereArgs: [ogrenciId]);
      await isaretle(db, studentId: ogrenciId, classId: bSubesi);

      final yeniSube = await db.query(
        'absence_followups',
        where: 'class_id = ? AND academic_year = ?',
        whereArgs: [bSubesi, '2025-2026'],
      );
      expect(yeniSube.length, 1,
          reason: 'Ogrenci yeni sube listesinde GORUNMELI');
      expect(yeniSube.first['note'], 'Veli arandı',
          reason: 'Sube degisirken yazilan not korunmali (veli kodu kurali)');

      // Kopya olusmamali: kayit tasinir, cogaltilmaz.
      expect((await db.query('absence_followups')).length, 1);
      final eskiSube = await db.query('absence_followups',
          where: 'class_id = ?', whereArgs: [aSubesi]);
      expect(eskiSube, isEmpty, reason: 'Eski subede satir kalmamali');

      await db.close();
    });

    test('Ayni subede tekrar isaretleme notu bozmuyor', () async {
      final db = await semaKur();
      final classId = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final ogrenciId = await ogrenciEkle(db, classId: classId, no: 5);

      await isaretle(db, studentId: ogrenciId, classId: classId);
      await db.update('absence_followups',
          {'note': 'Ev ziyareti yapıldı', 'reason': 'ailevi'},
          where: 'student_id = ?', whereArgs: [ogrenciId]);

      await isaretle(db, studentId: ogrenciId, classId: classId);

      final satir = (await db.query('absence_followups')).single;
      expect(satir['note'], 'Ev ziyareti yapıldı');
      expect(satir['reason'], 'ailevi');

      await db.close();
    });
  });

  group('Sinif siniri (regresyon)', () {
    test('KRITIK: guncelleme baska subenin kaydina dokunmuyor', () async {
      final db = await semaKur();
      final aSubesi = await db.insert('classes', {
        'name': '5-A',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final bSubesi = await db.insert('classes', {
        'name': '5-B',
        'subject': 'Sınıf',
        'academic_year': '2025-2026',
        'is_homeroom': 1,
      });
      final ogrA = await ogrenciEkle(db, classId: aSubesi, no: 1);
      final ogrB = await ogrenciEkle(db, classId: bSubesi, no: 1);

      await db.insert('absence_followups',
          kayit(studentId: ogrA, classId: aSubesi, note: 'A notu'));
      await db.insert('absence_followups',
          kayit(studentId: ogrB, classId: bSubesi, note: 'B notu'));

      // Uretimdeki updateDetails: student_id + class_id + yil
      await db.update(
        'absence_followups',
        {'note': 'A guncellendi', 'reason': 'saglik'},
        where: 'student_id = ? AND class_id = ? AND academic_year = ?',
        whereArgs: [ogrA, aSubesi, '2025-2026'],
      );

      final bKaydi = (await db.query('absence_followups',
              where: 'student_id = ?', whereArgs: [ogrB]))
          .single;
      expect(bKaydi['note'], 'B notu',
          reason: 'Bir subeden yapilan duzenleme otekini ezmemeli');

      await db.close();
    });

    test('Yazma yollari sinif kosulunu tasiyor', () {
      final s = read(repo);
      // updateDetails ve unmark: ikisi de sinifla sinirli olmali.
      expect(
        "AND class_id = ? AND academic_year = ?".allMatches(s).length,
        2,
        reason: 'updateDetails ve unmark sinif kosulu tasimali',
      );
    });
  });

  group('Provider maliyeti (regresyon)', () {
    test('KRITIK: aile anahtari int, ClassModel degil', () {
      final s = read(provider);
      // ClassModel'in == operatoru yok: anahtar o olsaydi sinif
      // listesi her yenilendiginde provider sifirdan kurulur, iki
      // DB sorgusu bosuna atilirdi.
      expect(s.contains('Provider.family<Set<int>, int>'), isTrue);
      expect(s.contains('absenceFollowupProvider(classId)'), isTrue,
          reason: 'family anahtari int classId olmali');
    });

    test('ClassModel hala == tasimiyor (varsayim dogrulamasi)', () {
      // Bu dogruysa yukaridaki kural gecerli kalir. ClassModel'e
      // ileride == eklenirse bu test duser ve kural gozden gecirilir.
      final s = read('lib/data/models/class_model.dart');
      expect(s.contains('operator =='), isFalse);
    });

    test('Toplu isaretleme tek islemde', () {
      expect(read(repo).contains('db.transaction('), isTrue,
          reason: 'Yarim kalan toplu yazim liste ile cizelgeyi ayirirdi');
    });

    test('Kapanmis notifier state yazmiyor', () {
      // Ekran kapaninca gelen gec yanit "disposed" hatasi veriyordu.
      expect(read(provider).contains('if (!mounted) return;'), isTrue);
    });

    test('Ders yili sinif kaydindan okunuyor, ekrandan degil', () {
      final s = read(provider);
      expect(s.contains('_classRepository.getClassById(classId)'), isTrue,
          reason: 'Ekran eski kopya tutuyorsa kayit yanlis yila yazilirdi');
    });
  });

  group('KVKK', () {
    test('KRITIK: devamsizlik verisi buluta cikmiyor', () {
      // Veri sahipligi karari (Secenek A): ogrenci verisi cihazda
      // kalir. Devamsizlik nedeni saglik/ekonomik olabiliyor.
      for (final yol in ['lib/core/cloud', 'lib/features/sync']) {
        final dir = Directory(yol);
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          expect(f.readAsStringSync().contains('absence_followups'), isFalse,
              reason: '${f.path} devamsizlik tablosuna dokunmamali');
        }
      }
    });

    test('KRITIK: cizelge gizlilik ibaresi tasiyor', () {
      final s = read(pdf);
      expect(s.contains('MEB.DVM.01 (HASSAS)'), isTrue,
          reason: 'Veli telefonu + saglik nedeni iceren belge hassas');
      final bas = s.indexOf('generateAbsenceFollowupPdfBytes');
      final son = s.indexOf('generateAbsenceFollowupPdf({', bas);
      expect(s.substring(bas, son).contains('GİZLİDİR'), isTrue,
          reason: 'Belge yazdirilip masada kalabiliyor, paylasilabiliyor');
    });
  });

  group('Belge uretimi (regresyon)', () {
    test('KRITIK: cizelge PdfTrFonts.kaydet ile uretiliyor', () {
      // Duz `pdf.save()` VS Code hata ayiklayicisi bagliyken hic
      // donmuyor; kullanici sonsuz "Belge Hazirlaniyor"da kaliyordu.
      // Dosyadaki diger 13 belge de kaydet kullaniyor.
      final s = read(pdf);
      expect(s.contains('return pdf.save();'), isFalse,
          reason: 'Zaman asimsiz save donma tuzagi');
      final bas = s.indexOf('generateAbsenceFollowupPdfBytes');
      final son = s.indexOf('generateAbsenceFollowupPdf({', bas);
      expect(s.substring(bas, son).contains('PdfTrFonts.kaydet(pdf)'), isTrue);
    });
  });

  group('Model', () {
    test('Neden kodlari gidip geliyor', () {
      for (final r in AbsenceReason.values) {
        expect(AbsenceReason.fromCode(r.code), r);
      }
    });

    test('Bilinmeyen neden kodu cokmez, bilinmiyora duser', () {
      // Eski surumden gelen ya da elle bozulmus kayit ekrani
      // cokertmemeli.
      expect(AbsenceReason.fromCode('yok_boyle_bir_kod'),
          AbsenceReason.bilinmiyor);
      expect(AbsenceReason.fromCode(null), AbsenceReason.bilinmiyor);
    });

    test('toMap/fromMap donusu bilgi kaybetmiyor', () {
      final an = DateTime(2026, 3, 14, 9, 30);
      final m = AbsenceFollowupModel(
        studentId: 5,
        classId: 2,
        academicYear: '2025-2026',
        reason: AbsenceReason.saglik,
        note: 'Rapor getirecek',
        markedAt: an,
        updatedAt: an,
      );
      final geri = AbsenceFollowupModel.fromMap(m.toMap());

      expect(geri.studentId, 5);
      expect(geri.academicYear, '2025-2026');
      expect(geri.reason, AbsenceReason.saglik);
      expect(geri.note, 'Rapor getirecek');
      expect(geri.markedAt, an);
    });

    test('Bos not "not var" sayilmaz', () {
      final an = DateTime.now();
      AbsenceFollowupModel yap(String? n) => AbsenceFollowupModel(
            studentId: 1,
            classId: 1,
            academicYear: '2025-2026',
            note: n,
            markedAt: an,
            updatedAt: an,
          );
      expect(yap(null).hasNote, isFalse);
      expect(yap('   ').hasNote, isFalse,
          reason: 'Bosluk dolu not ozet sayacini yanlis gosterirdi');
      expect(yap('Veli arandı').hasNote, isTrue);
    });
  });

  group('Veri sahipligi', () {
    test('KRITIK: devamsizlik notu students.notes sutununa yazilmiyor', () {
      final s = read(repo);
      expect(s.contains("'students'"), isFalse,
          reason: 'Devamsizlik notu kalici ogrenci notunu kirletmemeli');
    });

    test('Not sutunu SQLite ayrilmis sozcugu `not` degil', () {
      // guidance_logs ayni tuzaga dusmustu: `not` sutun adi
      // CREATE TABLE'i sessizce cokertiyordu.
      final s = read(dbHelper);
      expect(s.contains('        note TEXT,'), isTrue);
      expect(s.contains('        not TEXT,'), isFalse);
    });
  });

  group('Kapsam: rehberlik sinifi', () {
    test('KRITIK: brans sinifinda kart pasif ve nedeni yaziyor', () {
      final s = read(hub);
      expect(s.contains('disabledReason'), isTrue);
      expect(s.contains('rehberlik sınıfınız değil'), isTrue,
          reason: 'Pasif kart NEDEN kullanilamadigini soylemeli');
    });

    test('KRITIK: isaretleme eylemi yalnizca rehberlik sinifinda', () {
      final s = read(liste);
      expect(s.contains('if (widget.classModel.isHomeroom)'), isTrue,
          reason: 'Brans ogretmeni devamsizlik isaretleyememeli');
    });
  });

  group('Ekran', () {
    test('KRITIK: liste ve takip ekrani ayni kaynaktan besleniyor', () {
      // Iki liste ayri veri tutsaydi biri guncellenip digeri
      // eskimis kalirdi.
      expect(read(liste).contains('absentStudentIdsProvider'), isTrue);
      expect(read(ekran).contains('absenceFollowupProvider'), isTrue);
    });

    test('KRITIK: istenen dort alan da var (no, ad, veli no, not)', () {
      final s = read(ekran);
      expect(s.contains('entry.schoolNumber'), isTrue);
      expect(s.contains('entry.fullName'), isTrue);
      expect(s.contains('entry.parentPhone'), isTrue);
      expect(s.contains('f.note!'), isTrue);
    });

    test('Veli numarasi eksikse ekran bunu soyluyor', () {
      final s = read(ekran);
      expect(s.contains('Veli numarası kayıtlı değil'), isTrue,
          reason: 'Eksik numara ancak yaziciyla fark edilmemeliydi');
      expect(s.contains('veli numarası eksik'), isTrue);
    });

    test('Not silinmeden once onay soruluyor', () {
      final s = read(liste);
      expect(s.contains('devamsızlık notu da'), isTrue,
          reason: 'Isaret kaldirilinca not sessizce silinmemeli');
    });

    test('Takipten cikarmanin ogrenciyi silmedigi yaziyor', () {
      expect(read(ekran).contains('SİLİNMEZ'), isTrue);
    });
  });

  group('Belge', () {
    test('KRITIK: cizelge MEB kunyesi ve imza alani ile basiliyor', () {
      final s = read(pdf);
      expect(s.contains('DEVAMSIZ ÖĞRENCİ TAKİP ÇİZELGESİ'), isTrue);
      expect(s.contains('MEB.DVM.01'), isTrue);
      expect(s.contains('generateAbsenceFollowupPdfBytes'), isTrue);
    });

    test('KRITIK: cizelge Turkce fontla uretiliyor', () {
      // Varsayilan fontta Ş/İ/Ğ basilmiyordu.
      final s = read(pdf);
      final bas = s.indexOf('generateAbsenceFollowupPdfBytes');
      final son = s.indexOf('generateAbsenceFollowupPdf({', bas);
      expect(s.substring(bas, son).contains('PdfTrFonts.document()'), isTrue);
    });

    test('Cizelge sutunlari ekrandaki alanlarla ayni', () {
      final s = read(pdf);
      for (final baslik in [
        'OKUL NO',
        'ADI VE SOYADI',
        'VELİ TELEFONU',
        'NEDEN',
      ]) {
        expect(s.contains(baslik), isTrue, reason: '$baslik sutunu eksik');
      }
    });

    test('Liste bosken de imzalanabilir bos cizelge basiliyor', () {
      final s = read(pdf);
      expect(s.contains('sirali.isEmpty'), isTrue,
          reason: 'Ogretmen elle doldurulacak bos form da isteyebilir');
    });

    test('Cizelge ve ekran ayni siralamayi kullaniyor', () {
      expect(read(pdf).contains('a.schoolNumber.compareTo(b.schoolNumber)'),
          isTrue);
      expect(read(repo).contains('a.schoolNumber.compareTo(b.schoolNumber)'),
          isTrue);
    });
  });

  group('Ders yili', () {
    test('KRITIK: yil sinifin kendi kaydindan geliyor', () {
      final s = read(provider);
      expect(s.contains('classModel.academicYear'), isTrue);
      expect(s.contains('AppDateFormatter.academicYearLabel()'), isTrue,
          reason: 'Kayit bossa belge yilsiz kalmamali');
    });
  });

  group('Telefon bicimi tek kaynakta', () {
    test('KRITIK: kopyalar ortak bicimlendiriciye baglandi', () {
      // Ayni islev iki dosyada kopyalanmisti; biri duzeltilip
      // digeri unutulabilirdi.
      expect(
        read('lib/features/classes/screens/parent_contacts_screen.dart')
            .contains('PhoneFormatter.toDisplay'),
        isTrue,
      );
      expect(
        read('lib/features/classes/utils/parent_contacts_pdf_generator.dart')
            .contains('PhoneFormatter.toDisplay'),
        isTrue,
      );
    });

    test('Bicimlendirme uc yazimi da tek bicime getiriyor', () {
      const beklenen = '0 (532) 123 45 67';
      expect(PhoneFormatter.toDisplay('05321234567'), beklenen);
      expect(PhoneFormatter.toDisplay('5321234567'), beklenen);
      expect(PhoneFormatter.toDisplay('905321234567'), beklenen);
    });

    test('Bos deger cagirana gore degisiyor', () {
      expect(PhoneFormatter.toDisplay(null), '');
      expect(PhoneFormatter.toDisplay('  '), '');
      expect(PhoneFormatter.toDisplay(null, emptyPlaceholder: '-'), '-',
          reason: 'Tabloda bos hucre yerine tire basiliyor');
    });

    test('Taninmayan uzunluk oldugu gibi gosteriliyor', () {
      // Eksik/fazla haneli girdi yutulmamali; ogretmen ne yazdiysa
      // gorsun ki duzeltebilsin.
      expect(PhoneFormatter.toDisplay('444 0 312'), '444 0 312');
      expect(PhoneFormatter.toDisplay('+49 170 1234567'), '+49 170 1234567');
    });

    test('11 haneli sabit hat da cep bicimiyle basiliyor', () {
      // Mevcut davranis: 0 ile baslayan 11 hane cep varsayiliyor.
      // Uc dosyada da boyleydi, tek kaynaga tasinirken korundu.
      expect(PhoneFormatter.toDisplay('03124440000'), '0 (312) 444 00 00');
    });
  });
}
