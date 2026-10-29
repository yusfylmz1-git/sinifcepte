import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/analytics/presentation/views/exam_analysis_list_view.dart';
import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/data/repositories/exam_operations_repository.dart';
import 'package:sinifcepte/features/exam_operations/presentation/views/exam_operations_menu_view.dart';
import 'package:sinifcepte/features/exam_operations/presentation/views/exam_tracking_view.dart';

/// Sınav İşlemleri (DEG-10, 30 Ekim 2026).
///
/// Kullanıcı: "Sınav işlemleri görünüm olarak çok karmaşık; en üstteki
/// öğrenci değerlendirme takip yazısı düğme gibi görünüyor; alttaki iki
/// sarı düğme yakışmadı." Taslak gösterildi, onaylandı ("devam edelim").
/// Açıklama kutusu ve sarı düğmeler kalktı; beş iş Rehberlik Dosyası'nın
/// gruplu listesinde, alt satırda durum.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ExamModel sinav(String ad, int gunSonra) {
    final bugun = DateTime.now();
    return ExamModel(
      id: ad,
      title: ad,
      examDate: DateTime(bugun.year, bugun.month, bugun.day + gunSonra, 10),
      category: 'OKUL',
      isSchoolExam: true,
    );
  }

  group('Sınav Takvimi satırı', () {
    test('KRITIK: en yakın sınav ve kalan gün', () {
      expect(siradakiSinav([sinav('5-A 1. Yazılı', 12), sinav('LGS', 200)]),
          'Sıradaki: 5-A 1. Yazılı · 12 gün kaldı');
      expect(siradakiSinav([sinav('Quiz', 1)]), 'Sıradaki: Quiz · yarın');
      expect(siradakiSinav([sinav('Quiz', 0)]), 'Sıradaki: Quiz · bugün');
    });

    test('sınav yoksa ne yapılacağını söyler', () {
      expect(siradakiSinav(const []), 'Yaklaşan sınav yok · okulun yazılı tarihlerini ekleyin');
    });
  });

  group('Ekran', () {
    AppConfig.testDbNameOverride = 'sinav_islemleri_test.db';
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    setUpAll(() async {
      final yukleyici = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
      await yukleyici.load();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseHelper.instance.resetForTests();
    });

    Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
      for (var i = 0; i < 200 && !kosul(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> ac(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => ExamOperationsRepository().addSchoolExam(sinav('5-A Matematik 1. Yazılı', 12)));
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ExamOperationsMenuView())));
      // Durum satırları veritabanından gelir; okuma bitmeden test bitmesin.
      await bekleKadar(tester, () => find.textContaining('Sıradaki:').evaluate().isNotEmpty);
    }

    testWidgets('KRITIK: beş iş üç grupta, sırayla; eski kutu ve rozetler yok', (tester) async {
      await ac(tester);

      const sira = ['quiz', 'proje', 'takvim', 'analiz', 'karne'];
      final ustler = [
        for (final a in sira) tester.getTopLeft(find.byKey(ValueKey('sinav_islemleri_$a'))).dy,
      ];
      expect(ustler, orderedEquals([...ustler]..sort()), reason: 'sıra: $sira');

      final basliklar = [
        for (final b in ['NOT ÇİZELGELERİ', 'SINAVLAR', 'DÖNEM SONU']) tester.getTopLeft(find.text(b)).dy,
      ];
      expect(basliklar[0], lessThan(ustler[0]));
      expect(basliklar[1], allOf(greaterThan(ustler[1]), lessThan(ustler[2])));
      expect(basliklar[2], allOf(greaterThan(ustler[3]), lessThan(ustler[4])));

      for (final eski in ['Öğrenci Değerlendirme & Takip', 'Dinamik Çizelge', '10 Kriterli Rubric', 'Geri Sayım']) {
        expect(find.text(eski), findsNothing, reason: eski);
      }
      expect(find.text('Sıradaki: 5-A Matematik 1. Yazılı · 12 gün kaldı'), findsOneWidget);
      expect(find.text('Soru bazlı başarı ve MEB analiz raporu'), findsOneWidget, reason: 'girilmiş sınav yok');
    });

    testWidgets('satırlar kendi sayfasını açar', (tester) async {
      await ac(tester);

      await tester.tap(find.byKey(const ValueKey('sinav_islemleri_takvim')));
      await bekleKadar(tester, () => find.byType(ExamTrackingView).evaluate().isNotEmpty);
      expect(find.byType(ExamTrackingView), findsOneWidget);
      Navigator.of(tester.element(find.byType(ExamTrackingView))).pop();
      await bekleKadar(tester, () => find.byType(ExamTrackingView).evaluate().isEmpty);

      await tester.tap(find.byKey(const ValueKey('sinav_islemleri_analiz')));
      await bekleKadar(tester, () => find.byType(ExamAnalysisListView).evaluate().isNotEmpty);
      expect(find.byType(ExamAnalysisListView), findsOneWidget);
      // Açılan sayfanın okuması bitsin.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
      }
    });
  });
}
