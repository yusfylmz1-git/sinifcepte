import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../data/models/arti_eksi_model.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/arti_eksi_provider.dart';

const _artiRengi = Color(0xFF059669);
const _eksiRengi = Color(0xFFDC2626);

/// Artı-eksi listesi: sınıfın her öğrencisi, dönem boyunca biriken artı ve
/// eksileri ve satırda + / − düğmeleri. Eklendikçe sayılar güncellenir.
///
/// Ders ekranından açılır; eklenen kaydın tarihi o dersin tarihidir.
class ArtiEksiListesiView extends ConsumerStatefulWidget {
  const ArtiEksiListesiView({
    super.key,
    required this.classId,
    required this.baslik,
    required this.tarih,
    required this.ogrenciler,
  });

  final int classId;

  /// Örn. "5-A · Türkçe".
  final String baslik;

  /// Dersin tarihi (`YYYY-MM-DD`): eklenen kaydın tarihi ve gösterilen dönem.
  final String tarih;

  final List<StudentParticipationEvaluation> ogrenciler;

  static Future<void> open(BuildContext context, ClassroomParticipationSession s) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArtiEksiListesiView(
        classId: s.classId,
        baslik: '${s.className} · ${s.subjectName}',
        tarih: s.date,
        ogrenciler: s.evaluations,
      ),
    ));
  }

  @override
  ConsumerState<ArtiEksiListesiView> createState() => _ArtiEksiListesiViewState();
}

class _ArtiEksiListesiViewState extends ConsumerState<ArtiEksiListesiView> {
  bool _tumYil = false;

  DateTime get _gun => DateTime.tryParse(widget.tarih) ?? DateTime.now();

  ArtiEksiSorgu get _sorgu => ArtiEksiSorgu(
        widget.classId,
        _tumYil ? artiEksiYili(_gun) : artiEksiDonemi(_gun),
      );

  Future<void> _ekle(StudentParticipationEvaluation o, int deger) async {
    HapticFeedback.selectionClick();
    final repo = ref.read(artiEksiRepoProvider);
    final messenger = ScaffoldMessenger.of(context);
    // "Geri al" çubuğu liste kapansa da görünmeye devam eder (önceki
    // ekranda); `ref` o an geçersizdir, kapsayıcı geçerli kalır.
    final kapsayici = ProviderScope.containerOf(context, listen: false);
    try {
      final id = await repo.ekle(
        classId: widget.classId,
        studentId: o.studentId,
        deger: deger,
        tarih: widget.tarih,
      );
      ref.invalidate(artiEksiKayitlariProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${o.studentName}: ${deger > 0 ? 'artı' : 'eksi'} eklendi'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () async {
              await repo.sil(id);
              kapsayici.invalidate(artiEksiKayitlariProvider);
            },
          ),
        ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Eklenemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kayitlarA = ref.watch(artiEksiKayitlariProvider(_sorgu));
    final kayitlar = kayitlarA.valueOrNull;
    final ozetler = kayitlar == null ? const <int, ArtiEksiOzeti>{} : artiEksiOzetle(kayitlar);
    final ogrenciler = [...widget.ogrenciler]
      ..sort((a, b) => a.studentNumber.compareTo(b.studentNumber));
    final toplamArti = ozetler.values.fold<int>(0, (t, o) => t + o.arti);
    final toplamEksi = ozetler.values.fold<int>(0, (t, o) => t + o.eksi);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Artı-Eksi Listesi'),
            Text(widget.baslik, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(artiEksiDonemi(_gun).ad)),
                const ButtonSegment(value: true, label: Text('Tüm yıl')),
              ],
              selected: {_tumYil},
              onSelectionChanged: (s) => setState(() => _tumYil = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Toplam: $toplamArti artı · $toplamEksi eksi',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (kayitlarA.hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Liste okunamadı: ${kayitlarA.error}'),
            ),
          Expanded(
            child: kayitlar == null && kayitlarA.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: ogrenciler.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final o = ogrenciler[i];
                      return _Satir(
                        key: ValueKey('arti_eksi_${o.studentId}'),
                        ogrenci: o,
                        ozet: ozetler[o.studentId] ?? ArtiEksiOzeti.bos,
                        onArti: () => _ekle(o, 1),
                        onEksi: () => _ekle(o, -1),
                        onGecmis: () => _gecmisiAc(o),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _gecmisiAc(StudentParticipationEvaluation o) {
    final sorgu = _sorgu;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _Gecmis(ogrenci: o, sorgu: sorgu),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({
    super.key,
    required this.ogrenci,
    required this.ozet,
    required this.onArti,
    required this.onEksi,
    required this.onGecmis,
  });

  final StudentParticipationEvaluation ogrenci;
  final ArtiEksiOzeti ozet;
  final VoidCallback onArti;
  final VoidCallback onEksi;
  final VoidCallback onGecmis;

  @override
  Widget build(BuildContext context) {
    final kucuk = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      onTap: onGecmis,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text('${ogrenci.studentNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ogrenci.studentName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (ozet.son.isEmpty)
                    Text('Henüz yok', style: kucuk)
                  else
                    Text.rich(
                      TextSpan(children: [
                        for (final a in ozet.son)
                          TextSpan(
                            text: a ? '+ ' : '− ',
                            style: TextStyle(
                                color: a ? _artiRengi : _eksiRengi, fontWeight: FontWeight.w800),
                          ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                ],
              ),
            ),
            _Sayi(metin: '+${ozet.arti}', renk: _artiRengi, etiket: '${ozet.arti} artı'),
            _Sayi(metin: '−${ozet.eksi}', renk: _eksiRengi, etiket: '${ozet.eksi} eksi'),
            IconButton(
              tooltip: '${ogrenci.studentName}: eksi ver',
              onPressed: onEksi,
              icon: const Icon(Icons.remove_rounded, color: _eksiRengi),
            ),
            IconButton.filledTonal(
              tooltip: '${ogrenci.studentName}: artı ver',
              onPressed: onArti,
              icon: const Icon(Icons.add_rounded, color: _artiRengi),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sayi extends StatelessWidget {
  const _Sayi({required this.metin, required this.renk, required this.etiket});
  final String metin;
  final Color renk;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiket,
      excludeSemantics: true,
      child: SizedBox(
        width: 34,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            metin,
            style: TextStyle(color: renk, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

/// Bir öğrencinin tarihli kayıtları; yanlış verilen kayıt buradan silinir.
class _Gecmis extends ConsumerWidget {
  const _Gecmis({required this.ogrenci, required this.sorgu});
  final StudentParticipationEvaluation ogrenci;
  final ArtiEksiSorgu sorgu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hepsi = ref.watch(artiEksiKayitlariProvider(sorgu)).valueOrNull ?? const [];
    final kayitlar = hepsi.where((k) => k.studentId == ogrenci.studentId).toList().reversed.toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${ogrenci.studentNumber} · ${ogrenci.studentName} — ${sorgu.aralik.ad}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (kayitlar.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Bu aralıkta kayıt yok.', textAlign: TextAlign.center),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final k in kayitlar)
                      ListTile(
                        key: ValueKey('gecmis_${k.id}'),
                        dense: true,
                        leading: Text(
                          k.artiMi ? '+' : '−',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: k.artiMi ? _artiRengi : _eksiRengi,
                          ),
                        ),
                        title: Text(_tarihMetni(k.tarih)),
                        trailing: IconButton(
                          tooltip: 'Bu kaydı sil',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            await ref.read(artiEksiRepoProvider).sil(k.id);
                            ref.invalidate(artiEksiKayitlariProvider);
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _tarihMetni(String tarih) {
    final d = DateTime.tryParse(tarih);
    return d == null ? tarih : AppDateFormatter.gunAyYilGun(d);
  }
}
