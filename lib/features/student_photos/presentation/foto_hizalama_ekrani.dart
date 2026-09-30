import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/student_model.dart';
import '../domain/foto_isleme.dart';
import '../domain/kirpma_hesabi.dart';
import '../domain/yuz_kadraj.dart';
import '../domain/ogrenci_foto.dart';
import '../providers/ogrenci_foto_providers.dart';

/// Elle hizalama + kimlik onayı + kayıt.
///
/// ## İki adım (plan §4.3, §4.7)
/// 1. **Hizala:** sabit 133:171 çerçevenin altında görüntü kaydırılır,
///    iki parmakla yakınlaştırılır, gerekirse ±15° döndürülür.
/// 2. **Onayla:** üretilen 133×171 fotoğraf, sınıf + okul numarası +
///    ad-soyad ile BÜYÜK puntoda yan yana. Öğretmen "Bu fotoğraf bu
///    öğrenciye ait" demeden Kaydet çalışmaz.
///
/// Kimlik ekranın tepesinde iki adımda da sabit durur: öğretmenden
/// öğrenciyi yüzünden tanıması beklenmez.
///
/// Başarıyla kaydedilince `true` ile kapanır.
///
/// Ağır görüntü işleme ayrı izolatta ([Isolate.run]) yapılır; ana iş
/// parçacığı donmaz.
typedef ArkaPlanCalistirici = Future<T> Function<T>(FutureOr<T> Function() is_);

class FotoHizalamaEkrani extends ConsumerStatefulWidget {
  const FotoHizalamaEkrani({
    super.key,
    required this.ogrenci,
    required this.sinifAdi,
    required this.calisma,
    required this.kaynak,
    required this.mevcutFotoVar,
    this.arkaPlan,
  });

  final StudentModel ogrenci;
  final String sinifAdi;
  final CalismaGoruntusu calisma;

  /// [FotoKaynagi.dosya] ya da [FotoKaynagi.kamera].
  final String kaynak;
  final bool mevcutFotoVar;

  /// Test kapısı: izolat sahte test saatinde sonuç teslim etmiyor.
  /// Verilmezse [Isolate.run].
  final ArkaPlanCalistirici? arkaPlan;

  @override
  ConsumerState<FotoHizalamaEkrani> createState() => _FotoHizalamaEkraniState();
}

class _FotoHizalamaEkraniState extends ConsumerState<FotoHizalamaEkrani> {
  late CalismaGoruntusu _gorunen = widget.calisma;
  double _aci = 0;
  KirpmaDurumu? _durum;
  Size? _cerceve;

  // Hareket başlangıcı
  KirpmaDurumu? _hareketBasi;
  Offset _odakBasi = Offset.zero;

  bool _isleniyor = false;
  bool _yuzAraniyor = false;
  bool _otomatikDenendi = false;
  List<String> _yuzNotlari = const [];
  UretimSonucu? _sonuc;
  DateTime? _kimlikOnaylandi;
  bool _bulaniklikOnay = false;

  ArkaPlanCalistirici get _calistir => widget.arkaPlan ?? Isolate.run;

  String get _adSoyad => '${widget.ogrenci.firstName} ${widget.ogrenci.lastName}';

  Future<void> _aciyiUygula(double aci) async {
    final kaynak = widget.calisma;
    final onceki = _gorunen;
    setState(() => _isleniyor = true);
    try {
      final yeni = await _calistir(() => calismaGoruntusunuDondur(kaynak, aci));
      if (!mounted) return;
      setState(() {
        _gorunen = yeni;
        final d = _durum;
        final c = _cerceve;
        if (d != null && c != null) {
          _durum = d.tasi(
            eskiG: onceki.genislik,
            eskiY: onceki.yukseklik,
            yeniG: yeni.genislik,
            yeniY: yeni.yukseklik,
            cerceveG: c.width,
            cerceveY: c.height,
          );
        }
      });
    } catch (e) {
      _hata('Döndürülemedi: $e');
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  /// Yüzün yerini bulup 133:171 kadraj önerir (plan §4.7). Yüz TANIMA
  /// değil; sonuç yalnızca kadraj için kullanılır, öğretmen elle düzeltir.
  Future<void> _yuzeHizala() async {
    final bulucu = ref.read(yuzBulucuProvider);
    final c = _cerceve;
    if (!bulucu.destekli || c == null || _yuzAraniyor) return;
    setState(() => _yuzAraniyor = true);
    try {
      final g = _gorunen;
      final oneri = kadrajOner(await bulucu.bul(g), g.genislik, g.yukseklik);
      if (!mounted) return;
      setState(() {
        if (oneri == null) {
          _yuzNotlari = const ['Yüz bulunamadı; fotoğrafı elle hizalayın.'];
        } else {
          _durum = KirpmaDurumu.alandan(oneri.alan, g.genislik, g.yukseklik, c.width, c.height);
          _yuzNotlari = ['Yüze göre hizalandı; gerekirse elle düzeltin.', ...oneri.uyarilar];
        }
      });
    } catch (e) {
      debugPrint('Yüz aranamadı: $e');
      if (mounted) setState(() => _yuzNotlari = const ['Yüz aranamadı; fotoğrafı elle hizalayın.']);
    } finally {
      if (mounted) setState(() => _yuzAraniyor = false);
    }
  }

  Future<void> _devam() async {
    final d = _durum;
    final c = _cerceve;
    if (d == null || c == null) return;
    final g = _gorunen;
    final alan = d.alan(g.genislik, g.yukseklik, c.width);
    setState(() => _isleniyor = true);
    try {
      final sonuc = await _calistir(() => calismadanUret(g, alan));
      if (!mounted) return;
      setState(() {
        _sonuc = sonuc;
        _kimlikOnaylandi = null;
        _bulaniklikOnay = false;
      });
    } catch (e) {
      _hata(e is FotoIslemeHatasi ? e.mesaj : 'Fotoğraf hazırlanamadı: $e');
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  Future<void> _kaydet() async {
    final s = _sonuc;
    final onay = _kimlikOnaylandi;
    if (s == null || onay == null) return;
    setState(() => _isleniyor = true);
    try {
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      await depo.kaydet(
        ogrenciId: widget.ogrenci.id!,
        standartJpeg: s.jpeg,
        kaynak: widget.kaynak,
        kimlikOnaylandi: onay,
        kaliteUyarilari: s.kaliteUyarilari,
        elleOnay: _bulaniklikOnay,
      );
      if (!mounted) return;
      fotolarDegisti(ref);
      Navigator.of(context).pop(true);
    } catch (e) {
      _hata('Kaydedilemedi: $e');
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  void _hata(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onayAdimi = _sonuc != null;
    return PopScope(
      // Onay adımında geri tuşu hizalamaya döner, ekranı kapatmaz.
      canPop: !onayAdimi && !_isleniyor,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && onayAdimi && !_isleniyor) setState(() => _sonuc = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(onayAdimi ? 'Kimliği onayla' : 'Fotoğrafı hizala'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _KimlikSeridi(
                sinifAdi: widget.sinifAdi,
                okulNo: widget.ogrenci.schoolNumber,
                adSoyad: _adSoyad,
              ),
              Expanded(child: onayAdimi ? _onayGovdesi(context) : _hizalamaGovdesi(context)),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. adım: hizalama ------------------------------------------------

  Widget _hizalamaGovdesi(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, kisit) {
            const kenar = 24.0;
            final enG = kisit.maxWidth - 2 * kenar;
            final enY = kisit.maxHeight - 2 * kenar;
            var cg = enG;
            var cy = cg * eokulYukseklik / eokulGenislik;
            if (cy > enY) {
              cy = enY;
              cg = cy * eokulGenislik / eokulYukseklik;
            }
            final cerceve = Size(cg, cy);
            final g = _gorunen;
            if (_cerceve != cerceve || _durum == null) {
              final eski = _durum;
              final eskiC = _cerceve;
              _cerceve = cerceve;
              _durum = (eski == null || eskiC == null)
                  ? KirpmaDurumu.baslangic(g.genislik, g.yukseklik, cg, cy)
                  : KirpmaDurumu(eski.olcek * cg / eskiC.width, eski.x * cg / eskiC.width,
                          eski.y * cg / eskiC.width)
                      .sinirla(g.genislik, g.yukseklik, cg, cy);
            }
            // Açılışta bir kez otomatik öneri (plan §4.7 varsayılanı).
            if (!_otomatikDenendi && ref.read(yuzBulucuProvider).destekli) {
              _otomatikDenendi = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => _yuzeHizala());
            }
            final d = _durum!;
            final ox = (kisit.maxWidth - cg) / 2;
            final oy = (kisit.maxHeight - cy) / 2;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (e) {
                _hareketBasi = _durum;
                _odakBasi = e.localFocalPoint - Offset(ox, oy);
              },
              onScaleUpdate: (e) {
                final bas = _hareketBasi;
                if (bas == null) return;
                final odak = e.localFocalPoint - Offset(ox, oy);
                setState(() {
                  _durum = KirpmaDurumu.hareket(
                    baslangic: bas,
                    odakBaslangicX: _odakBasi.dx,
                    odakBaslangicY: _odakBasi.dy,
                    odakX: odak.dx,
                    odakY: odak.dy,
                    carpan: e.scale,
                  ).sinirla(g.genislik, g.yukseklik, cg, cy);
                });
              },
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: ox + d.x,
                      top: oy + d.y,
                      width: g.genislik * d.olcek,
                      height: g.yukseklik * d.olcek,
                      child: Image.memory(
                        g.jpeg,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _CerceveBoyasi(Rect.fromLTWH(ox, oy, cg, cy))),
                      ),
                    ),
                    if (_isleniyor || _yuzAraniyor) const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Yüzü ovalin içine alın, gözler kesikli çizgi hizasında olsun. '
            'İki parmakla yakınlaştırın.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (ref.read(yuzBulucuProvider).destekli)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: _isleniyor || _yuzAraniyor ? null : _yuzeHizala,
                  icon: const Icon(Icons.face_retouching_natural_rounded),
                  label: const Text('Yüzü bul ve otomatik hizala'),
                ),
                for (final n in _yuzNotlari)
                  Text(n, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  'Yüz tanıma yapmaz: yalnızca yüzün yerini bulur, kimseyi tanımlamaz, saklamaz.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.rotate_right_rounded, size: 20),
              const SizedBox(width: 4),
              Text('Açı ${_aci >= 0 ? '+' : ''}${_aci.toStringAsFixed(1)}°'),
              Expanded(
                child: Slider(
                  value: _aci,
                  min: -15,
                  max: 15,
                  divisions: 60,
                  label: '${_aci.toStringAsFixed(1)}°',
                  onChanged: _isleniyor ? null : (v) => setState(() => _aci = v),
                  onChangeEnd: _isleniyor ? null : _aciyiUygula,
                ),
              ),
              TextButton(
                onPressed: _isleniyor || _aci == 0
                    ? null
                    : () {
                        setState(() => _aci = 0);
                        _aciyiUygula(0);
                      },
                child: const Text('Sıfırla'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isleniyor ? null : _devam,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Devam'),
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. adım: kimlik onayı --------------------------------------------

  Widget _onayGovdesi(BuildContext context) {
    final s = _sonuc!;
    final bulanik = s.kaliteUyarilari.contains(kaliteDusukCozunurluk);
    final kaydedilebilir =
        _kimlikOnaylandi != null && (!bulanik || _bulaniklikOnay) && !_isleniyor;
    final no = widget.ogrenci.schoolNumber;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Image.memory(
              s.jpeg,
              width: eokulGenislik * 2,
              height: eokulYukseklik * 2,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'e-Okul ölçüsü: $eokulGenislik×$eokulYukseklik piksel (burada 2 kat büyük)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.mevcutFotoVar)
          const _Uyari(
            ikon: Icons.swap_horiz_rounded,
            metin: 'Bu öğrencinin mevcut fotoğrafı değiştirilecek. '
                'Yenisi kaydedilene kadar eskisi silinmez.',
          ),
        if (bulanik) ...[
          const _Uyari(
            ikon: Icons.blur_on_rounded,
            metin: 'Seçilen alan küçük; fotoğraf bulanık olabilir. '
                'Daha az yakınlaştırmayı ya da daha net bir fotoğrafı deneyin.',
          ),
          CheckboxListTile(
            value: _bulaniklikOnay,
            onChanged: (v) => setState(() => _bulaniklikOnay = v ?? false),
            title: const Text('Yine de bu fotoğrafı kullan'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: CheckboxListTile(
            value: _kimlikOnaylandi != null,
            onChanged: (v) =>
                setState(() => _kimlikOnaylandi = (v ?? false) ? DateTime.now() : null),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Bu fotoğraf $no — $_adSoyad öğrencisine ait',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${widget.sinifAdi} sınıfı'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isleniyor ? null : () => setState(() => _sonuc = null),
                icon: const Icon(Icons.crop_rounded),
                label: const Text('Hizalamayı düzelt'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: kaydedilebilir ? _kaydet : null,
                icon: _isleniyor
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('Kaydet'),
              ),
            ),
          ],
        ),
        if (_kimlikOnaylandi == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Kaydetmek için fotoğrafın bu öğrenciye ait olduğunu onaylayın.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Ekranın tepesindeki sabit kimlik: "5-A • 1234 / İsmail IŞIK".
class _KimlikSeridi extends StatelessWidget {
  const _KimlikSeridi({required this.sinifAdi, required this.okulNo, required this.adSoyad});

  final String sinifAdi;
  final int okulNo;
  final String adSoyad;

  @override
  Widget build(BuildContext context) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Öğrenci kimliği: $sinifAdi sınıfı, okul numarası $okulNo, $adSoyad',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.primary.withValues(alpha: koyu ? 0.25 : 0.10),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$sinifAdi • $okulNo',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(adSoyad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Uyari extends StatelessWidget {
  const _Uyari({required this.ikon, required this.metin});
  final IconData ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(metin)),
        ],
      ),
    );
  }
}

/// Çerçeve dışını karartır; yüz ovali ve göz çizgisi çizer.
class _CerceveBoyasi extends CustomPainter {
  _CerceveBoyasi(this.cerceve);
  final Rect cerceve;

  @override
  void paint(Canvas canvas, Size size) {
    final dis = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(cerceve);
    canvas.drawPath(dis, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRect(
      cerceve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    // Vesikalık oranları: baş çerçevenin üstünden ~%10 aşağıda başlar,
    // çene ~%76'da biter; gözler yüksekliğin ~%42'sinde.
    final oval = Rect.fromLTWH(
      cerceve.left + cerceve.width * 0.22,
      cerceve.top + cerceve.height * 0.10,
      cerceve.width * 0.56,
      cerceve.height * 0.66,
    );
    final kilavuz = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawOval(oval, kilavuz);
    final gozY = cerceve.top + cerceve.height * 0.42;
    for (var x = cerceve.left + 8; x < cerceve.right - 8; x += 12) {
      canvas.drawLine(Offset(x, gozY), Offset(x + 6, gozY), kilavuz);
    }
  }

  @override
  bool shouldRepaint(_CerceveBoyasi eski) => eski.cerceve != cerceve;
}

/// Seçilen fotoğrafı çalışma görüntüsüne çevirir (ayrı izolatta).
Future<CalismaGoruntusu> calismaGoruntusuAc(Uint8List bayt) =>
    Isolate.run(() => calismaGoruntusuHazirla(bayt));

/// Galeri/kamera baytlarını çalışma görüntüsüne çevirip hizalama ve
/// kimlik onayı ekranını açar. Kaydedildiyse `true`.
///
/// Sınıf ekranı (tek öğrenci) ve seri çekim aynı yolu kullanır: kamera
/// ve galeri çıktısı AYNI işlem hattından geçer (plan §4.6).
Future<bool> fotoyuHizalaVeKaydet(
  BuildContext context, {
  required Uint8List bayt,
  required StudentModel ogrenci,
  required String sinifAdi,
  required String kaynak,
  required bool mevcutFotoVar,
  void Function(bool mesgul)? mesgul,
  ArkaPlanCalistirici? arkaPlan,
}) async {
  mesgul?.call(true);
  CalismaGoruntusu calisma;
  try {
    calisma = arkaPlan != null
        ? await arkaPlan(() => calismaGoruntusuHazirla(bayt))
        : await calismaGoruntusuAc(bayt);
  } catch (e) {
    mesgul?.call(false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is FotoIslemeHatasi ? e.mesaj : 'Fotoğraf açılamadı: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
    return false;
  }
  mesgul?.call(false);
  if (!context.mounted) return false;
  final sonuc = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => FotoHizalamaEkrani(
        ogrenci: ogrenci,
        sinifAdi: sinifAdi,
        calisma: calisma,
        kaynak: kaynak,
        mevcutFotoVar: mevcutFotoVar,
        arkaPlan: arkaPlan,
      ),
    ),
  );
  return sonuc == true;
}
