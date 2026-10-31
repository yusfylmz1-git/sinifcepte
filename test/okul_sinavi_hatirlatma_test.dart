import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/services/notification_service.dart';
import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/data/repositories/exam_operations_repository.dart';
import 'package:sinifcepte/features/exam_operations/data/services/exam_sync_service.dart';
import 'package:sinifcepte/features/exam_operations/providers/exam_tracking_provider.dart';

/// Okul sınavı hatırlatması (31 Ekim 2026).
///
/// "Okulum" ekleme penceresi "Sınav gününe 24 saat kala otomatik alarm
/// bildirimi kurulacaktır" diyordu, düğmenin adı "Takvime Kaydet & Bildirim
/// Kur"du; oysa hiçbir bildirim kurulmuyordu ve okul sınavında ⭐ yoktu.
/// Telefon testinde öğretmen fark etti. Şimdi okul sınavı favori olarak
/// başlıyor, hatırlatma bir gün önce sabah çalıyor, silinince iptal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'okul_sinavi_hatirlatma_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.resetForTests();
  });

  group('Hatırlatma anı', () {
    test('KRITIK: saatsiz sınav bir gün önce sabah 08.00, gece yarısı değil', () {
      expect(NotificationService.sinavGunuHatirlatmaAni(DateTime(2026, 11, 11)),
          DateTime(2026, 11, 10, 8));
    });

    test('ay başındaki sınav önceki ayın son günü hatırlatılır', () {
      expect(NotificationService.sinavGunuHatirlatmaAni(DateTime(2026, 12, 1)),
          DateTime(2026, 11, 30, 8));
      expect(NotificationService.sinavGunuHatirlatmaAni(DateTime(2027, 1, 1)),
          DateTime(2026, 12, 31, 8));
    });

    test('saati bilinen sınav tam 24 saat önce', () {
      expect(NotificationService.sinavGunuHatirlatmaAni(DateTime(2026, 11, 22, 10, 15)),
          DateTime(2026, 11, 21, 10, 15));
    });
  });

  group('Okul sınavı favorisi', () {
    ExamModel okulSinavi(String id) => ExamModel(
          id: id,
          title: '5-A Matematik 1. Yazılı',
          examDate: DateTime(2030, 3, 10),
          category: 'OKUL',
          isSchoolExam: true,
          className: '5-A',
        );

    test('KRITIK: verilen kimlik korunur, favori ona bağlanır', () async {
      final repo = ExamOperationsRepository();
      await repo.addSchoolExam(okulSinavi('okul_123'));
      await repo.setFavorite('okul_123', true);

      final okul = (await repo.getAllExams()).where((e) => e.isSchoolExam).single;
      expect(okul.id, 'okul_123');
      expect(okul.isFavorite, isTrue);

      await repo.setFavorite('okul_123', false);
      final sonra = (await repo.getAllExams()).where((e) => e.isSchoolExam).single;
      expect(sonra.isFavorite, isFalse);
    });

    test('KRITIK: eklenen okul sınavı favori başlar, silinince favori kaydı kalmaz', () async {
      final notifier = ExamTrackingNotifier(ExamOperationsRepository(), ExamSyncService());
      await notifier.loadExams();

      expect(
          await notifier.addSchoolExam(
              title: '6-B Türkçe 1. Yazılı', examDate: DateTime(2030, 3, 10), className: '6-B'),
          isTrue);
      final okul = notifier.state.schoolExams.single;
      expect(okul.isFavorite, isTrue, reason: 'pencere "hatırlatma gelir" diyor');
      expect(notifier.state.favoriteExams.map((e) => e.id), contains(okul.id));

      await notifier.deleteSchoolExam(okul.intId!);
      final db = await DatabaseHelper.instance.database;
      expect(await db.query('favori_sinavlar', where: 'doc_id = ?', whereArgs: [okul.id]), isEmpty);
      expect(notifier.state.schoolExams, isEmpty);
    });
  });
}
