import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/idare_duyurusu.dart';

final idareDuyurusuDeposuProvider = Provider<IdareDuyurusuDeposu>((ref) => IdareDuyurusuDeposu());

/// Öğretmenin kayıtlı okullarının, imzası doğrulanmış idare duyuruları.
final idareDuyurulariProvider = FutureProvider.autoDispose<List<IdareDuyurusu>>(
  (ref) => ref.watch(idareDuyurusuDeposuProvider).getir(),
);

/// Özet'in üstünde "İdareden" kartı. Duyuru yoksa hiç yer kaplamaz.
///
/// Telefon bildirimi yok (kullanıcı kararı, 28 Ekim 2026): öğretmen
/// uygulamayı açınca görür, "Tamam" deyince bu telefonda bir daha
/// görmez.
class IdareDuyurusuKarti extends ConsumerStatefulWidget {
  const IdareDuyurusuKarti({super.key});

  @override
  ConsumerState<IdareDuyurusuKarti> createState() => _IdareDuyurusuKartiState();
}

class _IdareDuyurusuKartiState extends ConsumerState<IdareDuyurusuKarti> {
  bool _hepsi = false;
  final Set<String> _acik = {};

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(idareDuyurulariProvider).valueOrNull ?? const [];
    if (liste.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gosterilen = _hepsi ? liste : liste.take(1).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const ValueKey('idare_duyurusu_karti'),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withValues(alpha: isDark ? 0.45 : 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in gosterilen) ...[
              _duyuru(d, isDark),
              if (d != gosterilen.last) Divider(height: 14, color: isDark ? Colors.white12 : Colors.black12),
            ],
            if (liste.length > 1)
              TextButton(
                onPressed: () => setState(() => _hepsi = !_hepsi),
                child: Text(_hepsi ? 'Yalnız sonuncusu' : '${liste.length - 1} duyuru daha'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _duyuru(IdareDuyurusu d, bool isDark) {
    final ikincil = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final birincil = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final acik = _acik.contains(d.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.campaign_rounded, size: 18, color: AppColors.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'İdareden · ${d.okulAdi}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: ikincil),
              ),
            ),
            Text(
              AppDateFormatter.gunAy(d.olusturmaZamani),
              style: AppFonts.outfit(fontSize: 11, color: ikincil),
            ),
            const SizedBox(width: 6),
          ],
        ),
        const SizedBox(height: 6),
        Text(d.baslik, style: AppFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w800, color: birincil)),
        if (d.metin.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => acik ? _acik.remove(d.id) : _acik.add(d.id)),
            child: Text(
              d.metin.trim(),
              maxLines: acik ? null : 4,
              overflow: acik ? null : TextOverflow.ellipsis,
              style: AppFonts.outfit(fontSize: 13, height: 1.4, color: birincil),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: ValueKey('idare_duyurusu_tamam_${d.id}'),
            onPressed: () async {
              await ref.read(idareDuyurusuDeposuProvider).kapat(d.id);
              ref.invalidate(idareDuyurulariProvider);
            },
            child: const Text('Tamam'),
          ),
        ),
      ],
    );
  }
}
