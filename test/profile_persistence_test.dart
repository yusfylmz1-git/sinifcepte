import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Girişte branşın silinmesi.
///
/// Kullanıcı defalarca bildirdi:
/// > "hala daha girişte branş soruyor? profilden çıkış yapıp tekrar
/// > girince yine branş soruyor. bu sorunu hala çözemedik mi?"
///
/// Cihazdan çekilen kanıt:
///   profil_brans__Kplp...  = "Bilişim Teknolojileri"   (dolu)
///   profil_brans__WNBL...  = ""                         (BOŞ)
///
/// Kök sebep: `teacher_auth_service.dart` girişten sonra
/// `current.copyWith(...)` ile profil kaydediyordu. `current` giriş
/// ÖNCESİNDEKİ state'tir; çıkış yapılmışsa boştur. Diskteki dolu branş
/// boş değerle eziliyordu.
void main() {
  String servis() => File(
        'lib/features/auth_profile/data/services/teacher_auth_service.dart',
      ).readAsStringSync();

  group('Giriş kayıtlı profili EZMİYOR', () {
    test('KRİTİK: giriş sonrası önce diskten okunuyor', () {
      final kod = servis();

      // Kimlik ancak girişten sonra belli olur; okuma da orada olmalı.
      final okumaIndex = kod.indexOf('loadProfileFromStorage()');
      final kaydetmeIndex = kod.indexOf('saveProfile(updated)');

      expect(okumaIndex, isNot(-1),
          reason: 'kayıtlı profil okunmadan yazılırsa branş silinir');
      expect(kaydetmeIndex, isNot(-1));
      expect(okumaIndex, lessThan(kaydetmeIndex),
          reason: 'önce oku, sonra yaz');
    });

    test('KRİTİK: copyWith kaynağı kayıtlı profil (current değil)', () {
      final kod = servis();

      // `current.copyWith(...)` bu hatanın ta kendisiydi.
      expect(kod.contains('final updated = current.copyWith('), isFalse,
          reason: 'giriş öncesi boş state, diskteki veriyi ezer');
      expect(kod, contains('final updated = saved.copyWith('));
    });

    test('KRİTİK: Google adı kayıtlı adı ezmiyor', () {
      final kod = servis();

      // Öğretmen adını "Yusuf YILMAZ" olarak düzelttiyse, Google'ın
      // gönderdiği ham değer bunu bozmamalı.
      expect(kod, contains('saved.firstName.trim().isNotEmpty'));
      expect(kod, contains('saved.lastName.trim().isNotEmpty'));
    });
  });

  group('Kurulum tamamlanma ölçütü', () {
    test('KRİTİK: branş boşsa kurulum tamamlanmamış sayılır', () {
      final kod = File(
        'lib/features/auth_profile/data/models/teacher_profile_model.dart',
      ).readAsStringSync();

      expect(kod, contains('branch.trim().isNotEmpty'),
          reason: 'branş kadro listesinde görünüyor; boş kalamaz');
    });
  });

  group('Anahtar simetrisi', () {
    test('KRİTİK: yazma ve okuma aynı uid kuralını kullanıyor', () {
      final kod = File(
        'lib/features/auth_profile/providers/teacher_profile_provider.dart',
      ).readAsStringSync();

      // Yazma tarafı `updated.id` yer tutucuysa `_activeUid()`e düşer;
      // okuma tarafı zaten `_activeUid()` kullanır. İkisi ayrışırsa
      // kayıt bir anahtara, okuma başka anahtara gider.
      expect(kod, contains('CloudIds.isValidUid(updated.id)'));
      expect(kod, contains('await _activeUid()'));
    });

    test('servis katmanı profili okuyabiliyor', () {
      final kod = File(
        'lib/features/auth_profile/providers/teacher_profile_provider.dart',
      ).readAsStringSync();

      expect(kod, contains('get currentProfile'),
          reason: '`state` korumalı; servis katmanı erişemiyordu');
    });
  });
}
