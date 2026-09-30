import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/student_photos/data/foto_depolama.dart';
import '../database/database_helper.dart';
import 'tam_yedek.dart';

/// Veritabanı yedekleme.
///
/// ## Neden yazıldı
/// Profil ekranındaki "Verileri Yedekle" düğmesi şunu yapıyordu:
///
/// ```dart
/// onPressed: () {
///   ScaffoldMessenger.of(context).showSnackBar(
///     const SnackBar(content: Text('Veri Yedekleme Dosyası Hazırlandı! 💾')),
///   );
/// }
/// ```
///
/// **Hiçbir dosya yazılmıyordu.** Öğretmene "verin güvende" dedirtip
/// telefonu bozulduğunda bir yılı kaybettirecek bir yalandı.
///
/// Bağımsız denetimde (Grok, 31 Ağustos 2026) yakalandı ve doğrulandı.
///
/// ## Ne yapıyor
/// Aktif hesabın TAM yedeğini (veritabanı + e-Okul fotoğrafları, bkz.
/// [TamYedek]) üretip paylaşım penceresine veriyor. Öğretmen dosyayı
/// e-postayla kendine gönderebilir, buluta atabilir ya da bilgisayarına
/// aktarabilir. Geri yükleme doğrulayıp kapsamı gösterdikten sonra
/// uygulanır.
///
/// Bulut yedeklemesi **bilinçli olarak yapılmıyor**: öğrenci notları,
/// katılım ve devamsızlık cihazda kalıyor (KVKK kararı). Yedeği nereye
/// koyacağına öğretmen karar verir.
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  /// Yedek dosyasının uzantısı.
  static const String extension = 'sinifcepte';

  /// Aktif hesabın TAM yedeğini (veritabanı + e-Okul fotoğrafları)
  /// üretir; paylaşım penceresini çağıran açar.
  ///
  /// Başarılıysa yedek dosyasının yolunu döner; başarısızsa `null`.
  ///
  /// 30 Eylül 2026'dan önce yalnızca SQLite dosyası kopyalanıyordu;
  /// fotoğraflar yedeğe girmiyordu. WAL checkpoint, biçim ve geri
  /// okuyarak doğrulama [TamYedek.olustur]'da.
  Future<String?> exportDatabase() async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (!await File(db.path).exists()) {
        debugPrint('BackupService: veritabanı dosyası bulunamadı');
        return null;
      }
      final gecici = await getTemporaryDirectory();
      final dosya = await TamYedek.olustur(
        db: db,
        depolama: await FotoDepolama.uygulamaIcin(),
        hedefDizin: Directory(p.join(gecici.path, 'sinifcepte_yedek')),
      );
      return dosya.path;
    } catch (e, stackTrace) {
      debugPrint('BackupService.exportDatabase hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Yedeği paylaşım penceresiyle dışa aktarır.
  Future<bool> shareBackup(String yol) async {
    try {
      final sonuc = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(yol)],
          subject: 'SınıfCepte Yedek',
          text: 'SınıfCepte veri yedeği. Bu dosyayı güvenli bir yerde '
              'saklayın; geri yüklemek için uygulamaya aktarın.',
        ),
      );
      return sonuc.status == ShareResultStatus.success;
    } catch (e, stackTrace) {
      debugPrint('BackupService.shareBackup hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Seçilen yedeği inceler (üzerine YAZMAZ). Kapsam onay ekranında
  /// gösterilir; eski biçim (düz SQLite) de kabul edilir.
  Future<HazirYedek> yedegiIncele(String yol) async {
    final db = await DatabaseHelper.instance.database;
    final gecici = await getTemporaryDirectory();
    return TamYedek.incele(
      dosya: File(yol),
      calismaDizini: Directory(
          p.join(gecici.path, 'sinifcepte_geri_yukleme_${DateTime.now().microsecondsSinceEpoch}')),
      mevcutHesap: FotoDepolama.hesapAlani(db.path),
    );
  }

  /// Mevcut hesabın sayıları (onay ekranında "üzerine yazılacak").
  Future<({int sinif, int ogrenci, int fotograf})> mevcutKapsam() async {
    final db = await DatabaseHelper.instance.database;
    Future<int> say(String tablo) async {
      try {
        return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tablo')) ?? 0;
      } catch (_) {
        return 0;
      }
    }

    return (
      sinif: await say('classes'),
      ogrenci: await say('students'),
      fotograf: await say('student_photos'),
    );
  }

  /// İncelenmiş yedeği uygular: mevcut verinin üzerine yazar; çağıran
  /// **onay almalıdır**. Yarıda kalırsa önceki veri geri konur.
  ///
  /// Eski `restoreDatabase` hiçbir yerden çağrılmıyordu (uygulamada geri
  /// yükleme yolu yoktu) ve doğrulamasız üzerine yazıyordu; bunun
  /// yerine geçti.
  Future<void> geriYukle(HazirYedek yedek) async {
    try {
      await TamYedek.uygula(
        yedek: yedek,
        depolama: await FotoDepolama.uygulamaIcin(),
        veritabani: () => DatabaseHelper.instance.database,
        baglantiyiKapat: DatabaseHelper.instance.closeConnection,
      );
    } finally {
      await yedek.temizle();
    }
  }
}
