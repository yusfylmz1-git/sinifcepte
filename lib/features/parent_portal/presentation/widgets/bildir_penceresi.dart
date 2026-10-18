import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/support/support_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../data/moderasyon.dart';
import '../../providers/moderasyon_provider.dart';

/// Bildirilebilecek bir içerik (mesaj ya da duyuru).
class BildirimAdayi {
  final String kimlik;
  final String metin;

  /// Metnin üstünde gösterilen kısa bilgi (mesaj zamanı, duyuru başlığı).
  final String ust;

  const BildirimAdayi({required this.kimlik, required this.metin, this.ust = ''});
}

/// Pencerede yapılan seçim.
class BildirimSecimi {
  final BildirimAdayi aday;
  final BildirimNedeni neden;
  final String not;

  const BildirimSecimi({required this.aday, required this.neden, required this.not});
}

/// "Bildir" penceresi: hangi içerik, neden, isteğe bağlı not (18 Ekim 2026).
///
/// [adaylar] birden çoksa (sohbet menüsünden) kullanıcı mesajı seçer;
/// basılı tutulan mesajdan açılınca [seciliKimlik] hazır gelir.
Future<BildirimSecimi?> bildirimSec(
  BuildContext context, {
  required List<BildirimAdayi> adaylar,
  String? seciliKimlik,
  required String kime,
}) {
  return showModalBottomSheet<BildirimSecimi>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BildirimFormu(adaylar: adaylar, seciliKimlik: seciliKimlik, kime: kime),
  );
}

/// Bildirimi buluta yazar ve sonucu söyler.
///
/// Yazılamazsa "gönderildi" denmez: destek e-postası gösterilir.
Future<bool> bildirimGonder(BuildContext context, WidgetRef ref, IcerikBildirimi bildirim) async {
  final ok = await ref.read(moderasyonDeposuProvider).bildir(bildirim);
  if (!context.mounted) return ok;
  if (ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildiriminiz SınıfCepte ekibine iletildi. Teşekkürler.'),
        duration: Duration(seconds: 4),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirim gönderilemedi'),
        content: const Text(
          'İnternet bağlantınızı kontrol edip tekrar deneyin. Sorun sürerse '
          '${SupportRepository.supportEmail} adresine yazabilirsiniz.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }
  return ok;
}

class _BildirimFormu extends StatefulWidget {
  final List<BildirimAdayi> adaylar;
  final String? seciliKimlik;
  final String kime;

  const _BildirimFormu({required this.adaylar, required this.seciliKimlik, required this.kime});

  @override
  State<_BildirimFormu> createState() => _BildirimFormuState();
}

class _BildirimFormuState extends State<_BildirimFormu> {
  late String? _secili =
      widget.seciliKimlik ?? (widget.adaylar.length == 1 ? widget.adaylar.single.kimlik : null);
  BildirimNedeni? _neden;
  final _not = TextEditingController();

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  BildirimAdayi? get _aday => widget.adaylar.where((a) => a.kimlik == _secili).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ikincil = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final tekAday = widget.seciliKimlik != null || widget.adaylar.length == 1;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            children: [
              Text('Bildir', style: AppFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('${widget.kime} hakkında', style: AppFonts.outfit(fontSize: 12.5, color: ikincil)),
              const SizedBox(height: 14),
              _baslik(tekAday ? 'Bildirilen içerik' : 'Hangi mesajı bildiriyorsunuz?'),
              if (tekAday && _aday != null)
                _alinti(isDark, _aday!)
              else
                for (final a in widget.adaylar) _adaySatiri(isDark, a),
              const SizedBox(height: 12),
              _baslik('Neden?'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in BildirimNedeni.values)
                    ChoiceChip(
                      key: ValueKey('bildir_neden_${n.id}'),
                      label: Text(n.ad),
                      selected: _neden == n,
                      onSelected: (_) => setState(() => _neden = n),
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: AppFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _neden == n ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('bildir_not'),
                controller: _not,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
              ),
              Text(
                'Seçtiğiniz içeriğin metni incelenmek üzere SınıfCepte ekibine gönderilir. '
                'Karşı tarafa haber verilmez.',
                style: AppFonts.outfit(fontSize: 11.5, height: 1.45, color: ikincil),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('bildir_gonder'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: _aday == null || _neden == null
                          ? null
                          : () => Navigator.pop(
                                context,
                                BildirimSecimi(aday: _aday!, neden: _neden!, not: _not.text.trim()),
                              ),
                      child: const Text('Bildir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baslik(String metin) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(metin, style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _alinti(bool isDark, BildirimAdayi a) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (a.ust.isNotEmpty)
              Text(a.ust, style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700)),
            Text(a.metin, maxLines: 6, overflow: TextOverflow.ellipsis, style: AppFonts.outfit(fontSize: 12.5)),
          ],
        ),
      );

  Widget _adaySatiri(bool isDark, BildirimAdayi a) {
    final secili = _secili == a.kimlik;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: secili
            ? AppColors.primary.withValues(alpha: 0.10)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('bildir_aday_${a.kimlik}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _secili = a.kimlik),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  secili ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: secili ? AppColors.primary : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (a.ust.isNotEmpty)
                        Text(a.ust, style: AppFonts.outfit(fontSize: 11, color: Colors.grey)),
                      Text(a.metin, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppFonts.outfit(fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
