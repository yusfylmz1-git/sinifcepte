import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/documents/data/special_days_repository.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/features/analytics/presentation/widgets/class_report_card_comments_modal.dart';
import 'package:sinifcepte/features/assistant/data/cepte_katalog.dart';
import 'package:sinifcepte/features/attendance/providers/classroom_participation_provider.dart';
import 'package:sinifcepte/features/classes/screens/class_list_screen.dart';
import 'package:sinifcepte/features/classes/screens/sinifim_sekmesi.dart';
import 'package:sinifcepte/features/classes/screens/student_list_screen.dart';
import 'package:sinifcepte/features/dashboard/providers/activity_feed_provider.dart';
import 'package:sinifcepte/features/documents/presentation/views/evraklar_sekmesi.dart';
import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/data/repositories/exam_operations_repository.dart';
import 'package:sinifcepte/features/exam_operations/data/services/exam_sync_service.dart';
import 'package:sinifcepte/features/exam_operations/presentation/views/exam_operations_menu_view.dart';
import 'package:sinifcepte/features/exam_operations/providers/exam_tracking_provider.dart';
import 'package:sinifcepte/features/navigation/providers/navigation_provider.dart';
import 'package:sinifcepte/features/navigation/screens/main_navigation_screen.dart';
import 'package:sinifcepte/features/schedule/models/lesson_model.dart';
import 'package:sinifcepte/features/schedule/models/schedule_settings.dart';
import 'package:sinifcepte/features/schedule/screens/schedule_screen.dart';
import 'package:sinifcepte/features/schedule/utils/gunun_akisi.dart';
import 'package:sinifcepte/shared/widgets/custom_app_bar.dart';
import 'package:sinifcepte/shared/widgets/custom_bottom_nav_bar.dart';

/// Alt çubuk ve Özet (kullanıcı kararı, 26 Ekim 2026).
///
/// ## Neden bu testler var
/// 17 Ekim'de alt çubuk "Bugün · Sınıflar · Kazanımlar · Evraklarım · Ben"
/// yapılmış, ana sayfadaki düğmeler "tek kapı" kuralıyla kaldırılmıştı.
/// Kullanıcı: "ders programı sınıflar bölümünde olmadı", "Özet'teki
/// düğmelerin kalkması iyi olmadı". Yeni düzen:
///   * alt çubuk Özet · Ders Programı · Sınıfım · Profil;
///   * Özet'te altı düğme: Kazanımlar, Ders İçi Katılım, Rehberlik,
///     Sınıflar, Sınav İşlemleri, Evraklar;
///   * Sınıfım rehberlik sınıfını doğrudan açar;
///   * veli gelen kutusu kart değil, üst çubukta zilin yanında;
///   * günün akışı en çok iki ders, "şu an / sıradaki" saate göre.
/// Üç çizgili menü yine yok; sekme numarası tek kaynaktan ([AnaSekme]).
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

  Finder altCubukta(String ad) =>
      find.descendant(of: find.byType(CustomBottomNavBar), matching: find.text(ad));

  setUpAll(() async {
    // Evraklar'daki belirli gün satırı listeyi paylaşılan bir yüklemeyle
    // okur. Yükleme bir testin sahte saatinde başlarsa test bitince yarıda
    // kalır ve listeyi bekleyen sonraki testler (Özet akışı) takılır;
    // burada gerçek zamanda önceden yüklenir.
    await SpecialDaysRepository().all();
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
    // Veritabanı gerçek zamanda açılsın. Açma, kapama ve silme dosya
    // yolu başına tek kilit kullanır; açılış bir ekranın sahte saatinde
    // başlar ve test bitmeden tamamlanmazsa kilit hiç bırakılmaz,
    // sonraki testin silmesi sonsuza dek bekler. Tam takımın yükü altında
    // 31 Ekim'de iki turda beş test 10'ar dakika takıldı.
    await DatabaseHelper.instance.database;
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
    test('KRITIK: Özet · Ders Programı · Sınıfım · Profil, AnaSekme sırasıyla', () {
      final adlar = CustomBottomNavBar.tabs.map((t) => t.label).toList();
      expect(adlar, ['Özet', 'Ders Programı', 'Sınıfım', 'Profil']);
      expect(adlar[AnaSekme.ozet], 'Özet');
      expect(adlar[AnaSekme.dersProgrami], 'Ders Programı');
      expect(adlar[AnaSekme.sinifim], 'Sınıfım');
      expect(adlar[AnaSekme.profil], 'Profil');
    });

    test('KRITIK: ana ekrandaki sekme ekranları aynı sırada', () {
      final kod = yorumsuz(
          oku('lib/features/navigation/screens/main_navigation_screen.dart'));
      final sira = [
        'DashboardScreen(',
        'const ScheduleScreen()',
        'const SinifimSekmesi()',
        'const ProfileScreen()',
      ].map(kod.indexOf).toList();
      expect(sira.every((i) => i > 0), isTrue, reason: '$sira');
      for (var i = 1; i < sira.length; i++) {
        expect(sira[i], greaterThan(sira[i - 1]));
      }
      for (final sayfa in ['WeeklyOutcomesView', 'EvraklarSekmesi', 'ClassListScreen']) {
        expect(kod.contains(sayfa), isFalse, reason: '$sayfa artık Özet\'ten açılan sayfa');
      }
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
      await tester.tap(find.text('Profil'));
      await tester.tap(find.text('Ders Programı'));
      await tester.tap(find.text('Sınıfım'));
      expect(secilen, [AnaSekme.profil, AnaSekme.dersProgrami, AnaSekme.sinifim]);
    });
  });

  group('Özet\'teki altı düğme', () {
    test('KRITIK: kullanıcının yazdığı sırayla ve doğru sayfalara', () {
      final kod = yorumsuz(oku('lib/features/dashboard/screens/dashboard_screen.dart'));
      const dugmeler = [
        ('Kazanımlar', 'const WeeklyOutcomesView()'),
        ('Ders İçi Katılım', 'const ClassroomParticipationView()'),
        ('Rehberlik', 'const GuidanceHubScreen()'),
        ('Sınıflar', 'const ClassListScreen()'),
        ('Sınav İşlemleri', 'const ExamOperationsMenuView()'),
        ('Evraklar', 'const EvraklarSekmesi()'),
      ];
      var onceki = -1;
      for (final (baslik, hedef) in dugmeler) {
        final i = kod.indexOf("'title': '$baslik'");
        expect(i, greaterThan(onceki), reason: '$baslik sırası');
        final j = kod.indexOf("'target': $hedef", i);
        expect(j, greaterThan(i), reason: '$baslik → $hedef');
        expect(j - i, lessThan(400), reason: '$baslik kendi hedefini göstermeli');
        onceki = i;
      }
    });

    test('KRITIK: veli gelen kutusu Özet\'te kart değil, üst çubukta', () {
      final ozet = yorumsuz(oku('lib/features/dashboard/screens/dashboard_screen.dart'));
      expect(ozet.contains('GelenKutusuKarti'), isFalse);
      expect(File('lib/features/parent_portal/presentation/widgets/gelen_kutusu_karti.dart').existsSync(),
          isFalse);
      final ana = yorumsuz(oku('lib/features/navigation/screens/main_navigation_screen.dart'));
      expect(ana, contains('GelenKutusuEkrani.ac(context)'));
      expect(ana, contains('mesajRozeti: gelenKutusu?.rozet'));
    });
  });

  group('Üst çubukta gelen kutusu', () {
    testWidgets('KRITIK: zilin yanında; okunmamış rozeti; dokununca açılır', (tester) async {
      var acildi = 0;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'SınıfCepte',
              showBackButton: false,
              onMessageTap: () => acildi++,
              mesajRozeti: 3,
            ),
          ),
        ),
      ));
      expect(find.byKey(const ValueKey('ust_gelen_kutusu')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('ust_gelen_kutusu_rozet')), matching: find.text('3')),
        findsOneWidget,
      );
      expect(find.byTooltip('Bildirimler'), findsOneWidget, reason: 'zil yerinde');
      await tester.tap(find.byKey(const ValueKey('ust_gelen_kutusu')));
      expect(acildi, 1);
    });

    testWidgets('okunmamış yoksa rozet yok; bulut yoksa simge hiç yok', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(title: 'SınıfCepte', showBackButton: false, onMessageTap: () {}),
          ),
        ),
      ));
      expect(find.byKey(const ValueKey('ust_gelen_kutusu')), findsOneWidget);
      expect(find.byKey(const ValueKey('ust_gelen_kutusu_rozet')), findsNothing);

      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(key: ValueKey('yerel'), title: 'SınıfCepte', showBackButton: false),
          ),
        ),
      ));
      expect(find.byKey(const ValueKey('ust_gelen_kutusu')), findsNothing);
    });
  });

  group('Günün akışı (en çok iki ders)', () {
    // Varsayılan saatler: 1. ders 08:30-09:10, 2. 09:20-10:00, 3. 10:10-10:50,
    // 4. 11:00-11:40, öğle arası, 5. 12:25-13:05, 6. 13:15-13:55.
    const ayar = ScheduleSettings();
    final gun = DateTime(2026, 10, 26);
    DateTime saat(int s, int d) => DateTime(gun.year, gun.month, gun.day, s, d);
    List<LessonModel> dersler(List<int> saatler) => [
          for (final i in saatler)
            LessonModel(
                lessonName: 'Türkçe', className: '5-A', day: 'Pazartesi', lessonHourIndex: i, color: Colors.blue),
        ];
    List<int> gosterilen(GununAkisi a) => [for (final d in a.dersler) d.lessonHourIndex];

    test('KRITIK: 4. dersten sonra sıradaki ders görünür (eskiden ilk dördü gösteriliyordu)', () {
      final a = gununAkisi(dersler([0, 1, 2, 3, 4, 5]), ayar, saat(12, 30));
      expect(gosterilen(a), [4, 5]);
      expect(a.ilkiSuAn, isTrue, reason: '5. ders 12:25-13:05');
    });

    test('ders başlamadan: ilk iki ders, ilki "sıradaki"', () {
      final a = gununAkisi(dersler([0, 1, 2]), ayar, saat(8, 0));
      expect(gosterilen(a), [0, 1]);
      expect(a.ilkiSuAn, isFalse);
    });

    test('ders içinde: şu anki ve sonraki; teneffüste sıradaki', () {
      final ders = gununAkisi(dersler([0, 1, 2, 3]), ayar, saat(9, 30));
      expect(gosterilen(ders), [1, 2]);
      expect(ders.ilkiSuAn, isTrue);
      final teneffus = gununAkisi(dersler([0, 1, 2, 3]), ayar, saat(9, 12));
      expect(gosterilen(teneffus), [1, 2]);
      expect(teneffus.ilkiSuAn, isFalse);
    });

    test('boşluklu program ve karışık sıra: yalnız kalan ders', () {
      final a = gununAkisi(dersler([5, 1]), ayar, saat(10, 30));
      expect(gosterilen(a), [5]);
      expect(a.ilkiSuAn, isFalse);
    });

    test('dersler bitince "bitti"; hiç ders yoksa bitti değil', () {
      final bitti = gununAkisi(dersler([0, 1, 2]), ayar, saat(16, 0));
      expect(bitti.dersler, isEmpty);
      expect(bitti.bitti, isTrue);
      expect(bitti.toplam, 3);
      final bos = gununAkisi(const [], ayar, saat(10, 0));
      expect(bos.bitti, isFalse);
      expect(bos.dersler, isEmpty);
    });

    test('Özet akışı bu hesabı kullanıyor, ilk dördü değil', () {
      final kod = yorumsuz(oku('lib/features/dashboard/screens/dashboard_screen.dart'));
      expect(kod, contains('gununAkisi(todayLessons, scheduleSettings, now)'));
      expect(kod.contains('todayLessons.take('), isFalse);
      expect(kod, contains('ref.watch(lessonClockProvider)'),
          reason: 'Özet gün boyu açık kalır; saat dilimi değişince yenilenmeli');
    });
  });

  group('Katılım kartının dersi (DEG-6, 29 Ekim)', () {
    // Saatler yukarıdaki grupla aynı: 1. ders 08:30-09:10, 2. 09:20-10:00 …
    // 6. 13:15-13:55.
    const ayar = ScheduleSettings();
    final gun = DateTime(2026, 10, 29);
    DateTime saat(int s, int d) => DateTime(gun.year, gun.month, gun.day, s, d);

    test('KRITIK: dersler bitince kart yok (eskiden 1. saate düşüyordu)', () {
      expect(kartDersi([0, 1, 2, 3, 4, 5], ayar, saat(14, 48)), isNull);
    });

    test('ders başlamadan "sıradaki", "şu an" değil', () {
      final k = kartDersi([0, 1, 2], ayar, saat(8, 0))!;
      expect(k.index, 0);
      expect(k.durum, KartDersDurumu.siradaki);
    });

    test('ders içinde "şu an"', () {
      final k = kartDersi([0, 1, 2], ayar, saat(9, 30))!;
      expect(k.index, 1);
      expect(k.durum, KartDersDurumu.suAn);
    });

    test('ders bitince 5 dakika "az önce bitti", sonra sıradaki', () {
      final az = kartDersi([0, 1], ayar, saat(9, 12))!;
      expect((az.index, az.durum), (0, KartDersDurumu.azOnceBitti));
      final sonra = kartDersi([0, 1], ayar, saat(9, 16))!;
      expect((sonra.index, sonra.durum), (1, KartDersDurumu.siradaki));
    });

    test('boş saatte sonraki ders bulunur (eskiden kart kayboluyordu)', () {
      final k = kartDersi([0, 3], ayar, saat(9, 30))!;
      expect((k.index, k.durum), (3, KartDersDurumu.siradaki));
    });

    test('son ders: 5 dakika "az önce bitti", sonra kart yok', () {
      final az = kartDersi([5], ayar, saat(13, 58))!;
      expect((az.index, az.durum), (5, KartDersDurumu.azOnceBitti));
      expect(kartDersi([5], ayar, saat(14, 1)), isNull);
    });

    test('gün boyu günün akışıyla çelişmez', () {
      final saatler = [0, 1, 2, 4, 5];
      final ders = [
        for (final i in saatler)
          LessonModel(lessonName: 'Türkçe', className: '5-A', day: 'Perşembe', lessonHourIndex: i, color: Colors.blue),
      ];
      for (var dk = 7 * 60; dk <= 17 * 60; dk++) {
        final an = saat(dk ~/ 60, dk % 60);
        final akis = gununAkisi(ders, ayar, an);
        final kart = kartDersi(saatler, ayar, an);
        final ne = '${an.hour}:${an.minute}';
        if (akis.bitti) {
          expect(kart == null || kart.durum == KartDersDurumu.azOnceBitti, isTrue, reason: ne);
        }
        if (akis.dersler.isNotEmpty && akis.ilkiSuAn) {
          expect((kart?.index, kart?.durum), (akis.dersler.first.lessonHourIndex, KartDersDurumu.suAn), reason: ne);
        }
        if (kart?.durum == KartDersDurumu.siradaki) {
          expect(akis.dersler.first.lessonHourIndex, kart!.index, reason: ne);
        }
      }
    });

    test('depo kendi saat hesabını yapmıyor, ortak hesabı kullanıyor', () {
      final kod = yorumsuz(oku('lib/features/attendance/data/repositories/classroom_participation_repository.dart'));
      expect(kod, contains('kartDersi('));
      expect(kod.contains('lessonStart'), isFalse);
      expect(kod.contains('activeLessonIndex ?? 0'), isFalse);
    });
  });

  group('Eski yerlerin yeni evi var', () {
    // Madde → (evi olan dosya, o dosyada aranan çağrı).
    const evler = {
      'Sınıfım (rehberlik sınıfı)': ('lib/features/classes/screens/sinifim_sekmesi.dart', 'StudentListScreen('),
      'Sınıflarım': ('lib/features/dashboard/screens/dashboard_screen.dart', 'const ClassListScreen()'),
      'Ders İçi Katılım': ('lib/features/dashboard/screens/dashboard_screen.dart', 'ClassroomParticipationView('),
      'Müfredat & Kazanımlar': ('lib/features/dashboard/screens/dashboard_screen.dart', 'const WeeklyOutcomesView()'),
      'Rehberlik': ('lib/features/dashboard/screens/dashboard_screen.dart', 'const GuidanceHubScreen()'),
      'Evraklar': ('lib/features/dashboard/screens/dashboard_screen.dart', 'const EvraklarSekmesi()'),
      'MEB Çalışma Takvimi': ('lib/features/dashboard/screens/dashboard_screen.dart', 'const AcademicCalendarScreen()'),
      'Raporlar: soru analizi': ('lib/features/exam_operations/presentation/views/exam_operations_menu_view.dart', 'const ExamAnalysisListView()'),
      'Raporlar: karne görüşü': ('lib/features/exam_operations/presentation/views/exam_operations_menu_view.dart', 'ClassReportCardCommentsModal.show('),
      'Raporlar: katılım raporları': ('lib/features/attendance/presentation/views/classroom_participation_view.dart', 'ParticipationCumulativeReportsModal.show('),
      'e-Okul foto': ('lib/features/documents/presentation/views/evraklar_sekmesi.dart', 'const EokulFotoMerkeziEkrani()'),
      'Veri Yedekleme': ('lib/features/profile/screens/profile_screen.dart', 'yedekPenceresiniAc(context)'),
      'Veri Gizliliği & KVKK': ('lib/features/profile/screens/profile_screen.dart', 'const AboutScreen()'),
      'Ayarlar': ('lib/features/profile/screens/profile_screen.dart', 'const SettingsScreen()'),
      'Ders programı': ('lib/features/navigation/screens/main_navigation_screen.dart', 'const ScheduleScreen()'),
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
        for (final eski in [
          'Menü ›',
          'Belgeler ›',
          'Ana sayfa ›',
          'Diğer evraklar',
          'Alt menü',
          'Bugün ›',
          'Evraklarım ›',
          'Ben ›',
          'Sınıflar › Ders programım',
        ]) {
          expect(h.yol.contains(eski), isFalse, reason: '${h.baslik}: ${h.yol}');
        }
      }
    });
  });

  group('Evraklar sayfası', () {
    testWidgets('KRITIK: tek katalog; sınıf evrakları sınıf listesini açar', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: Center(child: _Ac(EvraklarSekmesi())))),
      ));
      await tester.tap(find.text('aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Evraklarım'), findsOneWidget, reason: 'sayfanın kendi üst çubuğu');
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      // DEG-1 (30 Ekim 2026): her belge tek dokunuşta; Kurul Tutanakları
      // ve Sınav İşlemleri ara sayfaları buradan açılmaz.
      for (final ad in [
        'Öğretmen Dosyası',
        'Yıllık Planlar',
        'Günlük Planlar',
        'Zümre Öğretmenler Kurulu',
        'Şube Öğretmenler Kurulu',
        'Sınav Analizleri',
        'e-Okul Karne Görüşü',
        'Quiz ve Sözlü Notlar',
        'Proje ve Ödev Değerlendirme',
        'Rehberlik ve BEP',
        'Belirli Gün ve Haftalar',
        'Sosyal Kulüpler',
        'e-Okul Foto',
        'Sınıf Evrakları',
      ]) {
        expect(find.text(ad), findsOneWidget, reason: ad);
      }
      expect(find.text('Kurul Tutanakları'), findsNothing);
      expect(find.text('Sınav İşlemleri'), findsNothing);

      await tester.tap(find.text('Sınıf Evrakları'));
      await bekleKadar(tester, () => find.text('Henüz Sınıf Bulunmuyor').evaluate().isNotEmpty);
      expect(find.byType(ClassListScreen), findsOneWidget);
      expect(find.text('Sınıflarım'), findsOneWidget);
      await bekle(tester);
    });

    testWidgets('KRITIK: Sınav İşlemleri karne görüşünü açıyor, alt çubuğu yok',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final kap = ProviderContainer();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: kap,
        child: const MaterialApp(home: ExamOperationsMenuView()),
      ));
      expect(find.byType(CustomBottomNavBar), findsNothing);
      // Satırın durumu veritabanından gelir; okuma bitmeden test bitmesin.
      // "Yaklaşan sınav yok" boş başlangıç durumunda da yazar; asıl işaret
      // sınav listesinin yazılıp okunmuş olması. Yazma tek işlemdir (sil +
      // ekle); yarıda kalırsa sonraki testin kapatması onu bekler.
      await bekleKadar(tester, () => kap.read(examTrackingProvider).exams.isNotEmpty);
      expect(kap.read(examTrackingProvider).exams, isNotEmpty,
          reason: 'sınav listesi yüklenmedi');
      expect(
          find.textContaining('Sıradaki:').evaluate().isNotEmpty ||
              find.textContaining('Yaklaşan sınav yok').evaluate().isNotEmpty,
          isTrue);
      expect(find.text('Sınav Analizleri'), findsOneWidget);

      await tester.tap(find.text('e-Okul Karne Görüşü'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ClassReportCardCommentsModal), findsOneWidget);
      await bekle(tester);
    });
  });

  group('Sınıflar ve Sınıfım', () {
    testWidgets('KRITIK: sınıf listesinde ders programı satırı yok; rehberlik seçilmemişse yol gösterir',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => ClassRepository().insertClass(
          const ClassModel(name: '6-B', subject: 'Matematik', academicYear: '2026-2027')));
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: ClassListScreen()),
      ));
      await bekleKadar(tester, () => find.text('6-B').evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('siniflar_ders_programi')), findsNothing);
      expect(find.text('Ders programım'), findsNothing, reason: 'ders programının kendi sekmesi var');
      expect(find.byKey(const ValueKey('rehberlik_sec_notu')), findsOneWidget);
      expect(find.textContaining('Rehberlik Sınıfı Yap'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing, reason: 'kökte geri düğmesi yok');
      await bekle(tester);
    });

    testWidgets('KRITIK: Sınıfım rehberlik sınıfını doğrudan açar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => ClassRepository().insertClass(
          const ClassModel(name: '6-B', subject: 'Matematik', academicYear: '2026-2027')));
      await tester.runAsync(() => ClassRepository().insertClass(const ClassModel(
          name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true)));
      final kap = ProviderContainer();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: kap,
        child: const MaterialApp(home: SinifimSekmesi()),
      ));
      await bekleKadar(tester, () => find.byType(StudentListScreen).evaluate().isNotEmpty);
      expect(find.byType(StudentListScreen), findsOneWidget);
      expect(find.text('5-A'), findsWidgets, reason: 'rehberlik sınıfının sayfası');
      expect(find.byKey(const ValueKey('serit_veliler')), findsOneWidget, reason: 'sınıf şeridi');
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing, reason: 'sekmede geri yok');
      await bekle(tester);
    });

    testWidgets('rehberlik sınıfı yoksa Sınıfım sınıf listesini gösterir', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SinifimSekmesi()),
      ));
      await bekleKadar(tester, () => find.text('Henüz Sınıf Bulunmuyor').evaluate().isNotEmpty);
      expect(find.byType(ClassListScreen), findsOneWidget);
      expect(find.byType(StudentListScreen), findsNothing);
      await bekle(tester);
    });
  });

  testWidgets('KRITIK: ana ekran gerçek veritabanıyla açılıyor; sekmeler ve Özet düğmeleri geziliyor',
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
      // Özet saat dilimini izler; gerçek akış periyodik zamanlayıcı kurar ve
      // test bitince "bekleyen zamanlayıcı" hatası verir.
      lessonClockProvider.overrideWith((ref) => Stream.value(0)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: const MaterialApp(home: MainNavigationScreen()),
    ));
    await bekleKadar(tester, () => find.text('Hızlı İşlemler').evaluate().isNotEmpty);

    // Özet: menü düğmesi yok; altı düğme; gelen kutusu kartı yok.
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
    expect(find.text('Özet'), findsWidgets);
    for (final ad in ['Kazanımlar', 'Ders İçi Katılım', 'Rehberlik', 'Sınıflar', 'Sınav İşlemleri', 'Evraklar']) {
      expect(find.byKey(ValueKey('ozet_$ad')), findsOneWidget, reason: ad);
    }
    expect(find.text('Veli gelen kutusu'), findsNothing);
    expect(find.byKey(const ValueKey('ust_gelen_kutusu')), findsNothing, reason: 'Google girişi yok');

    // Özet › Evraklar sayfa olarak açılır, geri ile Özet'e dönülür.
    await tester.ensureVisible(find.byKey(const ValueKey('ozet_Evraklar')));
    await tester.tap(find.byKey(const ValueKey('ozet_Evraklar')));
    await bekleKadar(tester, () => find.text('Öğretmen Dosyası').evaluate().isNotEmpty);
    expect(find.byType(EvraklarSekmesi), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
    await bekleKadar(tester, () => find.byType(EvraklarSekmesi).evaluate().isEmpty);
    expect(kap.read(navigationIndexProvider), AnaSekme.ozet);

    // Ders Programı sekmesi
    await tester.tap(altCubukta('Ders Programı'));
    await bekle(tester);
    expect(kap.read(navigationIndexProvider), AnaSekme.dersProgrami);
    expect(find.byType(ScheduleScreen), findsOneWidget);

    // Sınıfım: rehberlik sınıfı yok, sınıf listesi
    await tester.tap(altCubukta('Sınıfım'));
    await bekleKadar(tester, () => find.text('Henüz Sınıf Bulunmuyor').evaluate().isNotEmpty);
    expect(kap.read(navigationIndexProvider), AnaSekme.sinifim);

    // Profil: yedek penceresi buradan açılıyor.
    await tester.tap(altCubukta('Profil'));
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

    // Geri tuşu Özet'e döndürür (çıkmaz).
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(kap.read(navigationIndexProvider), AnaSekme.ozet);

    // Açılışta başlayan veritabanı/takvim okumaları bitmeden kap
    // kapatılırsa "dispose sonrası state" hatası test bittikten sonra düşer.
    await bekle(tester, 30);
  });

  testWidgets('DEG-7: Özet tek yaklaşan sınav gösterir; Özet\'e basınca sayfa başına döner',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final ileride = DateTime.now().add(const Duration(days: 3));
    final kap = ProviderContainer(overrides: [
      examTrackingProvider.overrideWith((ref) => _SahteSinavlar([
            for (var i = 0; i < 3; i++)
              ExamModel(id: 's$i', title: 'Deneme Sınavı $i', examDate: ileride.add(Duration(days: i)), category: 'MEB'),
          ])),
      dashboardFeedProvider.overrideWith((ref) async => const []),
      activeTimetableLessonProvider.overrideWith((ref) async => null),
      lessonClockProvider.overrideWith((ref) => Stream.value(0)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: const MaterialApp(home: MainNavigationScreen()),
    ));
    await bekleKadar(tester, () => find.text('Hızlı İşlemler').evaluate().isNotEmpty);

    expect(find.text('Deneme Sınavı 0'), findsOneWidget, reason: 'en yakın sınav');
    expect(find.text('Deneme Sınavı 1'), findsNothing, reason: 'yalnız bir sınav');
    expect(find.text('Deneme Sınavı 2'), findsNothing);

    ScrollController kaydirma() =>
        tester.widget<SingleChildScrollView>(find.byKey(const ValueKey('ozet_kaydirma'))).controller!;
    Future<void> asagi() async {
      kaydirma().jumpTo(kaydirma().position.maxScrollExtent);
      await tester.pump();
      expect(kaydirma().offset, greaterThan(0), reason: 'Özet bu boyda kaymalı');
    }

    // Başka sekmeden dönüş: anında en üst.
    await asagi();
    await tester.tap(altCubukta('Ders Programı'));
    await bekle(tester);
    await tester.tap(altCubukta('Özet'));
    await tester.pump();
    expect(kaydirma().offset, 0);

    // Özet açıkken Özet'e basmak: kayarak en üst.
    await asagi();
    await tester.tap(altCubukta('Özet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(kaydirma().offset, 0);

    await bekle(tester, 30);
  });
}

/// Sayfayı gerçekten "açılmış" hâlde sınar (geri düğmesi canPop'a bağlı).
class _Ac extends StatelessWidget {
  const _Ac(this.sayfa);

  final Widget sayfa;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => sayfa)),
        child: const Text('aç'),
      );
}

class _SahteSinavlar extends ExamTrackingNotifier {
  _SahteSinavlar(List<ExamModel> sinavlar)
      : super(ExamOperationsRepository(), ExamSyncService()) {
    state = ExamTrackingState(exams: sinavlar);
  }

  @override
  Future<void> loadExams() async {}
}
