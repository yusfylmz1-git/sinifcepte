import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/ogrenci_foto.dart';
import '../../providers/ogrenci_foto_providers.dart';

/// Öğrencinin güncel fotoğrafı ya da yedek görünüm.
///
/// Plan §4.9 kuralları:
/// - Yüklenirken boyut DEĞİŞMEZ (liste zıplamasın): kutu sabit.
/// - Dosya eksik/bozuksa hata göstermez, yedeğe döner.
/// - Dosya yolu burada okunmaz; kayıt ve depolama sağlayıcıdan gelir.
class OgrenciFotoKucuk extends ConsumerWidget {
  const OgrenciFotoKucuk({
    super.key,
    required this.foto,
    required this.genislik,
    this.yedek,
    this.yuvarlak = false,
  });

  final OgrenciFoto? foto;
  final double genislik;
  final Widget? yedek;

  /// Katılım kartı gibi yerlerde daire; listede köşeleri yuvarlak dikdörtgen.
  final bool yuvarlak;

  double get yukseklik => yuvarlak ? genislik : genislik * 171 / 133;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depolama = ref.watch(fotoDepolamaProvider).valueOrNull;
    final f = foto;
    Widget icerik;
    if (f != null && f.hazirMi && depolama != null) {
      final oran = MediaQuery.devicePixelRatioOf(context);
      icerik = Image.file(
        depolama.dosya(f.standardPath),
        // Yol her yeni fotoğrafta değişir (yeni klasör), eski görüntü
        // önbellekten gelmez.
        key: ValueKey(f.id),
        width: genislik,
        height: yukseklik,
        fit: BoxFit.cover,
        cacheWidth: (genislik * oran).round().clamp(1, 133),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _yedek(context),
      );
    } else {
      icerik = _yedek(context);
    }
    return SizedBox(
      width: genislik,
      height: yukseklik,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(yuvarlak ? genislik / 2 : 6),
        child: icerik,
      ),
    );
  }

  Widget _yedek(BuildContext context) {
    if (yedek != null) return yedek!;
    final koyu = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: genislik,
      height: yukseklik,
      color: koyu ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
      child: Icon(
        Icons.person_outline_rounded,
        size: genislik * 0.5,
        color: koyu ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }
}

/// Başka ekranlar için: öğrenci kimliğinden avatar. Sınıfın bütün
/// fotoğrafları tek sorguyla gelir (öğrenci başına sorgu yok).
class OgrenciAvatari extends ConsumerWidget {
  const OgrenciAvatari({
    super.key,
    required this.ogrenciId,
    required this.sinifId,
    required this.yedek,
    required this.boyut,
  });

  final int ogrenciId;
  final int sinifId;
  final Widget yedek;
  final double boyut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(fotolariGosterProvider)) return yedek;
    final foto = ref.watch(sinifFotolariProvider(sinifId)).valueOrNull?[ogrenciId];
    if (foto == null) return yedek;
    return OgrenciFotoKucuk(foto: foto, genislik: boyut, yuvarlak: true, yedek: yedek);
  }
}
