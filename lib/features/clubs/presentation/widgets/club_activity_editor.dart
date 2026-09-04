import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../utils/club_pdf_generator.dart';

/// Faaliyet (yıl sonu raporu) sekmesi.
///
/// ## Plan ile raporun ilişkisi
/// Planda "ne yapılacak", burada "ne yapıldı" yazar. İkisi PDF'te yan
/// yana basıldığı için öğretmen yıl sonunda rapor yazmak zorunda kalmaz;
/// ay ay doldurdukça rapor kendiliğinden oluşur.
class ClubActivityEditor extends ConsumerWidget {
  const ClubActivityEditor({super.key, required this.kulup});

  final ClubModel kulup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clubId = kulup.id ?? 0;
    final faaliyetler = ref.watch(clubActivityProvider(clubId));

    return faaliyetler.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Faaliyet kaydı yüklenemedi.\n$e',
            textAlign: TextAlign.center,
            style: AppFonts.outfit(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      ),
      data: (liste) {
        final dolu = liste.where((f) => f.dolu).length;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: liste.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, i) {
            if (i == 0) return _ozet(isDark, dolu, liste.length);
            if (i == liste.length + 1) {
              return _pdfDugmesi(context, ref, liste);
            }
            return _aySatiri(context, ref, isDark, liste[i - 1]);
          },
        );
      },
    );
  }

  Widget _ozet(bool isDark, int dolu, int toplam) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fact_check_outlined,
              size: 17, color: AppColors.info),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$toplam aydan $dolu tanesi dolduruldu. Her ay yaptığınız '
              'çalışmayı yazdıkça yıl sonu faaliyet raporu kendiliğinden '
              'oluşur.',
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
    ClubActivityLog kayit,
  ) {
    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _duzenle(context, ref, kayit),
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
                      color: (kayit.dolu ? AppColors.success : Colors.grey)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      kayit.ay,
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kayit.dolu
                            ? AppColors.success
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (kayit.katilanSayisi > 0)
                    Text(
                      '${kayit.katilanSayisi} katılımcı',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                kayit.dolu
                    ? kayit.yapilanCalisma
                    : 'Bu ay için kayıt girilmedi — dokunup yazın.',
                style: AppFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  fontStyle:
                      kayit.dolu ? FontStyle.normal : FontStyle.italic,
                  color: kayit.dolu
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pdfDugmesi(
    BuildContext context,
    WidgetRef ref,
    List<ClubActivityLog> faaliyetler,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () async {
          final profil = ref.read(teacherProfileProvider);
          final repo = ref.read(clubRepositoryProvider);
          final plan = await repo.plan(kulup);
          final uyeler = await repo.uyeler(kulup.id ?? 0);
          if (!context.mounted) return;
          await ClubPdfGenerator.faaliyetRaporuAc(
            context,
            kulup: kulup,
            plan: plan,
            faaliyetler: faaliyetler,
            uyeSayisi: uyeler.length,
            teacherProfile: profil,
          );
        },
        icon: const Icon(Icons.picture_as_pdf_outlined,
            size: 18, color: AppColors.primary),
        label: Text(
          'Faaliyet Raporu PDF',
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
    ClubActivityLog kayit,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metinKontrol = TextEditingController(text: kayit.yapilanCalisma);
    final sayiKontrol = TextEditingController(
      text: kayit.katilanSayisi > 0 ? '${kayit.katilanSayisi}' : '',
    );

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCardBackground : Colors.white,
        title: Text(
          '${kayit.ay} Faaliyeti',
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
              Text(
                'Gerçekleşen çalışma',
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
                controller: metinKontrol,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: AppFonts.outfit(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: _kutu(isDark, 'Bu ay ne yapıldı?'),
              ),
              const SizedBox(height: 12),
              Text(
                'Katılan üye sayısı',
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
                controller: sayiKontrol,
                keyboardType: TextInputType.number,
                style: AppFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: _kutu(isDark, 'Boş bırakılabilir'),
              ),
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

    final metin = metinKontrol.text.trim();
    // Sayı alanı boş ya da geçersizse 0: rapora "—" basılır.
    final sayi = int.tryParse(sayiKontrol.text.trim()) ?? 0;
    metinKontrol.dispose();
    sayiKontrol.dispose();

    if (kaydet != true) return;

    final clubId = kulup.id ?? 0;
    await ref.read(clubRepositoryProvider).faaliyetKaydet(
          ClubActivityLog(
            id: kayit.id,
            clubId: clubId,
            ay: kayit.ay,
            yapilanCalisma: metin,
            katilanSayisi: sayi < 0 ? 0 : sayi,
          ),
        );
    ref.invalidate(clubActivityProvider(clubId));
  }

  InputDecoration _kutu(bool isDark, String ipucu) => InputDecoration(
        isDense: true,
        hintText: ipucu,
        hintStyle: AppFonts.outfit(
          fontSize: 13,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}
