import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/firebase/crash_reporter.dart';

/// Cokme raporlama tamponu (Faz 4).
///
/// `main()` hizli acilis icin Firebase'i `runApp`'ten SONRA, arka planda
/// baslatiyor. Bu yuzden ilk anlarda Crashlytics hazir degil.
///
/// En kritik hatalar tam da orada oluyor (acilista cokme). Tampon
/// olmasaydi bu hatalar hic gorunmezdi.
void main() {
  setUp(CrashReporter.resetForTest);
  tearDown(CrashReporter.resetForTest);

  group('Firebase hazir degilken', () {
    test('KRITIK: hata kaybolmaz, tamponlanir', () {
      CrashReporter.record(Exception('acilista cokme'), StackTrace.current,
          reason: 'test');

      expect(CrashReporter.pendingCount, 1,
          reason: 'Firebase hazir olmadan olusan hata da gonderilebilmeli');
    });

    test('birden fazla hata birikir', () {
      for (var i = 0; i < 5; i++) {
        CrashReporter.record(Exception('hata $i'), StackTrace.current);
      }
      expect(CrashReporter.pendingCount, 5);
    });

    test('KRITIK: tampon sinirsiz buyumez', () {
      // Hata dongusune giren bir kod yolu bellegi doldurmamali.
      for (var i = 0; i < 200; i++) {
        CrashReporter.record(Exception('dongu $i'), StackTrace.current);
      }
      expect(CrashReporter.pendingCount, lessThanOrEqualTo(20),
          reason: 'dongudeki hata bellegi sismemeli');
    });
  });

  group('Kurulum', () {
    test('install iki kez cagrilinca sorun cikarmaz', () {
      CrashReporter.install();
      expect(CrashReporter.install, returnsNormally);
    });

    test('log Firebase hazir degilken cokmez', () {
      expect(() => CrashReporter.log('ekran: ogrenci listesi'),
          returnsNormally);
    });
  });

  group('Raporlayici uygulamayi dusurmemeli', () {
    test('null yigin izi kabul edilir', () {
      expect(() => CrashReporter.record(Exception('yigin yok'), null),
          returnsNormally);
      expect(CrashReporter.pendingCount, 1);
    });

    test('String hata da kabul edilir', () {
      expect(() => CrashReporter.record('duz metin hata', StackTrace.current),
          returnsNormally);
    });
  });
}
