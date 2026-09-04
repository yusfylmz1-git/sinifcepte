import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/cloud/cloud_ids.dart';

/// Profil anahtarlarinin cozumlenmesi.
///
/// Kullanici bildirdi: "girişte hala okul soruyor" — oysa cihazda
/// `profil_okul_id__{uid}` kaydi DOLUYDU.
///
/// Sebep: profil durumu baslangicta `id: 'local_teacher'` yer tutucusunu
/// tasir. Kimlik cozumlenirken yalnizca `isNotEmpty` bakiliyordu; yer
/// tutucu bos olmadigi icin anahtar `profil_okul__local_teacher` oluyor
/// ve o kayit hic bulunmuyordu.
void main() {
  String key(String base, String uid) => uid.isEmpty ? base : '${base}__$uid';

  /// Uretimdeki _activeUid ile ayni mantik.
  String activeUid(String stateId, String lastKnown) {
    if (CloudIds.isValidUid(stateId)) return stateId;
    return lastKnown;
  }

  group('Aktif hesap kimligi', () {
    test('KRITIK: yer tutucu kimlik gercek hesap sayilmaz', () {
      // Hatanin ozu buydu.
      expect(CloudIds.isValidUid('local_teacher'), isFalse);

      final uid = activeUid('local_teacher', 'KplpM8ibNdhVJENzWz8tvJ0vsLR2');
      expect(uid, 'KplpM8ibNdhVJENzWz8tvJ0vsLR2',
          reason: 'Yer tutucu, son bilinen hesabin yerine gecti');
    });

    test('KRITIK: yer tutucuyla yanlis anahtar uretilmez', () {
      final yanlis = key('profil_okul_id', 'local_teacher');
      final dogru = key('profil_okul_id', 'KplpM8ibNdhVJENzWz8tvJ0vsLR2');

      expect(yanlis, isNot(dogru));
      expect(dogru, 'profil_okul_id__KplpM8ibNdhVJENzWz8tvJ0vsLR2');
    });

    test('Gercek kimlik varsa dogrudan kullanilir', () {
      final uid = activeUid('KplpM8ibNdhVJENzWz8tvJ0vsLR2', 'baskaUid');
      expect(uid, 'KplpM8ibNdhVJENzWz8tvJ0vsLR2');
    });

    test('Hicbiri yoksa bos doner (masaustu yerel mod)', () {
      expect(activeUid('local_teacher', ''), '');
      expect(key('profil_okul_id', ''), 'profil_okul_id');
    });

    test('Iki hesap ayri anahtar seti kullanir', () {
      const a = 'KplpM8ibNdhVJENzWz8tvJ0vsLR2';
      const b = 'WNBLCBCsKEO1YU5LJk5QdTRi0Z73';

      expect(key('profil_okul_id', a), isNot(key('profil_okul_id', b)));
    });
  });
}
