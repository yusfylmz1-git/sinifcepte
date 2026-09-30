import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/turkish_text.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../classes/providers/student_provider.dart';
import '../data/foto_paylasim.dart';
import '../domain/foto_isleme.dart';
import '../domain/ogrenci_foto.dart';
import '../providers/ogrenci_foto_providers.dart';
import 'disa_aktarim_ekrani.dart';
import 'foto_hizalama_ekrani.dart';
import 'widgets/ogrenci_foto_kucuk.dart';

enum _Suzgec { tumu, eksik, inceleme, hazir, dosyaYok }

/// Bir sınıfın e-Okul fotoğrafları (plan §4.2).
///
/// Öğrenciler okul numarasına göre sıralı. Fotoğrafın sahibi SINIF DEĞİL
/// öğrencidir: öğrenci başka sınıfa taşınırsa fotoğrafı onunla gider.
class SinifFotoEkrani extends ConsumerStatefulWidget {
  const SinifFotoEkrani({super.key, required this.sinif});

  final ClassModel sinif;

  @override
  ConsumerState<SinifFotoEkrani> createState() => _SinifFotoEkraniState();
}

class _SinifFotoEkraniState extends ConsumerState<SinifFotoEkrani> {
  _Suzgec _suzgec = _Suzgec.tumu;
  String _arama = '';
  bool _izgara = false;
  bool _mesgul = false;

  int get _sinifId => widget.sinif.id!;

  static _Suzgec _durumu(OgrenciFoto? f) {
    if (f == null) return _Suzgec.eksik;
    switch (f.status) {
      case FotoDurumu.hazir:
        return _Suzgec.hazir;
      case FotoDurumu.inceleme:
        return _Suzgec.inceleme;
      default:
        return _Suzgec.dosyaYok;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ogrencilerA = ref.watch(studentListProvider(_sinifId));
    final fotolarA = ref.watch(sinifFotolariProvider(_sinifId));

    return Scaffold(
      appBar: AppBar(
        title: Text('e-Okul foto · ${widget.sinif.name}'),
        actions: [
          IconButton(
            tooltip: 'Dışa aktar',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DisaAktarimEkrani(baslangicSinifId: _sinifId)),
            ),
          ),
          IconButton(
            tooltip: _izgara ? 'Liste görünümü' : 'Fotoğraf ızgarası',
            icon: Icon(_izgara ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _izgara = !_izgara),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'hepsini_sil') _sinifFotolariniSil();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'hepsini_sil', child: Text('Bu sınıfın fotoğraflarını sil')),
            ],
          ),
        ],
      ),
      body: ogrencilerA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Öğrenciler yüklenemedi: $e')),
        data: (ogrenciler) {
          final fotolar = fotolarA.valueOrNull ?? const <int, OgrenciFoto>{};
          final sirali = [...ogrenciler]..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));
          final sayim = {for (final s in _Suzgec.values) s: 0};
          for (final o in sirali) {
            sayim[_durumu(fotolar[o.id])] = sayim[_durumu(fotolar[o.id])]! + 1;
          }
          sayim[_Suzgec.tumu] = sirali.length;
          final gorunen = sirali.where((o) {
            if (_suzgec != _Suzgec.tumu && _durumu(fotolar[o.id]) != _suzgec) return false;
            final q = _arama.trim();
            if (q.isEmpty) return true;
            return '${o.schoolNumber}'.startsWith(q) ||
                trContains('${o.firstName} ${o.lastName}', q);
          }).toList();

          if (sirali.isEmpty) {
            return const _BosDurum(
              metin: 'Bu sınıfta öğrenci yok. Önce Sınıflarım ekranından öğrenci ekleyin.',
            );
          }

          return Stack(
            children: [
              Column(
                children: [
                  _OzetSeridi(
                    hazir: sayim[_Suzgec.hazir]! + sayim[_Suzgec.inceleme]!,
                    toplam: sirali.length,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextField(
                      key: const Key('eokul_foto_arama'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Numara ya da ad ile ara',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _arama = v),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      children: [
                        for (final s in _Suzgec.values)
                          if (s == _Suzgec.tumu ||
                              s == _Suzgec.eksik ||
                              s == _Suzgec.hazir ||
                              sayim[s]! > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text('${_suzgecAdi(s)} (${sayim[s]})'),
                                selected: _suzgec == s,
                                onSelected: (_) => setState(() => _suzgec = s),
                              ),
                            ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: gorunen.isEmpty
                        ? const _BosDurum(metin: 'Bu süzgece uyan öğrenci yok.')
                        : _izgara
                            ? _izgaraGorunumu(gorunen, fotolar)
                            : _listeGorunumu(gorunen, fotolar),
                  ),
                ],
              ),
              if (_mesgul)
                const ColoredBox(
                  color: Color(0x55000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _suzgecAdi(_Suzgec s) => switch (s) {
        _Suzgec.tumu => 'Tümü',
        _Suzgec.eksik => 'Fotoğrafı yok',
        _Suzgec.inceleme => 'Uyarılı',
        _Suzgec.hazir => 'Hazır',
        _Suzgec.dosyaYok => 'Dosya kayıp',
      };

  Widget _listeGorunumu(List<StudentModel> liste, Map<int, OgrenciFoto> fotolar) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: liste.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final o = liste[i];
        final f = fotolar[o.id];
        return ListTile(
          key: ValueKey('eokul_ogrenci_${o.id}'),
          onTap: () => _ogrenciIslemleri(o, f),
          leading: OgrenciFotoKucuk(foto: f, genislik: 40),
          title: Text('${o.schoolNumber}  ${o.firstName} ${o.lastName}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: _DurumEtiketi(foto: f),
          trailing: Icon(
            f == null ? Icons.add_photo_alternate_outlined : Icons.more_vert_rounded,
          ),
        );
      },
    );
  }

  Widget _izgaraGorunumu(List<StudentModel> liste, Map<int, OgrenciFoto> fotolar) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        childAspectRatio: 0.52,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final o = liste[i];
        final f = fotolar[o.id];
        return InkWell(
          onTap: () => _ogrenciIslemleri(o, f),
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(builder: (context, k) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OgrenciFotoKucuk(foto: f, genislik: k.maxWidth),
                const SizedBox(height: 4),
                // Plan: ızgarada yalnız numara değil numara + ad-soyad.
                Text('${o.schoolNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${o.firstName} ${o.lastName}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                _DurumEtiketi(foto: f, kisa: true),
              ],
            );
          }),
        );
      },
    );
  }

  // --- Öğrenci işlemleri ---------------------------------------------------

  Future<void> _ogrenciIslemleri(StudentModel o, OgrenciFoto? f) async {
    final adSoyad = '${o.firstName} ${o.lastName}';
    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  OgrenciFotoKucuk(foto: f, genislik: 80),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.sinif.name} • ${o.schoolNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(adSoyad,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        _DurumEtiketi(foto: f),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (f != null && f.status == FotoDurumu.dosyaYok)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Fotoğraf kaydı var ama dosyası bu cihazda bulunamadı '
                    '(yedekten dönülmüş olabilir). Yeniden seçin ya da kaydı kaldırın.',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(f == null ? 'Galeriden seç' : 'Galeriden değiştir'),
                subtitle: const Text('Seçtikten sonra hizalayıp onaylayacaksınız'),
                onTap: () => Navigator.pop(ctx, 'galeri'),
              ),
              if (f != null && f.hazirMi) ...[
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Paylaş / kaydet'),
                  subtitle: Text(eokulDosyaAdi(
                      okulNo: o.schoolNumber, ad: o.firstName, soyad: o.lastName)),
                  onTap: () => Navigator.pop(ctx, 'paylas'),
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text('Başka öğrenciye aktar'),
                  subtitle: const Text('Yanlış öğrenciye kaydedildiyse'),
                  onTap: () => Navigator.pop(ctx, 'aktar'),
                ),
              ],
              if (f != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  title: Text(
                    f.hazirMi ? 'Fotoğrafı sil' : 'Kaydı kaldır',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  subtitle: const Text('Öğrenci kaydı ve diğer bilgileri silinmez'),
                  onTap: () => Navigator.pop(ctx, 'sil'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || secim == null) return;
    switch (secim) {
      case 'galeri':
        await _galeridenEkle(o, mevcutVar: f != null);
      case 'paylas':
        await _paylas(o, f!);
      case 'aktar':
        await _aktar(o, f!);
      case 'sil':
        await _sil(o, f!);
    }
  }

  Future<void> _galeridenEkle(StudentModel o, {required bool mevcutVar}) async {
    XFile? secilen;
    try {
      secilen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Telefonun kendi çözücüsü küçültür: 50 MP fotoğraf Dart'a
        // tam boy gelmez (bkz. pubspec notu).
        maxWidth: calismaUzunKenar.toDouble(),
        maxHeight: calismaUzunKenar.toDouble(),
        imageQuality: 95,
        requestFullMetadata: false,
      );
    } on PlatformException catch (e) {
      _mesaj('Galeri açılamadı: ${e.message ?? e.code}', hata: true);
      return;
    }
    if (secilen == null || !mounted) return;

    setState(() => _mesgul = true);
    CalismaGoruntusu calisma;
    try {
      calisma = await calismaGoruntusuAc(await secilen.readAsBytes());
    } catch (e) {
      if (mounted) setState(() => _mesgul = false);
      _mesaj(e is FotoIslemeHatasi ? e.mesaj : 'Fotoğraf açılamadı: $e', hata: true);
      return;
    }
    if (!mounted) return;
    setState(() => _mesgul = false);

    final kaydedildi = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FotoHizalamaEkrani(
          ogrenci: o,
          sinifAdi: widget.sinif.name,
          calisma: calisma,
          kaynak: FotoKaynagi.dosya,
          mevcutFotoVar: mevcutVar,
        ),
      ),
    );
    if (kaydedildi == true) {
      _mesaj('${o.schoolNumber} — ${o.firstName} ${o.lastName}: fotoğraf kaydedildi.');
    }
  }

  Future<void> _paylas(StudentModel o, OgrenciFoto f) async {
    final depo = await ref.read(ogrenciFotoDeposuProvider.future);
    if (!await depo.butunlukTamam(f)) {
      _mesaj('Fotoğraf dosyası bozuk ya da eksik; yeniden seçin.', hata: true);
      return;
    }
    await FotoPaylasim.paylas(
      kaynak: depo.depolama.dosya(f.standardPath),
      dosyaAdi: eokulDosyaAdi(okulNo: o.schoolNumber, ad: o.firstName, soyad: o.lastName),
    );
  }

  Future<void> _aktar(StudentModel kaynak, OgrenciFoto f) async {
    final ogrenciler = ref.read(studentListProvider(_sinifId)).valueOrNull ?? const [];
    final fotolar = ref.read(sinifFotolariProvider(_sinifId)).valueOrNull ?? const {};
    final adaylar = [...ogrenciler.where((o) => o.id != kaynak.id)]
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));
    if (adaylar.isEmpty) {
      _mesaj('Bu sınıfta aktarılacak başka öğrenci yok.');
      return;
    }
    final hedef = await showDialog<StudentModel>(
      context: context,
      builder: (ctx) => _OgrenciSecDiyalogu(adaylar: adaylar),
    );
    if (hedef == null || !mounted) return;

    DateTime? onay;
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Fotoğrafı aktar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Şu an: ${kaynak.schoolNumber} — ${kaynak.firstName} ${kaynak.lastName}'),
              const SizedBox(height: 4),
              Text(
                'Aktarılacak: ${hedef.schoolNumber} — ${hedef.firstName} ${hedef.lastName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (fotolar[hedef.id] != null) ...[
                const SizedBox(height: 8),
                const Text('Hedef öğrencinin mevcut fotoğrafı değiştirilecek.',
                    style: TextStyle(color: AppColors.warning)),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: onay != null,
                onChanged: (v) => setD(() => onay = (v ?? false) ? DateTime.now() : null),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Fotoğraf ${hedef.schoolNumber} — ${hedef.firstName} ${hedef.lastName} öğrencisine ait'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: onay == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Aktar'),
            ),
          ],
        ),
      ),
    );
    if (tamam != true || onay == null || !mounted) return;
    try {
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      await depo.yenidenEsle(
        kaynakOgrenciId: kaynak.id!,
        hedefOgrenciId: hedef.id!,
        kimlikOnaylandi: onay!,
      );
      if (!mounted) return;
      fotolarDegisti(ref);
      _mesaj('Fotoğraf ${hedef.schoolNumber} — ${hedef.firstName} ${hedef.lastName} öğrencisine aktarıldı.');
    } catch (e) {
      _mesaj('Aktarılamadı: $e', hata: true);
    }
  }

  Future<void> _sil(StudentModel o, OgrenciFoto f) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğrafı sil'),
        content: Text(
          '${o.schoolNumber} — ${o.firstName} ${o.lastName} öğrencisinin fotoğrafı silinecek.\n\n'
          'Yalnızca fotoğraf silinir; öğrenci kaydı, katılım ve not bilgileri silinmez.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fotoğrafı sil'),
          ),
        ],
      ),
    );
    if (evet != true || !mounted) return;
    try {
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      await depo.sil(o.id!);
      if (!mounted) return;
      fotolarDegisti(ref);
      _mesaj('Fotoğraf silindi.');
    } catch (e) {
      _mesaj('Silinemedi: $e', hata: true);
    }
  }

  /// Yıl sonu temizliği: sınıfın bütün fotoğrafları. Öğrenciler kalır.
  Future<void> _sinifFotolariniSil() async {
    final sayi = (ref.read(sinifFotolariProvider(_sinifId)).valueOrNull ?? const {}).length;
    if (sayi == 0) {
      _mesaj('Bu sınıfta silinecek fotoğraf yok.');
      return;
    }
    var anladim = false;
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('${widget.sinif.name}: fotoğrafları sil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$sayi öğrencinin fotoğrafı bu cihazdan silinecek. Öğrenci kayıtları, '
                  'katılım ve not bilgileri silinmez.'),
              const SizedBox(height: 6),
              const Text('Daha önce paylaştığınız kopyalar bundan etkilenmez.',
                  style: TextStyle(fontSize: 12)),
              CheckboxListTile(
                value: anladim,
                onChanged: (v) => setD(() => anladim = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text('$sayi fotoğrafın silineceğini anlıyorum'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: anladim ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Sil'),
            ),
          ],
        ),
      ),
    );
    if (evet != true || !mounted) return;
    try {
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      final n = await depo.sinifFotolariniSil(_sinifId);
      if (!mounted) return;
      fotolarDegisti(ref);
      _mesaj('$n fotoğraf silindi.');
    } catch (e) {
      _mesaj('Silinemedi: $e', hata: true);
    }
  }

  void _mesaj(String metin, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(metin), backgroundColor: hata ? AppColors.danger : null),
    );
  }
}

class _OzetSeridi extends StatelessWidget {
  const _OzetSeridi({required this.hazir, required this.toplam});
  final int hazir;
  final int toplam;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text('$hazir/$toplam hazır',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: toplam == 0 ? 0 : hazir / toplam,
                minHeight: 8,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Durum yalnızca renkle anlatılmaz: simge + metin.
class _DurumEtiketi extends StatelessWidget {
  const _DurumEtiketi({required this.foto, this.kisa = false});
  final OgrenciFoto? foto;
  final bool kisa;

  @override
  Widget build(BuildContext context) {
    final f = foto;
    final (IconData ikon, Color renk, String metin) = switch (f?.status) {
      null => (Icons.radio_button_unchecked_rounded, Colors.grey, 'Fotoğraf yok'),
      FotoDurumu.hazir => (Icons.check_circle_rounded, AppColors.success, 'Hazır'),
      FotoDurumu.inceleme => (Icons.error_outline_rounded, AppColors.warning, 'Uyarıyla onaylandı'),
      _ => (Icons.broken_image_outlined, AppColors.danger, 'Dosya kayıp'),
    };
    final tarih = (!kisa && f != null) ? ' · ${DateFormat('dd.MM.yyyy').format(f.approvedAt.toLocal())}' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: kisa ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(ikon, size: 14, color: renk),
        const SizedBox(width: 4),
        Flexible(
          child: Text('$metin$tarih',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: renk)),
        ),
      ],
    );
  }
}

class _BosDurum extends StatelessWidget {
  const _BosDurum({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(metin, textAlign: TextAlign.center),
        ),
      );
}

class _OgrenciSecDiyalogu extends StatefulWidget {
  const _OgrenciSecDiyalogu({required this.adaylar});
  final List<StudentModel> adaylar;

  @override
  State<_OgrenciSecDiyalogu> createState() => _OgrenciSecDiyaloguState();
}

class _OgrenciSecDiyaloguState extends State<_OgrenciSecDiyalogu> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final liste = widget.adaylar
        .where((o) => '${o.schoolNumber}'.startsWith(_q.trim()) ||
            trContains('${o.firstName} ${o.lastName}', _q))
        .toList();
    return AlertDialog(
      title: const Text('Doğru öğrenciyi seçin'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Numara ya da ad',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (_, i) {
                  final o = liste[i];
                  return ListTile(
                    dense: true,
                    title: Text('${o.schoolNumber}  ${o.firstName} ${o.lastName}'),
                    onTap: () => Navigator.pop(context, o),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
      ],
    );
  }
}
