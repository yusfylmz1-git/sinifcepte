import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/disa_aktarim_plani.dart';
import 'foto_depolama.dart';

/// Paket üretiminin sonucu. Durumlar ayrı (plan §13): "hazırlandı"
/// paylaşıldı demek değildir; kısmen tamamlanan iş "başarılı" sayılmaz.
class DisaAktarimSonucu {
  const DisaAktarimSonucu({
    required this.zip,
    required this.eklenenFoto,
    required this.beklenenFoto,
    required this.hatalar,
  });

  final File zip;
  final int eklenenFoto;
  final int beklenenFoto;

  /// Eklenemeyen fotoğraflar: `sınıf/dosya adı: neden`.
  final List<String> hatalar;

  bool get tamMi => hatalar.isEmpty && eklenenFoto == beklenenFoto;
}

class DisaAktarimIptal implements Exception {
  const DisaAktarimIptal();
}

class DisaAktarimHatasi implements Exception {
  DisaAktarimHatasi(this.mesaj);
  final String mesaj;
  @override
  String toString() => mesaj;
}

/// Kontrol belgelerinin klasörü. e-Okul'a yanlışlıkla yüklenmesin diye
/// fotoğraf klasörlerinden AYRI (plan §10.1).
const String kontrolKlasoru = 'Kontrol_Listeleri';

/// e-Okul fotoğraf paketi (ZIP).
///
/// ```text
/// SinifCepte_Fotograflar_2026-2027_20260930_143000/
///   5-A/1234_Ayşe_YILMAZ.jpg
///   5-B/...
///   Kontrol_Listeleri/eslestirme.csv, eksikler.csv, kontrol_listesi.pdf
/// ```
///
/// - JPEG yeniden sıkıştırılmaz (STORE): zaten sıkıştırılmış, 133×171.
/// - Dosya diske AKIŞLA yazılır; bütün paket bellekte tutulmaz.
/// - Her fotoğraf plandaki özetle doğrulanır: plan kurulduktan sonra
///   değişen/silinen fotoğraf pakete karışmaz, hata olarak listelenir.
/// - Bitince ZIP GERİ OKUNUR: CRC, dosya sayısı ve her fotoğrafın özeti
///   tutmadan sonuç verilmez.
/// - ZIP şifreleme sağlamaz; ekran bunu söyler.
class FotoDisaAktarici {
  FotoDisaAktarici(this.depolama);

  final FotoDepolama depolama;

  Future<DisaAktarimSonucu> zipUret({
    required DisaAktarimPlani plan,
    required Directory hedefDizin,
    Uint8List? kontrolPdf,
    bool Function()? iptalMi,
    void Function(int tamam, int toplam)? ilerleme,
    @visibleForTesting Future<void> Function(File zip)? kapandiktanSonra,
  }) async {
    if (!plan.uretilebilir) {
      throw DisaAktarimHatasi(plan.engelNedeni ?? 'Paket üretilemez.');
    }
    await hedefDizin.create(recursive: true);
    final zipYolu = p.join(hedefDizin.path, '${plan.paketAdi}.zip');
    final kok = plan.paketAdi;
    final kalemler = plan.aktarilacak;
    final beklenen = <String, String>{}; // paket yolu -> özet
    final hatalar = <String>[];

    // Fotoğraflar dosya başına sıkıştırmasız (noCompress); CSV/PDF
    // sıkıştırılır.
    final kodlayici = ZipFileEncoder()..create(zipYolu);
    var kapandi = false;
    try {
      for (var i = 0; i < kalemler.length; i++) {
        if (iptalMi?.call() ?? false) throw const DisaAktarimIptal();
        final k = kalemler[i];
        final foto = k.foto!;
        try {
          final bayt = await depolama.dosya(foto.standardPath).readAsBytes();
          final ozet = sha256.convert(bayt).toString();
          if (ozet != foto.checksum) {
            hatalar.add('${k.paketYolu}: dosya değişmiş ya da bozuk');
          } else {
            final yol = '$kok/${k.paketYolu}';
            kodlayici.addArchiveFile(ArchiveFile.noCompress(yol, bayt.length, bayt));
            beklenen[yol] = ozet;
          }
        } on FileSystemException {
          hatalar.add('${k.paketYolu}: dosya bulunamadı');
        }
        ilerleme?.call(i + 1, kalemler.length);
      }

      void ekle(String ad, List<int> bayt) {
        kodlayici.addArchiveFile(ArchiveFile('$kok/$kontrolKlasoru/$ad', bayt.length, bayt));
      }

      ekle('eslestirme.csv', utf8.encode(eslestirmeCsv(plan)));
      ekle('eksikler.csv', utf8.encode(eksiklerCsv(plan)));
      if (kontrolPdf != null) ekle('kontrol_listesi.pdf', kontrolPdf);
      await kodlayici.close();
      kapandi = true;
    } catch (_) {
      if (!kapandi) {
        try {
          await kodlayici.close();
        } catch (_) {}
      }
      await _sessizSil(File(zipYolu));
      rethrow;
    }

    await kapandiktanSonra?.call(File(zipYolu));

    // Geri oku ve doğrula.
    final dogrulanan = await _dogrula(File(zipYolu), beklenen);
    if (dogrulanan != beklenen.length) {
      await _sessizSil(File(zipYolu));
      throw DisaAktarimHatasi(
        'Paket doğrulanamadı ($dogrulanan/${beklenen.length} fotoğraf). Yeniden deneyin.',
      );
    }
    return DisaAktarimSonucu(
      zip: File(zipYolu),
      eklenenFoto: dogrulanan,
      beklenenFoto: kalemler.length,
      hatalar: hatalar,
    );
  }

  /// Pakete girecek fotoğrafları okur ve plandaki özetle doğrular (PDF
  /// albüm/kontrol listesi için). Tutmayan fotoğraf haritaya girmez.
  Future<Map<String, Uint8List>> fotolariOku(DisaAktarimPlani plan) async {
    final sonuc = <String, Uint8List>{};
    for (final k in plan.aktarilacak) {
      final f = k.foto!;
      try {
        final bayt = await depolama.dosya(f.standardPath).readAsBytes();
        if (sha256.convert(bayt).toString() == f.checksum) sonuc[f.id] = bayt;
      } on FileSystemException {
        // eksik: albümde "Fotoğraf yok" görünür
      }
    }
    return sonuc;
  }

  /// ZIP'teki fotoğrafları sayar; her birinin özeti beklenenle aynı mı?
  /// Beklenmeyen ek fotoğraf da hata sayılır.
  static Future<int> _dogrula(File zip, Map<String, String> beklenen) async {
    final giris = InputFileStream(zip.path);
    try {
      final arsiv = ZipDecoder().decodeBuffer(giris, verify: true);
      var tamam = 0;
      for (final f in arsiv.files) {
        if (!f.isFile || !f.name.toLowerCase().endsWith('.jpg')) continue;
        final ozet = beklenen[f.name];
        if (ozet == null) return -1;
        final icerik = f.content as List<int>;
        if (sha256.convert(icerik).toString() != ozet) return -1;
        tamam++;
      }
      return tamam;
    } catch (_) {
      return -1;
    } finally {
      await giris.close();
    }
  }

  static Future<void> _sessizSil(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
