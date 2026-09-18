/// Kurulum QR diyaloğunun yerleşim sözleşmesi.
///
/// ## Neden bu test var
///
/// "Öğretmen Ekle" düğmesi gerçek cihazda **ANR** veriyordu
/// ("SınıfCepte yanıt vermiyor"). Üç ANR kaydının üçünde de ana iş
/// parçacığı aynı yerdeydi:
///
///     main ... pthread_cond_wait
///     CPU %9.4  ← hesap yapmıyor, BEKLİYOR
///
/// Debug sürümü sebebi söyledi:
///
///     LayoutBuilder does not support returning intrinsic dimensions.
///     The relevant error-causing widget was: AlertDialog
///
/// `AlertDialog` içeriğinin **iç boyutunu** (intrinsic) sorar;
/// `QrImageView` ise içeride `LayoutBuilder` kullanıyor ve
/// `LayoutBuilder` iç boyut döndüremiyor. Debug'da assert atıyor,
/// **release'de assert kapalı olduğu için** yerleşim döngüsüne
/// girip ana iş parçacığını kilitliyordu.
///
/// ## Neden ekranın tamamı değil de diyalog
///
/// `TahtaYonetimiScreen` Firestore ve `flutter_secure_storage`
/// platform kanallarını istiyor; anlamlı bir widget testi için ağır
/// bir sahtelik katmanı gerekirdi. Kusur ise diyaloğun **yerleşim
/// yapısında**, veride değil — o yapı burada birebir kuruluyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sinifcepte/features/board_config/presentation/widgets/secret_satiri.dart';

/// Ekrandaki diyaloğun yerleşim iskeleti.
///
/// Ekrandan kopyalanmadı — **aynı yapı** kuruldu: `AlertDialog` +
/// sabit genişlikli `content` + sabit ölçülü QR. Ekran değişirse bu
/// test onu yakalamaz; yakaladığı şey yapının kendisinin geçerli
/// olduğu.
Widget _diyalog({required bool sabitOlcu, required String yuk}) {
  final qr = QrImageView(
    data: yuk,
    version: QrVersions.auto,
    size: 220,
    backgroundColor: Colors.white,
  );

  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => AlertDialog(
          title: const Text('Deneme Ogretmen'),
          content: sabitOlcu
              ? SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.white,
                        child: SizedBox(width: 220, height: 220, child: qr),
                      ),
                      const SizedBox(height: 12),
                      const Text('Öğretmen bu kodu okutmalı.'),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.white,
                      child: qr,
                    ),
                    const SizedBox(height: 12),
                    const Text('Öğretmen bu kodu okutmalı.'),
                  ],
                ),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Kapat')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // Gerçek yük: 'SCT1:okulId:KOD:Ad:secret' — ölçülen uzunluk 72.
  const yuk = 'SCT1:meb_775214:DENEME1:Deneme Ogretmen:'
      '45O6OJ5SJJTVLOD552RNFLCPONZ2U6EO';

  group('Kurulum QR diyaloğu', () {
    testWidgets('KRİTİK: sabit ölçüyle yerleşim hatası vermiyor',
        (tester) async {
      await tester.pumpWidget(_diyalog(sabitOlcu: true, yuk: yuk));
      await tester.pumpAndSettle();

      // Yerleşim istisnası atılmamalı. `takeException` bir istisna
      // varsa onu döndürür; null olması temiz demek.
      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('KRİTİK: sabit ölçü OLMADAN yerleşim hatası veriyor',
        (tester) async {
      // Bu test, düzeltmenin gerçekten bir şey düzelttiğini kanıtlıyor.
      // Geçmesi, `SizedBox` sarmalamasının şart olduğunu gösteriyor:
      // kaldırılırsa hata geri gelir.
      //
      // Testte assert AÇIK olduğu için istisna görünüyor. Release'de
      // aynı durum sessiz yerleşim döngüsü ve ANR üretiyordu — sahada
      // teşhisi çok daha zor hâli.
      await tester.pumpWidget(_diyalog(sabitOlcu: false, yuk: yuk));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNotNull,
        reason: 'Sarmalama olmadan hata bekleniyordu; QrImageView artık '
            'iç boyut döndürebiliyorsa sarmalama gereksizleşmiş olabilir',
      );
    });

    testWidgets('QR uzun yükle de çiziliyor', (tester) async {
      // 72 karakter sürüm 6-7 gerektiriyor; `QrVersions.auto` bunu
      // bulmak zorunda. Sığmazsa QR hiç çizilmez ve öğretmen
      // kurulumu tamamlayamaz.
      await tester.pumpWidget(_diyalog(sabitOlcu: true, yuk: yuk));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('diyalog kapatma düğmesi var', (tester) async {
      await tester.pumpWidget(_diyalog(sabitOlcu: true, yuk: yuk));
      await tester.pumpAndSettle();

      expect(find.text('Kapat'), findsOneWidget);
    });
  });

  group('Secret satırı — gizlilik sözleşmesi', () {
    const secret = '45O6OJ5SJJTVLOD552RNFLCPONZ2U6EO';

    Widget sarmala(Widget cocuk) => MaterialApp(
          home: Scaffold(body: Center(child: cocuk)),
        );

    testWidgets('KRİTİK: secret dokunmadan görünmüyor', (tester) async {
      // Aynı diyalogda "ekran görüntüsü alıp paylaşmayın" uyarısı var.
      // Sır sürekli açık dursa o uyarıyla çelişirdi ve omuz üstü
      // okuma kolaylaşırdı.
      await tester.pumpWidget(sarmala(const SecretSatiri(secret: secret)));
      await tester.pumpAndSettle();

      expect(find.text(secret), findsNothing);
      expect(find.text('Kodu yazıyla göster'), findsOneWidget);
    });

    testWidgets('dokununca açılıyor', (tester) async {
      await tester.pumpWidget(sarmala(const SecretSatiri(secret: secret)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kodu yazıyla göster'));
      await tester.pumpAndSettle();

      expect(find.text(secret), findsOneWidget);
    });

    testWidgets('tekrar gizlenebiliyor', (tester) async {
      await tester.pumpWidget(sarmala(const SecretSatiri(secret: secret)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kodu yazıyla göster'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gizle'));
      await tester.pumpAndSettle();

      expect(find.text(secret), findsNothing);
    });

    testWidgets('secret boşsa sebebini yazıyor', (tester) async {
      // Sessiz boş satır bırakmak, idareciye "kod yok mu, hata mı
      // var" diye sorduruyordu.
      await tester.pumpWidget(sarmala(const SecretSatiri(secret: '')));
      await tester.pumpAndSettle();

      expect(find.textContaining('tanımlı değil'), findsOneWidget);
    });
  });
}
