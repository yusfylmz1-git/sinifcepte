import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../classes/providers/student_provider.dart';
import '../domain/cekim_sirasi.dart';
import '../domain/ogrenci_foto.dart';
import '../providers/ogrenci_foto_providers.dart';
import 'foto_hizalama_ekrani.dart';
import 'widgets/ogrenci_foto_kucuk.dart';

/// Seri çekim (plan §4.4).
///
/// Sıradaki öğrencinin kimliği kamera açılmadan ÖNCE büyük kartla
/// gösterilir; çekimden sonra hizalama ekranı kimliği yine gösterir ve
/// "bu fotoğraf bu öğrenciye ait" onayı ister. Kayıt bitmeden sonraki
/// öğrenciye geçilmez. Oturum her adımda yazılır: uygulama kapanırsa
/// kaldığı öğrenciden sürer.
///
/// [baslangicSirasi] verilirse yeni oturum başlar; `null` ise sınıfın
/// süren oturumu devam ettirilir.
class SeriCekimEkrani extends ConsumerStatefulWidget {
  const SeriCekimEkrani({super.key, required this.sinif, this.baslangicSirasi, this.arkaPlan});

  final ClassModel sinif;
  final List<int>? baslangicSirasi;

  /// Test kapısı (bkz. [FotoHizalamaEkrani.arkaPlan]).
  final ArkaPlanCalistirici? arkaPlan;

  @override
  ConsumerState<SeriCekimEkrani> createState() => _SeriCekimEkraniState();
}

class _SonKayit {
  const _SonKayit(this.ogrenci, this.foto, this.oncekiVardi);
  final StudentModel ogrenci;
  final OgrenciFoto foto;

  /// Değiştirilen bir fotoğraf vardıysa geri alma onu geri getiremez
  /// (eski fotoğraf yeni kaydedilince silinir — veri en aza indirme).
  final bool oncekiVardi;
}

class _SeriCekimEkraniState extends ConsumerState<SeriCekimEkrani> {
  int? _oturumId;
  CekimSirasi? _sira;
  int? _elleSecilen;
  _SonKayit? _sonKayit;
  bool _mesgul = false;
  String? _hata;

  int get _sinifId => widget.sinif.id!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _baslat());
  }

  Future<void> _baslat() async {
    try {
      final depo = ref.read(cekimOturumuDeposuProvider);
      final (int, CekimSirasi)? o = widget.baslangicSirasi != null
          ? await depo.baslat(_sinifId, widget.baslangicSirasi!)
          : await depo.aktif(_sinifId);
      if (!mounted) return;
      if (o == null) {
        setState(() => _hata = 'Süren bir çekim oturumu yok.');
        return;
      }
      setState(() {
        _oturumId = o.$1;
        _sira = o.$2;
      });
      await _kayipFotografiSor();
    } catch (e) {
      if (mounted) setState(() => _hata = 'Oturum açılamadı: $e');
    }
  }

  /// Kamera açıkken sistem uygulamayı kapattıysa çekilen fotoğraf.
  Future<void> _kayipFotografiSor() async {
    final bayt = await ref.read(fotoAliciProvider).kayipFotograf();
    if (bayt == null || !mounted) return;
    final o = _siradakiOgrenci(_ogrenciler());
    if (o == null) return;
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğraf kurtarıldı'),
        content: Text(
          'Kamera açıkken uygulama kapanmış. Çekilen fotoğraf kurtarıldı.\n\n'
          '${o.schoolNumber} — ${o.firstName} ${o.lastName} için kullanılsın mı? '
          'Sonraki ekranda fotoğrafı görüp kimliği yine onaylayacaksınız.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kullanma')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kullan')),
        ],
      ),
    );
    if (evet == true && mounted) await _isle(o, bayt, kamera: true);
  }

  List<StudentModel> _ogrenciler() => ref.read(studentListProvider(_sinifId)).valueOrNull ?? const [];

  StudentModel? _siradakiOgrenci(List<StudentModel> ogrenciler) {
    final s = _sira;
    if (s == null) return null;
    final gecerli = {for (final o in ogrenciler) o.id!: o};
    final e = _elleSecilen;
    if (e != null && gecerli.containsKey(e)) return gecerli[e];
    final id = s.siradaki(gecerli.keys.toSet());
    return id == null ? null : gecerli[id];
  }

  Future<void> _yaz(CekimSirasi s) async {
    setState(() => _sira = s);
    final id = _oturumId;
    if (id != null) await ref.read(cekimOturumuDeposuProvider).yaz(id, s);
  }

  Future<void> _cek(StudentModel o, {required bool kamera}) async {
    final alici = ref.read(fotoAliciProvider);
    Uint8List? bayt;
    try {
      bayt = kamera ? await alici.kameradanAl() : await alici.galeridenAl();
    } on PlatformException catch (e) {
      _mesaj('${kamera ? 'Kamera' : 'Galeri'} açılamadı: ${e.message ?? e.code}', hata: true);
      return;
    }
    if (bayt == null || !mounted) return;
    await _isle(o, bayt, kamera: kamera);
  }

  Future<void> _isle(StudentModel o, Uint8List bayt, {required bool kamera}) async {
    final oncekiVardi = ref.read(sinifFotolariProvider(_sinifId)).valueOrNull?[o.id] != null;
    final kaydedildi = await fotoyuHizalaVeKaydet(
      context,
      bayt: bayt,
      ogrenci: o,
      sinifAdi: widget.sinif.name,
      kaynak: kamera ? FotoKaynagi.kamera : FotoKaynagi.dosya,
      mevcutFotoVar: oncekiVardi,
      mesgul: (m) {
        if (mounted) setState(() => _mesgul = m);
      },
      arkaPlan: widget.arkaPlan,
    );
    if (!kaydedildi || !mounted) return;
    final depo = await ref.read(ogrenciFotoDeposuProvider.future);
    final foto = await depo.guncel(o.id!);
    await _yaz(_sira!.kaydedildi(o.id!));
    if (!mounted) return;
    setState(() {
      _elleSecilen = null;
      if (foto != null) _sonKayit = _SonKayit(o, foto, oncekiVardi);
    });
    // Bildirim (SnackBar) YOK: alttaki "Son: … / Geri al" şeridini tam
    // geri alınmak istendiği anda 2 sn örtüyordu (test yakaladı). Şerit
    // ve değişen kimlik kartı geri bildirimin kendisi.
  }

  Future<void> _atla(StudentModel o) async {
    await _yaz(_sira!.atlandi(o.id!));
    if (mounted) setState(() => _elleSecilen = null);
  }

  Future<void> _ogrenciDegistir(List<StudentModel> ogrenciler) async {
    final s = _sira!;
    final adaylar = [...ogrenciler.where((o) => !s.tamamlanan.contains(o.id))]
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));
    final secilen = await showDialog<StudentModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Öğrenciyi seçin'),
        children: [
          for (final o in adaylar)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, o),
              child: Text('${o.schoolNumber}  ${o.firstName} ${o.lastName}'),
            ),
        ],
      ),
    );
    if (secilen != null && mounted) setState(() => _elleSecilen = secilen.id);
  }

  Future<void> _geriAl() async {
    final k = _sonKayit;
    if (k == null || k.oncekiVardi) return;
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Son çekimi geri al'),
        content: Row(
          children: [
            OgrenciFotoKucuk(foto: k.foto, genislik: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${k.ogrenci.schoolNumber} — ${k.ogrenci.firstName} ${k.ogrenci.lastName} '
                  'öğrencisinin az önce kaydedilen fotoğrafı silinecek; öğrenci yeniden sıraya gelecek.'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri al')),
        ],
      ),
    );
    if (evet != true || !mounted) return;
    try {
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      final simdiki = await depo.guncel(k.ogrenci.id!);
      // Arada başka fotoğraf kaydedildiyse (başka ekrandan) dokunma.
      if (simdiki?.id == k.foto.id) await depo.sil(k.ogrenci.id!);
      if (!mounted) return;
      fotolarDegisti(ref);
      await _yaz(_sira!.geriAlindi(k.ogrenci.id!));
      if (mounted) setState(() => _sonKayit = null);
    } catch (e) {
      _mesaj('Geri alınamadı: $e', hata: true);
    }
  }

  Future<void> _bitir() async {
    final id = _oturumId;
    if (id != null) await ref.read(cekimOturumuDeposuProvider).bitir(id);
    if (mounted) Navigator.of(context).pop();
  }

  void _mesaj(String metin, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(metin),
      backgroundColor: hata ? AppColors.danger : null,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ogrenciler = ref.watch(studentListProvider(_sinifId)).valueOrNull ?? const <StudentModel>[];
    final fotolar = ref.watch(sinifFotolariProvider(_sinifId)).valueOrNull ?? const <int, OgrenciFoto>{};
    final s = _sira;
    Widget govde;
    if (_hata != null) {
      govde = Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_hata!)));
    } else if (s == null) {
      govde = const Center(child: CircularProgressIndicator());
    } else {
      final o = _siradakiOgrenci(ogrenciler);
      final sayim = s.sayim({for (final x in ogrenciler) x.id!});
      govde = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text('${sayim.tamam}/${sayim.toplam} çekildi',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (sayim.atlanan > 0) Text(' · ${sayim.atlanan} atlandı'),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: sayim.toplam == 0 ? 0 : sayim.tamam / sayim.toplam,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: o == null ? _bitisGorunumu(s, sayim.atlanan) : _ogrenciGorunumu(o, fotolar[o.id], ogrenciler),
          ),
          if (_sonKayit != null) _sonKayitSeridi(_sonKayit!),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Seri çekim · ${widget.sinif.name}')),
      body: Stack(
        children: [
          SafeArea(child: govde),
          if (_mesgul)
            const ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _ogrenciGorunumu(StudentModel o, OgrenciFoto? mevcut, List<StudentModel> ogrenciler) {
    final kamera = ref.read(fotoAliciProvider).kameraVar;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Öğrenci değişince kart kısa bir geçişle değişir (plan §4.3).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(o.id),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Semantics(
              label: 'Sıradaki öğrenci: ${widget.sinif.name} sınıfı, okul numarası ${o.schoolNumber}, '
                  '${o.firstName} ${o.lastName}',
              child: Column(
                children: [
                  Text('${widget.sinif.name} • ${o.schoolNumber}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${o.firstName} ${o.lastName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  if (mevcut != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OgrenciFotoKucuk(foto: mevcut, genislik: 40),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text('Mevcut fotoğraf değiştirilecek',
                              style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Öğrenciye numarasını ve adını sorun; kartla aynıysa çekin.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (kamera)
          FilledButton.icon(
            onPressed: _mesgul ? null : () => _cek(o, kamera: true),
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Fotoğraf çek')),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _mesgul ? null : () => _cek(o, kamera: false),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Galeriden seç'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _mesgul ? null : () => _atla(o),
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Şimdi atla'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _mesgul ? null : () => _ogrenciDegistir(ogrenciler),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Öğrenciyi değiştir'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bitisGorunumu(CekimSirasi s, int atlanan) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
        const SizedBox(height: 8),
        Text(
          atlanan > 0 ? 'Sıra bitti; $atlanan öğrenci atlandı.' : 'Sıradaki bütün öğrencilerin fotoğrafı çekildi.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (atlanan > 0)
          FilledButton(
            onPressed: () => _yaz(s.atlananlarSiraya()),
            child: const Text('Atlananları çek'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _bitir, child: const Text('Oturumu bitir')),
      ],
    );
  }

  Widget _sonKayitSeridi(_SonKayit k) {
    return Material(
      elevation: 4,
      child: ListTile(
        leading: OgrenciFotoKucuk(foto: k.foto, genislik: 36),
        title: Text('Son: ${k.ogrenci.schoolNumber} ${k.ogrenci.firstName}'),
        subtitle: k.oncekiVardi ? const Text('Önceki fotoğraf geri getirilemez; gerekirse yeniden çekin') : null,
        trailing: TextButton(
          onPressed: k.oncekiVardi || _mesgul ? null : _geriAl,
          child: const Text('Geri al'),
        ),
      ),
    );
  }
}
