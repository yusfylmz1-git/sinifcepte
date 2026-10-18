import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/auth_profile/providers/teacher_profile_provider.dart';
import 'package:sinifcepte/features/classes/screens/class_list_screen.dart';
import 'package:sinifcepte/features/classes/screens/sinif_evraklari_ekrani.dart';
import 'package:sinifcepte/features/classes/screens/student_list_screen.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_link_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';
import 'package:sinifcepte/features/parent_portal/presentation/screens/sinif_velileri_ekrani.dart';
import 'package:sinifcepte/features/parent_portal/providers/cloud_communication_provider.dart';
import 'package:sinifcepte/features/parent_portal/providers/parent_token_provider.dart';

/// Sadeleştirme 3. aşama: sınıf tek kavram, Veliler tek sayfa (18 Ekim 2026).
///
/// ## Neden bu testler var
/// Rehberlik sınıfının ayrı bir "Sınıfım" merkezi vardı; diğer sınıflara
/// dokununca yalnız öğrenci listesi açılıyordu. Veli Paneli kendi alt
/// çubuğunda beş sekme, içinde ikinci beş sekmeydi; kadro en dipteydi.
/// Kullanıcı kararları:
///   * sınıfa dokununca öğrenciler açılır, üstte Katılım · Devamsızlık ·
///     Oturma · Veliler · Evrak şeridi durur;
///   * Veliler tek sayfa: yanıt bekleyenler, yazışmalar, derse giren
///     öğretmenler ("Okuldan öğretmen ekle" görünür), veli bağlantıları.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppConfig.testDbNameOverride = 'veliler_ve_sinif_sayfasi_test.db';
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const uid = 'ogretmenUid1';

  late ClassModel rehberlik;
  late ClassModel dersSinifi;

  Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
    for (var i = 0; i < 200 && !kosul(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> bekle(WidgetTester tester, [int tur = 12]) async {
    for (var i = 0; i < tur; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
  }

  setUpAll(() async {
    // Gerçek yazı tipi: test yazı tipinde her harf kare çizilir.
    final yukleyici = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await yukleyici.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.resetForTests();
    final rid = await ClassRepository().insertClass(const ClassModel(
        name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true));
    final did = await ClassRepository().insertClass(
        const ClassModel(name: '6-B', subject: 'Türkçe', academicYear: '2026-2027'));
    rehberlik = ClassModel(
        id: rid, name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true);
    dersSinifi = ClassModel(id: did, name: '6-B', subject: 'Türkçe', academicYear: '2026-2027');
    await StudentRepository().insertStudent(
        StudentModel(classId: rid, schoolNumber: 1, firstName: 'Ali', lastName: 'YILMAZ'));
    await StudentRepository().insertStudent(
        StudentModel(classId: rid, schoolNumber: 2, firstName: 'Ayşe', lastName: 'KAYA'));
  });

  group('Veliler sayfası (tek sayfa)', () {
    late _SahteBulut bulut;

    Future<ProviderContainer> ac(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      bulut = _SahteBulut();
      final cls = 'cls_${uid}_${rehberlik.id}';
      final kap = ProviderContainer(overrides: [
        teacherProfileProvider.overrideWith((ref) => _SahteProfil(uid)),
        cloudCommunicationRepositoryProvider.overrideWithValue(bulut),
        classLinkedParentsProvider(rehberlik).overrideWith((ref) async => [_bag()]),
        classAppointmentsCloudProvider(cls).overrideWith((ref) async => [_randevu()]),
        classStatusReportsCloudProvider(cls).overrideWith((ref) async => [_bildirim()]),
        classStaffProvider(cls).overrideWith((ref) async => const [
              CloudStaffMember(teacherUid: uid, teacherName: 'Sınıf Öğretmeni', branch: 'Türkçe', isHomeroom: true),
              CloudStaffMember(teacherUid: 'matUid2', teacherName: 'Ahmet Yılmaz', branch: 'Matematik'),
            ]),
      ]);
      addTearDown(kap.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: kap,
        child: MaterialApp(home: SinifVelileriEkrani(classModel: rehberlik)),
      ));
      await bekleKadar(tester, () => find.text('1/2 öğrencinin velisi bağlı').evaluate().isNotEmpty);
      return kap;
    }

    testWidgets('KRITIK: bölümler sırayla, sekme yok; kadro ve ekle düğmesi görünür', (tester) async {
      await ac(tester);

      expect(find.text('1/2 öğrencinin velisi bağlı'), findsOneWidget);
      expect(find.text('Duyuru yap'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing, reason: 'iç içe sekme yok');
      expect(find.byType(BottomNavigationBar), findsNothing);

      final y = [
        'Yanıt bekleyenler',
        'Yazışmalar',
        'Derse giren öğretmenler',
        'Veli bağlantıları',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      for (var i = 1; i < y.length; i++) {
        expect(y[i], greaterThan(y[i - 1]), reason: 'bölüm sırası');
      }

      // Kadro: branş öğretmeni listede, sınıf öğretmeninin kendi satırı yok.
      // (Bölüm açılınca sınıf öğretmeninin satırını onarır ve listeyi
      // tazeler; yeni liste gelene kadar beklenir.)
      await bekleKadar(tester, () => find.text('Ahmet Yılmaz · Matematik').evaluate().isNotEmpty);
      expect(find.text('Ahmet Yılmaz · Matematik'), findsOneWidget);
      expect(find.text('Sınıf Öğretmeni · Türkçe'), findsNothing);
      expect(find.byKey(const ValueKey('kadroya_ogretmen_ekle')), findsOneWidget);
      expect(find.text('Okuldan öğretmen ekle'), findsOneWidget);

      expect(find.text('Veli kodları'), findsOneWidget);
      expect(find.text('Veli rehberi'), findsOneWidget);
      await bekle(tester);
    });

    testWidgets('KRITIK: bekleyen randevu onaylanır, bildirim "görüldü" yapılır', (tester) async {
      await ac(tester);

      expect(find.textContaining('Randevu · Ali YILMAZ'), findsOneWidget);
      await tester.tap(find.text('Onayla'));
      await bekle(tester);
      expect(bulut.randevuYanitlari, ['randevu1:confirmed']);

      expect(find.textContaining('Erken çıkış'), findsOneWidget);
      await tester.tap(find.text('Görüldü'));
      await bekle(tester);
      expect(bulut.gorulenBildirimler, ['bildirim1']);
    });

    testWidgets('Google girişi yoksa bulut bölümleri yerine açıklama; veli rehberi duruyor', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [teacherProfileProvider.overrideWith((ref) => _SahteProfil('local_teacher'))],
        child: MaterialApp(home: SinifVelileriEkrani(classModel: rehberlik)),
      ));
      await tester.pump();
      expect(find.textContaining('Google ile giriş'), findsOneWidget);
      expect(find.text('Duyuru yap'), findsNothing);
      expect(find.text('Okuldan öğretmen ekle'), findsNothing);
      expect(find.text('Veli rehberi'), findsOneWidget);
    });
  });

  group('Sınıf sayfası şeridi', () {
    Future<void> sinifAc(WidgetTester tester, ClassModel sinif) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [teacherProfileProvider.overrideWith((ref) => _SahteProfil('local_teacher'))],
        child: MaterialApp(home: StudentListScreen(classModel: sinif)),
      ));
      await bekleKadar(tester, () => find.byKey(const ValueKey('serit_evrak')).evaluate().isNotEmpty);
    }

    testWidgets('KRITIK: ders sınıfında Veliler ve Devamsızlık pasif, dokununca nedenini söylüyor',
        (tester) async {
      await sinifAc(tester, dersSinifi);
      for (final k in ['serit_katilim', 'serit_devamsizlik', 'serit_oturma', 'serit_veliler', 'serit_evrak']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }

      await tester.tap(find.byKey(const ValueKey('serit_veliler')));
      await tester.pump();
      expect(find.textContaining('rehberlik sınıfında kurulur'), findsOneWidget);
      expect(find.byType(SinifVelileriEkrani), findsNothing);

      await tester.tap(find.byKey(const ValueKey('serit_devamsizlik')));
      await tester.pump();
      expect(find.textContaining('rehberlik sınıfınız değil'), findsOneWidget);
      await bekle(tester);
    });

    testWidgets('KRITIK: rehberlik sınıfında Veliler sayfası ve şube evrakları açılıyor', (tester) async {
      await sinifAc(tester, rehberlik);
      expect(find.textContaining('Rehberlik sınıfım'), findsOneWidget, reason: 'üst çubuk alt başlığı');
      await bekleKadar(tester, () => find.byKey(const ValueKey('sinif_sayilari')).evaluate().isNotEmpty);
      // Öğrenci modelinde cinsiyet varsayılanı "Erkek".
      expect(find.text('2 öğrenci · 0 kız · 2 erkek'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('serit_veliler')));
      await bekleKadar(tester, () => find.byType(SinifVelileriEkrani).evaluate().isNotEmpty);
      expect(find.byType(SinifVelileriEkrani), findsOneWidget);
      Navigator.of(tester.element(find.byType(SinifVelileriEkrani))).pop();
      // Geri geçiş animasyonu bitmeden dokunulursa dokunuş kapanan sayfaya düşer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await bekle(tester);

      await tester.tap(find.byKey(const ValueKey('serit_evrak')));
      await bekleKadar(tester, () => find.byType(SinifEvraklariEkrani).evaluate().isNotEmpty);
      expect(find.text('Nöbetçi Listesi'), findsOneWidget);
      expect(find.text('Veli Toplantı Tutanağı & İmza Sirküsü'), findsOneWidget);
      await bekle(tester);
    });

    testWidgets('ders sınıfının evrak sayfasında şube evrakı yok, nedeni yazıyor', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [teacherProfileProvider.overrideWith((ref) => _SahteProfil('local_teacher'))],
        child: MaterialApp(home: SinifEvraklariEkrani(classModel: dersSinifi)),
      ));
      await bekle(tester);
      expect(find.text('Sınıf Öğrenci Listesi Formu'), findsOneWidget);
      expect(find.text('Nöbetçi Listesi'), findsNothing);
      expect(find.textContaining('rehberlik sınıfınızın sayfasında'), findsOneWidget);
    });
  });

  testWidgets('KRITIK: Sınıflar listesinde rehberlik sınıfı en üstte tek kart, sınıf sayfasını açıyor',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [teacherProfileProvider.overrideWith((ref) => _SahteProfil('local_teacher'))],
      child: const MaterialApp(home: ClassListScreen()),
    ));
    await bekleKadar(tester, () => find.byKey(const ValueKey('rehberlik_sinifi_karti')).evaluate().isNotEmpty);

    expect(find.byKey(const ValueKey('rehberlik_sinifi_karti')), findsOneWidget);
    expect(find.text('5-A · Türkçe'), findsOneWidget);
    expect(find.text('5-A'), findsNothing, reason: 'rehberlik sınıfı gruplarda ikinci kez yok');
    expect(find.text('6-B'), findsOneWidget);
    expect(find.text('REHBERLİK & ŞUBE MERKEZİ'), findsNothing);

    final kart = tester.getTopLeft(find.byKey(const ValueKey('rehberlik_sinifi_karti'))).dy;
    expect(kart, lessThan(tester.getTopLeft(find.text('6-B')).dy));

    await tester.tap(find.byKey(const ValueKey('rehberlik_sinifi_karti')));
    await bekleKadar(tester, () => find.byType(StudentListScreen).evaluate().isNotEmpty);
    expect(find.byType(StudentListScreen), findsOneWidget);
    await bekle(tester);
  });

  test('KRITIK: Sınıfım merkezi, sekmeli veli paneli ve toplu duyuru silindi', () {
    for (final yol in [
      'lib/features/classes/screens/my_class_hub_screen.dart',
      'lib/features/parent_portal/presentation/screens/teacher_parent_panel_screen.dart',
      'lib/features/parent_portal/presentation/widgets/class_parent_communication_modal.dart',
      'lib/features/parent_portal/presentation/widgets/class_staff_manager_modal.dart',
      'lib/features/parent_portal/presentation/screens/bulk_announcement_screen.dart',
    ]) {
      expect(File(yol).existsSync(), isFalse, reason: yol);
    }
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final kod = f.readAsStringSync();
      for (final ad in [
        'MyClassHubScreen',
        'TeacherParentPanelScreen',
        'ClassParentCommunicationModal',
        'ClassStaffManagerModal',
        'BulkAnnouncementScreen',
      ]) {
        expect(kod.contains(ad), isFalse, reason: '${f.path}: $ad');
      }
    }
  });

  test('KRITIK: Veliler sayfası tek katman (sekme ve alt çubuk yok)', () {
    final s = File('lib/features/parent_portal/presentation/screens/sinif_velileri_ekrani.dart')
        .readAsStringSync();
    expect(s.contains('TabBar'), isFalse);
    expect(s.contains('bottomNavigationBar'), isFalse);
    expect(s.contains('SinifKadrosuBolumu('), isTrue, reason: 'kadro sayfanın içinde');
  });
}

ParentLinkModel _bag() => ParentLinkModel(
      id: 'bag1',
      parentUserId: 'veliUid1',
      parentName: 'Fatma YILMAZ',
      studentId: 1,
      studentName: 'Ali YILMAZ',
      studentNumber: 1,
      schoolId: 'okul1',
      schoolName: 'Okul',
      classId: 1,
      className: '5-A',
      linkedAt: DateTime(2026, 10, 1),
      linkedViaTokenCode: 'kod',
    );

CloudAppointment _randevu() => CloudAppointment(
      id: 'randevu1',
      studentCloudId: 'stu1',
      studentName: 'Ali YILMAZ',
      parentUserId: 'veliUid1',
      parentName: 'Fatma YILMAZ',
      teacherName: 'Sınıf Öğretmeni',
      appointmentDate: DateTime(2026, 10, 20),
      timeSlot: '13:30',
      topic: 'Ödev takibi',
      createdAt: DateTime(2026, 10, 17),
    );

CloudStatusReport _bildirim() => CloudStatusReport(
      id: 'bildirim1',
      studentCloudId: 'stu1',
      studentName: 'Ali YILMAZ',
      parentUserId: 'veliUid1',
      parentName: 'Fatma YILMAZ',
      type: 'early_leave',
      title: 'Erken çıkış',
      details: 'Saat 12:30 hastaneye',
      createdAt: DateTime(2026, 10, 18, 8),
    );

class _SahteProfil extends TeacherProfileNotifier {
  _SahteProfil(String id) {
    state = TeacherProfileModel(
      id: id,
      firstName: 'Deneme',
      lastName: 'Öğretmen',
      branch: 'Türkçe',
      schoolName: 'Deneme Ortaokulu',
      schoolId: 'okul1',
      schoolPrincipalName: 'Müdür',
      email: 'deneme@example.com',
    );
  }

  @override
  Future<void> loadProfileFromStorage() async {}
}

/// Bulut yazmaları yapılmaz; çağrılar kaydedilir.
class _SahteBulut extends CloudCommunicationRepository {
  final randevuYanitlari = <String>[];
  final gorulenBildirimler = <String>[];

  @override
  Future<bool> ensureClassRoom({
    required String classCloudId,
    required String className,
    required String teacherUid,
    required String teacherName,
    String schoolId = '',
    String schoolName = '',
    String meetingDay = '',
    String meetingTime = '',
  }) async =>
      true;

  @override
  Future<bool> updateAppointmentStatus({
    required String classCloudId,
    required String appointmentId,
    required String status,
    String? responseNote,
  }) async {
    randevuYanitlari.add('$appointmentId:$status');
    return true;
  }

  @override
  Future<bool> acknowledgeStatusReport({
    required String classCloudId,
    required String reportId,
    String? teacherNote,
  }) async {
    gorulenBildirimler.add(reportId);
    return true;
  }
}
