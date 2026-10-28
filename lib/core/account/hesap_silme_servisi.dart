import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/parent_portal/data/services/parent_lifecycle_service.dart';
import '../../features/student_photos/data/foto_depolama.dart';
import '../config/app_config.dart';
import '../database/database_helper.dart';
import '../storage/prefs_service.dart';

/// Buluttan silmenin sonucu.
sealed class HesapSilmeSonucu {
  const HesapSilmeSonucu();
}

class HesapSilindi extends HesapSilmeSonucu {
  const HesapSilindi();
}

class HesapSilinemedi extends HesapSilmeSonucu {
  const HesapSilinemedi(this.mesaj);

  /// Öğretmene gösterilecek, ne yapacağını söyleyen cümle.
  final String mesaj;
}

/// "Hesabımı sil" (Google Play şartı, KVKK m.7).
///
/// ## İki yarı
/// - Bulut: `hesabimiSil` fonksiyonu (functions/hesap_silme.js) bütün
///   kayıtları ve Firebase hesabını siler. İstemci bunu yapamaz:
///   başka öğretmenin sınıfındaki mesajlar kuralla kapalı.
/// - Telefon: öğretmenin sınıf/öğrenci veritabanı, öğrenci fotoğrafları ve
///   hesaba bağlı ayarlar. Bulut silinmeden telefon silinmez; bulut
///   hatasında öğretmen verisini kaybetmesin.
///
/// Fonksiyon `cloud_functions` paketi eklenmeden, çağrılabilir fonksiyonun
/// HTTP biçimiyle çağrılır (`{"data": ...}` gövdesi, kimlik jetonu başlıkta).
class HesapSilmeServisi {
  HesapSilmeServisi({
    http.Client? istemci,
    Future<String?> Function()? kimlikJetonu,
    String? projeKimligi,
  })  : _istemci = istemci,
        _kimlikJetonu = kimlikJetonu ?? _firebaseJetonu,
        _projeKimligi = projeKimligi;

  final http.Client? _istemci;
  final Future<String?> Function() _kimlikJetonu;
  final String? _projeKimligi;

  static const String bolge = 'europe-west1';

  /// Sunucu da bu sözü bekliyor: yanlışlıkla gönderilen istek silmesin.
  static const String onaySozu = 'SİL';

  static Future<String?> _firebaseJetonu() async =>
      FirebaseAuth.instance.currentUser?.getIdToken(true);

  Uri get adres {
    final proje = _projeKimligi ?? Firebase.app().options.projectId;
    return Uri.parse('https://$bolge-$proje.cloudfunctions.net/hesabimiSil');
  }

  Future<HesapSilmeSonucu> buluttanSil() async {
    final String? jeton;
    try {
      jeton = await _kimlikJetonu();
    } catch (e) {
      debugPrint('Hesap silme: kimlik jetonu alınamadı: $e');
      return const HesapSilinemedi(
        'Oturum doğrulanamadı. İnternet bağlantınızı kontrol edip yeniden deneyin.',
      );
    }
    if (jeton == null || jeton.isEmpty) {
      return const HesapSilinemedi('Oturum açık değil. Çıkış yapıp yeniden giriş yapın.');
    }

    final istemci = _istemci ?? http.Client();
    try {
      final yanit = await istemci
          .post(
            adres,
            headers: {
              'Authorization': 'Bearer $jeton',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'data': {'onay': onaySozu},
            }),
          )
          .timeout(const Duration(seconds: 90));
      final govde = _jsonMu(yanit.body);
      if (yanit.statusCode == 200 && govde?['result']?['ok'] == true) {
        return const HesapSilindi();
      }
      debugPrint('Hesap silme reddedildi (${yanit.statusCode}): ${yanit.body}');
      return const HesapSilinemedi(
        'Hesabınız silinemedi. Biraz sonra yeniden deneyin; sürerse destek adresine yazın.',
      );
    } on TimeoutException {
      return const HesapSilinemedi(
        'Sunucu zamanında yanıt vermedi. Yeniden deneyin; silinen kayıtlar tekrar silinmez, kalanlar silinir.',
      );
    } on SocketException {
      return const HesapSilinemedi('İnternet bağlantısı yok. Bağlanınca yeniden deneyin.');
    } catch (e) {
      debugPrint('Hesap silme hatası: $e');
      return const HesapSilinemedi('Hesabınız silinemedi. Biraz sonra yeniden deneyin.');
    } finally {
      if (_istemci == null) istemci.close();
    }
  }

  static Map<String, dynamic>? _jsonMu(String metin) {
    try {
      final v = jsonDecode(metin);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// Öğretmenin bu telefondaki verisi: veritabanı, öğrenci fotoğrafları,
  /// hesaba bağlı ayarlar (`..._{uid}` anahtarları).
  ///
  /// Silinen hesapla bir daha giriş yapılamaz (aynı Google hesabı yeni
  /// kimlik alır); veri kalsa da açılamazdı.
  static Future<void> ogretmenVerisiniSil(String uid, {FotoDepolama? fotolar}) async {
    final dbAdi = AppConfig.teacherDbName(uid);
    await DatabaseHelper.instance.closeConnection();
    try {
      await deleteDatabase(p.join(await getDatabasesPath(), dbAdi));
    } catch (e) {
      debugPrint('Hesap silme: veritabanı silinemedi: $e');
    }

    try {
      final depo = fotolar ?? await FotoDepolama.uygulamaIcin();
      final dizin = depo.hesapDizini(FotoDepolama.hesapAlani(dbAdi));
      if (await dizin.exists()) await dizin.delete(recursive: true);
    } catch (e) {
      debugPrint('Hesap silme: fotoğraflar silinemedi: $e');
    }

    final prefs = await PrefsService.instance();
    if (prefs != null) {
      for (final k in prefs.getKeys().toList()) {
        if (k.endsWith('__$uid')) await prefs.remove(k);
      }
      if (prefs.getString(DatabaseHelper.lastUidKey) == uid) {
        await prefs.remove(DatabaseHelper.lastUidKey);
      }
    }
  }

  /// Velinin bu telefondaki bağları, bildirimleri ve randevuları.
  static Future<void> veliVerisiniSil(String uid) async {
    await ParentLifecycleService.deleteParentSelfAccount(uid);
  }
}
