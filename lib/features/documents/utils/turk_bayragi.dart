import 'dart:math' as math;

/// Türk Bayrağı — Türk Bayrağı Kanunu (2893) ve Türk Bayrağı Tüzüğü
/// ölçüleriyle vektörel çizim.
///
/// ## Ölçüler (Tüzük cetveli, bayrağın eni G cinsinden)
///   A  dış ay dairesinin merkezi ile uçkurluk dikiş yeri arası  1/2 G
///   B  dış ve iç ay dairelerinin merkezleri arası               1/16 G
///   C  dış ay dairesinin çapı                                    1/2 G
///   D  iç ay dairesinin çapı                                     2/5 G
///   E  iç ay dairesi ile yıldız dairesi arası                    1/3 G
///   F  yıldız dairesinin çapı                                    1/4 G
///   L  boy                                                       1,5 G
///   M  uçkurluk eni                                              1/30 G
///
/// Uçkurluk (M) çizilmez: basılı bayrakta, MEB ders kitaplarının
/// İstiklâl Marşı sayfasında da yoktur. A bu yüzden kırmızı alanın
/// direk tarafındaki kenarından ölçülür.
///
/// E, iç ay dairesinin direğe yakın (sol) kenarından yıldız dairesinin
/// sol kenarına ölçülür. Bağımsız sağlama: hilal uçlarından geçen dikey
/// ile iç dairenin sol kenarı arası 279/800 G çıkar; test bunu
/// dairelerin kesişiminden hesaplayıp karşılaştırıyor.
///
/// ## Neden hazır SVG değil
/// Kullanıcının getirdiği hazır SVG'de (11 Ekim 2026) yıldız resmî
/// ölçünün ~%68'iydi. Ölçüler burada tüzük harfleriyle durunca yanlışlık
/// testte yakalanır.
class TurkBayragi {
  TurkBayragi._();

  /// Boy / en oranı (L).
  static const double boy = 1.5;

  /// Dış ay dairesinin merkezi, direk kenarından (A).
  static const double disMerkezX = 1 / 2;

  /// Dış ve iç ay dairelerinin merkezleri arası (B).
  static const double merkezlerArasi = 1 / 16;

  /// Dış ay dairesinin yarıçapı (C / 2).
  static const double disYaricap = 1 / 4;

  /// İç ay dairesinin yarıçapı (D / 2).
  static const double icYaricap = 1 / 5;

  /// İç ay dairesi ile yıldız dairesi arası (E).
  static const double icYildizArasi = 1 / 3;

  /// Yıldız dairesinin yarıçapı (F / 2).
  static const double yildizYaricap = 1 / 8;

  /// Bütün merkezler bayrağın yatay ortasında.
  static const double merkezY = 1 / 2;

  /// Bayrak kırmızısı.
  static const String kirmizi = '#E30A17';

  static double get icMerkezX => disMerkezX + merkezlerArasi;

  static double get yildizMerkezX =>
      icMerkezX - icYaricap + icYildizArasi + yildizYaricap;

  /// Yıldızın 10 köşesi (5 uç, 5 iç köşe), G = 1 biriminde.
  ///
  /// İlk uç direğe (hilale) bakar. İç köşelerin yarıçapı düzgün beş
  /// köşeli yıldızın oranıdır: cos 72° / cos 36°.
  static List<(double, double)> yildizKoseleri() {
    final ic = yildizYaricap * math.cos(2 * math.pi / 5) / math.cos(math.pi / 5);
    return [
      for (var i = 0; i < 10; i++)
        (
          yildizMerkezX +
              (i.isEven ? yildizYaricap : ic) * math.cos(math.pi + i * math.pi / 5),
          merkezY +
              (i.isEven ? yildizYaricap : ic) * math.sin(math.pi + i * math.pi / 5),
        ),
    ];
  }

  /// `pw.SvgImage` için SVG: en 800, boy 1200 birim.
  static String svg() {
    const g = 800.0;
    String s(double v) => (v * g).toStringAsFixed(3);
    final kose = yildizKoseleri();
    final yol = StringBuffer('M${s(kose.first.$1)} ${s(kose.first.$2)}');
    for (final k in kose.skip(1)) {
      yol.write(' L${s(k.$1)} ${s(k.$2)}');
    }
    yol.write(' Z');
    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 ${s(boy)} ${s(1)}">'
        '<rect width="${s(boy)}" height="${s(1)}" fill="$kirmizi"/>'
        '<circle cx="${s(disMerkezX)}" cy="${s(merkezY)}" '
        'r="${s(disYaricap)}" fill="#FFFFFF"/>'
        '<circle cx="${s(icMerkezX)}" cy="${s(merkezY)}" '
        'r="${s(icYaricap)}" fill="$kirmizi"/>'
        '<path d="$yol" fill="#FFFFFF"/>'
        '</svg>';
  }
}
