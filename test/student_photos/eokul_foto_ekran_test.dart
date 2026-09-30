import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/student_photos/data/foto_alici.dart';
import 'package:sinifcepte/features/student_photos/data/foto_depolama.dart';
import 'package:sinifcepte/features/student_photos/data/ogrenci_foto_deposu.dart';
import 'package:sinifcepte/features/student_photos/domain/foto_isleme.dart';
import 'package:sinifcepte/features/student_photos/domain/ogrenci_foto.dart';
import 'package:sinifcepte/features/student_photos/presentation/disa_aktarim_ekrani.dart';
import 'package:sinifcepte/features/student_photos/presentation/eokul_foto_merkezi_ekrani.dart';
import 'package:sinifcepte/features/student_photos/presentation/foto_hizalama_ekrani.dart';
import 'package:sinifcepte/features/student_photos/presentation/sinif_foto_ekrani.dart';
import 'package:sinifcepte/features/student_photos/presentation/seri_cekim_ekrani.dart';
import 'package:sinifcepte/features/student_photos/presentation/widgets/ogrenci_foto_kucuk.dart';
import 'package:sinifcepte/features/student_photos/providers/ogrenci_foto_providers.dart';
import 'package:sinifcepte/shared/widgets/app_drawer.dart';

/// e-Okul foto ekranları (Faz 2). Veritabanı ve dosya işlemleri gerçek;
/// yalnızca `path_provider` yerine geçici klasör veriliyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'eokul_foto_ekran_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory kok;
  late FotoDepolama depolama;
  late int sinifId;
  late int ismail;
  late ClassModel sinif;

  Uint8List jpeg(int g, int y) {
    final r = img.Image(width: g, height: y);
    img.fill(r, color: img.ColorRgb8(40, 120, 90));
    return Uint8List.fromList(img.encodeJpg(r));
  }

  OgrenciFotoDeposu depo() => OgrenciFotoDeposu(
        veritabani: () => DatabaseHelper.instance.database,
        depolama: depolama,
      );

  /// Gerçek G/Ç (sqflite ffi, dosya, izolat) sahte zamanda ilerlemez.
  Future<void> bekle(WidgetTester tester, [int tur = 12]) async {
    for (var i = 0; i < tur; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
  }

  /// Koşul sağlanana kadar gerçek G/Ç'ye zaman tanır (en çok ~8 sn).
  Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
    for (var i = 0; i < 200 && !kosul(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget sahne(Widget ekran) => ProviderScope(
        overrides: [fotoDepolamaProvider.overrideWith((ref) async => depolama)],
        child: MaterialApp(home: ekran),
      );

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();
    kok = await Directory.systemTemp.createTemp('eokul_foto_ekran');
    depolama = FotoDepolama(Directory(p.join(kok.path, 'student_photos')));
    sinifId = await ClassRepository().insertClass(const ClassModel(
      name: '5-A',
      subject: 'Türkçe',
      academicYear: '2026-2027',
    ));
    sinif = ClassModel(id: sinifId, name: '5-A', subject: 'Türkçe', academicYear: '2026-2027');
    ismail = await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 1234, firstName: 'İsmail', lastName: 'IŞIK'));
    await StudentRepository().insertStudent(
        StudentModel(classId: sinifId, schoolNumber: 5, firstName: 'Ali', lastName: 'CAN'));
  });

  tearDown(() async {
    // Windows: sahte zamanda yarım kalan resim okuması dosyayı kilitli
    // tutabiliyor; geçici klasör sonra işletim sistemince temizlenir.
    try {
      if (await kok.exists()) await kok.delete(recursive: true);
    } on FileSystemException {
      // yok say
    }
  });

  group('menü', () {
    testWidgets('KRITIK: "İdari işlemler" başlığı altında "e-Okul foto" var, sayfayı açıyor',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final anahtar = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(sahne(Scaffold(key: anahtar, drawer: const AppDrawer())));
      anahtar.currentState!.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('İdari işlemler'), findsOneWidget);
      expect(find.textContaining('IDARI'), findsNothing, reason: 'Türkçe İ tuzağı');
      final baslikY = tester.getTopLeft(find.text('İdari işlemler')).dy;
      final dugmeY = tester.getTopLeft(find.text('e-Okul foto')).dy;
      expect(dugmeY > baslikY, isTrue, reason: 'düğme başlığın altında');

      await tester.tap(find.text('e-Okul foto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EokulFotoMerkeziEkrani), findsOneWidget);
      await bekle(tester);
      expect(find.text('0/2 hazır'), findsOneWidget);
    });
  });

  group('sınıf ekranı', () {
    testWidgets('KRITIK: sayım, numara sırası, durum etiketi, süzgeç ve arama', (tester) async {
      await tester.runAsync(() => depo().kaydet(
            ogrenciId: ismail,
            standartJpeg: jpeg(133, 171),
            kaynak: FotoKaynagi.dosya,
            kimlikOnaylandi: DateTime.now(),
          ));
      await tester.pumpWidget(sahne(SinifFotoEkrani(sinif: sinif)));
      await bekleKadar(tester, () => find.textContaining('/2 hazır').evaluate().isNotEmpty);
      await bekle(tester, 4);

      expect(find.text('1/2 hazır'), findsOneWidget);
      final aliY = tester.getTopLeft(find.text('5  Ali CAN')).dy;
      final ismailY = tester.getTopLeft(find.text('1234  İsmail IŞIK')).dy;
      expect(aliY < ismailY, isTrue, reason: 'okul numarasına göre sıralı (5 < 1234)');
      expect(find.textContaining('Hazır ·'), findsOneWidget, reason: 'tarih ile birlikte');
      expect(find.text('Fotoğraf yok'), findsOneWidget);

      await tester.tap(find.text('Fotoğrafı yok (1)'));
      await tester.pump();
      expect(find.text('5  Ali CAN'), findsOneWidget);
      expect(find.text('1234  İsmail IŞIK'), findsNothing);

      await tester.tap(find.text('Tümü (2)'));
      await tester.enterText(find.byKey(const Key('eokul_foto_arama')), 'ışık');
      await tester.pump();
      expect(find.text('1234  İsmail IŞIK'), findsOneWidget);
      expect(find.text('5  Ali CAN'), findsNothing);
    });

    testWidgets('KRITIK: fotoğrafı sil yalnız fotoğrafı siler, önce ne silinmeyeceğini söyler',
        (tester) async {
      await tester.runAsync(() => depo().kaydet(
            ogrenciId: ismail,
            standartJpeg: jpeg(133, 171),
            kaynak: FotoKaynagi.dosya,
            kimlikOnaylandi: DateTime.now(),
          ));
      await tester.pumpWidget(sahne(SinifFotoEkrani(sinif: sinif)));
      await bekleKadar(tester, () => find.textContaining('/2 hazır').evaluate().isNotEmpty);
      await bekle(tester, 4);

      await tester.tap(find.text('1234  İsmail IŞIK'));
      await tester.pumpAndSettle();
      expect(find.text('1234_İsmail_IŞIK.jpg'), findsOneWidget, reason: 'paylaşım dosya adı');
      expect(find.text('Başka öğrenciye aktar'), findsOneWidget);
      await tester.tap(find.text('Fotoğrafı sil'));
      await tester.pumpAndSettle();
      expect(find.textContaining('öğrenci kaydı, katılım ve not bilgileri silinmez'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Fotoğrafı sil'));
      await bekleKadar(tester, () => find.text('0/2 hazır').evaluate().isNotEmpty);

      expect(find.text('0/2 hazır'), findsOneWidget);
      final kalan = await tester.runAsync(() => depo().guncel(ismail));
      expect(kalan, isNull);
      final ogr = await tester.runAsync(() => StudentRepository().getStudentsByClassId(sinifId));
      expect(ogr!.length, 2, reason: 'öğrenci silinmedi');
    });

    testWidgets('KRITIK: sınıfın fotoğraflarını toplu silme onaysız çalışmıyor', (tester) async {
      await tester.runAsync(() => depo().kaydet(
            ogrenciId: ismail,
            standartJpeg: jpeg(133, 171),
            kaynak: FotoKaynagi.dosya,
            kimlikOnaylandi: DateTime.now(),
          ));
      await tester.pumpWidget(sahne(SinifFotoEkrani(sinif: sinif)));
      await bekleKadar(tester, () => find.text('1/2 hazır').evaluate().isNotEmpty);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bu sınıfın fotoğraflarını sil'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Öğrenci kayıtları, katılım ve not bilgileri silinmez'), findsOneWidget);
      final sil = find.ancestor(of: find.text('Sil'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
      expect(tester.widget<ButtonStyleButton>(sil).onPressed, isNull);
      await tester.tap(find.text('1 fotoğrafın silineceğini anlıyorum'));
      await tester.pump();
      await tester.tap(sil);
      await bekleKadar(tester, () => find.text('0/2 hazır').evaluate().isNotEmpty);
      expect(find.text('0/2 hazır'), findsOneWidget);
    });

    testWidgets('fotoğrafı olmayan öğrencide paylaş/aktar/sil yok', (tester) async {
      await tester.pumpWidget(sahne(SinifFotoEkrani(sinif: sinif)));
      await bekleKadar(tester, () => find.textContaining('/2 hazır').evaluate().isNotEmpty);
      await bekle(tester, 4);
      await tester.tap(find.text('5  Ali CAN'));
      await tester.pumpAndSettle();
      expect(find.text('Galeriden seç'), findsOneWidget);
      expect(find.text('Paylaş / kaydet'), findsNothing);
      expect(find.text('Fotoğrafı sil'), findsNothing);
    });
  });

  group('dışa aktarma ekranı', () {
    Finder dugme(String metin) => find.ancestor(
        of: find.text(metin), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    bool etkin(WidgetTester t, String metin) => t.widget<ButtonStyleButton>(dugme(metin)).onPressed != null;

    Future<void> kur(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await depo().kaydet(
          ogrenciId: ismail,
          standartJpeg: jpeg(133, 171),
          kaynak: FotoKaynagi.dosya,
          kimlikOnaylandi: DateTime.now(),
        );
        // Veli: fotoğraf çekildikten sonra numarası değişti.
        final veli = await StudentRepository().insertStudent(
            StudentModel(classId: sinifId, schoolNumber: 7, firstName: 'Veli', lastName: 'KAR'));
        await depo().kaydet(
          ogrenciId: veli,
          standartJpeg: jpeg(133, 171),
          kaynak: FotoKaynagi.dosya,
          kimlikOnaylandi: DateTime.now(),
        );
        await StudentRepository().updateStudent(
            StudentModel(id: veli, classId: sinifId, schoolNumber: 8, firstName: 'Veli', lastName: 'KAR'));
      });
      await tester.pumpWidget(sahne(DisaAktarimEkrani(baslangicSinifId: sinifId)));
      await bekleKadar(tester, () => find.textContaining('pakete girecek').evaluate().isNotEmpty);
      await bekle(tester, 3);
    }

    testWidgets('KRITIK: satırda dosya adı; kimlik farkı varken ZIP ve albüm kapalı, nedeni yazıyor',
        (tester) async {
      await kur(tester);
      expect(find.text('1234_İsmail_IŞIK.jpg'), findsOneWidget);
      expect(find.text('Fotoğraf yok'), findsOneWidget);
      expect(find.text('Kimlik kontrolü gerekli'), findsOneWidget);
      expect(find.textContaining('1 fotoğraf pakete girecek'), findsOneWidget);
      expect(etkin(tester, 'ZIP paketi'), isFalse);
      expect(etkin(tester, 'PDF albüm'), isFalse);
      expect(etkin(tester, 'Fotoğraflı kontrol listesi (PDF)'), isTrue, reason: 'kontrol her zaman');
      expect(find.textContaining('1 öğrencide çözülmesi gereken sorun var'), findsOneWidget);
    });

    testWidgets('KRITIK: kimlik farkı iki kimlik yan yana gösterilip onayla çözülüyor', (tester) async {
      await kur(tester);
      await tester.tap(find.text('8  Veli KAR'));
      await tester.pumpAndSettle();
      expect(find.text('Çekimde: 7 — Veli KAR'), findsOneWidget);
      expect(find.text('Şimdi: 8 — Veli KAR'), findsOneWidget);
      expect(etkin(tester, 'Onayla'), isFalse, reason: 'işaretlemeden onay yok');
      await tester.tap(find.text('Fotoğraf 8 — Veli KAR öğrencisine ait'));
      await tester.pump();
      await tester.tap(dugme('Onayla'));
      await bekleKadar(tester, () => find.textContaining('2 fotoğraf pakete girecek').evaluate().isNotEmpty);
      expect(find.text('8_Veli_KAR.jpg'), findsOneWidget);
      expect(etkin(tester, 'ZIP paketi'), isTrue);
    });

    testWidgets('albüm ayarları: sığmayan ölçek ve kimliksiz albüm uyarısı', (tester) async {
      await kur(tester);
      await tester.tap(find.text('8  Veli KAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fotoğraf 8 — Veli KAR öğrencisine ait'));
      await tester.pump();
      await tester.tap(dugme('Onayla'));
      await bekleKadar(tester, () => find.textContaining('2 fotoğraf pakete girecek').evaluate().isNotEmpty);

      await tester.tap(dugme('PDF albüm'));
      await bekleKadar(tester, () => find.text('Albüm ayarları').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      expect(find.textContaining('3 sütun · sayfada'), findsOneWidget);
      await tester.tap(find.text('2 sütun'));
      await tester.tap(find.text('Büyük'));
      await tester.tap(find.text('Yatay sayfa'));
      await tester.pump();
      expect(find.textContaining('Seçilen ölçek sayfaya sığmıyor'), findsOneWidget);
      await tester.tap(find.text('Ad-soyad'));
      await tester.tap(find.text('Okul numarası'));
      await tester.pump();
      expect(find.textContaining('yalnız görsel albümdür'), findsOneWidget);
    });
  });

  group('seri çekim', () {
    Finder dugme(String metin, {bool dolu = false}) => find.ancestor(
        of: find.text(metin),
        matching: find.byWidgetPredicate((w) => dolu ? w is FilledButton : w is ButtonStyleButton));

    Future<_SahteAlici> kur(WidgetTester tester, {List<int>? sira, Uint8List? kayip}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final alici = _SahteAlici(jpeg(600, 800), kayip: kayip);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          fotoDepolamaProvider.overrideWith((ref) async => depolama),
          fotoAliciProvider.overrideWithValue(alici),
        ],
        child: MaterialApp(
          home: SeriCekimEkrani(
            sinif: sinif,
            baslangicSirasi: sira,
            arkaPlan: <T>(FutureOr<T> Function() is_) async => is_(),
          ),
        ),
      ));
      return alici;
    }

    Future<void> kartBekle(WidgetTester tester, String kimlik) =>
        bekleKadar(tester, () => find.text(kimlik).evaluate().isNotEmpty);

    /// Kamera → hizala → kimlik onayı → kaydet.
    Future<void> cekVeKaydet(WidgetTester tester, String onayMetni) async {
      await tester.tap(dugme('Fotoğraf çek'));
      await bekleKadar(tester, () => find.text('Fotoğrafı hizala').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam'));
      await bekleKadar(tester, () => find.text(onayMetni).evaluate().isNotEmpty);
      await tester.tap(find.text(onayMetni));
      await tester.pump();
      await tester.tap(dugme('Kaydet'));
      await bekleKadar(tester, () => find.byType(FotoHizalamaEkrani).evaluate().isEmpty);
      await bekle(tester, 6);
    }

    testWidgets('KRITIK: kimlik kartı → çek → onayla → kaydet ve sıradaki; geri al', (tester) async {
      final ali = (await tester.runAsync(() => StudentRepository().getStudentsByClassId(sinifId)))!
          .firstWhere((o) => o.schoolNumber == 5)
          .id!;
      final alici = await kur(tester, sira: [ali, ismail]);
      await kartBekle(tester, '5-A • 5');
      expect(find.text('Ali CAN'), findsOneWidget);
      expect(alici.kamera, 0, reason: 'kamera kimlik gösterilmeden açılmaz');

      await cekVeKaydet(tester, 'Bu fotoğraf 5 — Ali CAN öğrencisine ait');
      expect(alici.kamera, 1);
      expect(await tester.runAsync(() => depo().guncel(ali)), isNotNull, reason: "Ali'ye kaydedildi");
      await kartBekle(tester, '5-A • 1234');
      expect(find.text('1/2 çekildi'), findsOneWidget);
      expect(find.text('Son: 5 Ali'), findsOneWidget);

      // Geri al: fotoğraf silinir, Ali yeniden sıradaki.
      await tester.tap(find.widgetWithText(TextButton, 'Geri al'));
      await tester.pumpAndSettle();
      expect(find.textContaining('az önce kaydedilen fotoğrafı silinecek'), findsOneWidget);
      await tester.tap(dugme('Geri al', dolu: true));
      await kartBekle(tester, '5-A • 5');
      await bekleKadar(tester, () => find.text('0/2 çekildi').evaluate().isNotEmpty);
      expect(find.text('0/2 çekildi'), findsOneWidget);
      expect(await tester.runAsync(() => depo().guncel(ali)), isNull, reason: 'geri alınan fotoğraf silindi');
      await bekle(tester, 6); // yarım kalan sorgular bitsin
    });

    testWidgets('atla, sıra sonu, atlananları yeniden çek', (tester) async {
      await kur(tester, sira: [ismail]);
      await kartBekle(tester, '5-A • 1234');
      await tester.tap(find.text('Şimdi atla'));
      await bekleKadar(tester, () => find.textContaining('1 öğrenci atlandı').evaluate().isNotEmpty);
      await tester.tap(find.text('Atlananları çek'));
      await kartBekle(tester, '5-A • 1234');
    });

    testWidgets('KRITIK: uygulama kapanınca oturum kaldığı öğrenciden sürüyor', (tester) async {
      final ali = (await tester.runAsync(() => StudentRepository().getStudentsByClassId(sinifId)))!
          .firstWhere((o) => o.schoolNumber == 5)
          .id!;
      await kur(tester, sira: [ali, ismail]);
      await kartBekle(tester, '5-A • 5');
      await tester.tap(find.text('Şimdi atla'));
      await kartBekle(tester, '5-A • 1234');

      // Yeni ekran, yeni sağlayıcılar: oturum veritabanından okunur.
      await tester.pumpWidget(const SizedBox());
      await kur(tester); // sira: null → devam
      await kartBekle(tester, '5-A • 1234');
      expect(find.text('0/2 çekildi'), findsOneWidget);
      expect(find.textContaining('1 atlandı'), findsOneWidget);
    });

    testWidgets('kamera açıkken kaybolan fotoğraf kimlik sorularak kurtarılıyor', (tester) async {
      await kur(tester, sira: [ismail], kayip: jpeg(600, 800));
      await bekleKadar(tester, () => find.text('Fotoğraf kurtarıldı').evaluate().isNotEmpty);
      expect(find.textContaining('1234 — İsmail IŞIK için kullanılsın mı?'), findsOneWidget);
      await tester.tap(find.text('Kullan'));
      await bekleKadar(tester, () => find.text('Fotoğrafı hizala').evaluate().isNotEmpty);
    });

    testWidgets('KRITIK: kurtarılan fotoğraf "Kullanma" denirse kullanılmıyor', (tester) async {
      await kur(tester, sira: [ismail], kayip: jpeg(600, 800));
      await bekleKadar(tester, () => find.text('Fotoğraf kurtarıldı').evaluate().isNotEmpty);
      await tester.tap(find.text('Kullanma'));
      await bekle(tester, 6);
      expect(find.text('Fotoğrafı hizala'), findsNothing);
      expect(find.text('5-A • 1234'), findsOneWidget);
    });
  });

  group('avatar (katılım kartı, rastgele seçici, öğrenci listesi)', () {
    const yedekAnahtar = Key('yedek');

    Future<void> kur(WidgetTester tester, Map<int, OgrenciFoto> fotolar) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          fotoDepolamaProvider.overrideWith((ref) async => depolama),
          sinifFotolariProvider(sinifId).overrideWith((ref) async => fotolar),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OgrenciAvatari(
              ogrenciId: ismail,
              sinifId: sinifId,
              boyut: 22,
              yedek: const SizedBox(key: yedekAnahtar, width: 22, height: 22),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('KRITIK: fotoğraf varsa resim, aynı boyutta', (tester) async {
      final f = await tester.runAsync(() => depo().kaydet(
            ogrenciId: ismail,
            standartJpeg: jpeg(133, 171),
            kaynak: FotoKaynagi.dosya,
            kimlikOnaylandi: DateTime.now(),
          ));
      await kur(tester, {ismail: f!});
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(yedekAnahtar), findsNothing);
      expect(tester.getSize(find.byType(OgrenciAvatari)), const Size(22, 22),
          reason: 'kart düzeni kaymasın');
    });

    testWidgets('KRITIK: "fotoğrafları göster" kapalıysa fotoğraf olsa da eski görünüm', (tester) async {
      final f = await tester.runAsync(() => depo().kaydet(
            ogrenciId: ismail,
            standartJpeg: jpeg(133, 171),
            kaynak: FotoKaynagi.dosya,
            kimlikOnaylandi: DateTime.now(),
          ));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          fotoDepolamaProvider.overrideWith((ref) async => depolama),
          sinifFotolariProvider(sinifId).overrideWith((ref) async => {ismail: f!}),
          fotolariGosterProvider.overrideWith((ref) => FotolariGosterNotifier(false)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OgrenciAvatari(
              ogrenciId: ismail,
              sinifId: sinifId,
              boyut: 22,
              yedek: const SizedBox(key: yedekAnahtar, width: 22, height: 22),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(yedekAnahtar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('fotoğraf yoksa mevcut görünüm aynen', (tester) async {
      await kur(tester, const {});
      expect(find.byKey(yedekAnahtar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('KRITIK: dosyası kayıp kayıt hata göstermez, eski görünüme döner', (tester) async {
      final f = await tester.runAsync(() => depo().kaydet(
            ogrenciId: ismail,
            standartJpeg: jpeg(133, 171),
            kaynak: FotoKaynagi.dosya,
            kimlikOnaylandi: DateTime.now(),
          ));
      final kayip = OgrenciFoto.fromMap({
        'id': f!.id,
        'student_id': ismail,
        'revision': 1,
        'status': FotoDurumu.dosyaYok,
        'standard_relative_path': f.standardPath,
        'width': 133,
        'height': 171,
        'byte_size': 1,
        'checksum': '',
        'source_type': FotoKaynagi.dosya,
        'captured_school_number': 1234,
        'captured_full_name': 'x',
        'identity_confirmed_at': '2026-09-30T00:00:00Z',
        'captured_at': '2026-09-30T00:00:00Z',
        'approved_at': '2026-09-30T00:00:00Z',
        'updated_at': '2026-09-30T00:00:00Z',
      });
      await kur(tester, {ismail: kayip});
      expect(find.byKey(yedekAnahtar), findsOneWidget);
    });

    test('KRITIK: üç ekran ortak avatarı kullanıyor (kendi kopyası yok)', () {
      for (final yol in [
        'lib/features/attendance/presentation/widgets/compact_student_participation_grid.dart',
        'lib/features/attendance/presentation/widgets/random_student_picker_modal.dart',
        'lib/features/classes/screens/student_list_screen.dart',
      ]) {
        final s = File(yol).readAsStringSync();
        expect(s.contains('OgrenciAvatari('), isTrue, reason: yol);
        expect(s.contains('Image.file'), isFalse, reason: '$yol dosya yolunu kendisi okumasın');
      }
    });
  });

  group('hizalama ve kimlik onayı', () {
    Future<bool?> ac(WidgetTester tester, {bool mevcut = false}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      bool? sonuc;
      final calisma = calismaGoruntusuHazirla(jpeg(600, 800));
      await tester.pumpWidget(sahne(Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              sonuc = await Navigator.of(ctx).push<bool>(MaterialPageRoute(
                builder: (_) => FotoHizalamaEkrani(
                  ogrenci: StudentModel(
                      id: ismail, classId: sinifId, schoolNumber: 1234, firstName: 'İsmail', lastName: 'IŞIK'),
                  sinifAdi: '5-A',
                  calisma: calisma,
                  kaynak: FotoKaynagi.dosya,
                  mevcutFotoVar: mevcut,
                  arkaPlan: <T>(FutureOr<T> Function() is_) async => is_(),
                ),
              ));
            },
            child: const Text('aç'),
          ),
        ),
      )));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      return sonuc;
    }

    testWidgets('KRITIK: kimlik iki adımda da görünür, onaysız Kaydet çalışmaz', (tester) async {
      await ac(tester, mevcut: true);
      expect(find.text('5-A • 1234'), findsOneWidget);
      expect(find.text('İsmail IŞIK'), findsOneWidget);

      await tester.tap(find.text('Devam'));
      await bekle(tester);
      expect(find.text('Kimliği onayla'), findsOneWidget);
      expect(find.text('5-A • 1234'), findsOneWidget, reason: 'onay adımında da kimlik');
      expect(find.textContaining('mevcut fotoğrafı değiştirilecek'), findsOneWidget);

      // FilledButton.icon özel bir alt sınıf üretir; türe tam eşleşme bulmaz.
      final kaydetBul = find.ancestor(
          of: find.text('Kaydet'), matching: find.byWidgetPredicate((w) => w is FilledButton));
      FilledButton kaydet() => tester.widget<FilledButton>(kaydetBul);
      expect(kaydet().onPressed, isNull, reason: 'kimlik onayı yok');

      await tester.tap(find.text('Bu fotoğraf 1234 — İsmail IŞIK öğrencisine ait'));
      await tester.pump();
      expect(kaydet().onPressed, isNotNull);

      await tester.tap(kaydetBul);
      await bekleKadar(
          tester,
          () =>
              find.byType(FotoHizalamaEkrani).evaluate().isEmpty ||
              find.textContaining('Kaydedilemedi').evaluate().isNotEmpty);
      expect(find.textContaining('Kaydedilemedi'), findsNothing);
      expect(find.byType(FotoHizalamaEkrani), findsNothing, reason: 'kaydedince kapanır');

      final f = await tester.runAsync(() => depo().guncel(ismail));
      expect(f, isNotNull);
      expect((f!.width, f.height), (eokulGenislik, eokulYukseklik));
      expect(f.capturedFullName, 'İsmail IŞIK');
    });

    testWidgets('onay adımında geri tuşu hizalamaya döner, ekranı kapatmaz', (tester) async {
      await ac(tester);
      await tester.tap(find.text('Devam'));
      await bekle(tester);
      expect(find.text('Kimliği onayla'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Fotoğrafı hizala'), findsOneWidget);
      expect(find.byType(FotoHizalamaEkrani), findsOneWidget);
    });
  });
}

/// Kamera/galeri yerine sabit fotoğraf veren alıcı.
class _SahteAlici extends FotoAlici {
  _SahteAlici(this.bayt, {this.kayip});
  final Uint8List bayt;
  final Uint8List? kayip;
  int kamera = 0;

  @override
  bool get kameraVar => true;

  @override
  Future<Uint8List?> kameradanAl() async {
    kamera++;
    return bayt;
  }

  @override
  Future<Uint8List?> galeridenAl() async => bayt;

  @override
  Future<Uint8List?> kayipFotograf() async {
    final k = kayip;
    return k;
  }
}
