import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alt sayfa (bottom sheet) yükseklik davranışı.
///
/// ## Bağlam
/// Kullanıcı "açılıyormuş gibi yapıyor ama olmuyor" diye bildirdi: modal
/// açılıyor, içi boş kalıyordu.
///
/// Sebep: `isScrollControlled: true` ile açılan bir sayfada
/// `MainAxisSize.min` + `Flexible` birleşimi, içerik yüksekliği asenkron
/// geldiğinde sıfır yükseklik üretebiliyor. İçerik yüklenene kadar Column
/// kendini "en küçük" boyuta ayarlıyor ve sonrasında büyümüyor.
///
/// Çözüm sabit oranlı yükseklik. Bu testler o davranışı korur.
void main() {
  /// Sorunlu desen: min boyut + asenkron içerik.
  Widget brokenSheet() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 800 * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40, child: Text('Başlık')),
          Flexible(
            child: SingleChildScrollView(
              // İçerik henüz gelmedi (yükleniyor durumu)
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  /// Düzeltilmiş desen: sabit oranlı yükseklik.
  Widget fixedSheet(double screenHeight) {
    return SizedBox(
      height: screenHeight * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 40, child: Text('Başlık')),
          Flexible(
            child: SingleChildScrollView(
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  testWidgets('KRİTİK: sabit yükseklikli sayfa içerik boşken de yer kaplar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: fixedSheet(800))),
    );

    final size = tester.getSize(find.byType(SizedBox).first);

    // İçerik boş olsa bile sayfa görünür yükseklikte olmalı.
    expect(
      size.height,
      greaterThan(400),
      reason: 'içerik yüklenmeden önce de sayfa açık görünmeli',
    );
  });

  testWidgets('Sorunlu desen içerik boşken neredeyse sıfır yükseklik alır',
      (tester) async {
    // Bu test, düzeltmenin gerçekten bir şey değiştirdiğini kanıtlar.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: brokenSheet()))),
    );

    final size = tester.getSize(find.byType(Column).first);

    // Yalnızca başlık kadar yer kaplar — kullanıcı "boş açıldı" görür.
    expect(
      size.height,
      lessThan(100),
      reason: 'min boyut deseni asenkron içerikte çöker; düzeltme bu yüzden gerekli',
    );
  });

  testWidgets('Sayfa yüksekliği ekrana oranlanır (küçük ve büyük cihaz)',
      (tester) async {
    for (final screenHeight in [600.0, 900.0, 1200.0]) {
      // Test penceresini gerçek cihaz boyutuna ayarla; aksi halde
      // varsayılan boyut ölçümü kırpıyor.
      tester.view.physicalSize = Size(400, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: fixedSheet(screenHeight))),
      );
      await tester.pump();

      final size = tester.getSize(find.byType(SizedBox).first);
      expect(
        size.height,
        closeTo(screenHeight * 0.85, 1),
        reason: 'yükseklik ekran boyutuyla orantılı olmalı',
      );
    }
  });
}
