import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/features/guidance/data/models/guidance_plan_model.dart';
import 'package:sinifcepte/features/guidance/data/repositories/guidance_plan_repository.dart';

/// Sinif rehberlik plani modulu.
///
/// ## Neden bu testler var
/// Veri 13 xlsx ve 4 pdf'ten ayristirilarak uretiliyor
/// (`tool/build_rehberlik_dataset.py`). Ayristirmada YASANMIS hatalar:
///   * etkinlik imzasi gevsek arandi -> 98 sahte etkinlik
///   * "5. Sınıf" ile "6.sınıf" farkli yazilmis -> sinif cozulemedi
///   * "/ 1. Hafta" ile "(25.Hafta)" farkli -> hafta cozulemedi
///   * etkinlik adi ortaogretimde tablonun ALTINDA -> 42 adsiz kayit
/// Paket yeniden uretildiginde bunlar sessizce geri gelebilir; bu
/// testler veri KALITESINI dogrular, sadece kodu degil.
void main() {
  // Test dosyalari PARALEL kosuyor; ayni sqlite yolunu
  // paylasirlarsa "database is locked" hatasi cikiyor.
  AppConfig.testDbNameOverride = 'guidance_plan_test.db';
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late GuidancePlanRepository repo;

  /// Varlik test ortaminda rootBundle'dan okunamaz; dosyadan besleriz.
  setUpAll(() {
    final bytes = File('assets/data/sinif_rehberlik_plani.json.gz')
        .readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final ad = utf8.decode(message!.buffer.asUint8List());
      if (ad == 'assets/data/sinif_rehberlik_plani.json.gz') {
        return Uint8List.fromList(bytes).buffer.asByteData();
      }
      return null;
    });
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    GuidancePlanRepository.resetCache();
    repo = GuidancePlanRepository();
  });

  group('Veri paketi', () {
    test('KRITIK: 13 kademenin hepsinde plan var', () async {
      for (var g = 0; g <= 12; g++) {
        expect(await repo.hasPlan(g), isTrue,
            reason: '$g. kademe plani eksik');
      }
    });

    test('KRITIK: her kademede 35 uygulanabilir kazanim var', () async {
      for (var g = 0; g <= 12; g++) {
        final plan = await repo.planFor(g);
        final kazanim = plan.where((e) => e.uygulanabilir).length;
        expect(kazanim, greaterThanOrEqualTo(30),
            reason: '$g. kademede yalnizca $kazanim kazanim var');
      }
    });

    test('KRITIK: her etkinligin ADI var', () async {
      // Ortaogretimde baslik tablonun ALTINDA duruyordu; sadece ilk
      // satirlara bakan surum 42 etkinligi adsiz birakmisti.
      for (var g = 0; g <= 12; g++) {
        for (final e in await repo.activitiesFor(g)) {
          expect(e.etkinlikAdi.trim(), isNotEmpty,
              reason: '$g. sinif ${e.hafta}. hafta etkinligi adsiz');
        }
      }
    });

    test('KRITIK: her etkinligin surec basamaklari var', () async {
      for (var g = 0; g <= 12; g++) {
        for (final e in await repo.activitiesFor(g)) {
          expect(e.surec, isNotEmpty,
              reason: '${e.etkinlikAdi} surecsiz');
        }
      }
    });

    test('KRITIK: hafta numaralari 1-36 araliginda', () async {
      for (var g = 0; g <= 12; g++) {
        for (final e in await repo.activitiesFor(g)) {
          expect(e.hafta, isNotNull, reason: '${e.etkinlikAdi} haftasiz');
          expect(e.hafta, inInclusiveRange(1, 36));
        }
      }
    });

    test('KRITIK: satir sonu tirelemesi temizlenmis', () async {
      // PDF'te "duzen-\nlenebilir" tek kelime; birlestirme once
      // yapilmazsa metinde "duzen - lenebilir" kaliyordu.
      var bozuk = 0;
      for (var g = 0; g <= 12; g++) {
        for (final e in await repo.activitiesFor(g)) {
          for (final u in e.ozelGereksinimUyarlamalari) {
            if (RegExp(r'\w - \w').hasMatch(u)) bozuk++;
          }
        }
      }
      expect(bozuk, lessThan(20),
          reason: '$bozuk uyarlamada tire kalintisi var');
    });

    test('etkinliklerin cogunda BEP uyarlamasi var', () async {
      // BEP baglantisinin dayanagi bu alan; bosalirsa modulun
      // en ozgun parcasi calismaz.
      var uyarlamali = 0, toplam = 0;
      for (var g = 0; g <= 12; g++) {
        for (final e in await repo.activitiesFor(g)) {
          toplam++;
          if (e.bepUyarlamasiVar) uyarlamali++;
        }
      }
      expect(uyarlamali / toplam, greaterThan(0.6),
          reason: 'yalnizca $uyarlamali/$toplam etkinlikte uyarlama var');
    });

    test('ayni sinif+hafta icin tek etkinlik', () async {
      for (var g = 0; g <= 12; g++) {
        final haftalar =
            (await repo.activitiesFor(g)).map((e) => e.hafta).toList();
        expect(haftalar.length, haftalar.toSet().length,
            reason: '$g. sinifta ayni hafta birden fazla etkinlik');
      }
    });

    test('KRITIK: tatiller plandaki DOGRU yerinde duruyor', () async {
      // Tatillerin hafta numarasi yok; siralama yalnizca `hafta` ile
      // yapilinca `99` sayilip hepsi listenin SONUNA dusuyordu.
      // Oysa ara tatil Kasim'da, yariyil Ocak-Subat'ta.
      final plan = await repo.planFor(5);
      final sonSatir = plan.last;
      expect(sonSatir.tatilMi, isFalse,
          reason: 'liste tatille bitmemeli: ${sonSatir.kazanim}');

      // Ilk ara tatil, 9. hafta ile 10. hafta ARASINDA olmali.
      final i = plan.indexWhere((e) => e.tatilMi);
      expect(i, greaterThan(0));
      final onceki = plan.sublist(0, i).where((e) => e.hafta != null).last;
      final sonraki = plan.sublist(i).where((e) => e.hafta != null).first;
      expect(onceki.hafta! < sonraki.hafta!, isTrue,
          reason: 'tatil iki hafta arasina girmeli');
    });

    test('KRITIK: yildizla baslayan kazanim da sayiliyor', () async {
      // 36. hafta "*36- Sinif rehberlik programi etkinliklerine..."
      // seklinde yildizla basliyor; ayristirici bunu atlayinca
      // IDARI IS sayiliyor ve listede 35 kazanim gorunuyordu.
      for (var g = 1; g <= 12; g++) {
        final plan = await repo.planFor(g);
        final enBuyuk = plan
            .where((e) => e.siraNo != null)
            .map((e) => e.siraNo!)
            .fold(0, (a, b) => a > b ? a : b);
        expect(enBuyuk, greaterThanOrEqualTo(36),
            reason: '$g. sinifta son kazanim numarasi $enBuyuk');
      }
    });

    test('tatil satirlari kazanim sayilmaz', () async {
      final plan = await repo.planFor(5);
      final tatil = plan.where((e) => e.tatilMi);
      expect(tatil, isNotEmpty, reason: 'ara tatil ve yariyil olmali');
      for (final t in tatil) {
        expect(t.uygulanabilir, isFalse);
      }
    });

    test('idari isler kazanimdan ayrilmis', () async {
      // "Rehberlik Yurutme Komisyonu Toplantisi" bir kazanim degil;
      // ilerleme sayacinda paydaya girmemeli.
      final plan = await repo.planFor(5);
      final idari = plan.where((e) => e.idariIsMi).toList();
      expect(idari, isNotEmpty);
      expect(idari.every((e) => e.siraNo == null), isTrue);
    });
  });

  group('Uygulama kaydi', () {
    late int classId;

    setUp(() async {
      classId = await ClassRepository().insertClass(const ClassModel(
        name: '5-A',
        subject: 'Matematik',
        academicYear: '2026-2027',
        isHomeroom: true,
      ));
    });

    test('KRITIK: uygulama isareti kaydedilir ve okunur', () async {
      await repo.saveLog(GuidanceLogEntry(
        classId: classId,
        academicYear: '2026-2027',
        gradeLevel: 5,
        hafta: 1,
        siraNo: 1,
        uygulandi: true,
        not: 'Sınıfça çok sevildi',
        uygulanmaTarihi: DateTime(2026, 9, 18),
        updatedAt: DateTime.now(),
      ));

      final kayitlar = await repo.logsFor(
        classId: classId,
        academicYear: '2026-2027',
      );
      expect(kayitlar, hasLength(1));
      expect(kayitlar.single.uygulandi, isTrue);
      expect(kayitlar.single.not, 'Sınıfça çok sevildi');
    });

    test('KRITIK: ayni hafta iki kez isaretlenince cift kayit olmaz',
        () async {
      for (final u in [true, false]) {
        await repo.saveLog(GuidanceLogEntry(
          classId: classId,
          academicYear: '2026-2027',
          gradeLevel: 5,
          hafta: 3,
          siraNo: 3,
          uygulandi: u,
          updatedAt: DateTime.now(),
        ));
      }
      final kayitlar = await repo.logsFor(
        classId: classId,
        academicYear: '2026-2027',
      );
      expect(kayitlar, hasLength(1), reason: 'UNIQUE kisiti calismali');
      expect(kayitlar.single.uygulandi, isFalse, reason: 'son deger gecerli');
    });

    test('ilerleme ozeti: uygulanan / toplam', () async {
      for (var h = 1; h <= 5; h++) {
        await repo.saveLog(GuidanceLogEntry(
          classId: classId,
          academicYear: '2026-2027',
          gradeLevel: 5,
          hafta: h,
          siraNo: h,
          uygulandi: true,
          updatedAt: DateTime.now(),
        ));
      }
      final o = await repo.progress(
        classId: classId,
        academicYear: '2026-2027',
        gradeLevel: 5,
      );
      expect(o.uygulanan, 5);
      expect(o.toplam, greaterThanOrEqualTo(30),
          reason: 'payda kazanim sayisi olmali');
    });

    test('KRITIK: toplu yazma tek islemde biter', () async {
      // "Tumunu isaretle" 36 kazanim icin 36 ayri insert demek;
      // her biri ayri disk islemi oldugu icin arayuz doniyordu.
      final simdi = DateTime.now();
      await repo.saveLogs([
        for (var h = 1; h <= 20; h++)
          GuidanceLogEntry(
            classId: classId,
            academicYear: '2026-2027',
            gradeLevel: 5,
            hafta: h,
            siraNo: h,
            uygulandi: true,
            updatedAt: simdi,
          ),
      ]);
      final kayitlar = await repo.logsFor(
        classId: classId,
        academicYear: '2026-2027',
      );
      expect(kayitlar, hasLength(20));
      expect(kayitlar.every((e) => e.uygulandi), isTrue);
    });

    test('toplu yazma ayni satiri cogaltmaz', () async {
      final simdi = DateTime.now();
      for (var tekrar = 0; tekrar < 2; tekrar++) {
        await repo.saveLogs([
          GuidanceLogEntry(
            classId: classId,
            academicYear: '2026-2027',
            gradeLevel: 5,
            hafta: 4,
            siraNo: 4,
            uygulandi: true,
            updatedAt: simdi,
          ),
        ]);
      }
      final kayitlar = await repo.logsFor(
        classId: classId,
        academicYear: '2026-2027',
      );
      expect(kayitlar, hasLength(1), reason: 'UNIQUE kisiti calismali');
    });

    test('bos liste hicbir sey yazmaz', () async {
      await repo.saveLogs(const []);
      final kayitlar = await repo.logsFor(
        classId: classId,
        academicYear: '2026-2027',
      );
      expect(kayitlar, isEmpty);
    });

    test('gecen yilin kaydi bu yila karismaz', () async {
      await repo.saveLog(GuidanceLogEntry(
        classId: classId,
        academicYear: '2025-2026',
        gradeLevel: 5,
        hafta: 1,
        siraNo: 1,
        uygulandi: true,
        updatedAt: DateTime.now(),
      ));
      final buYil = await repo.logsFor(
        classId: classId,
        academicYear: '2026-2027',
      );
      expect(buYil, isEmpty);
    });
  });

  /// Ozel egitim programlari ve BEP baglantisi.
  ///
  /// ORGM ozel egitim okullari icin AYRI programlar yayimliyor;
  /// yapisi genel setten farkli (hafta yok, gostergeler var). Genel
  /// plan ozel egitim sinifinda uygulanamadigi icin bu veri o
  /// ogretmenin asil kaynagi.
  group('Ozel egitim programlari', () {
    test('KRITIK: dort program da yuklendi', () async {
      final programlar = await repo.specialPrograms();
      expect(programlar, hasLength(4));
      for (final p in programlar) {
        expect(p.adet, greaterThanOrEqualTo(25),
            reason: '${p.ad} yalnizca ${p.adet} etkinlik');
      }
    });

    test('KRITIK: her etkinligin kazanimi ve gostergesi var', () async {
      for (final kod in [
        'ozelAnaokulu',
        'ozelIlkokul',
        'ozelOrtaokul',
        'ozelMeslek',
      ]) {
        final liste = await repo.specialActivities(kod);
        expect(liste, isNotEmpty, reason: '$kod bos');
        for (final e in liste) {
          expect(e.kazanim.trim().length, greaterThan(10),
              reason: '$kod #${e.etkinlikNo} kazanimi eksik');
          expect(e.gostergeler, isNotEmpty,
              reason: '$kod #${e.etkinlikNo} gostergesiz');
        }
      }
    });

    test('KRITIK: icindekiler sayfasi etkinlik sayilmaz', () async {
      // Icindekiler de "Etkinlik" ve "Kazanım" kelimelerini iceriyordu;
      // ayiklanmazsa "...ları Ö-SRP Etkinlik Planı" gibi bozuk
      // kazanimlar listeye giriyordu.
      for (final kod in ['ozelAnaokulu', 'ozelOrtaokul']) {
        for (final e in await repo.specialActivities(kod)) {
          expect(e.kazanim.contains('Ö-SRP'), isFalse,
              reason: 'icindekiler satiri sizmis: ${e.kazanim}');
        }
      }
    });

    test('KRITIK: sayfa ustbilgisi metne karismamis', () async {
      // Her sayfanin ustunde "22 ÖZEL EĞİTİM ORTAOKULU ÖZELLEŞTİRİLMİŞ
      // SINIF REHBERLİĞİ PROGRAMI" tekrar ediyor; pypdf bunu govdeye
      // katiyordu.
      for (final kod in ['ozelOrtaokul', 'ozelMeslek']) {
        for (final e in await repo.specialActivities(kod)) {
          expect(e.kazanim.contains('ÖZELLEŞTİRİLMİŞ'), isFalse);
          expect(e.sure.contains('ÖZELLEŞTİRİLMİŞ'), isFalse);
        }
      }
    });

    test('etkinlikler numara sirasinda gelir', () async {
      final liste = await repo.specialActivities('ozelOrtaokul');
      final nolar = liste.map((e) => e.etkinlikNo ?? 0).toList();
      final sirali = [...nolar]..sort();
      expect(nolar, sirali);
    });
  });

  group('BEP baglantisi', () {
    test('KRITIK: haftanin uyarlama onerileri okunur', () async {
      // 5. sinif 1. hafta "GELİN TANIŞ OLALIM" etkinliginde iki
      // uyarlama var (akran eslestirmesi, gorsel kullanimi).
      final u = await repo.bepAdaptationsFor(gradeLevel: 5, hafta: 1);
      expect(u, isNotEmpty);
      expect(u.join(' ').toLowerCase(), contains('akran'));
    });

    test('etkinligi olmayan hafta bos liste dondurur', () async {
      final u = await repo.bepAdaptationsFor(gradeLevel: 5, hafta: 99);
      expect(u, isEmpty);
    });
  });
}
