import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// e-Okul'a yükleme için okunaklı dosya adı: `1234_İsmail_IŞIK.jpg`.
///
/// Kullanıcı kararı (30 Eylül 2026): fotoğraflar e-Okul'a öğrenci
/// sayfasından TEK TEK yükleniyor; öğretmen dosyayı adından bulmalı.
/// Türkçe harfler korunur (Android/iOS/Windows dosya adlarında sorun
/// yok); yalnızca dosya sisteminin yasakladığı karakterler çıkarılır.
String eokulDosyaAdi({required int okulNo, required String ad, required String soyad}) {
  String temizle(String s) => s
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  var govde = '${okulNo}_${temizle(ad)}_${temizle(soyad)}';
  govde = govde.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (govde.length > 80) govde = govde.substring(0, 80);
  return '$govde.jpg';
}

/// Tek fotoğrafı paylaşım penceresiyle dışarı verir.
///
/// Uygulama içi dosya adı kimliklerden oluşur (`standard.jpg`); paylaşımda
/// okunaklı adla GEÇİCİ bir kopya verilir. Eski kopyalar bir sonraki
/// paylaşımda silinir — paylaşım penceresi dosyayı okuyabilsin diye
/// hemen silinmiyor.
class FotoPaylasim {
  FotoPaylasim._();

  static const Duration _kopyaOmru = Duration(hours: 1);

  static Future<bool> paylas({required File kaynak, required String dosyaAdi}) async {
    try {
      final gecici = await getTemporaryDirectory();
      final dizin = Directory(p.join(gecici.path, 'eokul_foto_paylasim'));
      await _eskileriSil(dizin);
      // Her paylaşım kendi alt klasöründe: aynı adlı iki öğrenci
      // (farklı sınıf, aynı numara) birbirinin kopyasını ezmesin.
      final alt = Directory(p.join(dizin.path, '${DateTime.now().microsecondsSinceEpoch}'));
      await alt.create(recursive: true);
      final hedef = await kaynak.copy(p.join(alt.path, dosyaAdi));
      final sonuc = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(hedef.path, mimeType: 'image/jpeg', name: dosyaAdi)],
          subject: dosyaAdi,
        ),
      );
      return sonuc.status == ShareResultStatus.success;
    } catch (e, st) {
      debugPrint('FotoPaylasim.paylas hatası: $e\n$st');
      return false;
    }
  }

  static Future<void> _eskileriSil(Directory dizin) async {
    try {
      if (!await dizin.exists()) return;
      final simdi = DateTime.now();
      await for (final e in dizin.list(followLinks: false)) {
        if (simdi.difference((await e.stat()).modified) > _kopyaOmru) {
          await e.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('FotoPaylasim eski kopya temizliği: $e');
    }
  }
}
