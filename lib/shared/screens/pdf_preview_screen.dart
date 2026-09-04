import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/support/tani_log.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';

/// Resmî belge önizleme, yazdırma ve paylaşma ekranı.
///
/// ## Yakınlaştırma neden elle kuruluyor
/// Hazır `PdfPreview` yakınlaştırmayı yalnızca TEK SAYFA modunda
/// sunuyor ve o moda ÇİFT DOKUNUŞLA geçiliyor — dokunuş liste
/// kaydırmasıyla çakıştığı için pratikte hiç açılmıyordu.
///
/// Listeyi bir `InteractiveViewer` ile sarmak da yetmedi: hem
/// görüntüleyici hem içteki liste aynı dikey jesti istediği için
/// yakınlaştırdıktan sonra yukarı kaydırılamıyordu (aşağı iniyor,
/// yukarı çıkmıyordu).
///
/// `PdfPreviewCustom`'a geçip listenin kaydırmasını kapatmak ise
/// belgeyi hiç açılmaz hâle getirdi (sonsuz "Belge Hazırlanıyor").
/// Sebebini kanıtlayamadım; o yüzden ÇALIŞTIĞI GÖRÜLEN `PdfPreview`
/// bileşenine dönüldü.
///
/// Çalışan kurgu: kaydırma bileşenin kendisinde kalır,
/// `InteractiveViewer` yalnızca iki parmak ölçeklemesi yapar
/// (`panEnabled: false`). Yazdır/paylaş için hazır eylem çubuğu
/// kapatılıp (`useActions: false`) alt çubukta kendi düğmelerimiz
/// veriliyor.
class PdfPreviewScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String fileName;
  final Future<Uint8List> Function(PdfPageFormat format) documentBuilder;

  const PdfPreviewScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.fileName,
    required this.documentBuilder,
  });

  /// Hızlı gezinme yardımcısı.
  static Future<void> open(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String fileName,
    required Future<Uint8List> Function(PdfPageFormat format) documentBuilder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          title: title,
          subtitle: subtitle,
          fileName: fileName,
          documentBuilder: documentBuilder,
        ),
      ),
    );
  }

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  /// Paylaşırken belgeyi ikinci kez üretmemek için saklanır.
  Uint8List? _sonBelge;

  /// Tek sayfa (yakınlaştırma) modunda mıyız?
  ///
  /// Alt çubuktaki ipucunu değiştirmek için tutuluyor: kullanıcı
  /// yakınlaştırmanın nasıl açıldığını bilmiyordu.
  ///
  /// ## Neden `setState` DEĞİL de `ValueNotifier`
  ///
  /// Burada `setState` çağırmak "Belge Hazırlanıyor" takılmasının
  /// sebebiydi. Zincir şöyle işliyordu:
  ///
  ///   1. `onZoomChanged` → `setState` → `build()` yeniden çalışır
  ///   2. `build()` içinde `PdfPreview(...)` YENİ bir widget olur
  ///   3. Paketin `didUpdateWidget`i `preview = null` yapıp (ekran
  ///      boşalır) `raster()` çağırır — custom.dart:157
  ///   4. Önceki rasterizasyon hâlâ sürüyorsa `_rastering == true`
  ///      olduğu için yeni istek SESSİZCE atılır — raster.dart:98
  ///   5. Ekran boş kalır, bir daha dolmaz
  ///
  /// `ValueNotifier` ile yalnızca alt çubuktaki ipucu yeniden çizilir;
  /// `PdfPreview` hiç dokunulmadan yerinde kalır.
  final _yakinModu = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    TaniLog.yaz('EKRAN ▶ açıldı: ${widget.title} / ${widget.fileName}');
  }

  @override
  void dispose() {
    TaniLog.yaz('EKRAN ◀ kapandı: ${widget.fileName}');
    _yakinModu.dispose();
    _adim.dispose();
    super.dispose();
  }

  /// Üretim bir kez yapılır ve saklanır.
  ///
  /// `PdfPreview` `build` geri çağrısını birden çok kez tetikliyor
  /// (ölçek değişimi, yeniden çizim, yön değişimi). Her seferinde
  /// belgeyi baştan üretmek hem yavaş hem de eşzamanlı iki üretimin
  /// birbirini beklemesine yol açıyordu.
  Future<Uint8List>? _uretim;

  /// Kullanıcıya gösterilecek son hata.
  ///
  /// `PdfPreview` bazı hataları sessizce yutuyor ve ekran sonsuza kadar
  /// "Belge Hazırlanıyor"da kalıyor. Hatayı kendimiz yakalayıp burada
  /// tutarız; [build] bunu görünce hata ekranını basar.
  Object? _hataDurumu;

  /// Bir belgenin üretimi için üst sınır.
  ///
  /// Aşılırsa kullanıcı sonsuz bekleme yerine anlaşılır bir hata görür.
  /// En ağır belge (183 sayfalık pano testi) cihazda saniyeler sürüyor;
  /// 45 saniye fazlasıyla yeterli, takılmayı ise kesin yakalar.
  static const _zamanAsimi = Duration(seconds: 45);

  /// Üretimin hangi adımda olduğu — yükleme ekranında gösterilir.
  ///
  /// ## Neden ekranda
  ///
  /// Takılma yalnızca KABLO ÇIKINCA görülüyor; kablo takılıyken belge
  /// açılıyor. `debugPrint` ise yalnızca kablo bağlıyken okunabiliyor,
  /// yani sorunun görüldüğü koşulda elimizde hiçbir kanıt kalmıyordu.
  ///
  /// Adımı ekrana yazınca kullanıcı hangi aşamada donduğunu kendisi
  /// görüp söyleyebiliyor. Sorun çözülünce bu alan kaldırılabilir.
  final _adim = ValueNotifier<String>('başlatılıyor');

  Future<Uint8List> _uret(PdfPageFormat f) {
    // Süregelen üretim varsa ona bağlan; ikinci kez üretme.
    return _uretim ??= _uretGercek(f);
  }

  Future<Uint8List> _uretGercek(PdfPageFormat f) async {
    // Süre ölçümü release'de de açık.
    //
    // "Belge Hazırlanıyor" ekranında takılma şikâyeti geldiğinde tek
    // kanıt bu satır: üretim başladı mı, bitti mi, ne kadar sürdü?
    // Debug logu yalnızca kablo bağlıyken alınabiliyor ve sorun tam
    // da kablo çıkınca görülüyordu.
    final saat = Stopwatch()..start();
    TaniLog.yaz('PDF ▶ üretim başladı: ${widget.fileName}');
    _adim.value = 'belge oluşturuluyor';
    try {
      final b = await widget
          .documentBuilder(f)
          .timeout(
            _zamanAsimi,
            onTimeout: () => throw TimeoutException(
              'Belge ${_zamanAsimi.inSeconds} saniyede hazırlanamadı.',
              _zamanAsimi,
            ),
          );
      saat.stop();
      TaniLog.yaz(
        'PDF ✔ üretim bitti ${saat.elapsedMilliseconds} ms, ${b.length} bayt',
      );
      _adim.value = 'sayfalar çiziliyor (${saat.elapsedMilliseconds} ms)';
      _sonBelge = b;
      return b;
    } catch (e, st) {
      saat.stop();
      TaniLog.yaz('PDF ✖ HATA (${saat.elapsedMilliseconds} ms): $e');
      TaniLog.yaz('$st');
      // Sonraki denemede yeniden üretilebilsin.
      _uretim = null;
      // Hata ekranı `PdfPreview`in onError'ına kalmasın: bazı hatalar
      // oraya hiç ulaşmıyor ve ekran yükleniyor durumunda donuyor.
      //
      // Buradaki setState `PdfPreview`i yeniden kurar — normalde tam da
      // kaçındığımız şey (bkz. [_yakinModu]). Burada zararsız: hata
      // durumunda `PdfPreview` ekrandan tamamen kalkıyor, yerini hata
      // ekranı alıyor.
      if (mounted) {
        setState(() => _hataDurumu = e);
      }
      // rethrow YOK.
      //
      // Hatayı zaten kendimiz gösteriyoruz; yeniden fırlatmak paketin
      // içinde ikinci bir hata yolu açıyor ve Flutter'ın yakalanmamış
      // hata bildirimini tetikliyordu. Boş belge döndürmek de yanlış
      // olurdu (rasterleyici onu ayrıca hata sayar), o yüzden hiç
      // tamamlanmayan bir Future döneriz: ekranı zaten hata kaplıyor.
      return Completer<Uint8List>().future;
    }
  }

  /// Kullanıcı "Yeniden dene" dediğinde.
  void _tekrarDene() {
    setState(() {
      _hataDurumu = null;
      _uretim = null;
      _sonBelge = null;
    });
  }

  Future<void> _yazdir() =>
      Printing.layoutPdf(onLayout: _uret, name: widget.fileName);

  Future<void> _paylas() async {
    final b = _sonBelge ?? await _uret(PdfPageFormat.a4);
    await Printing.sharePdf(bytes: b, filename: widget.fileName);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
              Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        // Sarmalayıcı `InteractiveViewer` KALDIRILDI.
        //
        // Flutter'da ölçek (scale) jesti tek parmak sürüklemeyi de
        // kapsıyor: `panEnabled: false` olsa bile görüntüleyici jesti
        // TANIYOR ve liste kaydırmasıyla yarışıyordu. Sonuç, kasan ve
        // yarıda kesilen bir kaydırmaydı.
        //
        // Bunun yerine paketin kendi yakınlaştırma modu kullanılıyor:
        // sayfaya ÇİFT DOKUNUNCA tek sayfa görünümüne geçiyor ve orada
        // liste olmadığı için iki parmak yakınlaştırma akıcı çalışıyor.
        // Bu moda geçiş ipucu alt çubukta veriliyor.
        //
        // Hata kendi durumumuzdan okunur: `PdfPreview`in onError'ı bazı
        // hatalarda hiç çağrılmıyor ve ekran yükleniyor görünümünde
        // donuyordu ("Belge Hazırlanıyor" şikâyeti).
        child: _hataDurumu != null
            ? _hata(isDark, _hataDurumu!)
            : PdfPreview(
                build: _uret,
                pdfFileName: widget.fileName,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                // Eylem çubuğunu biz sunuyoruz (alt çubuk); hazır çubuk
                // ekranın üstünde ikinci bir sıra oluşturuyordu.
                useActions: false,
                maxPageWidth: 700,
                // Raster çözünürlüğü varsayılan olarak ekran genişliğinden
                // hesaplanıyor; yakınlaştırınca yazılar bulanıklaşıyordu.
                // 150 dpi, A4'ü ~1240 piksel genişliğinde üretir: tablonun
                // 6.8 punto metni büyütüldüğünde de okunur kalır.
                //
                // Bellek sınırı diye düşürülmesi DENENDİ ve gereksiz
                // olduğu ölçüldü: 150 dpi'da sayfa başına 8.3 MB, dört
                // sayfalık en ağır belge 33 MB — cihazın 256 MB'lık
                // sınırının çok altında. Takılmanın sebebi bu değil.
                dpi: 150,
                previewPageMargin: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                loadingWidget: _yukleniyor(isDark),
                onError: (context, error) => _hata(isDark, error),
                // setState YOK — bkz. [_yakinModu] açıklaması. Buradaki
                // bir setState, PdfPreview'i yeniden kurup önizlemeyi
                // sonsuza kadar boş bırakıyordu.
                onZoomChanged: (z) => _yakinModu.value = z,
                // Sayfa sayisi degistiginde rasterizasyonun ilerledigini
                // biliriz; ekrandaki adim yazisi bunu gosterir.
                onPageFormatChanged: (_) {
                  _adim.value = 'sayfa düzeni hazırlanıyor';
                  TaniLog.yaz('RASTER ▶ sayfa düzeni değişti');
                },
              ),
      ),
      bottomNavigationBar: _altCubuk(isDark),
    );
  }

  Widget _altCubuk(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yakınlaştırmanın nasıl açıldığı hiçbir yerde
            // yazmıyordu; öğretmen belgeyi büyütemediğini sanıyordu.
            //
            // Yalnızca BU metin yeniden çizilir; PdfPreview'e
            // dokunulmaz (bkz. [_yakinModu]).
            ValueListenableBuilder<bool>(
              valueListenable: _yakinModu,
              builder: (context, yakin, _) => Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  yakin
                      ? 'İki parmakla yakınlaştırın · Çıkmak için çift dokunun'
                      : 'Yakınlaştırmak için sayfaya çift dokunun',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dugme(isDark, Icons.print_rounded, 'Yazdır', _yazdir),
                _dugme(isDark, Icons.ios_share_rounded, 'Paylaş', _paylas),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dugme(
    bool isDark,
    IconData ikon,
    String etiket,
    Future<void> Function() eylem,
  ) {
    return Expanded(
      child: InkWell(
        onTap: eylem,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ikon,
                size: 19,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              const SizedBox(width: 8),
              Text(
                etiket,
                style: AppFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yukleniyor(bool isDark) {
    return Center(
      child: Container(
        // Sabit 80 punto dikey marj YATAY ekranda taşıyordu
        // ("BOTTOM OVERFLOWED BY 36 PIXELS"). Marj kaldırıldı,
        // kutu kendi içeriği kadar yer kaplıyor.
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Belge Hazırlanıyor...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            // Hangi adımda olduğumuz — takılma kablosuzken görüldüğü ve
            // debugPrint o koşulda okunamadığı için ekrana yazılıyor
            // (bkz. [_adim]).
            const SizedBox(height: 6),
            ValueListenableBuilder<String>(
              valueListenable: _adim,
              builder: (context, adim, _) => Text(
                adim,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hata(bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Belge Görüntülenemedi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error is TimeoutException
                  ? 'Belge beklenenden uzun sürdü ve durduruldu. '
                        'Uygulamayı kapatıp yeniden açmayı deneyin.'
                  : error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            // Sonsuz "hazırlanıyor" yerine kullanıcının elinde bir
            // eylem olmalı; aksi hâlde ekrandan çıkıp yeniden girmekten
            // başka çaresi kalmıyordu.
            FilledButton.icon(
              onPressed: _tekrarDene,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}
