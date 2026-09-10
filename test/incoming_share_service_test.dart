import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/share/incoming_share_service.dart';

/// WhatsApp Paylaş → SınıfCepte yönlendirmesi.
///
/// Android seçicisi okulun attığı PDF'i göstermez. Paylaşım, içe aktarma
/// ekranı açıkken oraya; değilse ana navigasyonun açacağı ekrana gider.
void main() {
  late IncomingShareService shares;

  setUp(() {
    shares = IncomingShareService.instance;
    shares.resetForTest();
  });

  tearDown(() {
    shares.resetForTest();
  });

  test('KRİTİK: içe aktarma açıkken paylaşım yeni ekran açmaz', () async {
    String? openedByNav;
    String? receivedByPreview;
    shares.onNeedOpenPreview = (path) => openedByNav = path;
    shares.addPreviewListener();
    final sub = shares.files.listen((path) => receivedByPreview = path);

    shares.debugOffer('/tmp/sinif_5a.pdf');
    await Future<void>.value();

    expect(openedByNav, isNull);
    expect(receivedByPreview, '/tmp/sinif_5a.pdf');
    expect(shares.pendingPath, isNull);
    await sub.cancel();
  });

  test('KRİTİK: içe aktarma kapalıysa bekleyen paylaşım ana ekrana verilir', () {
    String? openedByNav;
    shares.onNeedOpenPreview = (path) => openedByNav = path;

    shares.debugOffer('/tmp/sinif_5a.pdf');

    expect(openedByNav, '/tmp/sinif_5a.pdf');
    expect(shares.pendingPath, isNull);
  });

  test('Öğretmen henüz giriş yapmadıysa paylaşım bekler', () {
    shares.debugOffer('/cache/incoming_share_liste.pdf');

    expect(shares.pendingPath, '/cache/incoming_share_liste.pdf');

    String? openedByNav;
    shares.onNeedOpenPreview = (path) => openedByNav = path;
    shares.consumePendingIfUnhandled();

    expect(openedByNav, '/cache/incoming_share_liste.pdf');
    expect(shares.pendingPath, isNull);
  });

  test('Aynı dosya iki kez işlenmez', () {
    var count = 0;
    shares.onNeedOpenPreview = (_) => count++;
    shares.debugOffer('/tmp/a.pdf');
    shares.debugOffer('/tmp/a.pdf');
    expect(count, 1);
  });
}
