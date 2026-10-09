import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/attendance/data/models/classroom_participation_model.dart';
import 'package:sinifcepte/features/attendance/data/repositories/classroom_participation_repository.dart';
import 'package:sinifcepte/features/attendance/presentation/widgets/random_student_picker_modal.dart';
import 'package:sinifcepte/features/attendance/providers/classroom_participation_provider.dart';
import 'package:sinifcepte/features/student_photos/providers/ogrenci_foto_providers.dart';

/// Kura ile secilen ogrenci soz hakki alir (kullanici karari, 9 Ekim 2026).
///
/// Eskiden kura penceresi secilene soz hakki VERMIYORDU. "Sira ilerliyor"
/// testi soz hakkini kendisi ekledigi icin geciyordu; gercekte "Baska
/// Ogrenci" ayni ogrenciyi yine cikarabiliyordu ve kartta gorunmuyordu.
void main() {
  StudentParticipationEvaluation ogr(int id, {int soz = 0, bool devamsiz = false}) =>
      StudentParticipationEvaluation(
        studentId: id,
        studentName: 'Ogrenci $id',
        studentNumber: id,
        speakingTurns: soz,
        isAbsent: devamsiz,
      );

  ClassroomParticipationSession oturum(List<StudentParticipationEvaluation> e) =>
      ClassroomParticipationSession(
        id: 1,
        classId: 7,
        className: '5-A',
        date: '2026-10-09',
        lessonHour: 1,
        subjectName: 'Türkçe',
        evaluations: e,
      );

  Future<ProviderContainer> kap(List<StudentParticipationEvaluation> e) async {
    final c = ProviderContainer(overrides: [
      classroomParticipationRepoProvider.overrideWithValue(_SahteRepo(oturum(e))),
      // Kura penceresi ogrenci fotografini da gosteriyor; veritabani yok.
      sinifFotolariProvider(7).overrideWith((ref) async => const {}),
      fotolariGosterProvider.overrideWith((ref) => FotolariGosterNotifier(false)),
    ]);
    await c.read(currentParticipationSessionProvider.notifier).loadSession(
          classId: 7,
          date: '2026-10-09',
          lessonHour: 1,
        );
    return c;
  }

  int soz(ProviderContainer c, int id) => c
      .read(currentParticipationSessionProvider)
      .value!
      .evaluations
      .firstWhere((e) => e.studentId == id)
      .speakingTurns;

  group('adilKuraSec', () {
    test('KRITIK: devamsizlik takibindeki ogrenci kuraya girmiyor', () {
      final liste = [ogr(1, soz: 2), ogr(2, devamsiz: true), ogr(3, soz: 2)];
      for (var i = 0; i < 50; i++) {
        expect(adilKuraSec(liste, Random(i))!.studentId, isNot(2),
            reason: 'hic soz almadigi icin her seferinde one cikardi');
      }
    });

    test('herkes takipteyse yine birini seciyor', () {
      expect(adilKuraSec([ogr(4, devamsiz: true)], Random(1))!.studentId, 4);
    });

    test('bos sinifta null', () {
      expect(adilKuraSec(const [], Random(1)), isNull);
    });
  });

  group('saglayici kuraCek', () {
    test('KRITIK: secilen ogrenciye soz hakki veriliyor', () async {
      final c = await kap([ogr(1), ogr(2, soz: 3)]);
      addTearDown(c.dispose);
      final n = c.read(currentParticipationSessionProvider.notifier);

      final secilen = n.kuraCek(rng: Random(1))!;

      expect(secilen.studentId, 1);
      expect(soz(c, 1), 1);
      expect(soz(c, 2), 3, reason: 'digerine dokunulmaz');
      expect(n.hasUnsavedChanges, isTrue, reason: 'kaydet uyarisi cikmali');
    });

    test('KRITIK: art arda kuralar herkes soz alana kadar ayni ogrenciyi secmiyor', () async {
      final c = await kap([ogr(1), ogr(2), ogr(3), ogr(4)]);
      addTearDown(c.dispose);
      final n = c.read(currentParticipationSessionProvider.notifier);

      final secilenler = [for (var i = 0; i < 4; i++) n.kuraCek(rng: Random(i))!.studentId];

      expect(secilenler.toSet(), {1, 2, 3, 4});
      for (final id in [1, 2, 3, 4]) {
        expect(soz(c, id), 1);
      }
    });
  });

  group('kura penceresi', () {
    Future<ProviderContainer> ac(WidgetTester tester, List<StudentParticipationEvaluation> e) async {
      final c = await kap(e);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => RandomStudentPickerModal.show(
                    ctx, c.read(currentParticipationSessionProvider).value!),
                child: const Text('kura'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('kura'));
      await tester.pumpAndSettle();
      return c;
    }

    List<StudentParticipationEvaluation> sinif() => [ogr(1), ogr(2)];

    testWidgets('KRITIK: pencere acilinca secilen ogrenci soz hakki aliyor', (tester) async {
      final c = await ac(tester, sinif());
      expect(soz(c, 1) + soz(c, 2), 1, reason: 'tam bir soz hakki verildi');
      expect(find.textContaining('Söz hakkı verildi (bu derste 1.)'), findsOneWidget);
    });

    testWidgets('KRITIK: "Geri al" soz hakkini siliyor (ogrenci sinifta yoksa)', (tester) async {
      final c = await ac(tester, sinif());
      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(soz(c, 1) + soz(c, 2), 0);
      expect(find.text('Söz hakkı geri alındı'), findsOneWidget);
      expect(find.text('Geri al'), findsNothing, reason: 'iki kez geri alinmasin');
    });

    testWidgets('KRITIK: "Başka Öğrenci" ikinci ogrenciyi seciyor ve ona da veriyor', (tester) async {
      final c = await ac(tester, sinif());
      await tester.tap(find.text('Başka Öğrenci'));
      await tester.pumpAndSettle();
      expect(soz(c, 1), 1);
      expect(soz(c, 2), 1, reason: 'ilk secilen yeniden secilmedi');
    });
  });
}

class _SahteRepo extends ClassroomParticipationRepository {
  _SahteRepo(this.oturum);
  final ClassroomParticipationSession oturum;

  @override
  Future<ClassroomParticipationSession> getOrCreateSession({
    required int classId,
    required String date,
    required int lessonHour,
    String? subjectName,
    String? className,
  }) async =>
      oturum;
}
