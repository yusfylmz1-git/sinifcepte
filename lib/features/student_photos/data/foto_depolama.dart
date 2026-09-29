import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/foto_isleme.dart';

/// Öğrenci fotoğraflarının disk düzeni.
///
/// ```text
/// <uygulama destek dizini>/student_photos/
///   <hesap alanı>/<öğrenci id>/<foto id>/standard.jpg
/// ```
///
/// ## Kurallar (plan §9.1)
/// - Yolda öğrenci adı ya da okul numarası YOK; yalnızca kimlikler.
///   Okunaklı ad (`<no>_<Ad>_<SOYAD>.jpg`) yalnızca dışa aktarmada
///   üretilir.
/// - Uygulamanın ÖZEL alanı: galeriye düşmez, başka uygulama göremez.
/// - Veritabanında göreli yol tutulur; mutlak yol cihaz/yedek değişince
///   bozulur.
/// - Hesap alanı SQLite dosya adından türer: her Google hesabının ayrı
///   veritabanı olduğu gibi ayrı fotoğraf klasörü olur (Seçenek A).
///
/// ## Yol denetimi
/// Veritabanındaki yol yedekten gelmiş ya da kurcalanmış olabilir.
/// [dosya] ve [sil] kalıba uymayan yolu REDDEDER: `../` ile kök dışına
/// çıkıp başka dosya silmek mümkün olmasın.
class FotoDepolama {
  FotoDepolama(this.kok);

  /// `student_photos` kök dizini.
  final Directory kok;

  static Future<FotoDepolama> uygulamaIcin() async {
    final destek = await getApplicationSupportDirectory();
    return FotoDepolama(Directory(p.join(destek.path, 'student_photos')));
  }

  static final RegExp _gecerliYol = RegExp(
    r'^[A-Za-z0-9_-]{1,120}/[0-9]{1,18}/[0-9a-f]{32}/'
    r'(standard|album|original_background)\.jpg$',
  );

  /// Yarım kalmış yazma. Uzlaştırma bunları yaşına bakarak siler.
  static const String geciciUzanti = '.yaziliyor';

  /// Veritabanı dosya yolundan hesap alanı: `sinifcepte_<uid>.db` →
  /// `sinifcepte_<uid>`. Girişsiz masaüstü kullanımında ortak dosyanın
  /// adı (`sinifcepte`) kendi alanı olur.
  static String hesapAlani(String veritabaniYolu) {
    final ad = p.basenameWithoutExtension(veritabaniYolu);
    final temiz = ad.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (temiz.isEmpty) return 'yerel';
    return temiz.length > 120 ? temiz.substring(0, 120) : temiz;
  }

  /// 128 bit rastgele, 32 küçük onaltılık hane. Klasör adı da bu.
  static String yeniFotoKimligi([Random? rastgele]) {
    final r = rastgele ?? Random.secure();
    final b = StringBuffer();
    for (var i = 0; i < 16; i++) {
      b.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  static String standartYol(String hesap, int ogrenciId, String fotoId) =>
      '$hesap/$ogrenciId/$fotoId/standard.jpg';

  static bool gecerliMi(String goreliYol) => _gecerliYol.hasMatch(goreliYol);

  static String ozet(List<int> bayt) => sha256.convert(bayt).toString();

  File dosya(String goreliYol) {
    if (!gecerliMi(goreliYol)) {
      throw ArgumentError.value(goreliYol, 'goreliYol', 'geçersiz fotoğraf yolu');
    }
    return File(p.joinAll([kok.path, ...goreliYol.split('/')]));
  }

  /// Geçici dosyaya yazar, GERİ OKUYUP doğrular, sonra yerine taşır.
  ///
  /// Uygulama yazarken kapanırsa hedefte yarım JPEG kalmaz; yalnızca
  /// `.yaziliyor` uzantılı artık kalır, uzlaştırma onu temizler.
  /// Döndürdüğü değer dosyanın SHA-256 özeti.
  Future<String> atomikYaz(String goreliYol, Uint8List bayt) async {
    final hedef = dosya(goreliYol);
    await hedef.parent.create(recursive: true);
    final gecici = File('${hedef.path}$geciciUzanti');
    await gecici.writeAsBytes(bayt, flush: true);

    final geriOkunan = await gecici.readAsBytes();
    final beklenen = ozet(bayt);
    if (ozet(geriOkunan) != beklenen) {
      await _sessizSil(gecici);
      throw const FileSystemException('Fotoğraf diske eksik yazıldı.');
    }
    try {
      dogrula(geriOkunan);
    } catch (_) {
      await _sessizSil(gecici);
      rethrow;
    }
    await gecici.rename(hedef.path);
    return beklenen;
  }

  /// Dosyayı siler; boşalan foto ve öğrenci klasörünü de kaldırır.
  /// Dosya zaten yoksa başarı sayılır (temizlik tekrar denenebilir).
  Future<void> sil(String goreliYol) async {
    final f = dosya(goreliYol);
    if (await f.exists()) await f.delete();
    final gecici = File('${f.path}$geciciUzanti');
    if (await gecici.exists()) await gecici.delete();
    await _bossaSil(f.parent); // <foto id>
    await _bossaSil(f.parent.parent); // <öğrenci id>
  }

  Directory hesapDizini(String hesap) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(hesap)) {
      throw ArgumentError.value(hesap, 'hesap', 'geçersiz hesap alanı');
    }
    return Directory(p.join(kok.path, hesap));
  }

  Future<void> _bossaSil(Directory d) async {
    try {
      if (await d.exists() && await d.list().isEmpty) await d.delete();
    } on FileSystemException {
      // Aynı anda başka dosya yazıldıysa klasör boş değildir; sorun yok.
    }
  }

  static Future<void> _sessizSil(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Uzlaştırma sonra toplar.
    }
  }
}
