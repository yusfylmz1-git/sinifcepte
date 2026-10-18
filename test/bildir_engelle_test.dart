import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/support/support_request.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_link_model.dart';
import 'package:sinifcepte/features/parent_portal/data/moderasyon.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';
import 'package:sinifcepte/features/parent_portal/data/services/parent_auth_service.dart';
import 'package:sinifcepte/features/parent_portal/presentation/screens/parent_child_detail_screen.dart';
import 'package:sinifcepte/features/parent_portal/presentation/widgets/parent_teacher_chat_modal.dart';
import 'package:sinifcepte/features/parent_portal/providers/cloud_communication_provider.dart';
import 'package:sinifcepte/features/parent_portal/providers/moderasyon_provider.dart';
import 'package:sinifcepte/features/parent_portal/providers/parent_token_provider.dart';

/// Bildir ve engelle (Google Play kullanıcı içeriği kuralı, 18 Ekim 2026).
///
/// ## Neden bu testler var
/// Veli–öğretmen mesajları ve duyurular kullanıcı içeriği sayılır; Play,
/// uygulama içinden bildirme ve engelleme ister. Eski şikâyet yolu hiç
/// bağlanmamıştı. Bildirilen metin kuralda buluttaki gövdeyle birebir
/// karşılaştırıldığı için kırpılmadan ve doğru kimlikle gitmeli.
const _ogretmen = 'ogr1';
const _veli = 'veli1';
const _cls = 'cls_ogr1_1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Gerçek yazı tipi: test yazı tipinde her harf kare çizilir.
    final yukleyici = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await yukleyici.load();
  });

  group('İçerik bildirimi verisi', () {
    test('KRITIK: metin kırpılmaz, doğru kategori ve kimliklerle gider', () {
      final uzun = 'a' * 3500;
      final m = IcerikBildirimi(
        bildirenUid: _ogretmen,
        bildirenRol: 'teacher',
        tur: BildirilenIcerik.mesaj,
        icerikId: 'msg1',
        classCloudId: _cls,
        studentCloudId: 'stu1',
        bildirilenUid: _veli,
        bildirilenAd: 'Anne: Fatma YILMAZ',
        metin: uzun,
        neden: BildirimNedeni.hakaret,
        zaman: DateTime(2026, 10, 18, 10),
      ).toMap();
      expect(m['category'], 'content_report');
      expect(m['status'], 'open');
      expect(m['userId'], _ogretmen);
      expect(m['contentType'], 'message');
      expect(m['contentId'], 'msg1');
      expect(m['classCloudId'], _cls);
      expect(m['reportedUid'], _veli);
      expect(m['excerpt'], uzun, reason: 'kural buluttaki gövdeyle birebir karşılaştırır');
      expect(m['subject'], 'İçerik bildirimi: Hakaret veya taciz');
      expect(m['message'], 'Ek not yok.', reason: 'kural boş açıklamayı kabul etmez');
      expect(m.containsKey('contentTitle'), isFalse);
      expect((m['subject'] as String).length, lessThanOrEqualTo(SupportRequest.maxSubjectLength));
    });

    test('duyuru bildirimi başlığı taşır; uzun not sınıra kırpılır', () {
      final m = IcerikBildirimi(
        bildirenUid: _veli,
        bildirenRol: 'parent',
        tur: BildirilenIcerik.duyuru,
        icerikId: 'a1',
        classCloudId: _cls,
        bildirilenUid: _ogretmen,
        bildirilenAd: 'Ahmet Öğretmen',
        metin: 'Cuma müzeye gidiyoruz.',
        baslik: 'Gezi',
        neden: BildirimNedeni.uygunsuz,
        not: 'x' * 2500,
        zaman: DateTime(2026, 10, 18, 10),
      ).toMap();
      expect(m['contentType'], 'announcement');
      expect(m['contentTitle'], 'Gezi');
      expect((m['message'] as String).length, SupportRequest.maxMessageLength);
      expect(m.containsKey('studentCloudId'), isFalse);
    });

    test('"Taleplerim" ekranı içerik bildirimini tanır', () {
      expect(SupportCategory.fromId('content_report'), SupportCategory.contentReport);
    });

    test('KRITIK: duyurunun sınav tarihi ve yazarı okunur (eskiden tarih hiç okunmuyordu)', () {
      final a = CloudAnnouncement.fromMap('a1', {
        'title': 'Matematik sınavı',
        'content': 'Üniteler 1-3',
        'priority': 'exam',
        'authorName': 'Ahmet Öğretmen',
        'authorUid': _ogretmen,
        'createdAt': '2026-10-18T08:00:00.000',
        'updatedAt': '2026-10-18T08:00:00.000',
        'eventAt': '2026-10-25T00:00:00.000',
      });
      expect(a.eventAt, DateTime(2026, 10, 25));
      expect(a.hasDate, isTrue, reason: 'velinin takvimi yalnız tarihli duyuruları gösterir');
      expect(a.authorUid, _ogretmen);
      expect(a.copyWith(readByMe: true).authorUid, _ogretmen);
    });
  });

  group('Sohbette bildir ve engelle', () {
    late _SahteModerasyon moderasyon;

    Future<void> sohbetiAc(WidgetTester tester,
        {bool ogretmen = true, EngelDurumu engel = EngelDurumu.yok, bool bildirimBasarili = true}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      moderasyon = _SahteModerasyon(engel: engel, bildirimBasarili: bildirimBasarili);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          cloudCommunicationRepositoryProvider.overrideWithValue(_SahteBulut()),
          moderasyonDeposuProvider.overrideWithValue(moderasyon),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ParentTeacherChatPanel(
              classCloudId: _cls,
              studentCloudId: 'stu1',
              studentName: 'Ali YILMAZ',
              parentUserId: _veli,
              selfName: ogretmen ? 'Deneme Öğretmen' : 'Fatma YILMAZ',
              selfUid: ogretmen ? _ogretmen : _veli,
              asTeacher: ogretmen,
              counterpartName: ogretmen ? 'Anne: Fatma YILMAZ' : 'Deneme Öğretmen',
              teacherUid: _ogretmen,
            ),
          ),
        ),
      ));
      for (var i = 0; i < 10 && find.byKey(const ValueKey('mesaj_v1')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('KRITIK: karşı tarafın mesajı basılı tutulup bildirilir; metin ve kişi doğru', (tester) async {
      await sohbetiAc(tester);
      await tester.longPress(find.byKey(const ValueKey('mesaj_v1')));
      await tester.pumpAndSettle();
      expect(find.text('Bildirilen içerik'), findsOneWidget);
      expect(find.text('Hocam bu ne biçim not!'), findsNWidgets(2), reason: 'sohbette ve alıntıda');

      await tester.tap(find.byKey(const ValueKey('bildir_neden_hakaret')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bildir_gonder')));
      await tester.pumpAndSettle();

      final b = moderasyon.bildirimler.single;
      expect(b.icerikId, 'v1');
      expect(b.metin, 'Hocam bu ne biçim not!');
      expect(b.bildirenUid, _ogretmen);
      expect(b.bildirenRol, 'teacher');
      expect(b.bildirilenUid, _veli);
      expect(b.classCloudId, _cls);
      expect(b.neden, BildirimNedeni.hakaret);

      // Ardından engel önerilir; "Hayır" denirse engel yazılmaz.
      expect(find.text('Bu kişiyi engellemek ister misiniz?'), findsOneWidget);
      await tester.tap(find.text('Hayır'));
      await tester.pumpAndSettle();
      expect(moderasyon.engeller, isEmpty);
    });

    testWidgets('kendi mesajı bildirilemez', (tester) async {
      await sohbetiAc(tester);
      await tester.longPress(find.byKey(const ValueKey('mesaj_o1')));
      await tester.pumpAndSettle();
      expect(find.text('Bildirilen içerik'), findsNothing);
      expect(find.byKey(const ValueKey('bildir_gonder')), findsNothing);
    });

    testWidgets('menüden bildir: yalnız karşı tarafın mesajları seçilir; ardından engellenir', (tester) async {
      await sohbetiAc(tester);
      await tester.tap(find.byKey(const ValueKey('sohbet_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mesaj bildir'));
      await tester.pumpAndSettle();

      expect(find.text('Hangi mesajı bildiriyorsunuz?'), findsOneWidget);
      expect(find.byKey(const ValueKey('bildir_aday_v1')), findsOneWidget);
      expect(find.byKey(const ValueKey('bildir_aday_v2')), findsOneWidget);
      expect(find.byKey(const ValueKey('bildir_aday_o1')), findsNothing, reason: 'kendi mesajı');
      expect(
        tester.widget<FilledButton>(find.byKey(const ValueKey('bildir_gonder'))).onPressed,
        isNull,
        reason: 'mesaj ve neden seçilmeden gönderilmez',
      );

      await tester.tap(find.byKey(const ValueKey('bildir_aday_v2')));
      await tester.tap(find.byKey(const ValueKey('bildir_neden_spam')));
      await tester.enterText(find.byKey(const ValueKey('bildir_not')), 'Sürekli reklam atıyor');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bildir_gonder')));
      await tester.pumpAndSettle();
      expect(moderasyon.bildirimler.single.icerikId, 'v2');
      expect(moderasyon.bildirimler.single.not, 'Sürekli reklam atıyor');

      await tester.tap(find.byKey(const ValueKey('bildir_sonra_engelle')));
      await tester.pumpAndSettle();
      expect(moderasyon.engeller, ['$_ogretmen>$_veli']);
      expect(find.byKey(const ValueKey('sohbet_engel_seridi')), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'engelleyen de yazamaz');
    });

    testWidgets('KRITIK: menüden engelle, engeli kaldır', (tester) async {
      await sohbetiAc(tester);
      await tester.tap(find.byKey(const ValueKey('sohbet_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engelle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('durum bildirimleri'), findsOneWidget,
          reason: 'güvenlik bildirimlerinin açık kaldığı söylenmeli');
      await tester.tap(find.byKey(const ValueKey('engel_onayla')));
      await tester.pumpAndSettle();

      expect(moderasyon.engeller, ['$_ogretmen>$_veli']);
      expect(find.text('Bu veliyi engellediniz; size mesaj gönderemez.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sohbet_engeli_kaldir')));
      await tester.pumpAndSettle();
      expect(moderasyon.engeller, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('veli görünümü: öğretmen engellediyse yazamaz ve nedenini görür', (tester) async {
      await sohbetiAc(tester,
          ogretmen: false, engel: const EngelDurumu(benEngelledim: false, beniEngelledi: true));
      await tester.pump();
      expect(find.text('Öğretmen bu sohbeti kapattı. Okulla doğrudan iletişime geçebilirsiniz.'),
          findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const ValueKey('sohbet_engeli_kaldir')), findsNothing,
          reason: 'engeli yalnız engelleyen kaldırır');
      expect(moderasyon.sorulanlar, ['$_veli>$_ogretmen'], reason: 'karşı taraf öğretmen');
    });

    testWidgets('KRITIK: alt sayfada uyarı sayfanın arkasında değil, sohbetin içinde görünür', (tester) async {
      // Sayfanın ScaffoldMessenger'ı SnackBar'ı alt sayfanın ARKASINDA
      // gösteriyordu: veli "görüşme saati dışında" uyarısını hiç görmüyordu.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final moderasyon = _SahteModerasyon();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          cloudCommunicationRepositoryProvider.overrideWithValue(_SahteBulut()),
          moderasyonDeposuProvider.overrideWithValue(moderasyon),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => ParentTeacherChatModal.show(
                    context,
                    classCloudId: _cls,
                    studentCloudId: 'stu1',
                    studentName: 'Ali YILMAZ',
                    parentUserId: _veli,
                    selfName: 'Deneme Öğretmen',
                    selfUid: _ogretmen,
                    asTeacher: true,
                    counterpartName: 'Anne: Fatma YILMAZ',
                    teacherUid: _ogretmen,
                  ),
                  child: const Text('Sohbeti aç'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Sohbeti aç'));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('mesaj_v1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bildir_neden_hakaret')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bildir_gonder')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(ParentTeacherChatModal), matching: find.byType(SnackBar)),
        findsOneWidget,
      );
    });

    testWidgets('bildirim yazılamazsa "gönderildi" denmez, destek e-postası gösterilir', (tester) async {
      await sohbetiAc(tester, bildirimBasarili: false);
      await tester.longPress(find.byKey(const ValueKey('mesaj_v1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bildir_neden_diger')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bildir_gonder')));
      await tester.pumpAndSettle();
      expect(find.text('Bildirim gönderilemedi'), findsOneWidget);
      expect(find.textContaining('sinifcepte@gmail.com'), findsOneWidget);
      expect(find.text('Bu kişiyi engellemek ister misiniz?'), findsNothing);
    });
  });

  group('Duyuruyu bildir (veli)', () {
    testWidgets('KRITIK: duyuru metni, başlığı ve yazarıyla bildirilir', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final moderasyon = _SahteModerasyon();
      final cocuk = _cocuk();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          moderasyonDeposuProvider.overrideWithValue(moderasyon),
          parentAuthServiceProvider.overrideWithValue(_SahteVeliGirisi()),
          cloudAnnouncementsProvider(cocuk).overrideWith((ref) async => [
                CloudAnnouncement(
                  id: 'a1',
                  title: 'Gezi',
                  content: 'Cuma müzeye gidiyoruz.',
                  authorName: 'Deneme Öğretmen',
                  authorUid: _ogretmen,
                  createdAt: DateTime(2026, 10, 18, 8),
                  updatedAt: DateTime(2026, 10, 18, 8),
                ),
              ]),
        ],
        child: MaterialApp(home: ParentChildDetailScreen(child: cocuk)),
      ));
      for (var i = 0; i < 10 && find.byKey(const ValueKey('duyuru_bildir_a1')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.byKey(const ValueKey('duyuru_bildir_a1')));
      await tester.pumpAndSettle();
      expect(find.text('Bildirilen içerik'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bildir_neden_uygunsuz')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bildir_gonder')));
      await tester.pumpAndSettle();

      final b = moderasyon.bildirimler.single;
      expect(b.tur, BildirilenIcerik.duyuru);
      expect(b.icerikId, 'a1');
      expect(b.metin, 'Cuma müzeye gidiyoruz.');
      expect(b.baslik, 'Gezi');
      expect(b.bildirilenUid, _ogretmen);
      expect(b.bildirenUid, _veli);
      expect(b.bildirenRol, 'parent');
      expect(b.classCloudId, _cls);
      expect(find.textContaining('SınıfCepte ekibine iletildi'), findsOneWidget);
    });
  });
}

ParentLinkModel _cocuk() => ParentLinkModel(
      id: 'bag1',
      parentUserId: _veli,
      parentName: 'Fatma YILMAZ',
      studentId: 1,
      studentName: 'Ali YILMAZ',
      studentNumber: 1,
      schoolId: 'okul1',
      schoolName: 'Deneme Ortaokulu',
      classId: 1,
      className: '5-A',
      linkedAt: DateTime(2026, 10, 1),
      linkedViaTokenCode: 'kod',
      classCloudId: _cls,
      studentCloudId: 'stu1',
      teacherUid: _ogretmen,
    );

/// Bildirim ve engel çağrılarını kaydeder; buluta yazmaz.
class _SahteModerasyon extends ModerasyonDeposu {
  _SahteModerasyon({this.engel = EngelDurumu.yok, this.bildirimBasarili = true});

  final EngelDurumu engel;
  final bool bildirimBasarili;
  final bildirimler = <IcerikBildirimi>[];
  final engeller = <String>[];
  final sorulanlar = <String>[];

  @override
  Future<bool> bildir(IcerikBildirimi b) async {
    if (!bildirimBasarili) return false;
    bildirimler.add(b);
    return true;
  }

  @override
  Future<EngelDurumu> engelDurumu({required String ben, required String karsi}) async {
    sorulanlar.add('$ben>$karsi');
    return engel;
  }

  @override
  Future<bool> engelle({required String ben, required String karsi}) async {
    engeller.add('$ben>$karsi');
    return true;
  }

  @override
  Future<bool> engeliKaldir({required String ben, required String karsi}) async {
    engeller.remove('$ben>$karsi');
    return true;
  }
}

/// Sohbette iki veli mesajı ve bir öğretmen mesajı (yeniden eskiye).
class _SahteBulut extends CloudCommunicationRepository {
  @override
  Future<List<CloudMessage>> fetchMessages({
    required String classCloudId,
    required String studentCloudId,
    String? teacherUid,
    DateTime? since,
    int limit = 50,
  }) async =>
      [
        CloudMessage(
          id: 'v2',
          studentCloudId: 'stu1',
          parentUserId: _veli,
          authorRole: 'parent',
          authorName: 'Fatma YILMAZ',
          teacherUid: _ogretmen,
          body: 'Kampanyalı ürünler için tıklayın',
          createdAt: DateTime(2026, 10, 18, 10, 2),
        ),
        CloudMessage(
          id: 'o1',
          studentCloudId: 'stu1',
          parentUserId: _veli,
          authorRole: 'teacher',
          authorName: 'Deneme Öğretmen',
          teacherUid: _ogretmen,
          body: 'Notu birlikte inceleyelim.',
          createdAt: DateTime(2026, 10, 18, 10, 1),
        ),
        CloudMessage(
          id: 'v1',
          studentCloudId: 'stu1',
          parentUserId: _veli,
          authorRole: 'parent',
          authorName: 'Fatma YILMAZ',
          teacherUid: _ogretmen,
          body: 'Hocam bu ne biçim not!',
          createdAt: DateTime(2026, 10, 18, 10),
        ),
      ];
}

class _SahteVeliGirisi extends ParentAuthService {
  @override
  ParentIdentity? get currentIdentity =>
      const ParentIdentity(uid: _veli, displayName: 'Fatma YILMAZ', email: 'veli@example.com');
}
