import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/theme/app_fonts.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';

/// Taşma (RenderFlex overflow) koruması.
///
/// ## Neden bu test var
/// Taşma hataları yalnızca dar ekranda ve uzun içerikle ortaya çıkar;
/// `flutter analyze` bunları görmez. Gerçek cihaz testinde iki ayrı
/// ekranda sarı-siyah şeritler çıktı (AGENTS.md Madde 8 ihlali).
///
/// Burada taşmaya en yatkın satır düzenleri **320px genişlikte** ve
/// **uzun içerikle** çizilir. Taşma olursa Flutter test ortamında
/// exception fırlatır ve test kırılır.
///
/// 320px, desteklenen en dar ekrandır (AGENTS.md: 320–430px aralığı).
void main() {
  /// Widget'ı dar ekranda çizer; taşma varsa exception yakalanır.
  Future<void> pumpNarrow(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  group('Duyuru kartı başlığı (80px taşan düzendi)', () {
    Widget announcementHeader(String title, int readCount) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign_rounded, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: AppFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '👁️ $readCount',
                style: const TextStyle(fontSize: 10.5),
              ),
            ),
          ],
        ),
      );
    }

    testWidgets('Gerçek taşan başlık artık sığıyor', (tester) async {
      await pumpNarrow(
        tester,
        announcementHeader('SınıfCepte Veli Bilgilendirme Sistemi Başladı', 0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Çok uzun başlık ve büyük sayaç taşmaz', (tester) async {
      await pumpNarrow(
        tester,
        announcementHeader(
          'Çok Uzun Bir Duyuru Başlığı Örneği Veli Toplantısı Hakkında '
          'Önemli Bilgilendirme Metni',
          9999,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Veli rehberi eylem satırı (34px taşan düzendi)', () {
    Widget contactActionRow() {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Veli Telefonu Girilmedi',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.qr_code_2_rounded, size: 15),
              label: const Text('Veli Kodu', style: TextStyle(fontSize: 11.5)),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Numara Ekle', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
      );
    }

    testWidgets('Uyarı ve iki buton 320px ekranda taşmaz', (tester) async {
      await pumpNarrow(tester, contactActionRow());
      expect(tester.takeException(), isNull);
    });
  });

  group('Kadro satırı', () {
    testWidgets('Uzun öğretmen adı ve branş taşmaz', (tester) async {
      const member = CloudStaffMember(
        teacherUid: 'uid1',
        teacherName: 'Abdürrahman Hüsameddin Küçükoğulları',
        branch: 'Bilişim Teknolojileri ve Yazılım Geliştirme',
      );

      await pumpNarrow(
        tester,
        Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayTitle,
                      style: AppFonts.outfit(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Katılım kodu: K7M2P9',
                      style: AppFonts.outfit(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Sohbet balonu', () {
    testWidgets('Uzun mesaj dar ekranda taşmaz', (tester) async {
      await pumpNarrow(
        tester,
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320 * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Merhaba öğretmenim, Ali bugün rahatsızlandığı için okula '
                  'gelemeyecek. Bilginize sunarım, iyi çalışmalar.',
                  style: AppFonts.outfit(fontSize: 13),
                ),
                Text('18.08 13:45', style: AppFonts.outfit(fontSize: 9.5)),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Bağlantı onayı kartı', () {
    testWidgets('Uzun öğrenci adı ve okul adı taşmaz', (tester) async {
      await pumpNarrow(
        tester,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Abdürrahman Hüsameddin Küçükoğulları',
                style: AppFonts.outfit(fontSize: 17),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.apartment_rounded, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Şehit Öğretmen Neşe Alten Ortaokulu · 7-B',
                      style: AppFonts.outfit(fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Taşma tespiti gerçekten çalışıyor mu', () {
    testWidgets('Korumasız düzen taşma ÜRETİR (test aracı doğrulaması)',
        (tester) async {
      // Bu test, yukarıdaki testlerin gerçekten bir şey ölçtüğünü kanıtlar:
      // Expanded olmadan yazılan aynı düzen taşma exception'ı fırlatmalı.
      await pumpNarrow(
        tester,
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 16),
              const SizedBox(width: 6),
              // Expanded YOK — kasıtlı olarak korumasız
              Text(
                'SınıfCepte Veli Bilgilendirme Sistemi Başladı',
                style: AppFonts.outfit(fontSize: 13.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: const Text('👁️ 0 Veli Okudu'),
              ),
            ],
          ),
        ),
      );

      final exception = tester.takeException();
      expect(
        exception,
        isNotNull,
        reason: 'korumasız düzen taşmalı; taşmıyorsa test aracı bozuk demektir',
      );
    });
  });
}
