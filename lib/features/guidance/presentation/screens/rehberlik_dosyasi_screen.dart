import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/repositories/student_repository.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/gruplu_liste.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../bep/data/models/bep_models.dart';
import '../../../bep/data/repositories/bep_repository.dart';
import '../../../classes/data/services/seating_plan_service.dart';
import '../../../classes/models/seating_plan_model.dart';
import '../../../classes/presentation/widgets/counseling_interview_modal.dart';
import '../../../classes/presentation/widgets/parent_meeting_editor_modal.dart';
import '../../../classes/providers/absence_followup_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../../classes/screens/seating_plan_screen.dart';
import '../../../classes/utils/classroom_documents_pdf_generator.dart';
import '../../../classes/utils/seating_plan_pdf_generator.dart';
import '../../data/models/guidance_plan_model.dart';
import '../../data/repositories/guidance_plan_repository.dart';
import '../../utils/rehberlik_dosyasi_pdf.dart';
import '../../utils/sinif_risk_haritasi_pdf.dart';
import '../rehberlik_onizleme.dart';
import '../views/guidance_plan_view.dart';

/// Sınıf rehberlik dosyası: ORGM'nin dosyada istediği belgeler tek yerde.
///
/// ## Neden (29 Ekim 2026)
/// Kullanıcı: "Rehberlik dosyasında ORGM'nin sitesindeki rehberlik
/// dosyasında olması gereken evraklar olmalı." Belgelerin çoğu uygulamada
/// vardı ama Sınıf Evrakları ile Form Merkezi arasında dağınıktı; dördü
/// hiç yoktu (özel eğitim listesi, görüşme çizelgesi, iki faaliyet
/// raporu). Taslak kullanıcıya gösterilip onaylandı.
///
/// ## Neden zamana göre gruplu
/// Belgeler yılın farklı anlarında istenir: plan ekimde müdür onayına,
/// risk haritası kasımda rehberlik servisine, raporlar ocak ve haziranda.
/// Öğretmen "şimdi neyi hazırlamalıyım" sorusunun cevabını listenin
/// düzeninden okur; zamanı gelen grubun yanında etiket çıkar.
///
/// Belgeler eski yerlerinde de durur; burası onları toplar, kopyalamaz.
class RehberlikDosyasiScreen extends ConsumerStatefulWidget {
  const RehberlikDosyasiScreen({super.key, required this.classModel});

  final ClassModel classModel;

  @override
  ConsumerState<RehberlikDosyasiScreen> createState() => _RehberlikDosyasiScreenState();
}

class _RehberlikDosyasiScreenState extends ConsumerState<RehberlikDosyasiScreen> {
  final _repo = GuidancePlanRepository();

  late final int _grade;
  late final String _yil;

  List<GuidancePlanItem> _plan = const [];
  Map<int, GuidanceLogEntry> _kayitlar = const {};
  PlanHaftasi _hafta = (hafta: 0, tatil: false, tatilAdi: null);
  List<BepStudentSummary> _bep = const [];
  SeatingPlanModel? _oturma;
  bool _yukleniyor = true;

  int get _classId => widget.classModel.id ?? 0;

  @override
  void initState() {
    super.initState();
    _grade = int.tryParse(InputSanitizer.extractGradeLevel(widget.classModel.name) ?? '') ?? 0;
    _yil = widget.classModel.academicYear.isNotEmpty
        ? widget.classModel.academicYear
        : AppDateFormatter.academicYearLabel();
    _yukle();
  }

  Future<void> _yukle() async {
    final plan = await _repo.planFor(_grade);
    final kayit = await _repo.logsFor(classId: _classId, academicYear: _yil);
    final ogrenciler = await StudentRepository().getStudentsByClassId(_classId);
    final bep = await BepRepository().summariesForClass(students: ogrenciler, academicYear: _yil);
    final oturma = await SeatingPlanService().getSeatingPlan(_classId);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _kayitlar = {for (final k in kayit) k.siraNo: k};
      _hafta = planHaftasi(plan, AppDateFormatter.getCurrentAcademicWeek());
      _bep = bep;
      _oturma = oturma;
      _yukleniyor = false;
    });
  }

  Future<void> _sayfa(Widget hedef) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => hedef));
    if (mounted) await _yukle();
  }

  /// [dosya]: paylaşılan PDF'in adı (Türkçe harfsiz; bazı uygulamalar bozuyor).
  Future<void> _onizle(String ad, String dosya, Future<Uint8List> Function() uret) {
    return PdfPreviewScreen.open(
      context,
      title: ad,
      subtitle: '${widget.classModel.name} · $_yil',
      fileName: '${dosya}_${widget.classModel.name}.pdf',
      documentBuilder: (_) => uret(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ogrenciler = ref.watch(studentListProvider(_classId)).valueOrNull ?? const <StudentModel>[];
    final devamsiz = ref.watch(absenceFollowupProvider(_classId)).valueOrNull ?? const [];
    final teacher = ref.watch(teacherProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'Rehberlik Dosyası',
        subtitle: '${widget.classModel.name} · $_yil',
        showProfileAvatar: false,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                children: [
                  _haftaKarti(isDark, teacher, ogrenciler),
                  for (final g in _gruplar(teacher, ogrenciler, devamsiz.length)) ...[
                    const SizedBox(height: 18),
                    GrupBasligi(g.baslik, etiket: g.aylar == null ? null : zamanEtiketi(g.aylar!, DateTime.now())),
                    const SizedBox(height: 7),
                    GrupKutusu(satirlar: [for (final b in g.belgeler) _satir(b, ogrenciler.isEmpty)]),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Bir belgeye dokununca önizlemesi açılır; oradan yazdırılır ya da '
                    'paylaşılır. Öğrenci ve veli görüşme formları Rehberlik › Formlar\'dadır.',
                    style: AppFonts.outfit(fontSize: 11, color: _soluk(isDark)),
                  ),
                ],
              ),
            ),
    );
  }

  List<_Grup> _gruplar(TeacherProfileModel teacher, List<StudentModel> ogrenciler, int devamsizSayisi) {
    final c = widget.classModel;
    final telli = ogrenciler.where((s) => (s.parentPhone ?? '').trim().isNotEmpty).length;
    final bepli = _bep.where((b) => b.planCount > 0).length;
    final uygulanan = _plan.where((m) => m.uygulanabilir && _kayitlar[m.siraNo]?.uygulandi == true).toList();

    return [
      _Grup('YIL BAŞI · EYLÜL–EKİM', const [9, 10], [
        _Belge(
          anahtar: 'plan',
          ikon: Icons.event_note_outlined,
          ad: 'Sınıf Rehberlik Planı',
          alt: _plan.isEmpty
              ? 'Bu sınıf için plan bulunamadı'
              : 'Yıllık plan ve takip çizelgesi · ekim 2. haftasına kadar müdür onayı',
          eksik: _plan.isEmpty,
          ac: _plan.isEmpty
              ? null
              : () => RehberlikOnizleme.planCizelgesi(context,
                  classModel: c, teacher: teacher, plan: _plan, kayitlar: _kayitlar, grade: _grade, yil: _yil),
        ),
        _Belge(
          anahtar: 'sinif_listesi',
          ikon: Icons.format_list_numbered_rounded,
          ad: 'Sınıf Listesi',
          alt: '${ogrenciler.length} öğrenci · imza sütunlu',
          ogrenciGerekir: true,
          ac: () => ClassroomDocumentsPdfGenerator.generateStudentListPdf(
              context: context, classModel: c, students: ogrenciler, teacherProfile: teacher),
        ),
        _Belge(
          anahtar: 'veli_listesi',
          ikon: Icons.contact_phone_outlined,
          ad: 'Veli İletişim Listesi',
          alt: '$telli/${ogrenciler.length} velinin telefonu kayıtlı',
          eksik: telli < ogrenciler.length,
          ogrenciGerekir: true,
          ac: () => ClassroomDocumentsPdfGenerator.generateEmergencyContactListPdf(
              context: context, classModel: c, students: ogrenciler, teacherProfile: teacher),
        ),
        _Belge(
          anahtar: 'oturma_plani',
          ikon: Icons.event_seat_outlined,
          ad: 'Oturma Planı',
          alt: _oturma == null ? 'Henüz hazırlanmadı · dokunup hazırlayın' : 'Kayıtlı plan · sınıf krokisi',
          eksik: _oturma == null,
          ogrenciGerekir: true,
          ac: () {
            final plan = _oturma;
            if (plan == null) return _sayfa(SeatingPlanScreen(classModel: c));
            return _onizle('Oturma Planı', 'Oturma_Plani',
                () => SeatingPlanPdfGenerator.olustur(classModel: c, students: ogrenciler, plan: plan));
          },
        ),
        _Belge(
          anahtar: 'tanima_fisi',
          ikon: Icons.badge_outlined,
          ad: 'Öğrenci Tanıma Fişi',
          alt: 'Boş form ya da seçilen öğrencinin adına',
          ogrenciGerekir: true,
          ac: () => CounselingInterviewModal.show(context,
              classModel: c, students: ogrenciler, teacherProfile: teacher, initialDocumentIndex: 3),
        ),
        _Belge(
          anahtar: 'ozel_egitim',
          ikon: Icons.accessibility_new_rounded,
          ad: 'Özel Eğitime İhtiyacı Olan Öğrenciler',
          alt: bepli == 0 ? 'BEP\'i olan öğrenci yok · boş liste' : '$bepli öğrencinin BEP\'i var · amaç takibiyle',
          ac: () => _onizle('Özel Eğitime İhtiyacı Olan Öğrenciler', 'Ozel_Egitim_Listesi',
              () => RehberlikDosyasiPdf.ozelEgitimListesi(classModel: c, ogrenciler: _bep, teacherProfile: teacher)),
        ),
      ]),
      _Grup('KASIM', const [11], [
        _Belge(
          anahtar: 'risk_haritasi',
          ikon: Icons.grid_on_rounded,
          ad: 'Sınıf Risk Haritası',
          alt: 'Kâğıtta işaretlenir · rehberlik servisine verilir',
          ogrenciGerekir: true,
          ac: () => _onizle('Sınıf Risk Haritası', 'Sinif_Risk_Haritasi',
              () => SinifRiskHaritasiPdf.olustur(classModel: c, students: ogrenciler, teacherProfile: teacher)),
        ),
      ]),
      _Grup('YIL BOYUNCA', null, [
        _Belge(
          anahtar: 'haftalik_kayitlar',
          ikon: Icons.task_alt_rounded,
          ad: 'Haftalık Etkinlik Kayıtları',
          alt: uygulanan.isEmpty
              ? 'Henüz işaretli hafta yok · haftalık takipte işaretlenir'
              : '${uygulanan.length} hafta uygulandı · her hafta bir sayfa',
          ac: uygulanan.isEmpty
              ? () => _sayfa(_HaftalikTakip(classModel: c))
              : () => RehberlikOnizleme.uygulamaKayitlari(context,
                  classModel: c,
                  teacher: teacher,
                  repo: _repo,
                  maddeler: uygulanan,
                  kayitlar: _kayitlar,
                  grade: _grade,
                  yil: _yil,
                  baslik: 'uygulanan ${uygulanan.length} hafta'),
        ),
        _Belge(
          anahtar: 'gorusme_cizelgesi',
          ikon: Icons.forum_outlined,
          ad: 'Görüşme Çizelgesi',
          alt: 'Öğrenci ve veli görüşmeleri · yönlendirme sütunlu',
          ac: () => _onizle('Görüşme Çizelgesi', 'Gorusme_Cizelgesi',
              () => RehberlikDosyasiPdf.gorusmeCizelgesi(classModel: c, teacherProfile: teacher)),
        ),
        _Belge(
          anahtar: 'devamsizlik',
          ikon: Icons.person_off_outlined,
          ad: 'Devamsızlık Takip Çizelgesi',
          alt: devamsizSayisi == 0 ? 'Takipte öğrenci yok · boş çizelge' : '$devamsizSayisi öğrenci takipte',
          ac: () => ClassroomDocumentsPdfGenerator.generateAbsenceFollowupPdf(
              context: context,
              classModel: c,
              entries: ref.read(absenceFollowupProvider(_classId)).valueOrNull ?? const [],
              teacherProfile: teacher),
        ),
        _Belge(
          anahtar: 'veli_toplantisi',
          ikon: Icons.groups_outlined,
          ad: 'Veli Toplantı Tutanağı',
          alt: 'Gündem, kararlar, imza sirküsü',
          ogrenciGerekir: true,
          ac: () => ParentMeetingEditorModal.show(context,
              classModel: c, students: ogrenciler, teacherProfile: teacher),
        ),
        _Belge(
          anahtar: 'gezi_izni',
          ikon: Icons.directions_bus_outlined,
          ad: 'Gezi İzin Belgesi',
          alt: 'Tek A4\'te 2 muvafakatname',
          ogrenciGerekir: true,
          ac: () => CounselingInterviewModal.show(context,
              classModel: c, students: ogrenciler, teacherProfile: teacher, initialDocumentIndex: 4),
        ),
      ]),
      _Grup('DÖNEM VE YIL SONU', const [1, 6], [
        for (final d in FaaliyetDonemi.values)
          _Belge(
            anahtar: d == FaaliyetDonemi.birinci ? 'rapor_donem' : 'rapor_yil_sonu',
            ikon: d == FaaliyetDonemi.birinci ? Icons.summarize_outlined : Icons.assignment_turned_in_outlined,
            ad: d == FaaliyetDonemi.birinci ? '1. Dönem Faaliyet Raporu' : 'Yıl Sonu Faaliyet Raporu',
            alt: d == FaaliyetDonemi.birinci
                ? 'Ocak · haftalık kayıtlardan doldurulur'
                : 'Haziran · iki dönemin özeti',
            ac: () => _onizle(
              d == FaaliyetDonemi.birinci ? '1. Dönem Faaliyet Raporu' : 'Yıl Sonu Faaliyet Raporu',
              d == FaaliyetDonemi.birinci ? 'Donem_Faaliyet_Raporu' : 'Yil_Sonu_Faaliyet_Raporu',
              () => RehberlikDosyasiPdf.faaliyetRaporu(
                donem: d,
                classModel: c,
                students: ogrenciler,
                teacherProfile: teacher,
                plan: _plan,
                kayitlar: _kayitlar,
                // Tatildeyse tatilden önceki hafta bitti; değilse bu hafta sürüyor.
                sonGecenHafta: _hafta.tatil ? _hafta.hafta : _hafta.hafta - 1,
                bepliOgrenci: bepli,
                devamsizTakip: devamsizSayisi,
              ),
            ),
          ),
      ]),
    ];
  }

  Color _yazi(bool isDark) => isDark ? Colors.white : const Color(0xFF0F172A);
  Color _soluk(bool isDark) => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color _yuzey(bool isDark) => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color _cizgi(bool isDark) => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  /// Bu haftanın etkinliği ve yılın ilerlemesi; dokununca haftalık takip açılır.
  Widget _haftaKarti(bool isDark, TeacherProfileModel teacher, List<StudentModel> ogrenciler) {
    final uygulanabilir = _plan.where((m) => m.uygulanabilir).toList();
    final uygulanan = uygulanabilir.where((m) => _kayitlar[m.siraNo]?.uygulandi == true).length;
    final madde = _hafta.tatil
        ? null
        : uygulanabilir.where((m) => m.hafta == _hafta.hafta).firstOrNull;

    final String ust;
    final String baslik;
    final String? alt;
    if (_plan.isEmpty) {
      ust = 'SINIF REHBERLİK PLANI';
      baslik = _grade == 0 ? 'Sınıf adından kademe okunamadı' : '$_grade. sınıf için plan bulunamadı';
      alt = _grade == 0 ? 'Sınıf adı "5-A" gibi olmalı.' : null;
    } else if (_hafta.tatil) {
      final sonraki = uygulanabilir.where((m) => (m.hafta ?? 0) > _hafta.hafta).firstOrNull;
      ust = 'BU HAFTA';
      baslik = 'Tatil haftası';
      alt = sonraki == null ? null : 'Sıradaki: ${sonraki.etkinlikAdi ?? sonraki.kazanim}';
    } else if (madde == null) {
      ust = 'BU HAFTA · ${_hafta.hafta}. HAFTA';
      baslik = 'Bu hafta rehberlik etkinliği yok';
      alt = null;
    } else {
      ust = 'BU HAFTA · ${_hafta.hafta}. HAFTA';
      baslik = madde.etkinlikAdi ?? madde.kazanim;
      alt = madde.etkinlikAdi == null ? null : madde.kazanim;
    }
    final buHaftaYapildi = madde != null && _kayitlar[madde.siraNo]?.uygulandi == true;

    return Material(
      color: _yuzey(isDark),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('rehberlik_dosyasi_hafta'),
        borderRadius: BorderRadius.circular(14),
        onTap: _plan.isEmpty ? null : () => _sayfa(_HaftalikTakip(classModel: widget.classModel)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ust,
                        style: AppFonts.outfit(
                            fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.6)),
                  ),
                  if (_plan.isNotEmpty) ...[
                    Text('Haftalık takip',
                        style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(baslik, style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: _yazi(isDark))),
              if (alt != null) ...[
                const SizedBox(height: 2),
                Text(alt, style: AppFonts.outfit(fontSize: 11.5, color: _soluk(isDark))),
              ],
              if (buHaftaYapildi) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('Uygulandı',
                        style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ],
                ),
              ],
              if (uygulanabilir.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: uygulanan / uygulanabilir.length,
                    minHeight: 6,
                    color: AppColors.success,
                    backgroundColor: _cizgi(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$uygulanan / ${uygulanabilir.length} hafta uygulandı',
                    style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: _soluk(isDark))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _satir(_Belge b, bool ogrenciYok) {
    final engel = b.ogrenciGerekir && ogrenciYok;
    return GrupSatiri(
      key: ValueKey('rehberlik_dosyasi_${b.anahtar}'),
      ikon: b.ikon,
      ad: b.ad,
      alt: engel ? 'Önce sınıfa öğrenci ekleyin' : b.alt,
      uyari: b.eksik || engel,
      onTap: b.ac == null
          ? null
          : engel
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bu belge için önce sınıfa öğrenci ekleyin.')),
                  )
              : b.ac,
    );
  }
}

class _Grup {
  const _Grup(this.baslik, this.aylar, this.belgeler);

  final String baslik;

  /// Zaman etiketi için grubun ayları; "yıl boyunca" grubunda yok.
  final List<int>? aylar;
  final List<_Belge> belgeler;
}

class _Belge {
  const _Belge({
    required this.anahtar,
    required this.ikon,
    required this.ad,
    required this.alt,
    required this.ac,
    this.eksik = false,
    this.ogrenciGerekir = false,
  });

  /// Test anahtarı: `rehberlik_dosyasi_<anahtar>`.
  final String anahtar;
  final IconData ikon;
  final String ad;

  /// Sınıfın durumu: "32 öğrenci", "3 öğrenci takipte"…
  final String alt;

  /// Eksik bir şey var: alt satır turuncu yazılır.
  final bool eksik;

  /// Öğrenci listesinden üretilir; sınıf boşken açılmaz.
  final bool ogrenciGerekir;
  final Future<void> Function()? ac;
}

/// Haftalık takip: sınıf rehberlik planının hafta hafta işaretlendiği sayfa.
class _HaftalikTakip extends ConsumerWidget {
  const _HaftalikTakip({required this.classModel});

  final ClassModel classModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'Haftalık Takip',
        subtitle: '${classModel.name} · sınıf rehberlik planı',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: GuidancePlanView(
          classModel: classModel,
          teacher: ref.watch(teacherProfileProvider),
          students: ref.watch(studentListProvider(classModel.id ?? 0)).valueOrNull ?? const [],
        ),
      ),
    );
  }
}
