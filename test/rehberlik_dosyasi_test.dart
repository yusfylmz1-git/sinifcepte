import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/utils/date_formatter.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/bep/data/models/bep_models.dart';
import 'package:sinifcepte/features/guidance/data/models/guidance_plan_model.dart';
import 'package:sinifcepte/features/guidance/data/repositories/guidance_plan_repository.dart';
import 'package:sinifcepte/features/guidance/presentation/screens/rehberlik_dosyasi_screen.dart';
import 'package:sinifcepte/features/guidance/presentation/views/guidance_plan_view.dart';
import 'package:sinifcepte/features/guidance/utils/rehberlik_dosyasi_pdf.dart';
import 'package:sinifcepte/shared/widgets/gruplu_liste.dart';

/// Rehberlik Dosyası (29 Ekim 2026).
///
/// Kullanıcı: "Rehberlik dosyasında ORGM'nin sitesindeki rehberlik
/// dosyasında olması gereken evraklar olmalı." Taslak gösterildi, onaylandı
/// ("devam edelim o zaman"). Belgeler zamana göre gruplu; dördü yeni.
///
/// Yapılırken bulunan kusur: takvim haftası tatilleri de sayıyor, plan
/// haftası saymıyor. "Bu hafta" ara tatilden sonra kayıyor, toplu
/// işaretleme yarıyıldan sonra gelmemiş haftaları "uygulandı" yapıyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ogretmen = TeacherProfileModel(
    id: 'ogretmen',
    firstName: 'Ayşe',
    lastName: 'Demir',
    branch: 'Türkçe',
    schoolName: 'Mimar Sinan Ortaokulu',
    schoolPrincipalName: 'Mehmet Yılmaz',
    email: 'ayse@meb.k12.tr',
  );
  const sinif = ClassModel(id: 1, name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true);

  group('Takvim haftası → plan haftası', () {
    late List<GuidancePlanItem> plan;
    setUpAll(() async => plan = await GuidancePlanRepository().planFor(5));

    test('KRITIK: ara tatil ve yarıyıl atlanır', () {
      expect(planHaftasi(plan, 7), (hafta: 7, tatil: false, tatilAdi: null), reason: '26-30 Ekim');
      expect(planHaftasi(plan, 9).hafta, 9);
      final ara = planHaftasi(plan, 10);
      expect(ara.tatil, isTrue, reason: '16-20 Kasım ara tatil');
      expect(ara.hafta, 9, reason: 'tatilde son gelen hafta');
      expect(ara.tatilAdi, 'ARA TATİLİ');
      expect(planHaftasi(plan, 11), (hafta: 10, tatil: false, tatilAdi: null), reason: '23-27 Kasım');
      expect(planHaftasi(plan, 19), (hafta: 18, tatil: false, tatilAdi: null), reason: '18-22 Ocak');
      expect(planHaftasi(plan, 20).tatil, isTrue, reason: '25-29 Ocak yarıyıl');
      expect(planHaftasi(plan, 21).tatil, isTrue, reason: '1-5 Şubat yarıyıl');
      expect(planHaftasi(plan, 22).hafta, 19, reason: '8-12 Şubat: takvim 22, plan 19');
    });

    test('KRITIK: gerçek tarihle; uygulamanın takvim haftası hesabı üzerinden', () {
      int bu(DateTime gun) => planHaftasi(plan, AppDateFormatter.getCurrentAcademicWeek(targetDate: gun)).hafta;
      expect(bu(DateTime(2026, 10, 29)), 7, reason: '26-30 Ekim');
      expect(bu(DateTime(2026, 11, 25)), 10, reason: 'ara tatilden sonraki hafta');
      expect(bu(DateTime(2027, 2, 10)), 19, reason: 'yarıyıldan sonraki ilk hafta');
      expect(planHaftasi(plan, AppDateFormatter.getCurrentAcademicWeek(targetDate: DateTime(2027, 1, 27))).tatil,
          isTrue,
          reason: 'yarıyıl tatili');
    });

    test('KRITIK: hiçbir takvim haftasında henüz gelmemiş plan haftası "gelmiş" sayılmaz', () {
      // Toplu işaretleme "bu haftaya kadar" işaretler; plan haftası o güne
      // kadarki tatilsiz hafta sayısını geçerse gelmemiş hafta işaretlenir.
      final araliklar = <String>[];
      for (final m in plan) {
        if (m.tarihAraligi.isNotEmpty && !araliklar.contains(m.tarihAraligi)) araliklar.add(m.tarihAraligi);
      }
      final tatilli = {for (final m in plan) if (m.tatilMi) m.tarihAraligi};
      for (var t = 1; t <= araliklar.length; t++) {
        final dersHaftasi = araliklar.take(t).where((a) => !tatilli.contains(a)).length;
        expect(planHaftasi(plan, t).hafta, dersHaftasi, reason: 'takvim $t (${araliklar[t - 1]})');
      }
    });

    test('yazın tatil, bütün haftalar gelmiş', () {
      final yaz = planHaftasi(plan, 45);
      expect(yaz.tatil, isTrue);
      expect(yaz.hafta, 37);
    });

    test('bütün kademelerin planı aynı tarih aralıklarını aynı sırayla taşır', () async {
      List<String> araliklar(List<GuidancePlanItem> p) => [
            for (final m in p)
              if (m.tarihAraligi.isNotEmpty) m.tarihAraligi,
          ].fold<List<String>>([], (l, a) => l.contains(a) ? l : (l..add(a)));
      final ilk = araliklar(await GuidancePlanRepository().planFor(0));
      expect(ilk, hasLength(41));
      for (var k = 1; k <= 12; k++) {
        expect(araliklar(await GuidancePlanRepository().planFor(k)), ilk, reason: '$k. sınıf');
      }
    });

    test('1. dönem yarıyıl tatilinden önce biter', () {
      final birinci = birinciDonemMaddeleri(plan).where((m) => m.uygulanabilir).toList();
      expect(birinci.last.hafta, 18);
      expect(birinci, hasLength(18));
    });

    test('tarih aralığı olmayan planda eski davranış', () {
      const p = [GuidancePlanItem(gradeLevel: 5, ay: 'EYLÜL', siraNo: 1, hafta: 1, kazanim: 'x')];
      expect(planHaftasi(p, 4), (hafta: 4, tatil: false, tatilAdi: null));
    });
  });

  group('Zaman etiketi', () {
    test('ayın içinde "bu ay", bir önceki ayda "yaklaşıyor"', () {
      expect(zamanEtiketi(const [11], DateTime(2026, 10, 29)), 'yaklaşıyor');
      expect(zamanEtiketi(const [11], DateTime(2026, 11, 3)), 'bu ay');
      expect(zamanEtiketi(const [11], DateTime(2027, 3, 1)), isNull);
      expect(zamanEtiketi(const [1, 6], DateTime(2026, 12, 20)), 'yaklaşıyor', reason: 'aralık → ocak');
      expect(zamanEtiketi(const [9, 10], DateTime(2026, 8, 25)), 'yaklaşıyor');
    });
  });

  group('Faaliyet raporu', () {
    late List<GuidancePlanItem> plan;
    setUpAll(() async => plan = await GuidancePlanRepository().planFor(5));

    GuidanceLogEntry kayit(int hafta, {bool uygulandi = true, String not = ''}) => GuidanceLogEntry(
          classId: 1,
          academicYear: '2026-2027',
          gradeLevel: 5,
          hafta: hafta,
          siraNo: hafta,
          uygulandi: uygulandi,
          not: not,
          uygulanmaTarihi: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        );

    test('KRITIK: bitmemiş hafta "uygulanamadı" sayılmaz; uygulanan her hafta sayılır', () {
      // 7. haftanın içindeyiz: 6. hafta bitti, 7. sürüyor.
      final o = RehberlikDosyasiPdf.faaliyetOzeti(
        donem: FaaliyetDonemi.birinci,
        plan: plan,
        kayitlar: {for (final h in [1, 2, 3, 5, 7]) h: kayit(h)},
        sonGecenHafta: 6,
      );
      expect(o.kapsam, hasLength(18));
      expect(o.planlanan.map((m) => m.hafta), [1, 2, 3, 4, 5, 6, 7]);
      expect(o.uygulanan.map((m) => m.hafta), [1, 2, 3, 5, 7], reason: 'bu hafta uygulandıysa sayılır');
      expect(o.uygulanmayan.map((m) => m.hafta), [4, 6]);

      final buHaftaYapilmadi = RehberlikDosyasiPdf.faaliyetOzeti(
        donem: FaaliyetDonemi.birinci,
        plan: plan,
        kayitlar: {for (final h in [1, 2, 3, 5]) h: kayit(h)},
        sonGecenHafta: 6,
      );
      expect(buHaftaYapilmadi.uygulanmayan.map((m) => m.hafta), [4, 6], reason: '7. hafta henüz bitmedi');
    });

    test('yıl sonu iki dönemi kapsar; "uygulanmadı" kaydı uygulanmış sayılmaz', () {
      final o = RehberlikDosyasiPdf.faaliyetOzeti(
        donem: FaaliyetDonemi.yilSonu,
        plan: plan,
        kayitlar: {1: kayit(1), 20: kayit(20), 4: kayit(4, uygulandi: false, not: 'Sınav haftası')},
        sonGecenHafta: 37,
      );
      expect(o.kapsam, hasLength(36));
      expect(o.planlanan, hasLength(36));
      expect(o.uygulanan.map((m) => m.hafta), [1, 20]);
      expect(o.uygulanmayan, hasLength(34));
    });

    for (final d in FaaliyetDonemi.values) {
      test('${d.baslik} raporu PDF olarak çıkar', () async {
        final b = await RehberlikDosyasiPdf.faaliyetRaporu(
          donem: d,
          classModel: sinif,
          students: const [
            StudentModel(classId: 1, schoolNumber: 3, firstName: 'Ayşe', lastName: 'KAYA', gender: 'Kız'),
            StudentModel(classId: 1, schoolNumber: 7, firstName: 'Ali', lastName: 'YILMAZ', gender: 'Erkek'),
          ],
          teacherProfile: ogretmen,
          plan: plan,
          kayitlar: {1: kayit(1), 2: kayit(2), 4: kayit(4, uygulandi: false, not: 'Gezi vardı')},
          sonGecenHafta: 6,
          bepliOgrenci: 1,
          devamsizTakip: 2,
          tarih: DateTime(2027, 1, 22),
        );
        expect(latin1.decode(b.sublist(0, 4)), '%PDF');
      });
    }
  });

  group('Yeni belgeler', () {
    test('özel eğitim listesi: BEP\'liler ve boş liste', () async {
      for (final liste in [
        const <BepStudentSummary>[],
        const [
          BepStudentSummary(
            studentId: 1,
            studentName: 'Ali YILMAZ',
            schoolNumber: 7,
            planCount: 2,
            shortGoalCount: 8,
            achievedCount: 3,
            subjects: ['Türkçe', 'Matematik'],
            plans: [],
          ),
          BepStudentSummary(
            studentId: 2,
            studentName: 'Ayşe KAYA',
            schoolNumber: 3,
            planCount: 0,
            shortGoalCount: 0,
            achievedCount: 0,
            subjects: [],
            plans: [],
          ),
        ],
      ]) {
        final b = await RehberlikDosyasiPdf.ozelEgitimListesi(
            classModel: sinif, ogrenciler: liste, teacherProfile: ogretmen);
        expect(latin1.decode(b.sublist(0, 4)), '%PDF');
      }
    });

    test('görüşme çizelgesi', () async {
      final b = await RehberlikDosyasiPdf.gorusmeCizelgesi(classModel: sinif, teacherProfile: ogretmen);
      expect(latin1.decode(b.sublist(0, 4)), '%PDF');
    });
  });

  group('Ekran', () {
    AppConfig.testDbNameOverride = 'rehberlik_dosyasi_test.db';
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

    Future<ClassModel> kur(WidgetTester tester, {bool ogrenciVar = true}) async {
      late ClassModel c;
      await tester.runAsync(() async {
        final id = await ClassRepository().insertClass(
            const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true));
        c = sinif.copyWith(id: id);
        if (ogrenciVar) {
          await StudentRepository()
              .insertStudent(StudentModel(classId: id, schoolNumber: 3, firstName: 'Ayşe', lastName: 'KAYA'));
        }
      });
      return c;
    }

    Future<void> ac(WidgetTester tester, ClassModel c) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: RehberlikDosyasiScreen(classModel: c))));
      await bekleKadar(tester, () => find.byKey(const ValueKey('rehberlik_dosyasi_hafta')).evaluate().isNotEmpty);
      // Öğrenci listesi provider'dan ayrıca yüklenir.
      await bekleKadar(tester, () => find.text('1 öğrenci · imza sütunlu').evaluate().isNotEmpty);
    }

    const sira = [
      'plan',
      'sinif_listesi',
      'veli_listesi',
      'oturma_plani',
      'tanima_fisi',
      'ozel_egitim',
      'risk_haritasi',
      'haftalik_kayitlar',
      'gorusme_cizelgesi',
      'devamsizlik',
      'veli_toplantisi',
      'gezi_izni',
      'rapor_donem',
      'rapor_yil_sonu',
    ];

    testWidgets('KRITIK: ORGM dosyasının belgeleri zamana göre sırayla', (tester) async {
      await ac(tester, await kur(tester));
      final y = [for (final k in sira) tester.getTopLeft(find.byKey(ValueKey('rehberlik_dosyasi_$k'))).dy];
      for (var i = 1; i < y.length; i++) {
        expect(y[i] > y[i - 1], isTrue, reason: '${sira[i - 1]} → ${sira[i]}');
      }
      final gruplar = ['YIL BAŞI · EYLÜL–EKİM', 'KASIM', 'YIL BOYUNCA', 'DÖNEM VE YIL SONU'];
      final gy = [for (final g in gruplar) tester.getTopLeft(find.text(g)).dy];
      expect(gy[0] < y[0] && y[5] < gy[1] && gy[1] < y[6] && y[6] < gy[2] && gy[2] < y[7] && y[11] < gy[3],
          isTrue,
          reason: 'belgeler kendi gruplarının altında');
      expect(find.text('1/1 velinin telefonu kayıtlı'), findsNothing, reason: 'veli telefonu yok');
      expect(find.text('0/1 velinin telefonu kayıtlı'), findsOneWidget);
      expect(find.text('BEP\'i olan öğrenci yok · boş liste'), findsOneWidget);
    });

    testWidgets('bu haftanın kartı haftalık takibi açar', (tester) async {
      await ac(tester, await kur(tester));
      await tester.tap(find.byKey(const ValueKey('rehberlik_dosyasi_hafta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GuidancePlanView), findsOneWidget);
      expect(find.text('Haftalık Takip'), findsOneWidget);
      await bekleKadar(tester, () => find.byType(CircularProgressIndicator).evaluate().isEmpty);
    });

    testWidgets('sınıfta öğrenci yokken öğrenci listesinden çıkan belge açılmaz, nedenini söyler', (tester) async {
      final c = await kur(tester, ogrenciVar: false);
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: RehberlikDosyasiScreen(classModel: c))));
      await bekleKadar(tester, () => find.byKey(const ValueKey('rehberlik_dosyasi_risk_haritasi')).evaluate().isNotEmpty);
      expect(find.text('Önce sınıfa öğrenci ekleyin'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('rehberlik_dosyasi_risk_haritasi')));
      await tester.pump();
      expect(find.text('Bu belge için önce sınıfa öğrenci ekleyin.'), findsOneWidget);
    });
  });
}
