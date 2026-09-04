import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/outcomes/data/models/curriculum_outcome_model.dart';
import 'package:sinifcepte/features/outcomes/presentation/widgets/outcome_carousel_card.dart';

/// Kart taşma (overflow) korumaları.
///
/// MEB öğretim programı anlatımı eklendikten sonra carousel kartı
/// "BOTTOM OVERFLOWED BY 191 PIXELS" hatası veriyordu: gövdenin yalnızca
/// kazanım metni kaydırılabilirdi, Maarif kutuları sabit alanda kalıyordu.
void main() {
  CurriculumOutcomeModel buildOutcome({
    String? officialActivity,
    String description = 'Kısa kazanım',
  }) {
    return CurriculumOutcomeModel(
      docId: 'test_1',
      gradeLevel: 5,
      subjectCode: 'BILISIM',
      subjectName: 'Bilişim Teknolojileri ve Yazılım',
      publisher: 'TYMM (Maarif Modeli)',
      weekNumber: 1,
      unitTitle: 'Bilişim Teknolojilerinin Hayatımızdaki Yeri',
      topicTitle: 'Bilişim Teknolojilerinin Sınıflandırılması',
      outcomeCode: 'BTY.5.1.1',
      outcomeDescription: description,
      officialActivity: officialActivity,
      maarifSummary:
          "Bu hafta 'Bilişim Teknolojilerinin Sınıflandırılması' konusu; "
          'algoritmik düşünme, tasarım odaklı problem çözme ve dijital '
          'üretim etkinlikleriyle uygulamalı olarak işlenir.',
      maarifValues: 'Dijital Etik, Üretkenlik, İş Birliği, Sorumluluk',
      maarifSkills:
          'AB6 Algoritmik Düşünme, KB2.16 Dijital Üretim, SDB2.3 Takım Çalışması',
      differentiation:
          'Aşamalı blok/metin kodlama görevleri ve proje temelli grup '
          'çalışmalarıyla uygulanır.',
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    CurriculumOutcomeModel outcome, {
    required bool isCarousel,
    Size size = const Size(390, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Gerçek kullanımı taklit et: carousel kartı sabit yükseklikli bir
    // PageView içinde, liste kartı ise kaydırılabilir ListView içinde
    // (yükseklik kısıtı YOK) yaşar.
    final Widget card = OutcomeCarouselCard(
      outcome: outcome,
      isCarousel: isCarousel,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: isCarousel
                ? SizedBox(height: 460, child: card)
                : ListView(children: [card]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // MEB anlatımları ortalama ~530 karakter; en uzunu 602.
  const longActivity =
      'Günlük Yaşamda Kullanılan Bilişim Teknolojilerini Sınıflandırabilme '
      'Öğrencilere “bilişim teknolojileri” terimi hakkında ne düşündükleri '
      'sorularak beyin fırtınası yapılır. Tahtaya, öğrencilerin bilişim '
      'teknolojileri ile ilgili düşünceleri yazılır. Bu aşamada, öğrenciler '
      'günlük hayatlarında karşılaştıkları bilişim teknolojilerini belirleyerek '
      'örnekler verir. Ardından öğretmen, bilişim teknolojilerine ilişkin temel '
      'kavramları (iletişim, bilgi, bilişim, teknoloji, BİT) tanıtır. Grup '
      'çalışması becerilerini geliştirmek amacıyla öğrenciler küçük gruplara '
      'ayrılır ve her gruptan bir sunum hazırlaması istenir.';

  group('OutcomeCarouselCard taşma testleri', () {
    testWidgets('KRİTİK: uzun MEB anlatımıyla carousel kartı taşmaz',
        (tester) async {
      await pumpCard(
        tester,
        buildOutcome(officialActivity: longActivity),
        isCarousel: true,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dar ekranda da taşma olmaz', (tester) async {
      await pumpCard(
        tester,
        buildOutcome(officialActivity: longActivity),
        isCarousel: true,
        size: const Size(320, 600),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Uzun kazanım metni + MEB anlatımı birlikte taşmaz',
        (tester) async {
      await pumpCard(
        tester,
        buildOutcome(
          officialActivity: longActivity,
          description: 'BTY.5.1.1. ${'Uzun kazanım açıklaması. ' * 20}',
        ),
        isCarousel: true,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Liste görünümü de taşmaz', (tester) async {
      await pumpCard(
        tester,
        buildOutcome(officialActivity: longActivity),
        isCarousel: false,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('MEB anlatımı yoksa kart yine çalışır', (tester) async {
      await pumpCard(tester, buildOutcome(), isCarousel: true);
      expect(tester.takeException(), isNull);
    });
  });

  group('MEB anlatımı görünümü', () {
    testWidgets('Uzun metin kısaltılır ve "Devamını oku" gösterilir',
        (tester) async {
      await pumpCard(
        tester,
        buildOutcome(officialActivity: longActivity),
        isCarousel: false,
      );
      expect(find.text('MEB ÖĞRETİM PROGRAMI · DERS İŞLENİŞİ'), findsOneWidget);
      expect(find.text('Devamını oku'), findsOneWidget);
    });

    testWidgets('Dokununca tamamı açılır', (tester) async {
      await pumpCard(
        tester,
        buildOutcome(officialActivity: longActivity),
        isCarousel: false,
      );
      await tester.tap(find.text('Devamını oku'));
      await tester.pump();
      expect(find.text('Daha az göster'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
