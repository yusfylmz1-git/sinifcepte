import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../utils/club_bundle_exporter.dart';
import '../../utils/club_pdf_generator.dart';
import '../widgets/club_activity_editor.dart';
import '../widgets/club_member_picker_sheet.dart';
import '../widgets/club_plan_editor.dart';

/// Bir kulübün üç işi: plan, üyeler, faaliyet raporu.
///
/// Yönetmeliğin danışman öğretmenden istediği üç evrak burada üretilir.
/// Sekmeler evrakların hazırlanma sırasına göre dizilmiştir: yıl başında
/// plan, ardından üye kaydı, yıl sonunda rapor.
class ClubDetailView extends ConsumerStatefulWidget {
  const ClubDetailView({super.key, required this.kulup});

  final ClubModel kulup;

  @override
  ConsumerState<ClubDetailView> createState() => _ClubDetailViewState();
}

class _ClubDetailViewState extends ConsumerState<ClubDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  /// Kulüp adı düzenlenince listeden gelen kopya eskir; güncel hâli
  /// burada tutulur.
  late ClubModel _kulup;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _kulup = widget.kulup;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yil = ref.watch(currentAcademicYearProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: _kulup.ad,
        subtitle: '$yil Öğretim Yılı',
        showProfileAvatar: false,
        actions: [
          IconButton(
            tooltip: 'Belgeler',
            icon: const Icon(Icons.folder_open_rounded,
                color: AppColors.primary),
            onPressed: _belgeleriAc,
          ),
          IconButton(
            tooltip: 'Kulübü sil',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
            onPressed: _silmeyiSor,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkCardBackground : Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              indicatorColor: AppColors.primary,
              labelStyle: AppFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: AppFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Yıllık Plan'),
                Tab(text: 'Üyeler'),
                Tab(text: 'Faaliyet'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                ClubPlanEditor(
                  kulup: _kulup,
                  onKulupDegisti: (yeni) => setState(() => _kulup = yeni),
                ),
                _uyelerSekmesi(isDark),
                ClubActivityEditor(kulup: _kulup),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Üyeler sekmesi
  // ------------------------------------------------------------------

  Widget _uyelerSekmesi(bool isDark) {
    final uyeler = ref.watch(clubMembersProvider(_kulup.id ?? 0));

    return Stack(
      children: [
        uyeler.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Üyeler yüklenemedi.\n$e',
                textAlign: TextAlign.center,
                style: AppFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ),
          data: (liste) => liste.isEmpty
              ? _bosUye(isDark)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
                  itemCount: liste.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == liste.length) {
                      return _pdfDugmesi(
                        isDark,
                        'Üye Listesi PDF',
                        Icons.picture_as_pdf_outlined,
                        () => _uyeListesiPdf(liste),
                      );
                    }
                    return _uyeSatiri(isDark, liste[i], i + 1);
                  },
                ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'uye_ekle',
            onPressed: _uyeEkle,
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white),
            label: Text(
              'Üye Ekle',
              style: AppFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _uyeSatiri(bool isDark, ClubMember uye, int sira) {
    final temsilciMi = _kulup.temsilciUyeId != null &&
        _kulup.temsilciUyeId == uye.id;

    return Material(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _uyeSecenekleri(uye, temsilciMi),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$sira',
                  style: AppFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uye.adSoyad,
                      style: AppFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      [
                        if (uye.sinifAdi.isNotEmpty) uye.sinifAdi,
                        if (uye.okulNo > 0) 'No: ${uye.okulNo}',
                        uye.gorev,
                      ].join(' · '),
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
              if (temsilciMi)
                const Icon(Icons.star_rounded,
                    size: 19, color: AppColors.warning),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bosUye(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_outlined,
                size: 52,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'Henüz üye eklenmemiş',
              style: AppFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Kulüp farklı şubelerden öğrenci alabilir. Üye eklerken '
              'sınıf seçilir.',
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
            const SizedBox(height: 18),
            // Üye girilmemiş olsa da evrak bugün lazım olabilir: boş
            // çizelge basılır, öğretmen elle doldurur.
            OutlinedButton.icon(
              onPressed: () => _uyeListesiPdf(const []),
              icon: const Icon(Icons.picture_as_pdf_outlined,
                  size: 18, color: AppColors.primary),
              label: Text(
                'Boş Liste Şablonu İndir',
                style: AppFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                side:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfDugmesi(
    bool isDark,
    String etiket,
    IconData ikon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(ikon, size: 18, color: AppColors.primary),
        label: Text(
          etiket,
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

  // ------------------------------------------------------------------
  // İşlemler
  // ------------------------------------------------------------------

  Future<void> _uyeEkle() async {
    final id = _kulup.id;
    if (id == null) return;
    await ClubMemberPickerSheet.show(context, clubId: id);
    if (!mounted) return;
    ref.invalidate(clubMembersProvider(id));
  }

  Future<void> _uyeSecenekleri(ClubMember uye, bool temsilciMi) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final secim = await showModalBottomSheet<String>(
      context: context,
      backgroundColor:
          isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.star_outline_rounded,
                  color: AppColors.warning),
              title: Text(
                temsilciMi
                    ? 'Kulüp temsilciliğini kaldır'
                    : 'Kulüp temsilcisi yap',
                style: AppFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop('temsilci'),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined,
                  color: AppColors.danger),
              title: Text(
                'Üyelikten çıkar',
                style: AppFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop('sil'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (secim == null || !mounted) return;
    final repo = ref.read(clubRepositoryProvider);
    final clubId = _kulup.id;
    if (clubId == null) return;

    if (secim == 'temsilci') {
      // Temsilci tek kişidir: yeni seçim öncekini düşürür. Görev alanı
      // da güncellenir ki üye listesi PDF'i doğru bassın.
      final yeni = _kulup.copyWith(
        temsilciUyeId: temsilciMi ? null : uye.id,
        temsilciTemizle: temsilciMi,
      );
      await repo.kulupGuncelle(yeni);

      final hepsi = await repo.uyeler(clubId);
      for (final u in hepsi) {
        final olmali = !temsilciMi && u.id == uye.id
            ? 'Kulüp Temsilcisi'
            : 'Üye';
        if (u.gorev != olmali) {
          await repo.uyeGuncelle(u.copyWith(gorev: olmali));
        }
      }

      if (!mounted) return;
      setState(() => _kulup = yeni);
      await ref.read(clubListProvider.notifier).yukle();
    } else if (secim == 'sil') {
      final uyeId = uye.id;
      if (uyeId != null) await repo.uyeSil(uyeId);
      if (_kulup.temsilciUyeId == uye.id) {
        final yeni = _kulup.copyWith(temsilciTemizle: true);
        await repo.kulupGuncelle(yeni);
        if (mounted) setState(() => _kulup = yeni);
      }
    }

    if (!mounted) return;
    ref.invalidate(clubMembersProvider(clubId));
  }

  Future<void> _uyeListesiPdf(List<ClubMember> uyeler) async {
    final profil = ref.read(teacherProfileProvider);
    await ClubPdfGenerator.uyeListesiAc(
      context,
      kulup: _kulup,
      uyeler: uyeler,
      teacherProfile: profil,
    );
  }

  /// Kulübün üç resmî evrakını tek yerden sunar.
  ///
  /// ## Neden ayrı bir sayfa
  /// PDF düğmeleri sekmelerin altına dağılmıştı; öğretmen üç evrakı
  /// almak için üç sekme gezmek zorundaydı. Oysa evraklar birlikte
  /// isteniyor — dosyaya hepsi konuyor.
  ///
  /// Üçü de kulüp kurulur kurulmaz hazırdır: plan katalogdan gelir,
  /// faaliyet raporu kurulumda plandan tohumlanır, üye listesi boşsa
  /// elle doldurulacak çizelge olarak basılır.
  Future<void> _belgeleriAc() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kulüp Belgeleri',
                    style: AppFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Üçü de hazır. İçeriği değiştirmek isterseniz '
                    'sekmelerden düzenleyin.',
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _hepsiTekPdf();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          size: 17, color: Colors.white),
                      label: Text(
                        'Hepsi Tek PDF',
                        style: AppFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _ucDosyaPaylas();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                            color:
                                AppColors.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.ios_share_rounded,
                          size: 16, color: AppColors.primary),
                      label: Text(
                        '3 Dosya Paylaş',
                        style: AppFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Divider(height: 1),
            ),
            _belgeSatiri(
              sheetContext,
              isDark,
              ikon: Icons.event_note_rounded,
              ad: 'Yıllık Çalışma Planı',
              aciklama: 'Eylül-Haziran, on aylık plan',
              onTap: _planPdf,
            ),
            _belgeSatiri(
              sheetContext,
              isDark,
              ikon: Icons.fact_check_rounded,
              ad: 'Yıl Sonu Faaliyet Raporu',
              aciklama: 'Planlanan ve gerçekleşen çalışmalar',
              onTap: _raporPdf,
            ),
            _belgeSatiri(
              sheetContext,
              isDark,
              ikon: Icons.groups_rounded,
              ad: 'Üye Listesi',
              aciklama: 'Üye yoksa elle doldurulacak çizelge basılır',
              onTap: _uyePdf,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _belgeSatiri(
    BuildContext sheetContext,
    bool isDark, {
    required IconData ikon,
    required String ad,
    required String aciklama,
    required Future<void> Function() onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(ikon, size: 19, color: AppColors.primary),
      ),
      title: Text(
        ad,
        style: AppFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        aciklama,
        style: AppFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
      trailing: const Icon(Icons.picture_as_pdf_outlined,
          size: 19, color: AppColors.primary),
      onTap: () {
        // Önce sayfayı kapat: PDF önizlemesi üstüne açılmasın.
        Navigator.of(sheetContext).pop();
        onTap();
      },
    );
  }

  /// Üç belgeyi tek PDF olarak açar.
  ///
  /// Yazdırıp dosyaya koymak ve tek seferde imzalatmak için; her belge
  /// kendi künyesi ve imza bloğuyla ayrı sayfada başlar.
  Future<void> _hepsiTekPdf() async {
    final veri = await _belgeVerisi();
    if (!mounted || veri == null) return;
    await ClubBundleExporter.birlesikAc(
      context,
      kulup: _kulup,
      plan: veri.plan,
      uyeler: veri.uyeler,
      faaliyetler: veri.faaliyetler,
      teacherProfile: veri.profil,
    );
  }

  /// Üç belgeyi ayrı dosya olarak paylaşır.
  Future<void> _ucDosyaPaylas() async {
    final veri = await _belgeVerisi();
    if (!mounted || veri == null) return;

    // Üç PDF üretimi birkaç saniye sürebiliyor; kullanıcı beklediğini
    // görmeli, yoksa düğmeye tekrar basıyor.
    final mesajci = ScaffoldMessenger.of(context);
    mesajci.showSnackBar(
      const SnackBar(content: Text('Belgeler hazırlanıyor…')),
    );

    try {
      await ClubBundleExporter.ucDosyaPaylas(
        kulup: _kulup,
        plan: veri.plan,
        uyeler: veri.uyeler,
        faaliyetler: veri.faaliyetler,
        teacherProfile: veri.profil,
      );
    } catch (e) {
      mesajci.showSnackBar(
        SnackBar(content: Text('Belgeler paylaşılamadı: $e')),
      );
    }
  }

  /// Üç belge için gereken veriyi tek seferde okur.
  Future<({
    List<ClubPlanRow> plan,
    List<ClubMember> uyeler,
    List<ClubActivityLog> faaliyetler,
    TeacherProfileModel profil,
  })?> _belgeVerisi() async {
    final id = _kulup.id;
    if (id == null) return null;
    final repo = ref.read(clubRepositoryProvider);
    return (
      plan: await repo.plan(_kulup),
      uyeler: await repo.uyeler(id),
      faaliyetler: await repo.faaliyetler(id),
      profil: ref.read(teacherProfileProvider),
    );
  }

  Future<void> _planPdf() async {
    final repo = ref.read(clubRepositoryProvider);
    final profil = ref.read(teacherProfileProvider);
    final plan = await repo.plan(_kulup);
    if (!mounted) return;
    await ClubPdfGenerator.yillikPlanAc(
      context,
      kulup: _kulup,
      plan: plan,
      teacherProfile: profil,
    );
  }

  Future<void> _raporPdf() async {
    final repo = ref.read(clubRepositoryProvider);
    final profil = ref.read(teacherProfileProvider);
    final clubId = _kulup.id ?? 0;
    final plan = await repo.plan(_kulup);
    final faaliyetler = await repo.faaliyetler(clubId);
    final uyeler = await repo.uyeler(clubId);
    if (!mounted) return;
    await ClubPdfGenerator.faaliyetRaporuAc(
      context,
      kulup: _kulup,
      plan: plan,
      faaliyetler: faaliyetler,
      uyeSayisi: uyeler.length,
      teacherProfile: profil,
    );
  }

  Future<void> _uyePdf() async {
    final repo = ref.read(clubRepositoryProvider);
    final profil = ref.read(teacherProfileProvider);
    final uyeler = await repo.uyeler(_kulup.id ?? 0);
    if (!mounted) return;
    await ClubPdfGenerator.uyeListesiAc(
      context,
      kulup: _kulup,
      uyeler: uyeler,
      teacherProfile: profil,
    );
  }

  Future<void> _silmeyiSor() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCardBackground : Colors.white,
        title: Text(
          'Kulüp silinsin mi?',
          style: AppFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          '${_kulup.ad} ve bu kulübe ait üye kayıtları ile faaliyet '
          'kayıtları silinecek. Bu işlem geri alınamaz.',
          style: AppFonts.outfit(
            fontSize: 13.5,
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sil',
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

    if (onay != true || !mounted) return;
    final id = _kulup.id;
    if (id == null) return;
    await ref.read(clubListProvider.notifier).sil(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
