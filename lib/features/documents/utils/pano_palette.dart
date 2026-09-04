// ÜRETİLMİŞ DOSYA — elle düzenlemeyin.
// Kaynak: tool/pano_paletleri.py
// Yeniden üretmek için: python tool/build_pano_palet_dart.py
//
// Belirli günlere özel pano paletleri.
//
// ## Neden gri değerleri yazılı
//
// Öğretmenlerin çoğu okulda siyah-beyaz yazıcı kullanıyor. Her palet bu
// yüzden sabit bir "gri merdivene" oturuyor:
//
//   koyu : gri  42-62   beyaz metin taşır  — başlık bandı
//   orta : gri  92-118  beyaz metin taşır  — vurgu bandı
//   acik : gri 200-228  siyah metin taşır  — kart zemini
//
// Merdiven sabit olduğu için hangi gün seçilirse seçilsin s/b çıktıda
// hiyerarşi aynı okunur. Renk değişir, kontrast düzeni değişmez.
//
// Ölçütler `tool/pano_paletleri.py` içindeki dogrula() ile denetlenir;
// palet bozulursa veri üretimi durur.

import 'package:pdf/pdf.dart';

/// Bir günün pano paleti — üç basamak.
class PanoPalette {
  /// Başlık bandı. Beyaz metin taşır.
  final PdfColor koyu;

  /// Vurgu bandı, kart başlığı. Beyaz metin taşır.
  final PdfColor orta;

  /// Kart zemini, doldurma alanı. Siyah metin taşır.
  final PdfColor acik;

  /// Rengin neden seçildiği — sonradan değiştiren keyfî sanmasın.
  final String tema;

  const PanoPalette({
    required this.koyu,
    required this.orta,
    required this.acik,
    required this.tema,
  });

  /// Günün paleti; tanımlı değilse nötr varsayılan.
  ///
  /// Ad, `belirli_gun_hafta.json` içindeki adla birebir eşleşmeli.
  static PanoPalette of(String gunAdi) => _paletler[gunAdi] ?? varsayilan;


  /// Palete girmemiş günler için nötr palet.
  static const varsayilan = PanoPalette(
    koyu: PdfColor.fromInt(0xFF2B3440),
    orta: PdfColor.fromInt(0xFF5C6B7A),
    acik: PdfColor.fromInt(0xFFDEE3E8),
    tema: 'nötr — palete girmemiş günler',
  );

  static const Map<String, PanoPalette> _paletler = {
    // gri 46 / 96 / 219
    'Ulusal Egemenlik ve Çocuk Bayramı': PanoPalette(
      koyu: PdfColor.fromInt(0xFF800B0F),
      orta: PdfColor.fromInt(0xFFF02228),
      acik: PdfColor.fromInt(0xFFEDD3D4),
      tema: 'bayrak kırmızısı, çocuk neşesi — saf ton',
    ),
    // gri 47 / 95 / 219
    'Cumhuriyet Bayramı': PanoPalette(
      koyu: PdfColor.fromInt(0xFF780D1B),
      orta: PdfColor.fromInt(0xFFE0243D),
      acik: PdfColor.fromInt(0xFFEDD3D7),
      tema: 'bayrak kırmızısı, ağırbaşlı — hafif morumsu',
    ),
    // gri 46 / 95 / 221
    'Zafer Bayramı': PanoPalette(
      koyu: PdfColor.fromInt(0xFF731308),
      orta: PdfColor.fromInt(0xFFDB2E1A),
      acik: PdfColor.fromInt(0xFFEDD6D3),
      tema: 'zafer — turuncumsu kırmızı, askerî sıcaklık',
    ),
    // gri 46 / 95 / 220
    'Şehitler Günü': PanoPalette(
      koyu: PdfColor.fromInt(0xFF4A2320),
      orta: PdfColor.fromInt(0xFF914B46),
      acik: PdfColor.fromInt(0xFFEDD5D3),
      tema: 'anma — soluk bordo, düşük doygunluk',
    ),
    // gri 46 / 96 / 219
    '15 Temmuz Demokrasi ve Millî Birlik Günü': PanoPalette(
      koyu: PdfColor.fromInt(0xFF6E1023),
      orta: PdfColor.fromInt(0xFFD12A4B),
      acik: PdfColor.fromInt(0xFFEDD3D8),
      tema: 'millî birlik — gece kırmızısı',
    ),
    // gri 46 / 95 / 219
    'Kızılay Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF820B07),
      orta: PdfColor.fromInt(0xFFF72019),
      acik: PdfColor.fromInt(0xFFEDD4D3),
      tema: 'kızılay — kırmızı hilal, temiz ton',
    ),
    // gri 48 / 104 / 226
    'Atatürk Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF26323F),
      orta: PdfColor.fromInt(0xFF5A6B7D),
      acik: PdfColor.fromInt(0xFFDDE3E9),
      tema: 'anma — koyu gri-mavi',
    ),
    // gri 59 / 101 / 227
    'Atatürk\'ü Anma ve Gençlik ve Spor Bayramı': PanoPalette(
      koyu: PdfColor.fromInt(0xFF0B4F52),
      orta: PdfColor.fromInt(0xFF12888D),
      acik: PdfColor.fromInt(0xFFD3E9EA),
      tema: 'gençlik — canlı turkuaz',
    ),
    // gri 46 / 99 / 224
    'İstiklâl Marşı\'nın Kabulü ve Mehmet Akif Ersoy\'u Anma Günü': PanoPalette(
      koyu: PdfColor.fromInt(0xFF1E2F52),
      orta: PdfColor.fromInt(0xFF4E6494),
      acik: PdfColor.fromInt(0xFFDBE1EC),
      tema: 'şiir — mürekkep laciverti',
    ),
    // gri 48 / 106 / 227
    'Öğretmenler Günü': PanoPalette(
      koyu: PdfColor.fromInt(0xFF1F3A2C),
      orta: PdfColor.fromInt(0xFF4F7A62),
      acik: PdfColor.fromInt(0xFFDCE7E0),
      tema: 'kara tahta yeşili + tebeşir',
    ),
    // gri 51 / 103 / 226
    'Tutum, Yatırım ve Türk Malları Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF1B3A52),
      orta: PdfColor.fromInt(0xFF3E7396),
      acik: PdfColor.fromInt(0xFFDAE4EC),
      tema: 'tasarruf — kumbara mavisi',
    ),
    // gri 54 / 117 / 227
    'Enerji Tasarrufu Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF4A3410),
      orta: PdfColor.fromInt(0xFF9C7220),
      acik: PdfColor.fromInt(0xFFEDE3CC),
      tema: 'enerji — amber, ampul',
    ),
    // gri 48 / 97 / 226
    'Yeşilay Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF14402A),
      orta: PdfColor.fromInt(0xFF2E7D53),
      acik: PdfColor.fromInt(0xFFD8E8DF),
      tema: 'yeşilay — sağlık yeşili',
    ),
    // gri 47 / 96 / 220
    'Bilim ve Teknoloji Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF312075),
      orta: PdfColor.fromInt(0xFF6446DB),
      acik: PdfColor.fromInt(0xFFDDD8F2),
      tema: 'bilim — mor/indigo',
    ),
    // gri 47 / 98 / 227
    'Orman Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF1B3D1E),
      orta: PdfColor.fromInt(0xFF3F7A43),
      acik: PdfColor.fromInt(0xFFDBE8DC),
      tema: 'orman — koyu yeşil',
    ),
    // gri 50 / 102 / 226
    'Engelliler Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF123A5C),
      orta: PdfColor.fromInt(0xFF2E76A8),
      acik: PdfColor.fromInt(0xFFD8E5EE),
      tema: 'erişilebilirlik — mavi',
    ),
    // gri 53 / 111 / 226
    'Trafik ve İlkyardım Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF5A2A0C),
      orta: PdfColor.fromInt(0xFFB85A18),
      acik: PdfColor.fromInt(0xFFF0DFD1),
      tema: 'trafik — uyarı turuncusu',
    ),
    // gri 50 / 101 / 227
    'Çevre Koruma Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF17402F),
      orta: PdfColor.fromInt(0xFF357F5C),
      acik: PdfColor.fromInt(0xFFD9E8E1),
      tema: 'çevre — yaprak yeşili',
    ),
    // gri 53 / 107 / 227
    'Dünya Çocuk Hakları Günü': PanoPalette(
      koyu: PdfColor.fromInt(0xFF153C63),
      orta: PdfColor.fromInt(0xFF3878B0),
      acik: PdfColor.fromInt(0xFFD9E5EF),
      tema: 'çocuk hakları — BM mavisi',
    ),
    // gri 50 / 104 / 226
    'İlköğretim Haftası': PanoPalette(
      koyu: PdfColor.fromInt(0xFF1D3557),
      orta: PdfColor.fromInt(0xFF45709E),
      acik: PdfColor.fromInt(0xFFDCE3EC),
      tema: 'okul — defter mavisi',
    ),
  };
}
