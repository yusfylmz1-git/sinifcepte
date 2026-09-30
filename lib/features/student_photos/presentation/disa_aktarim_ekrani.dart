import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../shared/screens/pdf_preview_screen.dart';
import '../data/foto_albumu_pdf.dart';
import '../data/foto_disa_aktarici.dart';
import '../domain/disa_aktarim_plani.dart';
import '../providers/ogrenci_foto_providers.dart';
import 'widgets/ogrenci_foto_kucuk.dart';

/// Son kullanılan albüm ayarları (oturum boyunca).
final albumAyarlariProvider = StateProvider<AlbumAyarlari>((ref) => const AlbumAyarlari());

/// Dışa aktarma — önce fotoğraflı eşleştirme önizlemesi (plan §10.1).
///
/// Düğmeye basınca dosya hemen üretilmez: her satırda fotoğraf, sınıf,
/// okul numarası, ad-soyad ve ÜRETİLECEK DOSYA ADI görünür. Kimliği
/// çekimden sonra değişmiş, numarası çakışan ya da adı eksik öğrenci
/// varsa paket ve albüm üretilmez; kontrol listesi her zaman alınabilir.
class DisaAktarimEkrani extends ConsumerStatefulWidget {
  const DisaAktarimEkrani({super.key, this.baslangicSinifId});

  /// Sınıf ekranından gelindiyse o sınıf seçili başlar; yoksa hepsi.
  final int? baslangicSinifId;

  @override
  ConsumerState<DisaAktarimEkrani> createState() => _DisaAktarimEkraniState();
}

class _DisaAktarimEkraniState extends ConsumerState<DisaAktarimEkrani> {
  Set<int>? _secili;
  List<ClassModel> _siniflar = const [];
  DisaAktarimPlani? _plan;
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _planiKur());
  }

  Future<void> _planiKur() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      // Sınıflar sağlayıcıdan değil veritabanından: ekran sağlayıcı
      // yüklenmeden açılırsa liste boş görünüp "öğrenci yok" demesin.
      final siniflar = await ClassRepository().getAllClasses()
        ..sort((a, b) => a.name.compareTo(b.name));
      _siniflar = siniflar;
      _secili ??= widget.baslangicSinifId != null
          ? {widget.baslangicSinifId!}
          : siniflar.map((s) => s.id!).toSet();
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      final repo = StudentRepository();
      final secilen = <(ClassModel, List<StudentModel>)>[];
      for (final s in siniflar.where((s) => _secili!.contains(s.id))) {
        secilen.add((s, await repo.getStudentsByClassId(s.id!)));
      }
      final idler = [for (final (_, o) in secilen) ...o.map((e) => e.id!)];
      final fotolar = await depo.guncelFotolar(idler);
      final dosyaVar = <String, bool>{
        for (final f in fotolar.values) f.id: await depo.depolama.dosya(f.standardPath).exists(),
      };
      final plan = disaAktarimPlanla(
        siniflar: secilen,
        fotolar: fotolar,
        zaman: DateTime.now(),
        dosyaVar: (f) => dosyaVar[f.id] ?? false,
      );
      if (!mounted) return;
      setState(() => _plan = plan);
    } catch (e) {
      if (mounted) setState(() => _hata = 'Liste hazırlanamadı: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Dışa aktar')),
      body: Column(
        children: [
          _sinifSecimi(),
          if (plan != null) _OzetKarti(plan: plan),
          Expanded(
            child: _hata != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_hata!)))
                : (plan == null || _yukleniyor)
                    ? const Center(child: CircularProgressIndicator())
                    : _liste(plan),
          ),
        ],
      ),
      bottomNavigationBar: plan == null ? null : _eylemler(plan),
    );
  }

  Widget _sinifSecimi() {
    final siniflar = _siniflar;
    if (siniflar.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final s in siniflar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(s.name),
                selected: _secili?.contains(s.id) ?? false,
                onSelected: _yukleniyor
                    ? null
                    : (v) {
                        setState(() => v ? _secili!.add(s.id!) : _secili!.remove(s.id));
                        _planiKur();
                      },
              ),
            ),
        ],
      ),
    );
  }

  Widget _liste(DisaAktarimPlani plan) {
    if (plan.kalemler.isEmpty) {
      return const Center(child: Text('Seçili sınıflarda öğrenci yok.'));
    }
    final satirlar = <Widget>[];
    int? oncekiSinif;
    for (final k in plan.kalemler) {
      if (k.sinif.id != oncekiSinif) {
        oncekiSinif = k.sinif.id;
        satirlar.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text('${k.sinif.name}  →  klasör: ${k.klasor}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ));
      }
      satirlar.add(ListTile(
        key: ValueKey('aktarim_${k.ogrenci.id}'),
        dense: true,
        leading: OgrenciFotoKucuk(foto: k.durum == AktarimDurumu.tamam ? k.foto : null, genislik: 36),
        title: Text('${k.ogrenci.schoolNumber}  ${k.adSoyad}'),
        subtitle: Text(
          k.durum == AktarimDurumu.tamam ? k.dosyaAdi : k.durum.metin,
          style: TextStyle(
            color: k.durum.engeller
                ? AppColors.danger
                : k.durum == AktarimDurumu.tamam
                    ? null
                    : AppColors.warning,
          ),
        ),
        trailing: Icon(
          k.durum == AktarimDurumu.tamam
              ? Icons.check_circle_rounded
              : k.durum.engeller
                  ? Icons.error_rounded
                  : Icons.remove_circle_outline_rounded,
          color: k.durum == AktarimDurumu.tamam
              ? AppColors.success
              : k.durum.engeller
                  ? AppColors.danger
                  : AppColors.warning,
          semanticLabel: k.durum.metin,
        ),
        onTap: k.durum == AktarimDurumu.tamam ? null : () => _sorunuAc(k),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: satirlar);
  }

  Future<void> _sorunuAc(AktarimKalemi k) async {
    if (k.durum == AktarimDurumu.kimlikFarkli) {
      await _kimlikOnayi(k);
      return;
    }
    final metin = switch (k.durum) {
      AktarimDurumu.numaraCakismasi =>
        'Bu sınıfta ${k.ogrenci.schoolNumber} numarası birden fazla öğrencide. '
            'Sınıflarım ekranından numaraları düzeltin.',
      AktarimDurumu.adEksik => 'Öğrencinin adı ya da soyadı boş. Sınıflarım ekranından tamamlayın.',
      AktarimDurumu.dosyaKayip =>
        'Fotoğraf kaydı var ama dosyası bu cihazda yok. e-Okul foto ekranından yeniden seçin.',
      _ => 'Bu öğrencinin fotoğrafı yok; pakete girmez, eksikler listesinde yazar.',
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${k.ogrenci.schoolNumber} — ${k.adSoyad}'),
        content: Text(metin),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }

  Future<void> _kimlikOnayi(AktarimKalemi k) async {
    final f = k.foto!;
    DateTime? onay;
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Kimlik kontrolü'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OgrenciFotoKucuk(foto: f, genislik: 60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Çekimde: ${f.capturedSchoolNumber} — ${f.capturedFullName}'),
                        const SizedBox(height: 4),
                        Text('Şimdi: ${k.ogrenci.schoolNumber} — ${k.adSoyad}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Öğrencinin bilgisi fotoğraf çekildikten sonra değişmiş. Fotoğraf başka '
                'bir öğrenciye aitse onaylamayın; e-Okul foto ekranından doğru öğrenciye aktarın.',
                style: TextStyle(fontSize: 12),
              ),
              CheckboxListTile(
                value: onay != null,
                onChanged: (v) => setD(() => onay = (v ?? false) ? DateTime.now() : null),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text('Fotoğraf ${k.ogrenci.schoolNumber} — ${k.adSoyad} öğrencisine ait'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: onay == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ),
    );
    if (tamam != true || onay == null || !mounted) return;
    try {
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      await depo.kimligiYenidenOnayla(
        ogrenciId: k.ogrenci.id!,
        beklenenFotoId: f.id,
        kimlikOnaylandi: onay!,
      );
      if (!mounted) return;
      fotolarDegisti(ref);
      await _planiKur();
    } catch (e) {
      _mesaj('Onaylanamadı: $e', hata: true);
    }
  }

  Widget _eylemler(DisaAktarimPlani plan) {
    final neden = plan.engelNedeni;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (neden != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(neden,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: plan.uretilebilir && !_yukleniyor ? () => _zipUret(plan) : null,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: const Text('ZIP paketi'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: plan.uretilebilir && !_yukleniyor ? () => _albumAc(plan) : null,
                    icon: const Icon(Icons.photo_album_outlined),
                    label: const Text('PDF albüm'),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _yukleniyor || plan.kalemler.isEmpty ? null : () => _kontrolListesiAc(plan),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Fotoğraflı kontrol listesi (PDF)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _zipUret(DisaAktarimPlani plan) async {
    final depo = await ref.read(ogrenciFotoDeposuProvider.future);
    final aktarici = FotoDisaAktarici(depo.depolama);
    final ilerleme = ValueNotifier<(int, int)>((0, plan.aktarilacak.length));
    var iptal = false;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Paket hazırlanıyor'),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: ilerleme,
          builder: (_, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v.$2 == 0 ? null : v.$1 / v.$2),
              const SizedBox(height: 8),
              Text('${v.$1}/${v.$2} fotoğraf'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => iptal = true, child: const Text('İptal'))],
      ),
    );

    DisaAktarimSonucu? sonuc;
    String? hata;
    try {
      final bayt = await aktarici.fotolariOku(plan);
      final kontrol = await kontrolListesiPdfUret(plan: plan, fotoBaytlari: bayt, zaman: DateTime.now());
      final hedef = await _paketDizini();
      sonuc = await aktarici.zipUret(
        plan: plan,
        hedefDizin: hedef,
        kontrolPdf: kontrol,
        iptalMi: () => iptal,
        ilerleme: (a, b) => ilerleme.value = (a, b),
      );
    } on DisaAktarimIptal {
      hata = null;
    } catch (e) {
      hata = e is DisaAktarimHatasi ? e.mesaj : 'Paket hazırlanamadı: $e';
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ilerleme.dispose();
    if (sonuc == null) {
      _mesaj(hata ?? 'İptal edildi.', hata: hata != null);
      return;
    }
    await _sonucuGoster(sonuc);
  }

  Future<void> _sonucuGoster(DisaAktarimSonucu s) async {
    final paylas = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tamMi ? 'Paket hazırlandı' : 'Paket kısmen hazırlandı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.tamMi
                  ? '${s.eklenenFoto} fotoğraf pakete girdi ve doğrulandı.'
                  : '${s.eklenenFoto}/${s.beklenenFoto} fotoğraf pakete girdi. Eklenemeyenler:'),
              for (final h in s.hatalar)
                Text('• $h', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              const SizedBox(height: 10),
              const Text(
                'Kontrol listeleri paketin içinde ayrı klasörde (Kontrol_Listeleri); '
                'e-Okul\'a yalnızca sınıf klasörlerindeki fotoğrafları yükleyin.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              const Text(
                'ZIP şifreli değildir. Paylaştığınız kopya uygulamanın denetiminden çıkar.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kapat')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Paylaş / kaydet'),
          ),
        ],
      ),
    );
    if (paylas != true) return;
    try {
      final r = await SharePlus.instance.share(ShareParams(
        files: [XFile(s.zip.path, mimeType: 'application/zip')],
        subject: p.basename(s.zip.path),
      ));
      // Paylaşım penceresinin açılması teslim kanıtı değil (plan §13).
      _mesaj(r.status == ShareResultStatus.success
          ? 'Paylaşım başlatıldı.'
          : 'Paylaşım tamamlanmadı; paket yeniden paylaşılabilir.');
    } catch (e) {
      _mesaj('Paylaşılamadı: $e', hata: true);
    }
  }

  /// Geçici paket klasörü; bir saatten eski paketler silinir.
  static Future<Directory> _paketDizini() async {
    final gecici = await getTemporaryDirectory();
    final kok = Directory(p.join(gecici.path, 'eokul_foto_paket'));
    if (await kok.exists()) {
      final simdi = DateTime.now();
      await for (final e in kok.list(followLinks: false)) {
        try {
          if (simdi.difference((await e.stat()).modified) > const Duration(hours: 1)) {
            await e.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
    return Directory(p.join(kok.path, '${DateTime.now().microsecondsSinceEpoch}'));
  }

  Future<void> _albumAc(DisaAktarimPlani plan) async {
    final ayar = await showModalBottomSheet<AlbumAyarlari>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AlbumAyarSayfasi(baslangic: ref.read(albumAyarlariProvider)),
    );
    if (ayar == null || !mounted) return;
    ref.read(albumAyarlariProvider.notifier).state = ayar;
    final depo = await ref.read(ogrenciFotoDeposuProvider.future);
    final bayt = await FotoDisaAktarici(depo.depolama).fotolariOku(plan);
    if (!mounted) return;
    await PdfPreviewScreen.open(
      context,
      title: 'Fotoğraf albümü',
      subtitle: '${plan.aktarilacak.length} fotoğraf',
      fileName: '${plan.paketAdi}_album.pdf',
      documentBuilder: (_) => albumPdfUret(plan: plan, fotoBaytlari: bayt, ayarlar: ayar),
    );
  }

  Future<void> _kontrolListesiAc(DisaAktarimPlani plan) async {
    final depo = await ref.read(ogrenciFotoDeposuProvider.future);
    final bayt = await FotoDisaAktarici(depo.depolama).fotolariOku(plan);
    if (!mounted) return;
    await PdfPreviewScreen.open(
      context,
      title: 'Fotoğraf kontrol listesi',
      fileName: '${plan.paketAdi}_kontrol_listesi.pdf',
      documentBuilder: (_) => kontrolListesiPdfUret(plan: plan, fotoBaytlari: bayt, zaman: DateTime.now()),
    );
  }

  void _mesaj(String metin, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(metin), backgroundColor: hata ? AppColors.danger : null),
    );
  }
}

class _OzetKarti extends StatelessWidget {
  const _OzetKarti({required this.plan});
  final DisaAktarimPlani plan;

  @override
  Widget build(BuildContext context) {
    final parcalar = [
      '${plan.aktarilacak.length} fotoğraf pakete girecek',
      if (plan.eksikler.isNotEmpty) '${plan.eksikler.length} eksik',
      if (plan.engelleyenler.isNotEmpty) '${plan.engelleyenler.length} sorunlu',
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (plan.engelleyenler.isEmpty ? AppColors.success : AppColors.danger).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(parcalar.join(' · '), style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// Albüm ayarları. Ayar değiştikçe yerleşim özeti güncellenir.
class _AlbumAyarSayfasi extends StatefulWidget {
  const _AlbumAyarSayfasi({required this.baslangic});
  final AlbumAyarlari baslangic;

  @override
  State<_AlbumAyarSayfasi> createState() => _AlbumAyarSayfasiState();
}

class _AlbumAyarSayfasiState extends State<_AlbumAyarSayfasi> {
  late AlbumAyarlari _a = widget.baslangic;

  static String _olcekAdi(AlbumOlcegi o) => switch (o) {
        AlbumOlcegi.kucuk => 'Küçük',
        AlbumOlcegi.normal => 'Normal',
        AlbumOlcegi.buyuk => 'Büyük',
      };

  @override
  Widget build(BuildContext context) {
    final y = AlbumYerlesimi.hesapla(_a);
    final kucukStil = Theme.of(context).textTheme.bodySmall;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Albüm ayarları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2 sütun')),
                ButtonSegment(value: 3, label: Text('3 sütun')),
                ButtonSegment(value: 4, label: Text('4 sütun')),
              ],
              selected: {_a.sutun},
              onSelectionChanged: (s) => setState(() => _a = _a.kopya(sutun: s.first)),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AlbumOlcegi>(
              segments: [
                for (final o in AlbumOlcegi.values) ButtonSegment(value: o, label: Text(_olcekAdi(o))),
              ],
              selected: {_a.olcek},
              onSelectionChanged: (s) => setState(() => _a = _a.kopya(olcek: s.first)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AlbumSirasi>(
              initialValue: _a.sira,
              decoration: const InputDecoration(labelText: 'Sıralama', border: OutlineInputBorder()),
              items: [
                for (final s in AlbumSirasi.values) DropdownMenuItem(value: s, child: Text(s.metin)),
              ],
              onChanged: (s) => setState(() => _a = _a.kopya(sira: s)),
            ),
            SwitchListTile(
              value: _a.adSoyad,
              onChanged: (v) => setState(() => _a = _a.kopya(adSoyad: v)),
              title: const Text('Ad-soyad'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _a.okulNo,
              onChanged: (v) => setState(() => _a = _a.kopya(okulNo: v)),
              title: const Text('Okul numarası'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _a.siraNo,
              onChanged: (v) => setState(() => _a = _a.kopya(siraNo: v)),
              title: const Text('Sıra numarası'),
              subtitle: const Text('Albümdeki konum (1, 2, 3…); okul numarası değildir'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _a.sinif,
              onChanged: (v) => setState(() => _a = _a.kopya(sinif: v)),
              title: const Text('Sınıf'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _a.cekimTarihi,
              onChanged: (v) => setState(() => _a = _a.kopya(cekimTarihi: v)),
              title: const Text('Çekim tarihi'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _a.fotografsizlar,
              onChanged: (v) => setState(() => _a = _a.kopya(fotografsizlar: v)),
              title: const Text('Fotoğrafı olmayanları "Fotoğraf yok" kartıyla göster'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _a.yatay,
              onChanged: (v) => setState(() => _a = _a.kopya(yatay: v)),
              title: const Text('Yatay sayfa'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),
            Text(
              '${_a.sutun} sütun · sayfada ${y.sayfadaOgrenci(_a.sutun)} öğrenci',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (y.olcekDusuruldu)
              Text(
                'Seçilen ölçek sayfaya sığmıyor; ${_olcekAdi(y.olcek)} ölçek kullanılacak.',
                style: const TextStyle(color: AppColors.warning),
              ),
            if (_a.kimliksiz)
              const Text(
                'Numara ve ad kapalı: bu yalnız görsel albümdür, kimlik eşleştirme belgesi yerine geçmez.',
                style: TextStyle(color: AppColors.danger),
              ),
            Text(
              'Fotoğraflar 133×171 piksel; büyük ölçekte baskıda yumuşak görünebilir.',
              style: kucukStil,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, _a),
              child: const Text('Albümü oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
