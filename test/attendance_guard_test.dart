import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ders ici katilim denetimi (Faz 2.2).
///
/// EN CIDDI BULGU: degerlendirme yalnizca "Kaydet" dugmesiyle
/// veritabanina yaziliyordu ve cikis korumasi YOKTU. Ogretmen 30
/// ogrenciyi degerlendirip geri tusuna basinca hepsi SESSIZCE
/// kayboluyordu.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const provider =
      'lib/features/attendance/providers/classroom_participation_provider.dart';
  const view =
      'lib/features/attendance/presentation/views/classroom_participation_view.dart';

  group('Kaydedilmemis degisiklik takibi', () {
    test('KRITIK: kirli durum bayragi var', () {
      final s = read(provider);
      expect(s.contains('hasUnsavedChanges'), isTrue,
          reason: 'Bu bayrak olmadan cikis korumasi kurulamaz');
    });

    test('KRITIK: degistiren metotlar bayragi isaretliyor', () {
      final s = read(provider);
      final marks = '_markDirty()'.allMatches(s).length;
      expect(marks, greaterThan(10),
          reason: 'Her degerlendirme degisikligi isaretlenmeli');
    });

    test('KRITIK: kayit basarili olunca bayrak temizleniyor', () {
      final s = read(provider);
      expect(s.contains('_hasUnsavedChanges = false'), isTrue,
          reason: 'Kayittan sonra cikis serbest olmali');
    });
  });

  group('Cikis korumasi', () {
    test('KRITIK: ekran PopScope ile korunuyor', () {
      final s = read(view);
      expect(s.contains('PopScope'), isTrue,
          reason: 'Koruma olmadan geri tusu tum degerlendirmeyi siliyordu');
    });

    test('KRITIK: kaydedilmemis degisiklik varken cikis engelleniyor', () {
      final s = read(view);
      expect(s.contains('canPop: !ref'), isTrue);
      expect(s.contains('hasUnsavedChanges'), isTrue);
    });

    test('Kullaniciya onay diyalogu gosteriliyor', () {
      final s = read(view);
      expect(s.contains('Kaydedilmemiş Değerlendirme'), isTrue);
      expect(s.contains('Kaydetmeden Çık'), isTrue);
      expect(s.contains('Sayfada Kal'), isTrue);
    });
  });
}
