import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../data/models/guidance_plan_model.dart';
import '../../data/repositories/guidance_plan_repository.dart';

/// Özel eğitim okulları için özelleştirilmiş rehberlik programları.
///
/// ## Neden ayrı sekme
/// ORGM, özel eğitim anaokulu / ilkokulu / ortaokulu ve meslek okulu
/// için ayrı programlar yayımlıyor. Genel sınıf rehberlik planı bu
/// okullarda uygulanamıyor: kazanımlar farklı, her kazanımın altında
/// ölçülebilir **göstergeler** var ve hafta yerine etkinlik numarası
/// kullanılıyor.
///
/// Özel eğitim sınıfı öğretmeni için asıl kaynak bu; genel plana
/// karıştırılsaydı iki program da kullanılamaz hâle gelirdi.
class SpecialEducationView extends StatefulWidget {
  const SpecialEducationView({super.key});

  @override
  State<SpecialEducationView> createState() => _SpecialEducationViewState();
}

class _SpecialEducationViewState extends State<SpecialEducationView> {
  final _repo = GuidancePlanRepository();

  List<({String kod, String ad, int adet})> _programlar = const [];
  String? _secili;
  List<SpecialEducationActivity> _etkinlikler = const [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final p = await _repo.specialPrograms();
    if (!mounted) return;
    final ilk = p.isEmpty ? null : p.first.kod;
    final liste = ilk == null
        ? <SpecialEducationActivity>[]
        : await _repo.specialActivities(ilk);
    if (!mounted) return;
    setState(() {
      _programlar = p;
      _secili = ilk;
      _etkinlikler = liste;
      _yukleniyor = false;
    });
  }

  Future<void> _programSec(String kod) async {
    final liste = await _repo.specialActivities(kod);
    if (!mounted) return;
    setState(() {
      _secili = kod;
      _etkinlikler = liste;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_programlar.isEmpty) {
      return Center(
        child: Text(
          'Özel eğitim programı verisi bulunamadı.',
          style: AppFonts.outfit(
            fontSize: 12.5,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      );
    }

    return Column(
      children: [
        _programSecici(isDark),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _etkinlikler.length,
            itemBuilder: (_, i) => _kart(_etkinlikler[i], isDark),
          ),
        ),
      ],
    );
  }

  Widget _programSecici(bool isDark) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _programlar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final p = _programlar[i];
          final secili = p.kod == _secili;
          // "Özel Eğitim Ortaokulu" -> "Ortaokul": çipe sığması için
          // ortak önek atılır.
          final kisa = p.ad.replaceFirst('Özel Eğitim ', '');
          return ChoiceChip(
            // Renk verilmezse aydınlık modda etiket beyaz kalıp
            // okunmuyor; iki mod da açıkça ele alınır.
            label: Text(
              '$kisa (${p.adet})',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            selected: secili,
            onSelected: (_) => _programSec(p.kod),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _kart(SpecialEducationActivity e, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _detayAc(e),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${e.etkinlikNo ?? '-'}',
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.gelisimAlani.isNotEmpty)
                        Text(
                          e.gelisimAlani,
                          style: AppFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        e.kazanim,
                        style: AppFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (e.gostergeler.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${e.gostergeler.length} gösterge',
                          style: AppFonts.outfit(
                            fontSize: 10.5,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: isDark ? Colors.white38 : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _detayAc(SpecialEducationActivity e) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ResponsiveBottomSheet.show(
      context: context,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Text(
            'Etkinlik ${e.etkinlikNo ?? '-'} · ${e.programAdi}',
            style: AppFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            e.kazanim,
            style: AppFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (e.sure.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              e.sure,
              style: AppFonts.outfit(
                fontSize: 11,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (e.gostergeler.isNotEmpty)
            _bolum(isDark, 'Göstergeler', Icons.checklist_rtl_rounded,
                const Color(0xFF10B981), e.gostergeler),
          if (e.yontemTeknik.isNotEmpty)
            _bolum(isDark, 'Yöntem ve Teknik', Icons.psychology_alt_outlined,
                const Color(0xFF8B5CF6), e.yontemTeknik),
          if (e.aracGerecler.isNotEmpty)
            _bolum(isDark, 'Kaynak Araç ve Gereçler', Icons.backpack_outlined,
                const Color(0xFFF59E0B), e.aracGerecler),
          if (e.surec.isNotEmpty)
            _bolum(isDark, 'Uygulama Basamakları', Icons.list_alt_rounded,
                AppColors.primary, e.surec, numarali: true),
        ],
      ),
    );
  }

  Widget _bolum(
    bool isDark,
    String baslik,
    IconData ikon,
    Color renk,
    List<String> maddeler, {
    bool numarali = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 15, color: renk),
              const SizedBox(width: 6),
              Text(
                baslik,
                style: AppFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: renk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < maddeler.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      numarali ? '${i + 1}.' : '•',
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: renk,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      maddeler[i],
                      style: AppFonts.outfit(
                        fontSize: 12,
                        height: 1.4,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
