import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/utils/lesson_clock.dart';

/// Saat diliminin yeniden cizim sıklığı (Faz 2.5).
///
/// Ana sayfa 1728 satirlik tek bir build metodu; her saglayici degisimi
/// tum agaci yeniden cizdiriyor. Saat dilimi cok sik ilerlerse ana sayfa
/// gereksiz yere surekli yeniden cizilir.
void main() {
  test('KRITIK: bir ders saati boyunca en fazla birkac kez ilerler', () {
    // 40 dakikalik bir ders boyunca dakika dakika bak.
    final baslangic = DateTime(2026, 11, 10, 9, 0);
    final dilimler = <int>{};

    for (var dk = 0; dk < 40; dk++) {
      dilimler.add(currentBucket(at: baslangic.add(Duration(minutes: dk))));
    }

    expect(dilimler.length, 8,
        reason: '40 dakika / 5 dakikalik dilim = 8 yeniden cizim');
  });

  test('bir okul gunu boyunca yeniden cizim sayisi makul', () {
    // 08:00 - 16:00 arasi
    final dilimler = <int>{};
    for (var dk = 0; dk < 8 * 60; dk++) {
      dilimler.add(
          currentBucket(at: DateTime(2026, 11, 10, 8, 0).add(Duration(minutes: dk))));
    }

    expect(dilimler.length, 96,
        reason: '8 saat / 5 dakika = 96; saniyede bir cizimden cok daha iyi');
  });

  test('dilim araligi ders tespitiyle uyumlu', () {
    // Ders tespiti 5 dakikalik teneffus payi kullaniyor; tazeleme
    // araligi bundan buyuk olursa yanlis ders gosterilen pencere acilir.
    expect(kLessonClockInterval.inMinutes, lessThanOrEqualTo(5));
  });
}
