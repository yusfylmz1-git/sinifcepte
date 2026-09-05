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

  test('BEP tarih aralığı okul takvimine göre', () {
    // Eskiden kaba bir sabitti: her yıl 01.09 - 31.05. Gerçek okul
    // ne 1 Eylül'de açılır ne 31 Mayıs'ta kapanır; belgeye yanlış
    // tarih giriyordu. Artık MEB hesabı kullanılıyor: eylülün ikinci
    // pazartesisi + 39 hafta.
    expect(
      BepPdfGenerator.planDateRange('2026-2027', 'Eylül'),
      '14.09.2026 - 11.06.2027',
    );
    // Dönem ortasında açılan plan: o ayın ilk iş günü, bitiş yine
    // öğretim yılının sonu.
    expect(
      BepPdfGenerator.planDateRange('2026-2027', 'Ocak'),
      '01.01.2027 - 11.06.2027',
    );
  });
}
