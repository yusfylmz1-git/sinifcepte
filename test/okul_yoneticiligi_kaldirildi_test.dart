import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/profile/screens/profile_screen.dart';

/// Sadeleştirme 5b: telefondaki okul yöneticiliği ve şikâyet incelemesi
/// kalktı (kullanıcı kararı, 17-18 Ekim 2026).
///
/// ## Neden bu testler var
/// Öğretmen önce yöneticilik başvurusu yapıyor, süper admin bir betikle
/// onaylıyor, sonra panel açılıyordu. Panelde iki sekme vardı ve ikisi de
/// iş görmüyordu:
///   * "Öğretmen Onayı" öğretmen doğrulamıyordu; yalnızca aynı okulun
///     başka yöneticilik başvurularını salt okunur listeliyordu.
///     "Okul idaresince doğrulandı" rozetini veren kod hiç yoktu.
///   * "Şikâyetler" hep boştu: bulut şikâyeti gönderen hiçbir yol
///     bağlanmamıştı.
/// Okul yönetimi masaüstü Ana Program'da. Bu testler parçaların geri
/// gelmesini engeller.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Yorum satırları atılmış kod: yorumlar kaldırılanı anlatabilir.
  String yorumsuz(String icerik) => icerik
      .split('\n')
      .where((s) => !s.trimLeft().startsWith('//'))
      .join('\n');

  List<(String, String)> kaynaklar() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) =>
          (f.path.replaceAll('\\', '/'), yorumsuz(f.readAsStringSync())))
      .toList();

  test('KRITIK: yöneticilik ve şikâyet dosyaları silindi', () {
    for (final yol in [
      'lib/features/auth_profile/presentation/views/school_admin_panel_view.dart',
      'lib/features/auth_profile/presentation/views/school_admin_request_view.dart',
      'lib/features/auth_profile/data/repositories/school_admin_repository.dart',
      'lib/features/auth_profile/data/models/school_admin_request_model.dart',
      'lib/features/auth_profile/data/services/auth_claims_service.dart',
      'lib/features/parent_portal/data/models/content_report_model.dart',
      'scripts/admin/approve_school_admin.mjs',
    ]) {
      expect(File(yol).existsSync(), isFalse, reason: yol);
    }
  });

  test('KRITIK: kodda yöneticilik, rozet ve şikâyet yolu kalmadı', () {
    for (final (yol, kod) in kaynaklar()) {
      for (final yasak in [
        'SchoolAdmin',
        'school_admin',
        'refreshClaims',
        'AuthClaims',
        'schoolAdminStatus',
        'content_reports',
        'reportContent',
        'getContentReports',
        'verifyTeacher',
        'isTeacherVerified',
        'isVerifiedBySchoolAdmin',
        'Okul Yöneticiliği',
        'Okul Yönetim Paneli',
        'yönetici yetkisi',
      ]) {
        expect(kod.contains(yasak), isFalse, reason: '$yol: $yasak');
      }
    }
  });

  test('sohbet yorumu var olmayan şikâyet yolunu anlatmıyor', () {
    // "şikâyet mekanizması ikinci katman olarak durur" yazıyordu; böyle
    // bir yol hiç yoktu. Yanlış yorum, eksik işi gizler.
    final s = File('lib/features/parent_portal/presentation/widgets/'
            'parent_teacher_chat_modal.dart')
        .readAsStringSync();
    expect(s.contains('ikinci katman olarak durur'), isFalse);
  });

  testWidgets('KRITIK: Ben sekmesinde yöneticilik satırı yok, Tahta Kilidi ve yedek duruyor',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    PrefsService.resetCache();
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: ProfileScreen()),
    ));
    await tester.pump();

    expect(find.text('Tahta Kilidi'), findsOneWidget);
    expect(find.text('Yedekle ve geri yükle'), findsOneWidget);
    expect(find.textContaining('Yönetici'), findsNothing);
    expect(find.textContaining('yöneticiliği'), findsNothing);
    expect(find.byIcon(Icons.verified_rounded), findsNothing,
        reason: 'hiç verilemeyen doğrulama rozeti de kalktı');
  });
}
