import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/bep/presentation/views/bep_list_view.dart';
import 'package:sinifcepte/features/guidance/presentation/screens/guidance_hub_screen.dart';
import 'package:sinifcepte/features/guidance/presentation/views/special_education_view.dart';

/// Rehberlik ekranı sekmeyle açılabiliyor (26 Ekim 2026).
///
/// ## Neden bu test var
/// Cepte'de "bep" arayıp sonuca dokununca Rehberlik'in "Özel Eğitim" sekme
/// gövdesi tek başına açılıyordu: sayfa iskeleti yoktu, zemin siyah,
/// başlık ve geri düğmesi yok, çipler durum çubuğunun altında. Artık
/// Rehberlik ekranı istenen sekmeyle açılıyor; "bep" BEP Gelişim'i,
/// "özel eğitim" Özel Eğitim'i gösteriyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'rehberlik_sekmeleri_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
    for (var i = 0; i < 200 && !kosul(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

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

  Future<void> sayfaOlarakAc(WidgetTester tester, Widget sayfa) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => sayfa)),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  int seciliSekme(WidgetTester tester) => tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

  testWidgets('KRITIK: Özel Eğitim sekmesiyle açılır; başlık, geri düğmesi ve sayfa zemini var', (tester) async {
    await sayfaOlarakAc(
      tester,
      const GuidanceHubScreen(baslangicSekmesi: GuidanceHubScreen.ozelEgitimSekmesi),
    );
    expect(seciliSekme(tester), GuidanceHubScreen.ozelEgitimSekmesi);
    expect(find.text('Rehberlik'), findsOneWidget, reason: 'sayfanın üst çubuğu');
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byType(SpecialEducationView), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(SpecialEducationView), matching: find.byType(Scaffold)),
      findsWidgets,
      reason: 'sekme gövdesi bir sayfanın içinde',
    );
    await bekleKadar(tester, () => find.textContaining('gösterge').evaluate().isNotEmpty);
    expect(find.textContaining('gösterge'), findsWidgets, reason: 'ORGM programları yüklendi');
  });

  testWidgets('varsayılan ve "bep" açılışı BEP Gelişim sekmesi', (tester) async {
    await sayfaOlarakAc(tester, const GuidanceHubScreen());
    expect(seciliSekme(tester), GuidanceHubScreen.bepSekmesi);
    expect(GuidanceHubScreen.bepSekmesi, 0);
    expect(find.text('BEP Gelişim'), findsOneWidget);
    // Sınıf listesi okuması bitmeden test biterse kapanmış veritabanına yazar.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
  });

  // Kullanıcı (26 Ekim 2026): "BEP raporunda öğrenci arama yok; tek tek
  // tüm öğrencilere bakmak yerine üstte arama kutusu olsa işleri hızlandırır."
  testWidgets('KRITIK: BEP hedef takibinde öğrenci aranıyor', (tester) async {
    late ClassModel sinif;
    late List<StudentModel> ogrenciler;
    await tester.runAsync(() async {
      final id = await ClassRepository().insertClass(
          const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true));
      sinif = ClassModel(id: id, name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true);
      for (final (no, ad, soyad) in [(3, 'Ayşe', 'KAYA'), (7, 'Ali', 'YILMAZ'), (12, 'Işıl', 'DEMİR')]) {
        await StudentRepository().insertStudent(
            StudentModel(classId: id, schoolNumber: no, firstName: ad, lastName: soyad));
      }
      ogrenciler = await StudentRepository().getStudentsByClassId(id);
    });
    await sayfaOlarakAc(
      tester,
      BepListView(
        classModel: sinif,
        students: ogrenciler,
        teacher: const TeacherProfileModel(
          id: 'ogretmen',
          firstName: 'Ayşe',
          lastName: 'Demir',
          branch: 'Türkçe',
          schoolName: 'Mimar Sinan Ortaokulu',
          schoolPrincipalName: 'Mehmet Yılmaz',
          email: 'ayse@meb.k12.tr',
        ),
      ),
    );
    final kutu = find.byKey(const ValueKey('liste_arama'));
    await bekleKadar(tester, () => kutu.evaluate().isNotEmpty);
    expect(find.text('Ali YILMAZ'), findsOneWidget);
    expect(find.text('Işıl DEMİR'), findsOneWidget);

    await tester.enterText(kutu, 'isil');
    await tester.pump();
    expect(find.text('Işıl DEMİR'), findsOneWidget, reason: 'Türkçe harfsiz yazınca da');
    expect(find.text('Ali YILMAZ'), findsNothing);
    expect(find.text('Ayşe KAYA'), findsNothing);
    expect(find.text('Ders / gelişim alanı aç'), findsOneWidget, reason: 'bulunan öğrencinin eylemi');

    await tester.enterText(kutu, '7');
    await tester.pump();
    expect(find.text('Ali YILMAZ'), findsOneWidget, reason: 'okul numarasıyla');
    expect(find.text('Işıl DEMİR'), findsNothing);
  });

  test('rehberlik verisinde PDF bitişik harfi ve "ozellik" yazım hatası yok', () {
    // "keyiﬂi" gibi bitişik harfler aramada "keyifli"yi bulamıyordu.
    // Temizlik üretici betikte (tool/build_rehberlik_dataset.py, nrm).
    final ham = gzip.decode(File('assets/data/sinif_rehberlik_plani.json.gz').readAsBytesSync());
    final metin = utf8.decode(ham);
    for (final harf in ['ﬀ', 'ﬁ', 'ﬂ', 'ﬃ', 'ﬄ']) {
      expect(metin.contains(harf), isFalse, reason: 'U+${harf.codeUnitAt(0).toRadixString(16)}');
    }
    expect(RegExp(r'\bozellik').hasMatch(metin), isFalse);
    expect(File('tool/build_rehberlik_dataset.py').readAsStringSync(), contains('BITISIK'),
        reason: 'temizlik üreticide; yeniden üretimde geri gelmesin');
  });
}
