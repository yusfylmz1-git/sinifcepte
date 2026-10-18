import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
          onTap: () => _git(context, ClassroomParticipationView(initialClassId: classModel.id)),
        ),
        _dugme(
          context,
          anahtar: 'serit_devamsizlik',
          ikon: Icons.event_busy_rounded,
          ad: 'Devamsızlık',
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
          onTap: () => _git(context, SeatingPlanScreen(classModel: classModel)),
        ),
        _dugme(
          context,
          anahtar: 'serit_veliler',
          ikon: Icons.family_restroom_rounded,
          ad: 'Veliler',
          pasif: !rehberlik,
          onTap: rehberlik
              ? () => SinifVelileriEkrani.ac(context, classModel)
              : () => _neden(
                    context,
                    'Veli bağlantıları rehberlik sınıfında kurulur. Bu sınıfın '
                    'rehber öğretmeni sizi kadroya eklerse velilerle yazışabilirsiniz.',
                  ),
        ),
        _dugme(
          context,
          anahtar: 'serit_evrak',
          ikon: Icons.description_outlined,
          ad: 'Evrak',
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
    required VoidCallback onTap,
    bool pasif = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renk = pasif
        ? (isDark ? Colors.white30 : const Color(0xFF94A3B8))
        : AppColors.primary;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: ValueKey(anahtar),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ikon, size: 20, color: renk),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      ad,
                      maxLines: 1,
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: pasif
                            ? renk
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
