import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/shared/widgets/liste_arama_kutusu.dart';

/// Listelerde öğrenci arama (26 Ekim 2026).
///
/// ## Neden bu testler var
/// Kullanıcı: "BEP raporunda ve artı-eksi listesinde öğrenci arama yok…
/// Herhangi bir liste varsa arama kutusu olması işleri hızlandırır."
/// Otuz kişilik sınıfta öğretmen tek tek kaydırıyordu. Bütün listeler
/// aynı kutuyu ve aynı eşleşmeyi kullanır; biri unutulursa kaynak
/// denetimi yakalar.
void main() {
  group('aramayaUyar', () {
    test('boş arama her satıra uyar', () {
      expect(aramayaUyar('', ['Ali YILMAZ']), isTrue);
      expect(aramayaUyar('   ', ['Ali YILMAZ']), isTrue);
    });

    test('Türkçe harf yazmadan bulur, büyük/küçük harf fark etmez', () {
      expect(aramayaUyar('isil', ['Işıl DEMİR']), isTrue);
      expect(aramayaUyar('GULSAH', ['Gülşah Öz']), isTrue);
      expect(aramayaUyar('çağ', ['CAGLA Ak']), isTrue);
    });

    test('sözcükler ayrı aranır, sıra önemli değil', () {
      expect(aramayaUyar('yilmaz ali', ['Ali YILMAZ']), isTrue);
      expect(aramayaUyar('ali kaya', ['Ali YILMAZ']), isFalse);
    });

    test('rakam okul numarasında aranır', () {
      expect(aramayaUyar('12', ['Ali YILMAZ'], numara: 312), isTrue);
      expect(aramayaUyar('7', ['Ali YILMAZ'], numara: 312), isFalse);
      expect(aramayaUyar('0', ['Ali YILMAZ']), isFalse, reason: 'numarasız öğrencide 0 uymaz');
    });

    test('birden çok alanda arar (öğrenci ve veli adı)', () {
      expect(aramayaUyar('fatma', ['Ali YILMAZ', 'Anne: Fatma YILMAZ']), isTrue);
    });
  });

  group('ListeAramaKutusu', () {
    testWidgets('yazdıkça bildirir, çarpı temizler', (tester) async {
      var son = '-';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ListeAramaKutusu(onChanged: (v) => son = v)),
      ));
      expect(find.byTooltip('Aramayı temizle'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('liste_arama')), 'ali');
      await tester.pump();
      expect(son, 'ali');

      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pump();
      expect(son, '');
      expect(find.byTooltip('Aramayı temizle'), findsNothing);
    });

    testWidgets('aranabilir seçim: süzer, seçileni ve boş seçeneği döndürür', (tester) async {
      ({String? oge})? sonuc;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                sonuc = await aranabilirSec<String>(
                  context,
                  baslik: 'Öğrenci seç',
                  ogeler: const ['Ali YILMAZ', 'Ayşe KAYA', 'Işıl DEMİR'],
                  etiket: (s) => s,
                  bosSecenek: 'Boş şablon',
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text('Boş şablon'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('liste_arama')), 'isil');
      await tester.pump();
      expect(find.text('Ali YILMAZ'), findsNothing);
      expect(find.text('Boş şablon'), findsNothing, reason: 'arama varken yalnız sonuçlar');
      await tester.tap(find.text('Işıl DEMİR'));
      await tester.pumpAndSettle();
      expect(sonuc?.oge, 'Işıl DEMİR');

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boş şablon'));
      await tester.pumpAndSettle();
      expect(sonuc, isNotNull);
      expect(sonuc!.oge, isNull);
    });
  });

  group('KRITIK: öğrenci listelerinde arama kutusu var', () {
    // Kullanıcının saydığı iki liste ve aynı sorunu taşıyan diğerleri.
    const listeler = {
      'Artı-eksi listesi': 'lib/features/attendance/presentation/views/arti_eksi_listesi_view.dart',
      'BEP hedef takibi': 'lib/features/bep/presentation/views/bep_list_view.dart',
      'Quiz & sözlü çizelgesi': 'lib/features/exam_operations/presentation/views/quiz_list_view.dart',
      'Soru analizi not girişi': 'lib/features/analytics/presentation/views/exam_analysis_editor_view.dart',
      'Soru analizi sonuç listesi': 'lib/features/analytics/presentation/views/exam_analysis_detail_view.dart',
      'Kulübe üye ekleme': 'lib/features/clubs/presentation/widgets/club_member_picker_sheet.dart',
      'Velilerle yazışmalar': 'lib/features/parent_portal/presentation/screens/sinif_velileri_ekrani.dart',
      'Veli gelen kutusu': 'lib/features/parent_portal/presentation/screens/gelen_kutusu_ekrani.dart',
    };
    for (final e in listeler.entries) {
      test(e.key, () {
        final kaynak = File(e.value).readAsStringSync();
        expect(kaynak.contains('ListeAramaKutusu('), isTrue, reason: '${e.key}: arama kutusu yok');
        expect(kaynak.contains('aramayaUyar('), isTrue, reason: '${e.key}: liste aramayla süzülmüyor');
      });
    }

    test('görüşme formunda öğrenci açılır listeden değil aranarak seçilir', () {
      final kaynak = File('lib/features/classes/presentation/widgets/counseling_interview_modal.dart').readAsStringSync();
      expect(kaynak.contains('DropdownButton<StudentModel?>'), isFalse);
      expect(kaynak.contains('aranabilirSec<StudentModel>('), isTrue);
    });
  });
}
