// Pano görselleri — vektörel motifler.
//
// ## Neden vektör, neden gömülü görsel değil
//
// Panoya basılan görsel A3'e kadar büyüyor. Gömülü PNG bu ölçekte
// bozuluyor, APK'yı da megabaytlarca şişiriyordu. SVG her ölçekte
// keskin çıkar ve dosya olarak birkaç yüz bayt tutar.
//
// ## Gri merdiven burada da geçerli
//
// Motifler kendi rengini seçmez; çağıran [PanoPalette] üçlüsünü verir.
// Böylece öğretmenlerin çoğunun kullandığı siyah-beyaz yazıcıda motif
// de metinle aynı hiyerarşiye oturur (bkz. pano_palette.dart).
//
// ## Motif seçimi keyfî değil
//
// Her motif bir güne değil, bir *anlama* bağlı: sandık oy vermeyi,
// zeytin dalı barışı, fidan büyümeyi anlatır. Aynı motif anlamı örtüşen
// birden çok günde kullanılır — 20 gün için 20 ayrı çizim tutmak yerine
// anlam havuzu tutuluyor.

import 'dart:math' as math;

import 'package:pdf/pdf.dart';

import 'pano_palette.dart';

/// Panoya basılabilir vektörel motif üreticisi.
///
/// Her metot tam bir SVG belgesi döner; `pw.SvgImage(svg: ...)` ile
/// doğrudan basılır.
class PanoMotifler {
  const PanoMotifler._();

  static String _hex(PdfColor c) {
    int b(double v) => (v * 255).round().clamp(0, 255);
    return '#${b(c.red).toRadixString(16).padLeft(2, '0')}'
        '${b(c.green).toRadixString(16).padLeft(2, '0')}'
        '${b(c.blue).toRadixString(16).padLeft(2, '0')}';
  }

  static String _sar(String govde, {double en = 100, double boy = 100}) =>
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'viewBox="0 0 $en $boy">$govde</svg>';

  // ------------------------------------------------------------------
  // Köşe ve çerçeve süsleri — her günde kullanılabilir.
  // ------------------------------------------------------------------

  /// Köşe süsü: iç içe iki yay. Panonun dört köşesine döndürülerek
  /// basılır; sayfayı çerçeveler ama metin alanını daraltmaz.
  static String koseSusu(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    return _sar(
      '<path d="M2 40 Q2 2 40 2" fill="none" stroke="$k" stroke-width="4" '
      'stroke-linecap="round"/>'
      '<path d="M2 62 Q2 2 62 2" fill="none" stroke="$o" stroke-width="2" '
      'stroke-linecap="round"/>'
      '<circle cx="2" cy="2" r="4" fill="$k"/>',
      en: 70,
      boy: 70,
    );
  }

  /// Başlık altı ayraç: ortada baklava, iki yana incelen çizgi.
  static String ayrac(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    return _sar(
      '<line x1="0" y1="6" x2="86" y2="6" stroke="$o" stroke-width="1.4"/>'
      '<line x1="114" y1="6" x2="200" y2="6" stroke="$o" stroke-width="1.4"/>'
      '<rect x="94" y="0" width="12" height="12" fill="$k" '
      'transform="rotate(45 100 6)"/>',
      en: 200,
      boy: 12,
    );
  }

  /// Kesme çizgisi — makasla kesilecek kartların kenarı.
  ///
  /// Makas simgesi solda durur; öğretmen çizgiyi süs sanıp bırakmasın.
  static String kesmeCizgisi(PanoPalette p) {
    final o = _hex(p.orta);
    return _sar(
      '<line x1="16" y1="6" x2="200" y2="6" stroke="$o" stroke-width="1.2" '
      'stroke-dasharray="6 4"/>'
      '<circle cx="4" cy="3" r="2.4" fill="none" stroke="$o" '
      'stroke-width="1.2"/>'
      '<circle cx="4" cy="9" r="2.4" fill="none" stroke="$o" '
      'stroke-width="1.2"/>'
      '<line x1="6" y1="4" x2="13" y2="8" stroke="$o" stroke-width="1.2"/>'
      '<line x1="6" y1="8" x2="13" y2="4" stroke="$o" stroke-width="1.2"/>',
      en: 200,
      boy: 12,
    );
  }

  /// Üçgen flama dizisi — pano üstüne asılan bayrak sırası.
  static String flamaDizisi(PanoPalette p, {int adet = 7}) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final b = StringBuffer(
      '<line x1="0" y1="3" x2="210" y2="3" stroke="$k" stroke-width="1.6"/>',
    );
    for (var i = 0; i < adet; i++) {
      final x = 6.0 + i * 29.0;
      b.write('<path d="M$x 3 L${x + 22} 3 L${x + 11} 34 Z" '
          'fill="${i.isEven ? k : o}"/>');
    }
    return _sar(b.toString(), en: 210, boy: 36);
  }

  // ------------------------------------------------------------------
  // Anlam motifleri.
  // ------------------------------------------------------------------

  /// Sandık — oy vermeyi, milletin kararını anlatır.
  static String sandik(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final a = _hex(p.acik);
    return _sar(
      '<rect x="14" y="40" width="72" height="50" rx="4" fill="$a" '
      'stroke="$k" stroke-width="3"/>'
      '<rect x="38" y="46" width="24" height="4" rx="2" fill="$k"/>'
      '<rect x="42" y="14" width="16" height="22" rx="2" fill="$o" '
      'stroke="$k" stroke-width="2.4"/>'
      '<path d="M46 26 l4 4 l8 -9" fill="none" stroke="$k" '
      'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    );
  }

  /// El ele halka — birlik, dayanışma.
  static String birlikHalkasi(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final b = StringBuffer();
    for (var i = 0; i < 6; i++) {
      final aci = (i * 60 - 90) * math.pi / 180;
      final cx = 50 + 30 * math.cos(aci);
      final cy = 50 + 30 * math.sin(aci);
      b.write('<circle cx="${cx.toStringAsFixed(1)}" '
          'cy="${cy.toStringAsFixed(1)}" r="9" '
          'fill="${i.isEven ? k : o}"/>');
    }
    // Halkayı bağlayan çember: kesikli çizgi küçük ölçekte kopuk
    // görünüyordu, düz ince çizgi baskıda daha temiz çıkıyor.
    b.write('<circle cx="50" cy="50" r="30" fill="none" stroke="$o" '
        'stroke-width="1.4"/>');
    return _sar(b.toString());
  }

  /// Açık kitap — öğrenme, bilgi.
  static String kitap(PanoPalette p) {
    final k = _hex(p.koyu);
    final a = _hex(p.acik);
    return _sar(
      '<path d="M50 30 C38 20 22 20 12 24 L12 76 C22 72 38 72 50 80 Z" '
      'fill="$a" stroke="$k" stroke-width="3" stroke-linejoin="round"/>'
      '<path d="M50 30 C62 20 78 20 88 24 L88 76 C78 72 62 72 50 80 Z" '
      'fill="$a" stroke="$k" stroke-width="3" stroke-linejoin="round"/>'
      '<line x1="50" y1="30" x2="50" y2="80" stroke="$k" '
      'stroke-width="2.4"/>',
    );
  }

  /// Fidan — büyüme, gelecek, çevre.
  static String fidan(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    return _sar(
      '<line x1="50" y1="86" x2="50" y2="42" stroke="$k" stroke-width="4" '
      'stroke-linecap="round"/>'
      '<path d="M50 56 C34 52 26 40 28 28 C42 28 50 40 50 56 Z" fill="$o"/>'
      '<path d="M50 48 C66 44 74 32 72 20 C58 20 50 32 50 48 Z" fill="$k"/>'
      '<path d="M30 88 Q50 82 70 88" fill="none" stroke="$o" '
      'stroke-width="2.4" stroke-linecap="round"/>',
    );
  }

  /// Zeytin dalı — barış, anma.
  static String zeytinDali(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    // Dal düz bir doğru; yapraklar bu doğrunun üstünde eşit aralıkla
    // ve iki yana açılı duruyor. Eğri dal üzerinde yaprak hizalamak
    // elle yapılınca kayıyordu.
    final b = StringBuffer(
      '<line x1="12" y1="84" x2="88" y2="20" stroke="$k" '
      'stroke-width="3" stroke-linecap="round"/>',
    );
    for (var i = 0; i < 5; i++) {
      final t = 0.12 + i * 0.19;
      final x = 12 + 76 * t;
      final y = 84 - 64 * t;
      b.write('<ellipse cx="${(x - 9).toStringAsFixed(1)}" '
          'cy="${(y - 5).toStringAsFixed(1)}" rx="9" ry="4.6" fill="$o" '
          'transform="rotate(-40 ${(x - 9).toStringAsFixed(1)} '
          '${(y - 5).toStringAsFixed(1)})"/>');
      b.write('<ellipse cx="${(x + 9).toStringAsFixed(1)}" '
          'cy="${(y + 5).toStringAsFixed(1)}" rx="9" ry="4.6" fill="$k" '
          'transform="rotate(-40 ${(x + 9).toStringAsFixed(1)} '
          '${(y + 5).toStringAsFixed(1)})"/>');
    }
    return _sar(b.toString());
  }

  /// Meşale — aydınlanma, öğretmenlik, bilim.
  static String mesale(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    return _sar(
      '<path d="M50 12 C60 26 66 34 66 44 C66 55 59 62 50 62 '
      'C41 62 34 55 34 44 C34 34 40 26 50 12 Z" fill="$o"/>'
      '<path d="M50 26 C56 36 58 40 58 46 C58 52 55 56 50 56 '
      'C45 56 42 52 42 46 C42 40 44 36 50 26 Z" fill="$k"/>'
      '<rect x="44" y="62" width="12" height="26" rx="3" fill="$k"/>'
      '<rect x="38" y="60" width="24" height="7" rx="3" fill="$o"/>',
    );
  }

  /// Kalp içinde el — yardımlaşma, Kızılay, engelliler haftası.
  static String yardimEli(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final a = _hex(p.acik);
    return _sar(
      '<path d="M50 84 C22 66 12 52 12 38 C12 26 21 18 32 18 '
      'C40 18 46 22 50 29 C54 22 60 18 68 18 C79 18 88 26 88 38 '
      'C88 52 78 66 50 84 Z" fill="$a" stroke="$k" stroke-width="3" '
      'stroke-linejoin="round"/>'
      '<path d="M38 52 L38 38 M45 52 L45 34 M52 52 L52 36 M59 52 L59 40" '
      'stroke="$o" stroke-width="4" stroke-linecap="round"/>'
      '<path d="M34 50 L34 60 Q34 68 44 68 L56 68 Q64 68 64 60 L64 48" '
      'fill="none" stroke="$o" stroke-width="4" stroke-linejoin="round" '
      'stroke-linecap="round"/>',
    );
  }

  /// Kumbara — tutum, tasarruf, biriktirme.
  static String kumbara(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final a = _hex(p.acik);
    return _sar(
      // bacaklar önce, gövdenin altında kalsın
      '<rect x="26" y="70" width="9" height="16" rx="3" fill="$k"/>'
      '<rect x="65" y="70" width="9" height="16" rx="3" fill="$k"/>'
      // gövde
      '<ellipse cx="50" cy="52" rx="33" ry="25" fill="$a" stroke="$k" '
      'stroke-width="3"/>'
      // burun
      '<ellipse cx="82" cy="54" rx="9" ry="7" fill="$a" stroke="$k" '
      'stroke-width="3"/>'
      '<circle cx="80" cy="54" r="1.8" fill="$k"/>'
      '<circle cx="85" cy="54" r="1.8" fill="$k"/>'
      // kulak
      '<path d="M40 30 L52 30 L44 42 Z" fill="$o" stroke="$k" '
      'stroke-width="2.4" stroke-linejoin="round"/>'
      // göz
      '<circle cx="62" cy="46" r="3" fill="$k"/>'
      // para yarığı
      '<rect x="36" y="32" width="20" height="4" rx="2" fill="$k"/>'
      // düşen madenî para
      '<circle cx="46" cy="14" r="9" fill="$o" stroke="$k" '
      'stroke-width="2.4"/>',
    );
  }

  /// Trafik ışığı — trafik ve ilk yardım haftası.
  static String trafikIsigi(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final a = _hex(p.acik);
    return _sar(
      '<rect x="32" y="10" width="36" height="70" rx="9" fill="$a" '
      'stroke="$k" stroke-width="3"/>'
      '<circle cx="50" cy="28" r="9" fill="$k"/>'
      '<circle cx="50" cy="46" r="9" fill="$o"/>'
      '<circle cx="50" cy="64" r="9" fill="none" stroke="$k" '
      'stroke-width="2.4"/>'
      '<line x1="50" y1="80" x2="50" y2="92" stroke="$k" stroke-width="4" '
      'stroke-linecap="round"/>',
    );
  }

  /// Ay-yıldız — millî günler. Bayrağın kendisi değil, sembolü.
  ///
  /// Türk Bayrağı Kanunu bayrağın ölçülerini ve kullanımını bağlar;
  /// panoya bayrak basmak yerine ay-yıldız motifi kullanmak hem daha
  /// güvenli hem de tek renkli baskıda daha temiz çıkar.
  static String ayYildiz(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    return _sar(
      // hilal: büyük daireden küçük daireyi oyan iki yay
      '<path d="M58 16 A34 34 0 1 0 58 84 A27 27 0 1 1 58 16 Z" '
      'fill="$k"/>'
      // beş köşeli yıldız
      '<path d="M74 34 L79 47 L93 47 L82 55 L86 68 L74 60 '
      'L62 68 L66 55 L55 47 L69 47 Z" fill="$o"/>',
    );
  }

  /// Su damlası ve yaprak — sağlıklı yaşam, temizlik, Yeşilay.
  static String damla(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final a = _hex(p.acik);
    return _sar(
      '<path d="M50 12 C50 12 78 44 78 60 C78 76 65 88 50 88 '
      'C35 88 22 76 22 60 C22 44 50 12 50 12 Z" fill="$a" '
      'stroke="$k" stroke-width="3" stroke-linejoin="round"/>'
      '<path d="M50 44 C60 44 68 52 68 62 C58 62 50 54 50 44 Z" '
      'fill="$o"/>'
      '<path d="M50 44 C40 44 32 52 32 62 C42 62 50 54 50 44 Z" '
      'fill="$k"/>'
      '<line x1="50" y1="44" x2="50" y2="76" stroke="$k" '
      'stroke-width="2.6" stroke-linecap="round"/>',
    );
  }

  /// Dişli ve devre — bilim ve teknoloji.
  static String disli(PanoPalette p) {
    final k = _hex(p.koyu);
    final o = _hex(p.orta);
    final b = StringBuffer();
    for (var i = 0; i < 8; i++) {
      final aci = i * 45.0;
      b.write('<rect x="45" y="6" width="10" height="16" rx="2" fill="$k" '
          'transform="rotate($aci 50 50)"/>');
    }
    b.write('<circle cx="50" cy="50" r="30" fill="$o" stroke="$k" '
        'stroke-width="3"/>');
    b.write('<circle cx="50" cy="50" r="12" fill="none" stroke="$k" '
        'stroke-width="4"/>');
    return _sar(b.toString());
  }

  // ------------------------------------------------------------------
  // Gün → motif eşlemesi.
  // ------------------------------------------------------------------

  /// Günün anlamına en yakın motif.
  ///
  /// Eşleşme bulunamazsa [ayrac] döner — süs olarak her sayfada durur,
  /// yanlış bir simge basmaktan iyidir.
  static String gunMotifi(String gunAdi, PanoPalette p) {
    switch (gunAdi) {
      // Millî günler — ay-yıldız.
      case 'Cumhuriyet Bayramı':
      case 'Zafer Bayramı':
      case 'Atatürk Haftası':
      case "Atatürk'ü Anma ve Gençlik ve Spor Bayramı":
      case "İstiklâl Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü":
        return ayYildiz(p);

      // Egemenlik ve millî irade — sandık.
      case 'Ulusal Egemenlik ve Çocuk Bayramı':
      case '15 Temmuz Demokrasi ve Millî Birlik Günü':
        return sandik(p);

      // Anma — zeytin dalı.
      case 'Şehitler Günü':
        return zeytinDali(p);

      // Öğrenme ve okul.
      case 'Öğretmenler Günü':
        return mesale(p);
      case 'İlköğretim Haftası':
        return kitap(p);
      case 'Bilim ve Teknoloji Haftası':
        return disli(p);

      // Doğa.
      case 'Orman Haftası':
      case 'Çevre Koruma Haftası':
        return fidan(p);

      // Yardımlaşma ve haklar.
      case 'Kızılay Haftası':
      case 'Engelliler Haftası':
      case 'Dünya Çocuk Hakları Günü':
        return yardimEli(p);

      // Sağlık.
      case 'Yeşilay Haftası':
        return damla(p);

      // Tutum ve tasarruf.
      case 'Tutum, Yatırım ve Türk Malları Haftası':
      case 'Enerji Tasarrufu Haftası':
        return kumbara(p);

      case 'Trafik ve İlkyardım Haftası':
        return trafikIsigi(p);

      default:
        return ayrac(p);
    }
  }

  /// Günün motifi ayırt edici mi, yoksa yedek ayraç mı?
  ///
  /// Çağıran, yedek durumda motifi büyük basmak yerine küçük bir süs
  /// olarak kullanmak isteyebilir.
  static bool gunMotifiVar(String gunAdi) =>
      gunMotifi(gunAdi, _olcut) != ayrac(_olcut);

  static const _olcut = PanoPalette(
    koyu: PdfColor.fromInt(0xFF000000),
    orta: PdfColor.fromInt(0xFF808080),
    acik: PdfColor.fromInt(0xFFE0E0E0),
    tema: 'ölçüt',
  );
}
