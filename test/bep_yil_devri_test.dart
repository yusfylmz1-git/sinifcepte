import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/bep/data/models/bep_models.dart';
import 'package:sinifcepte/features/bep/data/repositories/bep_repository.dart';
import 'package:sinifcepte/features/bep/utils/bep_pdf_generator.dart';

/// Amaç gösterimi, otomatik tarih ve yıl devri.
///
/// ## Neden bu testler var
/// Öğretmen sordu: "uzun/kısa amaçlar rapora yansıyor mu, tarih
/// otomatik gelsin, gelecek yıl aynı planı tekrar kullanabilir
/// miyiz?"
///
/// Yansıyordu ama uzun amaç her satırda tekrar ediyordu. Devir
/// düzeneği de yarım kalmıştı: iki alan taşınmıyor, künye hiç
/// taşınmıyor, geçen yıl planı yokken kutu yine görünüyordu.
void main() {
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'bep_yil_devri_test.db';
  // PDF gömülü font yüklüyor; varlık isteği diskten karşılanır.
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final f = File(utf8.decode(message!.buffer.asUint8List()));
      return f.existsSync()
          ? Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData()
          : null;
    });
  });

  late BepRepository repo;
  late int classId;
  late StudentModel student;

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    repo = BepRepository();
    classId = await ClassRepository().insertClass(const ClassModel(
      name: '5-A',
      subject: 'Matematik',
      academicYear: '2026-2027',
      isHomeroom: true,
    ));
    final sid = await StudentRepository().insertStudent(StudentModel(
      classId: classId,
      schoolNumber: 12,
      firstName: 'Ahmet',
      lastName: 'Yılmaz',
    ));
    student = StudentModel(
      id: sid,
      classId: classId,
      schoolNumber: 12,
      firstName: 'Ahmet',
      lastName: 'Yılmaz',
    );
  });

  Future<BepPlan> planKur({
    String yil = '2026-2027',
    int kademe = 5,
    bool devret = false,
    bool yeterliHaric = true,
  }) =>
      repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: kademe,
        teacherName: 'Ayşe DEMİR',
        principalName: 'Mehmet ÖZ',
        isHomeroom: true,
        academicYear: yil,
        copyFromPreviousYear: devret,
        yeterliHaricTut: yeterliHaric,
      );

  String duz(String h) => h.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<String> pdfMetni(BepPlan plan, List<BepLongGoal> goals) async {
    final b = await BepPdfGenerator.build(
      plan: plan,
      student: student,
      className: '5-A',
      schoolName: 'Mimar Sinan Ortaokulu',
      teacherName: 'Ayşe DEMİR',
      principalName: 'Mehmet ÖZ',
      goals: goals,
    );
    final doc = PdfDocument(inputBytes: b);
    final t = duz(PdfTextExtractor(doc).extractText());
    doc.dispose();
    return t;
  }

  group('Uzun ve kisa amaclar PDF de', () {
    test('KRITIK: uzun amac adi grupta BIR KEZ basilir', () async {
      final plan = await planKur();
      final lg = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'Doğal sayıları tanır'),
      );
      for (final d in ['sayıları okur', 'sayıları yazar']) {
        await repo.insertShortGoal(BepShortGoal(
          longGoalId: lg,
          condition: 'Sınıf ortamında',
          behavior: 'Ahmet $d',
          criterion: '',
        ));
      }
      final metin = await pdfMetni(plan, await repo.longGoals(plan.id!));

      // Once her satirda tekrar ediyordu; ogretmen bir amacin nerede
      // bittigini goremiyordu.
      expect('Doğal sayıları tanır'.allMatches(metin).length, 1,
          reason: 'uzun amaç adı tekrar basılmış');
      // Iki kisa amacin ikisi de DURMALI.
      expect(metin.contains('Ahmet sayıları okur'), isTrue);
      expect(metin.contains('Ahmet sayıları yazar'), isTrue);
    });

    test('KRITIK: iki uzun amac da ayri ayri gorunur', () async {
      final plan = await planKur();
      for (final baslik in ['Doğal sayıları tanır', 'Dört işlemi yapar']) {
        final lg = await repo.insertLongGoal(
          BepLongGoal(planId: plan.id!, title: baslik),
        );
        await repo.insertShortGoal(BepShortGoal(
          longGoalId: lg,
          condition: 'Sınıf ortamında',
          behavior: 'Ahmet $baslik uygular',
          criterion: '',
        ));
      }
      final metin = await pdfMetni(plan, await repo.longGoals(plan.id!));

      expect(metin.contains('Doğal sayıları tanır'), isTrue);
      expect(metin.contains('Dört işlemi yapar'), isTrue);
    });

    test('KRITIK: devam satiri adsiz kalmaz', () async {
      final plan = await planKur();
      final lg = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'Doğal sayıları tanır'),
      );
      for (var i = 1; i <= 3; i++) {
        await repo.insertShortGoal(BepShortGoal(
          longGoalId: lg,
          condition: 'Sınıf ortamında',
          behavior: 'Ahmet $i. beceriyi uygular',
          criterion: '',
        ));
      }
      final metin = await pdfMetni(plan, await repo.longGoals(plan.id!));

      // Grup sayfayi asarsa devam satirlari yeni sayfanin ustune
      // duser; ilk sutun tamamen bos kalirsa o satirlarin hangi
      // amaca ait oldugu belgeden anlasilmaz. Isaret bunu onler.
      expect(metin.contains('»'), isTrue,
          reason: 'devam işareti basılmamış');
      // Tam baslik yine de BIR KEZ gecmeli.
      expect('Doğal sayıları tanır'.allMatches(metin).length, 1);
    });

    test('KRITIK: devam isareti gomulu fontta VAR', () async {
      // Ilk denemede ok (U+21B3) kullanildi ve PDF'te kutu cikti:
      // NotoSans'ta o glif yok. Font cmap'i okunarak U+00BB secildi.
      // Bu test glif kaybini yakalar: kutu cikan karakter metin
      // cikarimda da bulunamaz.
      final ham = File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync();
      expect(ham.length, greaterThan(1000), reason: 'font bulunamadı');

      final plan = await planKur();
      final lg = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'Sayılar'),
      );
      for (var i = 1; i <= 2; i++) {
        await repo.insertShortGoal(BepShortGoal(
          longGoalId: lg,
          condition: 'Sınıf ortamında',
          behavior: 'Ahmet $i. beceriyi uygular',
          criterion: '',
        ));
      }
      final metin = await pdfMetni(plan, await repo.longGoals(plan.id!));
      expect(metin.contains('»'), isTrue,
          reason: 'işaret gömülü fontta yok, kutu basılıyor');
    });

    test('KRITIK: sutun adi uzun donemli amaci soyler', () async {
      final plan = await planKur();
      final metin = await pdfMetni(plan, const []);

      // "Ogrenme Alani" sutunun ne oldugunu soylemiyordu.
      expect(metin.contains('Uzun Dönemli Amaç'), isTrue);
    });

    test('KRITIK: olcut bosken ", ." artigi cikmaz', () async {
      // composed her durumda ', ' + olcut + '.' ekliyordu; olcut bos
      // olabildigi icin belgede "...okur, ." artigi olusuyordu.
      const amac = BepShortGoal(
        longGoalId: 1,
        condition: 'Sınıf ortamında',
        behavior: 'Ahmet sayıları okur',
        criterion: '',
      );
      expect(amac.composed, 'Sınıf ortamında Ahmet sayıları okur.');
      expect(amac.composed.contains(', .'), isFalse);

      const olcutlu = BepShortGoal(
        longGoalId: 1,
        condition: 'Sınıf ortamında',
        behavior: 'Ahmet sayıları okur',
        criterion: '%70',
      );
      expect(olcutlu.composed, 'Sınıf ortamında Ahmet sayıları okur, %70.');
    });
  });

  group('Otomatik tarih', () {
    test('KRITIK: okul takvimine gore hesaplanir', () async {
      // Once kaba bir sabitti: her yil 01.09 - 31.05. Gercek okul ne
      // 1 Eylul'de acilir ne 31 Mayis'ta kapanir.
      expect(BepPdfGenerator.planDateRange('2026-2027', 'Eylül'),
          '14.09.2026 - 11.06.2027');
      expect(BepPdfGenerator.planDateRange('2025-2026', 'Eylül'),
          '08.09.2025 - 05.06.2026');
    });

    test('KRITIK: donem ortasinda baslayan plan', () async {
      // Subat'ta acilan BEP: baslangic o ayin ilk is gunu, bitis
      // yine ogretim yilinin sonu.
      final a = BepPdfGenerator.planDateRange('2026-2027', 'Şubat');
      expect(a.endsWith('11.06.2027'), isTrue, reason: 'bitiş değişmemeli');
      expect(a.startsWith('01.02.2027'), isTrue, reason: '1 Şubat 2027 pazartesi');
    });

    test('KRITIK: hesaplanan tarih belgeye basilir', () async {
      final plan = await planKur();
      final lg = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'Sayılar'),
      );
      await repo.insertShortGoal(BepShortGoal(
        longGoalId: lg,
        condition: 'Sınıf ortamında',
        behavior: 'Ahmet okur',
        criterion: '',
      ));
      final metin = await pdfMetni(plan, await repo.longGoals(plan.id!));

      expect(metin.contains('14.09.2026 - 11.06.2027'), isTrue);
      expect(metin.contains('31.05.2027'), isFalse,
          reason: 'eski kaba hesap hâlâ basılıyor');
    });

    test('ogretmenin girdigi tarih USTUNDUR', () async {
      var plan = await planKur();
      plan = plan.copyWith(startDate: '01.10.2026', endDate: '30.04.2027');
      await repo.updatePlan(plan);
      final metin = await pdfMetni((await repo.getPlan(plan.id!))!, const []);

      expect(metin.contains('01.10.2026 - 30.04.2027'), isTrue);
    });
  });

  group('Yil devri', () {
    /// Geçen yılın planı: iki uzun amaç, biri kazanılmış.
    Future<BepPlan> gecenYil() async {
      final plan = await planKur(yil: '2025-2026', kademe: 5);
      final lg1 = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'Doğal sayıları tanır'),
      );
      final kazanilan = await repo.insertShortGoal(BepShortGoal(
        longGoalId: lg1,
        condition: 'Sınıf ortamında',
        behavior: 'Ahmet sayıları okur',
        criterion: '%80',
        materials: 'Sayı Boncuğu',
        assessment: 'Gözlem Formu',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: 'Sayıları okuyabilme',
      ));
      await repo.insertShortGoal(BepShortGoal(
        longGoalId: lg1,
        condition: 'Sınıf ortamında',
        behavior: 'Ahmet sayıları yazar',
        criterion: '%80',
        materials: 'Çalışma Yaprağı',
        assessment: 'Kontrol Listesi',
        outcomeCode: 'MAT.5.1.2',
      ));
      await repo.addEvaluation(
        shortGoalId: kazanilan,
        status: BepEvalStatus.achieved,
      );

      // Ikinci uzun amac: TEK kisa amaci var ve o da kazanilmis.
      final lg2 = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'Dört işlemi yapar'),
      );
      final hepsiKazanildi = await repo.insertShortGoal(BepShortGoal(
        longGoalId: lg2,
        condition: 'Sınıf ortamında',
        behavior: 'Ahmet toplama yapar',
        criterion: '%80',
      ));
      await repo.addEvaluation(
        shortGoalId: hepsiKazanildi,
        status: BepEvalStatus.achieved,
      );

      // Kunye.
      await repo.updatePlan((await repo.getPlan(plan.id!))!.copyWith(
        ramDecision: 'RAM 2025/14 sayılı karar',
        performanceLevel: 'Tek basamaklı sayıları okuyabiliyor',
        physicalArrangements: 'Öğretmene yakın oturtma',
        socialArrangements: 'Akran desteği eşleştirmesi',
        digitalSupports: 'EBA içerikleri',
        defaultCriterion: '%70',
      ));
      return plan;
    }

    test('KRITIK: materyal ve olcme araci TASINIR', () async {
      await gecenYil();
      final yeni = await planKur(yil: '2026-2027', kademe: 5, devret: true);
      final goals = await repo.longGoals(yeni.id!);
      final hepsi = [for (final g in goals) ...g.shorts];

      // Bu iki alan modele sonradan eklenmis, klona yazilmayi
      // unutulmustu; ogretmen her yil yeniden seciyordu.
      final yazan = hepsi.firstWhere((e) => e.behavior.contains('yazar'));
      expect(yazan.materials, 'Çalışma Yaprağı');
      expect(yazan.assessment, 'Kontrol Listesi');
    });

    test('KRITIK: "Yeterli" amaclar haric tutulur', () async {
      await gecenYil();
      final yeni = await planKur(yil: '2026-2027', kademe: 5, devret: true);
      final goals = await repo.longGoals(yeni.id!);
      final hepsi = [for (final g in goals) ...g.shorts];

      expect(hepsi.any((e) => e.behavior.contains('okur')), isFalse,
          reason: 'kazanılmış amaç yeniden taşınmış');
      expect(hepsi.any((e) => e.behavior.contains('yazar')), isTrue,
          reason: 'kazanılmamış amaç düşmüş');
    });

    test('KRITIK: butun kisa amaclari elenen uzun amac ACILMAZ', () async {
      await gecenYil();
      final yeni = await planKur(yil: '2026-2027', kademe: 5, devret: true);
      final goals = await repo.longGoals(yeni.id!);

      // "Dört işlemi yapar"in tek kisa amaci kazanilmisti; bos
      // baslik resmi belgede eksik doldurulmus gibi duruyor.
      expect(goals.any((g) => g.title == 'Dört işlemi yapar'), isFalse);
      expect(goals.any((g) => g.title == 'Doğal sayıları tanır'), isTrue);
    });

    test('istenirse yeterli amaclar da tasinir', () async {
      await gecenYil();
      final yeni = await planKur(
        yil: '2026-2027',
        kademe: 5,
        devret: true,
        yeterliHaric: false,
      );
      final hepsi = [
        for (final g in await repo.longGoals(yeni.id!)) ...g.shorts
      ];
      expect(hepsi.length, 3);
    });

    test('KRITIK: kunye devredilir', () async {
      await gecenYil();
      final yeni = await planKur(yil: '2026-2027', kademe: 5, devret: true);
      final plan = (await repo.getPlan(yeni.id!))!;

      // Once hicbiri tasinmiyordu; her yil sifirdan dolduruluyordu.
      expect(plan.ramDecision, 'RAM 2025/14 sayılı karar');
      expect(plan.performanceLevel, 'Tek basamaklı sayıları okuyabiliyor');
      expect(plan.physicalArrangements, 'Öğretmene yakın oturtma');
      expect(plan.socialArrangements, 'Akran desteği eşleştirmesi');
      expect(plan.digitalSupports, 'EBA içerikleri');
      expect(plan.defaultCriterion, '%70');
    });

    test('KRITIK: UST SINIFTA kazanim bagi kopar, metin kalir', () async {
      await gecenYil();
      // Ogrenci 5'ten 6'ya gecti.
      final yeni = await planKur(yil: '2026-2027', kademe: 6, devret: true);
      final hepsi = [
        for (final g in await repo.longGoals(yeni.id!)) ...g.shorts
      ];
      final yazan = hepsi.firstWhere((e) => e.behavior.contains('yazar'));

      // Kod sinifa aittir: 2153 kodun 1877'si tek bir sinifa ait.
      // MAT.5.1.2 alti sinif planinda yanlis bilgidir; ustelik yeni
      // planin bankasi yalnizca kendi kademesini yukledigi icin
      // hicbir seye eslesmez.
      expect(yazan.outcomeCode, isNull,
          reason: 'eski sınıfın kazanım kodu taşınmış');
      expect(yazan.outcomeDescription, isNull);

      // Amac METNI kalmali: ogrenci hala yapamiyorsa amac gecerli.
      expect(yazan.behavior, 'Ahmet sayıları yazar');
      expect(yazan.criterion, '%80');
      expect(yazan.materials, 'Çalışma Yaprağı');
    });

    test('KRITIK: AYNI SINIFTA kazanim bagi korunur', () async {
      await gecenYil();
      final yeni = await planKur(yil: '2026-2027', kademe: 5, devret: true);
      final hepsi = [
        for (final g in await repo.longGoals(yeni.id!)) ...g.shorts
      ];
      final yazan = hepsi.firstWhere((e) => e.behavior.contains('yazar'));

      // Sinif degismediyse kod hala gecerli; gereksiz yere silinmemeli.
      expect(yazan.outcomeCode, 'MAT.5.1.2');
    });

    test('KRITIK: degerlendirme gecmisi KOPYALANMAZ', () async {
      await gecenYil();
      final yeni = await planKur(
        yil: '2026-2027',
        kademe: 5,
        devret: true,
        yeterliHaric: false,
      );
      final hepsi = [
        for (final g in await repo.longGoals(yeni.id!)) ...g.shorts
      ];

      // Gecen yilin degerlendirmesi yeni yila tasinmaz; plan sifirdan
      // baslar.
      expect(hepsi.every((e) => e.latestStatus == null), isTrue,
          reason: 'geçen yılın değerlendirmesi taşınmış');
    });

    test('KRITIK: devir sonucu bildirilir', () async {
      await gecenYil();
      await planKur(yil: '2026-2027', kademe: 5, devret: true);

      // Kopyalama sessiz olmamali: ogretmen kac amac geldigini
      // gormeli.
      final devir = repo.sonDevir;
      expect(devir, isNotNull);
      expect(devir!.kopyalanan, 1);
      expect(devir.elenen, 2);
    });

    test('gecen yil plani yoksa devir zararsiz', () async {
      // Onceden onay kutusu her zaman goruluyordu ve bu durumda
      // sessizce hicbir sey olmuyordu.
      final yeni = await planKur(yil: '2026-2027', kademe: 5, devret: true);
      expect(await repo.longGoals(yeni.id!), isEmpty);
      expect(repo.sonDevir, isNull);
    });

    test('hasPreviousYear gecmisi dogru bulur', () async {
      expect(
        await repo.hasPreviousYear(
          studentId: student.id!,
          subjectCode: 'MAT',
          year: '2026-2027',
        ),
        isFalse,
      );
      await gecenYil();
      expect(
        await repo.hasPreviousYear(
          studentId: student.id!,
          subjectCode: 'MAT',
          year: '2026-2027',
        ),
        isTrue,
      );
      // Baska ders: gecmis yok.
      expect(
        await repo.hasPreviousYear(
          studentId: student.id!,
          subjectCode: 'TURKCE',
          year: '2026-2027',
        ),
        isFalse,
      );
    });
  });
}
