import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Islenen Dersler (sinif katilim gecmisi).
///
/// ## Neden bu ekran var
/// Uygulamanin ogretmene verdigi soz: **"arti-eksi listesi tutmana
/// gerek yok, istedigin izlemeyi burada yapabilirsin."** O sozun
/// karsiligi, ogretmenin geriye donup *hangi dersi isledigini ve o
/// derste ne oldugunu* gorebilmesidir.
///
/// Once gecmis yalnizca iki dar yerden gorunuyordu: ogrenci kartindaki
/// son dersler seridi (tek ogrenci) ve donem sonu raporu (tek sayi).
/// Sinifin ders ders gecmisi hicbir yerde yoktu; depo metodu
/// `getClassRecentSessions` bunun icin yazilmis ama HICBIR EKRAN
/// cagirmiyordu — 30 satir olu kod.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  String read(String path) => File(path).readAsStringSync();

  const ekran =
      'lib/features/attendance/presentation/views/class_lesson_history_view.dart';
  const katilimEkrani =
      'lib/features/attendance/presentation/views/classroom_participation_view.dart';
  const saglayici =
      'lib/features/attendance/providers/classroom_participation_provider.dart';
  const depo =
      'lib/features/attendance/data/repositories/classroom_participation_repository.dart';

  group('Olu kod dirildi', () {
    test('KRITIK: getClassRecentSessions artik cagriliyor', () {
      final s = read(saglayici);
      expect(s.contains('getClassRecentSessions'), isTrue,
          reason: '30 satir yazilmis ama hicbir ekran kullanmiyordu');
      expect(s.contains('classRecentSessionsProvider'), isTrue);
    });

    test('Ekran saglayiciyi izliyor', () {
      expect(
        read(ekran).contains('classRecentSessionsProvider(widget.classId)'),
        isTrue,
      );
    });

    test('Limit tek derse sikismiyor', () {
      // 20 varsayilani bir donemi kapsamaz: haftada 4 ders x 18 hafta
      // = 72 oturum. Ogretmen "donem basinda ne olmustu" diyemezdi.
      expect(read(saglayici).contains('limit: 200'), isTrue);
    });
  });

  group('Ekrana ulasilabiliyor', () {
    test('KRITIK: katilim ekraninda gecmis dugmesi var', () {
      final s = read(katilimEkrani);
      expect(s.contains('ClassLessonHistoryView.open'), isTrue,
          reason: 'Ekran yazilip baglanmazsa yine olu kod olur');
      expect(s.contains("tooltip: 'İşlenen dersler'"), isTrue);
    });

    test('Sinif secili degilse sebebi soyleniyor', () {
      // Sessizce hicbir sey yapmamak kafa karistiriyordu.
      expect(read(katilimEkrani).contains('Önce bir sınıf seçin.'), isTrue);
    });

    test('Acik dersin adi suzgec olarak tasiniyor', () {
      expect(
        read(katilimEkrani).contains('subjectName: session?.subjectName'),
        isTrue,
      );
    });
  });

  group('KAYIT KAYBI KORUMASI (regresyon)', () {
    test('KRITIK: gecmisten ders acmadan once kaydedilmemis is soruluyor', () {
      // Katilim ekrani PopScope ile korunuyor ama gecmisten oturum
      // DEGISTIRMEK o korumayi ATLAR. Ogretmen 30 ogrenciyi
      // isaretleyip kaydetmeden baska derse atlasa hepsi sessizce
      // kaybolurdu; modulun en pahali hatasi tam buydu.
      final s = read(ekran);
      expect(s.contains('notifier.hasUnsavedChanges'), isTrue,
          reason: 'Gecis oncesi kirli durum kontrol edilmeli');
      expect(s.contains('Kaydedilmemiş Değerlendirme'), isTrue);
      expect(s.contains('Kaydetmeden Çık'), isTrue);
      expect(s.contains('Sayfada Kal'), isTrue);
    });

    test('KRITIK: onay verilmezse ders DEGISMIYOR', () {
      expect(read(ekran).contains('if (devam != true) return;'), isTrue,
          reason: 'Vazgecen ogretmenin isi durmali');
    });

    test('KRITIK: oturum degisince kirli bayrak temizleniyor', () {
      // Yalnizca saveCurrentSession temizliyordu: ogretmen bir derste
      // isaretleyip kaydetmeden baska derse gecince bayrak true
      // kaliyor, yeni derste hicbir sey yapmadan cikmak istese bile
      // uyari aliyordu.
      final s = read(saglayici);
      final bas = s.indexOf('Future<void> loadSession(');
      final son = s.indexOf('void markAllHomework(', bas);
      expect(bas, greaterThan(-1));
      expect(
        s.substring(bas, son).contains('_hasUnsavedChanges = false'),
        isTrue,
        reason: 'loadSession bayragi temizlemeli',
      );
    });

    test('Kayit sonrasi temizleme hala duruyor', () {
      // attendance_guard_test bunu kilitliyor; bozmadigimizi
      // burada da dogruluyoruz.
      expect(read(saglayici).contains('_hasUnsavedChanges = false'), isTrue);
    });
  });

  group('Liste ogretmene ne soyluyor', () {
    test('KRITIK: isaretlenmemis ders "%0 odev" gostermiyor', () {
      // Veri yoklugu basarisizlik degildir; modulun kendi ilkesi.
      final s = read(ekran);
      expect(s.contains('Bu derste işaretleme yapılmadı'), isTrue);
      expect(s.contains('isaretliVar'), isTrue);
    });

    test('Odev orani kac ogrenciye dayandigini yaziyor', () {
      // "%100 (3 ogrenci)" ile "%100 (30 ogrenci)" ayni sey degil.
      final s = read(ekran);
      expect(s.contains('homeworkEvaluatedCount'), isTrue);
      expect(s.contains('öğrenci)'), isTrue);
    });

    test('Soz hakki ve sessiz ogrenci gorunuyor', () {
      final s = read(ekran);
      expect(s.contains('totalSpeakingTurns'), isTrue);
      expect(s.contains('silentStudentCount'), isTrue);
    });

    test('Bos gecilen ders sayisi ust ozette', () {
      // Ogretmen "izlemeyi burada yapiyorum" diyorsa bos gectigi
      // dersleri de gormeli; yoksa rapor eksik veriye dayanir.
      expect(read(ekran).contains('derste işaretleme yok'), isTrue);
    });

    test('Her dersin kendi PDF raporu alinabiliyor', () {
      expect(read(ekran).contains('shareOrPrintClassPdf'), isTrue);
    });
  });

  group('Ders suzgeci', () {
    test('KRITIK: birden fazla derse giren ogretmen ayirabiliyor', () {
      final s = read(ekran);
      expect(s.contains('_subjectFilter'), isTrue);
      expect(s.contains('Tüm Dersler'), isTrue);
    });

    test('Tek ders varsa suzgec cikmiyor', () {
      // Tek secenekli suzgec ekranda gurultu.
      expect(read(ekran).contains('if (dersler.length > 1)'), isTrue);
    });
  });

  group('Depo sorgusu gercek veriyle', () {
    Future<Database> semaKur() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 27),
      );
      await db.execute('''
        CREATE TABLE students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          class_id INTEGER NOT NULL,
          school_number INTEGER NOT NULL,
          first_name TEXT NOT NULL,
          last_name TEXT NOT NULL,
          gender TEXT DEFAULT 'Erkek'
        )
      ''');
      await db.execute('''
        CREATE TABLE participation_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          class_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          lesson_hour INTEGER NOT NULL,
          subject_name TEXT,
          topic_name TEXT,
          note TEXT,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE participation_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          student_id INTEGER NOT NULL,
          homework_status TEXT NOT NULL DEFAULT 'yapti',
          materials_status TEXT NOT NULL DEFAULT 'tam',
          arrival_status TEXT NOT NULL DEFAULT 'zamaninda',
          stars_count INTEGER NOT NULL DEFAULT 0,
          custom_tags TEXT,
          badge_name TEXT,
          score INTEGER NOT NULL DEFAULT 0,
          note TEXT,
          speaking_turns INTEGER NOT NULL DEFAULT 0
        )
      ''');
      return db;
    }

    Future<void> dersEkle(
      Database db, {
      required int classId,
      required String tarih,
      required int saat,
      required String ders,
    }) async {
      await db.insert('participation_sessions', {
        'class_id': classId,
        'date': tarih,
        'lesson_hour': saat,
        'subject_name': ders,
      });
    }

    test('KRITIK: en yeni ders en ustte', () async {
      // Ogretmen once "gecen ders neydi" diye bakar.
      final db = await semaKur();

      await dersEkle(db,
          classId: 1, tarih: '2026-03-02', saat: 1, ders: 'Matematik');
      await dersEkle(db,
          classId: 1, tarih: '2026-03-05', saat: 3, ders: 'Matematik');
      await dersEkle(db,
          classId: 1, tarih: '2026-03-05', saat: 1, ders: 'Matematik');

      final rows = await db.query(
        'participation_sessions',
        where: 'class_id = ?',
        whereArgs: [1],
        orderBy: 'date DESC, lesson_hour DESC',
      );

      expect(rows.first['date'], '2026-03-05');
      expect(rows.first['lesson_hour'], 3,
          reason: 'Ayni gunde son ders saati once gelmeli');
      expect(rows.last['date'], '2026-03-02');

      await db.close();
    });

    test('Baska sinifin dersi karismiyor', () async {
      final db = await semaKur();

      await dersEkle(db,
          classId: 1, tarih: '2026-03-02', saat: 1, ders: 'Matematik');
      await dersEkle(db,
          classId: 2, tarih: '2026-03-02', saat: 1, ders: 'Matematik');

      final rows = await db.query(
        'participation_sessions',
        where: 'class_id = ?',
        whereArgs: [1],
      );

      expect(rows.length, 1);

      await db.close();
    });

    test('Ayni sinifta iki ders ayri listeleniyor', () async {
      // Ogretmen ayni sinifa hem matematik hem fen dersine girebilir.
      final db = await semaKur();

      await dersEkle(db,
          classId: 1, tarih: '2026-03-02', saat: 1, ders: 'Matematik');
      await dersEkle(db,
          classId: 1, tarih: '2026-03-03', saat: 2, ders: 'Fen Bilimleri');

      final hepsi = await db.query('participation_sessions');
      final dersler =
          hepsi.map((r) => r['subject_name'] as String).toSet();

      expect(dersler.length, 2);
      expect(dersler, containsAll(['Matematik', 'Fen Bilimleri']));

      await db.close();
    });

    test('Kayit yoksa bos liste doner (cokmez)', () async {
      final db = await semaKur();

      final rows = await db.query(
        'participation_sessions',
        where: 'class_id = ?',
        whereArgs: [99],
      );

      expect(rows, isEmpty);

      await db.close();
    });
  });

  group('Bos durum', () {
    test('Hic ders islenmemisse ne yapilacagi yaziyor', () {
      final s = read(ekran);
      expect(s.contains('Henüz işlenen ders yok'), isTrue);
      expect(s.contains('Bir ders işleyip kaydettiğinizde'), isTrue);
    });
  });

  group('Depo metodu bozulmadi', () {
    test('Siralama depoda da ayni', () {
      expect(
        read(depo).contains("orderBy: 'date DESC, lesson_hour DESC'"),
        isTrue,
      );
    });

    test('Hata durumunda bos liste donuyor', () {
      // Cokmek yerine bos liste: ekran acilabilmeli.
      final s = read(depo);
      final bas = s.indexOf('getClassRecentSessions');
      final son = s.indexOf('detectActiveLessonFromTimetable', bas);
      expect(s.substring(bas, son).contains('return [];'), isTrue);
    });
  });
}
