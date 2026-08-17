import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/schools/data/models/school_model.dart';
import 'package:sinifcepte/features/schools/data/models/school_types.dart';
import 'package:sinifcepte/features/schools/data/utils/normalized_levenshtein.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';

void main() {
  group('School directory helpers', () {
    test('inferType covers common MEB names', () {
      expect(SchoolTypes.inferFromName('Nilüfer Atatürk İlkokulu'), 'İlkokul');
      expect(SchoolTypes.inferFromName('Cumhuriyet Ortaokulu'), 'Ortaokul');
      expect(SchoolTypes.inferFromName('Bursa Fen Lisesi'), 'Fen Lisesi');
      expect(SchoolTypes.inferFromName('Anadolu İmam Hatip Lisesi'), 'Anadolu İmam Hatip Lisesi');
      expect(SchoolTypes.isExcludedInstitution('İl Milli Eğitim Müdürlüğü'), isTrue);
    });

    test('NormalizedLevenshtein scores near-duplicates high', () {
      expect(NormalizedLevenshtein.score('Cumhuriyet Ortaokulu', 'Cumhuriyet Ortaokulu'), 1);
      expect(NormalizedLevenshtein.score('Cumhuriyet Ortaokulu', 'Cumhuriyet  Ortaokulu'), greaterThan(0.85));
      expect(NormalizedLevenshtein.score('Fen Lisesi', 'Ticaret Meslek'), lessThan(0.5));
    });

    test('SchoolModel.fromShardMap reads snake_case wire', () {
      final school = SchoolModel.fromShardMap({
        'id': 'meb_734513',
        'meb_kurum_kodu': '734513',
        'name': 'Cumhuriyet Ortaokulu',
        'city': 'Bursa',
        'city_code': '16',
        'district': 'Nilüfer',
        'type': 'Ortaokul',
        'status': 'active',
        'source': 'resmi_liste',
      });
      expect(school.isCanonicalBindable, isTrue);
      expect(school.cityCode, '16');
    });

    test('TeacherProfileModel.isSchoolBound rejects legacy ids', () {
      const unbound = TeacherProfileModel(
        id: 't',
        firstName: 'A',
        lastName: 'B',
        branch: 'Mat',
        schoolName: 'Atatürk Anadolu Lisesi',
        schoolId: 'sch_16_01',
        schoolPrincipalName: '',
        email: '',
      );
      const bound = TeacherProfileModel(
        id: 't',
        firstName: 'A',
        lastName: 'B',
        branch: 'Mat',
        schoolName: 'Cumhuriyet Ortaokulu',
        schoolId: 'meb_734513',
        schoolPrincipalName: '',
        email: '',
      );
      expect(unbound.isSchoolBound, isFalse);
      expect(bound.isSchoolBound, isTrue);
    });
  });
}
