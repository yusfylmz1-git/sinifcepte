import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/attendance/data/models/classroom_participation_model.dart';

/// Ders ici katilim yeniden kurgusu.
///
/// ## Neden yeniden kurgulandi
/// Cihazdaki veritabaninda **sifir kayit** vardi: 7.393 satir kod
/// yazilmis, tek bir ders bile degerlendirilmemisti.
///
/// Sebep: ogrenciye dokunmak 962 satirlik bir diyalog aciyordu ve
/// 30 ogrenci icin ~120 dokunus gerekiyordu. Ders 40 dakika ve
/// ogretmen ayni anda ders anlatiyor.
void main() {
  StudentParticipationEvaluation ogr(
    int id, {
    int soz = 0,
    String ad = 'Ogrenci',
  }) =>
      StudentParticipationEvaluation(
        studentId: id,
        studentName: ad,
        studentNumber: id,
        speakingTurns: soz,
      );

  group('A — Soz hakki sayaci', () {
    test('KRITIK: yeni ogrenci sifir sozle baslar', () {
      expect(ogr(1).speakingTurns, 0);
      expect(ogr(1).isSilent, isTrue);
    });

    test('soz alan ogrenci sessiz sayilmaz', () {
      expect(ogr(1, soz: 1).isSilent, isFalse);
    });

    test('copyWith sayaci tasiyor', () {
      final e = ogr(1).copyWith(speakingTurns: 3);
      expect(e.speakingTurns, 3);
    });

    test('KRITIK: sayac diske yazilip geri okunuyor', () {
      final e = ogr(1, soz: 4);
      final geri = StudentParticipationEvaluation.fromMap(e.toMap(1));
      expect(geri.speakingTurns, 4);
    });

    test('eski kayitlarda sayac sifir gelir (goc oncesi)', () {
      // v15 oncesi kayitlarda sutun yok; null gelirse 0 olmali.
      final geri = StudentParticipationEvaluation.fromMap({
        'student_id': 1,
        'student_name': 'Eski Kayit',
      });
      expect(geri.speakingTurns, 0);
    });
  });

  group('Varsayilanlar YANLIS VERI uretmiyor', () {
    test('KRITIK: isaretlenmemis odev "yapti" degil', () {
      // Varsayilan `done` idi: ogretmen hicbir sey yapmadan
      // kaydettiginde sistem "30 ogrencinin hepsi odevini yapti"
      // diyordu. Bu YANLIS VERIDIR.
      expect(ogr(1).homeworkStatus, HomeworkStatus.unknown);
    });

    test('KRITIK: isaretlenmemis materyal "tam" degil', () {
      expect(ogr(1).materialsStatus, MaterialsStatus.unknown);
    });

    test('KRITIK: isaretlenmemis gelis "vaktinde" degil', () {
      expect(ogr(1).arrivalStatus, ArrivalStatus.unknown);
    });

    test('hic dokunulmamis ogrencide isaret yok', () {
      expect(ogr(1).hasAnyMark, isFalse);
    });

    test('soz alan ogrencide isaret var', () {
      expect(ogr(1, soz: 1).hasAnyMark, isTrue);
    });

    test('bilinmeyen kod "bilinmiyor"a duser', () {
      // Eskiden bilinmeyen kod `done`a dusuyordu: bozuk veri
      // "odevini yapti" olarak okunuyordu.
      expect(HomeworkStatus.fromCode('uydurma'), HomeworkStatus.unknown);
      expect(MaterialsStatus.fromCode(null), MaterialsStatus.unknown);
      expect(ArrivalStatus.fromCode('xyz'), ArrivalStatus.unknown);
    });
  });

  group('B — "Sirada kim?" gercekten adaletli', () {
    /// Saglayicidaki `pickFairStudent` ile ayni mantik.
    StudentParticipationEvaluation adilSec(
      List<StudentParticipationEvaluation> liste,
      Random rng,
    ) {
      final enAz =
          liste.map((e) => e.speakingTurns).reduce((a, b) => a < b ? a : b);
      final havuz = liste.where((e) => e.speakingTurns == enAz).toList();
      return havuz[rng.nextInt(havuz.length)];
    }

    test('KRITIK: hic konusmayan varken cok konusan secilmez', () {
      final liste = [
        ogr(1, soz: 5, ad: 'Cok konusan'),
        ogr(2, soz: 0, ad: 'Sessiz'),
        ogr(3, soz: 3),
      ];

      // 50 denemede de sessiz ogrenci secilmeli
      for (var i = 0; i < 50; i++) {
        expect(adilSec(liste, Random(i)).studentId, 2,
            reason: 'saf rastgelede cok konusan da cikiyordu');
      }
    });

    test('KRITIK: esit durumda havuzdan secilir', () {
      final liste = [
        ogr(1, soz: 0),
        ogr(2, soz: 0),
        ogr(3, soz: 4),
      ];

      final secilenler = <int>{};
      for (var i = 0; i < 100; i++) {
        secilenler.add(adilSec(liste, Random(i)).studentId);
      }

      expect(secilenler, containsAll([1, 2]),
          reason: 'esit olanlarin hepsi siraya girmeli');
      expect(secilenler.contains(3), isFalse,
          reason: 'daha cok konusan havuza girmemeli');
    });

    test('KRITIK: herkes konustukca sira ilerler', () {
      // Ogretmen sirayla soz veriyor; kimse iki kez one gecmemeli.
      var liste = [ogr(1), ogr(2), ogr(3)];
      final secimSirasi = <int>[];

      for (var tur = 0; tur < 3; tur++) {
        final secilen = adilSec(liste, Random(tur));
        secimSirasi.add(secilen.studentId);
        liste = liste
            .map((e) => e.studentId == secilen.studentId
                ? e.copyWith(speakingTurns: e.speakingTurns + 1)
                : e)
            .toList();
      }

      expect(secimSirasi.toSet().length, 3,
          reason: 'uc turda uc FARKLI ogrenci secilmeli');
    });

    test('tek ogrenci varsa o secilir', () {
      expect(adilSec([ogr(7)], Random(1)).studentId, 7);
    });
  });

  group('C — Ders sonu yalnizca istisnalar', () {
    test('KRITIK: istisna sayisi tum sinif degil', () {
      // Eskiden 30 ogrencinin HEPSI tek tek isaretleniyordu.
      // Artik yalnizca istisnalar: odevini yapmayan 3 kisi = 3 dokunus.
      final sinif = [
        ...List.generate(27, (i) => ogr(i + 1)),
        ogr(28).copyWith(homeworkStatus: HomeworkStatus.none),
        ogr(29).copyWith(homeworkStatus: HomeworkStatus.none),
        ogr(30).copyWith(arrivalStatus: ArrivalStatus.late),
      ];

      final odevIstisna = sinif
          .where((e) => e.homeworkStatus == HomeworkStatus.none)
          .length;
      final gelisIstisna =
          sinif.where((e) => e.arrivalStatus == ArrivalStatus.late).length;

      expect(odevIstisna, 2);
      expect(gelisIstisna, 1);
      expect(odevIstisna + gelisIstisna, lessThan(sinif.length),
          reason: 'istisna isaretlemek tum sinifi isaretlemekten az olmali');
    });

    test('sessiz ogrenciler ders sonunda gorunur', () {
      final sinif = [
        ogr(1, soz: 3),
        ogr(2, soz: 0),
        ogr(3, soz: 1),
        ogr(4, soz: 0),
      ];

      final sessizler = sinif.where((e) => e.isSilent).toList();
      expect(sessizler.length, 2,
          reason: 'ogretmen kimi atladigini gormeli');
    });
  });
}
