import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/features/assistant/data/cepte_katalog.dart';
import 'package:sinifcepte/features/assistant/presentation/views/cepte_arama_view.dart';
import 'package:sinifcepte/features/assistant/providers/cepte_provider.dart';
import 'package:sinifcepte/features/attendance/providers/classroom_participation_provider.dart';

/// Yeni Cepte ekranı (9 Ekim 2026): kutu üstte, yazdıkça sonuç; Cepte
/// eksik bilgide konuşarak sorar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'cepte_arama_view_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final katalog = [
    ...cepteEkranHedefleri(),
    ...cepteSinifHedefleri([(id: 1, ad: '5-A', ders: 'Türkçe')]),
  ];

  Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
    for (var i = 0; i < 250 && !kosul(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> ac(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cepteKatalogProvider.overrideWith((ref) async => katalog),
        activeTimetableLessonProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: CepteAramaView()),
    ));
    await bekleKadar(tester, () => find.textContaining('Merhaba').evaluate().isNotEmpty);
  }

  setUpAll(() async {
    await DatabaseHelper.instance.resetForTests();
    await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();
    await ClassRepository().insertClass(
        const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027'));
  });

  testWidgets('KRITIK: kutu en üstte, boşken karşılama ve bugünkü işler', (tester) async {
    await ac(tester);
    final kutu = tester.getTopLeft(find.byKey(const Key('cepte_arama'))).dy;
    expect(kutu, lessThan(120), reason: 'arama kutusu ekranın tepesinde');
    expect(find.textContaining('Merhaba'), findsOneWidget);
    expect(find.text('BUGÜN İŞİNİZE YARAYABİLECEKLER'), findsOneWidget);
    expect(find.text('Ders içi katılım'), findsOneWidget);
  });

  testWidgets('KRITIK: yazdıkça sonuç geliyor, gruplu', (tester) async {
    await ac(tester);
    await tester.enterText(find.byKey(const Key('cepte_arama')), 'kro');
    await tester.pump();
    expect(find.text('Oturma planı · 5-A'), findsOneWidget, reason: '"kro" → kroki');
    expect(find.text('SINIFLARIM'), findsOneWidget);
  });

  testWidgets('bulunamazsa Cepte söyler ve örnek verir; örneğe dokununca aranır', (tester) async {
    await ac(tester);
    await tester.enterText(find.byKey(const Key('cepte_arama')), 'zzqx');
    await tester.pump();
    expect(find.textContaining('bir şey bulamadım'), findsOneWidget);
    await tester.tap(find.text('oturma planı'));
    await tester.pump();
    expect(find.text('Oturma planı · 5-A'), findsOneWidget);
  });

  testWidgets('KRITIK: eksik bilgide Cepte sorar; cevaplanınca plan hazır, PDF önizlemeden', (tester) async {
    await ac(tester);
    await tester.enterText(find.byKey(const Key('cepte_arama')), 'yıllık plan');
    await tester.pump();
    expect(find.text('sınıf ve ders sorulacak', findRichText: true), findsNothing);
    expect(find.textContaining('sınıf ve ders sorulacak'), findsOneWidget);

    await tester.tap(find.text('yıllık planı hazırla'));
    await bekleKadar(tester, () => find.text('Hangi sınıf için?').evaluate().isNotEmpty);
    expect(find.text('5. sınıf'), findsOneWidget, reason: 'öğretmenin sınıflarının seviyesi');

    await tester.tap(find.text('5. sınıf'));
    await bekleKadar(tester, () => find.text('5. sınıfta hangi ders?').evaluate().isNotEmpty);
    await tester.tap(find.text('Türkçe').last);
    await bekleKadar(tester, () => find.text('PDF olarak aç').evaluate().isNotEmpty);
    expect(find.textContaining('yıllık plan hazır'), findsOneWidget);
    expect(find.textContaining('TASLAK'), findsOneWidget);
  });

  test('KRITIK: PDF önizleme ekranından açılıyor; günlük ve yıllık ayrı üretici', () {
    final s = File('lib/features/assistant/presentation/views/cepte_arama_view.dart').readAsStringSync();
    expect(s, contains('PdfPreviewScreen.open('));
    expect(s, isNot(contains('sharePdf')));
    expect(s, contains('DailyPlanPdfGenerator.generateFullYearPdf('));
    expect(s, contains('AnnualPlanPdfGenerator.generate('));
  });

  test('KRITIK: öneri çipleri temaya bırakılmıyor (açık temada görünmüyordu)', () {
    final s = File('lib/features/assistant/presentation/views/cepte_arama_view.dart').readAsStringSync();
    expect(s, isNot(contains('ActionChip(')));
    expect(s, contains('Widget _cip('));
  });

  test('KRITIK: ana sayfada en üstte arama kutusu, Cepte kartı yeni ekranı açıyor', () {
    final s = File('lib/features/dashboard/screens/dashboard_screen.dart').readAsStringSync();
    expect(s.indexOf('_aramaKutusu(context, isDark)'), greaterThan(0));
    expect(s.indexOf('_aramaKutusu(context, isDark)'), lessThan(s.indexOf('_buildModernGreetingHero(')));
    expect(s, contains("'target': const CepteAramaView()"));
    expect(s, isNot(contains('CepteSohbetView')));
  });
}
