import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/guidance/data/models/guidance_plan_model.dart';
import 'package:sinifcepte/features/guidance/presentation/widgets/guidance_activity_sheet.dart';

/// Cepte'den açılan rehberlik etkinliği: plan satırı yok, yalnız okunur.
void main() {
  const etkinlik = GuidanceActivity(
    gradeLevel: 5,
    hafta: 7,
    etkinlikAdi: 'Duygularımı Tanıyorum',
    gelisimAlani: 'Sosyal Duygusal',
    kazanim: 'Duygularını fark eder.',
    surec: ['Öğrencilere duygu kartları dağıtılır.'],
  );

  Future<void> ac(WidgetTester tester, GuidanceActivity e) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => GuidanceActivitySheet.oku(context, e),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('okunur hâlde işaret ve not alanı yok, yeri yazıyor', (tester) async {
    await ac(tester, etkinlik);

    expect(find.text('Duygularımı Tanıyorum'), findsOneWidget);
    expect(find.text('5. sınıf · 7. hafta'), findsOneWidget);
    expect(find.text('Duygularını fark eder.'), findsOneWidget);
    expect(find.text('Öğrencilere duygu kartları dağıtılır.'), findsOneWidget);

    expect(find.text('Uygulandı olarak işaretle'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Rehberlik › Rehberlik Dosyası'), findsOneWidget);
  });

  testWidgets('okul öncesi etkinliği "0. sınıf" yazmaz', (tester) async {
    await ac(
      tester,
      const GuidanceActivity(gradeLevel: 0, hafta: 3, etkinlikAdi: 'Merhaba Okul'),
    );
    expect(find.text('Okul öncesi · 3. hafta'), findsOneWidget);
  });
}
