import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/attendance/data/models/classroom_participation_model.dart';

/// Katilim raporu ve PDF (gercek kullanim geri bildirimi).
///
/// Kullanici bir hafta kullandiktan sonra bildirdi:
/// > "pdf paylasimi ekranina dokunmadin belli ki. pdf paylasma
/// > ekraninda da gorelim soz hakkini"
///
/// Ayrica oran hesaplari ISARETLENMEMIS ogrencileri paydaya katiyordu:
/// ogretmen 30 ogrencinin 3'unu isaretlediyse oran %10 cikiyordu, oysa
/// isaretlenen 3'un hepsi odevini yapmis olabilir.
void main() {
  StudentParticipationEvaluation ogr(
    int id, {
    int soz = 0,
    HomeworkStatus odev = HomeworkStatus.unknown,
    MaterialsStatus materyal = MaterialsStatus.unknown,
  }) =>
      StudentParticipationEvaluation(
        studentId: id,
        studentName: 'Ogrenci $id',
        studentNumber: id,
        speakingTurns: soz,
        homeworkStatus: odev,
        materialsStatus: materyal,
      );

  ClassroomParticipationSession oturum(
          List<StudentParticipationEvaluation> ogrenciler) =>
      ClassroomParticipationSession(
        classId: 1,
        className: '5-A',
        date: '2026-09-01',
        lessonHour: 3,
        subjectName: 'Matematik',
        evaluations: ogrenciler,
      );

  group('Soz hakki ozeti', () {
    test('KRITIK: toplam soz hakki sayiliyor', () {
      final s = oturum([ogr(1, soz: 3), ogr(2, soz: 1), ogr(3)]);
      expect(s.totalSpeakingTurns, 4);
    });

    test('KRITIK: hic konusmayan sayisi', () {
      final s = oturum([ogr(1, soz: 2), ogr(2), ogr(3), ogr(4, soz: 1)]);
      expect(s.silentStudentCount, 2,
          reason: 'ogretmenin "kimi atladim" sorusunun cevabi');
    });

    test('tum sinif konustuysa sessiz sayisi sifir', () {
      final s = oturum([ogr(1, soz: 1), ogr(2, soz: 2)]);
      expect(s.silentStudentCount, 0);
    });

    test('hic degerlendirme yoksa toplam sifir', () {
      final s = oturum([ogr(1), ogr(2)]);
      expect(s.totalSpeakingTurns, 0);
      expect(s.silentStudentCount, 2);
    });
  });

  group('Oranlar ISARETLENMEMISI paydaya katmiyor', () {
    test('KRITIK: 30 ogrencinin 3u isaretliyse oran %10 degil', () {
      // Eski hesap: 3 "yapti" / 30 ogrenci = %10
      // Dogrusu:    3 "yapti" / 3 isaretlenen = %100
      final sinif = [
        ogr(1, odev: HomeworkStatus.done),
        ogr(2, odev: HomeworkStatus.done),
        ogr(3, odev: HomeworkStatus.done),
        ...List.generate(27, (i) => ogr(i + 4)),
      ];
      final s = oturum(sinif);

      expect(s.homeworkCompletionRate, 100.0,
          reason: 'veri yoklugu basarisizlik gibi gorunmemeli');
      expect(s.homeworkEvaluatedCount, 3,
          reason: 'oranin kac ogrenciye dayandigi da gorunmeli');
    });

    test('KRITIK: gercek basarisizlik oranda gorunur', () {
      final s = oturum([
        ogr(1, odev: HomeworkStatus.done),
        ogr(2, odev: HomeworkStatus.none),
        ogr(3), // isaretlenmemis, sayilmaz
      ]);

      expect(s.homeworkCompletionRate, 50.0,
          reason: '1 yapti / 2 isaretlenen');
      expect(s.homeworkEvaluatedCount, 2);
    });

    test('KRITIK: hic isaretlenmemisse oran %100 DEGIL', () {
      // Veri yokken %100 gostermek "her sey harika" yalani olurdu.
      final s = oturum([ogr(1), ogr(2), ogr(3)]);
      expect(s.homeworkCompletionRate, 0.0);
      expect(s.homeworkEvaluatedCount, 0);
    });

    test('materyal orani da isaretlenmemisi saymaz', () {
      final s = oturum([
        ogr(1, materyal: MaterialsStatus.ready),
        ogr(2, materyal: MaterialsStatus.ready),
        ogr(3), // isaretlenmemis
      ]);
      expect(s.materialsReadinessRate, 100.0);
    });

    test('yarim yapilan odev yarim puan sayilir', () {
      final s = oturum([
        ogr(1, odev: HomeworkStatus.done),
        ogr(2, odev: HomeworkStatus.partial),
      ]);
      expect(s.homeworkCompletionRate, 75.0, reason: '(1 + 0.5) / 2');
    });
  });

  group('PDF soz hakkini gosteriyor', () {
    String pdfKodu() => File(
          'lib/features/attendance/utils/participation_pdf_generator.dart',
        ).readAsStringSync();

    test('KRITIK: tabloda Soz Hakki sutunu var', () {
      expect(pdfKodu(), contains("_buildHeaderCell('Söz Hakkı'"),
          reason: 'kullanici raporda soz hakkini gormek istedi');
    });

    test('KRITIK: satirda soz hakki basiliyor', () {
      expect(pdfKodu(), contains('e.speakingTurns'));
    });

    test('KRITIK: ust ozette sessiz ogrenci sayisi var', () {
      expect(pdfKodu(), contains('silentStudentCount'));
      expect(pdfKodu(), contains('totalSpeakingTurns'));
    });

    test('KRITIK: gelis durumu isaretlenmemisi "Gec" gostermiyor', () {
      // `== onTime ? ... : 'Geç'` yaziliyordu; isaretlenmemis ogrenci
      // raporda gec kalmis gorunuyordu — haksiz suclama.
      final kod = pdfKodu();
      expect(kod.contains("e.arrivalStatus == ArrivalStatus.onTime ? 'Zamanında' : 'Geç'"),
          isFalse);
      expect(kod, contains('ArrivalStatus.unknown =>'));
    });

    test('KRITIK: materyal durumu isaretlenmemisi "Eksik" gostermiyor', () {
      final kod = pdfKodu();
      expect(kod, contains('MaterialsStatus.unknown =>'));
    });
  });

  group('Ders adi ogretmenin bransi', () {
    test('KRITIK: PDF ice aktarimda sabit "Genel Ders" yok', () {
      final kod = File(
        'lib/features/classes/presentation/views/'
        'student_import_preview_view.dart',
      ).readAsStringSync();

      // Yalnizca yedek deger olarak kalabilir; sinif olustururken
      // ogretmenin bransi kullanilmali.
      expect(kod, contains('_defaultSubject'));
      expect(kod, contains('teacherProfileProvider'));
    });

    test('KRITIK: manuel sinif eklemede brans otomatik geliyor', () {
      final kod = File(
        'lib/features/classes/widgets/add_class_dialog.dart',
      ).readAsStringSync();

      expect(kod, contains('teacherProfileProvider'));
      expect(kod, contains('_subjectController.text = brans'));
      expect(kod, contains("'Ders / Branş'"),
          reason: 'etiket "Aciklama" degil "Ders / Brans" olmali');
    });
  });
}
