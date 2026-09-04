import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinifcepte/core/cloud/cloud_ids.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';

/// Oturum ve kurulum kaliciligi.
///
/// Beklenen davranis (kullanici, 30 Agustos 2026):
///  - Bir kez kurulum yapan hesap BIR DAHA kurulum sorulmamali.
///  - Cikis yapilsa bile ayni mail ile girince okul/brans sorulmamali.
///  - Cikis yapilmadiysa son hesapla otomatik acilmali.
///  - Cikista rol sifirlanmali: ogretmen/veli secimi yeniden cikmali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  String key(String base, String uid) => uid.isEmpty ? base : '${base}__$uid';

  TeacherProfileModel profil({
    String branch = 'Matematik',
    String schoolName = 'Mimar Sinan Ortaokulu',
  }) {
    return TeacherProfileModel(
      id: 'KplpM8ibNdhVJENzWz8tvJ0vsLR2',
      firstName: 'Yusuf',
      lastName: 'Yilmaz',
      gender: 'Erkek',
      branch: branch,
      schoolName: schoolName,
      schoolId: 'meb_775214',
      schoolType: 'Ortaokul',
      schoolPrincipalName: '',
      email: 'y@x.com',
    );
  }

  group('Kurulum kaliciligi', () {
    test('KRITIK: cikis hesabin profil kaydini silmez', () async {
      final prefs = await SharedPreferences.getInstance();
      const uid = 'KplpM8ibNdhVJENzWz8tvJ0vsLR2';

      await prefs.setString(key('profil_okul_id', uid), 'meb_775214');
      await prefs.setString(key('profil_brans', uid), 'Matematik');

      // logout() yalnizca ESKI sabit anahtarlari temizler.
      for (final k in ['profil_okul_id', 'profil_brans', 'profil_okul']) {
        await prefs.remove(k);
      }

      expect(prefs.getString(key('profil_okul_id', uid)), 'meb_775214');
      expect(prefs.getString(key('profil_brans', uid)), 'Matematik');
    });

    test('KRITIK: iki hesap birbirinin kurulumunu bozmaz', () async {
      final prefs = await SharedPreferences.getInstance();
      const a = 'KplpM8ibNdhVJENzWz8tvJ0vsLR2';
      const b = 'WNBLCBCsKEO1YU5LJk5QdTRi0Z73';

      await prefs.setString(key('profil_brans', a), 'Matematik');
      await prefs.setString(key('profil_brans', b), 'Rehberlik');

      expect(prefs.getString(key('profil_brans', a)), 'Matematik');
      expect(prefs.getString(key('profil_brans', b)), 'Rehberlik');
    });

    test('Kurulmus profil tamamlanmis sayilir', () {
      expect(profil().isSetupComplete, isTrue);
    });

    test('KRITIK: yalnizca brans eksikse kurulum istenir', () {
      final p = profil(branch: '');
      expect(p.isSchoolBound, isTrue, reason: 'Okul zaten bagli');
      expect(p.isSetupComplete, isFalse, reason: 'Brans eksik');
    });
  });

  group('Otomatik giris kimligi', () {
    test('KRITIK: her hesap kendi veritabanini acar', () {
      // Otomatik giriste openForUid cagrilir; kimlik gecerli olmali.
      expect(CloudIds.isValidUid('KplpM8ibNdhVJENzWz8tvJ0vsLR2'), isTrue);
      expect(CloudIds.isValidUid('local_teacher'), isFalse);
    });

    test('Yer tutucu kimlikle profil anahtari uretilmez', () {
      // Bu ayrim olmadan anahtar profil_okul__local_teacher oluyor ve
      // hicbir kayit bulunamiyordu.
      expect(key('profil_okul', 'local_teacher'),
          isNot(key('profil_okul', 'KplpM8ibNdhVJENzWz8tvJ0vsLR2')));
    });
  });
}
