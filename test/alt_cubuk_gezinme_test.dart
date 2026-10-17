import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/analytics/presentation/widgets/class_report_card_comments_modal.dart';
import 'package:sinifcepte/features/assistant/data/cepte_katalog.dart';
import 'package:sinifcepte/features/attendance/providers/classroom_participation_provider.dart';
import 'package:sinifcepte/features/classes/screens/class_list_screen.dart';
import 'package:sinifcepte/features/dashboard/providers/activity_feed_provider.dart';
import 'package:sinifcepte/features/documents/presentation/views/evraklar_sekmesi.dart';
import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/data/repositories/exam_operations_repository.dart';
import 'package:sinifcepte/features/exam_operations/data/services/exam_sync_service.dart';
import 'package:sinifcepte/features/exam_operations/presentation/views/exam_operations_menu_view.dart';
import 'package:sinifcepte/features/exam_operations/providers/exam_tracking_provider.dart';
import 'package:sinifcepte/features/navigation/providers/navigation_provider.dart';
import 'package:sinifcepte/features/navigation/screens/main_navigation_screen.dart';
import 'package:sinifcepte/features/schedule/screens/schedule_screen.dart';
import 'package:sinifcepte/shared/widgets/custom_app_bar.dart';
import 'package:sinifcepte/shared/widgets/custom_bottom_nav_bar.dart';

/// Sadeleştirme 4. aşama: alt çubuk ve menü (17 Ekim 2026).
///
/// ## Neden bu testler var
/// Alt çubuk "Özet · Sınıf · Kazanım · Ders Prog. · Profil" idi; yanında
/// on maddelik üç çizgili bir menü vardı ve maddelerin çoğu başka bir
/// yerden de açılıyordu. Yeni düzen: Bugün · Sınıflar · Kazanımlar ·
/// Evraklar · Ben, menü yok. Bu testler
///   * menünün hiçbir yerde geri gelmediğini,
///   * alt çubuğun yalnız ana ekranda durduğunu,
///   * sekme numarasının tek kaynaktan ([AnaSekme]) okunduğunu,
///   * eski menüdeki her maddenin yeni bir evi olduğunu
/// denetler; ana ekran da gerçek veritabanıyla açılıp gezilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'alt_cubuk_gezinme_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  /// Yorum satırları atılmış kod: yorumlar geçmişi anlatırken eski adları
  /// anabilir ("eskiden menüdeydi"); denetlenen, çalışan koddur.
  String yorumsuz(String icerik) => icerik
      .split('\n')
      .where((s) => !s.trimLeft().startsWith('//'))
      .join('\n');

  String oku(String yol) => File(yol).readAsStringSync();

  List<(String, String)> kaynaklar() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) =>
          (f.path.replaceAll('\\', '/'), yorumsuz(f.readAsStringSync())))
      .toList();

  /// Gerçek G/Ç (sqflite ffi) sahte zamanda ilerlemez.
  Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
    for (var i = 0; i < 200 && !kosul(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Açılan ekranın gerçek G/Ç'si (veritabanı okuması) bitsin.
  Future<void> bekle(WidgetTester tester, [int tur = 12]) async {
    for (var i = 0; i < tur; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
  }

  setUpAll(() async {
    // Gerçek yazı tipi: test yazı tipinde her harf kare çizilir, telefonda
    // sığan satırlar taşmış görünür. Telefondaki Roboto yerine pakete gömülü
    // Noto Sans yüklenir; biraz daha geniştir, burada sığan telefonda da
    // sığar.
    final yukleyici = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await yukleyici.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.resetForTests();
  });

  group('Üç çizgili menü yok', () {
    test('KRITIK: menü dosyası silindi, adı ve açma çağrısı hiçbir yerde yok',
        () {
      expect(File('lib/shared/widgets/app_drawer.dart').existsSync(), isFalse);
      for (final (yol, kod) in kaynaklar()) {
        for (final yasak in [
          'AppDrawer',
          'app_drawer.dart',
          'drawer:',
          'openDrawer',
          'showDrawerButton',
          'Menüyü Aç',
        ]) {
          expect(kod.contains(yasak), isFalse, reason: '$yol: $yasak');
        }
      }
    });

    testWidgets('üst çubukta menü düğmesi çıkmıyor', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'SınıfCepte',
              showBackButton: false,
              showProfileAvatar: true,
            ),
          ),
        ),
      ));
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
      expect(find.byTooltip('Menüyü Aç'), findsNothing);
    });
  });

  group('Alt çubuk', () {
    test('KRITIK: sekme adları AnaSekme sırasıyla', () {
      final adlar = CustomBottomNavBar.tabs.map((t) => t.label).toList();
      expect(adlar, ['Bugün', 'Sınıflar', 'Kazanımlar', 'Evraklar', 'Ben']);
      expect(adlar[AnaSekme.bugun], 'Bugün');
      expect(adlar[AnaSekme.siniflar], 'Sınıflar');
      expect(adlar[AnaSekme.kazanimlar], 'Kazanımlar');
      expect(adlar[AnaSekme.evraklar], 'Evraklar');
      expect(adlar[AnaSekme.ben], 'Ben');
    });

    test('KRITIK: ana ekrandaki sekme ekranları aynı sırada', () {
      final kod = yorumsuz(
          oku('lib/features/navigation/screens/main_navigation_screen.dart'));
      final sira = [
        'DashboardScreen(',
        'const ClassListScreen()',
        'const WeeklyOutcomesView()',
        'const EvraklarSekmesi()',
        'const ProfileScreen()',
      ].map(kod.indexOf).toList();
      expect(sira.every((i) => i > 0), isTrue, reason: '$sira');
      for (var i = 1; i < sira.length; i++) {
        expect(sira[i], greaterThan(sira[i - 1]));
      }
      expect(kod.contains('ScheduleScreen'), isFalse,
          reason: 'ders programı artık sekme değil');
    });

    test('KRITIK: alt çubuk yalnız ana ekranda', () {
      // Alt sayfalarda (sınav ekranları, Sınıfım) da vardı: "sekme içinde
      // sekme" hissi veriyordu.
      final kullananlar = [
        for (final (yol, kod) in kaynaklar())
          if (kod.contains('CustomBottomNavBar(') &&
              !yol.endsWith('custom_bottom_nav_bar.dart'))
            yol,
      ];
      expect(kullananlar, hasLength(1));
      expect(kullananlar.single, endsWith('main_navigation_screen.dart'));
    });

    test('KRITIK: sekme numarası elle yazılmıyor', () {
      final elle = RegExp(r'navigationIndexProvider\.notifier\)\.state\s*=\s*\d'
          r'|onNavigateTab\?\.call\(\d|onNavigateTab!\(\d');
      for (final (yol, kod) in kaynaklar()) {
        expect(elle.hasMatch(kod), isFalse, reason: yol);
      }
    });

    testWidgets('dokununca doğru sekme numarası gidiyor', (tester) async {
      final secilen = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar:
              CustomBottomNavBar(currentIndex: 0, onTap: secilen.add),
        ),
      ));
      expect(find.text('Ders Prog.'), findsNothing);
      await tester.tap(find.text('Evraklar'));
      await tester.tap(find.text('Ben'));
      await tester.tap(find.text('Sınıflar'));
      expect(secilen, [AnaSekme.evraklar, AnaSekme.ben, AnaSekme.siniflar]);
    });
  });

  group('Eski menüdeki her maddenin yeni evi var', () {
    // Madde → (evi olan dosya, o dosyada aranan çağrı).
    const evler = {
      'Sınıfım': ('lib/features/classes/screens/class_list_screen.dart', 'MyClassHubScreen('),
      'Sınıflarım': ('lib/features/navigation/screens/main_navigation_screen.dart', 'const ClassListScreen()'),
      'Ders İçi Katılım': ('lib/features/dashboard/screens/dashboard_screen.dart', 'ClassroomParticipationView('),
      'Müfredat & Kazanımlar': ('lib/features/navigation/screens/main_navigation_screen.dart', 'const WeeklyOutcomesView()'),
      'MEB Çalışma Takvimi': ('lib/features/dashboard/screens/dashboard_screen.dart', 'const AcademicCalendarScreen()'),
      'Raporlar: soru analizi': ('lib/features/exam_operations/presentation/views/exam_operations_menu_view.dart', 'const ExamAnalysisListView()'),
      'Raporlar: karne görüşü': ('lib/features/exam_operations/presentation/views/exam_operations_menu_view.dart', 'ClassReportCardCommentsModal.show('),
      'Raporlar: katılım raporları': ('lib/features/attendance/presentation/views/classroom_participation_view.dart', 'ParticipationCumulativeReportsModal.show('),
      'e-Okul foto': ('lib/features/documents/presentation/views/evraklar_sekmesi.dart', 'const EokulFotoMerkeziEkrani()'),
      'Veri Yedekleme': ('lib/features/profile/screens/profile_screen.dart', 'yedekPenceresiniAc(context)'),
      'Veri Gizliliği & KVKK': ('lib/features/profile/screens/profile_screen.dart', 'const AboutScreen()'),
      'Ayarlar': ('lib/features/profile/screens/profile_screen.dart', 'const SettingsScreen()'),
      'Ders programı': ('lib/features/classes/screens/class_list_screen.dart', 'const ScheduleScreen()'),
    };
    for (final e in evler.entries) {
      test('KRITIK: ${e.key}', () {
        expect(yorumsuz(oku(e.value.$1)), contains(e.value.$2));
      });
    }

    test('menüdeki yanlış gizlilik metni geri gelmedi', () {
      // Menüdeki KVKK penceresi "şifrelenmiş yerel SQLite" ve "3. taraf
      // sunuculara aktarmaz" diyordu; ikisi de doğru değildi (veritabanı
      // şifresiz, veli mesajları Firebase'de). Pencere menüyle kalktı.
      for (final (yol, kod) in kaynaklar()) {
        expect(kod.contains('şifrelenmiş yerel SQLite'), isFalse, reason: yol);
        expect(kod.contains('3. taraf sunuculara'), isFalse, reason: yol);
      }
    });

    test('KRITIK: Cepte "nerede" yolları eski yerleri göstermiyor', () {
      for (final h in cepteEkranHedefleri()) {
        for (final eski in ['Menü ›', 'Belgeler ›', 'Ana sayfa ›', 'Diğer evraklar', 'Alt menü › Program', 'Alt menü › Profil']) {
          expect(h.yol.contains(eski), isFalse, reason: '${h.baslik}: ${h.yol}');
        }
      }
    });
  });

  group('Evraklar sekmesi', () {
    testWidgets('KRITIK: tek katalog; sınıf evrakları Sınıflar sekmesine götürür',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final kap = ProviderContainer();
      addTearDown(kap.dispose);
      kap.read(navigationIndexProvider.notifier).state = AnaSekme.evraklar;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: kap,
        child: const MaterialApp(home: EvraklarSekmesi()),
      ));

      for (final ad in [
        'Öğretmen Dosyası',
        'Yıllık Planlar',
        'Günlük Planlar',
        'Kurul Tutanakları',
        'Sınav İşlemleri',
        'Rehberlik ve BEP',
        'Belirli Gün ve Haftalar',
        'Sosyal Kulüpler',
        'e-Okul Foto',
        'Sınıf Evrakları',
      ]) {
        expect(find.text(ad), findsOneWidget, reason: ad);
      }

      await tester.tap(find.text('Sınıf Evrakları'));
      await tester.pump();
      expect(kap.read(navigationIndexProvider), AnaSekme.siniflar);
      expect(find.byType(EvraklarSekmesi), findsOneWidget,
          reason: 'yeni sayfa açılmaz, sekme değişir');
    });

    testWidgets('KRITIK: Sınav İşlemleri karne görüşünü açıyor, alt çubuğu yok',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: ExamOperationsMenuView()),
      ));
      expect(find.byType(CustomBottomNavBar), findsNothing);
      expect(find.text('Soru Bazlı Sınav Analizi & MEB Raporları'), findsOneWidget);

      await tester.tap(find.text('e-Okul Karne Görüşü'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ClassReportCardCommentsModal), findsOneWidget);
      await bekle(tester);
    });
  });

  testWidgets('KRITIK: Sınıflar sekmesinde "Ders programım" sayfayı açıyor, geri dönülüyor',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: ClassListScreen()),
    ));
    // Sınıf listesi yüklenmeden test biterse yükleme kapanmış sağlayıcıya
    // yazar ve test bittikten sonra kırılır (tam takımda yük altında oldu).
    await bekleKadar(
        tester, () => find.text('Henüz Sınıf Bulunmuyor').evaluate().isNotEmpty);
    expect(find.byKey(const ValueKey('siniflar_ders_programi')), findsOneWidget,
        reason: 'hiç sınıf yokken de görünür');

    await tester.tap(find.byKey(const ValueKey('siniflar_ders_programi')));
    await bekleKadar(tester, () => find.text('Ders Programım').evaluate().isNotEmpty);
    expect(find.byType(ScheduleScreen), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget,
        reason: 'sayfa olarak açıldı, geri düğmesi var');

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await bekleKadar(tester, () => find.byType(ScheduleScreen).evaluate().isEmpty);
    expect(find.byType(ScheduleScreen), findsNothing);
    expect(find.byType(ClassListScreen), findsOneWidget);
    await bekle(tester);
  });

  testWidgets('KRITIK: ana ekran gerçek veritabanıyla açılıyor; sekmeler geziliyor',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    // Kap bilerek kapatılmıyor: ana sayfa açılışta takvim, sınıf, program
    // ve kazanım okumalarını başlatır; tam takımın yükü altında biri test
    // bittikten sonra bitebilir ve kapanmış sağlayıcıya yazınca test kırılır.
    final kap = ProviderContainer(overrides: [
      examTrackingProvider.overrideWith((ref) => _SahteSinavlar(const [])),
      dashboardFeedProvider.overrideWith((ref) async => const []),
      activeTimetableLessonProvider.overrideWith((ref) async => null),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: const MaterialApp(home: MainNavigationScreen()),
    ));
    await bekleKadar(tester, () => find.text('Hızlı İşlemler').evaluate().isNotEmpty);

    // Bugün: menü düğmesi yok, profil yuvarlağı var.
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
    expect(find.text('Bugün'), findsWidgets);

    // Evraklar
    await tester.tap(find.text('Evraklar').last);
    await bekleKadar(tester, () => find.text('Öğretmen Dosyası').evaluate().isNotEmpty);
    expect(kap.read(navigationIndexProvider), AnaSekme.evraklar);
    expect(find.text('Öğretmen Dosyası'), findsOneWidget);

    // Ben: yedek penceresi buradan açılıyor.
    await tester.tap(find.text('Ben'));
    await bekleKadar(tester, () => find.text('Yedekle ve geri yükle').evaluate().isNotEmpty);
    await tester.ensureVisible(find.text('Yedekle ve geri yükle'));
    // pumpAndSettle YOK: tam takımın yükü altında okumalar yavaşlar, bir
    // sekmede yükleniyor simgesi döner ve "durulma" hiç gelmez (10 dakikalık
    // zaman aşımıyla düşmüştü). Pencere animasyonuna sabit süre yeter.
    await tester.tap(find.text('Yedekle ve geri yükle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Yedekten geri yükle'), findsOneWidget);
    expect(find.textContaining('e-Okul fotoğrafları dahil'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Yedekten geri yükle'), findsNothing);

    // Geri tuşu Bugün'e döndürür (çıkmaz).
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(kap.read(navigationIndexProvider), AnaSekme.bugun);

    // Açılışta başlayan veritabanı/takvim okumaları bitmeden kap
    // kapatılırsa "dispose sonrası state" hatası test bittikten sonra düşer.
    await bekle(tester, 30);
  });
}

class _SahteSinavlar extends ExamTrackingNotifier {
  _SahteSinavlar(List<ExamModel> sinavlar)
      : super(ExamOperationsRepository(), ExamSyncService()) {
    state = ExamTrackingState(exams: sinavlar);
  }

  @override
  Future<void> loadExams() async {}
}
