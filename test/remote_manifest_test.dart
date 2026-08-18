import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/cloud/remote_manifest_service.dart';

void main() {
  group('Sürüm karşılaştırma', () {
    int cmp(String a, String b) =>
        RemoteManifestService.compareVersions(a, b);

    test('Eşit sürümler sıfır döner', () {
      expect(cmp('1.0.0', '1.0.0'), 0);
      expect(cmp('2.5.13', '2.5.13'), 0);
    });

    test('Sayısal karşılaştırma yapar, metin değil', () {
      // Metin karşılaştırmasında "1.10.0" < "1.9.0" olurdu — yanlış.
      expect(cmp('1.10.0', '1.9.0'), greaterThan(0));
      expect(cmp('1.9.0', '1.10.0'), lessThan(0));
      expect(cmp('2.0.0', '10.0.0'), lessThan(0));
    });

    test('Eksik parçalar sıfır sayılır', () {
      expect(cmp('1.0', '1.0.0'), 0);
      expect(cmp('1', '1.0.0'), 0);
      expect(cmp('1.0.1', '1.0'), greaterThan(0));
    });

    test('Bozuk sürüm dizesi çökmez', () {
      // Sunucudan hatalı değer gelirse uygulama açılmamazlık etmemeli.
      expect(() => cmp('abc', '1.0.0'), returnsNormally);
      expect(cmp('abc', '1.0.0'), lessThan(0));
      expect(cmp('', '0.0.0'), 0);
    });

    test('Boşluklar yok sayılır', () {
      expect(cmp(' 1.0.0 ', '1.0.0'), 0);
    });
  });

  group('Varsayılan manifest (ağ yokken)', () {
    test('Bakım modu kapalı başlar', () {
      // Ağ kurulamadıysa uygulama kilitlenmemeli.
      expect(RemoteManifest.fallback.maintenanceMode, isFalse);
    });

    test('Sürümler 1 ve asgari sürüm 1.0.0', () {
      const f = RemoteManifest.fallback;
      expect(f.calendarVersion, 1);
      expect(f.outcomesVersion, 1);
      expect(f.schoolDirectoryVersion, 1);
      expect(f.minAppVersion, '1.0.0');
    });

    test('Varsayılan asgari sürüm mevcut sürümü engellemez', () {
      // Güvenli varsayılan: ağ yokken kimse "güncelle" duvarına çarpmamalı.
      const current = '1.0.0';
      expect(
        RemoteManifestService.compareVersions(
          current,
          RemoteManifest.fallback.minAppVersion,
        ),
        greaterThanOrEqualTo(0),
      );
    });
  });

  group('Servis başlangıç durumu', () {
    test('Firebase yokken hazır değildir ama manifest okunabilir', () {
      // Test ortamında Firebase başlatılmaz; servis çökmemeli.
      final service = RemoteManifestService.instance;
      expect(service.isReady, isFalse);
      expect(service.manifest.maintenanceMode, isFalse);
    });

    test('Hazır değilken refresh sessizce false döner', () async {
      final ok = await RemoteManifestService.instance.refresh();
      expect(ok, isFalse);
    });
  });
}
