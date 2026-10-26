import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/outcomes/data/models/curriculum_outcome_model.dart';
import 'package:sinifcepte/features/outcomes/data/repositories/curriculum_outcome_repository.dart';
import 'package:sinifcepte/features/outcomes/presentation/views/weekly_outcomes_view.dart';
import 'package:sinifcepte/features/outcomes/providers/outcomes_provider.dart';

/// Kazanımlar sayfasında geri (26 Ekim 2026).
///
/// ## Neden bu testler var
/// Kullanıcı: "Kazanımlara basınca yukarıdan geri düğmesine basınca en son
/// kaldığı yerden bir önceki sayfaya geliyor; telefonun geri düğmesine
/// basınca Özet'e dönüyor. İkisinde de aynı davranış olmalı: geri basınca
/// Özet'e gelmeli, Kazanımlar'a basınca da kaldığı yer değil kademe seçimi
/// açılmalı." Seçim uygulama genelinde saklandığı için ikinci açılış eski
/// derste başlıyordu.
void main() {
  late ProviderContainer kap;

  setUp(() {
    kap = ProviderContainer(overrides: [
      curriculumRepositoryProvider.overrideWithValue(_SahteMufredat()),
    ]);
  });
  tearDown(() => kap.dispose());

  Future<void> kur(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const WeeklyOutcomesView())),
                child: const Text('Özet: Kazanımlar'),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> ac(WidgetTester tester) async {
    await tester.tap(find.text('Özet: Kazanımlar'));
    await tester.pumpAndSettle();
  }

  void dersSecildi() {
    kap.read(selectedGradeProvider.notifier).state = 5;
    kap.read(selectedSubjectProvider.notifier).state = {
      'subject_code': 'TDE',
      'subject_name': 'Türkçe',
      'publisher': 'MEB',
    };
  }

  testWidgets('KRITIK: üstteki geri, ders açıkken bile sayfayı kapatır; yeniden açılış kademe seçimi', (tester) async {
    await kur(tester);
    await ac(tester);
    expect(find.text('Müfredat & Kazanımlar'), findsOneWidget);

    dersSecildi();
    await tester.pumpAndSettle();
    expect(find.text('Türkçe'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyOutcomesView), findsNothing, reason: 'Özet\'e döndü');
    expect(kap.read(selectedGradeProvider), isNull);
    expect(kap.read(selectedSubjectProvider), isNull);

    await ac(tester);
    expect(find.text('Müfredat & Kazanımlar'), findsOneWidget, reason: 'kademe seçimi');
  });

  testWidgets('KRITIK: telefonun geri tuşu da aynı: kapatır ve seçimi sıfırlar', (tester) async {
    await kur(tester);
    await ac(tester);
    kap.read(selectedGradeProvider.notifier).state = 5;
    kap.read(isFavoritesModeProvider.notifier).state = true;
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyOutcomesView), findsNothing);
    expect(kap.read(selectedGradeProvider), isNull);
    expect(kap.read(isFavoritesModeProvider), isFalse);
  });

  testWidgets('günün akışından ya da Cepte\'den seçili açılış korunur', (tester) async {
    await kur(tester);
    // Arayan önce seçimi kurar, sonra sayfayı açar.
    dersSecildi();
    await ac(tester);
    expect(find.text('Türkçe'), findsWidgets);
    expect(find.text('Müfredat & Kazanımlar'), findsNothing);
  });

  testWidgets('kapanan sayfa hemen ardından açılan yeni sayfanın seçimini silmez', (tester) async {
    await kur(tester);
    await ac(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    // Kapanış geçişi bitmeden günün akışından bir ders açılır.
    await tester.pump(const Duration(milliseconds: 50));
    dersSecildi();
    await tester.tap(find.text('Özet: Kazanımlar'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(kap.read(selectedSubjectProvider)?['subject_name'], 'Türkçe');
  });
}

class _SahteMufredat implements CurriculumOutcomeRepository {
  @override
  Future<Set<String>> getFavoriteSubjectKeys() async => <String>{};

  @override
  Future<List<Map<String, dynamic>>> getAvailableSubjects(int gradeLevel) async => [
        {'subject_code': 'TDE', 'subject_name': 'Türkçe', 'publisher': 'MEB'},
      ];

  @override
  Future<List<CurriculumOutcomeModel>> getOutcomes({
    required int gradeLevel,
    required String subjectCode,
    String? publisher,
    String? searchQuery,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
