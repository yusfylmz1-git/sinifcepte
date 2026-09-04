import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../data/models/club_model.dart';
import '../../providers/club_provider.dart';
import '../views/club_detail_view.dart';
import '../widgets/club_catalog_sheet.dart';

/// Sosyal kulüpler ana ekranı.
///
/// ## Neden bu ekran var
/// Sosyal Etkinlikler Yönetmeliği MADDE 8/4 her öğrencinin en az bir
/// kulübe üye olmasını zorunlu kılıyor. Danışman öğretmen yıl içinde üç
/// evrak hazırlıyor: yıllık çalışma planı, üye listesi ve faaliyet
/// raporu. Üçü de her yıl elle yeniden yazılıyordu.
///
/// ## Kulüp neden sınıf seçtirmiyor
/// Diğer belge ekranlarının aksine burada sınıf seçici yok: kulüp okul
/// düzeyinde kurulur ve farklı şubelerden öğrenci alır. Üye eklerken
/// sınıf seçilir, kulübün kendisi bir şubeye bağlanmaz.
class ClubsHubScreen extends ConsumerWidget {
  const ClubsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kulupler = ref.watch(clubListProvider);
    final yil = ref.watch(currentAcademicYearProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'Sosyal Kulüpler',
        subtitle: '$yil Öğretim Yılı',
        showProfileAvatar: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ClubCatalogSheet.show(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Kulüp Kur',
          style: AppFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: kulupler.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _hataDurumu(isDark, e),
          data: (liste) => liste.isEmpty
              ? _bosDurum(context, isDark)
              : _liste(context, ref, isDark, liste),
        ),
      ),
    );
  }

  Widget _liste(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    List<ClubModel> liste,
  ) {
    return ListView.separated(
      // Alt boşluk FAB'ın listeyi kapatmaması için.
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      itemCount: liste.length + 2,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) return _mevzuatNotu(isDark);
        if (i == 1) return _kulupsuzUyarisi(context, ref, isDark);
        return _kart(context, ref, isDark, liste[i - 2]);
      },
    );
  }

  Widget _kart(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ClubModel kulup,
  ) {
    final uyeler = ref.watch(clubMembersProvider(kulup.id ?? 0));
    final renk = _temaRengi(kulup.tema);

    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClubDetailView(kulup: kulup),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_temaIkonu(kulup.tema), color: renk, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kulup.ad,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      uyeler.when(
                        loading: () => 'Üyeler yükleniyor…',
                        error: (_, _) => 'Üye bilgisi okunamadı',
                        data: (u) => u.isEmpty
                            ? 'Henüz üye eklenmemiş'
                            : '${u.length} üye',
                      ),
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
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hiçbir kulübe üye olmayan öğrencileri gösterir.
  ///
  /// MADDE 8/4 her öğrencinin en az bir kulübe üyeliğini zorunlu kılıyor.
  /// Öğretmen kimin açıkta kaldığını, sınıf sınıf gezmeden görebilmeli.
  /// Herkes bir kulübe yazıldıysa kart hiç görünmez — boş liste uyarı
  /// değil, iyi haberdir ve yer kaplamamalı.
  Widget _kulupsuzUyarisi(BuildContext context, WidgetRef ref, bool isDark) {
    final kulupsuz = ref.watch(clubUnassignedStudentsProvider);

    return kulupsuz.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (liste) {
        if (liste.isEmpty) return const SizedBox.shrink();

        return Material(
          color: AppColors.warning.withValues(alpha: isDark ? 0.16 : 0.11),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _kulupsuzListesi(context, isDark, liste),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(Icons.report_problem_outlined,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${liste.length} öğrenci hiçbir kulübe üye değil. '
                      'Yönetmelik en az bir üyelik istiyor.',
                      style: AppFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF334155)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Kulüpsüz öğrencileri sınıf sınıf listeler.
  void _kulupsuzListesi(
    BuildContext context,
    bool isDark,
    List<Map<String, Object?>> liste,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, kaydirma) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kulüpsüz Öğrenciler',
                    style: AppFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Bu öğrencileri bir kulübe eklemek için kulübü açıp '
                    '"Üye Ekle" deyin.',
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
            Expanded(
              child: ListView.builder(
                controller: kaydirma,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final o = liste[i];
                  final no = (o['okul_no'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      (o['ad_soyad'] as String? ?? '').trim(),
                      style: AppFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      [
                        if ((o['sinif_adi'] as String? ?? '').isNotEmpty)
                          o['sinif_adi'] as String,
                        if (no > 0) 'No: $no',
                      ].join(' · '),
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Öğretmene mevzuat dayanağını hatırlatır.
  ///
  /// "Neden bu evrak isteniyor" sorusunun cevabı ekranda dursun diye;
  /// öğretmen müdürle konuşurken maddeyi arayıp bulmak zorunda kalmasın.
  Widget _mevzuatNotu(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sosyal Etkinlikler Yönetmeliği MADDE 8: Kulüpler EK-4 '
              'çizelgesinden kurulur, öğretmenler kurulu kararıyla farklı '
              'kulüp de açılabilir. Her öğrencinin en az bir kulübe üye '
              'olması zorunludur; üyelik seçildiği öğretim yılıyla sınırlıdır.',
              style: AppFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bosDurum(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_2_outlined,
                size: 58,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            const SizedBox(height: 14),
            Text(
              'Henüz kulüp kurulmadı',
              style: AppFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'MEB EK-4 çizelgesindeki 52 kulüpten birini seçin; yıllık '
              'çalışma planı hazır gelir. Çizelge dışında kendi kulübünüzü '
              'de kurabilirsiniz.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hataDurumu(bool isDark, Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Kulüpler yüklenemedi.\n$e',
          textAlign: TextAlign.center,
          style: AppFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

/// Tema rengi — katalogdaki `tema` alanına karşılık gelir.
Color temaRengi(String tema) => _temaRengi(tema);

Color _temaRengi(String tema) => switch (tema) {
      'bilim' => const Color(0xFF3B82F6),
      'kultur' => const Color(0xFF8B5CF6),
      'sanat' => const Color(0xFFEC4899),
      'spor' => const Color(0xFFF59E0B),
      'doga' => const Color(0xFF10B981),
      'saglik' => const Color(0xFF14B8A6),
      'degerler' => const Color(0xFF6366F1),
      _ => const Color(0xFF64748B),
    };

/// Tema ikonu — liste ve seçim sayfasında ortak kullanılır.
IconData temaIkonu(String tema) => _temaIkonu(tema);

IconData _temaIkonu(String tema) => switch (tema) {
      'bilim' => Icons.science_outlined,
      'kultur' => Icons.menu_book_outlined,
      'sanat' => Icons.palette_outlined,
      'spor' => Icons.sports_soccer_outlined,
      'doga' => Icons.eco_outlined,
      'saglik' => Icons.health_and_safety_outlined,
      'degerler' => Icons.volunteer_activism_outlined,
      _ => Icons.groups_2_outlined,
    };
