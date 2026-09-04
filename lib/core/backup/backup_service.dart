import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

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
/// Aktif hesabın SQLite dosyasını kopyalayıp paylaşım penceresine
/// veriyor. Öğretmen dosyayı e-postayla kendine gönderebilir, buluta
/// atabilir ya da bilgisayarına aktarabilir.
///
/// Bulut yedeklemesi **bilinçli olarak yapılmıyor**: öğrenci notları,
/// katılım ve devamsızlık cihazda kalıyor (KVKK kararı). Yedeği nereye
/// koyacağına öğretmen karar verir.
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  /// Yedek dosyasının uzantısı.
  static const String extension = 'sinifcepte';

  /// Aktif hesabın veritabanını yedekler ve paylaşım penceresini açar.
  ///
  /// Başarılıysa yedek dosyasının yolunu döner; başarısızsa `null`.
  Future<String?> exportDatabase() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final kaynakYolu = db.path;

      final kaynak = File(kaynakYolu);
      if (!await kaynak.exists()) {
        debugPrint('BackupService: veritabanı dosyası bulunamadı ($kaynakYolu)');
        return null;
      }

      // WAL modunda son yazmalar ayrı dosyada bekliyor olabilir.
      // Checkpoint almadan kopyalanan yedek EKSİK olur — en son girilen
      // notlar yedekte bulunmaz.
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (e) {
        debugPrint('BackupService: checkpoint alınamadı: $e');
      }

      final gecici = await getTemporaryDirectory();
      final damga = _timestamp(DateTime.now());
      final hedefYolu = p.join(gecici.path, 'sinifcepte_yedek_$damga.$extension');

      await kaynak.copy(hedefYolu);

      final boyut = await File(hedefYolu).length();
      if (boyut == 0) {
        debugPrint('BackupService: yedek dosyası boş çıktı');
        return null;
      }

      return hedefYolu;
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

  /// Yedek dosyasından geri yükler.
  ///
  /// Mevcut veritabanının üzerine yazar; çağıran **onay almalıdır**.
  Future<bool> restoreDatabase(String yedekYolu) async {
    try {
      final yedek = File(yedekYolu);
      if (!await yedek.exists()) return false;

      // Dosya gerçekten SQLite mi? Yanlış dosya seçilirse veritabanı
      // bozulur ve öğretmen her şeyini kaybeder.
      if (!await _isSqlite(yedek)) {
        debugPrint('BackupService: seçilen dosya SQLite değil');
        return false;
      }

      final db = await DatabaseHelper.instance.database;
      final hedefYolu = db.path;

      // Bağlantı kapatılmadan dosyanın üzerine yazmak veritabanını
      // bozar. Kapatma alanı da temizler; sonraki erişimde yeni dosya
      // açılır.
      await DatabaseHelper.instance.closeConnection();

      await yedek.copy(hedefYolu);
      return true;
    } catch (e, stackTrace) {
      debugPrint('BackupService.restoreDatabase hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Dosyanın SQLite olup olmadığını başlıktan doğrular.
  ///
  /// SQLite dosyaları "SQLite format 3\0" ile başlar.
  Future<bool> _isSqlite(File f) async {
    try {
      final bytes = await f.openRead(0, 16).first;
      const imza = 'SQLite format 3';
      final basi = String.fromCharCodes(bytes.take(imza.length));
      return basi == imza;
    } catch (_) {
      return false;
    }
  }

  static String _timestamp(DateTime t) {
    String iki(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${iki(t.month)}${iki(t.day)}_'
        '${iki(t.hour)}${iki(t.minute)}';
  }
}
