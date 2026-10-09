import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/attendance/data/models/arti_eksi_model.dart';
import 'package:sinifcepte/features/attendance/data/models/classroom_participation_model.dart';
import 'package:sinifcepte/features/attendance/data/repositories/arti_eksi_repository.dart';
import 'package:sinifcepte/features/attendance/presentation/views/arti_eksi_listesi_view.dart';

/// Artı-eksi listesi (kullanıcı kararı, 9 Ekim 2026): öğretmen + / − verir,
/// söz hakkı ve ödevden ayrı; dönem boyunca birikir; eksi tek dokunuş.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'arti_eksi_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  ArtiEksiKaydi k(int ogr, int deger, {int id = 0, String tarih = '2026-10-09'}) =>
      ArtiEksiKaydi(id: id, classId: 1, studentId: ogr, deger: deger, tarih: tarih);

  group('dönem', () {
    void bekle(String gun, String bas, String bit, String ad) {
      final a = artiEksiDonemi(DateTime.parse(gun));
      expect((a.baslangic, a.bitis, a.ad), (bas, bit, ad), reason: gun);
    }

    test('KRITIK: ekim 1. dönem, ocak hâlâ 1. dönem, şubat 2. dönem', () {
      bekle('2026-10-09', '2026-08-01', '2027-01-31', '1. dönem');
      bekle('2027-01-22', '2026-08-01', '2027-01-31', '1. dönem');
      bekle('2027-02-08', '2027-02-01', '2027-07-31', '2. dönem');
    });

    test('yıl sınırı: 31 temmuz eski yılın, 1 ağustos yeni yılın', () {
      bekle('2026-07-31', '2026-02-01', '2026-07-31', '2. dönem');
      bekle('2026-08-01', '2026-08-01', '2027-01-31', '1. dönem');
    });

    test('tüm yıl 1 ağustos – 31 temmuz', () {
      final a = artiEksiYili(DateTime(2027, 3, 1));
      expect((a.baslangic, a.bitis), ('2026-08-01', '2027-07-31'));
    });
  });

  group('özet', () {
    test('KRITIK: artı ve eksi ayrı sayılıyor, öğrenciler karışmıyor', () {
      final o = artiEksiOzetle([k(1, 1), k(2, -1), k(1, 1), k(1, -1)]);
      expect((o[1]!.arti, o[1]!.eksi), (2, 1));
      expect((o[2]!.arti, o[2]!.eksi), (0, 1));
      expect(o[1]!.son, [true, true, false], reason: 'eskiden yeniye');
    });

    test('satırda en son $artiEksiSonKayitSayisi kayıt', () {
      final o = artiEksiOzetle([k(1, -1), for (var i = 0; i < 9; i++) k(1, 1)]);
      expect(o[1]!.son.length, artiEksiSonKayitSayisi);
      expect(o[1]!.son.contains(false), isFalse, reason: 'en eski eksi düştü');
      expect(o[1]!.eksi, 1, reason: 'sayı hepsini sayar');
    });
  });

  group('veritabanı', () {
    late int sinifId;
    late int ali;
    late int ayse;
    final repo = ArtiEksiRepository();
    final donem = artiEksiDonemi(DateTime(2026, 10, 9));

    setUp(() async {
      await DatabaseHelper.instance.resetForTests();
      sinifId = await ClassRepository().insertClass(
          const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027'));
      ali = await StudentRepository().insertStudent(
          StudentModel(classId: sinifId, schoolNumber: 7, firstName: 'Ali', lastName: 'YILMAZ'));
      ayse = await StudentRepository().insertStudent(
          StudentModel(classId: sinifId, schoolNumber: 3, firstName: 'Ayşe', lastName: 'KAYA'));
    });

    test('KRITIK: yeni kurulumda tablo var ve kayıt dönemine göre okunuyor', () async {
      await repo.ekle(classId: sinifId, studentId: ali, deger: 1, tarih: '2026-10-09');
      await repo.ekle(classId: sinifId, studentId: ali, deger: -1, tarih: '2027-03-02');
      final bu = await repo.kayitlar(classId: sinifId, aralik: donem);
      expect(bu.map((e) => e.deger), [1], reason: '2. dönemdeki eksi 1. dönemde görünmez');
      final yil = await repo.kayitlar(classId: sinifId, aralik: artiEksiYili(DateTime(2026, 10, 9)));
      expect(yil.length, 2);
    });

    test('sil yalnız o kaydı siliyor', () async {
      final a = await repo.ekle(classId: sinifId, studentId: ali, deger: 1, tarih: '2026-10-09');
      await repo.ekle(classId: sinifId, studentId: ali, deger: 1, tarih: '2026-10-09');
      await repo.sil(a);
      expect((await repo.kayitlar(classId: sinifId, aralik: donem)).length, 1);
    });

    test('KRITIK: öğrenci silinince kayıtları da siliniyor', () async {
      await repo.ekle(classId: sinifId, studentId: ali, deger: 1, tarih: '2026-10-09');
      await repo.ekle(classId: sinifId, studentId: ayse, deger: -1, tarih: '2026-10-09');
      await StudentRepository().deleteStudent(ali);
      final kalan = await repo.kayitlar(classId: sinifId, aralik: donem);
      expect(kalan.map((e) => e.studentId), [ayse]);
    });

    test('1 ve -1 dışındaki değer kabul edilmiyor', () async {
      expect(() => repo.ekle(classId: sinifId, studentId: ali, deger: 2, tarih: '2026-10-09'),
          throwsArgumentError);
      final db = await DatabaseHelper.instance.database;
      expect(
        () => db.insert('arti_eksi_kayitlari', {
          'class_id': sinifId,
          'student_id': ali,
          'deger': 3,
          'tarih': '2026-10-09',
          'olusturma': 'x',
        }),
        throwsA(isA<DatabaseException>()),
        reason: 'veritabanı da reddediyor (CHECK)',
      );
    });
  });

  group('göç', () {
    final kaynak = File('lib/core/database/database_helper.dart').readAsStringSync();

    test('KRITIK: sürüm 29, tablo göçte, yeni kurulumda ve her açılışta kuruluyor', () {
      expect(DatabaseHelper.veritabaniSurumu, greaterThanOrEqualTo(29),
          reason: 'yeni tablo sürüm artmadan cihaza inmez');
      expect(kaynak.contains('if (oldVersion < 29)'), isTrue);
      expect('artiEksiTablosunuKur(db)'.allMatches(kaynak).length, 3,
          reason: '_createDB, _onUpgrade, _onOpen');
    });
  });

  group('ekran', () {
    late int sinifId;
    late List<StudentParticipationEvaluation> ogrenciler;

    Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
      for (var i = 0; i < 200 && !kosul(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> ac(WidgetTester tester, {Size boyut = const Size(1080, 2400)}) async {
      tester.view.physicalSize = boyut;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await DatabaseHelper.instance.resetForTests();
        sinifId = await ClassRepository().insertClass(
            const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027'));
        final ali = await StudentRepository().insertStudent(
            StudentModel(classId: sinifId, schoolNumber: 7, firstName: 'Ali', lastName: 'YILMAZ'));
        final ayse = await StudentRepository().insertStudent(
            StudentModel(classId: sinifId, schoolNumber: 3, firstName: 'Ayşe', lastName: 'KAYA'));
        ogrenciler = [
          StudentParticipationEvaluation(studentId: ali, studentName: 'Ali YILMAZ', studentNumber: 7),
          StudentParticipationEvaluation(studentId: ayse, studentName: 'Ayşe KAYA', studentNumber: 3),
        ];
      });
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: ArtiEksiListesiView(
            classId: sinifId,
            baslik: '5-A · Türkçe',
            tarih: '2026-10-09',
            ogrenciler: ogrenciler,
          ),
        ),
      ));
      await bekleKadar(tester, () => find.text('Ali YILMAZ').evaluate().isNotEmpty);
      await bekleKadar(tester, () => find.byType(CircularProgressIndicator).evaluate().isEmpty);
    }

    Finder satir(String ad) => find.ancestor(of: find.text(ad), matching: find.byType(InkWell)).first;
    Finder satirda(String ad, Finder f) => find.descendant(of: satir(ad), matching: f);

    testWidgets('KRITIK: + ve − tek dokunuşla ekleniyor, sayılar hemen güncelleniyor', (tester) async {
      await ac(tester);
      expect(find.text('1. dönem'), findsOneWidget);
      final aliY = tester.getTopLeft(find.text('Ali YILMAZ')).dy;
      expect(tester.getTopLeft(find.text('Ayşe KAYA')).dy < aliY, isTrue, reason: 'numara sırası');

      await tester.tap(find.byTooltip('Ali YILMAZ: artı ver'));
      await bekleKadar(tester, () => satirda('Ali YILMAZ', find.text('+1')).evaluate().isNotEmpty);
      await tester.tap(find.byTooltip('Ali YILMAZ: artı ver'));
      await tester.tap(find.byTooltip('Ali YILMAZ: eksi ver'));
      await bekleKadar(tester, () => satirda('Ali YILMAZ', find.text('−1')).evaluate().isNotEmpty);

      expect(satirda('Ali YILMAZ', find.text('+2')), findsOneWidget);
      expect(satirda('Ali YILMAZ', find.text('−1')), findsOneWidget);
      expect(satirda('Ayşe KAYA', find.text('+0')), findsOneWidget, reason: 'başkasına yazılmadı');
      expect(find.text('Toplam: 2 artı · 1 eksi'), findsOneWidget);
    });

    testWidgets('KRITIK: "Geri al" son ekleneni siliyor', (tester) async {
      await ac(tester);
      await tester.tap(find.byTooltip('Ayşe KAYA: eksi ver'));
      // Önce eksinin listede GÖRÜNMESİ beklenir. Beklenmeseydi liste henüz
      // eski hâlinde (0) iken "geri alındı" denetimi boşuna geçiyordu:
      // geri al hiçbir şey silmese de test geçti (bozma denemesi, 9 Ekim).
      await bekleKadar(tester, () => find.text('Toplam: 0 artı · 1 eksi').evaluate().isNotEmpty);
      expect(satirda('Ayşe KAYA', find.text('−1')), findsOneWidget);
      expect(find.text('Ayşe KAYA: eksi eklendi'), findsOneWidget);
      // Çubuk aşağıdan kayarak geliyor; yerine oturmadan dokunuş ekranın
      // dışına düşüyordu (y=1217, ekran 1200).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Geri al'));
      await bekleKadar(tester, () => find.text('Toplam: 0 artı · 0 eksi').evaluate().isNotEmpty);
      expect(satirda('Ayşe KAYA', find.text('−0')), findsOneWidget);
    });

    testWidgets('satıra dokununca tarihli geçmiş; oradan silinebiliyor', (tester) async {
      await ac(tester);
      await tester.tap(find.byTooltip('Ali YILMAZ: artı ver'));
      await bekleKadar(tester, () => find.text('Toplam: 1 artı · 0 eksi').evaluate().isNotEmpty);
      await tester.tap(find.text('Ali YILMAZ'));
      await tester.pumpAndSettle();
      expect(find.text('9 Ekim 2026, Cuma'), findsOneWidget);
      await tester.tap(find.byTooltip('Bu kaydı sil'));
      await bekleKadar(tester, () => find.text('Bu aralıkta kayıt yok.').evaluate().isNotEmpty);
      expect(find.text('Bu aralıkta kayıt yok.'), findsOneWidget);
    });

    testWidgets('dar telefonda (320 dp) taşmıyor', (tester) async {
      await ac(tester, boyut: const Size(640, 1400));
      await tester.tap(find.byTooltip('Ali YILMAZ: artı ver'));
      await bekleKadar(tester, () => find.text('Toplam: 1 artı · 0 eksi').evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
