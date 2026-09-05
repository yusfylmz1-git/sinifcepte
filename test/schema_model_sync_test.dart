import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';

/// Sema ile model uyumu.
///
/// ## Neden bu test var
/// Kullanici sinifa ogrenci ekleyemedi:
///   "table classes has no column named is_homeroom"
///
/// Model `is_homeroom` yaziyordu ama sema sutunu icermiyordu. Mevcut
/// testler bunu KACIRDI cunku hepsi semayi sifirdan kuruyor ve model ile
/// sema ayni anda bozuldugunda tutarli gorunuyorlardi.
///
/// Buradaki testler modelin URETTIGI haritayi gercek tabloya yazar:
/// model bir alan eklerse ve sema guncellenmezse test kirmizi doner.
void main() {
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'schema_model_sync_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
  });

  group('classes tablosu', () {
    test('KRITIK: modelin yazdigi her sutun semada vardir', () async {
      final db = await DatabaseHelper.instance.database;

      const model = ClassModel(
        name: '5-D',
        subject: 'Genel Ders',
        academicYear: '2026-2027',
        isHomeroom: true,
      );

      // Hata tam olarak burada patliyordu.
      final id = await db.insert('classes', model.toMap());
      expect(id, greaterThan(0));
    });

    test('KRITIK: rehberlik sinifi kaydedilip geri okunur', () async {
      final repo = ClassRepository();

      await repo.insertClass(const ClassModel(
        name: '5-A',
        subject: 'Genel Ders',
        academicYear: '2026-2027',
        isHomeroom: true,
      ));

      final homeroom = await repo.getHomeroomClass();
      expect(homeroom, isNotNull);
      expect(homeroom!.isHomeroom, isTrue);
      expect(homeroom.name, '5-A');
    });

    test('KRITIK: coklu sinif dagitimi calisir (e-Okul ice aktarma)', () async {
      // Kullanicinin ekraninda 13 sube vardi; hepsi tek tek olusturulur.
      final repo = ClassRepository();
      const subeler = ['5-D', '5-A', '6-B', '6-A', '7-C', '7-B', '6-C'];

      for (final ad in subeler) {
        await repo.insertClass(ClassModel(
          name: ad,
          subject: 'Genel Ders',
          academicYear: '2026-2027',
        ));
      }

      final hepsi = await repo.getAllClasses();
      expect(hepsi.length, subeler.length);
    });

    test('Tek rehberlik sinifi kurali korunur', () async {
      final repo = ClassRepository();

      await repo.insertClass(const ClassModel(
        name: '5-A',
        subject: 'Genel',
        academicYear: '2026-2027',
        isHomeroom: true,
      ));
      await repo.insertClass(const ClassModel(
        name: '6-B',
        subject: 'Genel',
        academicYear: '2026-2027',
        isHomeroom: true,
      ));

      final hepsi = await repo.getAllClasses();
      final rehberlikler = hepsi.where((c) => c.isHomeroom).toList();
      expect(rehberlikler.length, 1);
      expect(rehberlikler.single.name, '6-B');
    });
  });

  group('students tablosu', () {
    test('KRITIK: modelin yazdigi her sutun semada vardir', () async {
      final db = await DatabaseHelper.instance.database;

      final classId = await db.insert('classes', const ClassModel(
        name: '5-D',
        subject: 'Genel',
        academicYear: '2026-2027',
      ).toMap());

      const student = StudentModel(
        classId: 1,
        schoolNumber: 101,
        firstName: 'Ali',
        lastName: 'Veli',
        gender: 'Erkek',
        parentName: 'Fatma Veli',
        parentPhone: '05321234567',
        notes: 'Test notu',
      );

      final id = await db.insert(
        'students',
        student.copyWith(classId: classId).toMap(),
      );
      expect(id, greaterThan(0));
    });
  });
}
