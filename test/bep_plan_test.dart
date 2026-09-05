import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/utils/date_formatter.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/bep/data/bep_developmental_bank.dart';
import 'package:sinifcepte/features/bep/data/bep_option_banks.dart';
import 'package:sinifcepte/features/bep/data/bep_subject_codes.dart';
import 'package:sinifcepte/features/bep/data/models/bep_models.dart';
import 'package:sinifcepte/features/bep/data/repositories/bep_repository.dart';
import 'package:sinifcepte/features/outcomes/data/models/curriculum_outcome_model.dart';

void main() {
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'bep_plan_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late BepRepository repo;
  late int classId;
  late StudentModel student;

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    repo = BepRepository();
    final classRepo = ClassRepository();
    classId = await classRepo.insertClass(const ClassModel(
      name: '5-A',
      subject: 'Matematik',
      academicYear: '2026-2027',
      isHomeroom: true,
    ));
    final studentRepo = StudentRepository();
    final sid = await studentRepo.insertStudent(StudentModel(
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

  group('Plan ve yıl', () {
    test('matematik ve türkçe ayrı plandır', () async {
      final mat = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      final tur = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Türkçe',
        subjectCode: 'TURKCE',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      expect(mat.id, isNot(tur.id));
      expect(mat.subjectCode, 'MAT');
      expect(tur.subjectCode, 'TURKCE');
      expect(mat.gradeLevel, 5);

      await repo.toggleOutcomeOnPlan(
        planId: mat.id!,
        unitTitle: 'Sayılar',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: 'Sayıları okur',
        studentFirstName: 'Ahmet',
        selected: true,
      );
      expect((await repo.longGoals(mat.id!)).single.shorts, isNotEmpty);
      expect(await repo.longGoals(tur.id!), isEmpty);

      final summaries = await repo.summariesForClass(
        students: [student],
        academicYear: '2026-2027',
      );
      expect(
        summaries.single.plans.map((p) => p.subjectCode).toSet(),
        {'MAT', 'TURKCE'},
      );
      expect(
        summaries.single.plans.firstWhere((p) => p.subjectCode == 'MAT').shortGoalCount,
        1,
      );
      expect(
        summaries.single.plans.firstWhere((p) => p.subjectCode == 'TURKCE').shortGoalCount,
        0,
      );
    });

    test('özel eğitim: iki öğrenci farklı kademe ve alan izler', () async {
      final studentRepo = StudentRepository();
      final sid2 = await studentRepo.insertStudent(StudentModel(
        classId: classId,
        schoolNumber: 13,
        firstName: 'Elif',
        lastName: 'Kaya',
      ));
      final elif = StudentModel(
        id: sid2,
        classId: classId,
        schoolNumber: 13,
        firstName: 'Elif',
        lastName: 'Kaya',
      );

      final ozbakim = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Öz bakım',
        subjectCode: 'DEV_OZBAKIM',
        gradeLevel: 0,
        teacherName: 'Zeynep',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
        placement: BepPlacement.specialClass,
        programKind: BepProgramKind.developmental,
        schoolName: 'Örnek Uygulama Okulu',
        diagnosis: 'Hafif düzey zihinsel yetersizlik',
      );
      final mat = await repo.createPlan(
        student: elif,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 2,
        teacherName: 'Zeynep',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
        placement: BepPlacement.specialClass,
        programKind: BepProgramKind.general,
        schoolName: 'Örnek Uygulama Okulu',
      );

      expect(ozbakim.programKind, BepProgramKind.developmental);
      expect(ozbakim.gradeLevel, 0);
      expect(mat.gradeLevel, 2);
      expect(ozbakim.id, isNot(mat.id));

      final skill = BepDevelopmentalBank.hits('DEV_OZBAKIM').first;
      await repo.toggleOutcomeOnPlan(
        planId: ozbakim.id!,
        unitTitle: skill.unitTitle,
        outcomeCode: skill.code,
        outcomeDescription: skill.description,
        studentFirstName: 'Ahmet',
        selected: true,
      );
      expect((await repo.longGoals(ozbakim.id!)).single.shorts, isNotEmpty);
      expect(await repo.longGoals(mat.id!), isEmpty);
    });

    test('kaba değerlendirme: yapamıyor plana alınır, yapıyor alınmaz', () async {
      final plan = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
        track: BepTrack.primary,
      );
      await repo.setCoarse(
        planId: plan.id!,
        unitTitle: 'Sayılar',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: 'Sayıları okur',
        studentFirstName: 'Ahmet',
        canDo: false,
      );
      expect((await repo.longGoals(plan.id!)).single.shorts.single.outcomeCode, 'MAT.5.1.1');
      await repo.setCoarse(
        planId: plan.id!,
        unitTitle: 'Sayılar',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: 'Sayıları okur',
        studentFirstName: 'Ahmet',
        canDo: true,
      );
      expect(await repo.longGoals(plan.id!), isEmpty);
      expect((await repo.coarseForPlan(plan.id!))['MAT.5.1.1'], isTrue);
    });

    test('ders veya kademe yoksa plan açılmaz', () async {
      expect(
        () => repo.createPlan(
          student: student,
          classId: classId,
          subject: '',
          subjectCode: '',
          gradeLevel: 5,
          teacherName: 'Ayşe',
          principalName: 'Müdür',
          isHomeroom: true,
          academicYear: '2026-2027',
        ),
        throwsStateError,
      );
      expect(
        () => repo.createPlan(
          student: student,
          classId: classId,
          subject: 'Matematik',
          subjectCode: 'MAT',
          gradeLevel: 0,
          teacherName: 'Ayşe',
          principalName: 'Müdür',
          isHomeroom: true,
          academicYear: '2026-2027',
        ),
        throwsStateError,
      );
    });

    test('aynı öğrenci+yıl+ders ikinci planı açmaz', () async {
      final a = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      final b = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      expect(a.id, b.id);
    });

    test('yeni öğretim yılı ayrı plandır', () async {
      await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2025-2026',
      );
      final next = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      final all = await repo.plansForStudent(student.id!);
      expect(all.length, 2);
      expect(next.academicYear, '2026-2027');
    });

    test('geçen yıldan kopyalama değerlendirmeyi taşımaz', () async {
      final old = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2025-2026',
      );
      final longId = await repo.insertLongGoal(BepLongGoal(
        planId: old.id!,
        title: 'Sayıları okur',
      ));
      final shortId = await repo.insertShortGoal(BepShortGoal(
        longGoalId: longId,
        condition: 'Sınıf ortamında',
        behavior: '2 basamaklı okur',
        criterion: '4/3',
      ));
      // "Devam" isaretli: kazanilmis amaclar artik varsayilan olarak
      // eleniyor (bkz. bep_yil_devri_test.dart). Burada olculen sey
      // DEGERLENDIRME GECMISININ tasinmamasi; onun icin taşınan bir
      // amac gerekiyor.
      await repo.addEvaluation(
        shortGoalId: shortId,
        status: BepEvalStatus.ongoing,
      );

      final next = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
        copyFromPreviousYear: true,
      );
      final goals = await repo.longGoals(next.id!);
      expect(goals.single.title, 'Sayıları okur');
      expect(goals.single.shorts.single.behavior, '2 basamaklı okur');
      expect(goals.single.shorts.single.latestStatus, isNull);
    });
  });

  group('Kısa amaç kuralları', () {
    test('üç parça yoksa kaydetmez', () async {
      final plan = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      final longId = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'UDA'),
      );
      expect(
        () => repo.insertShortGoal(BepShortGoal(
          longGoalId: longId,
          condition: '',
          behavior: 'okur',
          criterion: '3/4',
        )),
        throwsStateError,
      );
    });

    test('değerlendirme geçmişi silinmez', () async {
      final plan = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      final longId = await repo.insertLongGoal(
        BepLongGoal(planId: plan.id!, title: 'UDA'),
      );
      final shortId = await repo.insertShortGoal(BepShortGoal(
        longGoalId: longId,
        condition: 'sınıfta',
        behavior: 'yazar',
        criterion: '3/4',
      ));
      await repo.addEvaluation(
        shortGoalId: shortId,
        status: BepEvalStatus.ongoing,
      );
      await repo.addEvaluation(
        shortGoalId: shortId,
        status: BepEvalStatus.achieved,
      );
      final goals = await repo.longGoals(plan.id!);
      expect(goals.single.shorts.single.latestStatus, BepEvalStatus.achieved);
    });
  });

  group('Kazanım tohumu', () {
    test('kazanım işaretleyince amaç otomatik yazılır', () async {
      final plan = await repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        teacherName: 'Ayşe',
        principalName: 'Müdür',
        isHomeroom: true,
        academicYear: '2026-2027',
      );
      await repo.toggleOutcomeOnPlan(
        planId: plan.id!,
        unitTitle: 'Doğal sayılar',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: '2 basamaklı sayıları okur',
        studentFirstName: 'Ahmet',
        selected: true,
      );
      var goals = await repo.longGoals(plan.id!);
      expect(goals.single.title, 'Doğal sayılar');
      expect(goals.single.shorts.single.behavior, contains('Ahmet'));
      expect(goals.single.shorts.single.isComplete, isTrue);
      expect(goals.single.shorts.single.outcomeCode, 'MAT.5.1.1');

      await repo.toggleOutcomeOnPlan(
        planId: plan.id!,
        unitTitle: 'Doğal sayılar',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: '2 basamaklı sayıları okur',
        studentFirstName: 'Ahmet',
        selected: false,
      );
      goals = await repo.longGoals(plan.id!);
      expect(goals, isEmpty);
    });

    test('öğretim yılı etiketi Ağustos kırılımı', () {
      expect(AppDateFormatter.academicYearLabel(DateTime(2026, 8, 1)), '2026-2027');
      expect(AppDateFormatter.academicYearLabel(DateTime(2026, 7, 1)), '2025-2026');
    });

    test('tekil kazanım araması aynı kodu tekrarlamaz', () {
      final hits = uniqueOutcomeHits([
        {
          'outcome_code': 'MAT.5.1.1',
          'outcome_description': 'Sayıları okur',
          'unit_title': 'Sayılar',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 0,
        },
        {
          'outcome_code': 'MAT.5.1.1',
          'outcome_description': 'Sayıları okur',
          'unit_title': 'Sayılar',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 0,
        },
        {
          'outcome_code': 'MAT.5.1.2',
          'outcome_description': 'Sayıları yazar',
          'unit_title': 'Sayılar',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 0,
        },
      ]);
      expect(hits.map((h) => h.code), ['MAT.5.1.1', 'MAT.5.1.2']);
    });

    test('kazanım süreç bileşenleri PDF için saklanır', () {
      final hits = uniqueOutcomeHits([
        {
          'outcome_code': 'BTY.5.1.1',
          'outcome_description': 'BTY.5.1.1. Sınıflandırır',
          'unit_title': 'Bilişim Teknolojilerinin Yeri',
          'subject_code': 'BILISIM',
          'subject_name': 'Bilişim',
          'maarif_values': 'Merak, azim',
          'is_holiday_week': 0,
          'outcome_parts': [
            {
              'code': 'BTY.5.1.1',
              'text': 'Sınıflandırır',
              'steps': [
                'a) Temel kavramları belirler.',
                'b) Benzerlik ve farklılıkları ilişkilendirir.',
              ],
            },
          ],
        },
      ]);
      expect(hits.single.steps.first, contains('Temel kavramları'));
      expect(hits.single.values, 'Merak, azim');
    });

    test('OTP sosyal etkinlik ve tatil BEP kazanımı olmaz', () {
      final hits = uniqueOutcomeHits([
        {
          'outcome_code': 'MAT.5.1.1',
          'outcome_description': 'Sayıları okur',
          'unit_title': 'Sayılar',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 0,
        },
        {
          'outcome_code': '',
          'outcome_description': 'Zümre planı yapılır',
          'unit_title': 'Okul Temelli Planlama',
          'topic_title': 'Okul temelli planlama haftası',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_otp_week': 1,
          'is_holiday_week': 0,
        },
        {
          'outcome_code': '',
          'outcome_description': 'Sosyal etkinlikler',
          'unit_title': 'Sosyal Etkinlikler Haftası',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_social_event_week': 1,
          'is_holiday_week': 0,
        },
        {
          'outcome_code': '',
          'outcome_description': 'Ara tatil',
          'unit_title': 'Ara Tatil',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 1,
        },
      ]);
      expect(hits.map((h) => h.code), ['MAT.5.1.1']);
    });

    test('kazanım kodu açıklamada tekrar yazılmaz', () {
      final hits = uniqueOutcomeHits([
        {
          'outcome_code': 'MAT.5.1.1',
          'outcome_description':
              'MAT.5.1.1. Sayıları okur | a) ritmik sayar. b) yazar.',
          'unit_title': 'Sayılar',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 0,
        },
      ]);
      expect(hits.single.code, 'MAT.5.1.1');
      expect(hits.single.description, 'Sayıları okur');
      expect(hits.single.label, 'MAT.5.1.1  Sayıları okur');
    });

    test('outcome_parts haftalar arasında tekilleşir', () {
      const parts = [
        {'code': 'MAT.5.1.1', 'text': 'Sayıları okur'},
        {'code': 'MAT.5.1.2', 'text': 'Sayıları yazar'},
      ];
      final hits = uniqueOutcomeHits([
        {
          'outcome_code': 'MAT.5.1.1',
          'outcome_description': 'MAT.5.1.1. Sayıları okur',
          'outcome_parts': parts,
          'unit_title': 'Sayılar',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 0,
        },
        {
          'outcome_code': 'MAT.5.1.1',
          'outcome_description': 'MAT.5.1.1. Sayıları okur',
          'outcome_parts': parts,
          'unit_title': 'Sayılar',
          'subject_code': 'MAT',
          'subject_name': 'Matematik',
          'is_holiday_week': 0,
        },
      ]);
      expect(hits.map((h) => h.code), ['MAT.5.1.1', 'MAT.5.1.2']);
      expect(hits.map((h) => h.description), ['Sayıları okur', 'Sayıları yazar']);
    });

    test('ders seçicisinde aynı kod iki yayıneviyle tekrarlanmaz', () {
      final unique = BepSubjectCodes.uniqueByCode([
        {'subject_code': 'MAT', 'subject_name': 'Matematik', 'publisher': 'MEB'},
        {'subject_code': 'MAT', 'subject_name': 'Matematik', 'publisher': 'TYMM'},
        {'subject_code': 'TURKCE', 'subject_name': 'Türkçe', 'publisher': 'MEB'},
      ]);
      expect(unique.map((s) => s['subject_code']), ['MAT', 'TURKCE']);
    });

    test('gelişim alanı bankası kodları tekildir', () {
      final hits = BepDevelopmentalBank.hits('DEV_OZBAKIM');
      expect(hits, isNotEmpty);
      expect(hits.map((h) => h.code).toSet().length, hits.length);
      expect(hits.first.subjectCode, 'DEV_OZBAKIM');
    });
  });

  /// ## Neden bu grup var
  /// PDF, resmi BEP tablosunun dokuz sutununu basiyordu ama
  /// "Kullanilacak Materyaller" ve "Olcme-Degerlendirme" veri
  /// modelinde HIC YOKTU: her satira ayni sabit metin yaziliyordu.
  /// Bilisim dersi icin yazilmis "Akilli Tahta, Projeksiyon" listesi
  /// oz bakim BEP'inde de aynen cikiyordu; ogretmen degistiremiyordu.
  ///
  /// Ayni sekilde egitim ortami blogundaki uc kutu sadece BASLIK
  /// basiyordu — "one oturtma", "akran destegi" gibi asil BEP
  /// tedbirleri belgeye hic yazilamiyordu.
  group('Tablo sutunlari gercekten kaydediliyor', () {
    Future<BepPlan> planAc() => repo.createPlan(
          student: student,
          classId: classId,
          subject: 'Matematik',
          subjectCode: 'MAT',
          gradeLevel: 5,
          teacherName: 'Ayşe',
          principalName: 'Müdür',
          isHomeroom: true,
          academicYear: '2026-2027',
        );

    test('KRITIK: materyal ve olcme satir bazinda saklanir', () async {
      final plan = await planAc();
      final longId = await repo.insertLongGoal(BepLongGoal(
        planId: plan.id!,
        title: 'Dört basamaklı sayıları okur',
      ));
      await repo.insertShortGoal(BepShortGoal(
        longGoalId: longId,
        condition: 'Sınıf ortamında',
        behavior: 'iki basamaklı sayıları okur',
        criterion: '4/5 (%80)',
        method: 'Eşzamanlı İpucuyla Öğretim',
        materials: 'Sayma Çubukları, Görsel / Resimli Kartlar',
        assessment: 'Ölçüt Bağımlı Ölçü Aracı, Gözlem Formu',
      ));

      final goals = await repo.longGoals(plan.id!);
      final kayit = goals.single.shorts.single;

      expect(kayit.materials, 'Sayma Çubukları, Görsel / Resimli Kartlar',
          reason: 'materyal sutunu artik SABIT degil, satira ait');
      expect(kayit.assessment, 'Ölçüt Bağımlı Ölçü Aracı, Gözlem Formu');
      expect(kayit.method, 'Eşzamanlı İpucuyla Öğretim');
    });

    test('KRITIK: iki satir FARKLI materyal tasiyabilir', () async {
      // Asil hata buydu: butun satirlar ayni metni gosteriyordu.
      final plan = await planAc();
      final longId = await repo.insertLongGoal(BepLongGoal(
        planId: plan.id!,
        title: 'Öz bakım',
      ));
      await repo.insertShortGoal(BepShortGoal(
        longGoalId: longId,
        condition: 'Sınıf ortamında',
        behavior: 'ellerini yıkar',
        criterion: 'Bağımsız olarak',
        materials: 'Somut Nesneler',
        orderIndex: 0,
      ));
      await repo.insertShortGoal(BepShortGoal(
        longGoalId: longId,
        condition: 'Sınıf ortamında',
        behavior: 'ayakkabısını bağlar',
        criterion: 'Model olunarak',
        materials: 'Etkinlik Kartları',
        orderIndex: 1,
      ));

      final shorts = (await repo.longGoals(plan.id!)).single.shorts;
      expect(shorts.map((e) => e.materials).toSet().length, 2,
          reason: 'satirlar ayni sabiti paylasmamali');
    });

    test('KRITIK: egitim ortami duzenlemeleri planda kalir', () async {
      final plan = await planAc();
      await repo.updatePlan(plan.copyWith(
        physicalArrangements: 'Öğretmene yakın oturtma',
        socialArrangements: 'Akran desteği eşleştirmesi',
        digitalSupports: 'EBA içerikleri',
      ));

      final okunan = await repo.getPlan(plan.id!);
      expect(okunan!.physicalArrangements, 'Öğretmene yakın oturtma');
      expect(okunan.socialArrangements, 'Akran desteği eşleştirmesi');
      expect(okunan.digitalSupports, 'EBA içerikleri');
    });

    test('kazanim tohumu materyal ve olcmeyi de doldurur', () async {
      // Tohum bos birakirsa PDF yine yedek sabite duser; o yuzden
      // tohumun kendisi makul bir baslangic vermeli.
      final seed = BepShortGoal.fromOutcomeSeed(
        longGoalId: 1,
        studentFirstName: 'Ahmet',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: 'Doğal sayıları okur',
      );
      expect(seed.materials.trim(), isNotEmpty);
      expect(seed.assessment.trim(), isNotEmpty);
    });
  });

  /// Hizli kullanim: toplu isaretleme ve varsayilanlar.
  ///
  /// ## Neden
  /// Ogretmen 30-40 kazanimi ve donem sonunda ayni sayida amaci TEK
  /// TEK isaretliyordu. Unite basina "hepsini plana al" vardi ama
  /// listenin icine gomuluydu; toplu degerlendirme hic yoktu.
  group('Hizli BEP', () {
    Future<BepPlan> planAc() => repo.createPlan(
          student: student,
          classId: classId,
          subject: 'Matematik',
          subjectCode: 'MAT',
          gradeLevel: 5,
          teacherName: 'Ayşe',
          principalName: 'Müdür',
          isHomeroom: true,
          academicYear: '2026-2027',
        );

    test('KRITIK: unite basligi UZUN DONEMLI AMAC olarak kaydediliyor',
        () async {
      // Hiyerarsi: unite = uzun donemli amac, kazanimlari = kisa
      // donemli amaclar. Kazanim plana alininca otomatik kurulur.
      final plan = await planAc();
      await repo.toggleOutcomeOnPlan(
        planId: plan.id!,
        unitTitle: 'Doğal Sayılar',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: 'Dört basamaklı sayıları okur',
        studentFirstName: 'Ahmet',
        selected: true,
      );
      await repo.toggleOutcomeOnPlan(
        planId: plan.id!,
        unitTitle: 'Doğal Sayılar',
        outcomeCode: 'MAT.5.1.2',
        outcomeDescription: 'Beş basamaklı sayıları okur',
        studentFirstName: 'Ahmet',
        selected: true,
      );

      final uzun = await repo.longGoals(plan.id!);
      expect(uzun, hasLength(1), reason: 'ayni unite tek uzun amac olmali');
      expect(uzun.single.title, 'Doğal Sayılar');
      expect(uzun.single.shorts, hasLength(2),
          reason: 'iki kazanim ayni uzun amacin altinda');
    });

    test('KRITIK: farkli uniteler ayri uzun amac olur', () async {
      final plan = await planAc();
      for (final (unite, kod) in [
        ('Doğal Sayılar', 'MAT.5.1.1'),
        ('Kesirler', 'MAT.5.2.1'),
      ]) {
        await repo.toggleOutcomeOnPlan(
          planId: plan.id!,
          unitTitle: unite,
          outcomeCode: kod,
          outcomeDescription: 'kazanım',
          studentFirstName: 'Ahmet',
          selected: true,
        );
      }
      final uzun = await repo.longGoals(plan.id!);
      expect(uzun, hasLength(2));
    });

    test('KRITIK: toplu degerlendirme gecmisi silmez', () async {
      // "Tumu: Devam" dedikten sonra tek tek duzeltme yapiliyor;
      // her degerlendirme AYRI kayit olarak birikmelidir.
      final plan = await planAc();
      await repo.toggleOutcomeOnPlan(
        planId: plan.id!,
        unitTitle: 'Doğal Sayılar',
        outcomeCode: 'MAT.5.1.1',
        outcomeDescription: 'Dört basamaklı sayıları okur',
        studentFirstName: 'Ahmet',
        selected: true,
      );
      final kisa = (await repo.longGoals(plan.id!)).single.shorts.single;

      await repo.addEvaluation(
          shortGoalId: kisa.id!, status: BepEvalStatus.ongoing);
      await repo.addEvaluation(
          shortGoalId: kisa.id!, status: BepEvalStatus.achieved);

      final guncel = (await repo.longGoals(plan.id!)).single.shorts.single;
      expect(guncel.latestStatus, BepEvalStatus.achieved,
          reason: 'son degerlendirme gecerli');
    });

    test('varsayilan ortam duzenlemeleri BANKADA var', () async {
      // Varsayilan metin banka listesindeki ifadeyle BIREBIR ayni
      // olmali; yazim farki olursa cip secili gorunmez ve ogretmen
      // "secmedim" saniyor.
      const varsayilanlar = [
        ('Öğretmene yakın oturtma', bepFizikselBankasi),
        ('Dikkat dağıtıcı uyaranların azaltılması', bepFizikselBankasi),
        ('Akran desteği eşleştirmesi', bepSosyalBankasi),
        ('Yönergelerin sadeleştirilmesi', bepSosyalBankasi),
        ('Sık ve anında geri bildirim', bepSosyalBankasi),
        ('Etkileşimli tahta uygulamaları', bepDijitalBankasi),
        ('Video destekli anlatım', bepDijitalBankasi),
      ];
      for (final (metin, banka) in varsayilanlar) {
        expect(banka, contains(metin),
            reason: '"$metin" bankada yok; cip secili gorunmez');
      }
    });
  });
}
