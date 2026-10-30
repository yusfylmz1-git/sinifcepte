import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Zamanlı bildirimin kipi ile manifestteki izinler birlikte değişmeli.
///
/// 19 Eylül: kod kesin kip kullanıyordu, manifestte izin yoktu; sınav
/// hatırlatması hata vermeden hiç gelmiyordu. 30 Ekim: kesin kip ve
/// USE_EXACT_ALARM kalktı (Play bu izni yalnız alarm saati ve takvim
/// uygulamalarına veriyor; tek bildirim "24 saat kala" uyarısı).
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  bool izinVar(String ad) =>
      RegExp('<uses-permission[^>]*android:name="android\\.permission\\.$ad"')
          .hasMatch(manifest);

  test('KRITIK: hicbir bildirim kesin kiple zamanlanmiyor', () {
    final kesinKip = RegExp(r'AndroidScheduleMode\.(exact\w*|alarmClock)');
    final bulunan = <String>[];
    for (final dosya in Directory('lib').listSync(recursive: true)) {
      if (dosya is! File || !dosya.path.endsWith('.dart')) continue;
      final kod = dosya.readAsStringSync();
      for (final m in kesinKip.allMatches(kod)) {
        bulunan.add('${dosya.path}: ${m.group(0)}');
      }
    }
    expect(bulunan, isEmpty,
        reason: 'kesin kip izin ister; izinsiz Android 12+ alarmı sessizce '
            'kurmaz, USE_EXACT_ALARM ise Play beyanı ister');
  });

  test('KRITIK: Play kisitli kesin alarm izinleri manifestte yok', () {
    expect(izinVar('USE_EXACT_ALARM'), isFalse);
    expect(izinVar('SCHEDULE_EXACT_ALARM'), isFalse);
  });

  test('yeniden baslatmada hatirlatmalar geri kuruluyor', () {
    // Kesin olmayan alarm da yeniden başlatmada silinir.
    expect(izinVar('RECEIVE_BOOT_COMPLETED'), isTrue);
    final alici = RegExp(
      r'<receiver\s+android:name="com\.dexterous\.flutterlocalnotifications'
      r'\.ScheduledNotificationBootReceiver"\s+android:enabled="true"',
    );
    expect(alici.hasMatch(manifest), isTrue,
        reason: 'eklentinin alıcısı varsayılan olarak kapalı geliyor');
  });

  test('bildirim izni isteniyor (Android 13+)', () {
    expect(izinVar('POST_NOTIFICATIONS'), isTrue);
  });
}
