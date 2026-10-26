import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../attendance/presentation/views/classroom_participation_view.dart';
import '../../../parent_portal/presentation/screens/sinif_velileri_ekrani.dart';
import '../../screens/absence_followup_screen.dart';
import '../../screens/seating_plan_screen.dart';
import '../../screens/sinif_evraklari_ekrani.dart';

/// Sınıf sayfasının üstündeki düğme şeridi:
/// Katılım · Devamsızlık · Oturma · Veliler · Evrak.
///
/// Kullanıcı kararı (18 Ekim 2026): sınıfa dokununca önce öğrenciler
/// açılır, sınıfın işleri bu şeritte durur. Eskiden bu işlerin çoğu yalnız
/// rehberlik sınıfının "Sınıfım" merkezindeydi.
///
/// Devamsızlık takibi ve veli bağlantıları sınıf rehber öğretmeninin
/// işidir; ders sınıfında düğme gizlenmez, PASİF görünür ve dokununca
/// nedenini söyler (gizlense öğretmen özelliğin varlığını bilemezdi).
///
/// Görünüş (26 Ekim 2026, kullanıcı: "çok acemice, güzel ve şık
/// olmalı"): her iş kendi yumuşak renkli kutusunda, adı altta; çerçeve
/// ve gölge yok. Pasif düğmenin kutusu gri.
class SinifSeridi extends StatelessWidget {
  final ClassModel classModel;

  const SinifSeridi({super.key, required this.classModel});

  void _git(BuildContext context, Widget hedef) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => hedef));

  void _neden(BuildContext context, String metin) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(metin), duration: const Duration(seconds: 5)));
  }

  @override
  Widget build(BuildContext context) {
    final rehberlik = classModel.isHomeroom;

    return Row(
      children: [
        _dugme(
          context,
          anahtar: 'serit_katilim',
          ikon: Icons.stars_rounded,
          ad: 'Katılım',
          renk: _Renk.katilim,
          onTap: () => _git(context, ClassroomParticipationView(initialClassId: classModel.id)),
        ),
        _dugme(
          context,
          anahtar: 'serit_devamsizlik',
          ikon: Icons.event_busy_rounded,
          ad: 'Devamsızlık',
          renk: _Renk.devamsizlik,
          pasif: !rehberlik,
          onTap: rehberlik
              ? () => openAbsenceFollowupScreen(context, classModel)
              : () => _neden(
                  context,
                  'Devamsızlık takibi sınıf rehber öğretmeninin işidir. '
                  '${classModel.name} rehberlik sınıfınız değil.',
                ),
        ),
        _dugme(
          context,
          anahtar: 'serit_oturma',
          ikon: Icons.event_seat_rounded,
          ad: 'Oturma',
          renk: _Renk.oturma,
          onTap: () => _git(context, SeatingPlanScreen(classModel: classModel)),
        ),
        _dugme(
          context,
          anahtar: 'serit_veliler',
          ikon: Icons.family_restroom_rounded,
          ad: 'Veliler',
          renk: _Renk.veliler,
          pasif: !rehberlik,
          onTap: rehberlik
              ? () => SinifVelileriEkrani.ac(context, classModel)
              : () => _neden(
                  context,
                  'Veli bağlantıları rehberlik sınıfında kurulur. Bu sınıfın '
                  'rehber öğretmeni sizi kadroya eklediyse velilerin size '
                  'yazdıkları üst çubuktaki gelen kutusuna gelir.',
                ),
        ),
        _dugme(
          context,
          anahtar: 'serit_evrak',
          ikon: Icons.description_rounded,
          ad: 'Evrak',
          renk: _Renk.evrak,
          onTap: () => SinifEvraklariEkrani.ac(context, classModel),
        ),
      ],
    );
  }

  Widget _dugme(
    BuildContext context, {
    required String anahtar,
    required IconData ikon,
    required String ad,
    required _Renk renk,
    required VoidCallback onTap,
    bool pasif = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zemin = pasif
        ? (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9))
        : renk.ton.withValues(alpha: isDark ? 0.18 : 0.13);
    final simge = pasif ? (isDark ? Colors.white30 : const Color(0xFFA3AEBE)) : (isDark ? renk.acik : renk.koyu);
    final yazi = pasif
        ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
        : (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF334155));

    return Expanded(
      child: InkWell(
        key: ValueKey(anahtar),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: LayoutBuilder(
            builder: (context, kisit) {
              final yaziStili = AppFonts.outfit(
                fontSize: _yaziBoyu(context, kisit.maxWidth),
                fontWeight: FontWeight.w600,
                color: yazi,
              );
              // Çok dar ekranda kutu sütundan taşmasın.
              final kutu = kisit.maxWidth < 50 ? kisit.maxWidth : 50.0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: kutu,
                    height: kutu,
                    decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(15)),
                    child: Icon(ikon, size: 24, color: simge),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(ad, maxLines: 1, style: yaziStili),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Adların yazı boyu: en uzun ad ("Devamsızlık") sığacak kadar.
  ///
  /// Her düğme kendi adını ayrı küçültünce "Devamsızlık" ötekilerden
  /// ufak kalıyordu; düğmeler eşit genişlikte olduğu için bu hesap beşinde
  /// aynı boyu verir.
  static double _yaziBoyu(BuildContext context, double genislik) {
    const enBuyuk = 11.5;
    final olcum = TextPainter(
      text: TextSpan(
        text: 'Devamsızlık',
        style: DefaultTextStyle.of(
          context,
        ).style.merge(AppFonts.outfit(fontSize: enBuyuk, fontWeight: FontWeight.w600)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final gereken = olcum.width;
    olcum.dispose();
    if (gereken <= genislik || gereken == 0) return enBuyuk;
    return (enBuyuk * genislik / gereken).clamp(8.0, enBuyuk);
  }
}

/// Şeritteki her işin rengi: [ton] zeminin tonu, [koyu] aydınlık temada
/// simge, [acik] karanlık temada simge.
enum _Renk {
  katilim(Color(0xFFF59E0B), Color(0xFFB45309), Color(0xFFFBBF24)),
  devamsizlik(Color(0xFFF43F5E), Color(0xFFBE123C), Color(0xFFFB7185)),
  oturma(Color(0xFF14B8A6), Color(0xFF0F766E), Color(0xFF2DD4BF)),
  veliler(Color(0xFF8B5CF6), Color(0xFF6D28D9), Color(0xFFA78BFA)),
  evrak(Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF60A5FA));

  const _Renk(this.ton, this.koyu, this.acik);
  final Color ton;
  final Color koyu;
  final Color acik;
}
