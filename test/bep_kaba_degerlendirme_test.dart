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
import 'package:sinifcepte/features/bep/utils/bep_coarse_pdf_generator.dart';

/// Kaba Değerlendirme Formu (KDF).
///
/// ## Neden bu testler var
/// Kullanıcı, ERBAA RAM'in kullandığı sistemin ekran görüntülerini
/// paylaştı: *"bep planında bir de kaba değerlendirme formu muhabbeti
/// varmış, biz projeye dahil edebilir miyiz?"*
///
/// Ölçüm: işaretleme altyapısı (`bep_coarse`, "yapamıyor → plana al")
/// bizde ZATEN vardı. Eksik olan iki şeydi:
///   * belgenin kendisi — öğretmen işaretliyor ama formu okul
///     dosyasına koyamıyordu
///   * künye — değerlendirme tarihi ve değerlendiren hiç tutulmuyordu
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu paylasirlarsa
  // "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'bep_kaba_degerlendirme_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    // PDF gömülü font yüklüyor; varlık isteği diskten karşılanır.
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
      subject: 'Bilişim Teknolojileri',
      academicYear: '2026-2027',
      isHomeroom: true,
    ));
    final sid = await StudentRepository().insertStudent(StudentModel(
      classId: classId,
      schoolNumber: 101,
      firstName: 'Işıl',
      lastName: 'Çağrı',
    ));
    student = StudentModel(
      id: sid,
      classId: classId,
      schoolNumber: 101,
      firstName: 'Işıl',
      lastName: 'Çağrı',
    );
  });

  Future<BepPlan> planKur() => repo.createPlan(
        student: student,
        classId: classId,
        subject: 'Bilişim Teknolojileri',
        subjectCode: 'BILISIM',
        gradeLevel: 5,
        teacherName: 'Ayşe DEMİR',
        principalName: 'Muğdat ŞIHOĞLU',
        isHomeroom: true,
        academicYear: '2026-2027',
      );

  /// İki uzun amaç, üç işaret.
  Future<BepPlan> isaretleriKur() async {
    final plan = await planKur();
    await repo.setCoarse(
      planId: plan.id!,
      unitTitle: 'Bilişim Teknolojilerini Kavrar',
      outcomeCode: 'BTY.5.1.1',
      outcomeDescription: 'Günlük yaşamdaki önemini bilir',
      studentFirstName: student.firstName,
      canDo: false,
      evaluatedBy: 'Ayşe DEMİR',
    );
    await repo.setCoarse(
      planId: plan.id!,
      unitTitle: 'Bilişim Teknolojilerini Kavrar',
      outcomeCode: 'BTY.5.1.2',
      outcomeDescription: 'Bilgisayar sistemlerini bilir',
      studentFirstName: student.firstName,
      canDo: true,
      evaluatedBy: 'Ayşe DEMİR',
    );
    await repo.setCoarse(
      planId: plan.id!,
      unitTitle: 'Problem Çözme ve Programlamayı Kavrar',
      outcomeCode: 'BTY.5.2.1',
      outcomeDescription: 'Programlamayı bilir',
      studentFirstName: student.firstName,
      canDo: false,
      evaluatedBy: 'Ayşe DEMİR',
    );
    return plan;
  }

  String duz(String h) => h.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<String> pdfMetni(BepPlan plan) async {
    final marks = await repo.coarseMarksForPlan(plan.id!);
    final kunye = await repo.coarseHeader(plan.id!);
    final t = DateTime.tryParse(kunye.tarih);
    String iki(int n) => n.toString().padLeft(2, '0');
    final tarih =
        t == null ? '' : '${iki(t.day)}.${iki(t.month)}.${t.year}';

    final b = await BepCoarsePdfGenerator.build(
      plan: plan,
      student: student,
      className: '5-A',
      schoolName: 'Şehit Öğretmen Ortaokulu',
      marks: marks,
      evaluatedAt: tarih,
      evaluatedBy: kunye.kisi,
    );
    final doc = PdfDocument(inputBytes: b);
    final metin = duz(PdfTextExtractor(doc).extractText());
    doc.dispose();
    return metin;
  }

  group('Kunye', () {
    test('KRITIK: ilk isarette tarih ve degerlendiren kaydedilir', () async {
      final plan = await isaretleriKur();
      final kunye = await repo.coarseHeader(plan.id!);

      expect(kunye.tarih, isNotEmpty, reason: 'tarih kaydedilmemiş');
      expect(kunye.kisi, 'Ayşe DEMİR', reason: 'değerlendiren kaydedilmemiş');
    });

    test('KRITIK: sonraki isaretler tarihi DEGISTIRMEZ', () async {
      // Form bir oturumda doldurulan bir belge; öğretmen otuz amacı
      // işaretlerken tarihin her tıkta ilerlemesi belgeyi yanıltıcı
      // kılardı.
      final plan = await isaretleriKur();
      final ilk = await repo.coarseHeader(plan.id!);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.setCoarse(
        planId: plan.id!,
        unitTitle: 'Etik ve Güvenliği Kavrar',
        outcomeCode: 'BTY.5.3.1',
        outcomeDescription: 'Etik değerleri bilir',
        studentFirstName: student.firstName,
        canDo: false,
        evaluatedBy: 'Başka Öğretmen',
      );

      final sonra = await repo.coarseHeader(plan.id!);
      expect(sonra.tarih, ilk.tarih, reason: 'tarih değişmiş');
      expect(sonra.kisi, 'Ayşe DEMİR', reason: 'değerlendiren değişmiş');
    });

    test('KRITIK: kunye belgeye basiliyor', () async {
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);

      expect(t.contains('Işıl'), isTrue, reason: 'öğrenci adı yok');
      expect(t.contains('101'), isTrue, reason: 'öğrenci numarası yok');
      expect(t.contains('5-A'), isTrue, reason: 'sınıf yok');
      expect(t.contains('Ayşe'), isTrue, reason: 'değerlendiren yok');
      expect(RegExp(r'\d{2}\.\d{2}\.\d{4}').hasMatch(t), isTrue,
          reason: 'değerlendirme tarihi yok');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Belge icerigi', () {
    test('KRITIK: uzun amac basligi altinda gruplaniyor', () async {
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);

      // ERBAA'daki düzen: her uzun amaç kendi tablosuyla.
      expect(t.contains('Bilişim Teknolojilerini Kavrar'), isTrue);
      expect(t.contains('Problem Çözme ve Programlamayı Kavrar'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: Yapiyor ve Yapamiyor ayri basiliyor', () async {
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);

      expect(t.contains('Yapıyor'), isTrue);
      expect(t.contains('Yapamıyor'), isTrue);
      // Üç işaretin ikisi "Yapamıyor"; özet bunu söylemeli.
      expect(t.contains('3 amaç değerlendirilmiş'), isTrue);
      expect(t.contains('2 amaç'), isTrue, reason: 'plana giren sayı yok');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: isaretlenmemis amac belgede YOK', () async {
      // Belge yalnızca değerlendirileni gösterir; işaretlenmemiş
      // kazanım formda yer almaz.
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);
      expect(t.contains('Etik değerleri bilir'), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: hic isaret yoksa liste BOS gelir', () async {
      // Ekran bu durumda belge üretmez; depo boş dönmeli.
      final plan = await planKur();
      final marks = await repo.coarseMarksForPlan(plan.id!);
      expect(marks, isEmpty);
    });
  });

  group('Resmi evrak niteligi', () {
    test('KRITIK: resmi kunye tam', () async {
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);

      expect(t.contains('T.C.'), isTrue);
      expect(t.contains('MİLLÎ EĞİTİM BAKANLIĞI'), isTrue);
      expect(t.contains('MÜDÜRLÜĞÜ'), isTrue);
      expect(t.contains('KABA DEĞERLENDİRME FORMU'), isTrue);
      expect(t.contains('2026-2027'), isTrue,
          reason: 'öğretim yılı sınıfın kaydından gelmiyor');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: imzada isim BASILMAZ', () async {
      // BEP raporunda aynı karar verilmişti: önceden basılmış bir ad,
      // kurul üyesi değiştiğinde belgeyi yanlış kılıyor.
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);

      expect(t.contains('Muğdat ŞIHOĞLU'), isFalse,
          reason: 'müdür adı imza bloğunda basılı');
      expect(t.contains('Okul Müdürü'), isTrue);
      expect(t.contains('Adı Soyadı / İmza'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: "Taslak" ve cekince ibaresi YOK', () async {
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);

      expect(t.contains('Taslak'), isFalse);
      expect(t.contains('TASLAK'), isFalse);
      expect(t.contains('yerine geçmez'), isFalse);
      expect(t.contains('değildir'), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: Turkce harfler basiliyor', () async {
      final plan = await isaretleriKur();
      final t = await pdfMetni(plan);

      final trHarf = t.split('').where((c) => 'ışğüöçİŞĞÜÖÇ'.contains(c));
      expect(trHarf.length, greaterThan(30),
          reason: 'Türkçe harfler kayıp: ${trHarf.length} adet');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
