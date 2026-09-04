import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../utils/club_pdf_generator.dart';

/// Yıllık çalışma planı sekmesi.
///
/// ## Hazır plan neden düzenlenebilir
/// Paketteki metin her okulda kullanılabilecek şekilde yazıldı, ama
/// öğretmen kendi okuluna göre değiştirmek isteyebilir. Düzenlenen ay
/// `clubs.plan_duzenlemeleri` içinde saklanır; dokunulmayan aylar
/// katalogdan gelmeye devam eder, böylece paket güncellenince yeni
/// içerik kendiliğinden gelir.
class ClubPlanEditor extends ConsumerWidget {
  const ClubPlanEditor({
    super.key,
    required this.kulup,
    required this.onKulupDegisti,
  });

  final ClubModel kulup;

  /// Plan düzenlenince güncel kulübü üst ekrana bildirir.
  final ValueChanged<ClubModel> onKulupDegisti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = ref.watch(clubPlanProvider(kulup));

    return plan.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Plan yüklenemedi.\n$e',
            textAlign: TextAlign.center,
            style: AppFonts.outfit(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      ),
      data: (satirlar) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: satirlar.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (context, i) {
          if (i == 0) return _ustBilgi(isDark);
          if (i == satirlar.length + 1) {
            return _pdfDugmesi(context, ref, satirlar);
          }
          return _aySatiri(context, ref, isDark, satirlar[i - 1]);
        },
      ),
    );
  }

  Widget _ustBilgi(bool isDark) {
    final ozel = kulup.ozelKulup;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ozel ? AppColors.warning : AppColors.success)
            .withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ozel ? Icons.edit_note_rounded : Icons.auto_awesome_rounded,
            size: 17,
            color: ozel ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              ozel
                  ? 'Bu kulüp çizelge dışı kurulduğu için hazır plan yok. '
                      'Her aya dokunup kendi planınızı yazabilirsiniz.'
                  : 'Hazır plan yüklendi. Bir aya dokunarak kendi okulunuza '
                      'göre değiştirebilirsiniz.',
              style: AppFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aySatiri(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ClubPlanRow satir,
  ) {
    final duzenlendi = kulup.planDuzenlemeleri.containsKey(satir.ay);
    final bos = satir.amac.trim().isEmpty && satir.etkinlik.trim().isEmpty;

    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _duzenle(context, ref, satir),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      satir.ay,
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (duzenlendi)
                    Icon(Icons.edit_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ],
              ),
              const SizedBox(height: 8),
              if (bos)
                Text(
                  'Bu ay için plan yazılmadı — dokunup ekleyin.',
                  style: AppFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                )
              else ...[
                Text(
                  satir.amac,
                  style: AppFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  satir.etkinlik,
                  style: AppFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pdfDugmesi(
    BuildContext context,
    WidgetRef ref,
    List<ClubPlanRow> plan,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () async {
          final profil = ref.read(teacherProfileProvider);
          await ClubPdfGenerator.yillikPlanAc(
            context,
            kulup: kulup,
            plan: plan,
            teacherProfile: profil,
          );
        },
        icon: const Icon(Icons.picture_as_pdf_outlined,
            size: 18, color: AppColors.primary),
        label: Text(
          'Yıllık Plan PDF',
          style: AppFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _duzenle(
    BuildContext context,
    WidgetRef ref,
    ClubPlanRow satir,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amacKontrol = TextEditingController(text: satir.amac);
    final etkinlikKontrol = TextEditingController(text: satir.etkinlik);

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCardBackground : Colors.white,
        title: Text(
          '${satir.ay} Planı',
          style: AppFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _alan(isDark, 'Amaç', amacKontrol, 2),
              const SizedBox(height: 12),
              _alan(isDark, 'Yapılacak Etkinlikler', etkinlikKontrol, 6),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
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
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Kaydet',
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

    final yeniAmac = amacKontrol.text.trim();
    final yeniEtkinlik = etkinlikKontrol.text.trim();
    amacKontrol.dispose();
    etkinlikKontrol.dispose();

    if (kaydet != true) return;

    final duzenlemeler =
        Map<String, ClubPlanRow>.from(kulup.planDuzenlemeleri);
    duzenlemeler[satir.ay] = ClubPlanRow(
      ay: satir.ay,
      amac: yeniAmac,
      etkinlik: yeniEtkinlik,
    );

    final yeni = kulup.copyWith(planDuzenlemeleri: duzenlemeler);
    await ref.read(clubRepositoryProvider).kulupGuncelle(yeni);
    onKulupDegisti(yeni);
    ref.invalidate(clubPlanProvider(kulup));
    await ref.read(clubListProvider.notifier).yukle();
  }

  Widget _alan(
    bool isDark,
    String etiket,
    TextEditingController kontrol,
    int satirSayisi,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiket,
          style: AppFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: kontrol,
          maxLines: satirSayisi,
          textCapitalization: TextCapitalization.sentences,
          style: AppFonts.outfit(
            fontSize: 13,
            height: 1.45,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
