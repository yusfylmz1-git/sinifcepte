import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Metin alanlarinda uzunluk siniri.
///
/// Denetimde bulundu: kullanici 10.000 karakterlik metin yapistirabiliyordu.
/// Sonuc: Firestore dokuman siniri (1 MiB) asilabilir, arayuz tasar, PDF
/// bozulur. Bu veriler buluta ve PDF ciktisina oldugu gibi gidiyor.
///
/// Bu test kritik giris ekranlarinda sinir bulundugunu dogrular; sinir
/// kaldirilirsa kirmizi doner.
void main() {
  /// Dosyada sinir tanimi var mi? (iki yontem de kabul edilir)
  bool hasLimits(String path, int minCount) {
    final file = File(path);
    if (!file.existsSync()) return false;
    final text = file.readAsStringSync();
    final count = 'maxLength:'.allMatches(text).length +
        'LengthLimitingTextInputFormatter'.allMatches(text).length;
    return count >= minCount;
  }

  group('Giris alanlarinda uzunluk siniri', () {
    test('KRITIK: ogretmen kurulum ekrani (ad, soyad, brans)', () {
      expect(
        hasLimits(
          'lib/features/auth_profile/presentation/views/teacher_onboarding_view.dart',
          3,
        ),
        isTrue,
        reason: 'Ad/soyad/brans buluta ve veli ekranina gidiyor',
      );
    });

    test('KRITIK: sinif ekleme (ad, ders, yil, aciklama)', () {
      expect(
        hasLimits('lib/features/classes/widgets/add_class_dialog.dart', 4),
        isTrue,
        reason: 'Sinif adi PDF basliklarinda ve bulut kaydinda kullaniliyor',
      );
    });

    test('KRITIK: ogrenci ekleme', () {
      expect(
        hasLimits('lib/features/classes/widgets/add_student_dialog.dart', 2),
        isTrue,
      );
    });

    test('KRITIK: duyuru yayimlama (baslik + metin)', () {
      expect(
        hasLimits(
          'lib/features/parent_portal/presentation/widgets/class_parent_communication_modal.dart',
          2,
        ),
        isTrue,
        reason: 'Duyuru dogrudan Firestore dokumanina yaziliyor',
      );
    });

    test('KRITIK: veli-ogretmen mesajlasma', () {
      expect(
        hasLimits(
          'lib/features/parent_portal/presentation/widgets/parent_teacher_chat_modal.dart',
          1,
        ),
        isTrue,
        reason: 'Mesaj govdesi Firestore dokumanina yaziliyor',
      );
    });
  });

  group('PDF belgelerine giden alanlar', () {
    // Bu metinler sabit boyutlu PDF hucrelerine 6.2pt ile basiliyor;
    // sinirsiz metin belge duzenini bozar.
    test('KRITIK: veli davetiyesi (tarih, saat, yer, gundem, alt not)', () {
      expect(
        hasLimits(
          'lib/features/classes/presentation/widgets/parent_invitation_editor_modal.dart',
          5,
        ),
        isTrue,
        reason: 'Davetiye PDF olarak velilere dagitiliyor',
      );
    });

    test('KRITIK: veli toplantisi (tarih, saat, yer)', () {
      expect(
        hasLimits(
          'lib/features/classes/presentation/widgets/parent_meeting_editor_modal.dart',
          3,
        ),
        isTrue,
      );
    });

    test('KRITIK: gezi / gorusme formu', () {
      expect(
        hasLimits(
          'lib/features/classes/presentation/widgets/counseling_interview_modal.dart',
          3,
        ),
        isTrue,
      );
    });

    test('KRITIK: sinif kurallari', () {
      expect(
        hasLimits(
          'lib/features/classes/presentation/widgets/classroom_rules_editor_modal.dart',
          1,
        ),
        isTrue,
        reason: 'Kural metni PDF listesinde satir satir basiliyor',
      );
    });
  });

  group('Sinav islemleri alanlari', () {
    test('KRITIK: quiz not girisi ve kolon basligi', () {
      expect(
        hasLimits(
          'lib/features/exam_operations/presentation/views/quiz_list_view.dart',
          2,
        ),
        isTrue,
        reason: 'Not alani 3 hane, kolon basligi 40 karakter',
      );
    });

    test('KRITIK: okul sinavi ekleme (sinav adi, sinif)', () {
      expect(
        hasLimits(
          'lib/features/exam_operations/presentation/views/exam_tracking_view.dart',
          3,
        ),
        isTrue,
      );
    });

    test('KRITIK: proje / odev konusu', () {
      expect(
        hasLimits(
          'lib/features/exam_operations/presentation/views/project_tracking_view.dart',
          1,
        ),
        isTrue,
      );
    });
  });

  group('Ogretmen profili (buluta gidiyor)', () {
    test('KRITIK: profil kurulum ekrani', () {
      expect(
        hasLimits(
          'lib/features/auth_profile/presentation/views/teacher_profile_setup_view.dart',
          5,
        ),
        isTrue,
        reason: 'Ad, soyad, brans, mudur adi ve e-posta',
      );
    });
  });
}
