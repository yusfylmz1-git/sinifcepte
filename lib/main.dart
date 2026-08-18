import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/ads/ad_gate.dart';
import 'core/cloud/remote_manifest_service.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/services/notification_service.dart';
import 'core/storage/prefs_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Yerel depoyu erkenden ısıt: ilk ekran açılırken platform kanalı hazır
  // olsun. Kullanıcı "öğrenciye basınca 20 saniye tepki yok" bildirdiğinde
  // sebep, SharedPreferences çağrısının hiç dönmemesiydi.
  try {
    await PrefsService.warmUp();
  } catch (e) {
    debugPrint('Yerel depo ısıtma hatası: $e');
  }

  try {
    await FirebaseBootstrap.ensureInitialized();
  } catch (e, stackTrace) {
    debugPrint('Firebase bootstrap hatası: $e\n$stackTrace');
  }

  // Türkçe yerel tarih biçimlendirmesini başlat
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e, stackTrace) {
    debugPrint('Tarih formatlama başlatma hatası: $e\n$stackTrace');
  }

  // Yerel Bildirim Servisini Başlat
  try {
    await NotificationService.instance.initialize();
  } catch (e, stackTrace) {
    debugPrint('Bildirim servisi başlatma hatası: $e\n$stackTrace');
  }

  // Reklam kapısı (Faz 1: altyapı kurulur, reklam varsayılan olarak kapalıdır)
  try {
    await AdGate.instance.initialize();
  } catch (e, stackTrace) {
    debugPrint('Reklam kapısı başlatma hatası: $e\n$stackTrace');
  }

  // Uzak yapılandırma (sürüm, bakım modu). Ücretsiz ve kotasızdır;
  // ağ yoksa güvenli varsayılanlarla devam eder.
  try {
    await RemoteManifestService.instance.initialize();
  } catch (e, stackTrace) {
    debugPrint('Uzak yapılandırma başlatma hatası: $e\n$stackTrace');
  }

  // Windows / Masaüstü için SQLite FFI Başlatması
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const ProviderScope(child: SinifCepteUygulamasi()));
}

class SinifCepteUygulamasi extends ConsumerWidget {
  const SinifCepteUygulamasi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: NotificationService.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SınıfCepte',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode, // Dinamik Tema Modu (Dark / Light / System)
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const WelcomeScreen(),
    );
  }
}


