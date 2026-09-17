/// Tahtaya gidecek okul yapılandırması.
///
/// Alan adları, tahta tarafındaki Python çözücüsüyle **birebir**
/// eşleşmek zorundadır:
/// `sinifcepte-tahta/sinifcepte_tahta/cekirdek/yapilandirma.py`
///
/// Bir alan adı burada değişirse tahta onu okuyamaz ve sessizce
/// varsayılana düşer — sahada teşhisi zor bir hata. Bu yüzden anahtar
/// adları sabit olarak tutuluyor ve testle korunuyor.
library;

import '../../schedule/models/schedule_settings.dart';

/// Nöbetçi öğretmen kaydı — **haftalık döngü**, tarih bazlı değil.
///
/// Rakip ürünlerin hiçbirinde bulunmayan tek özellik bu; panonun
/// ayırt edici parçası.
///
/// ## Neden tarih değil gün
///
/// İlk tasarım ISO tarih (`2026-09-16`) kullanıyordu. Nöbet listesi
/// aylık değişiyor ve tarih bazlı yapıda her ay yeni yapılandırma
/// üretip **her tahtaya elden götürmek** gerekiyordu — 20 tahtalı bir
/// okulda bu yapılmaz. Haftalık döngü bir kez girilir, kendini tekrar
/// eder.
///
/// Tahta tarafı (`cekirdek/yapilandirma.py::Nobetci`) `gun` okuyor.
/// Bu alan `tarih` kaldığı sürece nöbetçiler tahtada **sessizce boş**
/// kalıyordu: imza geçerli, dosya yükleniyor, liste görünmüyordu.
class NobetciKaydi {
  /// Gün adı: `pazartesi`..`pazar`.
  ///
  /// Tahta tarafı büyük/küçük harf ve Türkçe aksanı kendisi katlıyor
  /// (`ekran.py::_gun_esles`), yani "Salı" da "SALI" da eşleşir.
  final String gun;
  final String kat;
  final String ad;

  const NobetciKaydi({
    required this.gun,
    required this.kat,
    required this.ad,
  });

  Map<String, Object?> toJson() => {
        'gun': gun,
        'kat': kat,
        'ad': ad,
      };
}

/// İdare duyurusu.
///
/// Sınıf duyurularıyla karıştırılmamalı: bunlar okul geneli ve veliye
/// değil **tahtaya** gider.
class PanoDuyurusu {
  final String id;
  final String baslik;
  final String metin;

  /// ISO zaman; boşsa hemen gösterilir.
  final String baslangic;

  /// ISO zaman; boşsa süresiz.
  final String bitis;

  const PanoDuyurusu({
    required this.id,
    required this.baslik,
    required this.metin,
    this.baslangic = '',
    this.bitis = '',
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'baslik': baslik,
        'metin': metin,
        'baslangic': baslangic,
        'bitis': bitis,
      };
}

/// Tahtada kilidi açabilecek öğretmen.
///
/// **KVKK notu:** buraya yalnızca öğretmenin adı ve açma sırları girer.
/// Öğrenci verisi ASLA girmez — tahta dosyası flash bellekle taşınıyor
/// ve okul içinde elden ele geçebiliyor.
class PanoOgretmeni {
  /// Tahtada elle girilebilen kısa kod (`OGR001`).
  final String kod;
  final String ad;

  /// TOTP secret'i (base32). Boşsa bu öğretmen TOTP ile açamaz.
  final String totpSecret;

  /// PIN'in argon2id özeti. Boşsa PIN ile açamaz.
  ///
  /// Ham PIN **asla** dosyaya yazılmaz.
  final String pinHash;

  const PanoOgretmeni({
    required this.kod,
    required this.ad,
    this.totpSecret = '',
    this.pinHash = '',
  });

  Map<String, Object?> toJson() => {
        'kod': kod,
        'ad': ad,
        'totpSecret': totpSecret,
        'pinHash': pinHash,
      };
}

/// Tahtaya gidecek yapılandırmanın tamamı.
class OkulConfigModel {
  /// Geri sarma koruması: tahta, kayıtlı sürümden küçük değeri reddeder.
  ///
  /// Her yayımda artmalı. Aksi halde saldırgan eski (imzası **geçerli**)
  /// bir dosyayı geri yükleyebilir; imza kontrolü bunu yakalamaz.
  final int surum;

  /// Kanonik okul kimliği (`meb_16_123456`).
  final String okulId;
  final String okulAdi;

  /// ISO zaman: bu dosyanın üretildiği an.
  final String uretimZamani;

  /// ISO zaman: bu tarihten sonra tahta dosyayı reddeder.
  ///
  /// Okul yılı bitince unutulmuş bir tahta eski veriyle çalışmasın.
  final String gecerlilikBitis;

  /// Zil düzeni. Öğretmenin mevcut ayarlarından üretilir.
  final ScheduleSettings zil;

  final List<PanoOgretmeni> ogretmenler;
  final List<NobetciKaydi> nobetciler;
  final List<PanoDuyurusu> duyurular;

  const OkulConfigModel({
    required this.surum,
    required this.okulId,
    required this.okulAdi,
    required this.uretimZamani,
    required this.gecerlilikBitis,
    required this.zil,
    this.ogretmenler = const [],
    this.nobetciler = const [],
    this.duyurular = const [],
  });

  /// Zil bloğu — Python `ZilAyarlari.sozlukten()` ile aynı anahtarlar.
  ///
  /// Bu eşleşme kritik: anahtar adı uyuşmazsa Python tarafı sessizce
  /// varsayılana düşer ve tahtadaki ders saatleri öğretmenin
  /// telefonundakinden farklı olur.
  Map<String, Object?> _zilJson() => {
        'ilkDersSaati': '${zil.firstLessonTime.hour.toString().padLeft(2, '0')}:'
            '${zil.firstLessonTime.minute.toString().padLeft(2, '0')}',
        'dersSuresi': zil.lessonDuration,
        'teneffusSuresi': zil.breakDuration,
        'gunlukDersSayisi': zil.dailyLessonCount,
        'ogleArasiVar': zil.hasLunchBreak,
        'ogleArasiSuresi': zil.lunchBreakDuration,
        'ogleArasiKacinciDerstenSonra': zil.lunchBreakAfterLesson,
      };

  /// İmzalanacak JSON yapısı.
  ///
  /// Alan sırası burada sabit; `TahtaImza.jsonBaytlari` bu haritayı
  /// aynı biçimde kodlayarak imzalanan baytları üretir.
  Map<String, Object?> toJson() => {
        'surum': surum,
        'okulId': okulId,
        'okulAdi': okulAdi,
        'uretimZamani': uretimZamani,
        'gecerlilikBitis': gecerlilikBitis,
        'zil': _zilJson(),
        'ogretmenler': ogretmenler.map((o) => o.toJson()).toList(),
        'nobetciler': nobetciler.map((n) => n.toJson()).toList(),
        'duyurular': duyurular.map((d) => d.toJson()).toList(),
      };

  /// Tahtanın zorunlu tuttuğu alanlar dolu mu?
  ///
  /// Python tarafı `okulId`, `okulAdi` ve `zil` yoksa dosyayı reddediyor
  /// (`yapilandirma.py`). Hatayı sahada değil üretim anında yakalamak
  /// için burada da kontrol edilir.
  List<String> eksikAlanlar() {
    final eksikler = <String>[];
    if (okulId.trim().isEmpty) eksikler.add('okulId');
    if (okulAdi.trim().isEmpty) eksikler.add('okulAdi');
    if (surum < 1) eksikler.add('surum');
    return eksikler;
  }
}
