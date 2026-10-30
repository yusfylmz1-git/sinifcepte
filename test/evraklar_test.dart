import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/analytics/presentation/views/exam_analysis_list_view.dart';
import 'package:sinifcepte/features/documents/data/council_minutes.dart';
import 'package:sinifcepte/features/documents/data/special_days_repository.dart';
import 'package:sinifcepte/features/documents/presentation/views/council_minutes_view.dart';
import 'package:sinifcepte/features/documents/presentation/views/evraklar_sekmesi.dart';

/// Evraklar (DEG-1, 30 Ekim 2026).
///
/// Kullanıcı başka bir uygulamanın evrak düzenini gösterdi: "adam düzenini
/// çok güzel kurmuş, bizde çok karışık." Bizde kartlar ara merkez
/// açıyordu (Kurul Tutanakları, Sınav İşlemleri); belgeye iki-üç dokunuşta
/// varılıyordu. Taslak gösterildi, onaylandı ("Devam edelim o zaman"):
/// gruplu liste, her satır doğrudan belgeyi açar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Belirli Gün satırı', () {
    const kizilay = SpecialDay(
        ad: 'Kızılay Haftası', tarihMetni: '29 Ekim-4 Kasım', tur: 'aralik', ay: 10, etkinlikli: true);
    const ataturk = SpecialDay(ad: 'Atatürk Haftası', tarihMetni: '10-16 Kasım', tur: 'aralik', ay: 11, etkinlikli: true);
    const sabit = SpecialDay(ad: 'Öğretmenler Günü', tarihMetni: '24 Kasım', tur: 'sabit', ay: 11, etkinlikli: true);
    const anma = SpecialDay(ad: 'Dünya Fikrî Mülkiyet Günü', tarihMetni: '26 Nisan', tur: 'sabit', ay: 4);
    final bugun = DateTime(2026, 10, 30, 14);

    test('KRITIK: ilk etkinlikli gün ve kalan süre', () {
      expect(
          siradakiBelirliGun([
            (madde: anma, tarih: DateTime(2026, 10, 30)),
            (madde: ataturk, tarih: DateTime(2026, 11, 10)),
          ], bugun),
          'Sıradaki: Atatürk Haftası · 11 gün sonra',
          reason: 'pano çalışması olmayan gün atlanır');
      expect(siradakiBelirliGun([(madde: sabit, tarih: DateTime(2026, 10, 31))], bugun),
          'Sıradaki: Öğretmenler Günü · yarın');
      expect(siradakiBelirliGun([(madde: sabit, tarih: DateTime(2026, 10, 30))], bugun),
          'Sıradaki: Öğretmenler Günü · bugün');
    });

    test('dün başlamış hafta "bu hafta" yazılır', () {
      // `upcoming` sürmekte olan haftanın ilk gününü bugün verir.
      expect(siradakiBelirliGun([(madde: kizilay, tarih: DateTime(2026, 10, 30))], bugun),
          'Sıradaki: Kızılay Haftası · bu hafta');
    });

    test('iki haftada etkinlikli gün yoksa null', () {
      expect(siradakiBelirliGun([(madde: anma, tarih: DateTime(2026, 11, 2))], bugun), isNull);
      expect(siradakiBelirliGun(const [], bugun), isNull);
    });
  });

  group('Ekran', () {
    AppConfig.testDbNameOverride = 'evraklar_test.db';
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    setUpAll(() async {
      // Evraklar'daki belirli gün satırı listeyi paylaşılan bir yüklemeyle
      // okur. Yükleme bir testin sahte saatinde başlarsa test bitince yarıda
      // kalır ve listeyi bekleyen sonraki testler (Özet akışı) takılır;
      // burada gerçek zamanda önceden yüklenir.
      await SpecialDaysRepository().all();
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

    Future<void> bekle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
      }
    }

    Future<void> ac(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: EvraklarSekmesi())));
      await bekle(tester);
    }

    testWidgets('KRITIK: on dört belge altı grupta, sırayla', (tester) async {
      await ac(tester);

      const sira = [
        'ogretmen_dosyasi', 'yillik_plan', 'gunluk_plan', //
        'zumre', 'sok', //
        'sinav_analizi', 'karne_gorusu', 'quiz', 'proje', //
        'rehberlik', //
        'belirli_gunler', 'kulupler', 'eokul_foto', //
        'sinif',
      ];
      final y = [for (final a in sira) tester.getTopLeft(find.byKey(ValueKey('evrak_$a'))).dy];
      expect(y, orderedEquals([...y]..sort()), reason: '$sira');

      // Grup başlığı, grubunun ilk satırından hemen önce.
      const gruplar = {
        'DOSYA VE PLANLAR': 0,
        'KURULLAR': 3,
        'SINAV VE DEĞERLENDİRME': 5,
        'REHBERLİK': 9,
        'OKUL ETKİNLİKLERİ VE İDARİ İŞLER': 10,
        'SINIFA BAĞLI EVRAKLAR': 13,
      };
      gruplar.forEach((baslik, ilk) {
        final by = tester.getTopLeft(find.text(baslik)).dy;
        expect(by, lessThan(y[ilk]), reason: baslik);
        if (ilk > 0) expect(by, greaterThan(y[ilk - 1]), reason: baslik);
      });
    });

    testWidgets('KRITIK: kurul tutanakları ara sayfasız açılır', (tester) async {
      await ac(tester);
      for (final (anahtar, tur) in [('evrak_zumre', CouncilKind.zumre), ('evrak_sok', CouncilKind.sok)]) {
        await tester.tap(find.byKey(ValueKey(anahtar)));
        await bekleKadar(tester, () => find.byType(CouncilMinutesView).evaluate().isNotEmpty);
        expect(tester.widget<CouncilMinutesView>(find.byType(CouncilMinutesView)).kind, tur);
        await bekle(tester);
        Navigator.of(tester.element(find.byType(CouncilMinutesView))).pop();
        await bekleKadar(tester, () => find.byType(CouncilMinutesView).evaluate().isEmpty);
      }
    });

    testWidgets('sınav analizi Sınav İşlemleri sayfasından geçmeden açılır', (tester) async {
      await ac(tester);
      await tester.tap(find.byKey(const ValueKey('evrak_sinav_analizi')));
      await bekleKadar(tester, () => find.byType(ExamAnalysisListView).evaluate().isNotEmpty);
      expect(find.byType(ExamAnalysisListView), findsOneWidget);
      await bekle(tester);
    });
  });
}
