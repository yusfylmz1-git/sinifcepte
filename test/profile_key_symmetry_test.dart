import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/cloud/cloud_ids.dart';

/// Profil anahtarlarinda YAZMA ve OKUMA simetrisi.
///
/// Kullanici defalarca bildirdi: "yine okul soruyor". Son sebep buydu:
/// `saveProfile` anahtari `updated.id` ile uretiyordu (yer tutucu
/// olabilir), okuma tarafi ise `_activeUid()` ile GERCEK UID ariyordu.
/// Yazma ve okuma farkli anahtarlara dustugu icin kayit hic bulunamiyor
/// ve kurulum her acilista yeniden isteniyordu.
void main() {
  String key(String base, String uid) => uid.isEmpty ? base : '${base}__$uid';

  /// Uretimdeki cozumleyicinin ayni mantigi (yazma ve okuma icin ORTAK).
  String resolveUid(String candidateId, String lastKnown) {
    if (CloudIds.isValidUid(candidateId)) return candidateId;
    return lastKnown;
  }

  group('Anahtar simetrisi', () {
    const gercekUid = 'KplpM8ibNdhVJENzWz8tvJ0vsLR2';

    test('KRITIK: yer tutucu kimlikle yazilan anahtar okunabilir', () {
      // Yazma: profil.id yer tutucu, ama son bilinen hesap var.
      final yazmaUid = resolveUid('local_teacher', gercekUid);
      // Okuma: ayni kuralla cozulur.
      final okumaUid = resolveUid('local_teacher', gercekUid);

      expect(key('profil_okul', yazmaUid), key('profil_okul', okumaUid));
      expect(yazmaUid, gercekUid);
    });

    test('KRITIK: eski hatali davranis anahtari kacirirdi', () {
      // Eski yazma: updated.id DOGRUDAN kullaniliyordu.
      final eskiYazma = key('profil_okul', 'local_teacher');
      // Okuma her zaman gercek UID ariyordu.
      final okuma = key('profil_okul', gercekUid);

      expect(eskiYazma, isNot(okuma),
          reason: 'Bu uyusmazlik kurulumun her acilista sorulmasina yol actı');
    });

    test('Gercek kimlikle yazma ve okuma ayni anahtari verir', () {
      final yazma = resolveUid(gercekUid, 'baskaUid');
      final okuma = resolveUid(gercekUid, 'baskaUid');
      expect(key('profil_brans', yazma), key('profil_brans', okuma));
    });

    test('Hicbir kimlik yoksa eski sabit anahtara duser', () {
      // Masaustu yerel modu: bulut kimligi yok.
      final uid = resolveUid('local_teacher', '');
      expect(uid, '');
      expect(key('profil_okul', uid), 'profil_okul');
    });

    test('Iki hesap ayri anahtar seti kullanir', () {
      const a = 'KplpM8ibNdhVJENzWz8tvJ0vsLR2';
      const b = 'WNBLCBCsKEO1YU5LJk5QdTRi0Z73';
      expect(key('profil_okul', a), isNot(key('profil_okul', b)));
    });
  });
}
