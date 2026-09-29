import 'dart:math' as math;

import 'foto_isleme.dart';

/// Elle hizalama ekranının hesabı — Flutter'sız, test edilebilir.
///
/// Ekranda sabit bir 133:171 çerçeve var; öğretmen görüntüyü altında
/// kaydırıp yakınlaştırıyor. Durum iki sayı: [olcek] (ekran pikseli /
/// görüntü pikseli) ve görüntünün sol üst köşesinin çerçeveye göre
/// konumu ([x], [y]).
///
/// Kural: görüntü çerçeveyi HER ZAMAN tamamen kaplar. Böylece kırpma
/// alanı görüntünün dışına taşmaz ve çıktıda boş şerit olmaz.
class KirpmaDurumu {
  const KirpmaDurumu(this.olcek, this.x, this.y);

  final double olcek;
  final double x;
  final double y;

  /// En fazla yakınlaştırma, sığdırma ölçeğinin katı olarak.
  static const double enFazlaYakinlastirma = 8;

  /// Çerçeveyi kaplayan en küçük ölçek.
  static double enKucukOlcek(int gorselG, int gorselY, double cerceveG, double cerceveY) =>
      math.max(cerceveG / gorselG, cerceveY / gorselY);

  /// Açılış: çerçeveyi kaplayacak kadar, ortalanmış.
  factory KirpmaDurumu.baslangic(int gorselG, int gorselY, double cerceveG, double cerceveY) {
    final s = enKucukOlcek(gorselG, gorselY, cerceveG, cerceveY);
    return KirpmaDurumu(s, (cerceveG - gorselG * s) / 2, (cerceveY - gorselY * s) / 2);
  }

  /// Ölçeği ve konumu sınırlar içine çeker.
  KirpmaDurumu sinirla(int gorselG, int gorselY, double cerceveG, double cerceveY) {
    final enKucuk = enKucukOlcek(gorselG, gorselY, cerceveG, cerceveY);
    final s = olcek.clamp(enKucuk, enKucuk * enFazlaYakinlastirma).toDouble();
    final x0 = x.clamp(cerceveG - gorselG * s, 0.0).toDouble();
    final y0 = y.clamp(cerceveY - gorselY * s, 0.0).toDouble();
    return KirpmaDurumu(s, x0, y0);
  }

  /// İki parmak hareketi: [odakBaslangic] noktasının altındaki görüntü
  /// noktası parmakla birlikte gider. [baslangic] hareketin başındaki
  /// durum, [carpan] hareketin toplam ölçek çarpanı.
  static KirpmaDurumu hareket({
    required KirpmaDurumu baslangic,
    required double odakBaslangicX,
    required double odakBaslangicY,
    required double odakX,
    required double odakY,
    required double carpan,
  }) {
    final gx = (odakBaslangicX - baslangic.x) / baslangic.olcek;
    final gy = (odakBaslangicY - baslangic.y) / baslangic.olcek;
    final s = baslangic.olcek * carpan;
    return KirpmaDurumu(s, odakX - gx * s, odakY - gy * s);
  }

  /// Görüntü ölçüsü değişince (açı düzeltmesi tuvali büyütür) çerçevenin
  /// ortasındaki nokta aynı kalsın; öğretmenin ayarladığı konum
  /// kaybolmasın.
  KirpmaDurumu tasi({
    required int eskiG,
    required int eskiY,
    required int yeniG,
    required int yeniY,
    required double cerceveG,
    required double cerceveY,
  }) {
    // Çerçeve ortasının eski görüntü merkezine göre konumu (piksel).
    final dx = (cerceveG / 2 - x) / olcek - eskiG / 2;
    final dy = (cerceveY / 2 - y) / olcek - eskiY / 2;
    final nx = cerceveG / 2 - (yeniG / 2 + dx) * olcek;
    final ny = cerceveY / 2 - (yeniY / 2 + dy) * olcek;
    return KirpmaDurumu(olcek, nx, ny).sinirla(yeniG, yeniY, cerceveG, cerceveY);
  }

  /// Çerçevenin görüntü üzerindeki karşılığı (görüntü pikseli).
  ///
  /// Genişlik yuvarlanır, yükseklik genişlikten 133:171 oranıyla
  /// türetilir: yuvarlama farkı çıktıda esnemeye dönüşmesin.
  KirpmaAlani alan(int gorselG, int gorselY, double cerceveG) {
    var g = (cerceveG / olcek).round().clamp(1, gorselG);
    var h = (g / eokulOran).round();
    if (h > gorselY) {
      h = gorselY;
      g = (h * eokulOran).round().clamp(1, gorselG);
    }
    final ax = (-x / olcek).round().clamp(0, gorselG - g);
    final ay = (-y / olcek).round().clamp(0, gorselY - h);
    return KirpmaAlani(ax, ay, g, h);
  }
}
