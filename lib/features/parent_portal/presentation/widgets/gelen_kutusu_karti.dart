import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../providers/gelen_kutusu_provider.dart';
import '../screens/gelen_kutusu_ekrani.dart';

/// Bugün'deki "Veli gelen kutusu" kartı: okunmamış mesaj, bekleyen
/// randevu ve görülmemiş veli bildirimi sayısı (18 Ekim 2026).
///
/// Google girişi yoksa (masaüstü yerel kip) hiç görünmez.
class GelenKutusuKarti extends ConsumerWidget {
  final bool isDark;

  const GelenKutusuKarti({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gelenKutusuProvider);
    final d = async.valueOrNull;
    if (d != null && !d.bulutVar) return const SizedBox.shrink();

    final parcalar = <String>[
      if (d != null && d.okunmamisMesaj > 0) '${d.okunmamisMesaj} okunmamış mesaj',
      if (d != null && d.randevular.isNotEmpty) '${d.randevular.length} randevu talebi',
      if (d != null && d.bildirimler.isNotEmpty) '${d.bildirimler.length} veli bildirimi',
    ];
    final ozet = d == null
        ? (async.hasError ? 'Okunamadı; dokunup yeniden deneyin' : 'Yükleniyor…')
        : (parcalar.isEmpty ? 'Yeni bir şey yok' : parcalar.join(' · '));
    final rozet = d?.rozet ?? 0;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('bugun_gelen_kutusu'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => GelenKutusuEkrani.ac(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rozet > 0
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inbox_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Veli gelen kutusu',
                      style: AppFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      ozet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.outfit(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (rozet > 0)
                Container(
                  key: const ValueKey('bugun_gelen_kutusu_rozet'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$rozet',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
