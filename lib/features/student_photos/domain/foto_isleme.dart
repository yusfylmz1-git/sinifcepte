import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// e-Okul öğrenci fotoğrafı — tam 133×171 piksel üretimi.
///
/// ## Kural (kullanıcı teyidi, 30 Eylül 2026)
/// e-Okul öğrenci fotoğrafı 133 piksel genişlik × 171 piksel yükseklik.
/// Görüntü hiçbir durumda ESNETİLMEZ: 133:171 oranlı alan kırpılır, sonra
/// tek seferde küçültülür.
///
/// ## Neden saf Dart
/// Kamera, dosya seçici ve ekran bu işlevi çağırır; ölçünün doğruluğu
/// cihazsız test edilebilsin. `image` paketi Android/iOS/Windows'ta aynı
/// sonucu verir.
///
/// ## Gizlilik
/// Çıktıda EXIF YOK: konum (GPS), cihaz modeli, çekim saati fotoğrafla
/// birlikte e-Okul'a ya da dışa aktarılan klasöre gitmesin.
const int eokulGenislik = 133;
const int eokulYukseklik = 171;
const double eokulOran = eokulGenislik / eokulYukseklik;

/// Varsayılan JPEG kalitesi. e-Okul'un KB sınırı doğrulanmadı; doğrulanırsa
/// ölçü değişmeden kalite aranır (plan §6).
const int varsayilanKalite = 90;

class FotoIslemeHatasi implements Exception {
  FotoIslemeHatasi(this.mesaj);
  final String mesaj;
  @override
  String toString() => mesaj;
}

/// Kaynak görüntüde (yönü DÜZELTİLMİŞ koordinatlarda) kırpılacak alan.
class KirpmaAlani {
  const KirpmaAlani(this.x, this.y, this.genislik, this.yukseklik);

  final int x;
  final int y;
  final int genislik;
  final int yukseklik;

  @override
  String toString() => 'KirpmaAlani($x, $y, $genislik×$yukseklik)';
}

/// Dosyayı çözer ve EXIF yönünü uygular.
///
/// Telefon fotoğrafları çoğu zaman yatay kaydedilip "döndür" bilgisi
/// EXIF'te taşınıyor; uygulanmazsa öğrenci yan yatık kırpılırdı. Kırpma
/// alanı bu işlevin döndürdüğü görüntünün koordinatlarındadır.
img.Image duzeltilmisGoruntu(Uint8List kaynak) {
  img.Image? cozulen;
  try {
    cozulen = img.decodeImage(kaynak);
  } catch (_) {
    // Bozuk/kesik dosyada paket kendi hatasını (RangeError vb.) atıyor;
    // ekran tek tür hata görsün.
    cozulen = null;
  }
  if (cozulen == null) {
    throw FotoIslemeHatasi('Dosya açılamadı ya da resim değil.');
  }
  return img.bakeOrientation(cozulen);
}

/// Görüntüye sığan EN BÜYÜK, ortalanmış 133:171 alan.
///
/// `merkezX`/`merkezY` (0–1) verilirse alan oraya kaydırılır ama görüntü
/// dışına taşmaz. `olcek` (0–1] alanı küçültür (yakınlaştırma).
KirpmaAlani kirpmaAlani(
  int kaynakGenislik,
  int kaynakYukseklik, {
  double merkezX = 0.5,
  double merkezY = 0.5,
  double olcek = 1.0,
}) {
  if (kaynakGenislik <= 0 || kaynakYukseklik <= 0) {
    throw FotoIslemeHatasi('Görüntü boş.');
  }
  // Oranı koruyan en büyük dikdörtgen.
  var g = kaynakGenislik.toDouble();
  var y = g / eokulOran;
  if (y > kaynakYukseklik) {
    y = kaynakYukseklik.toDouble();
    g = y * eokulOran;
  }
  final o = olcek.clamp(0.05, 1.0);
  g *= o;
  y *= o;

  var x0 = merkezX * kaynakGenislik - g / 2;
  var y0 = merkezY * kaynakYukseklik - y / 2;
  x0 = x0.clamp(0, kaynakGenislik - g).toDouble();
  y0 = y0.clamp(0, kaynakYukseklik - y).toDouble();

  final gi = g.floor().clamp(1, kaynakGenislik);
  final yi = y.floor().clamp(1, kaynakYukseklik);
  return KirpmaAlani(
    x0.round().clamp(0, kaynakGenislik - gi),
    y0.round().clamp(0, kaynakYukseklik - yi),
    gi,
    yi,
  );
}

/// Tam 133×171 JPEG üretir ve kendi çıktısını doğrular.
///
/// `alan` verilmezse ortalanmış en büyük alan. `dondurDerece` küçük açı
/// düzeltmesi içindir (göz hattı eğikse); kırpmadan ÖNCE uygulanır.
Uint8List standartFotoUret(
  img.Image duzeltilmis, {
  KirpmaAlani? alan,
  double dondurDerece = 0,
  int kalite = varsayilanKalite,
}) {
  var kaynak = duzeltilmis;
  if (dondurDerece.abs() > 0.01) {
    kaynak = img.copyRotate(kaynak, angle: dondurDerece, interpolation: img.Interpolation.cubic);
  }
  final a = alan ?? kirpmaAlani(kaynak.width, kaynak.height);
  if (a.x < 0 ||
      a.y < 0 ||
      a.x + a.genislik > kaynak.width ||
      a.y + a.yukseklik > kaynak.height) {
    throw FotoIslemeHatasi('Kırpma alanı görüntünün dışına taşıyor.');
  }
  final kirpilmis = img.copyCrop(
    kaynak,
    x: a.x,
    y: a.y,
    width: a.genislik,
    height: a.yukseklik,
  );
  final kucuk = img.copyResize(
    kirpilmis,
    width: eokulGenislik,
    height: eokulYukseklik,
    interpolation: img.Interpolation.cubic,
  );
  // EXIF, ICC ve metin alanları yok: konum/cihaz bilgisi çıkmasın.
  kucuk.exif = img.ExifData();
  kucuk.iccProfile = null;
  kucuk.textData = null;
  final jpeg = Uint8List.fromList(img.encodeJpg(kucuk, quality: kalite));
  dogrula(jpeg);
  return jpeg;
}

// ---------------------------------------------------------------------
// Çalışma görüntüsü: seçilen fotoğrafın kırpma ekranında kullanılan,
// yönü düzeltilmiş ve küçültülmüş kopyası.
// ---------------------------------------------------------------------

/// Kırpma ekranının üzerinde çalıştığı görüntünün uzun kenarı.
///
/// Çıktı 133×171; 2000 piksel, yüzü 10 kat yakınlaştırsa bile çıktıdan
/// büyük kalır. Tam boy 50 MP fotoğrafı bellekte tutmak (≈200 MB) düşük
/// donanımlı telefonda uygulamayı kapatabilirdi.
const int calismaUzunKenar = 2000;

/// Açılmadan reddedilen sınırlar: bellek taşmasına karşı.
const int kaynakEnFazlaBayt = 40 * 1024 * 1024;
const int kaynakEnFazlaPiksel = 60 * 1000 * 1000;

/// Kırpılan alan bundan küçükse fotoğraf büyütülerek üretilir ve bulanık
/// olur; kayıt öğretmen onayı ister.
const String kaliteDusukCozunurluk = 'dusuk_cozunurluk';

class CalismaGoruntusu {
  const CalismaGoruntusu(this.jpeg, this.genislik, this.yukseklik);

  /// Yönü uygulanmış, EXIF'siz JPEG. Ekranda doğrudan gösterilir.
  final Uint8List jpeg;
  final int genislik;
  final int yukseklik;
}

bool _heicMi(Uint8List b) {
  if (b.length < 12) return false;
  final tur = String.fromCharCodes(b.sublist(4, 12));
  return tur == 'ftypheic' || tur == 'ftypheix' || tur == 'ftypmif1' || tur == 'ftyphevc';
}

/// Seçilen dosyayı kırpma ekranına hazırlar. AYRI İZOLATTA çağrılmalı
/// (`Isolate.run`): çözme ve küçültme ana iş parçacığını dondurur.
CalismaGoruntusu calismaGoruntusuHazirla(Uint8List kaynak) {
  if (kaynak.length > kaynakEnFazlaBayt) {
    throw FotoIslemeHatasi('Dosya çok büyük (en fazla 40 MB).');
  }
  if (_heicMi(kaynak)) {
    throw FotoIslemeHatasi(
      'Bu fotoğraf HEIC biçiminde ve açılamıyor. Galeriden seçerek '
      'deneyin ya da fotoğrafı JPEG olarak kaydedin.',
    );
  }
  // Önce yalnızca başlığı oku: çok büyük görüntüyü açmadan reddet.
  final cozucu = img.findDecoderForData(kaynak);
  if (cozucu == null) {
    throw FotoIslemeHatasi('Dosya açılamadı ya da resim değil (JPEG/PNG seçin).');
  }
  try {
    final bilgi = cozucu.startDecode(kaynak);
    // Ölçü okunamıyorsa AÇMA (ek önlem): boyutunu bilmediğimiz görüntüyü
    // tam çözmek bellek sınırını atlamak olurdu. Bilinen bir örneği yok;
    // eksik başlıklı PNG'yi tam çözücü de zaten reddediyor.
    if (bilgi == null) {
      throw FotoIslemeHatasi('Dosya açılamadı ya da bozuk.');
    }
    if (bilgi.width * bilgi.height > kaynakEnFazlaPiksel) {
      throw FotoIslemeHatasi('Fotoğraf çok büyük (${bilgi.width}×${bilgi.height}).');
    }
  } on FotoIslemeHatasi {
    rethrow;
  } catch (_) {
    throw FotoIslemeHatasi('Dosya açılamadı ya da resim değil.');
  }

  var g = duzeltilmisGoruntu(kaynak);
  final uzun = g.width > g.height ? g.width : g.height;
  if (uzun > calismaUzunKenar) {
    g = g.width >= g.height
        ? img.copyResize(g, width: calismaUzunKenar, interpolation: img.Interpolation.average)
        : img.copyResize(g, height: calismaUzunKenar, interpolation: img.Interpolation.average);
  }
  if (g.width < 40 || g.height < 50) {
    throw FotoIslemeHatasi('Fotoğraf çok küçük (${g.width}×${g.height}).');
  }
  return _calismaKodla(g);
}

CalismaGoruntusu _calismaKodla(img.Image g) {
  // Saydam PNG: JPEG'de siyaha dönmesin, beyaz zemin.
  if (g.hasAlpha) {
    final zemin = img.Image(width: g.width, height: g.height);
    img.fill(zemin, color: img.ColorRgb8(255, 255, 255));
    g = img.compositeImage(zemin, g);
  }
  g.exif = img.ExifData();
  g.iccProfile = null;
  g.textData = null;
  return CalismaGoruntusu(Uint8List.fromList(img.encodeJpg(g, quality: 92)), g.width, g.height);
}

/// Küçük açı düzeltmesi. Tuval büyür, köşeler boş kalır; kırpma
/// ekranı bu yeni ölçüyle çalışır. AYRI İZOLATTA.
///
/// Her zaman DÖNDÜRÜLMEMİŞ çalışma görüntüsüne uygulanır; açılar üst
/// üste eklenmez (her adımda kalite kaybı birikmesin).
CalismaGoruntusu calismaGoruntusunuDondur(CalismaGoruntusu c, double derece) {
  if (derece.abs() < 0.01) return c;
  // Saydamlık kanalı şart: yoksa döndürmenin açtığı köşeler siyah
  // dolar ve beyaz zemin işe yaramaz.
  final g = img.decodeJpg(c.jpeg)!.convert(numChannels: 4);
  final d = img.copyRotate(g, angle: derece, interpolation: img.Interpolation.cubic);
  // Boş köşeler beyaz (siyah köşe e-Okul'da çirkin durur).
  final zemin = img.Image(width: d.width, height: d.height);
  img.fill(zemin, color: img.ColorRgb8(255, 255, 255));
  return _calismaKodla(img.compositeImage(zemin, d));
}

/// Kırpma ekranının sonucu: standart fotoğraf ve kalite uyarıları.
class UretimSonucu {
  const UretimSonucu(this.jpeg, this.kaliteUyarilari);
  final Uint8List jpeg;
  final List<String> kaliteUyarilari;
}

/// Çalışma görüntüsünden (döndürülmüşse döndürülmüş hâlinden) standart
/// fotoğraf. AYRI İZOLATTA.
UretimSonucu calismadanUret(CalismaGoruntusu c, KirpmaAlani alan) {
  final g = img.decodeJpg(c.jpeg)!;
  final jpeg = standartFotoUret(g, alan: alan);
  return UretimSonucu(jpeg, [
    if (alan.genislik < eokulGenislik || alan.yukseklik < eokulYukseklik) kaliteDusukCozunurluk,
  ]);
}

/// Diskten ya da bellekten gelen standart fotoğrafı doğrular.
///
/// Kayıt ve dışa aktarma bu kapıdan geçmeyen dosyayı kabul etmez.
void dogrula(Uint8List jpeg) {
  if (jpeg.length < 3 || jpeg[0] != 0xFF || jpeg[1] != 0xD8 || jpeg[2] != 0xFF) {
    throw FotoIslemeHatasi('Dosya JPEG değil.');
  }
  img.Image? cozulen;
  try {
    cozulen = img.decodeJpg(jpeg);
  } catch (_) {
    cozulen = null;
  }
  if (cozulen == null) {
    throw FotoIslemeHatasi('Fotoğraf okunamadı.');
  }
  if (cozulen.width != eokulGenislik || cozulen.height != eokulYukseklik) {
    throw FotoIslemeHatasi(
      'Fotoğraf $eokulGenislik×$eokulYukseklik değil (${cozulen.width}×${cozulen.height}).',
    );
  }
}
