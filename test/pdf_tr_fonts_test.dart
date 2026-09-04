import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/pdf/pdf_tr_fonts.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/bep/data/models/bep_models.dart';
import 'package:sinifcepte/features/bep/utils/bep_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gömülü Noto Sans yüklenir', () async {
    final fonts = await PdfTrFonts.load();
    expect(fonts.regular, isNotNull);
    expect(fonts.bold, isNotNull);
  });

  test('BEP PDF Türkçe başlıklarla üretilir', () async {
    final now = DateTime(2026, 9, 1);
    final bytes = await BepPdfGenerator.build(
      plan: BepPlan(
        studentId: 1,
        classId: 1,
        academicYear: '2026-2027',
        subject: 'Matematik',
        subjectCode: 'MAT',
        gradeLevel: 5,
        createdAt: now,
        updatedAt: now,
      ),
      student: const StudentModel(
        classId: 1,
        schoolNumber: 12,
        firstName: 'Ahmet',
        lastName: 'Yılmaz',
      ),
      className: '5-A',
      schoolName: 'Örnek Ortaokulu',
      teacherName: 'Ayşe Öğretmen',
      principalName: 'Mehmet Müdür',
      goals: const [],
    );
    expect(bytes.length, greaterThan(2000));
  });

  test('BEP tarih aralığı öğretim yılına göre', () {
    expect(
      BepPdfGenerator.planDateRange('2026-2027', 'Eylül'),
      '01.09.2026 - 31.05.2027',
    );
    expect(
      BepPdfGenerator.planDateRange('2026-2027', 'Ocak'),
      '01.01.2027 - 31.05.2027',
    );
  });
}
