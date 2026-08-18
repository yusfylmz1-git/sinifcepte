import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/cloud/firestore_budget_guard.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final guard = FirestoreBudgetGuard.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
    await guard.reset();
  });

  group('Yazma freni', () {
    test('Normal kullanımda yazmaya izin verir', () async {
      expect(await guard.allowWrite(), isTrue);
      expect(await guard.allowWrite(), isTrue);
      expect(guard.writesToday, 2);
      expect(guard.isWriteBlocked, isFalse);
    });

    test('Günlük tavana ulaşınca yazmayı durdurur', () async {
      // Kaçak bir döngü simülasyonu: tavanı tek seferde doldur.
      final ok = await guard.allowWrite(
        count: FirestoreBudgetGuard.dailyWriteLimit,
      );
      expect(ok, isTrue);
      expect(guard.isWriteBlocked, isTrue);

      // Sonraki yazma reddedilmeli.
      expect(await guard.allowWrite(), isFalse);
    });

    test('Tavanı aşacak toplu yazma tümüyle reddedilir', () async {
      // Kısmi yazma yapılmaz: batch ya tamamen geçer ya hiç.
      final ok = await guard.allowWrite(
        count: FirestoreBudgetGuard.dailyWriteLimit + 1,
      );
      expect(ok, isFalse);
      // Sayaç kirletilmemeli.
      expect(guard.writesToday, 0);
    });

    test('Reddedilen yazma sayacı artırmaz', () async {
      await guard.allowWrite(count: FirestoreBudgetGuard.dailyWriteLimit);
      final before = guard.writesToday;

      await guard.allowWrite();
      await guard.allowWrite();

      expect(guard.writesToday, before);
    });

    test('Tavanın hemen altındaki yazma geçer', () async {
      final ok = await guard.allowWrite(
        count: FirestoreBudgetGuard.dailyWriteLimit - 1,
      );
      expect(ok, isTrue);
      // Tam sınıra kadar bir yazma daha kabul edilir.
      expect(await guard.allowWrite(), isTrue);
      expect(await guard.allowWrite(), isFalse);
    });
  });

  group('Okuma sayacı', () {
    test('Okuma sayılır ama ASLA engellenmez', () async {
      // Okuma engellenirse uygulama kullanılamaz hale gelir.
      await guard.recordRead(
        count: FirestoreBudgetGuard.dailyReadWarnThreshold * 3,
      );

      expect(
        guard.readsToday,
        FirestoreBudgetGuard.dailyReadWarnThreshold * 3,
      );
      // Okuma çok olsa bile yazma freni bundan etkilenmez.
      expect(guard.isWriteBlocked, isFalse);
      expect(await guard.allowWrite(), isTrue);
    });

    test('Okuma ve yazma sayaçları bağımsızdır', () async {
      await guard.recordRead(count: 50);
      await guard.allowWrite(count: 3);

      expect(guard.readsToday, 50);
      expect(guard.writesToday, 3);
    });
  });

  group('Kalıcılık ve gün döngüsü', () {
    test('Sayaçlar diskte saklanır', () async {
      await guard.allowWrite(count: 7);
      await guard.recordRead(count: 11);

      final prefs = await PrefsService.instance();
      expect(prefs?.getInt('sinifcepte_budget_writes'), 7);
      expect(prefs?.getInt('sinifcepte_budget_reads'), 11);
    });

    test('Yeni gün sayaçları sıfırlar (dünün freni devretmez)', () async {
      // Dün tavana ulaşılmış gibi davran: eski tarih + dolu sayaç.
      SharedPreferences.setMockInitialValues({
        'sinifcepte_budget_date': '2020-01-01',
        'sinifcepte_budget_writes': FirestoreBudgetGuard.dailyWriteLimit,
        'sinifcepte_budget_reads': 9999,
      });
      PrefsService.resetCache();

      // setUp'taki reset() belleği "yüklendi" işaretler; diskteki eski
      // tarihin gerçekten okunduğunu görmek için önbelleği boşaltıyoruz.
      guard.invalidateCache();

      // allowWrite ilk çağrıda tarihi kontrol edip sayaçları sıfırlamalı.
      expect(await guard.allowWrite(), isTrue,
          reason: 'dün dolan tavan bugünü engellememeli');
      expect(guard.writesToday, 1);
      expect(guard.readsToday, 0);
    });

    test('Özet metni sayıları içerir', () async {
      await guard.allowWrite(count: 4);
      await guard.recordRead(count: 9);

      expect(guard.summary, contains('9'));
      expect(guard.summary, contains('4'));
      expect(
        guard.summary,
        contains('${FirestoreBudgetGuard.dailyWriteLimit}'),
      );
    });
  });

  group('Sınır değerleri', () {
    test('Yazma tavanı gerçekçi kullanımın çok üzerinde', () {
      // Maliyet planı: kullanıcı başına günde ~2 yazma bekleniyor.
      // Tavan bunun en az 50 katı olmalı ki normal kullanım engellenmesin.
      expect(FirestoreBudgetGuard.dailyWriteLimit, greaterThanOrEqualTo(100));
    });

    test('Okuma uyarısı yazma tavanından yüksek', () {
      // Okuma doğal olarak daha sık; eşik ona göre olmalı.
      expect(
        FirestoreBudgetGuard.dailyReadWarnThreshold,
        greaterThan(FirestoreBudgetGuard.dailyWriteLimit),
      );
    });
  });
}
