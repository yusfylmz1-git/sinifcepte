import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../data/ogretmen_tahta_deposu.dart';
import '../utils/tahta_totp.dart';

/// Öğretmenin tahta kilidini açtığı ekran.
///
/// ## İki aşama
///
/// 1. **Kurulum (bir kez)** — idarecinin gösterdiği QR okutulur, secret
///    telefona kaydedilir.
/// 2. **Açma (her ders)** — tahtadaki QR okutulur veya okul/tahta kodu
///    elle girilir; ekranda 6 hane görünür, öğretmen tahtaya yazar.
///
/// ## Neden 6 hane, neden QR'dan doğrudan açma değil
///
/// Tahtanın kamerası yok ve tahta ağa çıkmıyor — telefon tahtaya
/// hiçbir şey **gönderemez**. Bu yüzden insan aracılığıyla taşınan kısa
/// kod zorunlu.
///
/// ## Kamera yoksa akış kesilmiyor (kullanıcı kararı)
///
/// `mobile_scanner` Windows'u desteklemiyor ve kamera izni
/// reddedilebilir. Bu durumda öğretmen tahtada yazan okul kodunu elle
/// girer; kod üretimi aynı şekilde çalışır. Kamera bir kolaylık, şart
/// değil.
class TahtaKilidiScreen extends StatefulWidget {
  const TahtaKilidiScreen({super.key});

  @override
  State<TahtaKilidiScreen> createState() => _TahtaKilidiScreenState();
}

class _TahtaKilidiScreenState extends State<TahtaKilidiScreen> {
  final _depo = OgretmenTahtaDeposu();
  final _okulKoduCtrl = TextEditingController();

  bool _yukleniyor = true;
  OgretmenTahtaKaydi? _kayit;

  /// Üretilen kod ve geri sayım.
  String? _kod;
  int _kalanSaniye = 0;
  Timer? _sayac;

  @override
  void initState() {
    super.initState();
    _kaydiYukle();
  }

  @override
  void dispose() {
    _sayac?.cancel();
    _okulKoduCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydiYukle() async {
    final kayit = await _depo.oku();
    if (!mounted) return;
    setState(() {
      _kayit = kayit;
      _yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tahta Kilidi', style: AppFonts.outfit(fontSize: 17)),
        actions: [
          if (_kayit != null)
            IconButton(
              tooltip: 'Kaydı sil',
              icon: const Icon(Icons.link_off_rounded),
              onPressed: _kaydiSil,
            ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_kayit == null)
                  _kurulumBolumu(isDark)
                else ...[
                  _kimlikKarti(isDark),
                  const SizedBox(height: 16),
                  if (_kod != null) _kodKarti(isDark),
                  if (_kod != null) const SizedBox(height: 16),
                  _acmaBolumu(isDark),
                  const SizedBox(height: 16),
                  _yardimKarti(isDark),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // --- Kurulum ---

  Widget _kurulumBolumu(bool isDark) {
    return _kart(
      isDark,
      baslik: '📲 Kurulum',
      aciklama: 'Okul yöneticisi size bir QR gösterecek. Onu okutunca '
          'bu telefon tahtayı açabilir hâle gelir. Bir kez yapılır.',
      cocuklar: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _qrOkut(kurulumMu: true),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text('Kurulum QR\'ını Okut',
                style: AppFonts.outfit(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Kameranız yoksa veya çalışmıyorsa yöneticiden kurulum '
          'metnini isteyip aşağıya yapıştırabilirsiniz.',
          style: AppFonts.outfit(
              fontSize: 10.5, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _okulKoduCtrl,
          maxLength: 300,
          decoration: _girdi('Kurulum metni', 'SCT1:...'),
          style: AppFonts.outfit(fontSize: 12),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _kurulumKaydet(_okulKoduCtrl.text),
            child: Text('Metni Kaydet',
                style: AppFonts.outfit(fontSize: 12.5)),
          ),
        ),
      ],
    );
  }

  Future<void> _kurulumKaydet(String ham) async {
    final kayit = await _depo.qrIleKaydet(ham);
    if (!mounted) return;

    if (kayit == null) {
      _mesaj(
        'Bu kod tanınmadı. Yöneticinin gösterdiği kurulum QR\'ını '
        'okuttuğunuzdan emin olun — tahtanın ekranındaki QR farklıdır.',
        hata: true,
      );
      return;
    }

    _okulKoduCtrl.clear();
    await _kaydiYukle();
    if (!mounted) return;
    _mesaj('Kurulum tamam. Artık tahtayı açabilirsiniz.');
  }

  // --- Kimlik ---

  Widget _kimlikKarti(bool isDark) {
    final k = _kayit!;
    return _kart(
      isDark,
      baslik: '✅ Tanımlı',
      aciklama: 'Tahtada bu kodu kullanacaksınız.',
      cocuklar: [
        _bilgiSatiri(Icons.badge_outlined, 'Öğretmen kodu', k.kod),
        const SizedBox(height: 6),
        _bilgiSatiri(Icons.person_outline_rounded, 'Ad', k.ad),
      ],
    );
  }

  // --- Kod gösterimi ---

  Widget _kodKarti(bool isDark) {
    // Süre azaldıkça renk uyarıya döner: öğretmen kodu yazarken
    // süresinin dolduğunu görmeli, yoksa "yanlış kod" sanır.
    final azKaldi = _kalanSaniye <= 7;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (azKaldi ? Colors.orange : AppColors.primary)
            .withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (azKaldi ? Colors.orange : AppColors.primary)
              .withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Text('Tahtaya bu kodu girin',
              style: AppFonts.outfit(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            // Okunurluk için 3+3: tahtada elle giriliyor.
            '${_kod!.substring(0, 3)} ${_kod!.substring(3)}',
            style: AppFonts.outfit(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: azKaldi ? Colors.orange : AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_kalanSaniye saniye geçerli',
            style: AppFonts.outfit(
              fontSize: 11.5,
              color: azKaldi ? Colors.orange : Colors.grey,
              fontWeight: azKaldi ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _kod!));
              _mesaj('Kod kopyalandı.');
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: Text('Kopyala', style: AppFonts.outfit(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // --- Açma ---

  Widget _acmaBolumu(bool isDark) {
    return _kart(
      isDark,
      baslik: '🔓 Kilidi Aç',
      aciklama: 'Tahtadaki QR\'ı okutun; kod ekranda görünecek.',
      cocuklar: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _qrOkut(kurulumMu: false),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text('Tahtadaki QR\'ı Okut',
                style: AppFonts.outfit(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _kodUretDogrudan,
            icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
            label: Text('QR olmadan kod üret',
                style: AppFonts.outfit(fontSize: 12.5)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kamera çalışmıyorsa "QR olmadan kod üret"e basın. QR yalnızca '
          'doğru tahtada olduğunuzu teyit eder; kod aynı şekilde çalışır.',
          style: AppFonts.outfit(
              fontSize: 10.5, color: Colors.grey, height: 1.4),
        ),
      ],
    );
  }

  /// QR olmadan kod üretir.
  ///
  /// QR'ın tek işi okul eşleşmesini teyit etmek; secret telefonda
  /// olduğu için kod her hâlükârda üretilebilir. Kamerası bozuk
  /// öğretmen sınıfta mahsur kalmasın.
  void _kodUretDogrudan() {
    final k = _kayit;
    if (k == null) return;
    _kodUret(k.totpSecret);
  }

  void _kodUret(String secret) {
    try {
      final kod = TahtaTotp.kodUret(secret);
      _sayac?.cancel();

      setState(() {
        _kod = kod;
        _kalanSaniye = TahtaTotp.kalanSaniye();
      });

      _sayac = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final kalan = TahtaTotp.kalanSaniye();
        // Pencere döndüğünde kod da yenilenmeli; eski kodu göstermeye
        // devam etmek tahtada reddedilir.
        setState(() {
          _kalanSaniye = kalan;
          if (kalan == TahtaTotp.adimSn) {
            _kod = TahtaTotp.kodUret(secret);
          }
        });
      });
    } catch (e, stackTrace) {
      debugPrint('Kod üretme hatası: $e\n$stackTrace');
      _mesaj('Kod üretilemedi. Kurulumu yeniden yapmanız gerekebilir.',
          hata: true);
    }
  }

  // --- QR tarama ---

  Future<void> _qrOkut({required bool kurulumMu}) async {
    final sonuc = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _QrTaramaSayfasi(
          baslik: kurulumMu ? 'Kurulum QR\'ı' : 'Tahtadaki QR',
        ),
      ),
    );

    if (sonuc == null || !mounted) return;

    if (kurulumMu) {
      await _kurulumKaydet(sonuc);
      return;
    }

    // Tahtanın QR'ı: okul eşleşmesini teyit et.
    final yuk = TahtaTotp.qrAyristir(sonuc);
    if (yuk == null) {
      _mesaj(
        'Bu QR bir SınıfCepte tahtasına ait değil.',
        hata: true,
      );
      return;
    }

    final k = _kayit!;
    if (!yuk.ayniOkul(k.okulId)) {
      // Sessizce çalışmayan kod vermek yerine sebebi söyle.
      _mesaj(
        'Bu tahta başka bir okula ait. Kendi okulunuzun tahtasında '
        'deneyin.',
        hata: true,
      );
      return;
    }

    _kodUret(k.totpSecret);
  }

  Future<void> _kaydiSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kayıt silinsin mi?',
            style: AppFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Bu telefon artık tahtayı açamaz. Yeniden kurmak için '
          'yöneticiden QR istemeniz gerekir.',
          style: AppFonts.outfit(fontSize: 12.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    await _depo.sil();
    _sayac?.cancel();
    if (!mounted) return;
    setState(() {
      _kod = null;
      _kalanSaniye = 0;
    });
    await _kaydiYukle();
  }

  // --- Yardım ---

  Widget _yardimKarti(bool isDark) {
    return _kart(
      isDark,
      baslik: 'ℹ️ Kod kabul edilmiyorsa',
      aciklama: '',
      cocuklar: [
        Text(
          'Tahtanın saati şaşmışsa telefonun ürettiği kod kabul '
          'edilmez. Bu durumda tahtada kendi PIN\'inizi veya USB '
          'anahtarınızı kullanın; ikisi de saatten bağımsız çalışır.',
          style: AppFonts.outfit(fontSize: 11.5, height: 1.45),
        ),
      ],
    );
  }

  // --- Ortak parçalar ---

  Widget _kart(
    bool isDark, {
    required String baslik,
    required String aciklama,
    required List<Widget> cocuklar,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.grey.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik,
              style: AppFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          if (aciklama.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(aciklama,
                style: AppFonts.outfit(
                    fontSize: 11.5, color: Colors.grey, height: 1.4)),
          ],
          const SizedBox(height: 12),
          ...cocuklar,
        ],
      ),
    );
  }

  Widget _bilgiSatiri(IconData ikon, String etiket, String deger) {
    return Row(
      children: [
        Icon(ikon, size: 17, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$etiket: ',
            style: AppFonts.outfit(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            deger.isEmpty ? '—' : deger,
            style: AppFonts.outfit(
                fontSize: 12.5, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  InputDecoration _girdi(String etiket, String ipucu) {
    return InputDecoration(
      labelText: etiket,
      hintText: ipucu,
      labelStyle: AppFonts.outfit(fontSize: 12.5),
      hintStyle: AppFonts.outfit(fontSize: 12, color: Colors.grey),
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }

  void _mesaj(String metin, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(metin, style: AppFonts.outfit(fontSize: 12.5)),
        backgroundColor: hata ? Colors.redAccent : AppColors.primary,
        duration: Duration(seconds: hata ? 6 : 3),
      ),
    );
  }
}

/// QR tarama sayfası.
///
/// Kamera açılamazsa (izin reddi, donanım yok, Windows) kullanıcıya
/// **ne yapacağını** söyler ve geri döner; sessiz siyah ekran
/// bırakmaz.
class _QrTaramaSayfasi extends StatefulWidget {
  const _QrTaramaSayfasi({required this.baslik});

  final String baslik;

  @override
  State<_QrTaramaSayfasi> createState() => _QrTaramaSayfasiState();
}

class _QrTaramaSayfasiState extends State<_QrTaramaSayfasi> {
  bool _okundu = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.baslik, style: AppFonts.outfit(fontSize: 16)),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          // Tek okuma yeterli: `onDetect` saniyede birkaç kez tetikleniyor
          // ve her seferinde Navigator.pop çağırmak çökmeye yol açar.
          if (_okundu) return;

          final deger = capture.barcodes
              .map((b) => b.rawValue)
              .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);

          if (deger == null) return;

          _okundu = true;
          Navigator.of(context).pop(deger);
        },
        errorBuilder: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.no_photography_outlined,
                      size: 42, color: Colors.grey),
                  const SizedBox(height: 14),
                  Text(
                    'Kamera açılamadı',
                    style: AppFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kamera izni verilmemiş veya bu cihazda kamera '
                    'kullanılamıyor olabilir. Geri dönüp "QR olmadan kod '
                    'üret" seçeneğini kullanabilirsiniz — kod aynı '
                    'şekilde çalışır.',
                    textAlign: TextAlign.center,
                    style: AppFonts.outfit(fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Geri dön',
                        style: AppFonts.outfit(fontSize: 13)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
