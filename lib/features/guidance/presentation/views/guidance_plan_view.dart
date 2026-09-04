import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../data/models/class_model.dart';
import '../../data/models/guidance_plan_model.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../bep/data/repositories/bep_repository.dart';
import '../../data/repositories/guidance_plan_repository.dart';
import '../../utils/guidance_plan_pdf_generator.dart';
import '../widgets/guidance_activity_sheet.dart';

/// Sınıf rehberlik planı — haftalık uygulama takibi.
///
/// ## Neden liste değil de takip
/// Hazır planlar yılbaşında bir kez basılıp dolaba konuyor. Bizde
/// takvim zaten var: bu hafta hangi kazanım işleniyor, hangileri
/// uygulandı, yıl sonunda kaçı tamamlandı — hepsi otomatik.
class GuidancePlanView extends StatefulWidget {
  const GuidancePlanView({
    super.key,
    required this.classModel,
    required this.teacher,
    this.students = const [],
  });

  final ClassModel classModel;
  final TeacherProfileModel teacher;

  /// Sinifin ogrencileri — BEP'li ogrenci var mi diye bakilir.
  final List<StudentModel> students;

  @override
  State<GuidancePlanView> createState() => _GuidancePlanViewState();
}

class _GuidancePlanViewState extends State<GuidancePlanView> {
  final _repo = GuidancePlanRepository();

  late final int _grade;
  late final String _yil;
  late final int _buHafta;

  List<GuidancePlanItem> _plan = const [];
  Map<int, GuidanceLogEntry> _kayitlar = const {};
  bool _yukleniyor = true;

  /// Yalnızca uygulanmamışları göster.
  bool _sadeceKalanlar = false;

  /// Sinifta BEP plani olan ogrenci sayisi.
  ///
  /// Sifirdan buyukse etkinlik sayfasinda "ozel gereksinimli ogrenciler
  /// icin uyarlamalar" bolumu one cikarilir; ORGM her etkinlikte bu
  /// onerileri veriyor ama PDF'in icinde gomulu kaliyordu.
  int _bepliOgrenci = 0;

  @override
  void initState() {
    super.initState();
    _grade = int.tryParse(
          InputSanitizer.extractGradeLevel(widget.classModel.name) ?? '',
        ) ??
        0;
    _yil = widget.classModel.academicYear.isNotEmpty
        ? widget.classModel.academicYear
        : AppDateFormatter.academicYearLabel();
    _buHafta = AppDateFormatter.getCurrentAcademicWeek();
    _yukle();
  }

  Future<void> _yukle() async {
    final plan = await _repo.planFor(_grade);
    final kayit = await _repo.logsFor(
      classId: widget.classModel.id ?? 0,
      academicYear: _yil,
    );
    final bepli = widget.students.isEmpty
        ? 0
        : (await BepRepository().summariesForClass(
            students: widget.students,
            academicYear: _yil,
          ))
            .where((e) => e.planCount > 0)
            .length;
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _kayitlar = {for (final k in kayit) k.siraNo: k};
      _bepliOgrenci = bepli;
      _yukleniyor = false;
    });
  }

  Future<void> _isaretle(GuidancePlanItem madde, bool uygulandi) async {
    final mevcut = _kayitlar[madde.siraNo];
    await _repo.saveLog(GuidanceLogEntry(
      classId: widget.classModel.id ?? 0,
      academicYear: _yil,
      gradeLevel: _grade,
      hafta: madde.hafta ?? 0,
      siraNo: madde.siraNo ?? 0,
      uygulandi: uygulandi,
      not: mevcut?.not ?? '',
      uygulanmaTarihi: uygulandi ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    ));
    await _yukle();
  }

  Future<void> _etkinligiAc(GuidancePlanItem madde) async {
    final etkinlik = await _repo.activityFor(
      gradeLevel: _grade,
      hafta: madde.hafta ?? 0,
    );
    if (!mounted) return;
    GuidanceActivitySheet.show(
      context,
      madde: madde,
      etkinlik: etkinlik,
      kayit: _kayitlar[madde.siraNo],
      bepliOgrenci: _bepliOgrenci,
      onDurumDegisti: (u) => _isaretle(madde, u),
      onNotKaydet: (metin) async {
        await _repo.saveLog(GuidanceLogEntry(
          classId: widget.classModel.id ?? 0,
          academicYear: _yil,
          gradeLevel: _grade,
          hafta: madde.hafta ?? 0,
          siraNo: madde.siraNo ?? 0,
          uygulandi: _kayitlar[madde.siraNo]?.uygulandi ?? false,
          not: metin,
          uygulanmaTarihi: _kayitlar[madde.siraNo]?.uygulanmaTarihi,
          updatedAt: DateTime.now(),
        ));
        await _yukle();
      },
    );
  }

  /// Geçmiş haftaları toplu işaretler.
  ///
  /// ## Neden "tümü" değil de "bu haftaya kadar"
  /// Öğretmen yılın ortasında uygulamayı kurduğunda geriye dönük
  /// 20 kazanımı tek tek işaretlemek zorunda kalıyordu. Ama HENÜZ
  /// GELMEMİŞ haftaları da işaretlemek belgeyi yanlış kılar —
  /// yapılmamış işi yapılmış göstermek resmî evrakta savunulamaz.
  /// Bu yüzden yalnızca bu haftaya kadarki satırlar işaretlenir.
  Future<void> _gecmisiIsaretle() async {
    final hedef = _plan
        .where((e) =>
            e.uygulanabilir &&
            e.hafta != null &&
            e.hafta! <= _buHafta &&
            _kayitlar[e.siraNo]?.uygulandi != true)
        .toList();

    if (hedef.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu haftaya kadarki kazanımlar zaten işaretli.'),
        ),
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Toplu işaretleme'),
        content: Text(
          '${hedef.length} kazanım "uygulandı" olarak işaretlenecek '
          '(1 – $_buHafta. hafta arası). '
          'Bu haftadan sonraki kazanımlara dokunulmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('İşaretle'),
          ),
        ],
      ),
    );
    if (onay != true) return;

    final simdi = DateTime.now();
    await _repo.saveLogs([
      for (final e in hedef)
        GuidanceLogEntry(
          classId: widget.classModel.id ?? 0,
          academicYear: _yil,
          gradeLevel: _grade,
          hafta: e.hafta ?? 0,
          siraNo: e.siraNo ?? 0,
          uygulandi: true,
          not: _kayitlar[e.siraNo]?.not ?? '',
          uygulanmaTarihi: simdi,
          updatedAt: simdi,
        ),
    ]);
    await _yukle();
  }

  Future<void> _pdf() async {
    await PdfPreviewScreen.open(
      context,
      title: 'Rehberlik planı',
      subtitle: '${widget.classModel.name} · $_yil',
      fileName: 'Rehberlik_Plani_${widget.classModel.name}.pdf',
      documentBuilder: (_) => GuidancePlanPdfGenerator.build(
        plan: _plan,
        kayitlar: _kayitlar,
        gradeLevel: _grade,
        className: widget.classModel.name,
        schoolName: widget.teacher.schoolName,
        teacherName: widget.teacher.fullName,
        academicYear: _yil,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_plan.isEmpty) {
      return _bosDurum(isDark);
    }

    final uygulanabilir = _plan.where((e) => e.uygulanabilir).toList();
    final uygulanan =
        uygulanabilir.where((e) => _kayitlar[e.siraNo]?.uygulandi == true).length;

    final gosterilecek = _sadeceKalanlar
        ? _plan
            .where((e) =>
                !e.uygulanabilir || _kayitlar[e.siraNo]?.uygulandi != true)
            .toList()
        : _plan;

    return Column(
      children: [
        _ilerlemeSeridi(isDark, uygulanan, uygulanabilir.length),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: gosterilecek.length,
            itemBuilder: (_, i) => _satir(gosterilecek[i], isDark),
          ),
        ),
      ],
    );
  }

  Widget _bosDurum(bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_outlined,
                  size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _grade == 0
                    ? 'Sınıf adından kademe okunamadı.\n'
                        'Sınıf adı "5-A" gibi olmalı.'
                    : '$_grade. sınıf için rehberlik planı bulunamadı.',
                textAlign: TextAlign.center,
                style: AppFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _ilerlemeSeridi(bool isDark, int uygulanan, int toplam) {
    final oran = toplam == 0 ? 0.0 : uygulanan / toplam;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$_grade. Sınıf Rehberlik Planı',
                style: AppFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '$uygulanan / $toplam',
                style: AppFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _gecmisiIsaretle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.done_all_rounded,
                      size: 19, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _pdf,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.picture_as_pdf_rounded,
                      size: 19, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 6,
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$_yil · $_buHafta. hafta',
                style: AppFonts.outfit(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _sadeceKalanlar = !_sadeceKalanlar),
                child: Row(
                  children: [
                    Icon(
                      _sadeceKalanlar
                          ? Icons.filter_alt_rounded
                          : Icons.filter_alt_outlined,
                      size: 14,
                      color: _sadeceKalanlar
                          ? AppColors.primary
                          : (isDark ? Colors.white54 : Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kalanlar',
                      style: AppFonts.outfit(
                        fontSize: 11,
                        fontWeight: _sadeceKalanlar
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: _sadeceKalanlar
                            ? AppColors.primary
                            : (isDark ? Colors.white54 : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _satir(GuidancePlanItem madde, bool isDark) {
    if (madde.tatilMi) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.beach_access_rounded,
                size: 15, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${madde.kazanim}  ·  ${madde.tarihAraligi}',
                style: AppFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB45309),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // İdari işler işaretlenmez; hatırlatma amaçlı görünür.
    if (madde.idariIsMi) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(
          children: [
            Icon(Icons.push_pin_outlined,
                size: 13, color: isDark ? Colors.white38 : Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                madde.kazanim,
                style: AppFonts.outfit(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ),
            if (madde.hafta != null)
              Text(
                '${madde.hafta}. hf',
                style: AppFonts.outfit(
                  fontSize: 10.5,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
          ],
        ),
      );
    }

    final kayit = _kayitlar[madde.siraNo];
    final uygulandi = kayit?.uygulandi ?? false;
    final buHaftaMi = madde.hafta == _buHafta;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: buHaftaMi
              ? AppColors.primary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: buHaftaMi ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _etkinligiAc(madde),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tek dokunuşla işaretleme — diyalog açılmaz.
                InkWell(
                  onTap: () => _isaretle(madde, !uygulandi),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      uygulandi
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: uygulandi
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white30 : Colors.grey.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (buHaftaMi)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'BU HAFTA',
                                style: AppFonts.outfit(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Text(
                            '${madde.hafta}. hafta · ${madde.tarihAraligi}',
                            style: AppFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        madde.kazanim,
                        style: AppFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: uygulandi
                              ? (isDark ? Colors.white38 : Colors.grey)
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration:
                              uygulandi ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (madde.etkinlikAdi != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.local_activity_outlined,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                madde.etkinlikAdi!,
                                style: AppFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((kayit?.not ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '“${kayit!.not}”',
                          style: AppFonts.outfit(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: isDark ? Colors.white38 : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
