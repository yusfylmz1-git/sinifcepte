import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/foto_isleme.dart';

/// Galeri ve kamera erişimi — tek yer, testte sahtesi verilir.
///
/// Kamera telefonun KENDİ kamera uygulamasıdır: odak, pozlama, flaş ve
/// ön/arka seçimi orada; her telefonda çalışır. Uygulama içi özel kamera
/// (canlı kılavuz, yüz algılama) plan Faz 4'e bırakıldı: yeni bir yerel
/// kamera bağımlılığı telefonda denenmeden eklenmiyor.
///
/// Her iki yolda da telefonun kendi çözücüsü fotoğrafı 2000 piksele
/// küçültür (bkz. `pubspec.yaml` notu).
///
/// ## Geçici kopya silinir
/// Android/iOS'ta seçici fotoğrafın bir KOPYASINI uygulamanın önbelleğine
/// yazıyor; okununca silinir (veri en aza indirme: öğrencinin 2000
/// piksellik fotoğrafı önbellekte kalmasın). Yalnızca uygulamanın geçici
/// dizinindeki dosya silinir: Windows'ta seçici ASIL dosyanın yolunu
/// veriyor, o asla silinmez ([geciciKopyaMi]).
class FotoAlici {
  const FotoAlici();

  /// Windows'ta kamera yok (image_picker desteklemiyor); düğme gizlenir.
  bool get kameraVar {
    try {
      return ImagePicker().supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> galeridenAl() => _al(ImageSource.gallery);

  Future<Uint8List?> kameradanAl() => _al(ImageSource.camera);

  Future<Uint8List?> _al(ImageSource kaynak) async {
    final x = await ImagePicker().pickImage(
      source: kaynak,
      maxWidth: calismaUzunKenar.toDouble(),
      maxHeight: calismaUzunKenar.toDouble(),
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
    );
    if (x == null) return null;
    final bayt = await x.readAsBytes();
    await _geciciyiSil(x.path);
    return bayt;
  }

  /// Android: kamera açıkken sistem uygulamayı bellekten atarsa çekilen
  /// fotoğraf kaybolmasın. Uygulama yeniden açılınca seri çekim ekranı
  /// bunu sorar.
  Future<Uint8List?> kayipFotograf() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final r = await ImagePicker().retrieveLostData();
      if (r.isEmpty || r.file == null) return null;
      final bayt = await r.file!.readAsBytes();
      await _geciciyiSil(r.file!.path);
      return bayt;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _geciciyiSil(String yol) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final gecici = (await getTemporaryDirectory()).path;
      if (geciciKopyaMi(yol, gecici)) await File(yol).delete();
    } catch (e) {
      debugPrint('Geçici fotoğraf kopyası silinemedi: $e');
    }
  }
}

/// [yol] uygulamanın geçici dizininin İÇİNDE mi? Yalnızca öyleyse silinir;
/// `..` ile dışarı çıkan yol da dışarıda sayılır.
@visibleForTesting
bool geciciKopyaMi(String yol, String geciciDizin) {
  final y = p.normalize(p.absolute(yol));
  final d = p.normalize(p.absolute(geciciDizin));
  return p.isWithin(d, y);
}
