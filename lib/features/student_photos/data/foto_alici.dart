import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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
    return x?.readAsBytes();
  }

  /// Android: kamera açıkken sistem uygulamayı bellekten atarsa çekilen
  /// fotoğraf kaybolmasın. Uygulama yeniden açılınca seri çekim ekranı
  /// bunu sorar.
  Future<Uint8List?> kayipFotograf() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final r = await ImagePicker().retrieveLostData();
      if (r.isEmpty || r.file == null) return null;
      return r.file!.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
