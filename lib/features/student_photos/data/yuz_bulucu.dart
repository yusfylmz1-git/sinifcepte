import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/foto_isleme.dart';
import '../domain/yuz_kadraj.dart';

/// Yüz KONUMU bulucu (plan §5.1, kullanıcı kararı 30 Eylül 2026: yalnız
/// otomatik hizalama, beyaz arka plan yok).
///
/// Yüz TANIMA değildir: kimin yüzü olduğunu bilmez, şablon üretmez,
/// hiçbir şey saklamaz. Sonuç yalnızca kadraj önerisi için bellekte
/// kullanılır; algılama için yazılan geçici dosya hemen silinir.
abstract class YuzBulucu {
  /// Bu cihazda çalışıyor mu (Windows'ta yok).
  bool get destekli;

  Future<List<YuzBilgisi>> bul(CalismaGoruntusu goruntu);
}

/// Google ML Kit, cihaz içi GÖMÜLÜ model (`com.google.mlkit:face-detection`):
/// internet gerekmez, ilk kullanımda model indirmez.
class MlKitYuzBulucu implements YuzBulucu {
  const MlKitYuzBulucu();

  @override
  bool get destekli => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<List<YuzBilgisi>> bul(CalismaGoruntusu goruntu) async {
    if (!destekli) return const [];
    final gecici = await getTemporaryDirectory();
    final dosya = File(p.join(gecici.path, 'yuz_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    final bulucu = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
      ),
    );
    try {
      // Çalışma görüntüsünün yönü zaten uygulanmış ve EXIF'siz: ML Kit'in
      // koordinatları doğrudan kırpma ekranının koordinatları.
      await dosya.writeAsBytes(goruntu.jpeg, flush: true);
      final yuzler = await bulucu.processImage(InputImage.fromFilePath(dosya.path));
      return [
        for (final f in yuzler)
          YuzBilgisi(
            x: f.boundingBox.left,
            y: f.boundingBox.top,
            genislik: f.boundingBox.width,
            yukseklik: f.boundingBox.height,
            solGoz: _nokta(f.landmarks[FaceLandmarkType.leftEye]),
            sagGoz: _nokta(f.landmarks[FaceLandmarkType.rightEye]),
            egimDerece: f.headEulerAngleZ,
          ),
      ];
    } finally {
      await bulucu.close();
      try {
        if (await dosya.exists()) await dosya.delete();
      } catch (_) {}
    }
  }

  static math.Point<double>? _nokta(FaceLandmark? l) =>
      l == null ? null : math.Point(l.position.x.toDouble(), l.position.y.toDouble());
}
