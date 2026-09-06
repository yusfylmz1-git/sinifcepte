import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/documents/data/teacher_file_model.dart';
import 'package:sinifcepte/features/documents/utils/teacher_file_pdf_generator.dart';

/// Gözle bakmak için PDF üretir — doğrulama testi değil.
///
/// `flutter test test/ogretmen_dosyasi_gorsel_test.dart` çalıştırıp
/// yazdığı yoldan açılır. Düzen kararları (silüet, sütun genişliği)
/// metinle ölçülemiyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final f = File(utf8.decode(message!.buffer.asUint8List()));
      return f.existsSync()
          ? Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData()
          : null;
    });
  });

  test('gorsel: tum dosya uret', () async {
    const teacher = TeacherProfileModel(
      id: 't1',
      firstName: 'Ayşe',
      lastName: 'Çağrıöz',
      branch: 'Bilişim Teknolojileri',
      schoolName: 'Şehit Öğretmen İlkokulu',
      schoolPrincipalName: 'Muğdat ŞIHOĞLU',
      email: 'ayse@example.com',
    );

    final bytes = await TeacherFilePdfGenerator.tumDosya(
      teacher: teacher,
      bilgi: const TeacherFileInfo(
        nationalId: '12345678901',
        registryNo: '987654',
        graduation: 'Gazi Üniversitesi / BÖTE',
        startedDutyAt: '15.09.2015',
        startedSchoolAt: '01.09.2022',
        title: 'Bilişim Teknolojileri Öğretmeni',
        employmentType: 'Kadrolu',
        phone: '05001234567',
        bloodType: '0 Rh+',
      ),
      dersler: const [
        TeacherFileLesson(
            ders: 'Bilişim Teknolojileri',
            sinif: '5-A',
            gun: 'Pazartesi',
            saat: 0),
        TeacherFileLesson(
            ders: 'Bilişim Teknolojileri', sinif: '6-B', gun: 'Salı', saat: 2),
        TeacherFileLesson(
            ders: 'Kodlama', sinif: '7-C', gun: 'Cuma', saat: 5),
      ],
      siniflar: const [
        TeacherFileClass(
            ad: '5-A', ders: 'Bilişim Teknolojileri', ogrenciSayisi: 24),
        TeacherFileClass(
            ad: '6-B', ders: 'Bilişim Teknolojileri', ogrenciSayisi: 28),
      ],
      academicYear: '2026-2027',
    );

    final cikti = File('build/ogretmen_dosyasi_ornek.pdf');
    cikti.parent.createSync(recursive: true);
    cikti.writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('PDF: ${cikti.absolute.path} (${bytes.length ~/ 1024} KB)');

    expect(bytes.length, greaterThan(1000));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
