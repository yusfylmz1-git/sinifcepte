import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinifcepte/core/storage/prefs_service.dart';
import 'package:sinifcepte/features/board_config/data/idare_duyurusu.dart';
import 'package:sinifcepte/features/board_config/data/ogretmen_tahta_deposu.dart';
import 'package:sinifcepte/features/board_config/presentation/idare_duyurusu_karti.dart';

/// İdare duyurusu — telefon yarısı.
///
/// Ortak örnek `functions/test/veri/idare_duyurusu_ornek.json`: sunucu
/// (Node) ve Ana Program (Python) aynı imzayı üretiyor; telefon onu
/// doğrulamalı, tek harf değişince reddetmeli.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ornek = jsonDecode(File('functions/test/veri/idare_duyurusu_ornek.json').readAsStringSync())
      as Map<String, dynamic>;
  final d = ornek['duyuru'] as Map<String, dynamic>;
  final acik = base64.decode(ornek['acik'] as String);
  final anahtarUrl = (ornek['acikB64Url'] as String);

  Map<String, dynamic> belge([Map<String, dynamic> ek = const {}]) =>
      {...d, 'imza': ornek['imza'], 'acik': ornek['acik'], ...ek};

  group('imza', () {
    test('KRITIK: Ana Program\'ın imzaladığı duyuru doğrulanır', () {
      final s = IdareDuyurusu.dogrula(belge(), acik: acik, okulId: 'meb_775214');
      expect(s, isNotNull);
      expect(s!.baslik, 'Öğretmenler kurulu');
      expect(s.mesaj, _hex(ornek['mesajHex'] as String));
    });

    test('KRITIK: tek harfi değişen, başka okulun ya da başka anahtarın duyurusu reddedilir', () {
      for (final ek in [
        {'metin': '${d['metin']}!'},
        {'baslik': 'Öğretmenler Kurulu'},
        {'bitis': (d['bitis'] as int) + 1},
        {'imza': base64.encode(List.filled(64, 1))},
      ]) {
        expect(IdareDuyurusu.dogrula(belge(ek), acik: acik, okulId: 'meb_775214'), isNull, reason: '$ek');
      }
      expect(IdareDuyurusu.dogrula(belge(), acik: acik, okulId: 'meb_111111'), isNull);
      expect(IdareDuyurusu.dogrula(belge(), acik: Uint8List(32), okulId: 'meb_775214'), isNull);
    });

    test('belgedeki "acik" alanına güvenilmez, karekoddaki anahtar geçerli', () {
      final sahte = belge({'acik': base64.encode(List.filled(32, 9))});
      expect(IdareDuyurusu.dogrula(sahte, acik: acik, okulId: 'meb_775214'), isNotNull);
    });

    test('kanal kimliği sunucununkiyle aynı', () {
      expect(idareKanali('meb_775214', acik), ornek['kanal']);
    });
  });

  group('karekod', () {
    const temel = 'SCT1:meb_775214:AYILMAZ:Ayse Yilmaz:JBSWY3DPEHPK3PXP';

    test('KRITIK: 7. alan Ana Program anahtarı; eski 5 ve 6 alanlı karekod da okunur', () {
      final yeni = OgretmenTahtaDeposu.qrAyristir('$temel:Ataturk Ortaokulu:$anahtarUrl')!;
      expect(yeni.anaProgramAnahtari, anahtarUrl);
      expect(yeni.okulAdi, 'Ataturk Ortaokulu');

      final adsiz = OgretmenTahtaDeposu.qrAyristir('$temel::$anahtarUrl')!;
      expect(adsiz.okulAdi, '');
      expect(adsiz.anaProgramAnahtari, anahtarUrl);

      expect(OgretmenTahtaDeposu.qrAyristir(temel)!.anaProgramAnahtari, '');
      expect(OgretmenTahtaDeposu.qrAyristir('$temel:Ataturk Ortaokulu')!.okulAdi, 'Ataturk Ortaokulu');
    });

    test('bozuk anahtar karekodu düşürmez, yalnız duyuru kanalı kapalı kalır', () {
      final k = OgretmenTahtaDeposu.qrAyristir('$temel:Okul:bozuk!!')!;
      expect(k.totpSecret, 'JBSWY3DPEHPK3PXP');
      expect(k.anaProgramAnahtari, '');
      expect(OgretmenTahtaDeposu.qrAyristir('$temel:Okul:$anahtarUrl:fazla'), isNull);
    });
  });

  group('depo', () {
    late int okuma;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      PrefsService.resetCache();
      IdareDuyurusuDeposu.onbellegiBosalt();
      okuma = 0;
      await OgretmenTahtaDeposu().qrIleKaydet(
        'SCT1:meb_775214:AYILMAZ:Ayse Yilmaz:JBSWY3DPEHPK3PXP:Ataturk Ortaokulu:$anahtarUrl',
      );
    });

    IdareDuyurusuDeposu depo(List<Map<String, dynamic>> belgeler) => IdareDuyurusuDeposu(
          kanalOku: (kanal) async {
            okuma++;
            expect(kanal, ornek['kanal']);
            return belgeler;
          },
        );

    final yayinda = DateTime.fromMillisecondsSinceEpoch(((d['olusturma'] as int) + 3600) * 1000);

    test('KRITIK: yalnız imzası tutan ve süresi içindeki duyuru görünür', () async {
      final liste = await depo([belge(), belge({'id': 'sahte', 'metin': 'Yarın okul tatil'})]).getir(simdi: yayinda);
      expect(liste.map((x) => x.id), [d['id']]);
      expect(liste.single.okulAdi, 'Ataturk Ortaokulu');

      final sonra = DateTime.fromMillisecondsSinceEpoch(((d['bitis'] as int) + 1) * 1000);
      IdareDuyurusuDeposu.onbellegiBosalt();
      expect(await depo([belge()]).getir(simdi: sonra), isEmpty);
    });

    test('"Tamam" denen duyuru bir daha görünmez', () async {
      final r = depo([belge()]);
      await r.kapat(d['id'] as String);
      expect(await r.getir(simdi: yayinda), isEmpty);
    });

    test('10 dakika içinde kanal yeniden okunmaz (maliyet)', () async {
      final r = depo([belge()]);
      await r.getir(simdi: yayinda);
      await r.getir(simdi: yayinda.add(const Duration(minutes: 5)));
      expect(okuma, 1);
      await r.getir(simdi: yayinda.add(const Duration(minutes: 11)));
      expect(okuma, 2);
    });

    test('anahtarsız (eski) karekodda kanal hiç okunmaz', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await OgretmenTahtaDeposu().qrIleKaydet('SCT1:meb_775214:AYILMAZ:Ayse Yilmaz:JBSWY3DPEHPK3PXP');
      expect(await depo([belge()]).getir(simdi: yayinda), isEmpty);
      expect(okuma, 0);
    });
  });

  testWidgets('kart başlığı ve "Tamam" gösterir; duyuru yoksa yer kaplamaz', (tester) async {
    final duyuru = IdareDuyurusu.dogrula(belge(), acik: acik, okulId: 'meb_775214', okulAdi: 'Ataturk Ortaokulu')!;
    await tester.pumpWidget(ProviderScope(
      overrides: [idareDuyurulariProvider.overrideWith((ref) async => [duyuru])],
      child: const MaterialApp(home: Scaffold(body: IdareDuyurusuKarti())),
    ));
    await tester.pump();
    expect(find.text('Öğretmenler kurulu'), findsOneWidget);
    expect(find.textContaining('İdareden · Ataturk Ortaokulu'), findsOneWidget);
    expect(find.byKey(ValueKey('idare_duyurusu_tamam_${d['id']}')), findsOneWidget);

    // Yeni kapsam: aynı ProviderScope yeniden kullanılırsa eski sonuç kalır.
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [idareDuyurulariProvider.overrideWith((ref) async => const [])],
      child: const MaterialApp(home: Scaffold(body: IdareDuyurusuKarti())),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('idare_duyurusu_karti')), findsNothing);
  });

  test('KRITIK: kart Özet\'te arama kutusunun altında', () {
    final ozet = File('lib/features/dashboard/screens/dashboard_screen.dart').readAsStringSync();
    expect(ozet.indexOf('const IdareDuyurusuKarti()'), greaterThan(ozet.indexOf('_aramaKutusu(context, isDark),')));
  });
}

Uint8List _hex(String h) =>
    Uint8List.fromList([for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]);
