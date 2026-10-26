import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/absence_followup_repository.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/attendance/data/models/classroom_participation_model.dart';
import 'package:sinifcepte/features/attendance/data/repositories/classroom_participation_repository.dart';
import 'package:sinifcepte/features/attendance/presentation/views/arti_eksi_listesi_view.dart';

/// Devamsız öğrenci bilgi girilen listelerde çıkmıyor (26 Ekim 2026).
///
/// ## Neden bu testler var
/// Kullanıcı: "+- listesinde, BEP raporu, ders içi katılım listelerinde
/// bence olmamalı. Öğretmen bir bilgi girecek sonuçta." Eskiden devamsız
/// öğrenci katılım ızgarasında soluk görünüyordu; okula hiç gelmeyen
/// öğrenci her derste ekranda yer kaplıyordu. Artık katılım oturumunun
/// listesine girmiyor (kura, toplu işaretleme, sayılar ve artı-eksi de
/// aynı listeyi kullanır). O derste gerçekten değerlendirildiyse kaydı
/// korunur. BEP listesi: rehberlik_sekmeleri_test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'devamsiz_listeler_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const yil = '2026-2027';
  late int sinifId;
  late int ali;
  late int ayse;
  late int can;

  Future<void> kur() async {
    await DatabaseHelper.instance.resetForTests();
    sinifId = await ClassRepository().insertClass(
        const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: yil, isHomeroom: true));
    ali = await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 1, firstName: 'Ali', lastName: 'YILMAZ'));
    ayse = await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 2, firstName: 'Ayşe', lastName: 'KAYA'));
    can = await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 3, firstName: 'Can', lastName: 'ÖZ'));
  }

  Future<void> devamsizYap(int ogrenci) =>
      AbsenceFollowupRepository().mark(studentId: ogrenci, classId: sinifId, academicYear: yil);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Katılım oturumu', () {
    final repo = ClassroomParticipationRepository();

    Future<ClassroomParticipationSession> oturum({int saat = 1}) => repo.getOrCreateSession(
          classId: sinifId,
          date: '2026-10-26',
          lessonHour: saat,
        );

    test('KRITIK: yeni derste devamsız öğrenci listede yok', () async {
      await kur();
      await devamsizYap(ayse);
      final s = await oturum();
      expect(s.evaluations.map((e) => e.studentId), [ali, can]);
      expect(s.totalStudents, 2, reason: 'sayılar da devamsızı saymaz');
    });

    test('KRITIK: kaydedilmiş derste de boş devamsız kaydı listeye gelmiyor', () async {
      await kur();
      await devamsizYap(ayse);
      // Eski sürüm devamsızı boş kayıtla saklardı; aynı durumu kur.
      final ilk = await oturum();
      final bosKayitli = ilk.copyWith(evaluations: [
        ...ilk.evaluations,
        StudentParticipationEvaluation(
          studentId: ayse,
          studentName: 'Ayşe KAYA',
          studentNumber: 2,
          isAbsent: true,
        ),
      ]);
      await repo.saveSession(bosKayitli);
      final s = await oturum();
      expect(s.evaluations.map((e) => e.studentId), [ali, can]);
    });

    test('takibe alınmadan önce değerlendirildiyse o dersin kaydı korunur', () async {
      await kur();
      final ilk = await oturum();
      final ayseIsaretli = ilk.copyWith(evaluations: [
        for (final e in ilk.evaluations) e.studentId == ayse ? e.copyWith(speakingTurns: 2) : e,
      ]);
      await repo.saveSession(ayseIsaretli);
      await devamsizYap(ayse);

      final ayniDers = await oturum();
      final kayit = ayniDers.evaluations.where((e) => e.studentId == ayse).single;
      expect(kayit.speakingTurns, 2);
      expect(kayit.isAbsent, isTrue);

      final yeniDers = await oturum(saat: 2);
      expect(yeniDers.evaluations.map((e) => e.studentId), isNot(contains(ayse)));
    });
  });

  testWidgets('KRITIK: artı-eksi listesinde devamsız öğrenci yok (Cepte\'den açılış dahil)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await kur();
      await devamsizYap(ali);
    });
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ArtiEksiListesiView(
          classId: sinifId,
          baslik: '5-A · Türkçe',
          tarih: '2026-10-26',
          // Cepte bütün sınıfı verir; süzme ekranın işi.
          ogrenciler: [
            StudentParticipationEvaluation(studentId: ali, studentName: 'Ali YILMAZ', studentNumber: 1),
            StudentParticipationEvaluation(studentId: ayse, studentName: 'Ayşe KAYA', studentNumber: 2),
          ],
        ),
      ),
    ));
    for (var i = 0; i < 200 && find.text('Ayşe KAYA').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Ayşe KAYA'), findsOneWidget);
    expect(find.text('Ali YILMAZ'), findsNothing);
  });
}
