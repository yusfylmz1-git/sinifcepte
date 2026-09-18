import '../data/tahta_yetki_deposu.dart';
import '../models/okul_config_model.dart';

/// `okul_config` dosyasına gidecek öğretmen listesini iki kaynaktan
/// birleştirir.
///
/// ## Neden iki kaynak var
///
/// 1. **Cihazdaki liste** (`TahtaOgretmenDeposu`) — idarecinin elle
///    eklediği öğretmenler. Telefonu olmayan öğretmen, yöneticisi
///    olmayan okul ve çevrimdışı kurulum için gerekli.
/// 2. **Buluttaki onaylı kayıtlar** (`school_boards/*/teachers`) —
///    öğretmenin kendi isteği, yönetici onayından geçmiş.
///
/// İkisi yan yana yaşıyor: otomatik kayıt **ek bir yol**, elle
/// eklemenin yerine geçmiyor (kullanıcı kararı).
///
/// ## Neden saf fonksiyon, ekran içinde değil
///
/// Ekran Firestore ve güvenli depo platform kanallarını istiyor;
/// birleştirme mantığı orada kalsaydı test edilemezdi. Bu dosyada
/// hiçbir yan etki yok.
///
/// ## Çakışma kuralı: CİHAZ kazanır
///
/// Aynı kod iki kaynakta varsa cihazdaki kayıt korunuyor. Sebep:
/// idareci o kaydı bilerek girmiş ve secret'ını öğretmene QR ile
/// vermiş olabilir. Bulut kaydı üzerine yazarsa öğretmenin
/// telefonundaki secret geçersiz olur ve öğretmen sebebini anlamaz —
/// bu hata sınıfı sahada teşhisi en zor olanlardan.
///
/// Kod karşılaştırması büyük/küçük harf duyarsız: tahtada elle
/// giriliyor ve `ogr001` ile `OGR001` aynı kişi.
List<PanoOgretmeni> ogretmenleriBirlestir({
  required List<PanoOgretmeni> cihaz,
  required List<TahtaYetkiKaydi> bulut,
}) {
  final sonuc = <PanoOgretmeni>[];
  final gorulenKodlar = <String>{};

  // Cihaz önce: çakışmada o kazanıyor.
  for (final o in cihaz) {
    final kod = o.kod.trim().toUpperCase();
    if (kod.isEmpty) continue;
    if (!gorulenKodlar.add(kod)) continue;
    sonuc.add(o);
  }

  for (final k in bulut) {
    // Yalnızca ONAYLI kayıtlar dosyaya girer. Çağıran taraf süzmüş
    // olsa da burada ayrıca kontrol ediliyor: bu süzgeç yetkinin
    // kendisi, unutulursa bekleyen istek tahtayı açar.
    if (!k.onayli) continue;

    final kod = k.kod.trim().toUpperCase();
    if (kod.isEmpty || k.totpSecret.isEmpty) continue;
    if (!gorulenKodlar.add(kod)) continue;
    sonuc.add(k.panoOgretmeni());
  }

  return sonuc;
}
