import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/guidance/data/models/guidance_plan_model.dart';
import 'package:sinifcepte/features/guidance/data/repositories/guidance_plan_repository.dart';
import 'package:sinifcepte/features/guidance/presentation/widgets/guidance_activity_sheet.dart';
import 'package:sinifcepte/features/guidance/utils/rehberlik_etkinlik_pdf.dart';

/// Rehberlik etkinliği uygulama kaydı (29 Ekim 2026).
///
/// Kullanıcı: "Rehberlik dosyası her hafta çıktı alınabilir olmalı. Bizde
/// yalnız yapıldı/yapılmadı raporu var, yapılan etkinliğin çıktısını
/// vermiyoruz." Ayrıca belge ilk çıktığında ORGM PDF'inden kalan sayfa
/// numaraları ve sayfa başlıkları görüldü ("Küçük top 52",
/// "SINIF ETKİNLİKLERİ"); veri paketi temizlendi, bu test geri gelmesini önler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Veri paketinde PDF artığı yok', () {
    final paket = jsonDecode(utf8.decode(gzip.decode(
            File('assets/data/sinif_rehberlik_plani.json.gz').readAsBytesSync())))
        as Map<String, dynamic>;
    final etkinlikler = (paket['etkinlikler'] as List).cast<Map<String, dynamic>>();
    const listeler = ['onHazirlik', 'aracGerecler', 'surec', 'ozelGereksinimUyarlamalari'];
    const metinler = ['degerlendirme', 'uygulayiciyaNot'];

    test('KRITIK: madde ya da metin sayfa numarasıyla bitmiyor', () {
      final sonSayi = RegExp(r'(?:^|\s)(\d{1,3})$');
      final bozuk = <String>[];
      for (final e in etkinlikler) {
        final ks = e['kaynakSayfa'] as int? ?? 0;
        for (final a in [...listeler, ...metinler]) {
          final deger = e[a];
          for (final m in deger is List ? deger.cast<String>() : [deger as String? ?? '']) {
            final s = sonSayi.firstMatch(m.trim());
            if (s != null) {
              final n = int.parse(s.group(1)!);
              if (n >= ks - 1 && n <= ks + 12) bozuk.add('${e['etkinlikAdi']}: …${m.substring(m.length > 40 ? m.length - 40 : 0)}');
            }
          }
        }
      }
      expect(bozuk, isEmpty, reason: bozuk.take(5).join('\n'));
    });

    test('KRITIK: sayfa başlığı ve sonraki bölümün başlığı metne karışmamış', () {
      final bozuk = <String>[];
      for (final e in etkinlikler) {
        for (final a in listeler) {
          for (final m in (e[a] as List).cast<String>()) {
            if (RegExp(r'^(\d*\.?\s*HAFTA|(\d+\.\s*)?SINIF ETKİNLİKLERİ)$').hasMatch(m.trim()) ||
                m.contains('Süreç (Uygulama Basamakları)')) {
              bozuk.add('${e['etkinlikAdi']} [$a]: $m');
            }
          }
        }
        for (final a in metinler) {
          final m = e[a] as String? ?? '';
          if (m.startsWith(':') || m.contains('Süreç (Uygulama Basamakları)')) bozuk.add('${e['etkinlikAdi']} [$a]');
        }
      }
      expect(bozuk, isEmpty, reason: bozuk.take(5).join('\n'));
    });

    test('temizlik üretici betikte (yeniden üretimde de uygulanır)', () {
      final betik = File('tool/build_rehberlik_dataset.py').readAsStringSync();
      expect(betik, contains('def etkinlikArtiklari('));
      expect(betik, contains('etkinlikArtiklari(temizle(eski))'));
      expect(betik, contains('etkinlikArtiklari(temizle({'));
    });

    test('hiçbir etkinliğin uygulama basamakları boşalmadı', () {
      expect(etkinlikler, hasLength(458));
      expect(etkinlikler.where((e) => (e['surec'] as List).isEmpty), isEmpty);
    });
  });

  group('Uygulama kaydı PDF', () {
    test('KRITIK: gerçek etkinlikle ve etkinliksiz haftayla belge çıkıyor', () async {
      final repo = GuidancePlanRepository();
      final plan = await repo.planFor(5);
      final hafta8 = plan.firstWhere((e) => e.uygulanabilir && e.hafta == 8);
      final etkinlik = await repo.activityFor(gradeLevel: 5, hafta: 8);
      expect(etkinlik, isNotNull);
      final b = await RehberlikEtkinlikPdf.olustur(
        haftalar: [
          (
            madde: hafta8,
            etkinlik: etkinlik,
            kayit: GuidanceLogEntry(
              classId: 1,
              academicYear: '2026-2027',
              gradeLevel: 5,
              hafta: 8,
              siraNo: hafta8.siraNo ?? 0,
              uygulandi: true,
              not: 'Sınıf istekli katıldı.',
              uygulanmaTarihi: DateTime(2026, 10, 27),
              updatedAt: DateTime(2026, 10, 27),
            ),
          ),
          (madde: hafta8, etkinlik: null, kayit: null),
        ],
        schoolName: 'Mimar Sinan Ortaokulu',
        className: '5-A',
        teacherName: 'Ayşe DEMİR',
        academicYear: '2026-2027',
      );
      expect(latin1.decode(b.sublist(0, 4)), '%PDF');
    });
  });

  group('Haftanın penceresi', () {
    // Gerçek yazı tipi: test yazı tipinde harfler kare çizilir ve satırlar
    // sahte taşma verir.
    setUpAll(() async {
      final yukleyici = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
      await yukleyici.load();
    });

    const madde = GuidancePlanItem(gradeLevel: 5, ay: 'Kasım', siraNo: 8, hafta: 8, kazanim: 'Okulun imkânlarını tanır.');
    const etkinlik = GuidanceActivity(gradeLevel: 5, hafta: 8, etkinlikAdi: 'Var mı Yok mu?', kazanim: 'Okulun imkânlarını tanır.');

    Future<void> ac(WidgetTester tester, {Future<void> Function(String)? onYazdir}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => GuidanceActivitySheet.show(
                context,
                madde: madde,
                etkinlik: etkinlik,
                kayit: null,
                onDurumDegisti: (_) {},
                onNotKaydet: (_) async {},
                onYazdir: onYazdir,
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('KRITIK: uygulama kaydı düğmesi yazılan notu verir ve pencereyi kapatır', (tester) async {
      String? gelen;
      await ac(tester, onYazdir: (not) async => gelen = not);
      await tester.enterText(find.byType(TextField), '  İki öğrenci çekingen kaldı.  ');
      await tester.ensureVisible(find.byKey(const ValueKey('rehberlik_hafta_pdf')));
      await tester.tap(find.byKey(const ValueKey('rehberlik_hafta_pdf')));
      await tester.pumpAndSettle();
      expect(gelen, 'İki öğrenci çekingen kaldı.');
      expect(find.byType(GuidanceActivitySheet), findsNothing);
    });

    testWidgets('yazdırma verilmezse düğme yok', (tester) async {
      await ac(tester);
      expect(find.byKey(const ValueKey('rehberlik_hafta_pdf')), findsNothing);
    });
  });
}
