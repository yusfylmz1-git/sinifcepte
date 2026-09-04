import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kullanici verisi iceren metinlerde tasma korumasi (Faz 1.4).
///
/// Ogrenci, veli, ogretmen, sinif ve okul adlari kullanicinin yazdigi
/// serbest metinler. Dar bir ekranda (320dp) ya da uzun MEB okul adiyla
/// bunlar kart duzenini tasiriyordu. Kullanici zaten
/// "RIGHT OVERFLOWED BY 4.4 PIXELS" hatasini gordu.
///
/// Bu test kaynak duzeyinde bekci: korunmasi gereken satirlarda
/// `overflow` ya da `maxLines` kaldirilirsa kirmizi doner.
void main() {
  /// [parca] metnini iceren `Text(` cagrisinda koruma var mi?
  bool korumali(String path, String parca) {
    final file = File(path);
    if (!file.existsSync()) return false;
    final s = file.readAsStringSync();
    final i = s.indexOf(parca);
    if (i == -1) return false;

    final t = s.lastIndexOf('Text(', i);
    if (t == -1) return false;

    // Text( cagrisinin kapanisini bul
    var depth = 0;
    var end = -1;
    for (var k = t + 4; k < s.length && k < t + 2500; k++) {
      if (s[k] == '(') {
        depth++;
      } else if (s[k] == ')') {
        depth--;
        if (depth == 0) {
          end = k;
          break;
        }
      }
    }
    if (end == -1) return false;

    final blok = s.substring(t, end);
    return blok.contains('overflow:') || blok.contains('maxLines:');
  }

  group('Veli ekranlari', () {
    test('KRITIK: cocuk kartinda sinif + numara', () {
      expect(
        korumali(
          'lib/features/parent_portal/presentation/views/parent_profile_view.dart',
          r"'${child.className} · No: ${child.studentNumber}',",
        ),
        isTrue,
      );
    });

    test('KRITIK: bagli cocuk listesi (ad + sinif)', () {
      expect(
        korumali(
          'lib/features/parent_portal/presentation/views/parent_profile_view.dart',
          r"'${c.studentName} (${c.className})',",
        ),
        isTrue,
      );
    });

    test('KRITIK: randevu satiri (ogretmen adi)', () {
      expect(
        korumali(
          'lib/features/parent_portal/presentation/screens/parent_child_detail_screen.dart',
          r"'${teacher.teacherName} · Randevu',",
        ),
        isTrue,
      );
    });
  });

  group('Ogretmen ekranlari', () {
    test('KRITIK: randevu kartinda ogrenci + veli + yakinlik', () {
      expect(
        korumali(
          'lib/features/parent_portal/presentation/widgets/class_parent_communication_modal.dart',
          r"'${app.studentName} • ${app.parentName} (${app.relation})',",
        ),
        isTrue,
        reason: 'uc kullanici metni yan yana, Row icinde',
      );
    });

    test('KRITIK: referans kodu basligi (ogrenci adi)', () {
      expect(
        korumali(
          'lib/features/parent_portal/presentation/widgets/class_reference_codes_modal.dart',
          r"'${student.fullName} — Bağlı Veliler',",
        ),
        isTrue,
      );
    });
  });

  group('Evraklar ve raporlar', () {
    test('KRITIK: ogretmen adi tasmiyor', () {
      // Ekran yeniden yazildi; metin artik farkli kuruluyor ama
      // koruma sart: ogretmen adi kullanicinin yazdigi serbest metin.
      final s = File(
        'lib/features/documents/presentation/views/documents_hub_view.dart',
      ).readAsStringSync();

      expect(s, contains('profile.fullName'));
      expect(s, contains('overflow: TextOverflow.ellipsis'),
          reason: 'ad tasarsa kart duzeni bozulur');
    });

    test('KRITIK: brans + okul adi satiri korumali (uzun MEB adlari)', () {
      final s = File(
        'lib/features/documents/presentation/views/documents_hub_view.dart',
      ).readAsStringSync();

      // Brans ve okul adi tek satirda birlestiriliyor; MEB okul adlari
      // cok uzun olabildigi icin bu satir en riskli olan.
      expect(s, contains('profile.schoolName'));
      expect('overflow: TextOverflow.ellipsis'.allMatches(s).length,
          greaterThanOrEqualTo(2),
          reason: 'hem ad hem okul satiri korunmali');
    });

    test('KRITIK: sinav analizi basligi (sinif + ders)', () {
      expect(
        korumali(
          'lib/features/analytics/presentation/views/exam_analysis_detail_view.dart',
          r"'${_currentExam.className} • ${_currentExam.subjectName}',",
        ),
        isTrue,
      );
    });
  });

  group('Ana sayfa', () {
    test('KRITIK: canli ders karti (sinif + ders)', () {
      expect(
        korumali(
          'lib/features/dashboard/screens/dashboard_screen.dart',
          r"'$className • $subjectName',",
        ),
        isTrue,
      );
    });
  });
}
