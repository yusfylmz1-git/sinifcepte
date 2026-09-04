import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/documents/data/special_days_repository.dart';
import 'package:sinifcepte/features/documents/presentation/widgets/pano_kurgu_sheet.dart';
import 'package:sinifcepte/features/documents/utils/pano_layouts.dart';

/// Pano kurgu secim ekrani.
///
/// ## Neden bu testler var
/// Ogretmen bu ekrandan bir kurgu secip PDF aliyor. Ekranin acilmasi
/// yetmez: o gunun UYGUN kurgularini listelemeli, uymayani
/// gostermemeli ve sube adi sizdirmamalidir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final ad = utf8.decode(message!.buffer.asUint8List());
      final f = File(ad);
      if (f.existsSync()) {
        return Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData();
      }
      return null;
    });
  });

  Future<(SpecialDay, PanoContent?)> gunGetir(String ad) async {
    SpecialDaysRepository.resetCache();
    PanoContentRepository.resetCache();
    final gunler = await SpecialDaysRepository().all();
    final gun = gunler.firstWhere((g) => g.ad == ad);
    return (gun, await PanoContentRepository().forDay(ad));
  }

  Future<void> ekraniAc(
    WidgetTester tester,
    SpecialDay gun,
    PanoContent? icerik,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PanoKurguSheet(
              gun: gun,
              icerik: icerik,
              schoolName: 'Gazi İlkokulu',
              academicYear: '2026-2027',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('KRITIK: uygun kurgularin hepsi listelenir', (tester) async {
    final (gun, icerik) = await gunGetir('Kızılay Haftası');
    await ekraniAc(tester, gun, icerik);

    final uygun = PanoKurgular.uygunOlanlar(gun, icerik);
    // Sayi sabitlenmez: yeni kurgu eklendikce bu test kirilmasin.
    // Onemli olan, uygun bulunan her kurgunun listede gorunmesi.
    expect(uygun.length, PanoKurgu.values.length,
        reason: 'Kizilay tum kurgulari besliyor');

    for (final k in uygun) {
      expect(
        find.text(PanoKurgular.tanimlar[k]!.ad),
        findsOneWidget,
        reason: '${PanoKurgular.tanimlar[k]!.ad} listede yok',
      );
    }
  });

  testWidgets('KRITIK: uymayan kurgu listelenmez', (tester) async {
    // Alani bos olan kurgu listelenmez. Gun adiyla degil, bos icerikle
    // sinanir: veri zenginlestikce "su gunun su alani bos" varsayimi
    // eskiyor (bkz. pano_kurgu_test.dart'taki ayni not).
    final (gun, _) = await gunGetir('Orman Haftası');
    const icerik = PanoContent(
      ad: 'Deneme',
      kaynak: 'genel',
      ozet: 'Ozet.',
      biliyorMuydunuz: ['Bir', 'Iki', 'Uc'],
    );
    await ekraniAc(tester, gun, icerik);

    expect(
      find.text(PanoKurgular.tanimlar[PanoKurgu.onceSonra]!.ad),
      findsNothing,
      reason: 'oncesiSonrasi bos, kurgu gosterilmemeli',
    );
    expect(
      find.text(PanoKurgular.tanimlar[PanoKurgu.biliyorMuydunuz]!.ad),
      findsOneWidget,
      reason: 'olgular var, kurgu gosterilmeli',
    );
  });

  testWidgets('gun basligi ve secenek sayisi gorunur', (tester) async {
    final (gun, icerik) = await gunGetir('Öğretmenler Günü');
    await ekraniAc(tester, gun, icerik);

    expect(find.text('Öğretmenler Günü'), findsOneWidget);
    final n = PanoKurgular.uygunOlanlar(gun, icerik).length;
    expect(find.textContaining('$n pano çalışması'), findsOneWidget);
  });

  testWidgets('KRITIK: ekranda sube veya ogretmen adi gecmez',
      (tester) async {
    // Ekran bu bilgileri PARAMETRE OLARAK ALMIYOR — imza seviyesinde
    // engellenmis. Bu test o guvenceyi goruntude dogrular.
    final (gun, icerik) = await gunGetir('Cumhuriyet Bayramı');
    await ekraniAc(tester, gun, icerik);

    final metinler = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');

    expect(metinler, isNot(contains(RegExp(r'\b\d\s*[-/]\s*[A-ZÇĞİÖŞÜ]\b'))),
        reason: 'sube adi ekranda gorunmemeli');
    expect(metinler, contains('şube ve öğretmen adı basılmaz'),
        reason: 'kural ogretmene aciklanmali');
  });

  testWidgets('hazirlik istemeyen kurgu isaretlenir', (tester) async {
    final (gun, icerik) = await gunGetir('Kızılay Haftası');
    await ekraniAc(tester, gun, icerik);

    // En az bir kurgu hazirliksiz olmali; etiketi gorunmeli.
    expect(find.text('Hazırlık yok'), findsWidgets);
    expect(find.text('Öğrenci doldurur'), findsWidgets);
  });
}
