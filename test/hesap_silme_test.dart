import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/account/hesap_silme_servisi.dart';
import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/auth_profile/presentation/screens/hesap_silme_ekrani.dart';
import 'package:sinifcepte/features/student_photos/data/foto_depolama.dart';

/// "Hesabımı sil": bulut çağrısı, telefondaki veri, onay ekranı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'hesap_silme_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const uid = 'ogretmenAAAAAAAAAAAA1';
  const baskaUid = 'ogretmenBBBBBBBBBBBB2';

  group('bulut çağrısı', () {
    test('KRITIK: çağrılabilir fonksiyon biçiminde, jeton ve onayla gider', () async {
      late http.Request giden;
      final servis = HesapSilmeServisi(
        projeKimligi: 'sinifcepte',
        kimlikJetonu: () async => 'jeton123',
        istemci: MockClient((r) async {
          giden = r;
          return http.Response(jsonEncode({'result': {'ok': true, 'sinif': 1, 'belge': 3}}), 200);
        }),
      );

      expect(await servis.buluttanSil(), isA<HesapSilindi>());
      expect(giden.url.toString(), 'https://europe-west1-sinifcepte.cloudfunctions.net/hesabimiSil');
      expect(giden.headers['Authorization'], 'Bearer jeton123');
      expect(jsonDecode(giden.body), {
        'data': {'onay': 'SİL'},
      });
    });

    test('sunucu reddederse silinmedi sayılır', () async {
      final servis = HesapSilmeServisi(
        projeKimligi: 'sinifcepte',
        kimlikJetonu: () async => 'jeton',
        istemci: MockClient((_) async => http.Response(
            jsonEncode({'error': {'status': 'UNAUTHENTICATED', 'message': 'x'}}), 401)),
      );
      expect(await servis.buluttanSil(), isA<HesapSilinemedi>());
    });

    test('oturum yoksa istek hiç gitmez', () async {
      var gitti = false;
      final servis = HesapSilmeServisi(
        projeKimligi: 'sinifcepte',
        kimlikJetonu: () async => null,
        istemci: MockClient((_) async {
          gitti = true;
          return http.Response('{}', 200);
        }),
      );
      expect(await servis.buluttanSil(), isA<HesapSilinemedi>());
      expect(gitti, isFalse);
    });

    test('internet yoksa ne yapacağını söyler', () async {
      final servis = HesapSilmeServisi(
        projeKimligi: 'sinifcepte',
        kimlikJetonu: () async => 'jeton',
        istemci: MockClient((_) async => throw const SocketException('yok')),
      );
      final s = await servis.buluttanSil();
      expect(s, isA<HesapSilinemedi>());
      expect((s as HesapSilinemedi).mesaj, contains('İnternet'));
    });
  });

  group('telefondaki öğretmen verisi', () {
    late Directory gecici;

    setUp(() async {
      gecici = await Directory.systemTemp.createTemp('hesap_silme');
      SharedPreferences.setMockInitialValues({
        'profil_okul__$uid': 'Atatürk Ortaokulu',
        'profil_ad__$uid': 'Ayşe',
        'profil_okul__$baskaUid': 'Gazi Lisesi',
        'app_theme_mode': 'dark',
        DatabaseHelper.lastUidKey: uid,
      });
      PrefsService.resetCache();
    });

    tearDown(() async {
      await DatabaseHelper.instance.closeConnection();
      if (await gecici.exists()) await gecici.delete(recursive: true);
    });

    test('KRITIK: veritabanı, fotoğraflar ve hesabın ayarları silinir; başka hesap kalır', () async {
      await DatabaseHelper.instance.openForUid(uid);
      final dbYolu = p.join(await getDatabasesPath(), AppConfig.teacherDbName(uid));
      expect(File(dbYolu).existsSync(), isTrue);

      final depo = FotoDepolama(Directory(p.join(gecici.path, 'student_photos')));
      final benim = depo.hesapDizini(FotoDepolama.hesapAlani(AppConfig.teacherDbName(uid)));
      final baskasi = depo.hesapDizini(FotoDepolama.hesapAlani(AppConfig.teacherDbName(baskaUid)));
      await File(p.join(benim.path, '7', 'f1', 'standard.jpg')).create(recursive: true);
      await File(p.join(baskasi.path, '9', 'f2', 'standard.jpg')).create(recursive: true);

      await HesapSilmeServisi.ogretmenVerisiniSil(uid, fotolar: depo);

      expect(File(dbYolu).existsSync(), isFalse);
      expect(benim.existsSync(), isFalse);
      expect(baskasi.existsSync(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profil_okul__$uid'), isNull);
      expect(prefs.getString('profil_ad__$uid'), isNull);
      expect(prefs.getString(DatabaseHelper.lastUidKey), isNull);
      expect(prefs.getString('profil_okul__$baskaUid'), 'Gazi Lisesi');
      expect(prefs.getString('app_theme_mode'), 'dark');
    });
  });

  group('onay ekranı', () {
    Future<void> ac(WidgetTester tester, HesapSilmeServisi servis, {HesapRolu rol = HesapRolu.ogretmen}) async {
      // ListView görünmeyeni kurmaz: onay alanı ve düğme ekranda olsun.
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: HesapSilmeEkrani(rol: rol, servis: servis, uid: uid)),
      ));
    }

    FilledButton dugme(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('hesap_sil_dugme')));

    testWidgets('KRITIK: SİL yazılmadan düğme çalışmaz; küçük harfle de olur', (tester) async {
      await ac(tester, HesapSilmeServisi(kimlikJetonu: () async => null, projeKimligi: 'x'));
      expect(dugme(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('hesap_sil_onay')), 'si');
      await tester.pump();
      expect(dugme(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('hesap_sil_onay')), 'sil');
      await tester.pump();
      expect(dugme(tester).onPressed, isNotNull);
    });

    testWidgets('KRITIK: bulut silinemezse telefondaki veriye dokunulmaz, sebep yazılır', (tester) async {
      SharedPreferences.setMockInitialValues({'profil_okul__$uid': 'Atatürk Ortaokulu'});
      PrefsService.resetCache();
      final servis = HesapSilmeServisi(
        projeKimligi: 'sinifcepte',
        kimlikJetonu: () async => 'jeton',
        istemci: MockClient((_) async => http.Response('{}', 500)),
      );
      await ac(tester, servis);
      await tester.enterText(find.byKey(const ValueKey('hesap_sil_onay')), 'SİL');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('hesap_sil_dugme')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.byKey(const ValueKey('hesap_sil_hata')), findsOneWidget);
      expect(find.byType(HesapSilmeEkrani), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profil_okul__$uid'), 'Atatürk Ortaokulu');
    });

    testWidgets('silinenler role göre sayılır', (tester) async {
      await ac(tester, HesapSilmeServisi(kimlikJetonu: () async => null, projeKimligi: 'x'), rol: HesapRolu.veli);
      expect(find.textContaining('Çocuklarınızla kurduğunuz bağlantılar'), findsOneWidget);
      expect(find.textContaining('bağlantı kodları'), findsNothing);
    });
  });

  test('KRITIK: öğretmenin Profil sekmesinde ve velinin profilinde giriş var', () {
    final ogretmen = File('lib/features/profile/screens/profile_screen.dart').readAsStringSync();
    final veli = File('lib/features/parent_portal/presentation/views/parent_profile_view.dart').readAsStringSync();
    expect(ogretmen, contains('HesapSilmeEkrani(rol: HesapRolu.ogretmen)'));
    expect(veli, contains('HesapSilmeEkrani(rol: HesapRolu.veli)'));
  });
}
