import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/app_surumu.dart';
import 'package:sinifcepte/core/privacy/veri_saklama_metni.dart';
import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/data/repositories/exam_operations_repository.dart';
import 'package:sinifcepte/features/exam_operations/data/services/exam_sync_service.dart';
import 'package:sinifcepte/features/exam_operations/providers/exam_tracking_provider.dart';
import 'package:sinifcepte/features/profile/screens/about_screen.dart';
import 'package:sinifcepte/features/sync/services/sync_service.dart';
import 'package:sinifcepte/shared/widgets/custom_app_bar.dart';

/// Sadeleştirme 1. aşama: temizlik (17 Ekim 2026).
///
/// ## Neden bu testler var
/// Uygulama haritası çıkarılınca ekranda söz verip yapmayan ve artık doğru
/// olmayan parçalar bulundu:
///   * sürüm beş yerde "1.0.0" diye elle yazılıydı, uygulama 1.2.0'daydı;
///   * "%100 yerel, internet gerektirmez", "şifreli SQLite" gibi cümleler
///     (veli mesajları bulutta, veritabanı şifreli değil);
///   * 19 ekranda hep noktası yanan, basınca "Mesaj Kutusu (Yakında)"
///     diyen mesaj simgesi; zilde hep yanan nokta ve sahte bir bildirim;
///   * kadro ekranında çalışmayan "katılım koduyla ekle" düğmesi;
///   * eskimiş "Raporlar taşındı" kartı, ana sayfada çift Cepte kartı.
/// Bu testler bunların geri gelmesini engeller.
void main() {
  /// Yorum satırları atılmış kod: yorumlar geçmişi anlatmak için eski
  /// ifadeyi anabilir ("eskiden şu yazıyordu"); denetlenen, ekranda
  /// görünebilecek koddur.
  String yorumsuz(String icerik) => icerik
      .split('\n')
      .where((s) => !s.trimLeft().startsWith('//'))
      .join('\n');

  /// `lib/` altındaki bütün Dart dosyaları (yol, yorumsuz içerik).
  List<(String, String)> kaynaklar() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) =>
          (f.path.replaceAll('\\', '/'), yorumsuz(f.readAsStringSync())))
      .toList();

  group('Surum tek kaynaktan', () {
    test('KRITIK: uygulamaSurumu pubspec surumuyle ayni', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final satir = RegExp(r'^version:\s*([0-9.]+)', multiLine: true)
          .firstMatch(pubspec)!;
      expect(uygulamaSurumu, satir.group(1),
          reason: 'pubspec sürümü değişti ama app_surumu.dart değişmedi');
    });

    test('ekranlar ve guncelleme denetimi ayni degeri kullaniyor', () {
      expect(AboutScreen.appVersion, uygulamaSurumu);
      expect(SyncService.currentAppVersion, uygulamaSurumu);
    });

    test('KRITIK: kodda elle yazilmis "v1.0.0" kalmadi', () {
      for (final (yol, icerik) in kaynaklar()) {
        expect(icerik.contains('v1.0.0'), isFalse, reason: yol);
      }
    });
  });

  group('Veri saklama metni', () {
    test('KRITIK: yaniltici veri iddialari kodda yok', () {
      const yasak = [
        '%100 yerel',
        'şifreli yerel',
        'İnternet bağlantısı gerektirmez',
        'İnternet paketi gerektirmez',
        'KVKK Uyumlu',
        'tamamen yerel cihazınızda',
        'Tüm verileriniz yalnızca',
      ];
      for (final (yol, icerik) in kaynaklar()) {
        for (final ifade in yasak) {
          expect(icerik.contains(ifade), isFalse,
              reason: '$yol içinde "$ifade" var');
        }
      }
    });

    test('tek metin hem cihazi hem bulutu soyluyor', () {
      expect(VeriSaklamaMetni.uzun, contains('bu cihazda'));
      expect(VeriSaklamaMetni.uzun, contains('bulutta'));
      expect(VeriSaklamaMetni.uzun.contains('şifreli'), isFalse);
      expect(VeriSaklamaMetni.kisa, contains('cihazda'));
    });
  });

  group('Soz verip yapmayan parcalar kalkti', () {
    test('KRITIK: olu dugme ve bilgi kartlari kodda yok', () {
      const yasak = [
        'Mesaj Kutusu (Yakında)',
        'katılım koduyla ekle',
        'Raporlar taşındı',
      ];
      for (final (yol, icerik) in kaynaklar()) {
        for (final ifade in yasak) {
          expect(icerik.contains(ifade), isFalse,
              reason: '$yol içinde "$ifade" var');
        }
      }
      // Zile her açılışta eklenen sahte "sistem" bildirimi.
      final ustCubuk = yorumsuz(
          File('lib/shared/widgets/custom_app_bar.dart').readAsStringSync());
      expect(ustCubuk.contains("'type': 'system'"), isFalse);
    });

    test('ana sayfada Cepte ve Kazanimlar karti tekrar etmiyor', () {
      final ozet = yorumsuz(
          File('lib/features/dashboard/screens/dashboard_screen.dart')
              .readAsStringSync());
      expect(ozet.contains("'title': 'Cepte'"), isFalse,
          reason: 'Cepte arama kutusu zaten ekranın tepesinde');
      expect(ozet.contains("'title': 'Kazanımlar'"), isFalse,
          reason: 'Kazanımlar alt sekmede zaten duruyor');
    });

    test('profilde tema icin ikinci kapi yok', () {
      final profil = yorumsuz(
          File('lib/features/profile/screens/profile_screen.dart')
              .readAsStringSync());
      expect(profil.contains("'Karanlık Mod'"), isFalse);
      expect(profil.contains('Veritabanı yedekleme, dışa aktarma'), isFalse,
          reason: 'Ayarlar ekranında yedekleme yok');
    });
  });

  group('Zil bildirimleri (saf hesap)', () {
    final simdi = DateTime(2026, 10, 17, 10);
    ExamModel sinav(int gun, {bool fav = true, String ad = 'LGS'}) => ExamModel(
          id: ad,
          title: ad,
          examDate: DateTime.now().add(Duration(days: gun)),
          category: 'MEB',
          isFavorite: fav,
        );

    test('KRITIK: sinav yoksa liste BOS (sahte sistem bildirimi yok)', () {
      expect(CustomAppBar.sinavBildirimleri(const [], simdi: simdi), isEmpty);
    });

    test('favori ve 7 gun icindeki sinav hatirlatilir', () {
      final l = CustomAppBar.sinavBildirimleri([sinav(3)], simdi: simdi);
      expect(l, hasLength(1));
      expect(l.single['type'], 'exam_fav');
    });

    test('favori olmayan ya da uzak sinav hatirlatilmaz', () {
      expect(
          CustomAppBar.sinavBildirimleri(
              [sinav(3, fav: false), sinav(30, ad: 'YKS')],
              simdi: simdi),
          isEmpty);
    });

    test('gecmis sinav hatirlatilmaz', () {
      expect(CustomAppBar.sinavBildirimleri([sinav(-2)], simdi: simdi),
          isEmpty);
    });
  });

  group('Ust cubuk', () {
    Future<void> kur(
      WidgetTester tester, {
      VoidCallback? mesaj,
      List<ExamModel>? sinavlar,
    }) async {
      final container = ProviderContainer(overrides: [
        if (sinavlar != null)
          examTrackingProvider.overrideWith((ref) => _SahteSinavlar(sinavlar)),
      ]);
      addTearDown(container.dispose);
      // Ana sayfa sınavları yüklemiş gibi: sağlayıcı açık.
      if (sinavlar != null) container.read(examTrackingProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(title: 'Deneme', onMessageTap: mesaj),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('KRITIK: hedefi olmayan mesaj simgesi GORUNMEZ',
        (tester) async {
      await kur(tester);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
      expect(find.textContaining('Yakında'), findsNothing);
    });

    testWidgets('hedefi olan mesaj simgesi gorunur ve calisir',
        (tester) async {
      var basildi = 0;
      await kur(tester, mesaj: () => basildi++);
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      expect(basildi, 1);
    });

    testWidgets('KRITIK: uyari yokken zilde nokta YOK', (tester) async {
      await kur(tester, sinavlar: const []);
      expect(find.byKey(const ValueKey('zil_noktasi')), findsNothing);
    });

    testWidgets('yaklasan favori sinav varken zilde nokta var',
        (tester) async {
      await kur(tester, sinavlar: [
        ExamModel(
          id: 'lgs',
          title: 'LGS',
          examDate: DateTime.now().add(const Duration(days: 3)),
          category: 'MEB',
          isFavorite: true,
        ),
      ]);
      expect(find.byKey(const ValueKey('zil_noktasi')), findsOneWidget);
    });

    testWidgets('sinav listesi acik degilse ust cubuk onu BASLATMAZ',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(appBar: CustomAppBar(title: 'Deneme')),
        ),
      ));
      await tester.pump();
      expect(container.exists(examTrackingProvider), isFalse,
          reason: 'her ekranda sınav veritabanı yüklenirdi');
    });
  });
}

/// Veritabanına dokunmayan sınav sağlayıcısı.
class _SahteSinavlar extends ExamTrackingNotifier {
  _SahteSinavlar(List<ExamModel> sinavlar)
      : super(ExamOperationsRepository(), ExamSyncService()) {
    state = ExamTrackingState(exams: sinavlar);
  }

  @override
  Future<void> loadExams() async {}
}
