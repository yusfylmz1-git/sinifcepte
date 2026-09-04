import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/utils/lesson_clock.dart';

/// Aktif ders saatinin tazelenmesi (Faz 2.5).
///
/// Aktif ders sagalayicisi hic tazelenmiyordu; ana sayfa IndexedStack
/// icinde oturum boyunca acik kaldigi icin sabah hesaplanan ders aksama
/// kadar ekranda kaliyordu. Karttaki "tum sinifa tam puan" dugmesi de o
/// eski sinifa yaziyordu.
void main() {
  group('Ayni dilim ayni deger', () {
    test('bes dakika icindeki anlar ayni dilimde', () {
      final a = currentBucket(at: DateTime(2026, 11, 10, 8, 30));
      final b = currentBucket(at: DateTime(2026, 11, 10, 8, 34, 59));
      expect(a, b, reason: 'gereksiz yeniden hesaplama olmamali');
    });

    test('saniye ve salise dilimi degistirmez', () {
      final a = currentBucket(at: DateTime(2026, 11, 10, 8, 30, 0, 0));
      final b = currentBucket(at: DateTime(2026, 11, 10, 8, 30, 59, 999));
      expect(a, b);
    });
  });

  group('Dilim sinirinda deger degisir', () {
    test('KRITIK: bes dakika sonra dilim ilerler', () {
      final a = currentBucket(at: DateTime(2026, 11, 10, 8, 34));
      final b = currentBucket(at: DateTime(2026, 11, 10, 8, 35));
      expect(a, isNot(b), reason: 'saglayici yeniden hesaplanmali');
    });

    test('KRITIK: sabah acilip ogleye kadar bekleyen oturum tazelenir', () {
      final sabah = currentBucket(at: DateTime(2026, 11, 10, 8, 30));
      final ogle = currentBucket(at: DateTime(2026, 11, 10, 11, 0));
      expect(sabah, isNot(ogle),
          reason: '08:30 kartinin 11:00 de hala durmasi asil hataydi');
    });

    test('dilim sayisi zamanla artar', () {
      final a = currentBucket(at: DateTime(2026, 11, 10, 8, 0));
      final b = currentBucket(at: DateTime(2026, 11, 10, 9, 0));
      expect(b, greaterThan(a));
    });
  });

  group('Gun degisimi', () {
    test('KRITIK: gece yarisini gecen oturumda dunku ders kalmaz', () {
      final dun = currentBucket(at: DateTime(2026, 11, 10, 23, 58));
      final bugun = currentBucket(at: DateTime(2026, 11, 11, 0, 1));
      expect(dun, isNot(bugun));
    });

    test('KRITIK: ertesi gunun ayni saati ayni dilim sayilmaz', () {
      final a = currentBucket(at: DateTime(2026, 11, 10, 8, 30));
      final b = currentBucket(at: DateTime(2026, 11, 11, 8, 30));
      expect(a, isNot(b),
          reason: 'gun anahtara katilmazsa dunku ders gosterilmeye devam eder');
      expect(b, greaterThan(a));
    });

    test('ay ve yil gecisi de dilimi ilerletir', () {
      final aralik = currentBucket(at: DateTime(2026, 12, 31, 10, 0));
      final ocak = currentBucket(at: DateTime(2027, 1, 1, 10, 0));
      expect(ocak, greaterThan(aralik));
    });
  });

  group('Gun ici dilim sayisi tutarli', () {
    test('bir gunde 288 dilim var (5 dakikalik)', () {
      final ilk = currentBucket(at: DateTime(2026, 11, 10, 0, 0));
      final son = currentBucket(at: DateTime(2026, 11, 10, 23, 59));
      expect(son - ilk, 287, reason: '288 dilim, 0 dan 287 ye');
    });
  });
}
