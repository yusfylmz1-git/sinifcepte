import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/classes/presentation/widgets/counseling_interview_modal.dart';
import 'package:sinifcepte/features/guidance/utils/sinif_risk_haritasi_pdf.dart';

/// Sınıf risk haritası (29 Ekim 2026).
///
/// Kullanıcı: "Formlara risk raporu eklenmeli (indirilenlerde örnek var,
/// sınıf risk haritası)." Sınıf rehber öğretmeni sınıfının risk haritasını
/// oluşturur ve kasımda bir örneğini rehberlik servisine verir. Uygulama
/// adları yazar; işaretler kâğıtta konur, risk bilgisi saklanmaz.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sinif = ClassModel(id: 1, name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true);
  const ogretmen = TeacherProfileModel(
    id: 'ogretmen',
    firstName: 'Ayşe',
    lastName: 'Demir',
    branch: 'Türkçe',
    schoolName: 'Mimar Sinan Ortaokulu',
    schoolPrincipalName: 'Mehmet Yılmaz',
    email: 'ayse@meb.k12.tr',
  );
  List<StudentModel> ogrenciler(int n) => [
        for (var i = 0; i < n; i++)
          StudentModel(id: i + 1, classId: 1, schoolNumber: 10 + i, firstName: 'Öğrenci$i', lastName: 'KAYA'),
      ];

  test('KRITIK: resmî formdaki 35 risk alanı, aynı sırayla', () {
    expect(sinifRiskAlanlari, hasLength(35));
    expect(sinifRiskAlanlari.first, 'Anne en fazla ilkokul mezunu');
    expect(sinifRiskAlanlari[11], 'Şehit çocuğu');
    expect(sinifRiskAlanlari[30], 'Sürekli devamsız olan');
    expect(sinifRiskAlanlari.last, 'Diğer', reason: 'gözlemle belirlenenler buraya');
    expect(sinifRiskAlanlari.toSet(), hasLength(35), reason: 'tekrar yok');
  });

  test('KRITIK: PDF üretiliyor; kalabalık sınıf birden çok sayfaya taşıyor', () async {
    final az = await SinifRiskHaritasiPdf.olustur(
        classModel: sinif, students: ogrenciler(5), teacherProfile: ogretmen, tarih: DateTime(2026, 11, 3));
    final cok = await SinifRiskHaritasiPdf.olustur(
        classModel: sinif, students: ogrenciler(40), teacherProfile: ogretmen, tarih: DateTime(2026, 11, 3));
    expect(latin1.decode(az.sublist(0, 4)), '%PDF');
    expect(cok.length, greaterThan(az.length));
  });

  test('sınıf yokken de (boş liste) belge çıkıyor', () async {
    final b = await SinifRiskHaritasiPdf.olustur(classModel: sinif, students: const [], teacherProfile: ogretmen);
    expect(latin1.decode(b.sublist(0, 4)), '%PDF');
  });

  testWidgets('KRITIK: form merkezinde sınıf belgesi; öğrenci seçimi yok, gizlilik notu var', (tester) async {
    final yukleyici = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await yukleyici.load();
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CounselingInterviewModal(classModel: sinif, students: ogrenciler(3), teacherProfile: ogretmen),
      ),
    ));
    expect(find.byKey(const ValueKey('gorusme_ogrenci_sec')), findsOneWidget, reason: 'veli görüşmede seçilir');

    await tester.tap(find.text('Sınıf Risk Haritası'));
    await tester.pump();
    expect(find.byKey(const ValueKey('gorusme_ogrenci_sec')), findsNothing);
    expect(find.byKey(const ValueKey('risk_haritasi_notu')), findsOneWidget);
    expect(find.textContaining('3 öğrenci'), findsOneWidget);
    expect(find.textContaining('saklamaz'), findsOneWidget);
  });
}
