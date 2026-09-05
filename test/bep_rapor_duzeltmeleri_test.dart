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
import 'package:sinifcepte/features/outcomes/data/models/curriculum_outcome_model.dart';

/// BEP raporunda cihazda görülen yedi kusur.
///
/// ## Neden bu testler var
/// Öğretmen raporu telefonda açıp inceledi. Bulunanların hepsi
/// belgenin *çıktısıyla* ilgili: ölçüt sabitti, tarih hesaplanıyordu,
/// imzada isim basılıydı, kutular farklı boydaydı, bir sütun boş
/// geliyordu. Hiçbiri derlemeyi bozmuyordu — bu yüzden ancak üretilen
/// PDF okunarak yakalanabilir.
void main() {
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'bep_rapor_duzeltmeleri_test.db';
  // PDF gomulu font yukluyor (PdfTrFonts -> rootBundle); sade bir
  // dart testinde ServicesBinding olmadigi icin varlik istegi
  // dogrudan diskten karsilanir.
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final ad = utf8.decode(message!.buffer.asUint8List());
      final f = File(ad);
      if (f.existsSync()) {
        return Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData();
      }
      return null;
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

  Future<BepPlan> planKur() => repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe DEMİR',
        principalName: 'Mehmet ÖZ',
        isHomeroom: true,
        academicYear: '2026-2027',
      );

  /// PDF metnini aranabilir hâle getirir.
  ///
  /// Syncfusion her hücreyi ayrı satıra koyuyor; satır sonları
  /// boşluğa çevrilmezse çok kelimeli hiçbir ifade bulunamaz.
  String duz(String ham) => ham.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<String> pdfMetni(
    BepPlan plan, {
    List<BepLongGoal> goals = const [],
    List<UniqueOutcomeHit> bank = const [],
  }) async {
    final b = await BepPdfGenerator.build(
      plan: plan,
      student: student,
      className: '5-A',
      schoolName: 'Mimar Sinan Ortaokulu',
      teacherName: 'Ayşe DEMİR',
      principalName: 'Mehmet ÖZ',
      goals: goals,
      bank: bank,
    );
    final doc = PdfDocument(inputBytes: b);
    final t = duz(PdfTextExtractor(doc).extractText());
    doc.dispose();
    return t;
  }

  /// Bir uzun amaç ve altında bir kısa amaç.
  Future<List<BepLongGoal>> amacKur(
    BepPlan plan, {
    String criterion = '',
    String outcomeCode = '',
    BepEvalStatus? durum,
  }) async {
    final longId = await repo.insertLongGoal(BepLongGoal(
      planId: plan.id!,
      title: 'Sayılar ve İşlemler',
    ));
    final shortId = await repo.insertShortGoal(BepShortGoal(
      longGoalId: longId,
      condition: 'Sınıf ortamında',
      behavior: 'Ahmet iki basamaklı sayıları okur',
      criterion: criterion,
      outcomeCode: outcomeCode.isEmpty ? null : outcomeCode,
      outcomeDescription: outcomeCode.isEmpty ? null : 'Sayıları okuyabilme',
    ));
    if (durum != null) {
      await repo.addEvaluation(shortGoalId: shortId, status: durum);
    }
    return repo.longGoals(plan.id!);
  }

  group('1 - Olcutu ogretmen belirler', () {
    test('KRITIK: plan olcutu satirlara uygulanir', () async {
      var plan = await planKur();
      plan = plan.copyWith(defaultCriterion: '%60');
      await repo.updatePlan(plan);

      // Kisa amacin kendi olcutu YOK: plan olcutu kullanilmali.
      final goals = await amacKur(plan);
      final metin = await pdfMetni((await repo.getPlan(plan.id!))!,
          goals: goals);

      expect(metin.contains('%60'), isTrue,
          reason: 'öğretmenin ölçütü belgeye çıkmıyor');
      expect(metin.contains('4/5 (%80)'), isFalse,
          reason: 'sabit ölçüt hâlâ basılıyor');
    });

    test('KRITIK: amacin KENDI olcutu plan olcutunu ezer', () async {
      var plan = await planKur();
      plan = plan.copyWith(defaultCriterion: '%60');
      await repo.updatePlan(plan);

      final goals = await amacKur(plan, criterion: '9/10 (%90)');
      final metin = await pdfMetni((await repo.getPlan(plan.id!))!,
          goals: goals);

      expect(metin.contains('9/10 (%90)'), isTrue,
          reason: 'satıra özel ölçüt kayboldu');
    });

    test('olcut girilmemisse eski sabit surer', () async {
      final plan = await planKur();
      final goals = await amacKur(plan);
      final metin = await pdfMetni(plan, goals: goals);

      // Geriye donuk uyum: eski planlar bozulmamali.
      expect(metin.contains('4/5 (%80)'), isTrue);
    });
  });

  group('2 - Tarihi ogretmen ayarlar', () {
    test('KRITIK: girilen tarih basilir', () async {
      var plan = await planKur();
      plan = plan.copyWith(startDate: '15.10.2026', endDate: '20.03.2027');
      await repo.updatePlan(plan);

      final goals = await amacKur(plan);
      final metin = await pdfMetni((await repo.getPlan(plan.id!))!,
          goals: goals);

      expect(metin.contains('15.10.2026 - 20.03.2027'), isTrue,
          reason: 'öğretmenin tarihi belgeye çıkmıyor');
      expect(metin.contains('11.06.2027'), isFalse,
          reason: 'hesaplanan bitiş hâlâ basılıyor');
    });

    test('KRITIK: tarih girilmemisse eski hesap surer', () async {
      final plan = await planKur();
      final goals = await amacKur(plan);
      final metin = await pdfMetni(plan, goals: goals);

      // Tarih artik okul takviminden hesaplaniyor: eylulun ikinci
      // pazartesisi + 39 hafta. Once her yil 01.09 - 31.05 sabitiydi.
      expect(metin.contains('14.09.2026 - 11.06.2027'), isTrue);
    });

    test('tek taraf girilirse oteki hesaptan tamamlanir', () async {
      var plan = await planKur();
      plan = plan.copyWith(startDate: '01.11.2026');
      await repo.updatePlan(plan);

      final goals = await amacKur(plan);
      final metin = await pdfMetni((await repo.getPlan(plan.id!))!,
          goals: goals);

      expect(metin.contains('01.11.2026 - 11.06.2027'), isTrue,
          reason: 'yarım tarih belgeyi bozuyor');
    });
  });

  group('3 - Degerlendirme cikti verir', () {
    test('KRITIK: isaretlenen durum PDF de gorunur', () async {
      final plan = await planKur();
      final goals = await amacKur(plan, durum: BepEvalStatus.achieved);
      final metin = await pdfMetni(plan, goals: goals);

      // Onceden isaretleme veritabaninda kaliyor, belgeye HIC
      // cikmiyordu; kutucuklarin islevsiz gorunmesinin sebebi buydu.
      expect(metin.contains('Sonuç'), isTrue,
          reason: 'sonuç sütunu açılmamış');
      expect(metin.contains('Yeterli'), isTrue,
          reason: 'işaretlenen değerlendirme belgeye çıkmıyor');
    });

    test('hic degerlendirme yoksa sutun ACILMAZ', () async {
      final plan = await planKur();
      final goals = await amacKur(plan);
      final metin = await pdfMetni(plan, goals: goals);

      // Bos sutun yatay sayfayi gereksiz daraltir.
      expect(metin.contains('Sonuç'), isFalse);
    });
  });

  group('5 - Imzada isim yok', () {
    test('KRITIK: ogretmen ve mudur adi imza blogunda basilmaz', () async {
      final plan = await planKur();
      final goals = await amacKur(plan);
      final metin = await pdfMetni(plan, goals: goals);

      // Kurul uyesi degisince onceden basilmis ad belgeyi yanlis
      // kiliyordu; satirlar elle imzalanir.
      expect(metin.contains('Ayşe DEMİR'), isFalse,
          reason: 'öğretmen adı imza bloğunda basılı');
      expect(metin.contains('Mehmet ÖZ'), isFalse,
          reason: 'müdür adı imza bloğunda basılı');

      // Gorev adlari ve imza satiri DURMALI.
      expect(metin.contains('Öğrenci Velisi'), isTrue);
      expect(metin.contains('Birim Başkanı'), isTrue);
      expect(metin.contains('Adı Soyadı / İmza'), isTrue);
    });

    test('KRITIK: kuruldaki isim de basilmaz', () async {
      var plan = await planKur();
      plan = plan.copyWith(committee: const [
        BepCommitteeMember(role: 'rehber', name: 'Zeynep KAYA'),
      ]);
      await repo.updatePlan(plan);

      final goals = await amacKur(plan);
      final metin = await pdfMetni((await repo.getPlan(plan.id!))!,
          goals: goals);

      expect(metin.contains('Zeynep KAYA'), isFalse,
          reason: 'kurul üyesinin adı imza bloğunda basılı');
    });

    test('ogrencinin adi kunyede DURMAYA devam eder', () async {
      final plan = await planKur();
      final goals = await amacKur(plan);
      final metin = await pdfMetni(plan, goals: goals);

      // Imzadaki ad kaldirildi diye kunyedeki ogrenci adi gitmemeli.
      expect(metin.contains('Ahmet'), isTrue);
    });
  });

  group('6 - Taslak ibaresi kalkti', () {
    test('KRITIK: "Taslak BEP" yazisi yok', () async {
      final plan = await planKur();
      final goals = await amacKur(plan);
      final metin = await pdfMetni(plan, goals: goals);

      // Ibare belgeyi idarenin gozunde gecersiz gosteriyordu.
      expect(metin.contains('Taslak'), isFalse);
      expect(metin.contains('yerine geçmez'), isFalse);
      expect(metin.contains('MEB resmi ürünü değildir'), isFalse);
    });

    test('sayfa numarasi DURUR', () async {
      final plan = await planKur();
      final goals = await amacKur(plan);
      final metin = await pdfMetni(plan, goals: goals);

      // Resmi evrakta sayfa numarasi gerekli; ibareyle birlikte
      // silinmemeli.
      expect(metin.contains('Sayfa 1'), isTrue);
    });
  });

  group('7 - Surec bilesenleri bos kalmaz', () {
    test('KRITIK: bilesen varsa o basilir', () async {
      final plan = await planKur();
      final goals = await amacKur(plan, outcomeCode: 'MAT.5.1.1');
      final metin = await pdfMetni(
        plan,
        goals: goals,
        bank: const [
          UniqueOutcomeHit(
            code: 'MAT.5.1.1',
            description: 'Sayıları okuyabilme',
            unitTitle: 'Sayılar',
            subjectCode: 'MAT',
            subjectName: 'Matematik',
            steps: ['a) Basamak değerini ayırt eder.'],
          ),
        ],
      );

      expect(metin.contains('Basamak değerini ayırt eder'), isTrue);
    });

    test('KRITIK: bilesen TASIYAN kayit oncelikli secilir', () async {
      // Ayni kazanim mufredatta birden cok hafta tekrar ediyor ve MEB
      // bilesenleri her tekrarda yazmamis. Olcum: 398 kodda veri
      // baska haftanin satirinda VAR. Onceden ilk gorulen kayit
      // aliniyordu; bilesensizse sutun bos kaliyordu.
      final plan = await planKur();
      final goals = await amacKur(plan, outcomeCode: 'MAT.5.1.1');
      final metin = await pdfMetni(
        plan,
        goals: goals,
        bank: const [
          // Once BOS kayit geliyor.
          UniqueOutcomeHit(
            code: 'MAT.5.1.1',
            description: 'Sayıları okuyabilme',
            unitTitle: 'Sayılar',
            subjectCode: 'MAT',
            subjectName: 'Matematik',
          ),
          // Sonra DOLU olan.
          UniqueOutcomeHit(
            code: 'MAT.5.1.1',
            description: 'Sayıları okuyabilme',
            unitTitle: 'Sayılar',
            subjectCode: 'MAT',
            subjectName: 'Matematik',
            steps: ['a) Basamak değerini ayırt eder.'],
          ),
        ],
      );

      expect(metin.contains('Basamak değerini ayırt eder'), isTrue,
          reason: 'boş kayıt seçilmiş, dolu olan atlanmış');
    });

    test('KRITIK: hic bilesen yoksa hucre bos kalmaz', () async {
      // Olcum: 1992 kazanim kodunun 1047'sinde hicbir haftada bilesen
      // yok. Bos hucre resmi evrakta eksik doldurulmus gibi duruyor.
      final plan = await planKur();
      final goals = await amacKur(plan, outcomeCode: 'MAT.5.9.9');
      final metin = await pdfMetni(plan, goals: goals);

      expect(metin.contains('Ahmet iki basamaklı sayıları okur'), isTrue,
          reason: 'süreç bileşeni hücresi tamamen boş kalmış');
    });
  });
}
