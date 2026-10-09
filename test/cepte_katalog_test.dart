import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/assistant/data/cepte_arama.dart';
import 'package:sinifcepte/features/assistant/data/cepte_katalog.dart';
import 'package:sinifcepte/features/assistant/data/cepte_niyet.dart';
import 'package:sinifcepte/features/assistant/providers/cepte_provider.dart';

/// Cepte kataloğu: uygulamadaki her şey aranabiliyor mu?
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'cepte_katalog_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('bütünlük', () {
    test('KRITIK: sınıf seçmeden açılan her ekran aramada var', () {
      // Sınıfa bağlı eski niyetler her sınıf için ayrı sonuç olarak çıkıyor.
      const sinifaBagli = {
        CepteEkran.veliPaneli,
        CepteEkran.devamsizlik,
        CepteEkran.oturmaPlani,
        CepteEkran.nobetciListesi,
        CepteEkran.ogrenciListesi,
        CepteEkran.ogretmenKadrosu,
      };
      final katalogda = {
        for (final h in cepteEkranHedefleri())
          if (h.eylem case EkranEylemi(:final ekran)) ekran,
      };
      expect(katalogda, containsAll(CepteEkran.values.where((e) => !sinifaBagli.contains(e))));
    });

    test('her sınıf için her sınıf ekranı, kimlikler tekil', () {
      final h = cepteSinifHedefleri([
        (id: 1, ad: '5-A', ders: 'Türkçe'),
        (id: 2, ad: '6-B', ders: 'Matematik'),
      ]);
      expect(h.length, 2 * CepteSinifEkrani.values.length);
      final statik = cepteEkranHedefleri();
      final idler = [...h, ...statik].map((e) => e.id).toList();
      expect(idler.toSet().length, idler.length);
    });

    test('her ekranın en az üç anahtar sözü var (öğretmenin sözleri)', () {
      for (final h in cepteEkranHedefleri()) {
        expect(h.anahtarlar.length, greaterThanOrEqualTo(3), reason: h.baslik);
        expect(h.yol, isNotEmpty, reason: '${h.baslik}: nerede olduğu yazmalı');
      }
    });

    test('açıcı her eylemi karşılıyor', () {
      final kaynak = File('lib/features/assistant/presentation/cepte_hedef_acici.dart').readAsStringSync();
      for (final t in ['EkranEylemi', 'SinifEkraniEylemi', 'OgrenciEylemi', 'BelirliGunEylemi',
        'KulupEylemi', 'KazanimEylemi', 'PlanEylemi']) {
        expect(kaynak, contains('case $t('), reason: t);
      }
    });
  });

  group('gerçek veri', () {
    late ProviderContainer kap;
    late List<CepteHedef> katalog;

    setUpAll(() async {
      await DatabaseHelper.instance.resetForTests();
      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();
      final sinif = await ClassRepository().insertClass(
          const ClassModel(name: '5-A', subject: 'Türkçe', academicYear: '2026-2027'));
      await StudentRepository().insertStudent(
          StudentModel(classId: sinif, schoolNumber: 7, firstName: 'Ali', lastName: 'YILMAZ'));
      kap = ProviderContainer();
      katalog = await kap.read(cepteKatalogProvider.future);
    });

    tearDownAll(() => kap.dispose());

    List<CepteHedef> ara(String q) => cepteAra(q, katalog).map((s) => s.hedef).toList();

    test('KRITIK: belirli günler ve kulüpler gerçek dosyalardan geliyor', () {
      final gunler = katalog.where((h) => h.kategori == CepteKategori.belirliGun).length;
      final kulupler = katalog.where((h) => h.kategori == CepteKategori.kulup).length;
      expect(gunler, greaterThanOrEqualTo(50), reason: 'MEB çizelgesi 61 madde');
      expect(kulupler, greaterThanOrEqualTo(50), reason: 'EK-4 çizelgesi 52 kulüp');
    });

    test('KRITIK: "23 nisan" o günü, "kızılay" hem haftayı hem kulübü buluyor', () {
      expect(ara('23 nisan').first.kategori, CepteKategori.belirliGun);
      final k = ara('kızılay').map((h) => h.kategori).toSet();
      expect(k, containsAll([CepteKategori.belirliGun, CepteKategori.kulup]));
    });

    test('öğretmenin sınıfı, öğrencisi ve dersinin planı', () {
      expect(ara('oturma 5a').first.id, startsWith('sinif:oturmaPlani:'));
      expect(ara('ali').first.kategori, CepteKategori.ogrenci);
      expect(ara('5 türkçe yıllık').first.id, startsWith('yillik:5:'));
    });

    test('her arama hızlı (yazarken çalışıyor)', () {
      final s = Stopwatch()..start();
      for (final q in ['k', 'kr', 'kro', 'krok', 'kroki', '23 n', 'veli top', 'a']) {
        ara(q);
      }
      expect(s.elapsedMilliseconds, lessThan(400), reason: '${katalog.length} kayıt');
    });
  });
}
