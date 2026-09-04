import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../utils/club_activity_suggester.dart';
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
    // Öneri metni plandan üretiliyor; iki kaynak birlikte okunur.
    final plan = ref.watch(clubPlanProvider(kulup)).value ??
        const <ClubPlanRow>[];

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
            if (i == 0) {
              return _ozet(context, ref, isDark, dolu, liste, plan);
            }
            if (i == liste.length + 1) {
              return _pdfDugmesi(context, ref, liste);
            }
            return _aySatiri(context, ref, isDark, liste[i - 1], plan);
          },
        );
      },
    );
  }

  Widget _ozet(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    int dolu,
    List<ClubActivityLog> faaliyetler,
    List<ClubPlanRow> plan,
  ) {
    final toplam = faaliyetler.length;
    // Plandan doldurulabilecek boş ay var mı?
    final planAy = {for (final p in plan) p.ay: p};
    final doldurulabilir = faaliyetler
        .where((f) =>
            !f.dolu &&
            planAy[f.ay] != null &&
            ClubActivitySuggester.oneriVar(planAy[f.ay]!))
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (doldurulabilir > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _topluDoldur(context, ref, faaliyetler, plan),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: const Icon(Icons.auto_fix_high_rounded,
                    size: 17, color: Colors.white),
                label: Text(
                  'Boş $doldurulabilir ayı plandan doldur',
                  style: AppFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Boş ayları plandan üretilen metinle doldurur.
  ///
  /// Dolu aylara DOKUNMAZ: öğretmenin yazdığı metin üzerine yazmak
  /// geri alınamaz bir kayıp olurdu. Üretilen metinler taslaktır,
  /// öğretmen tek tek açıp düzeltebilir.
  Future<void> _topluDoldur(
    BuildContext context,
    WidgetRef ref,
    List<ClubActivityLog> faaliyetler,
    List<ClubPlanRow> plan,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planAy = {for (final p in plan) p.ay: p};

    final hedefler = faaliyetler
        .where((f) =>
            !f.dolu &&
            planAy[f.ay] != null &&
            ClubActivitySuggester.oneriVar(planAy[f.ay]!))
        .toList();
    if (hedefler.isEmpty) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
        title: Text(
          'Plandan doldurulsun mu?',
          style: AppFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Boş ${hedefler.length} ay, yıllık plandaki metinden üretilen '
          'taslakla doldurulacak. Dolu aylara dokunulmaz.\n\n'
          'Üretilen metinler taslaktır; her ayı açıp okulunuzda gerçekten '
          'yapılana göre düzeltmeniz beklenir.',
          style: AppFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
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
              'Doldur',
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

    if (onay != true) return;

    final repo = ref.read(clubRepositoryProvider);
    final clubId = kulup.id ?? 0;
    for (final f in hedefler) {
      await repo.faaliyetKaydet(ClubActivityLog(
        id: f.id,
        clubId: clubId,
        ay: f.ay,
        yapilanCalisma: ClubActivitySuggester.oner(planAy[f.ay]!),
        katilanSayisi: f.katilanSayisi,
      ));
    }
    ref.invalidate(clubActivityProvider(clubId));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${hedefler.length} ay dolduruldu. '
            'Metinleri gözden geçirmeyi unutmayın.'),
      ),
    );
  }

  Widget _aySatiri(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ClubActivityLog kayit,
    List<ClubPlanRow> plan,
  ) {
    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _duzenle(
          context,
          ref,
          kayit,
          _planSatiri(plan, kayit.ay),
        ),
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

  /// Bir ayin plan satirini bulur; yoksa null.
  ClubPlanRow? _planSatiri(List<ClubPlanRow> plan, String ay) {
    for (final p in plan) {
      if (p.ay == ay) return p;
    }
    return null;
  }

  Future<void> _duzenle(
    BuildContext context,
    WidgetRef ref,
    ClubActivityLog kayit,
    ClubPlanRow? planSatiri,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metinKontrol = TextEditingController(text: kayit.yapilanCalisma);
    final sayiKontrol = TextEditingController(
      text: kayit.katilanSayisi > 0 ? '${kayit.katilanSayisi}' : '',
    );

    // Öneri ve üye sayısı kısayolu için hazırlık.
    final oneri = planSatiri != null &&
            ClubActivitySuggester.oneriVar(planSatiri)
        ? ClubActivitySuggester.oner(planSatiri)
        : '';
    final uyeSayisi =
        (ref.read(clubMembersProvider(kulup.id ?? 0)).value ?? const [])
            .length;

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
              if (planSatiri != null) ...[
                // Planda ne yazdigi goz onunde dursun: ogretmen
                // "ne yapacaktim" diye geri donmek zorunda kalmasin.
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLANDA',
                        style: AppFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        planSatiri.amac,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
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
                  const Spacer(),
                  if (oneri.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        metinKontrol.text = oneri;
                        // İmleci sona al ki öğretmen yazmaya devam
                        // edebilsin.
                        metinKontrol.selection = TextSelection.collapsed(
                          offset: oneri.length,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.auto_fix_high_rounded,
                          size: 15, color: AppColors.primary),
                      label: Text(
                        'Plandan doldur',
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
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
              Row(
                children: [
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
                  const Spacer(),
                  if (uyeSayisi > 0)
                    TextButton(
                      onPressed: () => sayiKontrol.text = '$uyeSayisi',
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Tümü ($uyeSayisi)',
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
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
