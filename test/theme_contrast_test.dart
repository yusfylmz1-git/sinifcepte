import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Yeni eklenen ekranlar HER İKİ TEMADA da okunuyor mu?
///
/// ## Neden bu test var
/// BEP planı ekranındaki seçim çipleri aydınlık modda BEYAZ yazıyla
/// çıkıyordu: etiket `Text`'ine renk verilmemişti, Material çip kendi
/// zeminini boyayınca yazı okunmaz oluyordu. Karanlık modda sorun
/// görünmediği için gözden kaçtı.
///
/// Bu test, çip etiketlerinin rengi AÇIKÇA belirtilmiş mi diye
/// kaynağa bakar. Görsel denetimden farkı: yeni bir çip eklenip renk
/// unutulursa insan gözüne kalmadan yakalanır.
void main() {
  /// Çip etiketi olduğu hâlde rengi belirtilmemiş satırlar.
  ///
  /// `label: Text(...)` ifadesinden sonraki 4 satır içinde `color:`
  /// geçmiyorsa renk devralınıyor demektir.
  List<String> renksizCipEtiketleri(String yol) {
    final kod = File(yol).readAsLinesSync();
    final bulunan = <String>[];
    for (var i = 0; i < kod.length; i++) {
      if (!kod[i].contains('label: Text')) continue;
      final pencere = kod.sublist(i, (i + 5).clamp(0, kod.length)).join(' ');
      if (!pencere.contains('color:')) {
        bulunan.add('${yol.split(RegExp(r'[\\/]')).last}:${i + 1}');
      }
    }
    return bulunan;
  }

  /// Çip kullanan ekranlar.
  const dosyalar = [
    'lib/features/bep/presentation/widgets/bep_option_chips.dart',
    'lib/features/guidance/presentation/views/special_education_view.dart',
  ];

  test('KRITIK: cip etiketlerinin rengi acikca verilmis', () {
    final bozuk = <String>[];
    for (final d in dosyalar) {
      if (!File(d).existsSync()) continue;
      bozuk.addAll(renksizCipEtiketleri(d));
    }
    expect(bozuk, isEmpty,
        reason: 'Bu cip etiketleri rengi devraliyor; aydinlik modda '
            'beyaz kalip okunmuyor: ${bozuk.join(", ")}');
  });

  test('KRITIK: cip kullanan ekranlar iki temayi da ele aliyor', () {
    // Renk secimi `isDark` / `brightness` kontrolune bagli olmali;
    // tek renk sabitlenirse diger temada kontrast kayboluyor.
    for (final d in dosyalar) {
      if (!File(d).existsSync()) continue;
      final kod = File(d).readAsStringSync();
      expect(
        kod.contains('isDark') || kod.contains('Brightness.dark'),
        isTrue,
        reason: '$d tema ayrimi yapmiyor',
      );
    }
  });
}
