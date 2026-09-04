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
    required this.kulupAdi,
    this.kaydirma,
  });

  final int clubId;
  final String kulupAdi;

  /// DraggableScrollableSheet'in kaydırma denetleyicisi.
  final ScrollController? kaydirma;

  /// Sayfayı açar.
  ///
  /// `ResponsiveBottomSheet` değil: o yardımcı içeriğe sınırsız
  /// yükseklik veriyor ve içerideki `Expanded` çöküyor (bkz.
  /// `ClubCatalogSheet.show`).
  static Future<void> show(
    BuildContext context, {
    required int clubId,
    required String kulupAdi,
  }) {
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
          child: ClubMemberPickerSheet(
            clubId: clubId,
            kulupAdi: kulupAdi,
            kaydirma: kaydirma,
          ),
        ),
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
      children: [
        _tutamak(isDark),
        _baslik(isDark),
        siniflar.when(
          loading: () => const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Expanded(
            child: _bilgi(isDark, Icons.error_outline_rounded,
                'Sınıflar yüklenemedi'),
          ),
          data: (liste) {
            if (liste.isEmpty) {
              return Expanded(
                child: _bilgi(isDark, Icons.school_outlined,
                    'Önce sınıf eklemelisiniz'),
              );
            }
            final secili = _sinif ?? liste.first;
            return Expanded(
              child: Column(
                children: [
                  _sinifSecici(isDark, liste, secili),
                  Expanded(
                    child: _ogrenciListesi(isDark, secili, kayitliOgrenciler),
                  ),
                ],
              ),
            );
          },
        ),
        _altCubuk(isDark),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Üye Ekle',
                  style: AppFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.kulupAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  /// Şube seçici — yatay kaydırılan sekme şeridi.
  ///
  /// `ChoiceChip` yerine elle çizilmiş sekme: çip Material'ın kendi
  /// zeminini getiriyor ve aydınlık modda etiket okunmuyordu.
  Widget _sinifSecici(
    bool isDark,
    List<ClassModel> liste,
    ClassModel secili,
  ) {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        controller: null,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: liste.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = liste[i];
          final aktif = s.id == secili.id;

          return GestureDetector(
            onTap: () => setState(() => _sinif = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: aktif
                    ? AppColors.primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: aktif
                      ? AppColors.primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Text(
                s.name,
                style: AppFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  // Renk açıkça veriliyor: devralınan renk aydınlık
                  // modda okunmuyordu (bkz. theme_contrast_test).
                  color: aktif
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
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
      error: (e, _) => _bilgi(
          isDark, Icons.error_outline_rounded, 'Öğrenciler yüklenemedi'),
      data: (liste) {
        if (liste.isEmpty) {
          return _bilgi(
              isDark, Icons.people_outline_rounded, 'Bu şubede öğrenci yok');
        }

        // Tümünü seçme kısayolu: 30 kişilik sınıfta tek tek dokunmak
        // yorucu.
        final secilebilir = [
          for (final o in liste)
            if (o.id != null && !kayitli.contains(o.id)) o.id!,
        ];
        final hepsiSecili = secilebilir.isNotEmpty &&
            secilebilir.every(_secili.contains);

        return ListView.separated(
          controller: widget.kaydirma,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          itemCount: liste.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _tumunuSec(isDark, secilebilir, hepsiSecili);
            }
            return _ogrenciSatiri(isDark, liste[i - 1], kayitli);
          },
        );
      },
    );
  }

  Widget _tumunuSec(bool isDark, List<int> secilebilir, bool hepsiSecili) {
    if (secilebilir.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          'Bu şubedeki herkes zaten üye.',
          style: AppFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: () => setState(() {
          if (hepsiSecili) {
            _secili.removeAll(secilebilir);
          } else {
            _secili.addAll(secilebilir);
          }
        }),
        child: Row(
          children: [
            Icon(
              hepsiSecili
                  ? Icons.remove_done_rounded
                  : Icons.done_all_rounded,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 7),
            Text(
              hepsiSecili
                  ? 'Seçimi kaldır'
                  : 'Tümünü seç (${secilebilir.length})',
              style: AppFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ogrenciSatiri(bool isDark, StudentModel o, Set<int> kayitli) {
    final id = o.id;
    final zatenUye = id != null && kayitli.contains(id);
    final isaretli = id != null && _secili.contains(id);
    final ad = '${o.firstName} ${o.lastName}'.trim();

    return GestureDetector(
      onTap: zatenUye || id == null
          ? null
          : () => setState(() {
                if (isaretli) {
                  _secili.remove(id);
                } else {
                  _secili.add(id);
                }
              }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isaretli
              ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.09)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isaretli
                ? AppColors.primary.withValues(alpha: 0.55)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            // Baş harf rozeti — sıkışık listede satırları ayırır.
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: zatenUye
                    ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0))
                    : AppColors.primary.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Text(
                ad.isEmpty ? '?' : ad[0].toUpperCase(),
                style: AppFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: zatenUye
                      ? (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  Text(
                    zatenUye
                        ? 'Zaten üye'
                        : (o.schoolNumber > 0
                            ? 'No: ${o.schoolNumber}'
                            : 'Numarasız'),
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
            Icon(
              zatenUye
                  ? Icons.check_circle_rounded
                  : (isaretli
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 21,
              color: zatenUye
                  ? (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
                  : (isaretli
                      ? AppColors.primary
                      : (isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bilgi(bool isDark, IconData ikon, String metin) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon,
                size: 40,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            const SizedBox(height: 10),
            Text(
              metin,
              style: AppFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );

  /// Alt çubuk — seçim yoksa da durur ki sayfa aşağıdan kesik görünmesin.
  Widget _altCubuk(bool isDark) {
    final varMi = _secili.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: varMi ? _kaydet : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor:
                isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Text(
            varMi
                ? '${_secili.length} öğrenciyi üye yap'
                : 'Öğrenci seçin',
            style: AppFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: varMi
                  ? Colors.white
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _kaydet() async {
    if (_secili.isEmpty) return;

    // Seçimler birden çok şubeden birikmiş olabilir; hepsini tara.
    final siniflar = ref.read(classListProvider).value ?? const <ClassModel>[];
    final eklenecek = <ClubMember>[];

    for (final sinif in siniflar) {
      final ogrenciler =
          ref.read(studentListProvider(sinif.id ?? 0)).value ??
              const <StudentModel>[];
      for (final o in ogrenciler) {
        if (o.id == null || !_secili.contains(o.id)) continue;
        eklenecek.add(ClubMember(
          clubId: widget.clubId,
          studentId: o.id,
          adSoyad: '${o.firstName} ${o.lastName}'.trim(),
          okulNo: o.schoolNumber,
          // Şube adı kopyalanır: öğrenci sonradan şube değiştirse bile
          // yılın üye listesi tutarlı kalsın diye.
          sinifAdi: sinif.name,
        ));
      }
    }

    await ref.read(clubRepositoryProvider).uyeEkleToplu(eklenecek);
    if (!mounted) return;

    ref.invalidate(clubMembersProvider(widget.clubId));
    Navigator.of(context).pop();
  }
}
