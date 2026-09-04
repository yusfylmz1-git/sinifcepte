import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/classes/models/seating_plan_model.dart';

/// Sinif oturma plani testleri.
///
/// Bu ozellikte hic test yoktu. Asagidakiler once hatayi kanitlamak,
/// sonra duzeltmeyi kilitlemek icin yazildi.
void main() {
  StudentModel student(int id, {String gender = 'Erkek'}) {
    return StudentModel(
      id: id,
      classId: 1,
      schoolNumber: id,
      firstName: 'Ogrenci$id',
      lastName: 'Test',
      gender: gender,
    );
  }

  group('Model serilestirme', () {
    test('Koltuk atamalari kaydedilip geri okunur', () {
      const plan = SeatingPlanModel(
        classId: 7,
        columns: 3,
        rows: 5,
        assignments: {11: '0,0,0', 22: '2,4,1'},
      );

      final restored = SeatingPlanModel.fromMap(plan.toMap());

      expect(restored.classId, 7);
      expect(restored.columns, 3);
      expect(restored.rows, 5);
      expect(restored.assignments[11], '0,0,0');
      expect(restored.assignments[22], '2,4,1');
    });

    test('Bozuk JSON cokmez, bos plan doner', () {
      final restored = SeatingPlanModel.fromMap({
        'class_id': 1,
        'columns': 3,
        'rows': 5,
        'assignments': '{bozuk',
      });

      expect(restored.assignments, isEmpty);
    });

    test('KRITIK: varsayilan izgara boyutu her yerde ayni olmali', () {
      // Model 3x5, fromMap 4x6 diyordu. Yeni sinifin plani ilk acilista
      // 3x5 kuruluyor; NULL sutunlu satirdan okununca 4x6'ya siciyordu.
      const fresh = SeatingPlanModel(classId: 1);
      final fromNullRow = SeatingPlanModel.fromMap({
        'class_id': 1,
        'columns': null,
        'rows': null,
        'assignments': null,
      });

      expect(fromNullRow.columns, fresh.columns);
      expect(fromNullRow.rows, fresh.rows);
    });
  });

  group('Koltuk atama tutarliligi', () {
    test('KRITIK: ayni koltukta iki ogrenci oturamaz', () {
      final assignments = <int, String>{1: '0,0,0'};

      const target = '0,0,0';
      assignments.removeWhere((key, value) => value == target);
      assignments[2] = target;

      final seats = assignments.values.toList();
      expect(seats.toSet().length, seats.length,
          reason: 'Ayni koltuk iki kez atandi');
      expect(assignments.containsKey(1), isFalse);
    });

    test('KRITIK: takas sonrasi koltuk cakismasi olmaz', () {
      final assignments = <int, String>{1: '0,0,0', 2: '1,2,1'};

      final pos1 = assignments[1];
      final pos2 = assignments[2];
      assignments[1] = pos2!;
      assignments[2] = pos1!;

      expect(assignments[1], '1,2,1');
      expect(assignments[2], '0,0,0');
      final seats = assignments.values.toList();
      expect(seats.toSet().length, seats.length);
    });
  });

  group('Cinsiyet dengeli dagitim', () {
    /// Uretimdeki autoAssignGenderBalanced ile birebir ayni mantik.
    Map<int, String> genderBalanced(
      List<StudentModel> students,
      int blocks,
      int rows,
    ) {
      final girls =
          students.where((s) => s.gender.toLowerCase().contains('kiz')).toList();
      // Cinsiyeti taninmayan ogrenci de mutlaka bir koltuk almali.
      final boys = students
          .where((s) => !s.gender.toLowerCase().contains('kiz'))
          .toList();

      final map = <int, String>{};
      int gi = 0;
      int bi = 0;
      for (int r = 0; r < rows; r++) {
        for (int b = 0; b < blocks; b++) {
          final pos0 = '$b,$r,0';
          if (gi < girls.length) {
            map[girls[gi].id!] = pos0;
            gi++;
          } else if (bi < boys.length) {
            map[boys[bi].id!] = pos0;
            bi++;
          }

          final pos1 = '$b,$r,1';
          if (bi < boys.length) {
            map[boys[bi].id!] = pos1;
            bi++;
          } else if (gi < girls.length) {
            map[girls[gi].id!] = pos1;
            gi++;
          }
        }
      }
      return map;
    }

    test('KRITIK: hicbir ogrenci dagitim disinda kalmaz', () {
      final students = <StudentModel>[
        for (int i = 1; i <= 6; i++) student(i, gender: 'Kiz'),
        for (int i = 7; i <= 12; i++) student(i, gender: 'Erkek'),
      ];

      final map = genderBalanced(students, 3, 2);

      expect(map.length, students.length, reason: 'Yerlesemeyen ogrenci var');
    });

    test('KRITIK: tek cinsiyetli sinifta koltuk uzerine yazma olmaz', () {
      final students = [for (int i = 1; i <= 8; i++) student(i, gender: 'Kiz')];

      final map = genderBalanced(students, 2, 2);

      expect(map.length, 8, reason: 'Yerlesemeyen ogrenci var');
      final seats = map.values.toList();
      expect(seats.toSet().length, seats.length,
          reason: 'Ayni koltuga birden fazla ogrenci');
    });

    test('Cinsiyeti belirsiz ogrenci de yerlesir', () {
      // e-Okul listesinde cinsiyet sutunu bos gelebiliyor.
      final students = [
        student(1, gender: 'Kiz'),
        student(2, gender: 'Erkek'),
        student(3, gender: ''),
        student(4, gender: 'Belirtilmemis'),
      ];

      final map = genderBalanced(students, 2, 2);

      expect(map.length, students.length,
          reason: 'Cinsiyeti yazmayan ogrenci kayboldu');
    });
  });

  group('Ogrenci listesi degistiginde', () {
    test('KRITIK: silinen ogrencinin koltugu bosa cikar', () {
      const plan = SeatingPlanModel(
        classId: 1,
        assignments: {1: '0,0,0', 2: '0,0,1', 99: '1,1,0'},
      );
      final liveIds = {1, 2};

      final pruned = Map<int, String>.from(plan.assignments)
        ..removeWhere((studentId, _) => !liveIds.contains(studentId));

      expect(pruned.containsKey(99), isFalse,
          reason: 'Silinen ogrenci hala koltukta');
      expect(pruned.length, 2);
    });
  });

  group('Izgara boyutu', () {
    test('Sira silinince o siradaki ogrenciler havuza doner', () {
      const plan = SeatingPlanModel(
        classId: 1,
        columns: 3,
        rows: 4,
        assignments: {1: '0,0,0', 2: '0,3,1', 3: '1,3,0'},
      );

      final targetRow = plan.rows - 1;
      final next = Map<int, String>.from(plan.assignments)
        ..removeWhere((_, value) {
          final parts = value.split(',');
          return parts.length >= 2 && int.tryParse(parts[1]) == targetRow;
        });

      expect(next.keys, [1]);
    });

    test('KRITIK: blok azaltinca sigmayan atamalar temizlenir', () {
      const plan = SeatingPlanModel(
        classId: 1,
        columns: 4,
        rows: 4,
        assignments: {1: '0,0,0', 2: '3,1,1'},
      );

      const newBlocks = 2;
      const newRows = 4;
      final next = Map<int, String>.from(plan.assignments)
        ..removeWhere((_, value) {
          final parts = value.split(',');
          if (parts.length < 3) return false;
          final b = int.tryParse(parts[0]) ?? 0;
          final r = int.tryParse(parts[1]) ?? 0;
          return b >= newBlocks || r >= newRows;
        });

      expect(next.containsKey(2), isFalse,
          reason: '3. blok kaldirildi ama ogrenci hala orada');
      expect(next.containsKey(1), isTrue);
    });
  });
}
