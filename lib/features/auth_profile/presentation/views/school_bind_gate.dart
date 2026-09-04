import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/screens/welcome_screen.dart';
import '../../../navigation/screens/main_navigation_screen.dart';
import '../../data/repositories/school_directory_repository.dart';
import '../../data/services/teacher_auth_service.dart';
import '../../providers/teacher_profile_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/database/database_helper.dart';
import '../../data/models/teacher_profile_model.dart';
import 'teacher_onboarding_view.dart';
import '../../../../core/database/account_switch.dart';

/// Öğretmen kromuna tek giriş: kanonik okul bağı yoksa MainNavigation açılmaz.
class SchoolBindGate extends ConsumerStatefulWidget {
  const SchoolBindGate({super.key});

  @override
  ConsumerState<SchoolBindGate> createState() => _SchoolBindGateState();
}

class _SchoolBindGateState extends ConsumerState<SchoolBindGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      await ref.read(teacherProfileProvider.notifier).ensureLoaded();

      // Hesabın kendi veritabanını aç.
      //
      // Giriş akışı bunu zaten yapar; burası uygulama YENİDEN açıldığında
      // devreye girer. Yapılmazsa oturum açık olsa bile varsayılan
      // (paylaşılan) veritabanı açılır ve öğretmen başka bir hesabın
      // sınıflarını görebilir.
      final uid = ref.read(teacherProfileProvider).id;
      if (CloudIds.isValidUid(uid)) {
        await DatabaseHelper.instance.openForUid(uid);
        // Hesabın kendi anahtarlarından taze oku: `ensureLoaded`
        // önbelleğe alınmış (ve yer tutucu kimlikle okunmuş) sonucu
        // döndürebilir.
        await ref
            .read(teacherProfileProvider.notifier)
            .loadProfileFromStorage();

        // Sağlayıcılar da tazelenmeli; aksi halde önceki hesabın
        // sınıfları ekranda kalır.
        AccountSwitch.invalidateLocalData(ref);
      }

      _refreshDirectoryEntry();
    } catch (e, stackTrace) {
      debugPrint('SchoolBindGate hydrate hatası: $e\n$stackTrace');
    }
    if (mounted) setState(() => _ready = true);
  }

  /// Öğretmenin okul dizini kaydını her açılışta tazeler.
  ///
  /// Kayıt önceden YALNIZCA okul ilk kez seçilirken yazılıyordu. Bu
  /// yüzden okulu zaten bağlı olan bir hesap dizinde hiç görünmüyor ve
  /// meslektaşları onu sınıf kadrosuna ekleyemiyordu — "aynı okuldaki
  /// öğretmeni nereden davet edeceğim?" sorusunun sebebi buydu.
  ///
  /// Ad veya branş değiştiğinde de kaydı güncel tutar. Tek doküman
  /// yazması olduğu için maliyeti ihmal edilebilir; başarısız olursa
  /// akış bozulmaz (öğretmen yerel çalışmaya devam eder).
  void _refreshDirectoryEntry() {
    final profile = ref.read(teacherProfileProvider);
    if (!profile.isSchoolBound) return;
    if (!CloudIds.isValidUid(profile.id)) return;

    unawaited(
      SchoolDirectoryRepository()
          .registerTeacher(
            teacherUid: profile.id,
            schoolId: profile.schoolId ?? '',
            fullName: profile.fullName,
            branch: profile.branch,
            email: profile.email,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => false)
          .catchError((_) => false),
    );
  }

  /// Kurulum tamamlandiginda profili kaydeder ve dizine yazar.
  Future<void> _completeSetup(TeacherProfileModel updated) async {
    await ref.read(teacherProfileProvider.notifier).saveProfile(updated);

    // Okul bagini ve BRANSI buluta yaz: aynı okuldaki öğretmenler
    // birbirini kadro listesinde adı ve branşıyla görebilsin.
    unawaited(
      SchoolDirectoryRepository()
          .registerTeacher(
            teacherUid: updated.id,
            schoolId: updated.schoolId ?? '',
            fullName: updated.fullName,
            branch: updated.branch,
            email: updated.email,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => false)
          .catchError((_) => false),
    );

    if (mounted) setState(() {});
  }

  /// Kurulumdan vazgecen ogretmeni cikis yaptirip giris ekranina dondurur.
  Future<void> _handleSignOutAndReturn(BuildContext context) async {
    try {
      await TeacherAuthService().signOut();
      await ref.read(userRoleProvider.notifier).resetRole();
    } catch (e, stackTrace) {
      debugPrint('Kurulumdan çıkış hatası: $e\n$stackTrace');
    } finally {
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = ref.watch(teacherProfileProvider);
    // Okul TEK BASINA yeterli degil: brans ve ad-soyad da gerekir.
    // Eskiden okul secilir secilmez giriliyordu; brans hic sorulmadigi
    // icin okul dizinine bos brans yaziliyor ve sinif kadrosunda kimin
    // hangi derse girdigi gorunmuyordu.
    if (profile.isSetupComplete) {
      return const MainNavigationScreen();
    }

    // Masaüstünde bulut oturumu açılamıyor (google_sign_in Windows/Linux'u
    // desteklemiyor). Okul dizini bulut verisi olduğu için burada zorunlu
    // tutulursa kullanıcı bu ekranda kilitlenir; yerel mod doğrudan geçer.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      return const MainNavigationScreen();
    }

    return TeacherOnboardingView(
      onCompleted: _completeSetup,
      onCancel: () => _handleSignOutAndReturn(context),
    );
  }
}
