import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/attendance/data/repositories/arti_eksi_repository.dart';
import 'package:sinifcepte/features/attendance/data/repositories/classroom_participation_repository.dart';
import 'package:sinifcepte/features/attendance/utils/participation_cumulative_pdf_generator.dart';

/// Artı-eksi listesi dönem sonu PDF'lerinde (kullanıcı: "dönem sonu
/// PDF'lerinde olması önemli", 9 Ekim 2026). Metin PDF'ten bağımsız bir
/// okuyucuyla (syncfusion) çıkarılıyor; üreticinin kendi verisine bakılmıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'arti_eksi_rapor_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late int sinifId;
  late int ali;
  late int ayse;
  final artiEksi = ArtiEksiRepository();
  final rapor = ClassroomParticipationRepository();

  String duz(String ham) => ham.replaceAll(RegExp(r'\s+'), ' ').trim();

  String metin(Uint8List b) {
    final doc = PdfDocument(inputBytes: b);
    final t = duz(PdfTextExtractor(doc).extractText());
    doc.dispose();
    return t;
  }

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    sinifId = await ClassRepository().insertClass(
        const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027'));
    ali = await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 7, firstName: 'Ali', lastName: 'YILMAZ'));
    ayse = await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 3, firstName: 'Ayşe', lastName: 'KAYA'));

    Future<void> ver(int ogr, int deger, String tarih) =>
        artiEksi.ekle(classId: sinifId, studentId: ogr, deger: deger, tarih: tarih);
    await ver(ali, 1, '2026-10-09');
    await ver(ali, 1, '2026-10-16');
    await ver(ali, -1, '2026-11-02');
    await ver(ali, 1, '2027-03-01'); // 2. dönem
    await ver(ayse, -1, '2026-10-09');
  });

  Map<String, dynamic> ogrenci(Map<String, dynamic> r, int id) =>
      (r['students'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['studentId'] == id);

  group('rapor verisi', () {
    test('KRITIK: öğrenci başına artı ve eksi, dönem aralığıyla süzülüyor', () async {
      final r = await rapor.getClassCumulativeReportData(sinifId,
          startDate: '2026-08-01', endDate: '2027-01-31');
      expect((ogrenci(r, ali)['plusCount'], ogrenci(r, ali)['minusCount']), (2, 1),
          reason: '2. dönemdeki artı 1. dönem raporuna girmez');
      expect((ogrenci(r, ayse)['plusCount'], ogrenci(r, ayse)['minusCount']), (0, 1));
      expect((r['classTotalPlus'], r['classTotalMinus']), (2, 2));
    });

    test('yalnız bitiş tarihi (veli toplantısı) ve süzgeçsiz', () async {
      final toplanti = await rapor.getClassCumulativeReportData(sinifId, endDate: '2026-10-31');
      expect((ogrenci(toplanti, ali)['plusCount'], ogrenci(toplanti, ali)['minusCount']), (2, 0));
      final hepsi = await rapor.getClassCumulativeReportData(sinifId);
      expect(ogrenci(hepsi, ali)['plusCount'], 3);
    });

    test('artı-eksisi olmayan sınıfta sıfır, hata değil', () async {
      final bos = await ClassRepository().insertClass(
          const ClassModel(name: '6-B', subject: 'Türkçe', academicYear: '2026-2027'));
      await StudentRepository().insertStudent(
          StudentModel(classId: bos, schoolNumber: 1, firstName: 'Can', lastName: 'ER'));
      final r = await rapor.getClassCumulativeReportData(bos);
      expect((r['classTotalPlus'], r['classTotalMinus']), (0, 0));
      expect((r['students'] as List).single['plusCount'], 0);
    });
  });

  group('PDF', () {
    late Map<String, dynamic> veri;
    setUp(() async {
      veri = await rapor.getClassCumulativeReportData(sinifId,
          startDate: '2026-08-01', endDate: '2027-01-31');
    });

    test('KRITIK: idareye verilen dönem sonu çizelgesinde sütun ve sınıf toplamı', () async {
      final t = metin(await ParticipationCumulativePdfGenerator.generateOfficialAdministrativePdf(
        reportData: veri,
        teacherName: 'Ayşe DEMİR',
        termName: '2026-2027 1. Dönem',
      ));
      expect(t, contains('Artı / Eksi'));
      expect(t, contains('+2 / -1'), reason: 'Ali');
      expect(t, contains('+0 / -1'), reason: 'Ayşe');
      expect(t, contains('Artı-Eksi Listesi: 2 artı / 2 eksi'));
    });

    test('KRITIK: veli toplantısı kılavuzunda sütun', () async {
      final t = metin(await ParticipationCumulativePdfGenerator.generateParentMeetingGuidePdf(
        reportData: veri,
        teacherName: 'Ayşe DEMİR',
      ));
      expect(t, contains('Artı / Eksi'));
      expect(t, contains('+2 / -1'));
    });

    test('KRITIK: bireysel öğrenci kartında', () async {
      final t = metin(await ParticipationCumulativePdfGenerator.generateIndividualStudentCardPdf(
        studentData: ogrenci(veri, ali),
        className: '5-A',
        subjectName: 'Türkçe',
        teacherName: 'Ayşe DEMİR',
      ));
      expect(t, contains('Artı-Eksi Listesi: 2 artı / 1 eksi'));
    });
  });
}
