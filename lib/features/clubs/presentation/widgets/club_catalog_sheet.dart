import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../data/models/club_model.dart';
import '../../providers/club_provider.dart';
import '../screens/clubs_hub_screen.dart' show temaIkonu, temaRengi;

/// EK-4 çizelgesinden kulüp seçme sayfası.
///
/// ## Neden arama var
/// Çizelgede 52 kulüp var; kaydırarak aramak yorucu. Arama Türkçe
/// karakterleri normalleştirir: "cevre" yazınca "Çevre Koruma Kulübü"
/// bulunur — öğretmen İngilizce klavyeyle de arayabilsin diye.
///
/// ## Çizelge dışı kulüp
/// Yönetmelik MADDE 8/1 öğretmenler kurulu kararıyla farklı kulüp
/// kurulmasına izin verir. Listenin en altındaki seçenek bunun için.
class ClubCatalogSheet extends ConsumerStatefulWidget {
  const ClubCatalogSheet({super.key, this.kaydirma});

  /// DraggableScrollableSheet'in kaydirma denetleyicisi.
  final ScrollController? kaydirma;

  /// Sayfayi acar.
  ///
  /// `ResponsiveBottomSheet` KULLANILMIYOR: o yardimci icerigi
  /// `SingleChildScrollView` icine koyuyor, yani sinirsiz yukseklik
  /// veriyor. Icerideki `Expanded` orada sifir yukseklik alir ve liste
  /// hic cizilmez. `DraggableScrollableSheet` kendi yuksekligini bilir.
  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, kaydirma) => ClubCatalogSheet(kaydirma: kaydirma),
      ),
    );
  }

  @override
  ConsumerState<ClubCatalogSheet> createState() => _ClubCatalogSheetState();
}

class _ClubCatalogSheetState extends ConsumerState<ClubCatalogSheet> {
  final _aramaKontrol = TextEditingController();
  String _arama = '';

  @override
  void dispose() {
    _aramaKontrol.dispose();
    super.dispose();
  }

  /// Aramada karşılaştırma için sadeleştirir.
  ///
  /// Türkçe "İ" ve "ı" tuzağı: `toLowerCase()` bunları doğru
  /// çevirmediği için harf harf eşleniyor.
  String _sade(String s) {
    const cevrim = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
      'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'I': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
    };
    final b = StringBuffer();
    for (final h in s.split('')) {
      b.write(cevrim[h] ?? h.toLowerCase());
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final katalog = ref.watch(clubCatalogProvider);
    final kurulu = ref.watch(clubListProvider).value ?? const <ClubModel>[];
    final kuruluKodlar = {
      for (final k in kurulu)
        if (k.catalogCode.isNotEmpty) k.catalogCode
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kulüp Kur',
                style: AppFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'MEB Öğrenci Kulüpleri Çizelgesi (EK-4) — 52 kulüp',
                style: AppFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aramaKontrol,
                onChanged: (v) => setState(() => _arama = v),
                style: AppFonts.outfit(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Kulüp ara…',
                  hintStyle: AppFonts.outfit(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: katalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kulüp çizelgesi okunamadı.\nKendi kulübünüzü elle '
                  'kurabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: AppFonts.outfit(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
            data: (liste) {
              final suzulmus = _arama.trim().isEmpty
                  ? liste
                  : liste
                      .where((k) => _sade(k.ad).contains(_sade(_arama.trim())))
                      .toList();

              return ListView.separated(
                controller: widget.kaydirma,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: suzulmus.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == suzulmus.length) {
                    return _ozelKulupKarti(isDark);
                  }
                  final k = suzulmus[i];
                  return _katalogKarti(
                    isDark,
                    k,
                    zatenKurulu: kuruluKodlar.contains(k.kod),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _katalogKarti(
    bool isDark,
    ClubCatalogItem k, {
    required bool zatenKurulu,
  }) {
    final renk = temaRengi(k.tema);

    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: zatenKurulu ? null : () => _kur(k),
        child: Opacity(
          opacity: zatenKurulu ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(temaIkonu(k.tema), color: renk, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.ad,
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        zatenKurulu
                            ? 'Bu yıl zaten kurulu'
                            : 'EK-4 sıra ${k.no} · hazır yıllık plan',
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  zatenKurulu
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: zatenKurulu ? AppColors.success : renk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Çizelge dışı kulüp (MADDE 8/1).
  Widget _ozelKulupKarti(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _ozelKulupSor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    color: AppColors.primary, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Çizelge dışı kulüp kur',
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Öğretmenler kurulu kararıyla açılan kulüp',
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
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

  Future<void> _kur(ClubCatalogItem k) async {
    await ref.read(clubListProvider.notifier).katalogdanKur(k);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${k.ad} kuruldu.')),
    );
  }

  Future<void> _ozelKulupSor() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kontrol = TextEditingController();

    final ad = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCardBackground : Colors.white,
        title: Text(
          'Kulüp Adı',
          style: AppFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: TextField(
          controller: kontrol,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: AppFonts.outfit(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Örn. Robotik Kulübü',
            hintStyle: AppFonts.outfit(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Vazgeç',
              style: AppFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(kontrol.text.trim()),
            child: Text(
              'Kur',
              style: AppFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    kontrol.dispose();
    if (ad == null) return;

    // Kulup adi serbest metin; yalnizca bosluk sadelestirilir.
    final temiz = ad.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (temiz.isEmpty) return;

    await ref.read(clubListProvider.notifier).ozelKulupKur(temiz);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$temiz kuruldu.')),
    );
  }
}
