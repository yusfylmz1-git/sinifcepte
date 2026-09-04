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

  /// DraggableScrollableSheet'in kaydırma denetleyicisi.
  final ScrollController? kaydirma;

  /// Sayfayı açar.
  ///
  /// `ResponsiveBottomSheet` KULLANILMIYOR: o yardımcı içeriği
  /// `SingleChildScrollView` içine koyuyor, yani sınırsız yükseklik
  /// veriyor. İçerideki `Expanded` orada sıfır yükseklik alır ve liste
  /// hiç çizilmez. `DraggableScrollableSheet` kendi yüksekliğini bilir.
  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, kaydirma) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ClubCatalogSheet(kaydirma: kaydirma),
        ),
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
      children: [
        _tutamak(isDark),
        _baslik(isDark),
        _arayici(isDark),
        Expanded(
          child: katalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _bilgi(
              isDark,
              Icons.error_outline_rounded,
              'Kulüp çizelgesi okunamadı',
              'Kendi kulübünüzü elle kurabilirsiniz.',
              dugme: _ozelKulupSor,
            ),
            data: (liste) {
              final suzulmus = _arama.trim().isEmpty
                  ? liste
                  : liste
                      .where((k) => _sade(k.ad).contains(_sade(_arama.trim())))
                      .toList();

              if (suzulmus.isEmpty) {
                return _bilgi(
                  isDark,
                  Icons.search_off_rounded,
                  'Kulüp bulunamadı',
                  'Çizelge dışında kendi kulübünüzü kurabilirsiniz.',
                  dugme: _ozelKulupSor,
                );
              }

              return ListView.separated(
                controller: widget.kaydirma,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: suzulmus.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == suzulmus.length) return _ozelKulupKarti(isDark);
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

  /// Sürükleme tutamağı — sayfanın çekilebildiğini gösterir.
  Widget _tutamak(bool isDark) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _baslik(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups_2_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kulüp Kur',
                  style: AppFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'MEB çizelgesi (EK-4) · 52 kulüp',
                  style: AppFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded,
                size: 21,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  Widget _arayici(bool isDark) {
    final cerceve = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE2E8F0),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: TextField(
        controller: _aramaKontrol,
        onChanged: (v) => setState(() => _arama = v),
        style: AppFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Kulüp ara…',
          hintStyle: AppFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
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
          suffixIcon: _arama.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _aramaKontrol.clear();
                    setState(() => _arama = '');
                  },
                  icon: Icon(Icons.close_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF8FAFC),
          border: cerceve,
          enabledBorder: cerceve,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _katalogKarti(
    bool isDark,
    ClubCatalogItem k, {
    required bool zatenKurulu,
  }) {
    final renk = temaRengi(k.tema);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: zatenKurulu ? null : () => _kur(k),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: zatenKurulu
                  ? AppColors.success.withValues(alpha: 0.35)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: zatenKurulu ? 0.08 : 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    temaIkonu(k.tema),
                    color: zatenKurulu ? renk.withValues(alpha: 0.5) : renk,
                    size: 19,
                  ),
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
                          height: 1.25,
                          color: zatenKurulu
                              ? (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        zatenKurulu
                            ? 'Bu yıl zaten kurulu'
                            : 'Hazır yıllık plan · EK-4 sıra ${k.no}',
                        style: AppFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: zatenKurulu
                              ? AppColors.success
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  zatenKurulu
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 21,
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
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _ozelKulupSor,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: AppColors.primary, size: 20),
                  ),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Öğretmenler kurulu kararıyla açılan kulüp',
                          style: AppFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bilgi(
    bool isDark,
    IconData ikon,
    String baslik,
    String aciklama, {
    VoidCallback? dugme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon,
                size: 44,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              baslik,
              style: AppFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              aciklama,
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            if (dugme != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: dugme,
                icon: const Icon(Icons.edit_note_rounded,
                    size: 18, color: Colors.white),
                label: Text(
                  'Kendi Kulübümü Kur',
                  style: AppFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _kur(ClubCatalogItem k) async {
    await ref.read(clubListProvider.notifier).katalogdanKur(k);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${k.ad} kuruldu. Belgeleri hazır.')),
    );
  }

  Future<void> _ozelKulupSor() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Aramada yazdığı metin varsa oradan başlat: "Robotik" arayıp
    // bulamayan öğretmen aynı adı tekrar yazmasın.
    final kontrol = TextEditingController(text: _arama.trim());

    final ad = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            fontWeight: FontWeight.w500,
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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

    // Kulüp adı serbest metin; yalnızca boşluk sadeleştirilir.
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
