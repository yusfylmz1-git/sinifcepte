import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/features/auth_profile/providers/teacher_profile_provider.dart';
import 'package:sinifcepte/features/classes/providers/class_provider.dart';
import 'package:sinifcepte/features/documents/data/council_minutes.dart';
import 'package:sinifcepte/features/documents/presentation/views/council_minutes_view.dart';

/// Zümre / ŞÖK tutanağı (10 Ekim 2026): önce kısa form, sonra "hazırlandı"
/// ekranı. Kullanıcı rakibin akışını gösterdi; eski düzenleyici her şeyi
/// ilk ekrana yığıyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'council_minutes_view_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
    for (var i = 0; i < 150 && !kosul(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> ac(WidgetTester tester, CouncilKind tur,
      {bool sinifVar = true, Map<String, Object> profil = const {}}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(profil);
    PrefsService.resetCache(); // önceki testin ayarları önbellekte kalmasın
    await tester.runAsync(() async {
      await DatabaseHelper.instance.resetForTests();
      if (sinifVar) {
        await ClassRepository().insertClass(const ClassModel(
            name: '7-A', subject: 'Bilişim Teknolojileri', academicYear: '2026-2027', isHomeroom: true));
      }
    });
    final kap = ProviderContainer();
    addTearDown(kap.dispose);
    await tester.runAsync(() => kap.read(classListProvider.notifier).loadClasses());
    await tester.runAsync(() => kap.read(teacherProfileProvider.notifier).loadProfileFromStorage());
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CouncilMinutesView(kind: tur),
      ),
    ));
    await tester.pump();
  }

  testWidgets('KRITIK: ilk ekran kısa; oluşturunca "hazırlandı" ve eylemler', (tester) async {
    await ac(tester, CouncilKind.zumre);
    expect(find.text('Tutanağı hazırla'), findsOneWidget);
    expect(find.text('Sene başı'), findsOneWidget);
    expect(find.text('Katılımcılar'), findsNothing, reason: 'ayrıntı ilk ekrana yığılmaz');
    expect(find.textContaining('Gündem ('), findsNothing);

    await tester.tap(find.byKey(const Key('tutanak_olustur')));
    await tester.pump();
    expect(find.textContaining('Zümre tutanağı hazırlandı.'), findsOneWidget);
    expect(find.byKey(const Key('tutanak_onizle')), findsOneWidget);
    expect(find.byKey(const Key('tutanak_kagit')), findsOneWidget, reason: 'tutanağın kâğıt hâli');
    final madde = CouncilMinutes.buildAgenda(kind: CouncilKind.zumre, period: CouncilMinutes.suggestedPeriod()).length;
    expect(find.textContaining('$madde madde'), findsOneWidget);
  });

  testWidgets('KRITIK: gündem maddesi düzenlenince sonuç ekranına yansıyor', (tester) async {
    await ac(tester, CouncilKind.zumre);
    await tester.tap(find.byKey(const Key('tutanak_olustur')));
    await tester.pump();
    final once = CouncilMinutes.buildAgenda(kind: CouncilKind.zumre, period: CouncilMinutes.suggestedPeriod()).length;
    await tester.tap(find.byKey(const Key('tutanak_gundem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ek madde'));
    await tester.pumpAndSettle();
    expect(find.text('Gündem (${once + 1} madde)'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('${once + 1} madde'), findsOneWidget);
  });

  testWidgets('tarih takvimden, saat saat seçiciden (elle yazılmıyor)', (tester) async {
    await ac(tester, CouncilKind.zumre);
    await tester.tap(find.byKey(const Key('tutanak_tarih')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tutanak_saat')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets('KRITIK: ŞÖK şubesiz oluşturulamaz, nedeni yazıyor', (tester) async {
    await ac(tester, CouncilKind.sok, sinifVar: false);
    expect(find.text('ŞÖK için önce bir şube seçin.'), findsOneWidget);
    final dugme = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Tutanağı hazırla'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(dugme.onPressed, isNull);
  });

  testWidgets('ŞÖK şubeyle oluşuyor, yer dersliği öneriyor', (tester) async {
    await ac(tester, CouncilKind.sok);
    await bekleKadar(tester, () => find.text('7-A · Bilişim Teknolojileri').evaluate().isNotEmpty);
    expect(find.text('7-A dersliği'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutanak_olustur')));
    await tester.pump();
    expect(find.textContaining('ŞÖK tutanağı hazırlandı.'), findsOneWidget);
  });

  testWidgets('bize özgü: hazır gündem görünür, toplantı takvime göre önerilir', (tester) async {
    await ac(tester, CouncilKind.zumre);
    final g = CouncilMinutes.buildAgenda(
        kind: CouncilKind.zumre, period: CouncilMinutes.suggestedPeriod(), level: CouncilLevel.bilinmiyor);
    expect(find.textContaining('gündem maddesi hazır'), findsOneWidget);
    expect(find.text('Maarif Modeli'), findsOneWidget);
    expect(find.text('Önerilen'), findsOneWidget);
    expect(find.text('Eylül'), findsOneWidget, reason: 'zümre sene başı: ders yılı başlamadan önce');
    expect(g, isNotEmpty);
  });

  testWidgets('dar telefonda (320 dp) form ve hazırlandı ekranı taşmıyor', (tester) async {
    await ac(tester, CouncilKind.sok);
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Dar ekranda düğme listenin altında: önce kaydırılır.
    await tester.dragUntilVisible(
        find.byKey(const Key('tutanak_olustur')), find.byType(ListView), const Offset(0, -300));
    await tester.tap(find.byKey(const Key('tutanak_olustur')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('tutanak_kagit')), findsOneWidget);
  });

  testWidgets('KRITIK: branş profilden, kademe okul bilgisinden varsayılan; değiştirilebilir', (tester) async {
    // Kullanıcı (10 Ekim 2026): "Branş seçimi otomatik olsun ... okul
    // bilgisinden ortaokul mu lise mi ilkokul mu anlayabiliriz".
    await ac(tester, CouncilKind.zumre,
        profil: {'profil_brans': 'Matematik', 'profil_okul_turu': 'Ortaokul'});
    expect(find.text('Ders · profilinizden'), findsOneWidget);
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Kademe · okul bilginizden'), findsOneWidget);
    expect(find.text('Ortaokul'), findsOneWidget);

    final donem = CouncilMinutes.suggestedPeriod();
    int sayi(CouncilLevel l) =>
        CouncilMinutes.buildAgenda(kind: CouncilKind.zumre, period: donem, level: l).length;
    expect(find.text('${sayi(CouncilLevel.ortaokul)} gündem maddesi hazır'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutanak_kademe')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ortaöğretim (lise)'));
    await tester.pumpAndSettle();
    expect(find.text('Kademe'), findsOneWidget, reason: 'artık okul bilgisinden değil, seçildi');
    expect(find.text('Ortaöğretim'), findsOneWidget);
    expect(find.text('${sayi(CouncilLevel.ortaogretim)} gündem maddesi hazır'), findsOneWidget);
  });

  test('KRITIK: rakibin görünüşü kopyalanmadı (kullanıcı: "kopya yapalım demedim")', () {
    // İlk sürüm mor degrade başlık kartıyla rakibin birebir aynısıydı.
    final s = File('lib/features/documents/presentation/views/council_minutes_view.dart').readAsStringSync();
    expect(s, isNot(contains('LinearGradient')));
    expect(s, contains('CustomAppBar('), reason: 'uygulamanın kendi başlık çubuğu');
    expect(s, isNot(contains('ActionChip(')), reason: 'açık temada görünmüyor');
  });
}
