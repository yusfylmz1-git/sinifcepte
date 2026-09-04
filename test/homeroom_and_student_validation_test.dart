import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/utils/input_sanitizer.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/classes/data/services/pdf_student_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. MEB Rehberlik Sınıfı Kurgusu & ClassModel Testleri', () {
    test('ClassModel isHomeroom varsayılan olarak false olmalıdır', () {
      const model = ClassModel(
        id: 1,
        name: '5-A',
        subject: 'Matematik',
        academicYear: '2025-2026',
      );

      expect(model.isHomeroom, isFalse);
      expect(model.toMap()['is_homeroom'], 0);
    });

    test('ClassModel isHomeroom: true olduğunda toMap ve fromMap doğru dönüşüm yapmalıdır', () {
      const model = ClassModel(
        id: 2,
        name: '8-B',
        subject: 'Rehberlik & Matematik',
        academicYear: '2025-2026',
        isHomeroom: true,
      );

      final map = model.toMap();
      expect(map['is_homeroom'], 1);

      final fromMap = ClassModel.fromMap(map);
      expect(fromMap.id, 2);
      expect(fromMap.name, '8-B');
      expect(fromMap.isHomeroom, isTrue);
    });

    test('ClassModel copyWith ile isHomeroom durumu başarıyla güncellenebilmelidir', () {
      const initial = ClassModel(
        id: 3,
        name: '7-C',
        subject: 'Fen Bilimleri',
        academicYear: '2025-2026',
        isHomeroom: false,
      );

      final updated = initial.copyWith(isHomeroom: true);
      expect(updated.isHomeroom, isTrue);
      expect(updated.name, '7-C');
    });

    test('Bir öğretmenin sınıfları arasında en fazla 1 adet Rehberlik Sınıfı bulunabilir kuralı', () {
      final classes = [
        const ClassModel(id: 1, name: '5-A', subject: 'Matematik', academicYear: '2025-2026', isHomeroom: false),
        const ClassModel(id: 2, name: '6-B', subject: 'Matematik', academicYear: '2025-2026', isHomeroom: true),
        const ClassModel(id: 3, name: '7-A', subject: 'Matematik', academicYear: '2025-2026', isHomeroom: false),
      ];

      final homeroomCount = classes.where((c) => c.isHomeroom).length;
      expect(homeroomCount, 1);

      final activeHomeroom = classes.where((c) => c.isHomeroom).firstOrNull;
      expect(activeHomeroom?.name, '6-B');
    });
  });

  group('2. Sınıf İçi Mükerrer Öğrenci Numarası Önleme (Zero-Duplicate) Testleri', () {
    const classId1 = 10;
    const classId2 = 20;

    final existingStudentsClass1 = [
      const StudentModel(id: 1, classId: classId1, schoolNumber: 101, firstName: 'Ahmet', lastName: 'Yılmaz'),
      const StudentModel(id: 2, classId: classId1, schoolNumber: 102, firstName: 'Ayşe', lastName: 'Demir'),
      const StudentModel(id: 3, classId: classId1, schoolNumber: 105, firstName: 'Mehmet', lastName: 'Kaya'),
    ];

    test('1. Katman: Aynı sınıfa aynı okul numarası eklenmesi engellenmelidir', () {
      const inputNumber = 102;

      // Doğrulama kontrolü: Sınıfta 102 numaralı öğrenci var mı?
      final isDuplicate = existingStudentsClass1.any((s) => s.schoolNumber == inputNumber);
      expect(isDuplicate, isTrue);
    });

    test('Farklı bir sınıfta aynı okul numarası kullanılabilmelidir', () {
      const inputNumber = 102;

      final existingStudentsClass2 = [
        const StudentModel(id: 4, classId: classId2, schoolNumber: 201, firstName: 'Zeynep', lastName: 'Çelik'),
      ];

      final isDuplicateInClass2 = existingStudentsClass2.any((s) => s.schoolNumber == inputNumber);
      expect(isDuplicateInClass2, isFalse);
    });

    test('Öğrenci düzenlenirken kendi mevcut numarası mükerrer sayılmamalıdır', () {
      const studentBeingEdited = StudentModel(id: 2, classId: classId1, schoolNumber: 102, firstName: 'Ayşe', lastName: 'Demir');
      const newNumber = 102; // Numara aynı kaldı, sadece isim değişecek

      final isDuplicate = existingStudentsClass1.any(
        (s) => s.id != studentBeingEdited.id && s.schoolNumber == newNumber,
      );
      expect(isDuplicate, isFalse);
    });

    test('Öğrenci düzenlenirken sınıftaki başka bir öğrencinin numarası verilirse engellenmelidir', () {
      const studentBeingEdited = StudentModel(id: 2, classId: classId1, schoolNumber: 102, firstName: 'Ayşe', lastName: 'Demir');
      const conflictNumber = 105; // 105 no Mehmet Kaya'ya ait

      final isDuplicate = existingStudentsClass1.any(
        (s) => s.id != studentBeingEdited.id && s.schoolNumber == conflictNumber,
      );
      expect(isDuplicate, isTrue);
    });

    test('Toplu içe aktarma listesinde kendi içinde aynı numara varsa tespit edilmelidir', () {
      final draftList = [
        const StudentModel(classId: classId1, schoolNumber: 150, firstName: 'Ali', lastName: 'Can'),
        const StudentModel(classId: classId1, schoolNumber: 151, firstName: 'Veli', lastName: 'Han'),
        const StudentModel(classId: classId1, schoolNumber: 150, firstName: 'Canan', lastName: 'Tek'), // Mükerrer 150!
      ];

      final seenNumbers = <int>{};
      final internalDuplicates = <int>{};
      for (final s in draftList) {
        if (!seenNumbers.add(s.schoolNumber)) {
          internalDuplicates.add(s.schoolNumber);
        }
      }

      expect(internalDuplicates.contains(150), isTrue);
      expect(internalDuplicates.length, 1);
    });
  });

  group('3. Akıllı Belge Sınıf Tespiti & Otomatik Sınıf Eşleştirme Testleri', () {
    final existingClasses = [
      const ClassModel(id: 1, name: '5-A', subject: 'Genel', academicYear: '2025-2026'),
      const ClassModel(id: 2, name: '6-B', subject: 'Genel', academicYear: '2025-2026'),
      const ClassModel(id: 3, name: '7-C', subject: 'Genel', academicYear: '2025-2026'),
    ];

    test('Farklı formatlardaki sınıf adları ("5/A", "5-A", "5 A", "5.A", "5a") InputSanitizer ile "5-A"ya normalize edilmelidir', () {
      expect(InputSanitizer.cleanClassName('5/A'), '5-A');
      expect(InputSanitizer.cleanClassName('5-A'), '5-A');
      expect(InputSanitizer.cleanClassName('5 A'), '5-A');
      expect(InputSanitizer.cleanClassName('5.A'), '5-A');
      expect(InputSanitizer.cleanClassName('5a'), '5-A');
      expect(InputSanitizer.cleanClassName('7/c'), '7-C');
    });

    test('Tespit edilen sınıf adı mevcut sınıflar arasında varsa otomatik eşleşmeli ve seçilmelidir', () {
      const detectedName = '5/A';
      final normalized = InputSanitizer.cleanClassName(detectedName);

      final matched = existingClasses.where((c) => InputSanitizer.cleanClassName(c.name) == normalized).firstOrNull;

      expect(matched, isNotNull);
      expect(matched!.id, 1);
      expect(matched.name, '5-A');
    });

    test('Tespit edilen sınıf adı sistemde yoksa yeni sınıf olarak oluşturulma moduna geçmelidir', () {
      const detectedName = '8/D';
      final normalized = InputSanitizer.cleanClassName(detectedName);

      final matched = existingClasses.where((c) => InputSanitizer.cleanClassName(c.name) == normalized).firstOrNull;

      expect(matched, isNull);
      // Sistem 8-D adıyla yeni sınıf açar
    });
  });

  group('4. Çoklu Sınıf Belgesi (Taşımalı / Kulüp Listesi) Ayrıştırma & Dağıtım Testleri', () {
    test('e-Okul Taşımalı liste satırlarından sınıf şubeleri doğru regex ile ayıklanmalıdır', () {
      final mebPattern = RegExp(
        r'([1-9]|1[0-2])\s*\.?\s*(?:Sınıfı?|Sinifi?)?\s*[\/\-\s]\s*([A-Za-zğüşöçıİĞÜŞÖÇ])\s*(?:Şubesi|Subesi|Şube|Sube)?\b',
        caseSensitive: false,
      );

      String? extract(String text) {
        final match = mebPattern.firstMatch(text);
        if (match != null) {
          final grade = match.group(1);
          final branch = match.group(2)?.toUpperCase();
          if (grade != null && branch != null) {
            return '$grade-$branch';
          }
        }
        return null;
      }

      expect(extract('5. Sınıf / D Şubesi'), '5-D');
      expect(extract('5. Sınıf / A Şubesi'), '5-A');
      expect(extract('6. Sınıf / B Şubesi'), '6-B');
      expect(extract('7. Sınıf / B Şubesi'), '7-B');
      expect(extract('8. Sınıf / D Şubesi'), '8-D');
      expect(extract('11. Sınıf / F Şubesi'), '11-F');
      expect(extract('5-A'), '5-A');
      expect(extract('6/C'), '6-C');
    });

    test('Çoklu sınıfa sahip öğrenci listesi sınıflara göre hatasız gruplanmalı ve dağıtılmalıdır', () {
      final parsedStudents = [
        const ParsedStudentItem(schoolNumber: 101, firstName: 'Ahmet', lastName: 'Yılmaz', gender: 'Erkek', className: '5-D'),
        const ParsedStudentItem(schoolNumber: 102, firstName: 'Zeynep', lastName: 'Kaya', gender: 'Kız', className: '5-D'),
        const ParsedStudentItem(schoolNumber: 201, firstName: 'Mehmet', lastName: 'Demir', gender: 'Erkek', className: '6-A'),
        const ParsedStudentItem(schoolNumber: 301, firstName: 'Ayşe', lastName: 'Çelik', gender: 'Kız', className: '7-B'),
      ];

      final Map<String, List<ParsedStudentItem>> groupedByClass = {};
      for (final student in parsedStudents) {
        final clsName = student.className ?? 'Genel';
        groupedByClass.putIfAbsent(clsName, () => []).add(student);
      }

      expect(groupedByClass.keys.length, 3);
      expect(groupedByClass['5-D']!.length, 2);
      expect(groupedByClass['6-A']!.length, 1);
      expect(groupedByClass['7-B']!.length, 1);
      expect(groupedByClass['5-D']!.first.firstName, 'Ahmet');
    });
  });

  group('4. Öğrenci Sınıf Değiştirme (Şube Transferi) & Çapraz Sınıf Mükerrer Numara Testleri', () {
    const classId5A = 1;
    const classId5B = 2;

    final studentsIn5A = [
      const StudentModel(id: 10, classId: classId5A, schoolNumber: 305, firstName: 'Ali', lastName: 'Yıldız'),
      const StudentModel(id: 11, classId: classId5A, schoolNumber: 420, firstName: 'Ece', lastName: 'Aydın'),
    ];

    final studentsIn5B = [
      const StudentModel(id: 20, classId: classId5B, schoolNumber: 305, firstName: 'Cem', lastName: 'Kaya'), // 305 numarası 5-B'de zaten var!
      const StudentModel(id: 21, classId: classId5B, schoolNumber: 550, firstName: 'Banu', lastName: 'Kurt'),
    ];

    test('Hedef sınıfta aynı numara yoksa (Ece Aydın #420 -> 5-B) transfer başarılı olmalıdır', () {
      final studentToMove = studentsIn5A.firstWhere((s) => s.id == 11);
      final duplicateInTarget = studentsIn5B.where((s) => s.schoolNumber == studentToMove.schoolNumber).firstOrNull;

      expect(duplicateInTarget, isNull);

      final movedStudent = studentToMove.copyWith(classId: classId5B);
      expect(movedStudent.classId, classId5B);
      expect(movedStudent.schoolNumber, 420);
      // Soyad artik standart geregi TAMAMEN BUYUK: "Yusuf YILMAZ".
      expect(movedStudent.fullName, 'Ece AYDIN');
    });

    test('Hedef sınıfta aynı numara varsa (Ali Yıldız #305 -> 5-B) çakışma tespit edilip engellenmelidir', () {
      final studentToMove = studentsIn5A.firstWhere((s) => s.id == 10); // Okul no: 305
      final duplicateInTarget = studentsIn5B.where((s) => s.schoolNumber == studentToMove.schoolNumber).firstOrNull;

      expect(duplicateInTarget, isNotNull);
      expect(duplicateInTarget?.schoolNumber, 305);
      expect(duplicateInTarget?.fullName, 'Cem KAYA');

      // Validasyon hatası mesajı
      final error = 'Hedef sınıfta #${studentToMove.schoolNumber} numaralı başka bir öğrenci (${duplicateInTarget!.fullName}) zaten kayıtlı!';
      expect(error, contains('305'));
      expect(error, contains('Cem KAYA'));
    });

    test('Öğrencinin zaten kayıtlı olduğu mevcut sınıfa transferi engellenmelidir', () {
      final studentToMove = studentsIn5A.first;
      const targetClassId = classId5A; // Aynı sınıf

      final isSameClass = studentToMove.classId == targetClassId;
      expect(isSameClass, isTrue);
    });

    test('InputSanitizer.extractGradeLevel farklı sınıf formatlarından kademeyi doğru ayıklamalıdır', () {
      expect(InputSanitizer.extractGradeLevel('5-A'), '5');
      expect(InputSanitizer.extractGradeLevel('5/B'), '5');
      expect(InputSanitizer.extractGradeLevel('5. Sınıf D'), '5');
      expect(InputSanitizer.extractGradeLevel('6-C'), '6');
      expect(InputSanitizer.extractGradeLevel('7-A'), '7');
      expect(InputSanitizer.extractGradeLevel('8-B'), '8');
      expect(InputSanitizer.extractGradeLevel('11-F'), '11');
      expect(InputSanitizer.extractGradeLevel('12/A'), '12');
      expect(InputSanitizer.extractGradeLevel('Özel Eğitim'), isNull);
    });

    test('Sınıf değiştirme listesinde YALNIZCA aynı kademedeki şubeler listelenmelidir', () {
      final allClasses = [
        const ClassModel(id: 1, name: '5-D', subject: 'Genel', academicYear: '2025-2026'),
        const ClassModel(id: 2, name: '5-A', subject: 'Genel', academicYear: '2025-2026'),
        const ClassModel(id: 3, name: '5-B', subject: 'Genel', academicYear: '2025-2026'),
        const ClassModel(id: 4, name: '5-C', subject: 'Genel', academicYear: '2025-2026'),
        const ClassModel(id: 5, name: '6-A', subject: 'Genel', academicYear: '2025-2026'),
        const ClassModel(id: 6, name: '6-B', subject: 'Genel', academicYear: '2025-2026'),
        const ClassModel(id: 7, name: '7-A', subject: 'Genel', academicYear: '2025-2026'),
        const ClassModel(id: 8, name: '8-B', subject: 'Genel', academicYear: '2025-2026'),
      ];

      const currentClassId = 1; // 5-D sınıfı
      final currentGrade = InputSanitizer.extractGradeLevel('5-D'); // '5'

      // Filtreleme kuralı
      final filteredTargetClasses = allClasses.where((c) {
        if (c.id == currentClassId) return false;
        if (currentGrade != null) {
          return InputSanitizer.extractGradeLevel(c.name) == currentGrade;
        }
        return true;
      }).toList();

      // Sonuç: Yalnızca 5-A, 5-B, 5-C gelmeli (6-A, 6-B, 7-A, 8-B ASLA gelmemeli!)
      expect(filteredTargetClasses.length, 3);
      expect(filteredTargetClasses.map((c) => c.name).toList(), ['5-A', '5-B', '5-C']);
      expect(filteredTargetClasses.any((c) => c.name.startsWith('6-')), isFalse);
      expect(filteredTargetClasses.any((c) => c.name.startsWith('7-')), isFalse);
      expect(filteredTargetClasses.any((c) => c.name.startsWith('8-')), isFalse);
    });
  });
}



