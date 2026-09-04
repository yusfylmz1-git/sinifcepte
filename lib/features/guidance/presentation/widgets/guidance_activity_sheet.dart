import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../data/models/guidance_plan_model.dart';

/// Bir haftanın rehberlik etkinliği.
///
/// ## Neden bu ekran
/// Etkinliklerin tam metni ORGM'nin 745 sayfalık PDF'lerinde duruyor.
/// Öğretmen ders başlamadan önce telefonda o dosyayı açıp doğru sayfayı
/// bulamıyor. Burada haftanın etkinliği hazır: ön hazırlık, araç-gereç,
/// süreç basamakları ve BEP'li öğrenci için uyarlamalar.
class GuidanceActivitySheet extends StatefulWidget {
  const GuidanceActivitySheet({
    super.key,
    required this.madde,
    required this.etkinlik,
    required this.kayit,
    this.bepliOgrenci = 0,
    required this.onDurumDegisti,
    required this.onNotKaydet,
  });

  final GuidancePlanItem madde;
  final GuidanceActivity? etkinlik;
  final GuidanceLogEntry? kayit;

  /// Sinifta BEP plani olan ogrenci sayisi.
  final int bepliOgrenci;

  final ValueChanged<bool> onDurumDegisti;
  final Future<void> Function(String) onNotKaydet;

  static Future<void> show(
    BuildContext context, {
    required GuidancePlanItem madde,
    required GuidanceActivity? etkinlik,
    required GuidanceLogEntry? kayit,
    int bepliOgrenci = 0,
    required ValueChanged<bool> onDurumDegisti,
    required Future<void> Function(String) onNotKaydet,
  }) {
    return ResponsiveBottomSheet.show(
      context: context,
      child: GuidanceActivitySheet(
        madde: madde,
        etkinlik: etkinlik,
        kayit: kayit,
        bepliOgrenci: bepliOgrenci,
        onDurumDegisti: onDurumDegisti,
        onNotKaydet: onNotKaydet,
      ),
    );
  }

  @override
  State<GuidanceActivitySheet> createState() => _GuidanceActivitySheetState();
}

class _GuidanceActivitySheetState extends State<GuidanceActivitySheet> {
  late final TextEditingController _not;
  late bool _uygulandi;

  @override
  void initState() {
    super.initState();
    _not = TextEditingController(text: widget.kayit?.not ?? '');
    _uygulandi = widget.kayit?.uygulandi ?? false;
  }

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final e = widget.etkinlik;

    // `ResponsiveBottomSheet` içeriği ZATEN `SingleChildScrollView`
    // ile sarıyor. Burada ikinci bir `ListView` kullanmak iç içe iki
    // kaydırma alanı oluşturuyor ve dikey jest ikisi arasında
    // bölündüğü için sayfa aşağı kaydırılamıyordu.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baslik(isDark),
        const SizedBox(height: 12),
        _durumSatiri(isDark),
        const SizedBox(height: 14),

        if (e == null)
          _bilgiKutusu(
            isDark,
            'Bu hafta için hazır etkinlik metni bulunamadı. '
            'Kazanımı kendi planınıza göre işleyebilirsiniz.',
            Icons.info_outline_rounded,
            Colors.orange,
          )
        else ...[
          _rozetler(isDark, e),
          const SizedBox(height: 14),
          if (e.onHazirlik.isNotEmpty)
            _bolum(isDark, 'Ön Hazırlık', Icons.checklist_rounded,
                const Color(0xFF0EA5E9), e.onHazirlik),
          if (e.aracGerecler.isNotEmpty)
            _bolum(isDark, 'Araç-Gereçler', Icons.backpack_outlined,
                const Color(0xFFF59E0B), e.aracGerecler),
          if (e.surec.isNotEmpty)
            _bolum(isDark, 'Uygulama Basamakları', Icons.list_alt_rounded,
                AppColors.primary, e.surec, numarali: true),
          // Sinifta BEP'li ogrenci varsa uyarlamalar SURECTEN ONCE
          // gosterilir; ogretmen dersi planlarken uyarlamayi sonradan
          // hatirlamak yerine bastan gorur.
          if (e.ozelGereksinimUyarlamalari.isNotEmpty)
            _bepBolumu(isDark, e),
          if (e.degerlendirme.isNotEmpty)
            _metinBolumu(isDark, 'Kazanımın Değerlendirilmesi',
                Icons.fact_check_outlined, const Color(0xFF10B981),
                e.degerlendirme),
          if (e.uygulayiciyaNot.isNotEmpty)
            _metinBolumu(isDark, 'Uygulayıcıya Not',
                Icons.sticky_note_2_outlined, const Color(0xFF64748B),
                e.uygulayiciyaNot),
        ],

        const SizedBox(height: 6),
        _notAlani(isDark),
      ],
    );
  }

  Widget _baslik(bool isDark) {
    final ad = widget.etkinlik?.etkinlikAdi ??
        widget.madde.etkinlikAdi ??
        'Rehberlik Etkinliği';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.madde.hafta}. hafta · ${widget.madde.tarihAraligi}',
          style: AppFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ad,
          style: AppFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.madde.kazanim,
          style: AppFonts.outfit(
            fontSize: 12.5,
            height: 1.35,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  /// Uygulandı işareti — tek dokunuş.
  Widget _durumSatiri(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _uygulandi = !_uygulandi);
              widget.onDurumDegisti(_uygulandi);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _uygulandi
                    ? const Color(0xFF10B981).withValues(alpha: 0.14)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _uygulandi
                      ? const Color(0xFF10B981)
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _uygulandi
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: _uygulandi
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white38 : Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _uygulandi ? 'Uygulandı' : 'Uygulandı olarak işaretle',
                    style: AppFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _uygulandi
                          ? const Color(0xFF059669)
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rozetler(bool isDark, GuidanceActivity e) {
    final ogeler = <(String, Color)>[
      if (e.gelisimAlani.isNotEmpty) (e.gelisimAlani, const Color(0xFF8B5CF6)),
      if (e.yeterlikAlani.isNotEmpty)
        (e.yeterlikAlani, const Color(0xFF3B82F6)),
      if (e.sure.isNotEmpty) (e.sure, const Color(0xFF64748B)),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (metin, renk) in ogeler)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              metin,
              style: AppFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: renk,
              ),
            ),
          ),
      ],
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
          _bolumBasligi(isDark, baslik, ikon, renk),
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

  /// BEP uyarlamaları ayrı renkte ve çerçeveli.
  ///
  /// Kaynaştırma öğrencisi olan öğretmen için etkinliğin en kritik
  /// parçası bu; düz liste içinde kaybolmamalı.
  Widget _bepBolumu(bool isDark, GuidanceActivity e) {
    const renk = Color(0xFF10B981);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bolumBasligi(
            isDark,
            widget.bepliOgrenci > 0
                ? 'Özel Gereksinimli Öğrenciler İçin '
                    "(${widget.bepliOgrenci} BEP'li öğrenci)"
                : 'Özel Gereksinimli Öğrenciler İçin',
            Icons.accessibility_new_rounded,
            renk,
          ),
          const SizedBox(height: 6),
          for (final u in e.ozelGereksinimUyarlamalari)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: renk)),
                  Expanded(
                    child: Text(
                      u,
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

  Widget _metinBolumu(bool isDark, String baslik, IconData ikon, Color renk,
      String metin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bolumBasligi(isDark, baslik, ikon, renk),
          const SizedBox(height: 6),
          Text(
            metin,
            style: AppFonts.outfit(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bolumBasligi(
      bool isDark, String baslik, IconData ikon, Color renk) {
    return Row(
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
    );
  }

  Widget _bilgiKutusu(
      bool isDark, String metin, IconData ikon, Color renk) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 15, color: renk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              metin,
              style: AppFonts.outfit(
                fontSize: 11.5,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notAlani(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bolumBasligi(isDark, 'Notum', Icons.edit_note_rounded,
            isDark ? Colors.white54 : const Color(0xFF64748B)),
        const SizedBox(height: 6),
        TextField(
          controller: _not,
          maxLines: 3,
          maxLength: 500,
          style: AppFonts.outfit(fontSize: 12.5),
          decoration: const InputDecoration(
            hintText: 'Nasıl geçti? Sınıfın tepkisi ne oldu?',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              await widget.onNotKaydet(_not.text.trim());
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ),
      ],
    );
  }
}
