import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_model.dart';
import '../../classes/providers/class_provider.dart';
import '../data/ogrenci_foto_deposu.dart';
import '../domain/foto_isleme.dart';
import '../providers/ogrenci_foto_providers.dart';
import 'disa_aktarim_ekrani.dart';
import 'sinif_foto_ekrani.dart';

/// e-Okul foto — giriş ekranı (menü > İdari işlemler > e-Okul foto).
///
/// Bütün sınıflar kart olarak: "28/32 hazır" + ilerleme çubuğu. Durum
/// yalnızca renkle değil sayı ve metinle anlatılır (plan §4.1).
class EokulFotoMerkeziEkrani extends ConsumerStatefulWidget {
  const EokulFotoMerkeziEkrani({super.key});

  @override
  ConsumerState<EokulFotoMerkeziEkrani> createState() => _EokulFotoMerkeziEkraniState();
}

class _EokulFotoMerkeziEkraniState extends ConsumerState<EokulFotoMerkeziEkrani> {
  @override
  void initState() {
    super.initState();
    // Disk ile kayıtları uzlaştır (plan §9.3: açılışta değil, gerektiğinde).
    WidgetsBinding.instance.addPostFrameCallback((_) => _uzlastir());
  }

  Future<void> _uzlastir() async {
    try {
      final depo = await ref.read(ogrenciFotoDeposuProvider.future);
      final s = await depo.uzlastir();
      await depo.temizle();
      if (!mounted) return;
      if (s.eksikIsaretlenen + s.geriGelen > 0) fotolarDegisti(ref);
    } catch (e) {
      debugPrint('e-Okul foto uzlaştırma: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final siniflarA = ref.watch(classListProvider);
    final ozetler = ref.watch(sinifFotoOzetleriProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('e-Okul foto'),
        actions: [
          IconButton(
            tooltip: 'Dışa aktar (ZIP, PDF albüm, kontrol listesi)',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DisaAktarimEkrani()),
            ),
          ),
        ],
      ),
      body: siniflarA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Sınıflar yüklenemedi: $e')),
        data: (siniflar) {
          final sirali = [...siniflar]..sort((a, b) {
              if (a.isHomeroom != b.isHomeroom) return a.isHomeroom ? -1 : 1;
              return a.name.compareTo(b.name);
            });
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _BilgiKarti(),
              const SizedBox(height: 12),
              if (sirali.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Henüz sınıf yok. Önce Sınıflarım ekranından sınıf ve öğrenci ekleyin.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final s in sirali)
                _SinifKarti(sinif: s, ozet: ozetler[s.id] ?? SinifFotoOzeti.bos),
            ],
          );
        },
      ),
    );
  }
}

class _BilgiKarti extends StatelessWidget {
  const _BilgiKarti();

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.badge_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('e-Okul öğrenci fotoğrafı',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Her fotoğraf tam $eokulGenislik×$eokulYukseklik piksel üretilir. '
              'Paylaşırken dosya adı okul numarası ve ad-soyaddır '
              '(ör. 1234_Ayşe_YILMAZ.jpg).',
              style: stil,
            ),
            const SizedBox(height: 6),
            Text(
              'Fotoğraflar yalnızca bu cihazda, uygulamanın kendi alanında saklanır; '
              'galeride görünmez, hiçbir yere gönderilmez.',
              style: stil,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Veri yedeği fotoğrafları henüz içermiyor. Telefon değişmeden önce '
                    'fotoğrafları paylaşıp saklayın.',
                    style: stil,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SinifKarti extends StatelessWidget {
  const _SinifKarti({required this.sinif, required this.ozet});
  final ClassModel sinif;
  final SinifFotoOzeti ozet;

  @override
  Widget build(BuildContext context) {
    final hazir = ozet.kullanilabilir;
    final ayrinti = <String>[
      if (ozet.eksik > 0) '${ozet.eksik} fotoğrafsız',
      if (ozet.inceleme > 0) '${ozet.inceleme} uyarılı',
      if (ozet.dosyaYok > 0) '${ozet.dosyaYok} dosya kayıp',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SinifFotoEkrani(sinif: sinif)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sinif.isHomeroom ? '${sinif.name} · rehberlik sınıfım' : sinif.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('$hazir/${ozet.toplam} hazır',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              Text('${sinif.subject} · ${sinif.academicYear}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ozet.toplam == 0 ? 0 : hazir / ozet.toplam,
                  minHeight: 6,
                  color: AppColors.success,
                ),
              ),
              if (ozet.toplam == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Öğrenci yok', style: Theme.of(context).textTheme.bodySmall),
                )
              else if (ayrinti.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(ayrinti.join(' · '), style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
