import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinifcepte/core/cloud/delta_sync_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Delta Senkron Takibi (maliyet kararı #2)', () {
    test('İlk açılışta senkron damgası yoktur — tam çekim yapılır', () async {
      final last = await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1');
      expect(last, isNull);
    });

    test('Senkron sonrası damga okunur ve güvenlik payı geriye alınır', () async {
      final now = DateTime(2026, 8, 18, 12, 0);
      await DeltaSyncTracker.instance.markSynced('ann_cls_1', at: now);

      final last = await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1');

      expect(last, isNotNull);
      // 5 dakikalık saat kayması payı geriye alınmalı: sınırdaki bir
      // dokümanı atlamaktansa iki kez okumak tercih edilir.
      expect(last, now.subtract(const Duration(minutes: 5)));
    });

    test('Çok eski senkron yok sayılır ve tam çekime dönülür', () async {
      final old = DateTime.now().subtract(const Duration(days: 45));
      await DeltaSyncTracker.instance.markSynced('ann_cls_1', at: old);

      final last = await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1');

      expect(last, isNull, reason: '30 günden eski senkron zinciri kopmuş sayılır');
    });

    test('30 gün sınırının içindeki senkron korunur', () async {
      final recent = DateTime.now().subtract(const Duration(days: 20));
      await DeltaSyncTracker.instance.markSynced('ann_cls_1', at: recent);

      final last = await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1');

      expect(last, isNotNull);
    });

    test('Farklı akışlar birbirini etkilemez', () async {
      final t = DateTime(2026, 8, 18, 9, 0);
      await DeltaSyncTracker.instance.markSynced('ann_cls_1', at: t);

      expect(await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1'), isNotNull);
      expect(await DeltaSyncTracker.instance.lastSyncOf('ann_cls_2'), isNull);
      expect(await DeltaSyncTracker.instance.lastSyncOf('msg_stu_1'), isNull);
    });

    test('Sıfırlama sonrası tam çekime dönülür', () async {
      await DeltaSyncTracker.instance.markSynced('ann_cls_1');
      expect(await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1'), isNotNull);

      await DeltaSyncTracker.instance.reset('ann_cls_1');
      expect(await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1'), isNull);
    });

    test('Bozuk damga güvenli varsayılana düşer (tam çekim)', () async {
      SharedPreferences.setMockInitialValues({
        'sinifcepte_delta_ann_cls_1': 'bu-bir-tarih-degil',
      });

      final last = await DeltaSyncTracker.instance.lastSyncOf('ann_cls_1');
      expect(last, isNull);
    });

    test('Akış adları çakışmayacak biçimde üretilir', () {
      final ann = DeltaSyncTracker.announcementsStream('cls_uidA_7');
      final msg = DeltaSyncTracker.messagesStream('stu_uidA_42');

      expect(ann, 'ann_cls_uidA_7');
      expect(msg, 'msg_stu_uidA_42');
      expect(ann, isNot(msg));
    });
  });
}
