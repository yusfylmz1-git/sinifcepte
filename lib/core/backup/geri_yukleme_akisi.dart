import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/student_photos/providers/ogrenci_foto_providers.dart';
import '../database/account_switch.dart';
import '../theme/app_colors.dart';
import 'backup_service.dart';
import 'tam_yedek.dart';

/// Yedekten geri yükleme ekranı (plan §16).
///
/// 1. Dosya seçilir ve İNCELENİR — hiçbir şeyin üzerine yazılmaz.
/// 2. Somut kapsam: yedeğin tarihi ve içeriği, bu cihazda SİLİNECEK veri.
///    Eski biçim (fotoğrafsız) ve başka hesabın yedeği ayrıca uyarılır.
/// 3. "Mevcut verilerin silineceğini anlıyorum" işaretlenmeden
///    uygulanmaz. Yarıda kalırsa önceki veri geri konur.
///
/// Diyalog zinciri yerine ekran: akış çekmeceden başlıyor ve çekmecenin
/// bağlamı kapanınca ölüyor; tazeleme için yaşayan bir `ref` gerekiyor.
class GeriYuklemeEkrani extends ConsumerStatefulWidget {
  const GeriYuklemeEkrani({super.key, this.inceleyici, this.uygulayici, this.mevcutKapsam});

  /// Test kapıları; verilmezse [BackupService].
  final Future<HazirYedek> Function(String yol)? inceleyici;
  final Future<void> Function(HazirYedek yedek)? uygulayici;
  final Future<({int sinif, int ogrenci, int fotograf})> Function()? mevcutKapsam;

  @override
  ConsumerState<GeriYuklemeEkrani> createState() => GeriYuklemeEkraniState();
}

@visibleForTesting
class GeriYuklemeEkraniState extends ConsumerState<GeriYuklemeEkrani> {
  HazirYedek? _hazir;
  ({int sinif, int ogrenci, int fotograf})? _mevcut;
  bool _anladim = false;
  String? _durum; // "İnceleniyor…" / "Geri yükleniyor…"
  String? _hata;
  bool _bitti = false;

  @override
  void dispose() {
    final h = _hazir;
    if (h != null && !_bitti) h.temizle();
    super.dispose();
  }

  Future<void> _dosyaSec() async {
    final secim = await FilePicker.platform.pickFiles(
      dialogTitle: 'SınıfCepte yedek dosyasını seçin (.sinifcepte)',
      // Uzantı süzgeci bazı Android seçicilerinde dosyayı gizliyor; biçim
      // içerikten anlaşılır.
      type: FileType.any,
    );
    final yol = secim?.files.single.path;
    if (yol != null) await incele(yol);
  }

  /// Seçilen dosyayı inceler (testler doğrudan çağırır).
  @visibleForTesting
  Future<void> incele(String yol) async {
    await _hazir?.temizle();
    setState(() {
      _hazir = null;
      _anladim = false;
      _hata = null;
      _durum = 'Yedek inceleniyor…';
    });
    try {
      final h = await (widget.inceleyici ?? BackupService.instance.yedegiIncele)(yol);
      final m = await (widget.mevcutKapsam ?? BackupService.instance.mevcutKapsam)();
      if (!mounted) {
        await h.temizle();
        return;
      }
      setState(() {
        _hazir = h;
        _mevcut = m;
      });
    } on YedekHatasi catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } catch (e) {
      if (mounted) setState(() => _hata = 'Yedek okunamadı: $e');
    } finally {
      if (mounted) setState(() => _durum = null);
    }
  }

  Future<void> _uygula() async {
    final h = _hazir;
    if (h == null || !_anladim) return;
    setState(() {
      _durum = 'Geri yükleniyor…';
      _hata = null;
    });
    try {
      await (widget.uygulayici ?? BackupService.instance.geriYukle)(h);
      _bitti = true;
      if (!mounted) return;
      // Bütün yerel sağlayıcılar yeni veriyi okusun.
      AccountSwitch.invalidateLocalData(ref);
      fotolarDegisti(ref);
      setState(() => _durum = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _durum = null;
        _hata = e is YedekHatasi
            ? e.mesaj
            : 'Geri yükleme tamamlanamadı; önceki verileriniz yerinde bırakıldı. ($e)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _hazir;
    final m = _mevcut;
    return PopScope(
      canPop: _durum == null,
      child: Scaffold(
        appBar: AppBar(title: const Text('Yedekten geri yükle')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_bitti && h != null) ...[
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
              const SizedBox(height: 8),
              Text(
                'Geri yükleme tamamlandı: ${h.sinif} sınıf, ${h.ogrenci} öğrenci, ${h.fotograf} fotoğraf.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
            ] else ...[
              const Text(
                'SınıfCepte yedek dosyasını (.sinifcepte) seçin. Dosya önce incelenir; '
                'onay vermeden hiçbir şey değişmez.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _durum == null ? _dosyaSec : null,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(h == null ? 'Yedek dosyası seç' : 'Başka dosya seç'),
              ),
              if (_durum != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Text(_durum!),
                  ]),
                ),
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_hata!, style: const TextStyle(color: AppColors.danger)),
                ),
              if (h != null && m != null && _durum == null) ..._kapsam(h, m),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _kapsam(HazirYedek h, ({int sinif, int ogrenci, int fotograf}) m) {
    final eksikDosya = h.fotoKaydi - h.fotograf;
    return [
      const SizedBox(height: 16),
      Text('Yedek tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(h.tarih)}'),
      const SizedBox(height: 4),
      Text('Yedekte: ${h.sinif} sınıf, ${h.ogrenci} öğrenci, ${h.fotograf} fotoğraf',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Text(
        'Bu cihazdaki ${m.sinif} sınıf, ${m.ogrenci} öğrenci ve ${m.fotograf} fotoğraf '
        'SİLİNİP yedektekiyle değiştirilecek.',
        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
      ),
      if (h.baskaHesap) ...[
        const SizedBox(height: 10),
        const Text(
          'Bu yedek BAŞKA bir hesaptan alınmış. Kendi verileriniz yerine o hesabın verileri gelecek.',
          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
        ),
      ],
      if (!h.fotografli) ...[
        const SizedBox(height: 10),
        const Text(
          'Bu yedek eski biçimde ve fotoğraf içermiyor. Bu cihazdaki e-Okul fotoğrafları da silinecek.',
          style: TextStyle(color: AppColors.warning),
        ),
      ],
      if (eksikDosya > 0) ...[
        const SizedBox(height: 10),
        Text(
          '$eksikDosya fotoğrafın dosyası yedekte yok; bu öğrencilerde "dosya kayıp" görünecek.',
          style: const TextStyle(color: AppColors.warning),
        ),
      ],
      const SizedBox(height: 8),
      CheckboxListTile(
        value: _anladim,
        onChanged: (v) => setState(() => _anladim = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: const Text('Mevcut verilerin silineceğini anlıyorum'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
        onPressed: _anladim ? _uygula : null,
        child: const Text('Geri yükle'),
      ),
    ];
  }
}
