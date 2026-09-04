import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../data/models/club_model.dart';
import '../../providers/club_provider.dart';

/// Kulübe üye ekleme sayfası.
///
/// ## Neden önce sınıf seçiliyor
/// Kulüp okul düzeyindedir ve farklı şubelerden öğrenci alır. Öğretmenin
/// tüm öğrencileri tek listede görmesi karışıklık yaratırdı; önce şube,
/// sonra o şubenin öğrencileri seçilir. Sayfa kapanmadan başka şubeye
/// geçilebilir, seçimler birikir.
///
/// Zaten üye olan öğrenci listede işaretli ve pasif görünür —
/// `club_members` tablosundaki `UNIQUE(club_id, student_id)` kısıtı
/// yinelenen kaydı zaten engelliyor, ama öğretmen bunu ekranda görmeli.
class ClubMemberPickerSheet extends ConsumerStatefulWidget {
  const ClubMemberPickerSheet({
    super.key,
    required this.clubId,
    this.kaydirma,
  });

  /// DraggableScrollableSheet'in kaydirma denetleyicisi.
  final ScrollController? kaydirma;

  final int clubId;

  /// Sayfayi acar.
  ///
  /// `ResponsiveBottomSheet` degil: o yardimci icerige sinirsiz
  /// yukseklik veriyor ve icerideki `Expanded` cokuyor (bkz.
  /// `ClubCatalogSheet.show`).
  static Future<void> show(BuildContext context, {required int clubId}) {
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
        builder: (_, kaydirma) =>
            ClubMemberPickerSheet(clubId: clubId, kaydirma: kaydirma),
      ),
    );
  }

  @override
  ConsumerState<ClubMemberPickerSheet> createState() =>
      _ClubMemberPickerSheetState();
}

class _ClubMemberPickerSheetState
    extends ConsumerState<ClubMemberPickerSheet> {
  ClassModel? _sinif;

  /// Bu oturumda seçilen öğrenciler. Kaydedilene kadar burada durur.
  final Set<int> _secili = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final siniflar = ref.watch(classListProvider);
    final mevcutUyeler = ref.watch(clubMembersProvider(widget.clubId));

    final kayitliOgrenciler = <int>{
      for (final u in mevcutUyeler.value ?? const <ClubMember>[])
        if (u.studentId != null) u.studentId!,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Üye Ekle',
                style: AppFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Kulüp farklı şubelerden öğrenci alabilir.',
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
        siniflar.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Sınıflar yüklenemedi.',
              style: AppFonts.outfit(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          data: (liste) {
            if (liste.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Önce sınıf eklemelisiniz.',
                  style: AppFonts.outfit(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              );
            }
            final secili = _sinif ?? liste.first;
            return Expanded(
              child: Column(
                children: [
                  _sinifSecici(isDark, liste, secili),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _ogrenciListesi(isDark, secili, kayitliOgrenciler),
                  ),
                ],
              ),
            );
          },
        ),
        if (_secili.isNotEmpty) _kaydetCubugu(isDark),
      ],
    );
  }

  Widget _sinifSecici(
    bool isDark,
    List<ClassModel> liste,
    ClassModel secili,
  ) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: liste.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final s = liste[i];
          final aktif = s.id == secili.id;
          return ChoiceChip(
            selected: aktif,
            onSelected: (_) => setState(() => _sinif = s),
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
            selectedColor: AppColors.primary.withValues(alpha: 0.18),
            label: Text(
              s.name,
              style: AppFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                // Renk açıkça veriliyor: aydınlık modda devralınan beyaz
                // yazı okunmaz oluyordu (bkz. theme_contrast_test).
                color: aktif
                    ? AppColors.primary
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ogrenciListesi(
    bool isDark,
    ClassModel sinif,
    Set<int> kayitli,
  ) {
    final ogrenciler = ref.watch(studentListProvider(sinif.id ?? 0));

    return ogrenciler.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Öğrenciler yüklenemedi.',
          style: AppFonts.outfit(
            fontSize: 13,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
      data: (liste) {
        if (liste.isEmpty) {
          return Center(
            child: Text(
              'Bu şubede öğrenci yok.',
              style: AppFonts.outfit(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          );
        }

        return ListView.builder(
          controller: widget.kaydirma,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          itemCount: liste.length,
          itemBuilder: (context, i) {
            final o = liste[i];
            final id = o.id;
            final zatenUye = id != null && kayitli.contains(id);
            final isaretli = id != null && _secili.contains(id);

            return CheckboxListTile(
              value: zatenUye || isaretli,
              onChanged: zatenUye || id == null
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _secili.add(id);
                        } else {
                          _secili.remove(id);
                        }
                      }),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                '${o.firstName} ${o.lastName}'.trim(),
                style: AppFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: zatenUye
                      ? (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              subtitle: Text(
                zatenUye
                    ? 'Zaten üye'
                    : (o.schoolNumber > 0 ? 'No: ${o.schoolNumber}' : '—'),
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
        );
      },
    );
  }

  Widget _kaydetCubugu(bool isDark) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: FilledButton(
          onPressed: _kaydet,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            '${_secili.length} öğrenciyi üye yap',
            style: AppFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _kaydet() async {
    final sinif = _sinif;
    if (sinif == null || _secili.isEmpty) return;

    final ogrenciler =
        ref.read(studentListProvider(sinif.id ?? 0)).value ??
            const <StudentModel>[];

    final eklenecek = <ClubMember>[
      for (final o in ogrenciler)
        if (o.id != null && _secili.contains(o.id))
          ClubMember(
            clubId: widget.clubId,
            studentId: o.id,
            adSoyad: '${o.firstName} ${o.lastName}'.trim(),
            okulNo: o.schoolNumber,
            // Şube adı kopyalanır: öğrenci sonradan şube değiştirse
            // bile yılın üye listesi tutarlı kalsın diye.
            sinifAdi: sinif.name,
          ),
    ];

    await ref.read(clubRepositoryProvider).uyeEkleToplu(eklenecek);
    if (!mounted) return;

    ref.invalidate(clubMembersProvider(widget.clubId));
    setState(_secili.clear);
    Navigator.of(context).pop();
  }
}
