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
import 'package:sinifcepte/data/repositories/absence_followup_repository.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/bep/presentation/views/bep_list_view.dart';
import 'package:sinifcepte/features/guidance/presentation/screens/guidance_hub_screen.dart';
import 'package:sinifcepte/features/guidance/presentation/views/guidance_plan_view.dart';

/// Rehberlik ekranı: sekmesiz tek liste (29 Ekim 2026).
///
/// ## Neden bu test var
/// Kullanıcı: "Özel eğitim kısmı gereksiz, kaldıralım. Sekmeye gerek yok,
/// alt alta: en üstte BEP gelişim raporu, altında rehberlik dosyası, en
/// altta formlar. Formlara basınca Rehberlik & Resmî Form Merkezi doğrudan
/// açılsın." Ayrıca sınıf yokken ekran kilitlenmez; kullanılamayan kart
/// nedenini yazar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'rehberlik_ekrani_test.db';
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

  /// Sınıf ve öğrenci okuması bitmeden test biterse kapanmış veritabanına yazar.
  Future<void> dinlen(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
  }

  Future<void> sinifKur(WidgetTester tester, {required bool rehberlik}) async {
    await tester.runAsync(() async {
      final id = await ClassRepository().insertClass(
          ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: rehberlik));
      await StudentRepository()
          .insertStudent(StudentModel(classId: id, schoolNumber: 3, firstName: 'Ayşe', lastName: 'KAYA'));
    });
  }

  bool yuklendi() =>
      find.text('Önce bir sınıf ekleyin.').evaluate().isEmpty &&
      find.textContaining('öğrenci yok').evaluate().isEmpty;

  testWidgets('KRITIK: sekme yok; BEP Gelişim Raporu, Rehberlik Dosyası, Formlar alt alta; Özel Eğitim yok',
      (tester) async {
    await sayfaOlarakAc(tester, const GuidanceHubScreen());
    await dinlen(tester);
    expect(find.byType(TabBar), findsNothing);
    expect(find.textContaining('Özel Eğitim'), findsNothing);
    expect(find.text('Rehberlik'), findsOneWidget, reason: 'sayfanın üst çubuğu');
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    final y = [
      for (final k in ['rehberlik_bep', 'rehberlik_dosyasi', 'rehberlik_formlar'])
        tester.getTopLeft(find.byKey(ValueKey(k))).dy,
    ];
    expect(y[0] < y[1] && y[1] < y[2], isTrue, reason: 'sıra: BEP, dosya, formlar');
  });

  testWidgets('sınıf yokken ekran kilitlenmez; kartlar soluk ve nedenini yazar', (tester) async {
    await sayfaOlarakAc(tester, const GuidanceHubScreen());
    await dinlen(tester);
    expect(find.text('Önce bir sınıf ekleyin.'), findsNWidgets(3));
    await tester.tap(find.text('Formlar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rehberlik & Resmî Form Merkezi'), findsNothing);
  });

  testWidgets('KRITIK: Formlar\'a basınca Rehberlik & Resmî Form Merkezi doğrudan açılır', (tester) async {
    await sinifKur(tester, rehberlik: true);
    await sayfaOlarakAc(tester, const GuidanceHubScreen());
    await bekleKadar(tester, yuklendi);
    await tester.tap(find.text('Formlar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rehberlik & Resmî Form Merkezi'), findsOneWidget);
    await dinlen(tester);
  });

  testWidgets('Rehberlik Dosyası kendi sayfasında açılır', (tester) async {
    await sinifKur(tester, rehberlik: true);
    await sayfaOlarakAc(tester, const GuidanceHubScreen());
    await bekleKadar(tester, yuklendi);
    await tester.tap(find.text('Rehberlik Dosyası'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GuidancePlanView), findsOneWidget);
    expect(find.text('5-A · sınıf rehberlik planı'), findsOneWidget, reason: 'sayfanın üst çubuğu');
    await dinlen(tester);
  });

  testWidgets('branş sınıfında Rehberlik Dosyası nedenini yazar, diğerleri açık', (tester) async {
    await sinifKur(tester, rehberlik: false);
    await sayfaOlarakAc(tester, const GuidanceHubScreen());
    await bekleKadar(tester, yuklendi);
    expect(find.textContaining('rehber öğretmeni olduğunuz şube'), findsOneWidget);
    expect(find.textContaining('öğrenci yok'), findsNothing);
    await dinlen(tester);
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
      for (final (no, ad, soyad) in [(3, 'Ayşe', 'KAYA'), (7, 'Ali', 'YILMAZ'), (12, 'Işıl', 'DEMİR'), (15, 'Can', 'ÖZ')]) {
        await StudentRepository().insertStudent(
            StudentModel(classId: id, schoolNumber: no, firstName: ad, lastName: soyad));
      }
      ogrenciler = await StudentRepository().getStudentsByClassId(id);
      // Kullanıcı (26 Ekim 2026): devamsız öğrenci BEP listesinde çıkmaz.
      await AbsenceFollowupRepository().mark(
          studentId: ogrenciler.firstWhere((s) => s.firstName == 'Can').id!,
          classId: id,
          academicYear: '2026-2027');
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
    expect(find.text('Can ÖZ'), findsNothing, reason: 'devamsızlık takibinde');

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
