import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/features/academic_calendar/providers/academic_calendar_provider.dart';
import 'package:sinifcepte/features/classes/providers/class_provider.dart';

/// Okuma sürerken sağlayıcı kapanırsa (hesap değişince `invalidate`,
/// ekran kapanınca) okuma bitince kapanmış nesneye yazılmamalı.
///
/// ## Neden bu test var (18 Ekim 2026)
/// Sınıf listesi ve çalışma takvimi okumaları bittiğinde koşulsuz
/// `state =` yazıyordu. Sağlayıcı o arada kapanmışsa "Tried to use
/// ClassListNotifier after dispose" hatası düşüyordu; tam test takımında
/// yük altında üç ayrı testi "bittikten sonra" kırdı. Uygulamada da hesap
/// değiştirirken aynı yarış var.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'saglayici_kapaninca_yazmaz_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.resetForTests();
  });

  test('KRITIK: sınıf listesi okunurken kapanırsa hata düşmez', () async {
    final kap = ProviderContainer();
    kap.read(classListProvider); // okuma başlar
    kap.dispose(); // okuma bitmeden kapanır
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });

  test('KRITIK: çalışma takvimi okunurken kapanırsa hata düşmez', () async {
    final kap = ProviderContainer();
    kap.read(academicCalendarProvider);
    kap.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
}
