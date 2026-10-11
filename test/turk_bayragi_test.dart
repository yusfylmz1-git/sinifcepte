import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/documents/utils/turk_bayragi.dart';

/// Türk Bayrağı çiziminin Türk Bayrağı Tüzüğü ölçülerine uyması.
///
/// ## Neden bu testler var
/// 11 Ekim 2026'da kullanıcının getirdiği hazır bayrak SVG'sinde yıldız
/// resmî ölçünün ~%68'iydi; gözle fark etmek zor, resmî evrakta kusur.
/// Ölçüler tüzük harfleriyle sınanıyor; üstüne tüzük cetvelinde OLMAYAN
/// bağımsız bir ölçü (hilal uçları, 279/800 G) dairelerin kesişiminden
/// hesaplanıp karşılaştırılıyor: kendi sabitimizi kendi sabitimizle
/// sınamış olmayalım.
void main() {
  const yakin = 1e-9;

  group('Tuzuk olculeri (G = bayragin eni)', () {
    test('boy 1,5 G', () => expect(TurkBayragi.boy, 1.5));

    test('dis ay: merkez direkten 1/2 G, cap 1/2 G', () {
      expect(TurkBayragi.disMerkezX, closeTo(0.5, yakin));
      expect(2 * TurkBayragi.disYaricap, closeTo(0.5, yakin));
    });

    test('ic ay: merkezler arasi 1/16 G, cap 2/5 G', () {
      expect(TurkBayragi.icMerkezX - TurkBayragi.disMerkezX,
          closeTo(1 / 16, yakin));
      expect(2 * TurkBayragi.icYaricap, closeTo(0.4, yakin));
    });

    test('KRITIK: yildiz dairesinin capi 1/4 G', () {
      // Hazır SVG'de bu ~0,17 G idi.
      expect(2 * TurkBayragi.yildizYaricap, closeTo(0.25, yakin));
    });

    test('ic ay dairesi ile yildiz dairesi arasi 1/3 G', () {
      final icSol = TurkBayragi.icMerkezX - TurkBayragi.icYaricap;
      final yildizSol = TurkBayragi.yildizMerkezX - TurkBayragi.yildizYaricap;
      expect(yildizSol - icSol, closeTo(1 / 3, yakin));
    });
  });

  group('Bagimsiz saglama', () {
    test('KRITIK: hilal uclari ile ic dairenin sol kenari arasi 279/800 G',
        () {
      // İki dairenin kesişim noktasının x'i (hilalin uçları):
      // (x-a)² - (x-b)² = r1² - r2²  →  x = (r1² - r2² + b² - a²) / 2(b-a)
      const a = TurkBayragi.disMerkezX;
      final b = TurkBayragi.icMerkezX;
      const r1 = TurkBayragi.disYaricap;
      const r2 = TurkBayragi.icYaricap;
      final uclarX = (r1 * r1 - r2 * r2 + b * b - a * a) / (2 * (b - a));
      final icSol = b - r2;
      expect(uclarX - icSol, closeTo(279 / 800, yakin));
    });

    test('yildiz beyaz hilale degmez', () {
      // Her köşe ya iç dairenin içinde ya dış dairenin dışında.
      for (final (x, y) in TurkBayragi.yildizKoseleri()) {
        final dDis = math.sqrt(math.pow(x - TurkBayragi.disMerkezX, 2) +
            math.pow(y - TurkBayragi.merkezY, 2));
        final dIc = math.sqrt(math.pow(x - TurkBayragi.icMerkezX, 2) +
            math.pow(y - TurkBayragi.merkezY, 2));
        expect(dIc < TurkBayragi.icYaricap || dDis > TurkBayragi.disYaricap,
            isTrue,
            reason: 'köşe ($x, $y) hilalin beyazına düşüyor');
      }
    });

    test('yildizin bir ucu direge (hilale) bakar, ortada', () {
      final ilk = TurkBayragi.yildizKoseleri().first;
      expect(ilk.$2, closeTo(TurkBayragi.merkezY, yakin));
      final enSol = TurkBayragi.yildizKoseleri()
          .map((k) => k.$1)
          .reduce(math.min);
      expect(ilk.$1, closeTo(enSol, yakin));
    });

    test('yildiz bayragin icinde', () {
      for (final (x, y) in TurkBayragi.yildizKoseleri()) {
        expect(x, inInclusiveRange(0, TurkBayragi.boy));
        expect(y, inInclusiveRange(0, 1));
      }
    });
  });

  group('SVG', () {
    test('KRITIK: daireler tuzuk olculeriyle (en 800 birim)', () {
      final svg = TurkBayragi.svg();
      expect(svg, contains('viewBox="0 0 1200.000 800.000"'));
      expect(svg, contains('cx="400.000" cy="400.000" r="200.000"'));
      expect(svg, contains('cx="450.000" cy="400.000" r="160.000"'));
    });

    test('yildiz yolu 10 koseli ve kapali', () {
      final svg = TurkBayragi.svg();
      final yol = RegExp(r'<path d="([^"]+)"').firstMatch(svg)!.group(1)!;
      expect(RegExp(r'[ML]').allMatches(yol).length, 10);
      expect(yol.trim().endsWith('Z'), isTrue);
      // İlk uç: yıldız dairesinin sol kenarı = 1/3 G + iç dairenin sol
      // kenarı (290) → 556.667.
      expect(yol, startsWith('M556.667 400.000'));
    });

    test('bayrak kirmizisi', () {
      expect(TurkBayragi.svg(), contains('fill="#E30A17"'));
    });
  });
}
