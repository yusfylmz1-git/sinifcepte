import 'dart:math' as math;

import 'foto_isleme.dart';

/// Bulunan bir yüz (çalışma görüntüsünün piksel koordinatlarında).
///
/// Yalnızca KONUM bilgisi: kutu, göz noktaları, baş eğimi. Yüz şablonu,
/// kimlik ya da benzerlik bilgisi YOK; bellekte kalır, saklanmaz
/// (plan §5.1: yüz analizi yalnız kadraj yardımı).
class YuzBilgisi {
  const YuzBilgisi({
    required this.x,
    required this.y,
    required this.genislik,
    required this.yukseklik,
    this.solGoz,
    this.sagGoz,
    this.egimDerece,
  });

  final double x;
  final double y;
  final double genislik;
  final double yukseklik;
  final math.Point<double>? solGoz;
  final math.Point<double>? sagGoz;

  /// Baş yana yatıklığı (ML Kit `headEulerAngleZ`), derece.
  final double? egimDerece;

  double get alan => genislik * yukseklik;
}

/// Kadraj önerisinin sonucu.
class KadrajOnerisi {
  const KadrajOnerisi({required this.alan, required this.uyarilar});

  final KirpmaAlani alan;

  /// Öğretmene gösterilecek kısa uyarılar.
  final List<String> uyarilar;
}

/// Göz hattı yüksekliğin bu oranında (hizalama ekranındaki kesikli
/// çizgiyle AYNI: `_CerceveBoyasi`, %42).
const double gozHattiOrani = 0.42;

/// Yüz kutusu (alın–çene) kadraj yüksekliğinin bu oranı olur; saçla
/// birlikte baş, ekrandaki ovali (%66) doldurur.
const double yuzYuksekligiOrani = 0.55;

/// Bu açıdan fazla eğik göz hattı uyarılır (otomatik döndürülmez).
const double egimUyariDerecesi = 5;

/// Yüzlerden 133:171 kadraj önerir. Yüz yoksa `null`.
///
/// - Birden fazla yüz varsa EN BÜYÜĞÜ seçilir ve uyarılır (öğretmen
///   kontrol etsin; kimin fotoğrafı olduğuna uygulama karar vermez).
/// - Göz noktaları varsa yatay merkez ve göz hattı gözlerden, yoksa
///   kutudan tahmin edilir.
/// - Kadraj görüntüden taşarsa içeri kaydırılır; görüntü yetmiyorsa
///   sığan en büyük kadraj alınır ve uyarılır.
KadrajOnerisi? kadrajOner(List<YuzBilgisi> yuzler, int gorselG, int gorselY) {
  if (yuzler.isEmpty || gorselG <= 0 || gorselY <= 0) return null;
  final uyarilar = <String>[];
  final yuz = yuzler.reduce((a, b) => a.alan >= b.alan ? a : b);
  if (yuzler.length > 1) {
    uyarilar.add('${yuzler.length} yüz bulundu; en büyüğü seçildi. Doğru kişi mi, kontrol edin.');
  }

  final sol = yuz.solGoz, sag = yuz.sagGoz;
  final double merkezX;
  final double gozY;
  if (sol != null && sag != null) {
    merkezX = (sol.x + sag.x) / 2;
    gozY = (sol.y + sag.y) / 2;
  } else {
    merkezX = yuz.x + yuz.genislik / 2;
    gozY = yuz.y + yuz.yukseklik * 0.38; // alın–çene kutusunda gözler
  }

  var h = yuz.yukseklik / yuzYuksekligiOrani;
  var g = h * eokulOran;
  if (g > gorselG || h > gorselY) {
    final k = math.min(gorselG / g, gorselY / h);
    g *= k;
    h *= k;
    uyarilar.add('Yüz fotoğrafa çok yakın; kadraj sığan en büyük alana göre ayarlandı.');
  }
  final x0 = merkezX - g / 2;
  final y0 = gozY - gozHattiOrani * h;
  // İçeri kaydırma dönüşte (tam sayıya çevrilirken) yapılıyor.
  if (x0 < 0 || y0 < 0 || x0 + g > gorselG || y0 + h > gorselY) {
    uyarilar.add('Yüz kenara yakın; kadraj içeri kaydırıldı.');
  }

  final egim = yuz.egimDerece ?? _gozEgimi(sol, sag);
  if (egim != null && egim.abs() > egimUyariDerecesi) {
    uyarilar.add('Baş ${egim.abs().round()}° eğik görünüyor; gerekirse açıyı düzeltin.');
  }

  var gi = g.round().clamp(1, gorselG);
  var hi = (gi / eokulOran).round();
  if (hi > gorselY) {
    hi = gorselY;
    gi = (hi * eokulOran).round().clamp(1, gorselG);
  }
  return KadrajOnerisi(
    alan: KirpmaAlani(
      x0.round().clamp(0, gorselG - gi),
      y0.round().clamp(0, gorselY - hi),
      gi,
      hi,
    ),
    uyarilar: uyarilar,
  );
}

double? _gozEgimi(math.Point<double>? sol, math.Point<double>? sag) {
  if (sol == null || sag == null) return null;
  return math.atan2(sag.y - sol.y, sag.x - sol.x) * 180 / math.pi;
}
